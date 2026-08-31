import Foundation

/// Something the app can be asked to do from outside itself.
///
/// Reachable over a `tassel://` URL, which means anything that can run a shell
/// command can ask for it — a git hook, a Shortcut, a CI script, a cron job.
/// No integration, no API, no daemon: one line of `open`.
public enum Command: Equatable, Sendable {
    /// Bring the charm forward and set it swinging, for a moment worth marking.
    case bless
    /// Perform the current charm's ritual.
    case ritual
    case show
    case hide
    /// Switch to a charm by name, matched case-insensitively.
    case charm(String)

    public static let scheme = "tassel"

    /// Parse a `tassel://` URL. Returns nil for anything else, so a malformed
    /// or hostile URL is ignored rather than guessed at.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        // `tassel://bless` puts the verb in the host; `tassel:bless` puts it in
        // the path. Both are things people will type, so accept both.
        let verb = (url.host ?? url.path)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        switch verb {
        case "bless": self = .bless
        case "ritual": self = .ritual
        case "show": self = .show
        case "hide": self = .hide
        case "charm":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let name = components?.queryItems?.first { $0.name.lowercased() == "name" }?.value
            guard let name, !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            self = .charm(name)
        default:
            return nil
        }
    }
}
