import Foundation

/// Rules about drawn charm artwork, kept here so they can be checked without a
/// screen and so the drawing template and the code cannot drift apart.
public enum Artwork {
    /// The square the template is drawn on.
    public static let canvas: Double = 1024
    /// Where the template marks the anchor, as fractions of the canvas: 40px
    /// down, centred across. A guide for drawing, not a rule — the app hangs a
    /// charm from wherever the top of its drawing turns out to be.
    public static let anchorY: Double = 40.0 / 1024.0
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

    /// How deep a sliver off the top of a drawing is taken as what it hangs
    /// by, as a fraction of the drawing's height: enough to span the top of a
    /// loop, not so much that it reaches the ears or shoulders below one.
    public static let hookBand: Double = 0.03

    /// Where a drawing sits on its image, found from which pixels are drawn.
    ///
    /// - Parameters:
    ///   - step: sample every this many pixels each way. A few thousand samples
    ///     place an edge closely enough; a million would only be slower.
    ///   - isDrawn: whether the pixel at (x, y), counting y down from the top,
    ///     is part of the drawing.
    /// - Returns: the drawn part, in unit coordinates of the image, y up; and
    ///   how far across the image the drawing's top is, which is where the rope
    ///   meets it. That is the middle of its loop, and not the middle of the
    ///   drawing whenever something — a raised paw — sticks out to one side.
    public static func measure(
        width: Int,
        height: Int,
        step: Int,
        isDrawn: (Int, Int) -> Bool
    ) -> (content: CGRect, hookX: Double) {
        let whole = (content: CGRect(x: 0, y: 0, width: 1, height: 1), hookX: 0.5)
        guard width > 0, height > 0 else { return whole }
        let step = max(1, step)

        // The drawn span of each sampled row that has any, top row first.
        var rows: [(y: Int, minX: Int, maxX: Int)] = []
        for y in stride(from: 0, to: height, by: step) {
            var low = Int.max, high = Int.min
            for x in stride(from: 0, to: width, by: step) where isDrawn(x, y) {
                low = min(low, x)
                high = max(high, x)
            }
            if low <= high { rows.append((y, low, high)) }
        }
        guard let top = rows.first, let bottom = rows.last else { return whole }

        let w = Double(width), h = Double(height)
        let minX = rows.map(\.minX).min()!, maxX = rows.map(\.maxX).max()!
        let content = CGRect(
            x: Double(minX) / w,
            y: 1 - Double(bottom.y + step) / h,
            width: Double(maxX + step - minX) / w,
            height: Double(bottom.y + step - top.y) / h
        )

        let depth = max(step, Int(hookBand * Double(bottom.y + step - top.y)))
        let sliver = rows.prefix { $0.y < top.y + depth }
        let low = sliver.map(\.minX).min()!, high = sliver.map(\.maxX).max()!
        return (content, Double(low + high + step) / 2 / w)
    }

    /// Where to draw artwork so its drawn part lands correctly on the rope.
    ///
    /// - Parameters:
    ///   - content: the opaque part of the image, in unit coordinates of the
    ///     image, y up. A charm using the whole canvas gives (0, 0, 1, 1).
    ///   - hookX: how far across the image the drawing hangs from, as `measure`
    ///     finds it. The rope's line runs through this.
    ///   - aspect: the image's width divided by its height.
    ///   - hanging: true for the charm on the end of the rope, which hangs by
    ///     the top of its drawing; false for one threaded onto the rope, which
    ///     sits centred on it.
    /// - Returns: the rectangle to draw the whole image into, relative to the
    ///   point on the rope.
    public static func drawRect(
        content: CGRect,
        hookX: Double,
        aspect: Double,
        charmSize: Double,
        hanging: Bool
    ) -> CGRect {
        // Guard a fully transparent image, which would divide by zero.
        let contentHeight = content.height > 0.001 ? content.height : 1
        let height = charmSize * scale / contentHeight
        let width = height * (aspect > 0 ? aspect : 1)

        // Line the drawing up with the rope: its top for a hanging charm, its
        // middle for a threaded one, and across, the point it hangs from.
        let anchorInContent = hanging ? content.maxY : content.midY
        return CGRect(
            x: -hookX * width,
            y: -anchorInContent * height,
            width: width,
            height: height
        )
    }

    /// The drawn part of the artwork, in the charm's own frame — where the rope
    /// meets it is the origin and "down" is the rope's direction. This is what a
    /// click has to land in, rather than a circle round the end of the rope,
    /// which misses most of anything that hangs below it.
    public static func contentBox(
        content: CGRect,
        hookX: Double,
        aspect: Double,
        charmSize: Double,
        hanging: Bool
    ) -> CGRect {
        let rect = drawRect(content: content, hookX: hookX, aspect: aspect, charmSize: charmSize, hanging: hanging)
        return CGRect(
            x: rect.minX + content.minX * rect.width,
            y: rect.minY + content.minY * rect.height,
            width: content.width * rect.width,
            height: content.height * rect.height
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
