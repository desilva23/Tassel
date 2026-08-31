import AppKit
import ServiceManagement

/// Whether the app starts itself when you log in.
///
/// `SMAppService` registers the app bundle itself, so this only behaves for a
/// bundle living somewhere permanent — registering a copy in a build folder
/// leaves macOS pointing at a path that the next `make clean` deletes.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True when macOS has the request but is waiting on the user to approve it
    /// in System Settings, which it does silently.
    static var awaitingApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// The app has to be somewhere permanent before it is worth registering.
    static var isInstalled: Bool {
        let path = Bundle.main.bundleURL.path
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Error? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error
        }
    }
}
