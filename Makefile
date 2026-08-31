# Tassel — build helpers. Everything here works with the Command Line Tools;
# a full Xcode install is not required.

APP_NAME    := Tassel
CONFIG      ?= debug
BUILD_DIR   := .build/$(CONFIG)
BUNDLE      := .build/$(APP_NAME).app

.PHONY: all build app run install uninstall check clean

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
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "installed /Applications/$(APP_NAME).app"
	open "/Applications/$(APP_NAME).app"

uninstall:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf "/Applications/$(APP_NAME).app"
	@echo "removed /Applications/$(APP_NAME).app"

clean:
	rm -rf .build
