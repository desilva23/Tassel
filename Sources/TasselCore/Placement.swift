import CoreGraphics
import Foundation

/// Where the charm lives.
///
/// The cord always falls from the top of the screen, so a placement only has to
/// say how far across and how far down the charm itself should rest.
public enum Placement: Equatable, Sendable {
    /// Hang from the menu bar item and follow it as it slides around.
    case followStatusItem
    /// Fractions of the anchor screen: `x` across from the left, `drop` down
    /// from the top edge. Stored as fractions so a resolution or display change
    /// keeps the charm roughly where you put it.
    case fixed(x: Double, drop: Double)

    public static let presets: [(name: String, placement: Placement)] = [
        ("Menu Bar", .followStatusItem),
        ("Top Left", .fixed(x: 0.05, drop: 0.16)),
        ("Top Right", .fixed(x: 0.95, drop: 0.16)),
        ("Bottom Left", .fixed(x: 0.05, drop: 0.86)),
        ("Bottom Right", .fixed(x: 0.95, drop: 0.86)),
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

        case let .fixed(x, drop):
            let across = x.clamped(to: 0...1)
            let down = drop.clamped(to: 0...1)
            return Anchor(
                pivot: CGPoint(x: screen.minX + across * screen.width, y: screen.maxY),
                cordLength: (down * screen.height).clamped(to: minimumCord...maximumCord)
            )
        }
    }

    /// The placement that would rest the charm at `point`, for drag-to-position.
    public static func placement(forCharmAt point: CGPoint, screen: CGRect) -> Placement {
        guard screen.width > 0, screen.height > 0 else { return .followStatusItem }
        let across = (point.x - screen.minX) / screen.width
        let down = (screen.maxY - point.y) / screen.height
        return .fixed(x: across.clamped(to: 0...1), drop: down.clamped(to: 0...1))
    }
}
