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

    public init(glyph: String, name: String) {
        self.glyph = glyph
        self.name = name
    }

    public static let builtIn: [Charm] = [
        Charm(glyph: "\u{1F340}", name: "Four-Leaf Clover"),
        Charm(glyph: "\u{1FA99}", name: "Coin"),
        Charm(glyph: "\u{1F514}", name: "Bell"),
        Charm(glyph: "\u{1F52E}", name: "Crystal Ball"),
        Charm(glyph: "\u{1F9FF}", name: "Nazar"),
        Charm(glyph: "\u{2B50}", name: "Star"),
        Charm(glyph: "\u{1F41A}", name: "Shell"),
        Charm(glyph: "\u{1F344}", name: "Mushroom"),
    ]

    public static let fallback = builtIn[0]
}
