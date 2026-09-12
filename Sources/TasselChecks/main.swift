import CoreGraphics
import Foundation
import ImageIO
import TasselCore

/// Distance from `point` to the straight line through `a` and `b`. This is the
/// measure of "is it bending": a rigid pendulum keeps every point on that line.
func deviation(of point: CGPoint, fromLineThrough a: CGPoint, and b: CGPoint) -> Double {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let span = hypot(dx, dy)
    guard span > 1e-9 else { return hypot(point.x - a.x, point.y - a.y) }
    return abs(dy * (point.x - a.x) - dx * (point.y - a.y)) / span
}

/// The largest sideways departure of any node from the straight line between
/// the rope's two ends.
func maximumBend(of rope: Rope) -> Double {
    rope.nodes.map { deviation(of: $0.position, fromLineThrough: rope.anchor, and: rope.endPoint) }.max() ?? 0
}

/// How far the rope has stretched beyond its rest length, as a fraction.
func stretch(of rope: Rope) -> Double {
    var measured = 0.0
    for index in 0..<(rope.nodes.count - 1) {
        let a = rope.nodes[index].position
        let b = rope.nodes[index + 1].position
        measured += hypot(b.x - a.x, b.y - a.y)
    }
    return measured / rope.length - 1
}

func makeRope(length: Double = 300) -> Rope {
    var rope = Rope(anchor: CGPoint(x: 0, y: 0), length: length)
    rope.settle()
    return rope
}

// A rope left alone hangs straight down and stays there.
Expect.suite("a settled rope hangs still") {
    var rope = makeRope()
    for _ in 0..<600 {
        rope.step(dt: 1.0 / 60)
    }
    Expect.near(rope.endPoint.x, 0, 0.5, "the charm drifted sideways on its own")
    // The rope has a little give, so it hangs a hair longer than its rest
    // length under the charm's own weight. A fraction of a percent, invisible.
    Expect.near(rope.endPoint.y, -300, 2.0, "the charm should hang a full rope below the anchor")
    Expect.that(rope.isAtRest, "a rope left alone should report itself at rest")
    Expect.near(maximumBend(of: rope), 0, 0.5, "a rope at rest should be straight")
}

// The point of the whole rewrite: pushed in the middle, it has to *bend*, not
// just swing. A rigid pendulum keeps every point on the line between its ends,
// so it scores zero here no matter how hard it is pushed.
Expect.suite("a push in the middle bends the rope") {
    var rope = makeRope()
    let middle = rope.nodes[rope.nodes.count / 2].position
    let push = Rope.Push(
        point: middle,
        acceleration: CGVector(dx: 9000, dy: 0),
        radius: 90
    )
    for _ in 0..<12 {
        rope.step(dt: 1.0 / 120, push: push)
    }
    Expect.that(maximumBend(of: rope) > 10, "the rope stayed straight under a sideways push — it is not bending")
}

// A rope shoved at the bottom curves too, rather than pivoting rigidly.
Expect.suite("the rope curves when its end is thrown") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 520, dy: 0))
    var peak = 0.0
    for _ in 0..<90 {
        rope.step(dt: 1.0 / 120)
        peak = max(peak, maximumBend(of: rope))
    }
    Expect.that(peak > 4, "a thrown rope should curve on the way, not stay a rigid line")
}

// Under everyday forces — the pointer sweeping through it — the rope should
// barely give at all.
Expect.suite("the rope holds its length under ordinary force") {
    var rope = makeRope()
    let push = Rope.Push(point: rope.endPoint, acceleration: CGVector(dx: 6500, dy: 0), radius: 80)
    var worst = 0.0
    for _ in 0..<240 {
        rope.step(dt: 1.0 / 120, push: push)
        worst = max(worst, abs(stretch(of: rope)))
    }
    Expect.that(worst < 0.03, "a pointer sweep stretched the rope by \(Int(worst * 100))%")
}

// Pull the charm past where the rope reaches and the rope stretches to follow.
Expect.suite("dragging past the end stretches the rope") {
    var rope = makeRope()
    rope.holdEnd(at: CGPoint(x: 0, y: -360))
    for _ in 0..<30 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(stretch(of: rope) > 0.1, "dragging well past the rope's reach barely stretched it")
    Expect.near(rope.endPoint.y, -360, 1.0, "the charm should have followed the pointer down")
}

// ...but only so far. Past the limit the pointer pulls away from the charm.
Expect.suite("the rope cannot be stretched without limit") {
    var rope = makeRope()
    rope.holdEnd(at: CGPoint(x: 0, y: -5000))
    for _ in 0..<60 {
        rope.step(dt: 1.0 / 120)
    }
    // Arc length, so it reads a little over the straight-line stretch limit.
    Expect.that(stretch(of: rope) < 0.9, "the rope tore apart when dragged far enough: \(Int(stretch(of: rope) * 100))%")
    let reach = hypot(rope.endPoint.x - rope.anchor.x, rope.endPoint.y - rope.anchor.y)
    Expect.that(reach <= rope.length * 1.71, "the charm was let past the rope's stretch limit")
    Expect.that(rope.endPoint.y > -560, "the charm should have stayed behind the pointer")
}

// Letting go of a stretched rope snaps it back, and the recoil carries.
Expect.suite("a stretched rope recoils when released") {
    var rope = makeRope()
    rope.holdEnd(at: CGPoint(x: 0, y: -370))
    for _ in 0..<30 {
        rope.step(dt: 1.0 / 120)
    }
    let stretched = stretch(of: rope)
    let heldAt = rope.endPoint.y

    rope.releaseEnd()
    // The rope goes slack for an instant before the recovery takes hold, so the
    // charm dips a little before it climbs. Give it long enough to do both.
    for _ in 0..<24 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(stretch(of: rope) < stretched, "the rope did not pull back in after release")
    Expect.that(rope.endPoint.y > heldAt, "the charm should spring back up when let go")

    // It should still be travelling, not have oozed to a halt.
    Expect.that(abs(rope.nodes[rope.nodes.count - 1].drift.y) > 0.02, "the recoil should carry, not stop dead")
}

// Stretching must be strictly temporary: once let go, the rope returns to the
// exact length it started with. A rope that kept the stretch would creep longer
// every time it was pulled.
Expect.suite("a stretched rope returns to its original length") {
    var rope = makeRope()
    let restingLength = rope.length
    let restingEnd = rope.endPoint

    for _ in 0..<40 {
        rope.holdEnd(at: CGPoint(x: 90, y: -380))
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(stretch(of: rope) > 0.1, "the rope should have stretched while held")

    rope.releaseEnd()
    for _ in 0..<900 {
        rope.step(dt: 1.0 / 120)
    }

    Expect.near(rope.length, restingLength, 1e-9, "the rope's resting length changed")
    Expect.near(stretch(of: rope), 0, 0.01, "the rope stayed stretched after release")
    Expect.that(rope.isAtRest, "the rope was still quivering long after release")
    Expect.near(rope.endPoint.x, restingEnd.x, 1.0, "the charm did not come back to centre")
    Expect.near(rope.endPoint.y, restingEnd.y, 1.0, "the charm did not come back to its resting height")
}

// The charm hangs, so it can be pulled down but never lifted over its anchor.
Expect.suite("the charm cannot be dragged above its anchor") {
    var rope = makeRope()
    rope.holdEnd(at: CGPoint(x: 40, y: 250))
    rope.step(dt: 1.0 / 120)
    Expect.that(rope.endPoint.y <= rope.anchor.y + 1e-9, "the charm was lifted above the point it hangs from")

    // Pulling down is fine, and stretches.
    rope.holdEnd(at: CGPoint(x: 0, y: -360))
    for _ in 0..<30 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.near(rope.endPoint.y, -360, 1.0, "pulling straight down should be allowed")
}

// How long the return takes is a dial, not an accident. The default is a quick
// snap; these check the mechanism responds, so the timing can be re-tuned by
// taste without anyone wondering whether the knob is even connected.
Expect.suite("recovery speed sets how long the return takes") {
    func returnTime(recovery: Double) -> Double {
        var rope = Rope(anchor: .zero, length: 300, stretchRecovery: recovery)
        rope.settle()
        for _ in 0..<120 {
            rope.holdEnd(at: CGPoint(x: 0, y: -520))
            rope.step(dt: 1.0 / 120)
        }
        rope.releaseEnd()
        for frame in 0..<2400 {
            rope.step(dt: 1.0 / 120)
            if abs(rope.endPoint.y + 300) < 12 { return Double(frame) / 120 }
        }
        return .infinity
    }

    let quick = returnTime(recovery: 40)
    let slow = returnTime(recovery: 2.5)
    Expect.that(quick.isFinite, "the charm never came back at the default speed")
    Expect.that(slow.isFinite, "the charm never came back at a slow recovery")
    Expect.that(quick < 0.25, "the default return took \(Int(quick * 1000))ms — it should be a snap")
    Expect.that(slow > quick * 3, "lowering the recovery rate barely changed the timing")
}

// Clicking the charm must not leave a loop of rope dangling below it. This is
// what a nudge measured in the wrong units looks like: an impulse meant as a
// speed but spent as a per-substep displacement is 240 times too big, the rope
// cannot follow the charm, and it buckles.
Expect.suite("a click never leaves a loop below the charm") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 620, dy: 0))

    var worstOverhang = 0.0
    var sharpestTurn = 0.0
    for _ in 0..<600 {
        rope.step(dt: 1.0 / 120)

        // Any node below the charm is a loop dangling off the bottom of it.
        let lowest = rope.nodes.map(\.position.y).min() ?? 0
        worstOverhang = max(worstOverhang, rope.endPoint.y - lowest)

        for index in 1..<(rope.nodes.count - 1) {
            let a = rope.nodes[index - 1].position
            let b = rope.nodes[index].position
            let c = rope.nodes[index + 1].position
            var turn = abs(atan2(c.y - b.y, c.x - b.x) - atan2(b.y - a.y, b.x - a.x))
            if turn > .pi { turn = 2 * .pi - turn }
            sharpestTurn = max(sharpestTurn, turn)
        }
    }
    Expect.that(worstOverhang < 4, "\(Int(worstOverhang))pt of rope hung below the charm")
    Expect.that(sharpestTurn < .pi / 2, "the rope kinked at \(Int(sharpestTurn * 180 / .pi)) degrees")
}

// How fast the rope recovers must not change how it hangs.
Expect.suite("recovery speed does not affect resting height") {
    var quick = Rope(anchor: .zero, length: 300, stretchRecovery: 40)
    var slow = Rope(anchor: .zero, length: 300, stretchRecovery: 2)
    quick.settle()
    slow.settle()
    for _ in 0..<600 {
        quick.step(dt: 1.0 / 120)
        slow.step(dt: 1.0 / 120)
    }
    Expect.near(quick.endPoint.y, slow.endPoint.y, 0.1, "recovery speed changed where the charm hangs")
}

// Bending must not mean tearing: even an absurd shove stays inside the ceiling.
Expect.suite("the rope survives an absurd shove") {
    var rope = makeRope()
    let push = Rope.Push(
        point: rope.endPoint,
        acceleration: CGVector(dx: 40000, dy: -20000),
        radius: 400
    )
    var worst = 0.0
    for _ in 0..<240 {
        rope.step(dt: 1.0 / 120, push: push)
        worst = max(worst, abs(stretch(of: rope)))
    }
    Expect.that(worst < 0.75, "the rope tore apart under load: \(Int(worst * 100))%")
}

// Damping has to actually take energy out, or the rope never settles.
Expect.suite("damping settles the rope") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 620, dy: 0))
    for _ in 0..<1800 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.near(rope.endPoint.x, 0, 6, "the rope should have come back to hanging straight")
    Expect.that(maximumBend(of: rope) < 2, "the rope should have straightened out")
}

// A dropped frame or a wake from sleep must not blow the solver up.
Expect.suite("a very long frame stays bounded") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 460, dy: 0))
    rope.step(dt: 12.0)
    for node in rope.nodes {
        Expect.that(node.position.x.isFinite && node.position.y.isFinite, "a node went non-finite")
    }
    Expect.that(abs(stretch(of: rope)) < 0.2, "a huge frame tore the rope apart")
}

// Zero and negative time steps are no-ops rather than NaN factories.
Expect.suite("non-positive steps are ignored") {
    var rope = makeRope()
    let before = rope
    rope.step(dt: 0)
    rope.step(dt: -1)
    Expect.that(rope == before, "a non-positive dt changed the rope")
}

// The gesture the app actually performs: the charm is held at the pointer while
// its anchor slides to the pointer's column, so the rope stretches downward
// rather than sideways. Letting go must leave the charm hanging under the new
// column at its proper length, with no stretch left over.
Expect.suite("dragging aside and down, then releasing, rehangs it cleanly") {
    var rope = makeRope()

    for step in 0...30 {
        let x = Double(step) * 4
        rope.moveAnchor(to: CGPoint(x: x, y: 0))
        rope.holdEnd(at: CGPoint(x: x, y: -430))
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(stretch(of: rope) > 0.1, "dragging down should have stretched the rope")
    Expect.near(rope.endPoint.y, -430, 1.0, "the charm should track the pointer while held")

    rope.releaseEnd()
    for _ in 0..<600 {
        rope.step(dt: 1.0 / 120)
    }

    Expect.near(stretch(of: rope), 0, 0.02, "the rope stayed stretched after release")
    Expect.near(rope.endPoint.x, 120, 3.0, "the charm should hang under the column it was dropped in")
    Expect.near(rope.endPoint.y, -300, 2.0, "the charm should return to its proper hanging length")
}

// Holding the end pins it exactly, so a drag tracks the pointer.
Expect.suite("a held end tracks the pointer exactly") {
    var rope = makeRope()
    let target = CGPoint(x: 120, y: -180)
    rope.holdEnd(at: target)
    rope.step(dt: 1.0 / 120)
    Expect.near(rope.endPoint.x, target.x, 1e-9, "the held charm drifted off the pointer")
    Expect.near(rope.endPoint.y, target.y, 1e-9, "the held charm drifted off the pointer")
}

// Yanking the anchor sideways makes the rope trail behind it.
Expect.suite("the rope trails a yanked anchor") {
    var rope = makeRope()
    for step in 1...20 {
        rope.moveAnchor(to: CGPoint(x: Double(step) * 7, y: 0))
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(rope.endPoint.x < rope.anchor.x, "the charm should lag behind an anchor moving right")
    Expect.that(maximumBend(of: rope) > 1, "a trailing rope should curve")
}

// Teleporting the anchor re-hangs the rope instead of whipping it across.
Expect.suite("placing the anchor does not whip the rope") {
    var rope = makeRope()
    rope.placeAnchor(at: CGPoint(x: 900, y: 400))
    Expect.that(rope.isAtRest, "a placed anchor should leave the rope still")
    Expect.near(rope.endPoint.x, 900, 1e-9, "the rope should hang under its new anchor")
    Expect.near(rope.endPoint.y, 100, 1e-9, "the rope should hang a full length below it")
}

// A nudge should whip the rope, moving the free end more than the top.
Expect.suite("a nudge whips the free end") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 460, dy: 0))
    rope.step(dt: 1.0 / 120)
    let topDrift = abs(rope.nodes[1].drift.x)
    let endDrift = abs(rope.nodes[rope.nodes.count - 1].drift.x)
    Expect.that(endDrift > topDrift, "the end should move more than the top")
}

// The charm is rotated to match the rope's last segment.
Expect.suite("the end angle follows the rope") {
    var rope = makeRope()
    Expect.near(rope.endAngle, 0, 1e-6, "a rope hanging straight should not tilt the charm")

    rope.holdEnd(at: CGPoint(x: 300, y: 0))
    rope.step(dt: 1.0 / 120)
    Expect.that(rope.endAngle > 0.2, "a rope pulled to the right should tilt the charm right")
}

// A screen deliberately shaped so every coordinate is easy to check by eye.
let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

// Fixed placements hang from the top edge, whatever the drop.
Expect.suite("fixed placement hangs from the top edge") {
    for (name, placement) in Placement.presets where placement != .followStatusItem {
        let anchor = PlacementSolver.solve(
            placement: placement,
            screen: screen,
            statusItemAnchor: CGPoint(x: 700, y: 780),
            defaultCordLength: 92
        )
        Expect.near(anchor.pivot.y, screen.maxY, 1e-9, "\(name) should nail the cord to the top edge")
        Expect.that(anchor.pivot.x >= screen.minX && anchor.pivot.x <= screen.maxX, "\(name) pivot left the screen")
        let charmY = anchor.pivot.y - anchor.cordLength
        Expect.that(charmY >= screen.minY, "\(name) hung the charm below the screen")
        Expect.that(charmY < anchor.pivot.y, "\(name) did not hang the charm below its pivot")
    }
}

// Left and right sit at the edges, centre in the middle.
Expect.suite("presets sit where they say") {
    func solve(_ p: Placement) -> Anchor {
        PlacementSolver.solve(placement: p, screen: screen, statusItemAnchor: nil, defaultCordLength: 150)
    }
    Expect.near(solve(.fixed(x: 0.06)).pivot.x, 60, 1e-9, "left should sit near the left edge")
    Expect.near(solve(.fixed(x: 0.5)).pivot.x, 500, 1e-9, "centre should sit in the middle")
    Expect.near(solve(.fixed(x: 0.94)).pivot.x, 940, 1e-9, "right should sit near the right edge")
}

// Every placement pays out the same rope: position is a column, not a height.
Expect.suite("placement does not change the rope's length") {
    let lengths = Placement.presets.map {
        PlacementSolver.solve(
            placement: $0.placement, screen: screen,
            statusItemAnchor: CGPoint(x: 700, y: 780), defaultCordLength: 150
        ).cordLength
    }
    Expect.that(lengths.allSatisfy { abs($0 - 150) < 1e-9 }, "a placement changed how far the charm hangs")
}

// Cord length is clamped so the charm can never hide in the menu bar or fall
// off the bottom of the screen.
Expect.suite("cord length is clamped to the screen") {
    let tooShort = PlacementSolver.solve(
        placement: .fixed(x: 0.5),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 0
    )
    Expect.that(tooShort.cordLength >= PlacementSolver.minimumCord, "a zero length should still pay out rope")

    let tooLong = PlacementSolver.solve(
        placement: .fixed(x: 0.5),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 99_999
    )
    Expect.that(tooLong.pivot.y - tooLong.cordLength >= screen.minY, "a huge length should stay on screen")
}

// Out-of-range fractions are clamped rather than trusted.
Expect.suite("placement fractions are clamped") {
    let wild = PlacementSolver.solve(
        placement: .fixed(x: 40),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 150
    )
    Expect.near(wild.pivot.x, screen.maxX, 1e-9, "x beyond 1 should clamp to the right edge")

    let negative = PlacementSolver.solve(
        placement: .fixed(x: -3),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 150
    )
    Expect.near(negative.pivot.x, screen.minX, 1e-9, "x below 0 should clamp to the left edge")
}

// A status item reported above the screen top is pulled back to the top edge.
Expect.suite("status item above the screen is clamped") {
    let anchor = PlacementSolver.solve(
        placement: .followStatusItem,
        screen: screen,
        statusItemAnchor: CGPoint(x: 700, y: 832),
        defaultCordLength: 92
    )
    Expect.near(anchor.pivot.y, screen.maxY, 1e-9, "pivot should be clamped to the visible top edge")
    Expect.near(anchor.pivot.x, 700, 1e-9, "the horizontal anchor should be left alone")
}

// Dropping the charm somewhere puts it in that column — and only that column.
Expect.suite("a drop takes the column and ignores the height") {
    let high = PlacementSolver.placement(forCharmAt: CGPoint(x: 812, y: 700), screen: screen)
    let low = PlacementSolver.placement(forCharmAt: CGPoint(x: 812, y: 60), screen: screen)
    Expect.that(high == low, "pointing lower down changed the placement — it should only take the column")

    let anchor = PlacementSolver.solve(
        placement: high, screen: screen, statusItemAnchor: nil, defaultCordLength: 150
    )
    Expect.near(anchor.pivot.x, 812, 1e-6, "the charm moved sideways on the way back")
    Expect.near(anchor.cordLength, 150, 1e-9, "dropping the charm changed how far it hangs")
}

// Placement survives a round trip through UserDefaults.
Expect.suite("placement persists") {
    let defaults = UserDefaults(suiteName: "tassel.checks.\(UUID().uuidString)")!
    let preferences = Preferences(defaults: defaults)
    Expect.that(preferences.placement == .followStatusItem, "a fresh install should follow the menu bar")

    preferences.placement = .fixed(x: 0.95)
    Expect.that(preferences.placement == .fixed(x: 0.95), "a fixed placement should round-trip")

    preferences.placement = .followStatusItem
    Expect.that(preferences.placement == .followStatusItem, "switching back should round-trip")
}

// Anything threaded on the rope is placed by fraction of arc length, so it has
// to stay on the rope however the rope is bent or stretched.
Expect.suite("threading stays on the rope") {
    var rope = makeRope()
    Expect.near(rope.point(atFraction: 0).y, rope.anchor.y, 1e-6, "fraction 0 should be the anchor")
    Expect.near(rope.point(atFraction: 1).y, rope.endPoint.y, 1e-6, "fraction 1 should be the charm")
    Expect.near(rope.point(atFraction: 0.5).y, -150, 1.0, "halfway down should be halfway down")

    // Bend it hard, then stretch it, and check again.
    let push = Rope.Push(point: rope.point(atFraction: 0.5), acceleration: CGVector(dx: 9000, dy: 0), radius: 90)
    for _ in 0..<20 {
        rope.step(dt: 1.0 / 120, push: push)
    }
    Expect.that(maximumBend(of: rope) > 10, "the rope should be bent for this check to mean anything")

    for (_, fraction) in Ornament.layout(Ornament.standard, charmSize: 44, ropeLength: rope.arcLength) {
        Expect.that(rope.distance(to: rope.point(atFraction: fraction)) < 0.5, "a bead came off the rope when it bent")
    }

    for _ in 0..<40 {
        rope.holdEnd(at: CGPoint(x: 0, y: -430))
        rope.step(dt: 1.0 / 120)
    }
    for (_, fraction) in Ornament.layout(Ornament.standard, charmSize: 44, ropeLength: rope.arcLength) {
        Expect.that(rope.distance(to: rope.point(atFraction: fraction)) < 0.5, "a bead came off the rope when it stretched")
    }
}

// Beads keep their order and spacing, rather than bunching as the rope stretches.
Expect.suite("threading keeps its order") {
    var rope = makeRope()
    func heights() -> [Double] {
        Ornament.layout(Ornament.standard, charmSize: 44, ropeLength: rope.arcLength)
            .map { rope.point(atFraction: $0.fraction).y }
    }

    let resting = heights()
    Expect.that(zip(resting, resting.dropFirst()).allSatisfy { $0 > $1 }, "the beads are out of order at rest")

    // Held long enough to settle: the rope has to stretch and straighten at
    // the same time, and that takes a moment to converge.
    for _ in 0..<200 {
        rope.holdEnd(at: CGPoint(x: 0, y: -430))
        rope.step(dt: 1.0 / 120)
    }
    let stretched = heights()
    Expect.that(zip(stretched, stretched.dropFirst()).allSatisfy { $0 > $1 }, "the beads are out of order when stretched")

    // A rope pulled taut should be taut: no belly hanging below the charm.
    Expect.near(rope.arcLength, 430, 6.0, "the rope bowed instead of pulling taut when stretched")
    Expect.that(stretched[0] < resting[0], "the beads should spread out as the rope stretches")

    // And they must clear the charm, whatever size it is, rather than hiding
    // behind it — which is exactly what a fixed fraction of the rope does.
    for size in Charm.sizes.map(\.points) {
        var still = makeRope()
        for _ in 0..<60 { still.step(dt: 1.0 / 120) }
        for (_, fraction) in Ornament.layout(Ornament.standard, charmSize: size, ropeLength: still.arcLength) {
            let point = still.point(atFraction: fraction)
            let gap = hypot(point.x - still.endPoint.x, point.y - still.endPoint.y)
            Expect.that(gap > size * 0.5, "an ornament sat behind a \(Int(size))pt charm")
        }
    }
}

// Telling a grab of the rope from a grab of the charm is a distance test, so it
// had better measure what it claims to.
Expect.suite("distance to the rope") {
    let rope = makeRope()
    Expect.near(rope.distance(to: CGPoint(x: 0, y: -150)), 0, 0.5, "a point on the rope should be no distance from it")
    Expect.near(rope.distance(to: CGPoint(x: 25, y: -150)), 25, 0.5, "a point beside the rope should measure across")
    Expect.that(rope.distance(to: CGPoint(x: 0, y: 90)) > 80, "a point above the anchor is not on the rope")
    Expect.near(rope.distance(to: rope.endPoint), 0, 1e-6, "the charm sits on the end of its own rope")
}

// Anything threaded on the rope lies along it.
Expect.suite("the tangent follows the rope") {
    var rope = makeRope()
    Expect.near(rope.tangentAngle(atFraction: 0.5), 0, 1e-6, "a rope hanging straight should not tilt a bead")

    rope.holdEnd(at: CGPoint(x: 300, y: 0))
    for _ in 0..<20 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(rope.tangentAngle(atFraction: 0.9) > 0.2, "a rope pulled right should tilt what is threaded on it")
}

// Every charm's threading has to fit on the rope at every size it can be shown
// at, rather than piling up against the anchor on the biggest one.
Expect.suite("every charm's threading fits the rope") {
    var rope = makeRope(length: 150)
    for _ in 0..<120 {
        rope.step(dt: 1.0 / 120)
    }

    for charm in Charm.builtIn {
        for size in Charm.sizes.map(\.points) {
            let threading = Ornament.layout(charm.threading, charmSize: size, ropeLength: rope.arcLength)
            Expect.that(!threading.isEmpty, "\(charm.name) threaded nothing at all at \(Int(size))pt")

            let fractions = threading.map(\.fraction)
            for fraction in fractions {
                let point = rope.point(atFraction: fraction)
                Expect.that(rope.distance(to: point) < 0.5, "\(charm.name) threading left the rope at \(Int(size))pt")
                let gap = hypot(point.x - rope.endPoint.x, point.y - rope.endPoint.y)
                Expect.that(gap > size * 0.4, "\(charm.name) threading sat behind the charm at \(Int(size))pt")
            }
            // Strictly increasing fractions means nothing has collapsed onto
            // the anchor or onto a neighbour.
            Expect.that(
                zip(fractions, fractions.dropFirst()).allSatisfy { $0 < $1 },
                "\(charm.name) threading collided at \(Int(size))pt"
            )
        }
    }
}

// The chillies lie across the string rather than along it.
Expect.suite("nimbu mirchi hangs its chillies crosswise") {
    // The glyph lies flat already, so a chilli is horizontal at 0 and at half a
    // turn. A quarter turn would stand it upright, which is the failure to catch.
    let turns = Ornament.nimbuMirchi.map(\.rotation)
    for turn in turns {
        let uprightness = abs(sin(turn))
        Expect.that(uprightness < 0.2, "a chilli was stood upright instead of lying across the string")
    }
    Expect.that(
        zip(turns, turns.dropFirst()).allSatisfy { abs(cos($0) - cos($1)) > 1.5 },
        "the chillies should point left and right by turns"
    )
    Expect.that(Charm.builtIn.contains { $0.name == "Nimbu Mirchi" }, "the charm should be on the menu")
}

// A charm fades as its ritual goes untended, and is restored by tending it.
Expect.suite("a ritual fades and is restored") {
    let ritual = Ritual(name: "Hang a Fresh One", days: 7)
    let now = Date()

    // Never tended is not the same as neglected: hanging one up counts.
    Expect.near(ritual.freshness(lastPerformed: nil, now: now), 1, 1e-9, "an untouched charm should start fresh")
    Expect.near(ritual.opacity(lastPerformed: nil, now: now), 1, 1e-9, "an untouched charm should be fully solid")

    let justNow = now.addingTimeInterval(-1)
    Expect.near(ritual.freshness(lastPerformed: justNow, now: now), 1, 0.01, "a charm just tended should be fresh")

    let halfway = now.addingTimeInterval(-3.5 * 86_400)
    Expect.near(ritual.freshness(lastPerformed: halfway, now: now), 0.5, 0.01, "halfway through should be half faded")

    let overdue = now.addingTimeInterval(-30 * 86_400)
    Expect.near(ritual.freshness(lastPerformed: overdue, now: now), 0, 1e-9, "long overdue should be fully faded")
}

// However long it is left, a charm never fades to nothing.
Expect.suite("a neglected charm never disappears") {
    let now = Date()
    let forgotten = now.addingTimeInterval(-3650 * 86_400)
    for charm in Charm.builtIn {
        let opacity = charm.ritual.opacity(lastPerformed: forgotten, now: now)
        if charm.ritual.isStaged {
            // Staged rituals wait instead: a daruma left one-eyed for a year is
            // a wish still pending, not a neglected charm.
            Expect.near(opacity, 1, 1e-9, "\(charm.name) faded, but a staged ritual should wait, not fade")
            continue
        }
        Expect.that(opacity > 0.08, "\(charm.name) faded to \(opacity) — it should look neglected, not vanish")
        Expect.that(opacity < 1, "\(charm.name) does not fade at all when neglected")
    }
}

// A clock that has jumped backwards must not make a charm more than fresh.
Expect.suite("a ritual in the future is still just fresh") {
    let ritual = Ritual(name: "Ring It", days: 3)
    let now = Date()
    let future = now.addingTimeInterval(90 * 86_400)
    Expect.near(ritual.freshness(lastPerformed: future, now: now), 1, 1e-9, "a future date should clamp to fresh")
    Expect.near(ritual.opacity(lastPerformed: future, now: now), 1, 1e-9, "a future date should clamp to solid")
}

// The menu says so once a charm is more than half gone.
Expect.suite("a ritual comes due halfway") {
    let ritual = Ritual(name: "Wipe It Clear", days: 10)
    let now = Date()
    Expect.that(!ritual.isDue(lastPerformed: now.addingTimeInterval(-4 * 86_400), now: now), "not due at 40 per cent")
    Expect.that(ritual.isDue(lastPerformed: now.addingTimeInterval(-6 * 86_400), now: now), "due at 60 per cent")
    Expect.that(!ritual.isDue(lastPerformed: nil, now: now), "an untouched charm is not overdue")
}

// Every charm carries an upkeep of its own rather than a shared placeholder.
Expect.suite("every charm has its own ritual") {
    let names = Set(Charm.builtIn.map(\.ritual.name))
    Expect.that(names.count == Charm.builtIn.count, "two charms share a ritual name")
    for charm in Charm.builtIn {
        Expect.that(charm.ritual.isStaged || charm.ritual.period > 0, "\(charm.name) has no ritual period")
        Expect.that(charm.ritual.name != Ritual.generic.name, "\(charm.name) was left on the generic ritual")
    }
}

// tassel:// URLs, which is how anything else on the machine asks for something.
Expect.suite("tassel:// urls parse") {
    func command(_ text: String) -> Command? {
        URL(string: text).flatMap(Command.init(url:))
    }

    Expect.that(command("tassel://bless") == .bless, "bless should parse")
    Expect.that(command("tassel://ritual") == .ritual, "ritual should parse")
    Expect.that(command("tassel://show") == .show, "show should parse")
    Expect.that(command("tassel://hide") == .hide, "hide should parse")

    // Both spellings, because both are things people will type.
    Expect.that(command("tassel:bless") == .bless, "the slashless form should parse")
    Expect.that(command("TASSEL://BLESS") == .bless, "parsing should not care about case")
    Expect.that(command("tassel://bless/") == .bless, "a trailing slash should be tolerated")

    Expect.that(command("tassel://charm?name=Nazar") == .charm("Nazar"), "charm should carry its name")
    Expect.that(command("tassel:charm?name=Nazar") == .charm("Nazar"), "the slashless form should carry its name too")
    Expect.that(command("tassel://charm?name=Nimbu%20Mirchi") == .charm("Nimbu Mirchi"), "an escaped space should decode")
    Expect.that(command("tassel://charm?other=x&name=Star") == .charm("Star"), "name should be found among other parameters")

    // Both spellings must agree, on every verb. They did not: Foundation puts
    // the verb in a different place for each form depending on its version, and
    // only CI noticed.
    for verb in ["bless", "ritual", "show", "hide"] {
        Expect.that(
            command("tassel://\(verb)") == command("tassel:\(verb)"),
            "tassel://\(verb) and tassel:\(verb) should mean the same thing"
        )
    }
}

// Anything unrecognised is ignored rather than guessed at. These arrive from
// outside the app, so the parser is the boundary.
Expect.suite("tassel:// urls reject the rest") {
    func command(_ text: String) -> Command? {
        URL(string: text).flatMap(Command.init(url:))
    }

    Expect.that(command("https://example.com/bless") == nil, "another scheme should be refused")
    Expect.that(command("tassel://quit") == nil, "an unknown verb should be refused")
    Expect.that(command("tassel://") == nil, "an empty verb should be refused")
    Expect.that(command("tassel://charm") == nil, "charm without a name should be refused")
    Expect.that(command("tassel://charm?name=") == nil, "charm with an empty name should be refused")
    Expect.that(command("tassel://charm?name=%20") == nil, "charm with a blank name should be refused")
}

// A URL can only ever select a charm that already exists, so nothing outside
// the app can put arbitrary content on screen.
Expect.suite("a url cannot invent a charm") {
    Expect.that(Charm.named("Nazar") != nil, "a real charm should resolve")
    Expect.that(Charm.named("  nazar  ") != nil, "resolving should tolerate case and spacing")
    Expect.that(Charm.named("\u{1F480}") == nil, "a raw glyph should not resolve to a charm")
    Expect.that(Charm.named("Definitely Not A Charm") == nil, "an unknown name should not resolve")
}

// Artwork names become file names and bundle lookups, so the rule that governs
// them is a boundary, not a convention.
Expect.suite("artwork names are restricted") {
    for good in ["daruma", "maneki-neko", "nimbu-mirchi", "charm2", "a"] {
        Expect.that(Artwork.isValidName(good), "\(good) should be a usable artwork name")
    }
    for bad in ["", "../../etc/passwd", "/etc/passwd", "Daruma", "my charm",
                "charm.png", "charm/../x", "charm\u{0000}", String(repeating: "a", count: 65)] {
        Expect.that(!Artwork.isValidName(bad), "\(bad.debugDescription) should be refused as an artwork name")
    }
}

// The anchor the template draws and the anchor the code uses must be the same
// number, or every drawn charm hangs slightly wrong.
Expect.suite("the artwork anchor is where the template says") {
    Expect.near(Artwork.canvas, 1024, 1e-9, "the template canvas is 1024 square")
    Expect.near(Artwork.anchorY * Artwork.canvas, 40, 1e-9, "the anchor is 40px down from the top")
    Expect.near(Artwork.anchorX, 0.5, 1e-9, "the anchor is horizontally centred")
    Expect.that(Artwork.scale > 1, "artwork is drawn larger than the charm size, not smaller")
}

// A charm may carry artwork, but must never depend on it: the glyph is what
// appears in menus, and what gets drawn if the file has gone missing.
Expect.suite("every charm survives its artwork going missing") {
    for charm in Charm.builtIn {
        Expect.that(!charm.glyph.isEmpty, "\(charm.name) has no glyph to fall back on")
        let names = [charm.artwork].compactMap { $0 } + charm.ritual.stages.map(\.artwork)
        for artwork in names {
            Expect.that(Artwork.isValidName(artwork), "\(charm.name) has an unusable artwork name \(artwork)")
        }
    }
}

// Beads are coloured against their charm, not left one bone colour for all.
// A new charm strung with beads should get a colour picked for it too.
Expect.suite("every beaded charm has beads of its own colour") {
    for charm in Charm.builtIn where charm.threading.contains(where: { $0.shape == .bead }) {
        Expect.that(charm.beadColor != nil, "\(charm.name) is strung with beads but names no bead colour")
    }
    let hex = RGB(0xFF8000)
    Expect.near(hex.red, 1, 1e-9, "a hex colour's red should read from the top byte")
    Expect.near(hex.green, 128.0 / 255, 1e-9, "a hex colour's green should read from the middle byte")
    Expect.near(hex.blue, 0, 1e-9, "a hex colour's blue should read from the bottom byte")
}

// Artwork is placed by where the drawing actually is, not by the canvas it was
// drawn on, so a charm that left a margin does not hang from a length of bare
// rope where that margin is.
Expect.suite("artwork hangs by its drawing, not its canvas") {
    let full = CGRect(x: 0, y: 0, width: 1, height: 1)
    // The same charm drawn small in the middle of its page.
    let inset = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)

    let a = Artwork.drawRect(content: full, hookX: 0.5, aspect: 1, charmSize: 60, hanging: true)
    let b = Artwork.drawRect(content: inset, hookX: 0.5, aspect: 1, charmSize: 60, hanging: true)

    // Both must put the top of the drawing exactly on the rope.
    Expect.near(a.maxY, 0, 1e-9, "a full-canvas drawing should start at the rope")
    Expect.near(b.origin.y + inset.maxY * b.height, 0, 1e-9, "an inset drawing should start at the rope too")

    // And both must come out the same size on screen.
    Expect.near(full.height * a.height, inset.height * b.height, 1e-9, "the two should draw at the same size")
    Expect.near(full.height * a.height, 60 * Artwork.scale, 1e-9, "the drawing should be scale times the charm size")
}

// Horizontally, the rope meets the drawing at its hook however it sat on the
// page — its middle when it is symmetric, off to one side when it is not.
Expect.suite("artwork hangs on the rope by its hook") {
    let offCentre = CGRect(x: 0.1, y: 0.2, width: 0.4, height: 0.6)
    let centred = Artwork.drawRect(content: offCentre, hookX: offCentre.midX, aspect: 1, charmSize: 50, hanging: true)
    Expect.near(centred.origin.x + offCentre.midX * centred.width, 0, 1e-9, "a drawing hooked in its middle should straddle the rope")

    let lopsided = Artwork.drawRect(content: offCentre, hookX: 0.42, aspect: 1, charmSize: 50, hanging: true)
    Expect.near(lopsided.origin.x + 0.42 * lopsided.width, 0, 1e-9, "the hook, not the middle, should be on the rope")
}

// A maneki-neko raises a paw out to one side, which pulls the middle of the
// drawing well away from the loop it hangs by. The rope has to meet the loop,
// or it ends in thin air beside it.
Expect.suite("a drawing hangs by its loop, not by its middle") {
    // 100 square, y down: a ring centred at x 70, a body under it, and a paw
    // reaching out far to the left.
    let measured = Artwork.measure(width: 100, height: 100, step: 1) { x, y in
        let ring = hypot(Double(x - 70), Double(y - 8)) <= 6
        let body = (40...95).contains(x) && (20...99).contains(y)
        let paw = (0...40).contains(x) && (25...40).contains(y)
        return ring || body || paw
    }
    Expect.near(measured.content.minX, 0, 1e-9, "the paw is part of the drawing")
    Expect.near(measured.content.maxY, 0.98, 1e-9, "the top of the drawing is the top of the ring")
    Expect.near(measured.hookX, 0.70, 0.01, "the drawing should hang from its ring, at 70")

    // Whereas a symmetric one hangs from its middle, exactly as before.
    let disc = Artwork.measure(width: 100, height: 100, step: 1) { x, y in
        hypot(Double(x - 50), Double(y - 50)) <= 30
    }
    Expect.near(disc.hookX, disc.content.midX, 1e-9, "a symmetric drawing should hang from its middle")

    let blank = Artwork.measure(width: 10, height: 10, step: 1) { _, _ in false }
    Expect.that(blank.content == CGRect(x: 0, y: 0, width: 1, height: 1) && blank.hookX == 0.5,
                "a blank image should fall back to the whole canvas")
}

// Threaded on rather than hung from: the rope passes through the middle.
Expect.suite("a threaded charm sits centred on the rope") {
    let content = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    let rect = Artwork.drawRect(content: content, hookX: content.midX, aspect: 1, charmSize: 40, hanging: false)
    Expect.near(rect.origin.y + content.midY * rect.height, 0, 1e-9, "a threaded charm should be centred, not hung")

    let hung = Artwork.drawRect(content: content, hookX: content.midX, aspect: 1, charmSize: 40, hanging: true)
    Expect.that(hung.origin.y < rect.origin.y, "a hanging charm should sit lower than a threaded one")
}

// A blank or broken image must not divide by zero.
Expect.suite("empty artwork does not explode") {
    let rect = Artwork.drawRect(content: .zero, hookX: 0, aspect: 0, charmSize: 40, hanging: true)
    Expect.that(rect.width.isFinite && rect.height.isFinite, "an empty image produced a non-finite rect")
    Expect.that(rect.height > 0, "an empty image produced no height")
}

// Every artwork a charm names must actually be in the repository. A typo in a
// name would otherwise only show up as a charm quietly falling back to its
// glyph, which is easy to miss.
Expect.suite("every named artwork file exists") {
    let folder = FileManager.default.currentDirectoryPath + "/" + Artwork.folder
    for charm in Charm.builtIn {
        let names = [charm.artwork].compactMap { $0 } + charm.ritual.stages.map(\.artwork)
        for name in names {
            let path = "\(folder)/\(name).png"
            Expect.that(FileManager.default.fileExists(atPath: path), "\(charm.name) names \(name).png, which is not there")
        }
    }
}

// The drawings themselves, measured the way the app measures them: wherever
// the rope ends up meeting one, there has to be something drawn there. A stray
// speck above the loop, or a lopsided drawing hung from its middle, puts the
// end of the rope in empty air instead.
Expect.suite("the rope meets every drawn charm on its drawing") {
    let folder = FileManager.default.currentDirectoryPath + "/" + Artwork.folder
    let names = Set(Charm.builtIn.flatMap { [$0.artwork].compactMap { $0 } + $0.ritual.stages.map(\.artwork) })
    for name in names.sorted() {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: "\(folder)/\(name).png") as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let context = CGContext(
                  data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                  bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            Expect.that(false, "\(name).png could not be read")
            continue
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let width = image.width, height = image.height
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        // Rows run top-down in memory; alpha is the fourth byte.
        let isDrawn = { (x: Int, y: Int) in
            x >= 0 && y >= 0 && x < width && y < height && pixels[(y * width + x) * 4 + 3] > 20
        }
        let step = min(width, height) / 200
        let measured = Artwork.measure(width: width, height: height, step: step, isDrawn: isDrawn)

        // Where the rope's end lands on the image, in pixels, y down.
        let rect = Artwork.drawRect(content: measured.content, hookX: measured.hookX,
                                    aspect: Double(width) / Double(height), charmSize: 60, hanging: true)
        let ropeX = Int(-rect.minX / rect.width * Double(width))
        let ropeY = Int((1 - -rect.minY / rect.height) * Double(height))
        let touches = (ropeY...(ropeY + 3 * step)).contains { y in
            ((ropeX - 3)...(ropeX + 3)).contains { x in isDrawn(x, y) }
        }
        Expect.that(touches, "the rope meets \(name).png at \(ropeX),\(ropeY), where nothing is drawn")
    }
}

// A staged ritual moves forward one stage at a time and begins again after the
// last, rather than stopping or skipping.
Expect.suite("a staged ritual advances and starts over") {
    let ritual = Ritual(name: "Test", stages: [
        RitualStage(action: "A", artwork: "a"),
        RitualStage(action: "B", artwork: "b"),
        RitualStage(action: "C", artwork: "c"),
    ])
    Expect.that(ritual.isStaged, "a ritual with stages should say so")
    Expect.that(ritual.stage(after: 0) == 1 && ritual.stage(after: 1) == 2, "stages should advance one at a time")
    Expect.that(ritual.stage(after: 2) == 0, "after the last stage it should begin again")

    // A stored stage can outlive a change to the number of stages.
    Expect.that(ritual.stage(at: 7)?.action == "B", "an out-of-range stage should wrap, not trap")
    Expect.that(ritual.stage(at: -1)?.action == "C", "a negative stage should wrap, not trap")

    Expect.that(!ritual.isDue(lastPerformed: Date.distantPast), "a staged ritual is never overdue")
    Expect.that(Ritual(name: "x", days: 3).stage(at: 0) == nil, "an ordinary ritual has no stages")
}

// The daruma goes blank, then one eye, then both — in that order, because that
// is the order the custom has.
Expect.suite("the daruma is painted in order") {
    guard let daruma = Charm.named("Daruma") else {
        Expect.that(false, "the daruma is missing from the charms")
        return
    }
    Expect.that(daruma.ritual.isStaged, "the daruma's ritual should advance, not fade")
    Expect.that(daruma.artwork(atStage: 0) == "daruma-blank", "a new daruma should be blank")
    Expect.that(daruma.artwork(atStage: 1) == "daruma-one-eye", "a wish made should open one eye")
    Expect.that(daruma.artwork(atStage: 2) == "daruma", "a wish granted should open both")
    Expect.that(daruma.artwork(atStage: daruma.ritual.stage(after: 2)) == "daruma-blank",
                "a granted daruma should give way to a new blank one")
}

// Where a staged ritual has got is remembered per charm.
Expect.suite("ritual stages persist per charm") {
    let defaults = UserDefaults(suiteName: "tassel.checks.\(UUID().uuidString)")!
    let preferences = Preferences(defaults: defaults)
    Expect.that(preferences.ritualStage(forCharm: "a") == 0, "a charm never tended should be at the first stage")

    preferences.setRitualStage(2, forCharm: "a")
    Expect.that(preferences.ritualStage(forCharm: "a") == 2, "a stage should round-trip")
    Expect.that(preferences.ritualStage(forCharm: "b") == 0, "tending one charm should not move another")

    preferences.setRitualStage(-5, forCharm: "a")
    Expect.that(preferences.ritualStage(forCharm: "a") == 0, "a negative stage should not be stored")
}

// A charm continues the line of its rope. The rotation that places it got its
// sign backwards for a long time, so every charm bent back against its rope like
// a mirror image — hidden by a round nazar, obvious on a swinging daruma.
Expect.suite("a charm continues the line of its rope") {
    for degrees in [-60.0, -25, 0, 25, 60] {
        let heading = degrees * .pi / 180
        let placement = Rope.placement(at: CGPoint(x: 100, y: 200), heading: heading)
        let origin = CGPoint.zero.applying(placement)
        let down = CGPoint(x: 0, y: -1).applying(placement)
        // Where the charm's own "down" ends up, as a direction.
        let dx = down.x - origin.x, dy = down.y - origin.y
        Expect.near(dx, sin(heading), 1e-9, "at \(Int(degrees)) degrees the charm leans the wrong way sideways")
        Expect.near(dy, -cos(heading), 1e-9, "at \(Int(degrees)) degrees the charm points the wrong way vertically")
        Expect.near(origin.x, 100, 1e-9, "the charm should sit at the rope's end")
    }
}

// What can be clicked is the drawn charm, hanging below the rope's end.
Expect.suite("a hanging charm's clickable area is where it is drawn") {
    let content = CGRect(x: 0.1, y: 0.05, width: 0.8, height: 0.86)
    let box = Artwork.contentBox(content: content, hookX: content.midX, aspect: 1, charmSize: 60, hanging: true)
    Expect.near(box.maxY, 0, 1e-9, "the top of the drawing should meet the rope's end")
    Expect.near(box.midX, 0, 1e-9, "the drawing should straddle the rope")
    Expect.near(box.height, 60 * Artwork.scale, 1e-9, "the box should be as tall as the drawing is drawn")
    Expect.that(box.minY < -60, "the box should reach all the way down a hanging charm, not stop near the rope")
}

Expect.report()
