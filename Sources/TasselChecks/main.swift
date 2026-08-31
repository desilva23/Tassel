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
    rope.nudge(CGVector(dx: 26, dy: 0))
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
    Expect.that(stretch(of: rope) < 0.35, "the rope tore apart when dragged far enough: \(Int(stretch(of: rope) * 100))% at end y=\(Int(rope.endPoint.y))")
    Expect.that(rope.endPoint.y > -400, "the charm should have stayed behind the pointer")
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
    for _ in 0..<20 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(stretch(of: rope) < stretched, "the rope did not pull back in after release")
    Expect.that(rope.endPoint.y > heldAt, "the charm should spring back up when let go")

    // It should overshoot and keep moving, not just ooze back into place.
    Expect.that(abs(rope.nodes[rope.nodes.count - 1].drift.y) > 0.05, "the recoil should carry, not stop dead")
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
    Expect.that(worst < 0.35, "the rope tore apart under load: \(Int(worst * 100))%")
}

// Damping has to actually take energy out, or the rope never settles.
Expect.suite("damping settles the rope") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 30, dy: 0))
    for _ in 0..<1800 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.near(rope.endPoint.x, 0, 6, "the rope should have come back to hanging straight")
    Expect.that(maximumBend(of: rope) < 2, "the rope should have straightened out")
}

// A dropped frame or a wake from sleep must not blow the solver up.
Expect.suite("a very long frame stays bounded") {
    var rope = makeRope()
    rope.nudge(CGVector(dx: 20, dy: 0))
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

// Letting go of a rope you were swinging throws it. Verlet gives this for free:
// the held node's velocity is the gap it was dragged across.
Expect.suite("releasing a held end throws it") {
    var rope = makeRope()
    // Sweep the charm steadily sideways, then let go.
    for step in 0...20 {
        rope.holdEnd(at: CGPoint(x: Double(step) * 6, y: -290))
        rope.step(dt: 1.0 / 120)
    }
    let releasedAt = rope.endPoint
    rope.releaseEnd()
    for _ in 0..<10 {
        rope.step(dt: 1.0 / 120)
    }
    Expect.that(rope.endPoint.x > releasedAt.x, "the charm should keep travelling after release")
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
    rope.nudge(CGVector(dx: 20, dy: 0))
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

Expect.report()
