# Tassel — build helpers. Everything here works with the Command Line Tools;
# a full Xcode install is not required.

APP_NAME    := Tassel
CONFIG      ?= debug
# `=`, not `:=`. `:=` fixes the path the moment this file is read, while CONFIG
# is still debug, so `make install` built a release binary and then shipped the
# old debug one — for three installs running, before anyone noticed.
BUILD_DIR   = .build/$(CONFIG)
BUNDLE      := .build/$(APP_NAME).app

VERSION     := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
DMG         := .build/$(APP_NAME)-$(VERSION).dmg

.PHONY: all build app run install uninstall dist release icon check clean

all: app

build:
	swift build -c $(CONFIG)

## Assemble a real .app bundle. SwiftPM only produces a bare executable, and a
## menu bar app needs the Info.plist (LSUIElement) to stay out of the Dock.
app: build
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	## Drawn charm artwork, if there is any yet. The template is a guide for
	## drawing and has no business being shipped.
	@if ls Resources/Charms/*.png >/dev/null 2>&1; then \
		for art in Resources/Charms/*.png; do \
			case "$$art" in *TEMPLATE.png) continue;; esac; \
			cp "$$art" "$(BUNDLE)/Contents/Resources/"; \
		done; \
		echo "bundled $$(ls $(BUNDLE)/Contents/Resources/*.png 2>/dev/null | wc -l | tr -d ' ') charm image(s)"; \
	fi
	## Ad-hoc signature: enough to run locally. Replace with your own Developer ID
	## before distributing, or users will meet Gatekeeper.
	codesign --force --sign - "$(BUNDLE)" >/dev/null 2>&1 || true
	@echo "built $(BUNDLE)"

run: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	open "$(BUNDLE)"

## `swift test` is deliberately not used: XCTest ships with Xcode, not the
## Command Line Tools, so it cannot run on a CLT-only machine.
check:
	swift run -c $(CONFIG) TasselChecks

## Put it somewhere permanent, so it survives `make clean` and can be launched
## from Spotlight or set to open at login.
install: CONFIG = release
install: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@## Wait for it to actually quit: `open` on an app that is still shutting down
	@## brings the old one forward instead of launching the new one.
	@while pgrep -x $(APP_NAME) >/dev/null; do sleep 0.1; done
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "installed /Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

## A disk image to give to someone else: the app beside a link to /Applications
## to drag it onto. Universal, so it runs on Apple Silicon and Intel alike and
## nobody has to know which they have. Still only ad-hoc signed: without a
## Developer ID and notarization, the first open needs Open Anyway in
## System Settings ▸ Privacy & Security.
dist: CONFIG = release
dist: app
	swift build -c release --triple arm64-apple-macosx14.0 --product $(APP_NAME)
	swift build -c release --triple x86_64-apple-macosx14.0 --product $(APP_NAME)
	lipo -create \
		.build/arm64-apple-macosx/release/$(APP_NAME) \
		.build/x86_64-apple-macosx/release/$(APP_NAME) \
		-output "$(BUNDLE)/Contents/MacOS/$(APP_NAME)"
	codesign --force --sign - "$(BUNDLE)"
	rm -rf .build/dmg "$(DMG)"
	mkdir -p .build/dmg
	cp -R "$(BUNDLE)" .build/dmg/
	ln -s /Applications .build/dmg/Applications
	hdiutil create -quiet -volname "$(APP_NAME)" -srcfolder .build/dmg -ov -format UDZO "$(DMG)"
	rm -rf .build/dmg
	@echo "made $(DMG)"

## Publish a new version through the Homebrew tap. See Tools/release.sh.
##   make release VERSION=0.1.2 NOTES="What changed."
release:
	Tools/release.sh "$(VERSION)"

## Redraw Resources/AppIcon.icns from the maneki-neko drawing. The result is
## checked in, so this is only needed when the icon itself should change.
icon:
	swiftc -O Sources/TasselCore/*.swift Tools/app-icon/main.swift -o .build/app-icon
	.build/app-icon

uninstall:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf "/Applications/$(APP_NAME).app"
	@echo "removed /Applications/$(APP_NAME).app"

clean:
	rm -rf .build
