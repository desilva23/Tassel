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
    /// Base name of a drawn PNG in `Resources/Charms`, without the extension.
    ///
    /// When there is one it is used everywhere the charm is shown — on the rope,
    /// in the menu bar, in the Charm menu. The `glyph` is what gets drawn in its
    /// place if the file turns out to be missing: a charm should never fail to
    /// appear because an artwork file was renamed.
    public let artwork: String?
    /// The colour of the beads threaded above it: picked to stand out against
    /// the charm rather than match it, so the beads read as beads and not as
    /// pieces of the charm. Nil keeps plain bone.
    public let beadColor: RGB?

    public init(
        glyph: String,
        name: String,
        ritual: Ritual = .generic,
        artwork: String? = nil,
        beadColor: RGB? = nil,
        threading: [Ornament] = Ornament.standard
    ) {
        self.glyph = glyph
        self.name = name
        self.ritual = ritual
        self.artwork = artwork
        self.beadColor = beadColor
        self.threading = threading
    }

    /// Each ritual is the upkeep its own object actually asks for, rather than a
    /// generic "refresh". That is the whole point of having them.
    ///
    /// Bead colours are picked against each charm's main colour — its opposite,
    /// or a colour the real object is strung with — and kept mid-toned, so they
    /// show on a light desktop and a dark one alike.
    public static let builtIn: [Charm] = [
        Charm(
            glyph: "\u{1F340}", name: "Four-Leaf Clover",
            ritual: Ritual(name: "Press a New One", days: 14),
            beadColor: RGB(0xD6457E)   // rose, against green
        ),
        // Drawn by hand: a Yongzheng Tongbao (1723-1735), round with a square
        // hole, hung by the red thread its ritual is about. Read top, bottom,
        // right, left — 雍正通寶 — so 通 is on the right and 寶 on the left.
        // Feng shui replicas often have those two swapped; this one does not.
        Charm(
            glyph: "\u{1FA99}", name: "Yansheng",
            ritual: Ritual(name: "Re-tie the Red Thread", days: 21),
            artwork: "yansheng",
            beadColor: RGB(0xC8202F)   // the red thread, against bronze
        ),
        Charm(
            glyph: "\u{1F514}", name: "Bell",
            ritual: Ritual(name: "Ring It", days: 3),
            beadColor: RGB(0x3E6FD1)   // blue, against gold
        ),
        Charm(
            glyph: "\u{1F9FF}", name: "Nazar",
            ritual: Ritual(name: "Turn Back the Eye", days: 10)
            // Bone beads, by choice: white already rings the eye.
        ),
        // Drawn by hand, because a daruma is not in the emoji font. Bought
        // blank; one eye is painted when a wish is made, the other when it
        // comes true, and then it is retired and a new one begun. The one-eyed
        // stage is made from the other two, so the three always line up.
        Charm(
            glyph: "\u{1F3EE}", name: "Daruma",
            ritual: Ritual(name: "Paint an Eye", stages: [
                RitualStage(action: "Make a Wish", artwork: "daruma-blank"),
                RitualStage(action: "My Wish Came True", artwork: "daruma-one-eye"),
                RitualStage(action: "Start a New Wish", artwork: "daruma"),
            ]),
            artwork: "daruma",
            beadColor: RGB(0xE8B53A)   // gold, against red
        ),
        // Drawn by hand. The beckoning cat raises its right paw, which invites
        // money, and holds a koban reading 千万両 — ten million ryō. Its gold is
        // kept bright by polishing, so that is what it asks for.
        Charm(
            glyph: "\u{1F431}", name: "Maneki Neko",
            ritual: Ritual(name: "Polish the Koban", days: 9),
            artwork: "maneki-neko",
            beadColor: RGB(0xD7261E)   // collar red, against a white cat
        ),
        // Drawn by hand: a Ukrainian decorated egg, with the wheat, birds,
        // stars and flowers pysanky are covered in. A pysanka is "written"
        // (pysaty, to write), kept in the home the year round and a new one
        // written each Easter — so its ritual comes round once a year.
        Charm(
            glyph: "\u{1F95A}", name: "Pysanka",
            ritual: Ritual(name: "Write a New One", days: 365),
            artwork: "pysanka",
            beadColor: RGB(0xF5C21B)   // sunflower, against a blue egg
        ),
    ]

    /// The artwork to show at a given ritual stage. A staged ritual supplies
    /// its own; otherwise it is the charm's usual artwork.
    public func artwork(atStage stage: Int) -> String? {
        ritual.stage(at: stage)?.artwork ?? artwork
    }

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
