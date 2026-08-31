import AppKit
import QuartzCore
import TasselCore

/// Draws the cord and the charm, runs the simulation once per displayed frame,
/// and handles drag-to-position.
///
/// The view covers the whole screen so the charm can hang anywhere on it, which
/// means redrawing the full bounds every frame would be wasteful. Only the swept
/// region is invalidated instead.
final class CharmView: NSView {
    /// Where the cord is nailed down, in this view's coordinates.
    var pivot: CGPoint = .zero {
        didSet {
            guard pivot != oldValue else { return }
            invalidateArc()
        }
    }

    var charm: Charm = .fallback { didSet { invalidateArc() } }
    var charmSize: Double = 28 { didSet { invalidateArc() } }

    /// A faint, slow drift so the charm sways while you work instead of hanging
    /// dead still. Set to 0 for a charm that only moves when something moves it.
    var breezeStrength: Double = 220

    /// Called with a point in view coordinates when the user places the charm.
    var onPositionChosen: ((CGPoint) -> Void)?

    /// Called while the charm's anchor is being dragged with Command held.
    /// `isFinal` is true on release, which is the only point worth persisting.
    var onAnchorDragged: ((CGPoint, _ isFinal: Bool) -> Void)?

    /// Whether the charm can be grabbed. With this off it is purely decorative
    /// and never takes a click, but the pointer can still bat it around.
    var catchesPointer = true {
        didSet { releasePointerCaptureIfNeeded() }
    }

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

    private var pendulum = Pendulum()
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
    private var anchorDragSpeed: Double = 0
    private var hasPointerCapture = false

    /// How close the pointer has to be before the charm can be grabbed, and
    /// before it starts getting batted around, as multiples of the charm size.
    private static let grabRadiusScale: Double = 0.85
    private static let pushRadiusScale: Double = 2.6
    private static let pushStrength: Double = 6500

    /// Pivot motion is differenced twice to get the pseudo-force that makes the
    /// charm lag behind when its anchor is yanked sideways.
    private var lastPivotOnScreen: CGPoint?
    private var lastPivotVelocity = CGVector(dx: 0, dy: 0)

    /// The bob position drawn last frame, so the swept region can be invalidated.
    private var lastDrawnBob: CGPoint?

    /// The cord length the breeze was tuned against.
    private static let referenceLength: Double = 92

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { isPositioning }

    /// True while the user is doing something to the charm. Anything that would
    /// re-resolve the charm's position from its stored placement has to stand
    /// down while this is set, or it will yank the charm out of the user's hand.
    var isInteracting: Bool { isGrabbed || isPositioning }

    var cordLength: Double {
        get { pendulum.length }
        set {
            guard newValue != pendulum.length else { return }
            pendulum.length = newValue
            invalidateArc()
        }
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
        lastPivotOnScreen = nil
        lastPivotVelocity = CGVector(dx: 0, dy: 0)
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

        if isGrabbed {
            // Dragging a thing moves it — that is what everyone reaches for
            // first. Command-drag is the one that swings it in place instead.
            isMovingAnchor = !NSEvent.modifierFlags.contains(.command)
            if let cursor {
                if isMovingAnchor {
                    // Let the swing settle while the anchor moves, so the charm
                    // sits exactly under the pointer instead of trailing it.
                    pendulum.reset()
                    if let previous = lastCursor {
                        // Remembered so letting go can throw it.
                        let velocity = (cursor.x - previous.x) / dt
                        anchorDragSpeed = anchorDragSpeed * 0.6 + velocity * 0.4
                    }
                    onAnchorDragged?(cursor, false)
                } else {
                    // Follow the pointer along the cord. Releasing keeps the
                    // speed this implies, so the charm can be thrown.
                    pendulum.hold(
                        towards: CGPoint(x: cursor.x - pivot.x, y: cursor.y - pivot.y),
                        dt: dt
                    )
                }
                if let origin = grabOrigin, hypot(cursor.x - origin.x, cursor.y - origin.y) > 3 {
                    didDragWhileGrabbed = true
                }
            }
        } else {
            pendulum.step(
                dt: dt,
                pivotAcceleration: acceleration(dt: dt),
                bobAcceleration: pointerPush(cursor: cursor, dt: dt)
            )
        }

        invalidateArc()
    }

    // MARK: - Pointer

    /// The pointer, in this view's coordinates.
    ///
    /// Polled from `NSEvent.mouseLocation` rather than watched with a global
    /// monitor, so the charm can react to the pointer without the app ever
    /// asking to observe input it has no business seeing.
    private func cursorInView() -> CGPoint? {
        guard let window else { return nil }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return convert(inWindow, from: nil)
    }

    /// A shove away from a pointer sweeping past, so the charm can be batted.
    ///
    /// Scaled by how fast the pointer is moving: a pointer parked next to the
    /// charm should leave it alone rather than pinning it to one side.
    private func pointerPush(cursor: CGPoint?, dt: Double) -> CGVector {
        guard catchesPointer, let cursor, let previous = lastCursor else {
            return CGVector(dx: 0, dy: 0)
        }

        let bob = bobPosition
        let distance = hypot(bob.x - cursor.x, bob.y - cursor.y)
        let radius = charmSize * Self.pushRadiusScale
        guard distance > 1, distance < radius else { return CGVector(dx: 0, dy: 0) }

        let speed = hypot(cursor.x - previous.x, cursor.y - previous.y) / dt
        let proximity = 1 - distance / radius
        let strength = Self.pushStrength * proximity * min(1, speed / 400)

        return CGVector(
            dx: (bob.x - cursor.x) / distance * strength,
            dy: (bob.y - cursor.y) / distance * strength
        )
    }

    /// `ignoresMouseEvents` is a whole-window switch, so it is flipped on only
    /// while the pointer is actually over the charm. Everywhere else on the
    /// screen, and at every other moment, clicks pass straight through.
    private func updatePointerCapture(cursor: CGPoint?) {
        guard !isPositioning else { return }

        var wanted = false
        if catchesPointer, let cursor {
            let bob = bobPosition
            wanted = isGrabbed
                || hypot(bob.x - cursor.x, bob.y - cursor.y) <= charmSize * Self.grabRadiusScale
        }

        guard wanted != hasPointerCapture else { return }
        hasPointerCapture = wanted
        window?.ignoresMouseEvents = !wanted
        invalidateArc()
    }

    private func releasePointerCaptureIfNeeded() {
        guard !catchesPointer, hasPointerCapture else { return }
        hasPointerCapture = false
        isGrabbed = false
        window?.ignoresMouseEvents = true
        invalidateArc()
    }

    /// Ambient breeze plus whatever the pivot itself is doing.
    private func acceleration(dt: Double) -> CGVector {
        breezePhase += dt * 0.9
        // Two detuned sines beat against each other, so the drift never settles
        // into an obvious loop the eye can latch onto.
        let breeze = sin(breezePhase) * 0.6 + sin(breezePhase * 0.37 + 1.1) * 0.4

        // A long cord swings through the same angle for a given push but covers
        // far more distance doing it, so ease off as the cord grows. Without
        // this, a charm hung near the bottom of the screen flails.
        let scale = (Self.referenceLength / max(pendulum.length, 1)).clamped(to: 0.15...1)

        var ax = breeze * breezeStrength * scale
        var ay = 0.0

        if let window {
            let screenPivot = window.convertPoint(toScreen: convert(pivot, to: nil))
            if let previous = lastPivotOnScreen {
                let velocity = CGVector(
                    dx: (screenPivot.x - previous.x) / dt,
                    dy: (screenPivot.y - previous.y) / dt
                )
                ax += (velocity.dx - lastPivotVelocity.dx) / dt
                ay += (velocity.dy - lastPivotVelocity.dy) / dt
                lastPivotVelocity = velocity
            }
            lastPivotOnScreen = screenPivot
        }

        // A teleporting pivot (screen change, display wake) would otherwise
        // produce an absurd impulse.
        return CGVector(dx: ax.clamped(to: -6000...6000), dy: ay.clamped(to: -6000...6000))
    }

    /// Called when the user asks for the charm: a shove, so it drops in swinging.
    func nudge() {
        pendulum.nudge(angularVelocity: .random(in: 4...7) * (Bool.random() ? 1 : -1))
    }

    func settle() {
        pendulum.reset()
        invalidateArc()
    }

    // MARK: - Invalidation

    private var bobPosition: CGPoint {
        let offset = pendulum.bobOffset
        return CGPoint(x: pivot.x + offset.x, y: pivot.y + offset.y)
    }

    /// Invalidate the region swept between the last drawn frame and this one.
    private func invalidateArc() {
        guard !isPositioning else {
            needsDisplay = true
            return
        }
        let bob = bobPosition
        var region = CGRect(
            x: min(pivot.x, bob.x),
            y: min(pivot.y, bob.y),
            width: abs(pivot.x - bob.x),
            height: abs(pivot.y - bob.y)
        )
        if let previous = lastDrawnBob {
            region = region.union(CGRect(x: previous.x, y: previous.y, width: 0, height: 0))
        }
        // Inflate by the charm's own extent plus a little for the cord's width.
        setNeedsDisplay(region.insetBy(dx: -charmSize * 2, dy: -charmSize * 2))
    }

    // MARK: - Positioning

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isPositioning {
            updatePreview(with: event)
            return
        }
        guard catchesPointer else { return }
        isGrabbed = true
        isMovingAnchor = !event.modifierFlags.contains(.command)
        anchorDragSpeed = 0
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

        if isMovingAnchor {
            isMovingAnchor = false
            onAnchorDragged?(point, true)
            // Let go while moving and the charm keeps going, so it can be slung
            // into its new spot rather than just appearing there.
            let thrown = anchorDragSpeed / max(pendulum.length, 1)
            pendulum.nudge(angularVelocity: thrown.clamped(to: -12 ... 12))
            anchorDragSpeed = 0
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

    override func draw(_ dirtyRect: NSRect) {
        if isPositioning {
            drawPositioningBackdrop()
        }

        // While positioning, the charm follows the cursor from a pivot directly
        // above it, which is exactly where it will hang once dropped.
        let anchor = preview.map { CGPoint(x: $0.x, y: bounds.maxY) } ?? pivot
        let bob = preview ?? bobPosition
        let lean = preview == nil ? pendulum.angle : 0

        let cord = NSBezierPath()
        cord.move(to: anchor)
        cord.line(to: bob)
        cord.lineWidth = 1.5
        cord.lineCapStyle = .round
        NSColor.labelColor.withAlphaComponent(0.35).setStroke()
        cord.stroke()

        // A ring while the pointer is on the charm, so it is obvious that this
        // one spot is live and everywhere else is still click-through.
        if hasPointerCapture {
            let radius = charmSize * Self.grabRadiusScale
            let ring = NSBezierPath(ovalIn: CGRect(
                x: bob.x - radius, y: bob.y - radius,
                width: radius * 2, height: radius * 2
            ))
            NSColor.labelColor.withAlphaComponent(isGrabbed ? 0.22 : 0.12).setFill()
            ring.fill()
        }

        let text = NSAttributedString(
            string: charm.glyph,
            attributes: [.font: NSFont.systemFont(ofSize: charmSize)]
        )
        let size = text.size()

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        // Hang the charm off the cord: rotating by the swing angle keeps it
        // pointing along the cord rather than staying stubbornly upright.
        let transform = NSAffineTransform()
        transform.translateX(by: bob.x, yBy: bob.y)
        transform.rotate(byRadians: -lean)
        transform.concat()
        text.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2))
        context.restoreGraphicsState()

        lastDrawnBob = bob
    }

    private func drawPositioningBackdrop() {
        NSColor.black.withAlphaComponent(0.18).setFill()
        bounds.fill()

        let message = "Click anywhere to hang the charm there"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: message, attributes: attributes)
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
