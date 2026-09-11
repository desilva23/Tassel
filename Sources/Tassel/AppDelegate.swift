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
            self.refreshRitualState()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        refreshRitualState()
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
        menu.addItem(sizeMenuItem())
        menu.addItem(positionMenuItem())

        menu.addItem(ritualMenuItem())

        menu.addItem(.separator())

        let beads = NSMenuItem(
            title: "Beads on the Rope",
            action: #selector(toggleOrnaments),
            keyEquivalent: ""
        )
        beads.target = self
        beads.state = preferences.showsOrnaments ? .on : .off
        beads.toolTip = "Thread two beads and a smaller charm onto the rope."
        menu.addItem(beads)

        let grab = NSMenuItem(
            title: "Grab With Pointer",
            action: #selector(toggleCatchesPointer),
            keyEquivalent: ""
        )
        grab.target = self
        grab.state = preferences.catchesPointer ? .on : .off
        grab.toolTip = "Let the charm be pulled about and thrown. Turn off to make it purely decorative."
        menu.addItem(grab)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        if LoginItem.awaitingApproval {
            login.title = "Open at Login (approve in System Settings)"
        } else if !LoginItem.isInstalled {
            // Registering a copy in a build folder points macOS at a path that
            // the next clean deletes, so do not offer it until it is installed.
            login.title = "Open at Login (move to Applications first)"
            login.action = nil
        }
        menu.addItem(login)

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

    /// The current charm's ritual, named for whatever it needs next. Shared by
    /// the menu bar and the right-click menu so the two can never disagree.
    private func ritualMenuItem() -> NSMenuItem {
        let charm = preferences.charm
        let ritual = charm.ritual
        let title: String
        if let stage = ritual.stage(at: preferences.ritualStage(forCharm: charm.glyph)) {
            // A staged ritual offers whatever moves it on from where it is.
            title = stage.action
        } else {
            let due = ritual.isDue(lastPerformed: preferences.lastRitual(forCharm: charm.glyph))
            title = due ? "\(ritual.name)  \u{00B7}  due" : ritual.name
        }
        let item = NSMenuItem(title: title, action: #selector(performRitual), keyEquivalent: "")
        item.target = self
        item.toolTip = ritual.isStaged
            ? "\(ritual.name). It waits for as long as it takes."
            : "The one thing this charm asks of you. It fades if left alone."
        return item
    }

    /// What right-clicking the charm offers: its name, and its ritual.
    private func charmContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(.sectionHeader(title: preferences.charm.name))
        menu.addItem(ritualMenuItem())
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

    private func sizeMenuItem() -> NSMenuItem {
        let submenu = NSMenu()
        for (index, size) in Charm.sizes.enumerated() {
            let item = NSMenuItem(title: size.name, action: #selector(selectSize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = abs(size.points - preferences.charmSize) < 0.5 ? .on : .off
            submenu.addItem(item)
        }

        let item = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
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

        let move = NSMenuItem(title: "Place\u{2026}", action: #selector(beginPositioning), keyEquivalent: "")
        move.toolTip = "Click anywhere on screen to choose the column. You can also just drag the charm."
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
        charmView.showsOrnaments = preferences.showsOrnaments
        charmView.onPositionChosen = { [weak self] point in
            self?.finishPositioning(at: point)
        }
        charmView.contextMenu = { [weak self] in
            self?.charmContextMenu()
        }
        charmView.onAnchorDragged = { [weak self] point, isFinal in
            self?.handleAnchorDrag(to: point, isFinal: isFinal)
        }

        overlay.contentView = charmView
        repositionOverlay(teleport: true)
    }

    /// Resolve the stored placement into a pivot, and park the window over the
    /// screen so view coordinates and screen coordinates line up.
    /// - Parameter teleport: true when the charm is being sent somewhere
    ///   outright — a placement change, a display change — so the rope re-hangs
    ///   at the new spot instead of lashing across the screen to reach it.
    private func repositionOverlay(teleport: Bool = false) {
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
        let point = CGPoint(
            x: anchor.pivot.x - screen.frame.minX,
            y: anchor.pivot.y - screen.frame.minY
        )
        if teleport {
            charmView.jump(to: point)
        } else {
            charmView.pivot = point
        }
    }

    @objc private func screensChanged() {
        repositionOverlay(teleport: true)
    }

    private func setVisible(_ visible: Bool) {
        preferences.isVisible = visible
        if visible {
            repositionOverlay(teleport: true)
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
        }
        charmView.nudge()
    }

    @objc private func selectCharm(_ sender: NSMenuItem) {
        guard let glyph = sender.representedObject as? String else { return }
        apply(glyph: glyph)
    }

    @objc private func selectSize(_ sender: NSMenuItem) {
        guard Charm.sizes.indices.contains(sender.tag) else { return }
        preferences.charmSize = Charm.sizes[sender.tag].points
        charmView.charmSize = preferences.charmSize
        refreshMenu()
        dropIn()
    }

    /// Tend the charm: the fade resets, and it drops in to acknowledge it.
    @objc private func performRitual() {
        let charm = preferences.charm
        if charm.ritual.isStaged {
            let current = preferences.ritualStage(forCharm: charm.glyph)
            preferences.setRitualStage(charm.ritual.stage(after: current), forCharm: charm.glyph)
        }
        preferences.recordRitual(forCharm: charm.glyph)
        refreshRitualState()
        refreshMenu()
        dropIn()
    }

    /// Recompute how faded the charm should look. Cheap, so the anchor poll
    /// carries it rather than running a second timer.
    private func refreshRitualState() {
        let charm = preferences.charm
        charmView.charmOpacity = charm.ritual.opacity(
            lastPerformed: preferences.lastRitual(forCharm: charm.glyph)
        )
        charmView.ritualStage = preferences.ritualStage(forCharm: charm.glyph)
    }

    // MARK: - tassel:// URLs

    /// Anything that can run a shell command can ask for these — a git hook, a
    /// Shortcut, a CI script. Commands arrive from outside the app, so the
    /// parser accepts only the verbs it knows and `charm` only ever resolves to
    /// a built-in name: a URL can never inject arbitrary content into the app.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let command = Command(url: url) else { continue }
            perform(command)
        }
    }

    private func perform(_ command: Command) {
        switch command {
        case .bless:
            if !preferences.isVisible {
                setVisible(true)
            }
            overlay.orderFrontRegardless()
            charmView.nudge()

        case .ritual:
            performRitual()

        case .show:
            setVisible(true)

        case .hide:
            setVisible(false)

        case let .charm(name):
            guard let charm = Charm.named(name) else { return }
            apply(glyph: charm.glyph)
        }
    }

    @objc private func toggleLoginItem() {
        if let error = LoginItem.setEnabled(!LoginItem.isEnabled) {
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change the login item"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        refreshMenu()
    }

    @objc private func toggleOrnaments() {
        preferences.showsOrnaments.toggle()
        charmView.showsOrnaments = preferences.showsOrnaments
        refreshMenu()
    }

    @objc private func toggleCatchesPointer() {
        preferences.catchesPointer.toggle()
        charmView.catchesPointer = preferences.catchesPointer
        charmView.showsOrnaments = preferences.showsOrnaments
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
        repositionOverlay(teleport: true)
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
        repositionOverlay(teleport: true)
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
        refreshRitualState()
        refreshMenu()
        dropIn()
    }
}
