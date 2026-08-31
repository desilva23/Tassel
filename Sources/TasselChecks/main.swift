import CoreGraphics
import Foundation
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

Expect.report()
