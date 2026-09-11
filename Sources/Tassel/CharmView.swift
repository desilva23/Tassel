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
    /// Which stage of a staged ritual to draw, for a charm that has one.
    var ritualStage = 0 { didSet { invalidateRope() } }
    var charmSize: Double = 44 { didSet { invalidateRope() } }
    var showsOrnaments = true { didSet { invalidateRope() } }
    /// How solid the charm looks. Falls as its ritual goes untended, so a
    /// neglected charm looks neglected rather than announcing itself.
    var charmOpacity: Double = 1 {
        didSet {
            guard abs(charmOpacity - oldValue) > 0.001 else { return }
            invalidateRope()
        }
    }

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
    /// What the pointer is on, and what a drag from there will do.
    enum GrabTarget {
        /// The charm: pulling it stretches the rope, and it recoils.
        case charm
        /// The rope itself: dragging it carries the whole thing sideways.
        case rope
    }

    private var isGrabbed = false
    private var grabTarget: GrabTarget?
    /// From the pointer to the rope's end, fixed when the charm is taken hold
    /// of, so the charm stays under the pointer where it was gripped.
    private var grabOffset = CGVector(dx: 0, dy: 0)
    private var hoverTarget: GrabTarget?
    private var grabOrigin: CGPoint?
    private var didDragWhileGrabbed = false
    private var hasPointerCapture = false
    private var isShowingHandCursor = false

    /// The rope's bounding box last time it was drawn, so the swept region can
    /// be invalidated without redrawing the whole screen.
    private var lastDrawnBounds: CGRect?

    /// How close the pointer has to be before the charm can be grabbed, and
    /// before the rope starts getting batted around, relative to the charm size.
    private static let grabRadiusScale: Double = 0.85
    /// How close counts as being on the rope, in points. Generous, because the
    /// thread is two points wide and nobody can hit that.
    private static let ropeGrabDistance: Double = 10
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
        hoverTarget = nil
        updateCursor()
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
            // What you took hold of decides what the drag does. Pulling the
            // charm stretches the rope and lets it recoil; pulling the rope
            // carries the whole thing to another column.
            switch grabTarget {
            case .charm:
                rope.holdEnd(at: CGPoint(x: cursor.x + grabOffset.dx, y: cursor.y + grabOffset.dy))
            case .rope:
                onAnchorDragged?(cursor, false)
            case nil:
                break
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

        let target = cursor.flatMap(hitTarget(at:))
        if target != hoverTarget {
            hoverTarget = target
            invalidateRope()
        }

        updateCursor()

        let wanted = catchesPointer && (isGrabbed || target != nil)
        guard wanted != hasPointerCapture else { return }
        hasPointerCapture = wanted
        window?.ignoresMouseEvents = !wanted
        invalidateRope()
    }

    /// An open hand over anything that can be taken hold of, a closed one while
    /// it is being held.
    ///
    /// Cursor *rects* would be the tidy way to do this, but they only apply to
    /// the key window and this app never becomes key, so the cursor is set
    /// directly. It is re-set every frame rather than only on the way in:
    /// AppKit resets the cursor as the pointer moves inside a window with no
    /// cursor rects of its own, so setting it once would not stick.
    private func updateCursor() {
        let wanted: NSCursor? = {
            guard catchesPointer, !isPositioning else { return nil }
            if isGrabbed { return .closedHand }
            return hoverTarget == nil ? nil : .openHand
        }()

        if let wanted {
            isShowingHandCursor = true
            wanted.set()
        } else if isShowingHandCursor {
            // Only on the way out. Doing this every frame would fight whichever
            // app is under the pointer for the rest of the screen.
            isShowingHandCursor = false
            NSCursor.arrow.set()
        }
    }

    /// The charm wins ties: it sits on the end of the rope, so near the bottom
    /// both are in range, and pulling the charm is the more likely intent.
    private func hitTarget(at point: CGPoint) -> GrabTarget? {
        guard catchesPointer else { return nil }
        if charmContains(point) {
            return .charm
        }
        if rope.distance(to: point) <= Self.ropeGrabDistance {
            return .rope
        }
        return nil
    }

    /// Whether `point` is on the charm as it is actually drawn.
    ///
    /// Tested in the charm's own frame — rope's end at the origin, rope's
    /// direction as down — so a charm swung out at an angle is hit where it is,
    /// not where it would be hanging straight. A glyph is centred on the rope's
    /// end, but artwork hangs below it, so a circle round the end would miss
    /// most of a daruma.
    private func charmContains(_ point: CGPoint) -> Bool {
        let local = point.applying(
            Rope.placement(at: rope.endPoint, heading: rope.endAngle).inverted()
        )
        guard let artwork = currentArtwork else {
            return hypot(local.x, local.y) <= charmSize * Self.grabRadiusScale
        }
        let box = Artwork.contentBox(
            content: artwork.content,
            aspect: artwork.aspect,
            charmSize: charmSize,
            hanging: true
        )
        // A little slack round the edge, because nobody clicks a silhouette
        // to the pixel.
        return box.insetBy(dx: -6, dy: -6).contains(local)
    }

    private func releasePointerCaptureIfNeeded() {
        guard !catchesPointer, hasPointerCapture else { return }
        hasPointerCapture = false
        isGrabbed = false
        hoverTarget = nil
        rope.releaseEnd()
        window?.ignoresMouseEvents = true
        updateCursor()
        invalidateRope()
    }

    /// Called when the user asks for the charm: a shove, so it drops in swinging.
    func nudge() {
        rope.nudge(CGVector(dx: .random(in: 420...620) * (Bool.random() ? 1 : -1), dy: 0))
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
        if event.modifierFlags.contains(.control) {
            // Control-click is a right-click on a Mac.
            rightMouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        guard let target = hitTarget(at: point) else { return }
        isGrabbed = true
        grabTarget = target
        grabOrigin = point
        grabOffset = CGVector(dx: rope.endPoint.x - point.x, dy: rope.endPoint.y - point.y)
        didDragWhileGrabbed = false
        updateCursor()
    }

    /// Supplies the menu shown when the charm is right-clicked.
    var contextMenu: (() -> NSMenu?)?

    /// Right-click, or Control-click, on the charm or its rope offers the
    /// charm's ritual right there, rather than making you go and find it in the
    /// menu bar.
    override func rightMouseDown(with event: NSEvent) {
        guard !isPositioning else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hitTarget(at: point) != nil, let menu = contextMenu?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
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
        let target = grabTarget
        isGrabbed = false
        grabTarget = nil
        grabOrigin = nil

        switch target {
        case .charm:
            // Letting go of a stretched rope lets it recoil on its own.
            rope.releaseEnd()
            if !didDragWhileGrabbed {
                // A click without a drag is a request for a swing.
                nudge()
            }
        case .rope:
            onAnchorDragged?(point, true)
        case nil:
            break
        }
        didDragWhileGrabbed = false
        updateCursor()
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

    /// Bone, in both themes.
    private static let beadColor = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.94, green: 0.92, blue: 0.86, alpha: 1)
            : NSColor(srgbRed: 0.99, green: 0.98, blue: 0.94, alpha: 1)
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
        // Thicker while the pointer is on it, so it reads as grabbable. Without
        // this nobody would guess the thread does anything.
        path.lineWidth = hoverTarget == .rope ? Self.threadWidth + 1.5 : Self.threadWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        Self.cordColor.setStroke()
        path.stroke()

        // The rope keeps its colour; only what hangs on it fades, so the fading
        // reads as the charm going untended rather than the whole thing dimming.
        let context = NSGraphicsContext.current
        context?.saveGraphicsState()
        context?.cgContext.setAlpha(charmOpacity.clamped(to: 0.05...1))

        if showsOrnaments {
            drawOrnaments()
        }
        drawCharm(at: rope.endPoint, angle: rope.endAngle)

        context?.restoreGraphicsState()
    }

    /// Beads and a smaller charm, threaded on the rope above the main one.
    private func drawOrnaments() {
        let threading = Ornament.layout(
            charm.threading,
            charmSize: charmSize,
            ropeLength: rope.arcLength
        )

        for (ornament, fraction) in threading {
            let point = rope.point(atFraction: fraction)
            let lean = rope.tangentAngle(atFraction: fraction) + ornament.rotation

            switch ornament.shape {
            case .bead:
                let radius = charmSize * ornament.scale
                let box = CGRect(
                    x: point.x - radius, y: point.y - radius,
                    width: radius * 2, height: radius * 2
                )
                Self.beadColor.setFill()
                NSBezierPath(ovalIn: box).fill()

                let rim = NSBezierPath(ovalIn: box.insetBy(dx: 0.4, dy: 0.4))
                rim.lineWidth = 0.8
                Self.cordColor.withAlphaComponent(0.45).setStroke()
                rim.stroke()

            case .echo:
                drawCharmBody(size: charmSize * ornament.scale, at: point, angle: lean, hanging: false)

            case let .glyph(text):
                drawGlyph(text, size: charmSize * ornament.scale, at: point, angle: lean)
            }
        }
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
        drawCharmBody(size: charmSize, at: point, angle: angle, hanging: true)
    }

    /// The charm's glyph, tipped to lie along the rope rather than staying
    /// stubbornly upright.
    /// The charm itself: drawn artwork when it has any, its glyph otherwise.
    ///
    /// - Parameter hanging: true for the charm on the end, which hangs *from*
    ///   the point; false for one threaded onto the rope, which the rope passes
    ///   through and which therefore sits centred on it. Getting this wrong
    ///   makes a threaded charm droop into whatever bead is below it.
    /// The artwork showing right now: the ritual stage's, then the charm's own.
    /// Nil means the glyph is drawn — a missing file should cost the charm its
    /// look, never its presence.
    private var currentArtwork: ArtworkStore.Loaded? {
        let names = [charm.artwork(atStage: ritualStage), charm.artwork].compactMap { $0 }
        return names.lazy.compactMap(ArtworkStore.artwork(named:)).first
    }

    private func drawCharmBody(size: Double, at point: CGPoint, angle: Double, hanging: Bool) {
        if let artwork = currentArtwork {
            drawArtwork(artwork, size: size, at: point, angle: angle, hanging: hanging)
        } else {
            drawGlyph(charm.glyph, size: size, at: point, angle: angle)
        }
    }

    /// Artwork hangs *from* the anchor marked on the drawing template, rather
    /// than being centred on the rope's end the way a glyph is. That is what
    /// lets a drawn charm have a loop or a knot at its top and have the rope
    /// meet it exactly there.
    private func drawArtwork(
        _ artwork: ArtworkStore.Loaded,
        size: Double,
        at point: CGPoint,
        angle: Double,
        hanging: Bool
    ) {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.cgContext.concatenate(Rope.placement(at: point, heading: angle))

        artwork.image.draw(
            in: Artwork.drawRect(
                content: artwork.content,
                aspect: artwork.aspect,
                charmSize: size,
                hanging: hanging
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        context.restoreGraphicsState()
    }

    private func drawGlyph(_ glyph: String, size: Double, at point: CGPoint, angle: Double) {
        let text = NSAttributedString(
            string: glyph,
            attributes: [.font: NSFont.systemFont(ofSize: size)]
        )
        let measured = text.size()

        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.cgContext.concatenate(Rope.placement(at: point, heading: angle))
        text.draw(at: NSPoint(x: -measured.width / 2, y: -measured.height / 2))
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
