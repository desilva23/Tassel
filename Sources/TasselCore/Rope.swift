import CoreGraphics
import Foundation

/// A flexible rope: a chain of point masses held together by distance
/// constraints, integrated with Verlet.
///
/// The obvious way to hang a charm is a single rigid pendulum, but a pendulum
/// has exactly one degree of freedom — the angle at its pivot — so it can only
/// sweep left and right. It cannot bend, curve, whip, or go slack, because there
/// is nothing in it that is allowed to move independently. A rope needs the
/// chain: every node can move on its own, and the constraints between them are
/// what add up to rope-like motion.
///
/// Verlet suits this well. Velocity is implicit in the gap between a node's
/// current and previous position, so satisfying a constraint by simply *moving*
/// a node updates its velocity for free — which is why letting go of a rope you
/// were swinging throws it correctly without any extra bookkeeping.
public struct Rope: Equatable, Sendable {
    public struct Node: Equatable, Sendable {
        public var position: CGPoint
        /// Where this node was a step ago. Verlet stores velocity as this gap.
        public var previous: CGPoint
        public var isPinned: Bool

        public init(position: CGPoint, previous: CGPoint? = nil, isPinned: Bool = false) {
            self.position = position
            self.previous = previous ?? position
            self.isPinned = isPinned
        }

        /// How far the node moved over the last step.
        public var drift: CGPoint {
            CGPoint(x: position.x - previous.x, y: position.y - previous.y)
        }
    }

    /// A localised shove — the pointer sweeping through the rope.
    public struct Push: Equatable, Sendable {
        public var point: CGPoint
        public var acceleration: CGVector
        public var radius: Double

        public init(point: CGPoint, acceleration: CGVector, radius: Double) {
            self.point = point
            self.acceleration = acceleration
            self.radius = radius
        }
    }

    public private(set) var nodes: [Node]
    public var gravity: Double
    /// Viscous drag, in inverse seconds.
    public var damping: Double
    /// Drag applied *after* the constraints are solved, in inverse seconds.
    ///
    /// In Verlet a constraint is satisfied by moving a node, and moving a node
    /// is velocity — which is what makes throwing and recoil work without extra
    /// bookkeeping. The cost is that a solver which has not fully converged
    /// keeps feeding in a little velocity every step, and ordinary damping never
    /// sees it, because that runs before the solve. Left alone the rope quivers
    /// faintly forever instead of coming to rest.
    public var constraintDamping: Double
    /// How many times the distance constraints are enforced per substep. More
    /// passes make a stiffer rope; too few let it stretch visibly.
    public var relaxationPasses: Int
    /// The charm on the end is heavier than the rope, so it throws its weight
    /// around and the rope trails after it.
    public var endMass: Double
    /// The most a segment may be stretched past its rest length.
    ///
    /// The rope has real give: pull the charm past where the rope reaches and it
    /// stretches to follow, then recoils when let go. This is the ceiling on
    /// that, so a hard enough shove cannot tear the rope apart. Hanging normally
    /// the rope sits well inside it — the give only shows when something is
    /// actively pulling.
    public var maximumStretch: Double

    private var segmentLength: Double

    /// Substeps are capped so a dropped frame or a wake from sleep cannot blow
    /// the constraint solver up.
    private static let maxSubstep = 1.0 / 240.0

    public init(
        anchor: CGPoint,
        length: Double,
        nodeCount: Int = 24,
        gravity: Double = 2000,
        damping: Double = 1.1,
        constraintDamping: Double = 3,
        relaxationPasses: Int = 14,
        endMass: Double = 3,
        maximumStretch: Double = 1.3
    ) {
        let count = max(3, nodeCount)
        let span = max(length, 1)
        self.segmentLength = span / Double(count - 1)
        self.gravity = gravity
        self.damping = damping
        self.constraintDamping = constraintDamping
        self.relaxationPasses = relaxationPasses
        self.endMass = endMass
        self.maximumStretch = max(1, maximumStretch)
        self.nodes = (0..<count).map { index in
            let point = CGPoint(x: anchor.x, y: anchor.y - Double(index) * span / Double(count - 1))
            return Node(position: point, isPinned: index == 0)
        }
    }

    // MARK: - Shape

    /// Total rope length. Changing it re-spaces the segments; the rope takes a
    /// few frames to settle into the new length rather than snapping to it.
    public var length: Double {
        get { segmentLength * Double(nodes.count - 1) }
        set { segmentLength = max(newValue, 1) / Double(nodes.count - 1) }
    }

    public var anchor: CGPoint { nodes[0].position }

    /// Where the charm hangs.
    public var endPoint: CGPoint { nodes[nodes.count - 1].position }

    /// The direction the last segment points, as an angle from straight down.
    /// The charm is rotated by this so it hangs off the rope rather than
    /// floating at the end of it.
    public var endAngle: Double {
        let last = nodes[nodes.count - 1].position
        let previous = nodes[nodes.count - 2].position
        let dx = last.x - previous.x
        let dy = last.y - previous.y
        guard abs(dx) > 1e-9 || abs(dy) > 1e-9 else { return 0 }
        return atan2(dx, -dy)
    }

    public var isAtRest: Bool {
        nodes.allSatisfy { hypot($0.drift.x, $0.drift.y) < 0.01 }
    }

    // MARK: - Anchor

    /// Move the top of the rope and let the rest feel the yank.
    public mutating func moveAnchor(to point: CGPoint) {
        nodes[0].previous = nodes[0].position
        nodes[0].position = point
    }

    /// Move the top of the rope and re-hang it straight, with no motion. For a
    /// teleport — a placement change, a display change — where a whip would be
    /// an artefact rather than an effect.
    public mutating func placeAnchor(at point: CGPoint) {
        nodes[0].position = point
        nodes[0].previous = point
        settle()
    }

    /// Hang the rope straight down from its anchor, motionless.
    public mutating func settle() {
        let top = nodes[0].position
        for index in nodes.indices {
            let point = CGPoint(x: top.x, y: top.y - Double(index) * segmentLength)
            nodes[index].position = point
            nodes[index].previous = point
        }
    }

    // MARK: - Grabbing

    /// Hold the charm at a point, as when it is dragged. Verlet turns the
    /// motion of the held node into velocity on its own, so releasing mid-drag
    /// throws the rope without any extra work.
    public mutating func holdEnd(at point: CGPoint) {
        let last = nodes.count - 1
        nodes[last].previous = nodes[last].position
        // The charm hangs: it can be pulled down and aside but never lifted
        // above the point it hangs from, which would fold the rope over itself.
        let below = CGPoint(x: point.x, y: min(point.y, nodes[0].position.y))
        // Dragging past where the rope reaches stretches it rather than
        // teleporting the charm, but only so far — past the limit the pointer
        // pulls away and the charm stays behind, as it would on a real cord.
        nodes[last].position = clampedToReach(below)
        nodes[last].isPinned = true
    }

    /// The nearest point to `point` that the charm can actually get to.
    private func clampedToReach(_ point: CGPoint) -> CGPoint {
        let top = nodes[0].position
        let dx = point.x - top.x
        let dy = point.y - top.y
        let distance = hypot(dx, dy)
        let reach = length * maximumStretch
        guard distance > reach, distance > 1e-9 else { return point }
        return CGPoint(x: top.x + dx / distance * reach, y: top.y + dy / distance * reach)
    }

    public mutating func releaseEnd() {
        nodes[nodes.count - 1].isPinned = false
    }

    /// Kick the lower half of the rope, for the drop-in flourish.
    public mutating func nudge(_ impulse: CGVector) {
        for index in nodes.indices where !nodes[index].isPinned {
            // Weight it toward the free end, so the rope whips rather than
            // sliding sideways in one piece.
            let share = Double(index) / Double(nodes.count - 1)
            nodes[index].previous.x -= impulse.dx * share
            nodes[index].previous.y -= impulse.dy * share
        }
    }

    // MARK: - Simulation

    public mutating func step(dt: Double, wind: CGVector = CGVector(dx: 0, dy: 0), push: Push? = nil) {
        guard dt > 0, dt.isFinite else { return }

        // A long dt (app asleep, debugger paused) is clamped rather than
        // simulated: catching up honestly would just look like an explosion.
        let total = min(dt, 0.1)
        let count = max(1, Int((total / Self.maxSubstep).rounded(.up)))
        let h = total / Double(count)

        for _ in 0..<count {
            integrate(h: h, wind: wind, push: push)
            for pass in 0..<relaxationPasses {
                // Alternate the sweep direction. A single-direction sweep
                // carries tension only one node per pass, so on a long rope the
                // far end never learns it is being pulled and the rope bows
                // instead of going taut. Alternating propagates from both ends.
                relax(reversed: pass % 2 == 1)
            }
            if !nodes[nodes.count - 1].isPinned {
                enforceMaximumStretch()
            }
            settleConstraintNoise(h: h)
        }
    }

    private mutating func integrate(h: Double, wind: CGVector, push: Push?) {
        let retention = exp(-damping * h)

        for index in nodes.indices where !nodes[index].isPinned {
            var ax = wind.dx
            var ay = wind.dy - gravity

            if let push, push.radius > 0 {
                let dx = nodes[index].position.x - push.point.x
                let dy = nodes[index].position.y - push.point.y
                let distance = hypot(dx, dy)
                if distance < push.radius {
                    let falloff = 1 - distance / push.radius
                    ax += push.acceleration.dx * falloff
                    ay += push.acceleration.dy * falloff
                }
            }

            let drift = nodes[index].drift
            nodes[index].previous = nodes[index].position
            nodes[index].position.x += drift.x * retention + ax * h * h
            nodes[index].position.y += drift.y * retention + ay * h * h
        }
    }

    /// Pull each pair of neighbours back to the rest length. Repeated passes
    /// converge on a rope that holds its length while still bending freely.
    private mutating func relax(reversed: Bool) {
        let order = reversed
            ? Array((0..<(nodes.count - 1)).reversed())
            : Array(0..<(nodes.count - 1))

        for index in order {
            let upper = index
            let lower = index + 1

            let upperFree = !nodes[upper].isPinned
            let lowerFree = !nodes[lower].isPinned
            guard upperFree || lowerFree else { continue }

            let dx = nodes[lower].position.x - nodes[upper].position.x
            let dy = nodes[lower].position.y - nodes[upper].position.y
            let distance = max(hypot(dx, dy), 1e-9)
            let correction = (distance - segmentLength) / distance

            let upperMass = mass(at: upper)
            let lowerMass = mass(at: lower)
            var upperShare = upperFree ? lowerMass / (upperMass + lowerMass) : 0
            var lowerShare = lowerFree ? upperMass / (upperMass + lowerMass) : 0
            // When one end is pinned the other has to take up all the slack.
            if !lowerFree { upperShare = 1 }
            if !upperFree { lowerShare = 1 }

            nodes[upper].position.x += dx * correction * upperShare
            nodes[upper].position.y += dy * correction * upperShare
            nodes[lower].position.x -= dx * correction * lowerShare
            nodes[lower].position.y -= dy * correction * lowerShare
        }
    }

    /// Walk down from the anchor pulling in any segment that has been stretched
    /// past the limit. Going top-down from a fixed anchor means one pass is
    /// enough: each node is corrected only after the one above it has settled.
    private mutating func enforceMaximumStretch() {
        let limit = segmentLength * maximumStretch
        for index in 0..<(nodes.count - 1) {
            let lower = index + 1
            guard !nodes[lower].isPinned else { continue }

            let dx = nodes[lower].position.x - nodes[index].position.x
            let dy = nodes[lower].position.y - nodes[index].position.y
            let distance = hypot(dx, dy)
            guard distance > limit, distance > 1e-9 else { continue }

            let scale = limit / distance
            nodes[lower].position = CGPoint(
                x: nodes[index].position.x + dx * scale,
                y: nodes[index].position.y + dy * scale
            )
        }
    }

    /// Bleed off the velocity the constraint solve just introduced.
    private mutating func settleConstraintNoise(h: Double) {
        guard constraintDamping > 0 else { return }
        let retention = exp(-constraintDamping * h)
        for index in nodes.indices where !nodes[index].isPinned {
            let drift = nodes[index].drift
            nodes[index].previous = CGPoint(
                x: nodes[index].position.x - drift.x * retention,
                y: nodes[index].position.y - drift.y * retention
            )
        }
    }

    private func mass(at index: Int) -> Double {
        index == nodes.count - 1 ? endMass : 1
    }
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
