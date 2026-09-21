import AppKit

// Renders the physics clips for the brag video from TasselCore's own Rope, as
// PNG frames. Compiled together with Sources/TasselCore:
//
//   swiftc -O Sources/TasselCore/*.swift brag-output/clip-renderer/main.swift -o render
//   BG=dusk render <repo> main <frames-dir>
//
// The desktop is a real 1440x900-point screen, y up — this Mac's own, a 2560x1600
// panel at 2x — with a 24pt menu bar and a 44pt charm on a 150pt cord, the app's
// defaults at the size they really are. A camera then frames part of that screen
// into the 1920x1080 video: wide it shows the screen's full width (the empty
// bottom 90pt fall outside a 16:9 frame), and pushed in it makes the close work
// legible without anything being drawn larger than life.

let arguments = CommandLine.arguments
let repo = arguments[1], clip = arguments[2], outDir = arguments[3]
let W: CGFloat = 1440, H: CGFloat = 900, fps = 30.0, substeps = 8
// The video frame, supersampled; the encode step scales it back to 1920x1080.
// CUT=wide gives the 16:9 video; CUT=tall gives the 4:5 one for a phone feed.
let tall = ProcessInfo.processInfo.environment["CUT"] == "tall"
let frameW: CGFloat = tall ? 1080 : 1920, frameH: CGFloat = tall ? 1350 : 1080
let scale: CGFloat = 2
let barH: CGFloat = 24
let menuBottom = H - barH

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
            blue: CGFloat(v & 255) / 255, alpha: a)
}

// MARK: - Artwork, measured the way the app measures it

struct Art { let image: NSImage; let content: CGRect; let hookX: Double }
var artCache: [String: Art] = [:]
func art(_ name: String) -> Art {
    if let cached = artCache[name] { return cached }
    let image = NSImage(contentsOfFile: "\(repo)/Resources/Charms/\(name).png")!
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let m = Artwork.measure(width: rep.pixelsWide, height: rep.pixelsHigh, step: rep.pixelsWide / 200) { x, y in
        (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.08
    }
    let result = Art(image: image, content: m.content, hookX: m.hookX)
    artCache[name] = result
    return result
}

// MARK: - A charm on its cord, driven like CharmView drives it

final class Hanger {
    var rope: Rope
    var charm: Charm
    var artwork: String?
    var size: Double
    var breezePhase: Double

    init(_ charm: Charm, anchor: CGPoint, length: Double, size: Double, phase: Double) {
        rope = Rope(anchor: anchor, length: length)
        rope.settle()
        self.charm = charm
        artwork = charm.artwork
        self.size = size
        breezePhase = phase
    }

    func breeze(_ dt: Double) -> CGVector {
        breezePhase += dt * 0.9
        let wander = sin(breezePhase) * 0.6 + sin(breezePhase * 0.37 + 1.1) * 0.4
        return CGVector(dx: wander * 260 * min(max(92 / rope.length, 0.2), 1), dy: 0)
    }
}

let pushStrength = 7000.0
func pushRadius(_ h: Hanger) -> Double { h.size * 2.6 }

// MARK: - The pointer: keyframes eased segment by segment

struct Key { let t: Double; let p: CGPoint }
func pointer(_ keys: [Key], at t: Double) -> CGPoint? {
    guard let first = keys.first, let last = keys.last, t >= first.t, t <= last.t else { return nil }
    for i in 0..<(keys.count - 1) where t >= keys[i].t && t <= keys[i + 1].t {
        let a = keys[i], b = keys[i + 1]
        var u = (t - a.t) / max(b.t - a.t, 1e-9)
        u = u * u * (3 - 2 * u)
        return CGPoint(x: a.p.x + (b.p.x - a.p.x) * u, y: a.p.y + (b.p.y - a.p.y) * u)
    }
    return last.p
}

// MARK: - Drawing

// Original, procedurally drawn wallpapers. BG=dusk | aurora | desk
let background = ProcessInfo.processInfo.environment["BG"] ?? "dusk"
let lightDesktop = background == "desk"

func glow(_ colour: NSColor, at c: CGPoint, radius: CGFloat) {
    NSGradient(colors: [colour, colour.withAlphaComponent(0)])!
        .draw(fromCenter: c, radius: 0, toCenter: c, radius: radius, options: [])
}

/// A soft hill line across the wallpaper, filled down to the bottom edge.
func hill(_ colour: NSColor, base: CGFloat, amplitude: CGFloat, waves: [(CGFloat, CGFloat)]) {
    let W: CGFloat = 960
    let path = NSBezierPath()
    path.move(to: CGPoint(x: 0, y: 0))
    for i in 0...96 {
        let x = W * CGFloat(i) / 96
        let y = base + waves.reduce(0) { $0 + amplitude * sin(x / W * $1.0 * .pi * 2 + $1.1) }
        path.line(to: CGPoint(x: x, y: y))
    }
    path.line(to: CGPoint(x: W, y: 0)); path.close()
    colour.setFill(); path.fill()
}

/// The wallpaper is drawn on a 960x540 canvas and scaled up to the screen, so
/// its hills and stars keep the proportions they were designed with.
func wallpaper() {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current?.cgContext.scaleBy(x: W / 960, y: H / 540)
    drawWallpaper()
    NSGraphicsContext.restoreGraphicsState()
}

func drawWallpaper() {
    let W: CGFloat = 960, H: CGFloat = 540
    let all = NSRect(x: 0, y: 0, width: W, height: H)
    switch background {
    case "aurora":
        hex(0x0D1022).setFill(); all.fill()
        glow(hex(0x2BB5A8, 0.55), at: CGPoint(x: 150, y: 120), radius: 560)
        glow(hex(0x7B4BD6, 0.60), at: CGPoint(x: 760, y: 110), radius: 520)
        glow(hex(0xF2A541, 0.42), at: CGPoint(x: 470, y: 520), radius: 430)
        glow(hex(0xD6457E, 0.34), at: CGPoint(x: 930, y: 420), radius: 380)
    case "desk":
        NSGradient(colors: [hex(0xF3EDE4), hex(0xE4DDF0)])!.draw(in: all, angle: -80)
        glow(hex(0xF6C8A8, 0.55), at: CGPoint(x: 200, y: 120), radius: 460)
        glow(hex(0xB9C7F2, 0.50), at: CGPoint(x: 820, y: 460), radius: 420)
        // A notes window on the left, and the Dock.
        let window = NSRect(x: 48, y: 120, width: 400, height: 330)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -8); shadow.set()
        hex(0xFFFFFF, 0.92).setFill(); NSBezierPath(roundedRect: window, xRadius: 12, yRadius: 12).fill()
        NSGraphicsContext.restoreGraphicsState()
        for (i, c) in [hex(0xFF5F57), hex(0xFEBC2E), hex(0x28C840)].enumerated() {
            c.setFill(); NSBezierPath(ovalIn: NSRect(x: window.minX + 14 + CGFloat(i) * 18, y: window.maxY - 22, width: 11, height: 11)).fill()
        }
        hex(0x000000, 0.10).setFill()
        for (i, w) in [300.0, 340, 260, 320, 180, 330, 290, 220].enumerated() {
            NSBezierPath(roundedRect: NSRect(x: window.minX + 24, y: window.maxY - 60 - CGFloat(i) * 30, width: w, height: 9),
                         xRadius: 4.5, yRadius: 4.5).fill()
        }
        let dock = NSRect(x: 300, y: 8, width: 360, height: 52)
        hex(0xFFFFFF, 0.45).setFill(); NSBezierPath(roundedRect: dock, xRadius: 16, yRadius: 16).fill()
        for (i, c) in [0x4A90E2, 0xF5A623, 0x7ED321, 0xD0021B, 0x9013FE, 0x50E3C2].enumerated() {
            hex(UInt32(c)).setFill()
            NSBezierPath(roundedRect: NSRect(x: dock.minX + 14 + CGFloat(i) * 57, y: dock.minY + 7, width: 38, height: 38),
                         xRadius: 9, yRadius: 9).fill()
        }
    default: // dusk
        NSGradient(colors: [hex(0x141A3C), hex(0x3B2D66), hex(0x8C4F7E), hex(0xF0A07A)],
                   atLocations: [0, 0.45, 0.78, 1], colorSpace: .sRGB)!.draw(in: all, angle: -90)
        glow(hex(0xFFD6A0, 0.55), at: CGPoint(x: 250, y: 150), radius: 300)
        // Stars, from a fixed seed so every frame and every render agree.
        var seed: UInt32 = 20260918
        func next() -> CGFloat { seed = seed &* 1664525 &+ 1013904223; return CGFloat(seed >> 8) / CGFloat(1 << 24) }
        for _ in 0..<70 {
            let x = next() * W, y = H * 0.55 + next() * H * 0.42, r = 0.4 + next() * 0.9
            NSColor.white.withAlphaComponent(0.25 + next() * 0.5).setFill()
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: r * 2, height: r * 2)).fill()
        }
        hill(hex(0x6E4A86), base: 150, amplitude: 22, waves: [(1.2, 0.4), (2.7, 1.9)])
        hill(hex(0x46325F), base: 105, amplitude: 18, waves: [(1.6, 2.2), (3.4, 0.3)])
        hill(hex(0x261D3D), base: 55, amplitude: 14, waves: [(2.1, 1.1), (4.3, 2.6)])
    }
}

func drawStatusIcon(_ name: String, at c: CGPoint) {
    let a = art(name), s = a.image.size
    let crop = NSRect(x: a.content.minX * s.width, y: a.content.minY * s.height,
                      width: a.content.width * s.width, height: a.content.height * s.height)
    let fit = min(18 / crop.width, 18 / crop.height)
    a.image.draw(in: NSRect(x: c.x - crop.width * fit / 2, y: c.y - crop.height * fit / 2,
                            width: crop.width * fit, height: crop.height * fit),
                 from: crop, operation: .sourceOver, fraction: 1)
}

func menuBar(statusIcon: String?, iconX: CGFloat) {
    (lightDesktop ? hex(0xFFFFFF, 0.55) : hex(0x000000, 0.28)).setFill()
    NSRect(x: 0, y: menuBottom, width: W, height: barH).fill()
    let y = H - barH / 2
    if let statusIcon { drawStatusIcon(statusIcon, at: CGPoint(x: iconX, y: y)) }
    let white = lightDesktop ? NSColor.black.withAlphaComponent(0.85) : NSColor.white.withAlphaComponent(0.92)
    // The menus of an app that is open, so the bar does not look empty.
    var left: CGFloat = 16
    for (text, weight) in [("\u{F8FF}", NSFont.Weight.regular), ("Finder", .bold), ("File", .regular),
                           ("Edit", .regular), ("View", .regular), ("Go", .regular), ("Window", .regular),
                           ("Help", .regular)] {
        let item = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: weight), .foregroundColor: white,
        ])
        item.draw(at: CGPoint(x: left, y: y - item.size().height / 2))
        left += item.size().width + 18
    }
    // Laid out from the right: clock, then wifi, then battery, each clear of the next.
    let clock = NSAttributedString(string: "Fri 18 Sep  9:41", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: white,
    ])
    let clockX = W - 12 - clock.size().width
    clock.draw(at: CGPoint(x: clockX, y: y - clock.size().height / 2))
    let wifiX = clockX - 20
    for (i, r) in [3.0, 6.5, 10.0].enumerated() {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: CGPoint(x: wifiX, y: y - 5), radius: r, startAngle: 45, endAngle: 135)
        arc.lineWidth = i == 0 ? 3 : 1.8; arc.lineCapStyle = .round; white.setStroke(); arc.stroke()
    }
    let batteryX = wifiX - 44
    let body = NSBezierPath(roundedRect: NSRect(x: batteryX, y: y - 5.5, width: 22, height: 11), xRadius: 3, yRadius: 3)
    white.setStroke(); body.lineWidth = 1.1; body.stroke()
    white.setFill()
    NSBezierPath(roundedRect: NSRect(x: batteryX + 2, y: y - 3.5, width: 14, height: 7), xRadius: 1.5, yRadius: 1.5).fill()
    NSBezierPath(roundedRect: NSRect(x: batteryX + 23, y: y - 2, width: 1.8, height: 4), xRadius: 0.8, yRadius: 0.8).fill()
}

func ropePath(_ rope: Rope) -> NSBezierPath {
    let p = rope.nodes.map(\.position), path = NSBezierPath()
    path.move(to: p[0])
    for i in 0..<(p.count - 1) {
        let b = p[max(i - 1, 0)], s = p[i], e = p[i + 1], a = p[min(i + 2, p.count - 1)]
        path.curve(to: e,
                   controlPoint1: CGPoint(x: s.x + (e.x - b.x) / 6, y: s.y + (e.y - b.y) / 6),
                   controlPoint2: CGPoint(x: e.x - (a.x - s.x) / 6, y: e.y - (a.y - s.y) / 6))
    }
    return path
}

func drawBody(_ h: Hanger, size: Double, at p: CGPoint, angle: Double, hanging: Bool, ctx: CGContext) {
    ctx.saveGState()
    ctx.concatenate(Rope.placement(at: p, heading: angle))
    if let name = h.artwork {
        let a = art(name)
        a.image.draw(in: Artwork.drawRect(content: a.content, hookX: a.hookX, aspect: 1,
                                          charmSize: size * h.charm.artworkScale, hanging: hanging),
                     from: .zero, operation: .sourceOver, fraction: 1)
    } else {
        let t = NSAttributedString(string: h.charm.glyph, attributes: [.font: NSFont.systemFont(ofSize: size)])
        let m = t.size()
        t.draw(at: CGPoint(x: -m.width / 2, y: -m.height / 2))
    }
    ctx.restoreGState()
}

func drawHanger(_ h: Hanger, ctx: CGContext) {
    let cord = ropePath(h.rope)
    cord.lineWidth = 2.2; cord.lineCapStyle = .round
    hex(0xBD8F42, 0.95).setStroke(); cord.stroke()
    for (o, f) in Ornament.layout(h.charm.threading, charmSize: h.size, ropeLength: h.rope.arcLength) {
        let p = h.rope.point(atFraction: f), lean = h.rope.tangentAngle(atFraction: f) + o.rotation
        switch o.shape {
        case .bead:
            let r = h.size * o.scale
            let colour = h.charm.beadColor.map { NSColor(srgbRed: $0.red, green: $0.green, blue: $0.blue, alpha: 1) }
                ?? NSColor(srgbRed: 0.94, green: 0.92, blue: 0.86, alpha: 1)
            colour.setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)).fill()
        case .echo:
            drawBody(h, size: h.size * o.scale, at: p, angle: lean, hanging: false, ctx: ctx)
        case .glyph:
            break
        }
    }
    drawBody(h, size: h.size, at: h.rope.endPoint, angle: h.rope.endAngle, hanging: h.artwork != nil, ctx: ctx)
}

/// The hand the app puts under the pointer: open over a charm it can take hold
/// of, closed while it is holding one.
func drawHand(at p: CGPoint, closed: Bool) {
    let hand = NSBezierPath()
    func capsule(_ x: CGFloat, _ bottom: CGFloat, _ top: CGFloat, _ width: CGFloat) {
        hand.appendRoundedRect(NSRect(x: p.x + x - width / 2, y: p.y + bottom,
                                      width: width, height: top - bottom),
                               xRadius: width / 2, yRadius: width / 2)
    }
    if closed {
        // A fist: the palm, with the folded fingers as a row of knuckles.
        hand.appendRoundedRect(NSRect(x: p.x - 7.4, y: p.y - 10, width: 14.8, height: 15),
                               xRadius: 5.4, yRadius: 5.4)
        for x in stride(from: CGFloat(-5.1), through: 5.1, by: 3.4) { capsule(x, 2.5, 6.6, 3.1) }
        capsule(-8.4, -4.5, 1.5, 3.4)
    } else {
        // An open hand: palm, four fingers and a thumb held out to the side.
        hand.appendRoundedRect(NSRect(x: p.x - 7.2, y: p.y - 10, width: 14.4, height: 12),
                               xRadius: 5, yRadius: 5)
        for (x, top) in [(-5.4, 8.4), (-1.8, 10.6), (1.8, 10.2), (5.4, 7.6)] as [(CGFloat, CGFloat)] {
            capsule(x, -2, top, 3.3)
        }
        let thumb = NSBezierPath(roundedRect: NSRect(x: -1.7, y: -1.7, width: 9, height: 3.4),
                                 xRadius: 1.7, yRadius: 1.7)
        var lean = AffineTransform(translationByX: p.x - 6.4, byY: p.y - 4.2)
        lean.rotate(byDegrees: 143)
        thumb.transform(using: lean)
        hand.append(thumb)
    }
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1.5); shadow.set()
    NSColor.black.setStroke(); hand.lineWidth = 3.2; hand.lineJoinStyle = .round; hand.stroke()
    NSGraphicsContext.restoreGraphicsState()
    // The white fill covers the inner half of the outline, and with it every
    // seam between the shapes the hand is built from.
    NSColor.white.setFill(); hand.windingRule = .nonZero; hand.fill()
}

func drawCursor(at p: CGPoint) {
    let shape: [(CGFloat, CGFloat)] = [(0, 0), (0, -17), (4.2, -13.2), (7.2, -19.6), (9.8, -18.4), (6.9, -12.2), (12.2, -12.2)]
    let a = NSBezierPath()
    a.move(to: p)
    for (x, y) in shape.dropFirst() { a.line(to: CGPoint(x: p.x + x, y: p.y + y)) }
    a.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowBlurRadius = 3
    shadow.shadowOffset = NSSize(width: 0, height: -1.5); shadow.set()
    NSColor.black.setFill(); a.fill()
    NSGraphicsContext.restoreGraphicsState()
    let inner = a.copy() as! NSBezierPath
    NSColor.black.setStroke(); a.lineWidth = 1.6; a.lineJoinStyle = .round; a.stroke()
    NSColor.white.setFill(); inner.fill()
    NSColor.black.setStroke(); inner.lineWidth = 1.1; inner.lineJoinStyle = .round; inner.stroke()
}

// MARK: - The camera

/// Where the video frame sits on the screen: a centre in screen points and how
/// far in it is pushed. The whole desktop is drawn at its real size and the
/// camera decides how much of it the frame shows, so the close work is legible
/// without the charm ever being drawn bigger than it is.
struct Shot { let t: Double; let centre: CGPoint; let zoom: CGFloat }

func camera(_ shots: [Shot], at t: Double) -> (centre: CGPoint, zoom: CGFloat) {
    if t <= shots[0].t { return (shots[0].centre, shots[0].zoom) }
    for i in 0..<(shots.count - 1) where t >= shots[i].t && t <= shots[i + 1].t {
        let a = shots[i], b = shots[i + 1]
        let u = CGFloat(ease((t - a.t) / max(b.t - a.t, 1e-9)))
        return (CGPoint(x: a.centre.x + (b.centre.x - a.centre.x) * u,
                        y: a.centre.y + (b.centre.y - a.centre.y) * u),
                a.zoom + (b.zoom - a.zoom) * u)
    }
    return (shots[shots.count - 1].centre, shots[shots.count - 1].zoom)
}

// MARK: - The clips

// The Tassel status item sits among the other menu bar icons, left of the
// battery, and the charm hangs from it — the app's own defaults: a 44pt charm
// on a 150pt cord.
let anchor = CGPoint(x: 1210, y: menuBottom)
var hangers: [Hanger] = []
var keys: [Key] = []
var pushes = true
var duration = 0.0
var statusIcon: String? = nil
var shots: [Shot] = []
// Per-substep behaviour, and how far the hanging charm is drawn raised, set by each clip.
var beforeStep: (Double) -> Void = { _ in }
var raised: (Double) -> CGFloat = { _ in 0 }

func ease(_ u: Double) -> Double { let c = min(max(u, 0), 1); return c * c * (3 - 2 * c) }
func lerp(_ a: CGPoint, _ b: CGPoint, _ u: Double) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u)
}
func tune(_ name: String, _ fallback: Double) -> Double {
    Double(ProcessInfo.processInfo.environment[name] ?? "") ?? fallback
}

guard clip == "main" else { fatalError("unknown clip \(clip)") }

// One continuous shot of the app, on one cord: the charm drops in, is flicked,
// is pulled right down and let go, is switched from the menu twice, performs
// its ritual, and is resized. Times are seconds into the video.
duration = 28.40
let cat = Hanger(Charm.named("Maneki Neko")!, anchor: anchor, length: 150, size: 44, phase: 0.3)
hangers = [cat]
statusIcon = "maneki-neko"

// The whole screen, then in on the charm for the close work, then back out to
// see it hanging on the screen again while its size is changed. Wide, the frame
// is the screen's full width; close, it is pushed as far as it can go without
// showing past the screen's own top and right edges — 835x470 points of screen
// at 2.3x.
let wideZoom = frameW / W
// Wide, the 16:9 cut is the screen's full width; the tall cut sets the whole
// screen high in the frame and leaves the space below it for the words.
let wide = tall
    ? CGPoint(x: W / 2, y: H / 2 - (frameH / 2 - 470) / wideZoom)
    : CGPoint(x: W / 2, y: H - frameH / 2 / wideZoom)
let closeZoom: CGFloat = tall ? 2.2 : 2.3
let close = CGPoint(x: W - frameW / 2 / closeZoom - 6, y: H - frameH / 2 / closeZoom)
shots = [
    Shot(t: 0, centre: wide, zoom: wideZoom), Shot(t: 4.18, centre: wide, zoom: wideZoom),
    Shot(t: 5.22, centre: close, zoom: closeZoom), Shot(t: 25.95, centre: close, zoom: closeZoom),
    Shot(t: 27.05, centre: wide, zoom: wideZoom), Shot(t: duration, centre: wide, zoom: wideZoom),
]

// Drops out from under the menu bar, hanging straight, gathering speed as it
// falls; the landing is a downward shove the rope's own stretch bounces back from.
let dropStart = 0.70, landing = 1.05
raised = { t in
    if t < dropStart { return 260 }
    if t >= landing { return 0 }
    let u = (t - dropStart) / (landing - dropStart)
    return CGFloat(1 - u * u) * 260
}

// Choosing a charm in the app swaps it on the same cord and calls Drop In,
// which nudges it into a swing.
struct Event { let t: Double; let run: () -> Void }
func switchTo(_ name: String, art artwork: String? = nil, swing: Double) {
    cat.charm = Charm.named(name)!
    cat.artwork = artwork ?? cat.charm.artwork
    cat.rope.nudge(CGVector(dx: swing, dy: 0))
}
var events: [Event] = [
    Event(t: landing) { cat.rope.nudge(CGVector(dx: 110, dy: -660)) },
    Event(t: 14.76) { switchTo("Pysanka", swing: 400) },
    Event(t: 16.85) { switchTo("Daruma", art: "daruma-blank", swing: -370) },
    Event(t: 19.00) { cat.artwork = "daruma-one-eye" },
    Event(t: 21.03) { cat.artwork = "daruma" },
    // Size, from the app's own list: Small 28, Medium 44, Large 62, Extra Large 84.
    Event(t: 23.64) { cat.size = 28 },
    Event(t: 25.72) { cat.size = 84 },
]
beforeStep = { t in
    while let next = events.first, t >= next.t {
        next.run()
        events.removeFirst()
    }
    statusIcon = cat.artwork
}

// The pointer sweeps through the cord, then comes back for the charm itself.
// Later pointer moves, over the menus, are drawn by the composition so they
// can sit above the menus.
keys = [
    Key(t: 6.60, p: CGPoint(x: anchor.x + 200, y: menuBottom - 62)),
    Key(t: 7.24, p: CGPoint(x: anchor.x + 84, y: menuBottom - 78)),
    Key(t: 7.32, p: CGPoint(x: anchor.x + 82, y: menuBottom - 79)),
    Key(t: 7.52, p: CGPoint(x: anchor.x - 114, y: menuBottom - 84)),
    Key(t: 8.30, p: CGPoint(x: anchor.x - 88, y: menuBottom - 128)),
]

// The pull. The pointer comes back to the charm, takes hold of it, drags it
// down until the cord is stretched taut, holds it there, and lets go — the
// same holdEnd/releaseEnd the app runs for a drag, so the recoil is the
// rope's own.
let reachStart = tune("REACH", 8.30), reachEnd = tune("REACHED", 8.86), takeHold = tune("HOLD", 9.50)
let pullEnd = tune("PULLED", 10.30), letGo = tune("LETGO", 10.60), leave = 11.70
// Where the hand settles to wait for the charm, and where the end of the rope
// is dragged to: down and aside, until the cord is stretched about a third
// past its length.
let reachTo = CGPoint(x: tune("REACHX", anchor.x - 22), y: tune("REACHY", menuBottom - 180))
let pullTo = CGPoint(x: tune("PULLX", anchor.x - 68), y: tune("PULLY", menuBottom - 183))
var reachFrom: CGPoint?
var dragFrom: CGPoint?
var holdOffset: CGVector?
var holding = false

/// The middle of the charm as it is actually drawn, which is what a hand goes for.
func charmCentre(_ h: Hanger) -> CGPoint {
    CGPoint(x: 0, y: -h.size * 0.52).applying(Rope.placement(at: h.rope.endPoint, heading: h.rope.endAngle))
}

func pointerNow(_ t: Double) -> CGPoint? {
    if t < reachStart { return pointer(keys, at: t) }
    if t < takeHold {
        if reachFrom == nil { reachFrom = pointer(keys, at: reachStart) ?? charmCentre(cat) }
        // The hand shoves the charm aside on its way in — it is a pointer push
        // like any other — so it arrives early and waits for the charm to swing
        // back into it before closing.
        return lerp(reachFrom!, reachTo, ease((t - reachStart) / (reachEnd - reachStart)))
    }
    // Once it has hold, the hand follows its own path: down, still, then away.
    let from = dragFrom ?? reachTo
    let offset = holdOffset ?? CGVector(dx: 0, dy: 0)
    let target = CGPoint(x: pullTo.x - offset.dx, y: pullTo.y - offset.dy)
    if t < pullEnd { return lerp(from, target, ease((t - takeHold) / (pullEnd - takeHold))) }
    if t < letGo { return target }
    if t < leave { return lerp(target, CGPoint(x: W - 40, y: menuBottom - 320), ease((t - letGo) / (leave - letGo))) }
    return nil
}

// MARK: - Simulate and draw

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let frames = Int((duration * fps).rounded())
let dt = 1 / (fps * Double(substeps))
var t = 0.0
var last = pointerNow(0)

for frame in 0..<frames {
    for _ in 0..<substeps {
        t += dt
        beforeStep(t)
        let cur = pointerNow(t)
        // Taking hold, and letting go. A held charm follows the hand and is
        // not shoved by it, exactly as in the app.
        if t >= takeHold, t < letGo, let cur {
            if !holding {
                holding = true
                dragFrom = cur
                holdOffset = CGVector(dx: cat.rope.endPoint.x - cur.x, dy: cat.rope.endPoint.y - cur.y)
            }
            let offset = holdOffset!
            cat.rope.holdEnd(at: CGPoint(x: cur.x + offset.dx, y: cur.y + offset.dy))
        } else if holding {
            holding = false
            cat.rope.releaseEnd()
        }
        for h in hangers {
            var push: Rope.Push? = nil
            if pushes, !holding, let cur, let prev = last {
                let dx = cur.x - prev.x, dy = cur.y - prev.y, speed = hypot(dx, dy) / dt
                if speed > 40 {
                    let travel = max(hypot(dx, dy), 1e-9), strength = pushStrength * min(1, speed / 400)
                    push = Rope.Push(point: cur, acceleration: CGVector(dx: dx / travel * strength, dy: dy / travel * strength),
                                     radius: pushRadius(h))
                }
            }
            h.rope.step(dt: dt, wind: h.breeze(dt), push: push)
        }
        last = cur
    }

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(frameW * scale), pixelsHigh: Int(frameH * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = g
    g.imageInterpolation = .high
    let ctx = g.cgContext
    ctx.scaleBy(x: scale, y: scale)
    // The camera: the frame shows this much of the screen, around this point.
    let shot = camera(shots, at: t)
    ctx.translateBy(x: frameW / 2, y: frameH / 2)
    ctx.scaleBy(x: shot.zoom, y: shot.zoom)
    ctx.translateBy(x: -shot.centre.x, y: -shot.centre.y)

    // Beyond the screen's edges there is no screen: the tall cut frames it as a
    // band with the desk around it.
    if tall {
        NSGraphicsContext.saveGraphicsState()
        ctx.saveGState()
        ctx.resetClip()
        ctx.concatenate(ctx.ctm.inverted())
        NSGradient(colors: [hex(0x0B0E1F), hex(0x171231)])!
            .draw(in: NSRect(x: 0, y: 0, width: frameW * scale, height: frameH * scale), angle: -90)
        ctx.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
    }
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: H)).addClip()

    wallpaper()
    // Nothing shows above the menu bar: a raised charm is hidden behind it.
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: W, height: menuBottom)).addClip()
    ctx.translateBy(x: 0, y: raised(t))
    hangers.forEach { drawHanger($0, ctx: ctx) }
    NSGraphicsContext.restoreGraphicsState()
    menuBar(statusIcon: statusIcon, iconX: anchor.x)
    NSGraphicsContext.restoreGraphicsState()
    if let cur = last, cur.x > -5, cur.x < W + 5, cur.y > -5, cur.y < H + 5 {
        // The app swaps the arrow for a hand over a charm it can take hold of.
        if t >= takeHold - 0.22, t < letGo { drawHand(at: cur, closed: t >= takeHold) }
        else if t >= letGo, t < letGo + 0.26 { drawHand(at: cur, closed: false) }
        else { drawCursor(at: cur) }
    }

    NSGraphicsContext.restoreGraphicsState()
    // PROBE="15.9,18.4" prints where the charm hangs at those times, in screen points.
    for probe in (ProcessInfo.processInfo.environment["PROBE"] ?? "").split(separator: ",").compactMap({ Double($0) })
    where frame == Int(probe * fps) {
        let h = hangers[0], e = h.rope.endPoint, c = charmCentre(h)
        print(String(format: "t=%.2f hook=(%.0f,%.0f) centre=(%.0f,%.0f) stretch=%.2f angle=%.3f",
                     probe, e.x, e.y, c.x, c.y,
                     hypot(e.x - h.rope.anchor.x, e.y - h.rope.anchor.y) / h.rope.length, h.rope.endAngle))
    }
    if let still = Double(ProcessInfo.processInfo.environment["STILL_AT"] ?? ""), frame != Int(still * fps) { continue }
    let path = String(format: "%@/%04d.png", outDir, frame)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
print("\(clip): \(frames) frames")
