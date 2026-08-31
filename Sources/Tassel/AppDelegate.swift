import AppKit
import Carbon.HIToolbox
import TasselCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlay: OverlayWindow!
    private var charmView: CharmView!
    private var hotKey: GlobalHotKey?
    private var anchorTimer: Timer?
    private var positioningTimeout: Timer?

    private let preferences = Preferences.shared

    /// Positioning mode swallows every click on the screen, so it gets a hard
    /// deadline: an app that can trap your mouse needs a way out that does not
    /// depend on the user knowing the way out.
    private let positioningTimeLimit: TimeInterval = 20

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        setUpOverlay()
        setUpHotKey()

        // Menu bar items slide around as other apps come and go, and AppKit
        // posts no notification for it, so poll at a rate nobody will feel.
        anchorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            // Stand down while the charm is in the user's hand: re-resolving the
            // stored placement mid-drag would yank it straight back.
            guard let self, !self.charmView.isInteracting else { return }
            self.repositionOverlay()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        setVisible(preferences.isVisible)
    }

    func applicationWillTerminate(_ notification: Notification) {
        anchorTimer?.invalidate()
        positioningTimeout?.invalidate()
        charmView?.stopAnimating()
    }

    /// The screen the charm hangs on. Multi-display placement is not modelled
    /// yet, so it always uses the screen that owns the menu bar.
    private var anchorScreen: NSScreen? {
        statusItem?.button?.window?.screen ?? NSScreen.screens.first ?? NSScreen.main
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = preferences.charm.glyph
        statusItem.button?.toolTip = "Tassel"
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: preferences.isVisible ? "Hide Charm" : "Show Charm",
            action: #selector(toggleVisible),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let drop = NSMenuItem(title: "Drop In", action: #selector(dropIn), keyEquivalent: "")
        drop.target = self
        menu.addItem(drop)

        menu.addItem(.separator())
        menu.addItem(charmMenuItem())
        menu.addItem(positionMenuItem())

        let grab = NSMenuItem(
            title: "Grab With Pointer",
            action: #selector(toggleCatchesPointer),
            keyEquivalent: ""
        )
        grab.target = self
        grab.state = preferences.catchesPointer ? .on : .off
        grab.toolTip = "Let the charm be picked up and thrown. Turn off to make it purely decorative."
        menu.addItem(grab)

        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit Tassel",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        return menu
    }

    private func charmMenuItem() -> NSMenuItem {
        let submenu = NSMenu()
        for charm in Charm.builtIn {
            let item = NSMenuItem(
                title: "\(charm.glyph)  \(charm.name)",
                action: #selector(selectCharm(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = charm.glyph
            item.state = charm.glyph == preferences.charm.glyph ? .on : .off
            submenu.addItem(item)
        }
        submenu.addItem(.separator())

        let custom = NSMenuItem(
            title: "Custom Emoji\u{2026}",
            action: #selector(chooseCustomCharm),
            keyEquivalent: ""
        )
        custom.target = self
        submenu.addItem(custom)

        let item = NSMenuItem(title: "Charm", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func positionMenuItem() -> NSMenuItem {
        let submenu = NSMenu()
        let current = preferences.placement

        for (index, preset) in Placement.presets.enumerated() {
            let item = NSMenuItem(
                title: preset.name,
                action: #selector(selectPlacement(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            item.state = preset.placement == current ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(.separator())

        let move = NSMenuItem(title: "Move\u{2026}", action: #selector(beginPositioning), keyEquivalent: "")
        move.target = self
        submenu.addItem(move)

        // A custom spot from a drag matches no preset, so say so rather than
        // showing a submenu with nothing ticked.
        let isCustom = !Placement.presets.contains { $0.placement == current }
        let item = NSMenuItem(title: isCustom ? "Position (Custom)" : "Position", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func refreshMenu() {
        statusItem.menu = buildMenu()
    }

    // MARK: - Overlay

    private func setUpOverlay() {
        // The window covers the whole screen so the charm can hang anywhere on
        // it. It is transparent and click-through, and `CharmView` only redraws
        // the region the charm actually sweeps.
        let frame = anchorScreen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        overlay = OverlayWindow(contentRect: frame)

        charmView = CharmView(frame: NSRect(origin: .zero, size: frame.size))
        charmView.autoresizingMask = [.width, .height]
        charmView.charm = preferences.charm
        charmView.charmSize = preferences.charmSize
        charmView.catchesPointer = preferences.catchesPointer
        charmView.onPositionChosen = { [weak self] point in
            self?.finishPositioning(at: point)
        }
        charmView.onAnchorDragged = { [weak self] point, isFinal in
            self?.handleAnchorDrag(to: point, isFinal: isFinal)
        }

        overlay.contentView = charmView
        repositionOverlay()
    }

    /// Resolve the stored placement into a pivot, and park the window over the
    /// screen so view coordinates and screen coordinates line up.
    private func repositionOverlay() {
        guard let overlay, let screen = anchorScreen else { return }

        if overlay.frame != screen.frame {
            overlay.setFrame(screen.frame, display: false)
        }

        let statusAnchor = statusItem.button?.window.map { window in
            CGPoint(x: window.frame.midX, y: window.frame.minY)
        }
        let anchor = PlacementSolver.solve(
            placement: preferences.placement,
            screen: screen.frame,
            statusItemAnchor: statusAnchor,
            defaultCordLength: preferences.cordLength
        )

        charmView.cordLength = anchor.cordLength
        charmView.pivot = CGPoint(
            x: anchor.pivot.x - screen.frame.minX,
            y: anchor.pivot.y - screen.frame.minY
        )
    }

    @objc private func screensChanged() {
        repositionOverlay()
    }

    private func setVisible(_ visible: Bool) {
        preferences.isVisible = visible
        if visible {
            repositionOverlay()
            overlay.orderFrontRegardless()
            charmView.startAnimating()
        } else {
            endPositioning()
            charmView.stopAnimating()
            overlay.orderOut(nil)
        }
        refreshMenu()
    }

    // MARK: - Hotkey

    private func setUpHotKey() {
        // Option-Command-L. Change it here until there is a preferences window.
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: UInt32(optionKey | cmdKey)
        ) { [weak self] in
            self?.dropIn()
        }
    }

    // MARK: - Actions

    @objc private func toggleVisible() {
        setVisible(!preferences.isVisible)
    }

    @objc private func dropIn() {
        if !preferences.isVisible {
            setVisible(true)
            charmView.settle()
        }
        charmView.nudge()
    }

    @objc private func selectCharm(_ sender: NSMenuItem) {
        guard let glyph = sender.representedObject as? String else { return }
        apply(glyph: glyph)
    }

    @objc private func toggleCatchesPointer() {
        preferences.catchesPointer.toggle()
        charmView.catchesPointer = preferences.catchesPointer
        refreshMenu()
    }

    /// Command-dragging the charm moves where it hangs from. The live frames
    /// only move the view; the placement is not written until release.
    private func handleAnchorDrag(to point: CGPoint, isFinal: Bool) {
        guard let screen = anchorScreen else { return }

        let onScreen = CGPoint(x: point.x + screen.frame.minX, y: point.y + screen.frame.minY)
        let placement = PlacementSolver.placement(forCharmAt: onScreen, screen: screen.frame)
        let anchor = PlacementSolver.solve(
            placement: placement,
            screen: screen.frame,
            statusItemAnchor: nil,
            defaultCordLength: preferences.cordLength
        )

        charmView.cordLength = anchor.cordLength
        charmView.pivot = CGPoint(
            x: anchor.pivot.x - screen.frame.minX,
            y: anchor.pivot.y - screen.frame.minY
        )

        if isFinal {
            preferences.placement = placement
            refreshMenu()
        }
    }

    @objc private func selectPlacement(_ sender: NSMenuItem) {
        guard Placement.presets.indices.contains(sender.tag) else { return }
        preferences.placement = Placement.presets[sender.tag].placement
        charmView.settle()
        repositionOverlay()
        refreshMenu()
        dropIn()
    }

    /// Let the whole screen take clicks so the user can point at a spot.
    @objc private func beginPositioning() {
        guard preferences.isVisible else {
            setVisible(true)
            beginPositioning()
            return
        }

        overlay.ignoresMouseEvents = false
        charmView.isPositioning = true
        overlay.orderFrontRegardless()

        positioningTimeout?.invalidate()
        positioningTimeout = Timer.scheduledTimer(
            withTimeInterval: positioningTimeLimit,
            repeats: false
        ) { [weak self] _ in
            self?.endPositioning()
        }
    }

    private func endPositioning() {
        positioningTimeout?.invalidate()
        positioningTimeout = nil
        charmView.isPositioning = false
        overlay.ignoresMouseEvents = true
    }

    private func finishPositioning(at point: CGPoint) {
        guard let screen = anchorScreen else {
            endPositioning()
            return
        }

        let onScreen = CGPoint(x: point.x + screen.frame.minX, y: point.y + screen.frame.minY)
        preferences.placement = PlacementSolver.placement(forCharmAt: onScreen, screen: screen.frame)

        endPositioning()
        charmView.settle()
        repositionOverlay()
        refreshMenu()
        charmView.nudge()
    }

    @objc private func chooseCustomCharm() {
        let alert = NSAlert()
        alert.messageText = "Custom Charm"
        alert.informativeText = "Type or paste any emoji or character to hang on the cord."
        alert.addButton(withTitle: "Use It")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = preferences.charm.glyph
        alert.accessoryView = field

        // The app is an accessory, so it has to ask for the foreground before it
        // can put a dialog in front of anyone.
        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeFirstResponder(field)

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let glyph = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !glyph.isEmpty else { return }
        apply(glyph: String(glyph.prefix(4)))
    }

    private func apply(glyph: String) {
        let charm = Charm.builtIn.first { $0.glyph == glyph } ?? Charm(glyph: glyph, name: "Custom")
        preferences.charm = charm
        charmView.charm = charm
        statusItem.button?.title = charm.glyph
        refreshMenu()
        dropIn()
    }
}
