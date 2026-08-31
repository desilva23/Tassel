import AppKit
import QuartzCore
import TasselCore

/// Draws the rope and the charm, runs the simulation once per displayed frame,
/// and handles pointer interaction.
///
/// The view covers the whole screen so the charm can hang anywhere on it, which
/// means redrawing the full bounds every frame would be wasteful. Only the
/// region the rope actually occupies is invalidated instead.
final class CharmView: NSView {
    /// Where the rope is nailed down, in this view's coordinates. Setting it
    /// drags the anchor, so the rope trails behind as the menu bar item shifts.
    var pivot: CGPoint = .zero {
        didSet {
            guard pivot != oldValue else { return }
            rope.moveAnchor(to: pivot)
            invalidateRope()
        }
    }

    var charm: Charm = .fallback { didSet { invalidateRope() } }
    var charmSize: Double = 44 { didSet { invalidateRope() } }

    /// A faint, slow drift so the charm sways while you work instead of hanging
    /// dead still. Set to 0 for a charm that only moves when something moves it.
    var breezeStrength: Double = 260

    /// Called with a point in view coordinates when the user places the charm.
    var onPositionChosen: ((CGPoint) -> Void)?

    /// Called while the charm is being dragged to a new spot. `isFinal` is true
    /// on release, which is the only point worth persisting.
    var onAnchorDragged: ((CGPoint, _ isFinal: Bool) -> Void)?

    /// Whether the charm can be grabbed. With this off it is purely decorative
    /// and never takes a click, but the pointer can still bat it around.
    var catchesPointer = true {
        didSet { releasePointerCaptureIfNeeded() }
    }

    private var rope = Rope(anchor: .zero, length: 92)
    private var frameLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval?
    private var breezePhase: Double = .random(in: 0..<(2 * .pi))
    private var preview: CGPoint?

    /// Pointer interaction state.
    private var lastCursor: CGPoint?
    private var isGrabbed = false
    private var isMovingAnchor = false
    private var grabOrigin: CGPoint?
    private var didDragWhileGrabbed = false
    private var hasPointerCapture = false

    /// The rope's bounding box last time it was drawn, so the swept region can
    /// be invalidated without redrawing the whole screen.
    private var lastDrawnBounds: CGRect?

    /// How close the pointer has to be before the charm can be grabbed, and
    /// before the rope starts getting batted around, relative to the charm size.
    private static let grabRadiusScale: Double = 0.85
    private static let pushRadiusScale: Double = 2.6
    private static let pushStrength: Double = 7000
    /// The rope length the breeze was tuned against.
    private static let referenceLength: Double = 92
    /// Thread, not string. Kept fine so a large charm reads as hanging from it.
    private static let threadWidth: Double = 2

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { isPositioning }

    /// True while the user is doing something to the charm. Anything that would
    /// re-resolve the charm's position from its stored placement has to stand
    /// down while this is set, or it will yank the charm out of the user's hand.
    var isInteracting: Bool { isGrabbed || isPositioning }

    /// While true the window is capturing clicks, so the mode is drawn loudly
    /// enough that nobody wonders why their clicks stopped working.
    var isPositioning = false {
        didSet {
            preview = nil
            if !isPositioning {
                // Leaving the mode must not strand a stale capture flag, or the
                // charm stays ungrabbable until the pointer wanders off and back.
                hasPointerCapture = false
                window?.ignoresMouseEvents = true
            }
            needsDisplay = true
        }
    }

    var cordLength: Double {
        get { rope.length }
        set {
            guard newValue != rope.length else { return }
            rope.length = newValue
            invalidateRope()
        }
    }

    /// Move the rope somewhere else outright, with no whip. For a placement
    /// change or a display change, where a lash across the screen would be an
    /// artefact rather than an effect.
    func jump(to point: CGPoint) {
        rope.placeAnchor(at: point)
        invalidateRope()
    }

    // MARK: - Frame loop

    func startAnimating() {
        guard frameLink == nil else { return }
        let link = displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        frameLink = link
    }

    func stopAnimating() {
        frameLink?.invalidate()
        frameLink = nil
        lastFrameTime = nil
        lastCursor = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastFrameTime = now }
        guard let last = lastFrameTime else { return }
        let dt = now - last
        guard dt > 0 else { return }

        let cursor = cursorInView()
        defer { lastCursor = cursor }

        updatePointerCapture(cursor: cursor)

        if isGrabbed, let cursor {
            // A plain drag pulls the charm about on its rope and lets it
            // spring back — the rope's resting length is never touched.
            // Command-drag is the one that rehangs it somewhere else.
            isMovingAnchor = NSEvent.modifierFlags.contains(.command)

            if isMovingAnchor {
                // Sliding it to a new column: the charm keeps its hanging
                // height and only travels sideways.
                rope.holdEnd(at: CGPoint(x: cursor.x, y: rope.anchor.y - rope.length))
                onAnchorDragged?(cursor, false)
            } else {
                // Pulling it about: the charm tracks the pointer exactly while
                // the rope between is left free to bow, trail, and stretch.
                rope.holdEnd(at: cursor)
            }
            if let origin = grabOrigin, hypot(cursor.x - origin.x, cursor.y - origin.y) > 3 {
                didDragWhileGrabbed = true
            }
        }

        rope.step(dt: dt, wind: breeze(dt: dt), push: pointerPush(cursor: cursor, dt: dt))
        invalidateRope()
    }

    /// A slow, wandering sideways drift.
    private func breeze(dt: Double) -> CGVector {
        guard breezeStrength > 0 else { return CGVector(dx: 0, dy: 0) }
        breezePhase += dt * 0.9
        // Two detuned sines beat against each other, so the drift never settles
        // into an obvious loop the eye can latch onto.
        let wander = sin(breezePhase) * 0.6 + sin(breezePhase * 0.37 + 1.1) * 0.4
        // A long rope covers far more ground for the same push, so ease off as
        // it grows. Without this, a charm hung near the bottom flails.
        let scale = (Self.referenceLength / max(rope.length, 1)).clamped(to: 0.2...1)
        return CGVector(dx: wander * breezeStrength * scale, dy: 0)
    }

    // MARK: - Pointer

    /// The pointer, in this view's coordinates.
    ///
    /// Polled from `NSEvent.mouseLocation` rather than watched with a global
    /// monitor, so the charm can react to the pointer without the app ever
    /// asking for permission to observe input it has no business seeing.
    private func cursorInView() -> CGPoint? {
        guard let window else { return nil }
        return convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
    }

    /// A shove away from a pointer sweeping past. Because it acts on whichever
    /// nodes are nearby rather than on the charm alone, sweeping through the
    /// middle of the rope bends it there.
    ///
    /// Scaled by how fast the pointer is moving: a pointer parked against the
    /// rope should leave it alone rather than pinning it to one side.
    private func pointerPush(cursor: CGPoint?, dt: Double) -> Rope.Push? {
        guard catchesPointer, !isGrabbed, let cursor, let previous = lastCursor else { return nil }

        let speed = hypot(cursor.x - previous.x, cursor.y - previous.y) / dt
        guard speed > 40 else { return nil }

        let dx = cursor.x - previous.x
        let dy = cursor.y - previous.y
        let travel = max(hypot(dx, dy), 1e-9)
        let strength = Self.pushStrength * min(1, speed / 400)

        // Shove along the direction of travel: the rope is swept aside by the
        // pointer going past, rather than repelled from a fixed point.
        return Rope.Push(
            point: cursor,
            acceleration: CGVector(dx: dx / travel * strength, dy: dy / travel * strength),
            radius: charmSize * Self.pushRadiusScale
        )
    }

    /// `ignoresMouseEvents` is a whole-window switch, so it is flipped on only
    /// while the pointer is actually over the charm. Everywhere else on the
    /// screen, and at every other moment, clicks pass straight through.
    private func updatePointerCapture(cursor: CGPoint?) {
        guard !isPositioning else { return }

        var wanted = false
        if catchesPointer, let cursor {
            let end = rope.endPoint
            wanted = isGrabbed
                || hypot(end.x - cursor.x, end.y - cursor.y) <= charmSize * Self.grabRadiusScale
        }

        guard wanted != hasPointerCapture else { return }
        hasPointerCapture = wanted
        window?.ignoresMouseEvents = !wanted
        invalidateRope()
    }

    private func releasePointerCaptureIfNeeded() {
        guard !catchesPointer, hasPointerCapture else { return }
        hasPointerCapture = false
        isGrabbed = false
        rope.releaseEnd()
        window?.ignoresMouseEvents = true
        invalidateRope()
    }

    /// Called when the user asks for the charm: a shove, so it drops in swinging.
    func nudge() {
        rope.nudge(CGVector(dx: .random(in: 14...22) * (Bool.random() ? 1 : -1), dy: 0))
    }

    func settle() {
        rope.settle()
        invalidateRope()
    }

    // MARK: - Invalidation

    private func invalidateRope() {
        var region = CGRect(x: rope.anchor.x, y: rope.anchor.y, width: 0, height: 0)
        for node in rope.nodes {
            region = region.union(CGRect(x: node.position.x, y: node.position.y, width: 0, height: 0))
        }
        // The charm and its hover ring hang off the end, so allow for them.
        region = region.insetBy(dx: -charmSize * 1.5, dy: -charmSize * 1.5)

        if isPositioning {
            needsDisplay = true
        } else {
            setNeedsDisplay(region.union(lastDrawnBounds ?? region))
        }
        lastDrawnBounds = region
    }

    // MARK: - Interaction

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isPositioning {
            updatePreview(with: event)
            return
        }
        guard catchesPointer else { return }
        isGrabbed = true
        isMovingAnchor = event.modifierFlags.contains(.command)
        grabOrigin = convert(event.locationInWindow, from: nil)
        didDragWhileGrabbed = false
    }

    override func mouseDragged(with event: NSEvent) {
        if isPositioning {
            updatePreview(with: event)
        }
        // A plain drag is followed by the frame loop from the polled pointer,
        // which keeps moving even when AppKit coalesces drag events away.
    }

    override func mouseUp(with event: NSEvent) {
        if isPositioning {
            preview = nil
            onPositionChosen?(convert(event.locationInWindow, from: nil))
            return
        }
        guard isGrabbed else { return }

        let point = convert(event.locationInWindow, from: nil)
        isGrabbed = false
        grabOrigin = nil
        // Verlet keeps the velocity the charm was dragged at, so simply letting
        // it go throws it — and a stretched rope recoils on its own.
        rope.releaseEnd()

        if isMovingAnchor {
            isMovingAnchor = false
            onAnchorDragged?(point, true)
        } else if !didDragWhileGrabbed {
            // A click without a drag is a request for a swing.
            nudge()
        }
        didDragWhileGrabbed = false
    }

    private func updatePreview(with event: NSEvent) {
        preview = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    // MARK: - Drawing

    /// A warm cord in both themes. `labelColor` would make it grey, and a rope
    /// reads as a rope partly because of its colour.
    private static let cordColor = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0.74, green: 0.56, blue: 0.26, alpha: 0.95)
            : NSColor(srgbRed: 0.40, green: 0.28, blue: 0.11, alpha: 0.90)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isPositioning {
            drawPositioningBackdrop()
        }

        // While positioning, the charm follows the pointer from an anchor
        // directly above it, which is where it will hang once dropped.
        if let preview {
            // Only the column is being chosen, so preview it at the height the
            // charm will actually hang at rather than under the pointer.
            let anchor = CGPoint(x: preview.x, y: bounds.maxY)
            let preview = CGPoint(x: preview.x, y: bounds.maxY - rope.length)
            let path = NSBezierPath()
            path.move(to: anchor)
            path.line(to: preview)
            path.lineWidth = Self.threadWidth
            path.lineCapStyle = .round
            Self.cordColor.setStroke()
            path.stroke()
            drawCharm(at: preview, angle: 0)
            return
        }

        let path = ropePath()
        path.lineWidth = Self.threadWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        Self.cordColor.setStroke()
        path.stroke()

        drawCharm(at: rope.endPoint, angle: rope.endAngle)
    }

    /// A smooth curve through the rope's nodes.
    ///
    /// Catmull-Rom, converted to the cubic Béziers `NSBezierPath` speaks. Joining
    /// the nodes with straight lines would show every one of them as a crease
    /// once the rope bends.
    private func ropePath() -> NSBezierPath {
        let points = rope.nodes.map(\.position)
        let path = NSBezierPath()
        guard points.count > 1 else { return path }

        path.move(to: points[0])
        for index in 0..<(points.count - 1) {
            let before = points[max(index - 1, 0)]
            let start = points[index]
            let end = points[index + 1]
            let after = points[min(index + 2, points.count - 1)]

            path.curve(
                to: end,
                controlPoint1: CGPoint(
                    x: start.x + (end.x - before.x) / 6,
                    y: start.y + (end.y - before.y) / 6
                ),
                controlPoint2: CGPoint(
                    x: end.x - (after.x - start.x) / 6,
                    y: end.y - (after.y - start.y) / 6
                )
            )
        }
        return path
    }

    private func drawCharm(at point: CGPoint, angle: Double) {
        // A ring while the pointer is on the charm, so it is obvious that this
        // one spot is live and everywhere else is still click-through.
        if hasPointerCapture {
            let radius = charmSize * Self.grabRadiusScale
            NSColor.labelColor.withAlphaComponent(isGrabbed ? 0.22 : 0.12).setFill()
            NSBezierPath(ovalIn: CGRect(
                x: point.x - radius, y: point.y - radius,
                width: radius * 2, height: radius * 2
            )).fill()
        }

        let text = NSAttributedString(
            string: charm.glyph,
            attributes: [.font: NSFont.systemFont(ofSize: charmSize)]
        )
        let size = text.size()

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        // Hang the charm off the rope's last segment, so it tips with the rope
        // rather than staying stubbornly upright.
        let transform = NSAffineTransform()
        transform.translateX(by: point.x, yBy: point.y)
        transform.rotate(byRadians: -angle)
        transform.concat()
        text.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2))
        context.restoreGraphicsState()
    }

    private func drawPositioningBackdrop() {
        NSColor.black.withAlphaComponent(0.18).setFill()
        bounds.fill()

        let text = NSAttributedString(
            string: "Click to choose the column the charm hangs in",
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
        )
        let size = text.size()
        let padding = NSSize(width: 18, height: 10)
        let box = NSRect(
            x: bounds.midX - (size.width + padding.width * 2) / 2,
            y: bounds.midY - (size.height + padding.height * 2) / 2,
            width: size.width + padding.width * 2,
            height: size.height + padding.height * 2
        )

        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: box, xRadius: 10, yRadius: 10).fill()
        text.draw(at: NSPoint(x: box.minX + padding.width, y: box.minY + padding.height))
    }
}
