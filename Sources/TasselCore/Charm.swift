import Foundation

/// A thing that hangs on the end of the cord.
///
/// Charms are plain Unicode text drawn with the system emoji font. Nothing here
/// ships anyone else's artwork — if you swap in drawn assets later, keep them
/// original or public domain and note their provenance in ASSETS.md.
public struct Charm: Equatable, Identifiable, Sendable {
    public var id: String { glyph }
    public let glyph: String
    public let name: String
    /// What is threaded on the rope above this charm.
    public let threading: [Ornament]
    /// The one small thing this charm can have done to it.
    public let ritual: Ritual

    public init(
        glyph: String,
        name: String,
        ritual: Ritual = .generic,
        threading: [Ornament] = Ornament.standard
    ) {
        self.glyph = glyph
        self.name = name
        self.ritual = ritual
        self.threading = threading
    }

    /// Each ritual is the upkeep its own object actually asks for, rather than a
    /// generic "refresh". That is the whole point of having them.
    public static let builtIn: [Charm] = [
        Charm(
            glyph: "\u{1F340}", name: "Four-Leaf Clover",
            ritual: Ritual(name: "Press a New One", days: 14)
        ),
        Charm(
            glyph: "\u{1FA99}", name: "Lucky Coin",
            ritual: Ritual(name: "Re-tie the Red Thread", days: 21)
        ),
        Charm(
            glyph: "\u{1F514}", name: "Bell",
            ritual: Ritual(name: "Ring It", days: 3)
        ),
        Charm(
            glyph: "\u{1F52E}", name: "Crystal Ball",
            ritual: Ritual(name: "Wipe It Clear", days: 7)
        ),
        Charm(
            glyph: "\u{1F9FF}", name: "Nazar",
            ritual: Ritual(name: "Turn Back the Eye", days: 10)
        ),
        Charm(
            glyph: "\u{1FAAC}", name: "Hamsa",
            ritual: Ritual(name: "Turn the Palm Outward", days: 12)
        ),
        Charm(
            glyph: "\u{1F409}", name: "Dragon",
            ritual: Ritual(name: "Wake the Dragon", days: 12)
        ),
        Charm(
            glyph: "\u{2B50}", name: "Star",
            ritual: Ritual(name: "Wish On It", days: 7)
        ),
        Charm(
            glyph: "\u{1F41A}", name: "Shell",
            ritual: Ritual(name: "Hold It to Your Ear", days: 10)
        ),
        Charm(
            glyph: "\u{1F344}", name: "Mushroom",
            ritual: Ritual(name: "Find Another", days: 14)
        ),
        // A lemon under a row of chillies, hung over a doorway to turn away bad
        // luck. It is taken down and replaced when it dries out, traditionally
        // on a Saturday — so a week is not an arbitrary number here.
        Charm(
            glyph: "\u{1F34B}", name: "Nimbu Mirchi",
            ritual: Ritual(name: "Hang a Fresh One", days: 7),
            threading: Ornament.nimbuMirchi
        ),
    ]

    /// Look one up by name, for `tassel://charm?name=...`.
    public static func named(_ name: String) -> Charm? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return builtIn.first { $0.name.lowercased() == wanted }
    }

    public static let fallback = builtIn[0]

    /// Offered sizes, in points. A charm is decoration: how big it should be is
    /// a matter of taste, not something to be guessed on the user's behalf.
    public static let sizes: [(name: String, points: Double)] = [
        ("Small", 28),
        ("Medium", 44),
        ("Large", 62),
        ("Extra Large", 84),
    ]
}
