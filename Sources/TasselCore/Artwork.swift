import Foundation

/// Rules about drawn charm artwork, kept here so they can be checked without a
/// screen and so the drawing template and the code cannot drift apart.
public enum Artwork {
    /// The square the template is drawn on.
    public static let canvas: Double = 1024
    /// How far down the canvas the string ends, as a fraction. The charm hangs
    /// from this point, so it is the one measurement the artwork must respect.
    public static let anchorY: Double = 40.0 / 1024.0
    /// Horizontally centred, always.
    public static let anchorX: Double = 0.5
    /// The full canvas is drawn this many times the charm size tall. Tuned so a
    /// drawn charm reads at about the same weight as an emoji one beside it.
    public static let scale: Double = 1.4

    /// Where the artwork folder lives, relative to the repository root.
    public static let folder = "Resources/Charms"

    /// A name is usable as a file name and as a bundle resource: lowercase
    /// letters, digits and hyphens. Rejecting anything else here means a charm
    /// can never reach for a path outside the bundle.
    public static func isValidName(_ name: String) -> Bool {
        !name.isEmpty
            && name.count <= 64
            && name.allSatisfy { $0.isLowercase && $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
