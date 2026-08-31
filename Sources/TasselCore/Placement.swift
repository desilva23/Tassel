import CoreGraphics
import Foundation

/// Where the charm lives.
///
/// The rope always falls from the top of the screen and always pays out the same
/// length, so a placement only has to say how far *across* the charm sits. How
/// far down it hangs is the rope's business, not the placement's: the drop is
/// what the rope stretches and springs back along, so letting it be repositioned
/// too would leave a stretch and a move impossible to tell apart.
public enum Placement: Equatable, Sendable {
    /// Hang from the menu bar item and follow it as it slides around.
    case followStatusItem
    /// A fraction of the way across the anchor screen. Stored as a fraction so
    /// a resolution or display change keeps the charm roughly where you put it.
    case fixed(x: Double)

    public static let presets: [(name: String, placement: Placement)] = [
        ("Menu Bar", .followStatusItem),
        ("Left", .fixed(x: 0.06)),
        ("Centre", .fixed(x: 0.5)),
        ("Right", .fixed(x: 0.94)),
    ]
}

/// A resolved placement: a point to nail the cord to, and how much cord to pay out.
public struct Anchor: Equatable, Sendable {
    /// Screen coordinates, y pointing up.
    public var pivot: CGPoint
    public var cordLength: Double

    public init(pivot: CGPoint, cordLength: Double) {
        self.pivot = pivot
        self.cordLength = cordLength
    }
}

public enum PlacementSolver {
    /// Never pay out so little cord that the charm sits inside the menu bar.
    public static let minimumCord: Double = 28
    /// Keep the charm off the very bottom edge of the screen.
    public static let bottomInset: Double = 12

    /// Turn a placement into a concrete anchor on `screen`.
    ///
    /// - Parameter statusItemAnchor: the bottom-centre of the menu bar item in
    ///   screen coordinates, when there is one.
    public static func solve(
        placement: Placement,
        screen: CGRect,
        statusItemAnchor: CGPoint?,
        defaultCordLength: Double
    ) -> Anchor {
        let maximumCord = max(minimumCord, screen.height - bottomInset)

        switch placement {
        case .followStatusItem:
            // The menu bar is not always inside the screen rect AppKit reports
            // for it: on some display configurations the status item sits above
            // `maxY`, and anchoring blindly there would hang the cord from a
            // point nobody can see.
            let x = statusItemAnchor?.x ?? screen.midX
            let y = min(statusItemAnchor?.y ?? screen.maxY, screen.maxY)
            return Anchor(
                pivot: CGPoint(x: x.clamped(to: screen.minX...screen.maxX), y: y),
                cordLength: defaultCordLength.clamped(to: minimumCord...maximumCord)
            )

        case let .fixed(x):
            let across = x.clamped(to: 0...1)
            return Anchor(
                pivot: CGPoint(x: screen.minX + across * screen.width, y: screen.maxY),
                cordLength: defaultCordLength.clamped(to: minimumCord...maximumCord)
            )
        }
    }

    /// The placement that would put the charm at `point`. Only the horizontal
    /// part is taken: pointing lower down does not hang the charm lower, it just
    /// picks the column it hangs in.
    public static func placement(forCharmAt point: CGPoint, screen: CGRect) -> Placement {
        guard screen.width > 0 else { return .followStatusItem }
        return .fixed(x: ((point.x - screen.minX) / screen.width).clamped(to: 0...1))
    }
}
