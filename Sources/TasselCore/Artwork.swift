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
    /// The drawn part of the artwork — ignoring empty margin — is this many
    /// times the charm size tall. Tuned so a drawn charm reads at about the same
    /// weight as an emoji one beside it.
    ///
    /// Measured against the drawing rather than the canvas so that two charms
    /// drawn at different sizes on the page still hang at the same size, and so
    /// that a charm drawn slightly small does not hang from a length of bare
    /// rope where its margin is.
    public static let scale: Double = 1.2

    /// Where to draw artwork so its drawn part lands correctly on the rope.
    ///
    /// - Parameters:
    ///   - content: the opaque part of the image, in unit coordinates of the
    ///     image, y up. A charm using the whole canvas gives (0, 0, 1, 1).
    ///   - aspect: the image's width divided by its height.
    ///   - hanging: true for the charm on the end of the rope, which hangs by
    ///     the top of its drawing; false for one threaded onto the rope, which
    ///     sits centred on it.
    /// - Returns: the rectangle to draw the whole image into, relative to the
    ///   point on the rope.
    public static func drawRect(
        content: CGRect,
        aspect: Double,
        charmSize: Double,
        hanging: Bool
    ) -> CGRect {
        // Guard a fully transparent image, which would divide by zero.
        let contentHeight = content.height > 0.001 ? content.height : 1
        let height = charmSize * scale / contentHeight
        let width = height * (aspect > 0 ? aspect : 1)

        // Line the drawing up with the rope: its top for a hanging charm, its
        // middle for a threaded one, and its centre horizontally either way.
        let anchorInContent = hanging ? content.maxY : content.midY
        return CGRect(
            x: -content.midX * width,
            y: -anchorInContent * height,
            width: width,
            height: height
        )
    }

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
