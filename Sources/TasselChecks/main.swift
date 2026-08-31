import CoreGraphics
import Foundation
import TasselCore

// Hanging straight down with no push, it should stay hanging straight down.
Expect.suite("rest is stable") {
    var pendulum = Pendulum()
    for _ in 0..<600 {
        pendulum.step(dt: 1.0 / 60)
    }
    Expect.near(pendulum.angle, 0, 1e-9, "angle drifted from rest")
    Expect.near(pendulum.angularVelocity, 0, 1e-9, "velocity appeared from nowhere")
    Expect.that(pendulum.isAtRest, "should report itself at rest")
}

// Released from one side, it swings back toward centre rather than away.
Expect.suite("released from an angle swings back") {
    var pendulum = Pendulum(angle: 0.6)
    let start = pendulum.angle
    pendulum.step(dt: 1.0 / 60)
    Expect.that(pendulum.angle < start, "swung outward instead of back")
}

// Damping has to actually take energy out, or the charm never settles.
Expect.suite("damping bleeds off amplitude") {
    var pendulum = Pendulum(angle: 0.7)
    var peak = 0.0
    for _ in 0..<1200 {
        pendulum.step(dt: 1.0 / 60)
        peak = max(peak, abs(pendulum.angle))
    }
    Expect.that(abs(pendulum.angle) < 0.05, "still swinging at \(pendulum.angle) after 20s")
    Expect.that(peak <= 0.7 + 1e-6, "amplitude grew to \(peak)")
}

// An undamped swing should keep roughly the amplitude it started with, which is
// the check that the integrator is not quietly pumping energy into the system.
Expect.suite("undamped swing conserves amplitude") {
    var pendulum = Pendulum(damping: 0, angle: 0.4)
    var peak = 0.0
    for _ in 0..<3000 {
        pendulum.step(dt: 1.0 / 120)
        peak = max(peak, abs(pendulum.angle))
    }
    Expect.near(peak, 0.4, 0.05, "amplitude was not conserved")
}

// Yank the anchor to the right and the charm lags to the left.
Expect.suite("pivot acceleration pushes the bob the other way") {
    var pendulum = Pendulum()
    pendulum.step(dt: 1.0 / 60, pivotAcceleration: CGVector(dx: 3000, dy: 0))
    Expect.that(pendulum.angle < 0, "bob led the pivot instead of lagging it")
}

// A dropped frame or a wake from sleep must not fling it into orbit.
Expect.suite("a very long frame stays bounded") {
    var pendulum = Pendulum(angle: 0.5)
    pendulum.step(dt: 12.0)
    Expect.that(pendulum.angle.isFinite, "angle went non-finite")
    Expect.that(abs(pendulum.angle) <= .pi / 2, "angle escaped its clamp")
    Expect.that(abs(pendulum.angularVelocity) <= 40, "velocity escaped its clamp")
}

// Zero and negative time steps are no-ops rather than NaN factories.
Expect.suite("non-positive steps are ignored") {
    var pendulum = Pendulum(angle: 0.3)
    let before = pendulum
    pendulum.step(dt: 0)
    pendulum.step(dt: -1)
    Expect.that(pendulum == before, "a non-positive dt changed the state")
}

// The bob hangs below the pivot, and leans the way the angle points.
Expect.suite("bob offset geometry") {
    var pendulum = Pendulum(length: 100)
    Expect.near(pendulum.bobOffset.x, 0, 1e-9, "at rest the bob should be centred")
    Expect.near(pendulum.bobOffset.y, -100, 1e-9, "at rest the bob should be a full cord below")

    pendulum = Pendulum(length: 100, angle: .pi / 6)
    Expect.near(pendulum.bobOffset.x, 50, 1e-6, "30 degrees should put the bob at half a cord across")
    Expect.that(pendulum.bobOffset.y < 0, "the bob should always hang below the pivot")
}

// Preferences clamp anything absurd that lands in UserDefaults.
Expect.suite("preferences clamp out-of-range values") {
    let defaults = UserDefaults(suiteName: "tassel.checks.\(UUID().uuidString)")!
    let preferences = Preferences(defaults: defaults)

    Expect.that(preferences.charm == Charm.fallback, "a fresh install should get the default charm")
    Expect.that(preferences.isVisible, "a fresh install should be visible")

    preferences.cordLength = 100_000
    Expect.that(preferences.cordLength <= 400, "cord length was not clamped")
    preferences.charmSize = -20
    Expect.that(preferences.charmSize >= 12, "charm size was not clamped")

    preferences.charm = Charm(glyph: "\u{1F680}", name: "Custom")
    Expect.that(preferences.charm.glyph == "\u{1F680}", "a custom glyph should round-trip")
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

// The corners are actually in the corners.
Expect.suite("corner presets land in corners") {
    func solve(_ p: Placement) -> Anchor {
        PlacementSolver.solve(placement: p, screen: screen, statusItemAnchor: nil, defaultCordLength: 92)
    }
    let topLeft = solve(.fixed(x: 0.05, drop: 0.16))
    let bottomRight = solve(.fixed(x: 0.95, drop: 0.86))
    Expect.near(topLeft.pivot.x, 50, 1e-9, "top left should sit near the left edge")
    Expect.near(topLeft.cordLength, 128, 1e-9, "top left should pay out a short cord")
    Expect.near(bottomRight.pivot.x, 950, 1e-9, "bottom right should sit near the right edge")
    Expect.near(bottomRight.cordLength, 688, 1e-9, "bottom right should pay out a long cord")
}

// Cord length is clamped so the charm can never hide in the menu bar or fall
// off the bottom of the screen.
Expect.suite("cord length is clamped to the screen") {
    let tooShort = PlacementSolver.solve(
        placement: .fixed(x: 0.5, drop: 0),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 92
    )
    Expect.that(tooShort.cordLength >= PlacementSolver.minimumCord, "a zero drop should still pay out cord")

    let tooLong = PlacementSolver.solve(
        placement: .fixed(x: 0.5, drop: 1),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 92
    )
    Expect.that(tooLong.pivot.y - tooLong.cordLength >= screen.minY, "a full drop should stay on screen")
}

// Out-of-range fractions are clamped rather than trusted.
Expect.suite("placement fractions are clamped") {
    let wild = PlacementSolver.solve(
        placement: .fixed(x: 40, drop: -12),
        screen: screen, statusItemAnchor: nil, defaultCordLength: 92
    )
    Expect.near(wild.pivot.x, screen.maxX, 1e-9, "x beyond 1 should clamp to the right edge")
    Expect.that(wild.cordLength >= PlacementSolver.minimumCord, "a negative drop should clamp, not go negative")
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

// Dragging the charm somewhere and solving again should put it back there.
Expect.suite("drag position round-trips") {
    let dropped = CGPoint(x: 812, y: 240)
    let placement = PlacementSolver.placement(forCharmAt: dropped, screen: screen)
    let anchor = PlacementSolver.solve(
        placement: placement, screen: screen, statusItemAnchor: nil, defaultCordLength: 92
    )
    Expect.near(anchor.pivot.x, dropped.x, 1e-6, "the charm moved horizontally on the way back")
    Expect.near(anchor.pivot.y - anchor.cordLength, dropped.y, 1e-6, "the charm moved vertically on the way back")
}

// Placement survives a round trip through UserDefaults.
Expect.suite("placement persists") {
    let defaults = UserDefaults(suiteName: "tassel.checks.\(UUID().uuidString)")!
    let preferences = Preferences(defaults: defaults)
    Expect.that(preferences.placement == .followStatusItem, "a fresh install should follow the menu bar")

    preferences.placement = .fixed(x: 0.95, drop: 0.86)
    Expect.that(preferences.placement == .fixed(x: 0.95, drop: 0.86), "a fixed placement should round-trip")

    preferences.placement = .followStatusItem
    Expect.that(preferences.placement == .followStatusItem, "switching back should round-trip")
}

// A push at the charm itself sends it the way you pushed.
Expect.suite("a push at the bob moves it that way") {
    var pendulum = Pendulum()
    pendulum.step(dt: 1.0 / 60, bobAcceleration: CGVector(dx: 3000, dy: 0))
    Expect.that(pendulum.angle > 0, "a rightward push should swing the charm right")

    var other = Pendulum()
    other.step(dt: 1.0 / 60, bobAcceleration: CGVector(dx: -3000, dy: 0))
    Expect.that(other.angle < 0, "a leftward push should swing the charm left")
}

// A push straight along the cord is eaten by the cord, as a real one would be.
Expect.suite("a push along the cord does nothing") {
    var pendulum = Pendulum()
    pendulum.step(dt: 1.0 / 60, bobAcceleration: CGVector(dx: 0, dy: -3000))
    Expect.near(pendulum.angle, 0, 1e-9, "a straight-down push should not swing the charm")
}

// Dragging points the charm at the pointer.
Expect.suite("holding points the charm at the pointer") {
    var pendulum = Pendulum(length: 100)
    pendulum.hold(towards: CGPoint(x: 100, y: 0), dt: 1.0 / 60)
    Expect.near(pendulum.angle, .pi / 2, 1e-9, "dragging level right should lay the cord out right")

    pendulum.hold(towards: CGPoint(x: 0, y: -100), dt: 1.0 / 60)
    Expect.near(pendulum.angle, 0, 1e-9, "dragging straight down should hang it straight down")
}

// Dragging above the pivot is clamped rather than allowed to loop over the top.
Expect.suite("holding is clamped to the horizontal") {
    var pendulum = Pendulum(length: 100)
    pendulum.hold(towards: CGPoint(x: 10, y: 400), dt: 1.0 / 60)
    Expect.that(abs(pendulum.angle) <= .pi / 2 + 1e-9, "dragging upward escaped the clamp")
}

// Letting go throws the charm, rather than dropping it dead.
Expect.suite("releasing a drag throws the charm") {
    var pendulum = Pendulum(length: 100)
    // Sweep the pointer steadily left to right across the bottom of the arc.
    for step in 0...10 {
        let x = -50.0 + Double(step) * 10
        pendulum.hold(towards: CGPoint(x: x, y: -100), dt: 1.0 / 60)
    }
    Expect.that(pendulum.angularVelocity > 0.5, "a left-to-right drag should build rightward speed")

    let released = pendulum.angularVelocity
    pendulum.step(dt: 1.0 / 60)
    Expect.that(pendulum.angle > 0, "it should keep travelling after release")
    Expect.that(abs(pendulum.angularVelocity) < abs(released) * 1.5, "release speed should not blow up")
}

Expect.report()
