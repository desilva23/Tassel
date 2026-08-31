import CoreGraphics
import Foundation

/// Something threaded on the rope above the charm.
///
/// A charm on a cord is rarely just a charm on a cord — the real objects carry
/// beads, and often a smaller echo of the charm itself. Positions are fractions
/// of the way down the rope rather than fixed distances, so the threading keeps
/// its spacing while the rope bends and stretches.
public struct Ornament: Equatable, Sendable {
    public enum Shape: Equatable, Sendable {
        /// A small round bead.
        case bead
        /// A smaller copy of whatever charm is on the end.
        case echo
        /// Any character, threaded on like everything else.
        case glyph(String)
    }

    /// How far above the charm this sits, in multiples of the charm's size.
    ///
    /// Measured against the charm rather than fixed as a fraction of the rope,
    /// because a fraction that clears a small charm puts a bead straight behind
    /// a large one — and the charm is resizable.
    public var above: Double
    public var shape: Shape
    /// Bead radius, or the height of an echo, as a fraction of the charm's size.
    public var scale: Double
    /// Turned this much further than the rope's own lean, in radians. Beads are
    /// round and do not care; a chilli threaded across the string does.
    public var rotation: Double

    public init(above: Double, shape: Shape, scale: Double, rotation: Double = 0) {
        self.above = max(above, 0)
        self.shape = shape
        self.scale = scale
        self.rotation = rotation
    }

    /// Where a set sits along the rope, given how big the charm is and how much
    /// rope there is to thread it onto.
    ///
    /// Laid out from the charm upwards, and anything that will not fit is left
    /// off rather than squeezed in. Squeezing keeps the count and ruins the
    /// spacing — on a short rope under a large charm it presses the lowest
    /// ornament inside the charm itself. Threading on fewer looks like a choice;
    /// threading on all of them badly looks like a bug.
    public static func layout(
        _ ornaments: [Ornament],
        charmSize: Double,
        ropeLength: Double
    ) -> [(ornament: Ornament, fraction: Double)] {
        guard ropeLength > 1e-9 else { return [] }
        // Leave the top of the rope clear, so a set never crowds the anchor.
        let allowance = ropeLength * 0.85

        return ornaments.compactMap { ornament in
            let distance = ornament.above * charmSize
            guard distance <= allowance else { return nil }
            return (ornament, (1 - distance / ropeLength).clamped(to: 0...1))
        }
    }

    /// Bead, small charm, bead — the way these things are actually strung,
    /// ordered from the top of the rope down.
    public static let standard: [Ornament] = [
        Ornament(above: 1.30, shape: .bead, scale: 0.10),
        Ornament(above: 0.96, shape: .echo, scale: 0.34),
        Ornament(above: 0.62, shape: .bead, scale: 0.10),
    ]

    /// Chillies threaded across the string above the lemon, pointing left and
    /// right by turns, the way they hang on the real thing.
    ///
    /// The rotations are 0 and half a turn rather than a quarter turn either
    /// way, because the chilli glyph already lies flat, tip to the left. A
    /// quarter turn stands it upright, which is the one thing it must not do.
    public static let nimbuMirchi: [Ornament] = {
        let chilli = "\u{1F336}\u{FE0F}"
        let heights = [2.30, 1.85, 1.40, 0.95, 0.50]
        return heights.enumerated().map { index, above in
            Ornament(
                above: above,
                shape: .glyph(chilli),
                scale: 0.82,
                rotation: index.isMultiple(of: 2) ? 0 : .pi
            )
        }
    }()
}
