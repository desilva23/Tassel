import CoreGraphics
import Foundation

/// A damped pendulum hanging from a pivot that is allowed to move.
///
/// Angles are radians measured from straight down, positive to the right.
/// Positions are in screen points with y pointing up, so the bob sits at
/// `length * (sin(angle), -cos(angle))` relative to the pivot.
public struct Pendulum: Equatable, Sendable {
    /// Distance from the pivot to the bob, in points.
    public var length: Double
    /// Downward acceleration, in points per second squared.
    public var gravity: Double
    /// Viscous drag on angular velocity, in inverse seconds.
    public var damping: Double

    public private(set) var angle: Double
    public private(set) var angularVelocity: Double

    /// Integration substeps never exceed this, which keeps a dropped frame or a
    /// wakeup from sleep from flinging the bob into orbit.
    private static let maxSubstep = 1.0 / 240.0

    public init(
        length: Double = 92,
        gravity: Double = 2600,
        damping: Double = 1.6,
        angle: Double = 0,
        angularVelocity: Double = 0
    ) {
        self.length = length
        self.gravity = gravity
        self.damping = damping
        self.angle = angle
        self.angularVelocity = angularVelocity
    }

    /// Advance the simulation by `dt` seconds.
    ///
    /// `pivotAcceleration` is the pivot's own acceleration in points per second
    /// squared. In the pivot's frame it shows up as a pseudo-force, which is what
    /// makes the charm lag behind when the anchor is yanked sideways.
    /// - Parameter bobAcceleration: a force applied directly at the charm, in
    ///   points per second squared — the pointer batting it around, say. Only
    ///   the component along the swing does anything; the cord eats the rest.
    public mutating func step(
        dt: Double,
        pivotAcceleration: CGVector = CGVector(dx: 0, dy: 0),
        bobAcceleration: CGVector = CGVector(dx: 0, dy: 0)
    ) {
        guard dt > 0, dt.isFinite else { return }

        // A long dt (app was asleep, debugger paused) is clamped rather than
        // simulated: catching up honestly would just look like an explosion.
        let total = min(dt, 0.1)
        let steps = max(1, Int((total / Self.maxSubstep).rounded(.up)))
        let h = total / Double(steps)

        for _ in 0..<steps {
            let restoring = -(gravity / length) * sin(angle)
            let driven = -(pivotAcceleration.dx * cos(angle) + pivotAcceleration.dy * sin(angle)) / length
            let pushed = (bobAcceleration.dx * cos(angle) + bobAcceleration.dy * sin(angle)) / length
            let drag = -damping * angularVelocity

            // Semi-implicit Euler: velocity first, then position. Cheap, and it
            // does not pump energy into the system the way explicit Euler does.
            angularVelocity += (restoring + driven + pushed + drag) * h
            angle += angularVelocity * h
        }

        // Keep the charm hanging rather than doing loops if something goes wild.
        angle = angle.clamped(to: -Double.pi / 2 ... Double.pi / 2)
        angularVelocity = angularVelocity.clamped(to: -40 ... 40)
    }

    /// Drive the pendulum directly, as when the charm is dragged by hand.
    ///
    /// `offset` is where the bob should be, relative to the pivot. The velocity
    /// this implies is kept, so letting go throws the charm rather than dropping
    /// it dead — smoothed, because a jittery pointer would otherwise fling it.
    public mutating func hold(towards offset: CGPoint, dt: Double) {
        let target = atan2(offset.x, -offset.y).clamped(to: -Double.pi / 2 ... Double.pi / 2)
        guard dt > 0, dt.isFinite else {
            angle = target
            return
        }
        let implied = (target - angle) / dt
        angularVelocity = (angularVelocity * 0.6 + implied * 0.4).clamped(to: -40 ... 40)
        angle = target
    }

    /// Give the bob a shove, in radians per second.
    public mutating func nudge(angularVelocity delta: Double) {
        angularVelocity = (angularVelocity + delta).clamped(to: -40 ... 40)
    }

    /// Drop the bob back to rest immediately.
    public mutating func reset() {
        angle = 0
        angularVelocity = 0
    }

    /// Offset of the bob from the pivot, y negative because it hangs below.
    public var bobOffset: CGPoint {
        CGPoint(x: length * sin(angle), y: -length * cos(angle))
    }

    /// True once the swing is small enough that redrawing is a waste of power.
    public var isAtRest: Bool {
        abs(angle) < 0.001 && abs(angularVelocity) < 0.001
    }
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
