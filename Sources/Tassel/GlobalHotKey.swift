import AppKit
import Carbon.HIToolbox

/// A system-wide hotkey, registered through Carbon's `RegisterEventHotKey`.
///
/// This deliberately avoids `NSEvent.addGlobalMonitorForEvents`, which would ask
/// the user for Accessibility access. A toy that hangs a charm on your screen has
/// no business requesting permission to observe every keystroke you type.
final class GlobalHotKey {
    private static var handlerInstalled = false
    private static var registry: [UInt32: GlobalHotKey] = [:]
    private static var nextIdentifier: UInt32 = 1

    private let identifier: UInt32
    private let action: () -> Void
    private var reference: EventHotKeyRef?

    /// - Parameters:
    ///   - keyCode: a virtual key code, e.g. `UInt32(kVK_ANSI_L)`.
    ///   - modifiers: Carbon modifier mask, e.g. `UInt32(cmdKey | optionKey)`.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.identifier = Self.nextIdentifier
        Self.nextIdentifier += 1

        Self.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        // The usual reason for failure is another app already owning the
        // combination. Not fatal: the menu item still works.
        guard status == noErr, let ref else { return nil }
        self.reference = ref
        Self.registry[identifier] = self
    }

    deinit {
        if let reference {
            UnregisterEventHotKey(reference)
        }
        Self.registry.removeValue(forKey: identifier)
    }

    private static let signature: OSType = {
        // 'tsel' — a four-character code identifying this app's hotkeys.
        let chars = Array("tsel".utf8)
        return chars.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
    }()

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.signature == GlobalHotKey.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                GlobalHotKey.registry[hotKeyID.id]?.action()
                return noErr
            },
            1,
            &spec,
            nil,
            nil
        )
    }
}
