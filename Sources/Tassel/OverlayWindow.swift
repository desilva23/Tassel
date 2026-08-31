import AppKit

/// The transparent window the charm is drawn into.
///
/// It floats above ordinary windows, follows you between Spaces, and passes every
/// click straight through to whatever is underneath, so it can never get in the
/// way of the work it is decorating.
final class OverlayWindow: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        // Sit just under the menu bar's own level: visible over regular windows
        // without covering menus the user has pulled down.
        level = .statusBar - 1

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary,
        ]
    }

    // A borderless panel refuses key status by default, which is what we want:
    // the charm should never steal focus from the app you are typing in.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
