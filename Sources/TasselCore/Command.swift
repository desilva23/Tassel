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
    ///
    /// Read out of the raw string rather than `URL.host` and `URL.path`.
    /// Foundation disagrees with itself across versions about where the verb in
    /// the slashless `tassel:bless` form lives — it is the host on one and the
    /// path on another — so `tassel:bless` parsed here and failed on CI. Taking
    /// the text apart directly behaves the same everywhere.
    public init?(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == Self.scheme else { return nil }

        // Everything after `tassel:`, which is the same text in both forms once
        // any leading slashes come off.
        let body = url.absoluteString.dropFirst(scheme.count + 1)
        let verb = body
            .prefix { $0 != "?" && $0 != "#" }
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        switch verb {
        case "bless": self = .bless
        case "ritual": self = .ritual
        case "show": self = .show
        case "hide": self = .hide
        case "charm":
            let query = body.drop { $0 != "?" }.dropFirst()
            guard let name = Self.value(named: "name", in: query),
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            self = .charm(name)
        default:
            return nil
        }
    }

    private static func value(named key: String, in query: Substring) -> String? {
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0].lowercased() == key else { continue }
            let raw = parts[1].replacingOccurrences(of: "+", with: " ")
            return raw.removingPercentEncoding ?? raw
        }
        return nil
    }
}
