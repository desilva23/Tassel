import AppKit
import CoreText

// An original maneki-neko outline, for colouring underneath.
//
//   neko <out.png> [--mirror]
//
// Drawn from the traditional figure alone — seated, one paw raised, collar and
// bell, holding a koban coin — not traced from anybody's picture of one.
//
// The inside of every shape stays transparent, because the colour goes on a
// layer *below* this one. So shapes cannot hide each other by being filled in
// white. Instead they are laid down back to front, and each one first clears
// whatever is behind it inside its own outline, then draws that outline.

let side: CGFloat = 1024
let output = CommandLine.arguments[1]
let mirrored = CommandLine.arguments.contains("--mirror")

let ctx = CGContext(
    data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))

/// Laid out for the paw raised on the viewer's left; `--mirror` flips it.
func x(_ v: CGFloat) -> CGFloat { mirrored ? side - v : v }
func P(_ px: CGFloat, _ py: CGFloat) -> CGPoint { CGPoint(x: x(px), y: py) }

func layer(_ path: CGPath, width: CGFloat = 18, hides: Bool = true) {
    if hides {
        ctx.setBlendMode(.clear)
        ctx.addPath(path); ctx.fillPath()
        ctx.setBlendMode(.normal)
    }
    ctx.setLineWidth(width)
    ctx.addPath(path); ctx.strokePath()
}
func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: x(cx) - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
}
func line(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint? = nil, width: CGFloat) {
    let p = CGMutablePath(); p.move(to: a)
    if let c { p.addQuadCurve(to: b, control: c) } else { p.addLine(to: b) }
    layer(p, width: width, hides: false)
}

// 1. Tail, curling out from behind the body on the side away from the paw.
let tail = CGMutablePath()
tail.move(to: P(740, 140))
tail.addCurve(to: P(858, 190), control1: P(800, 118), control2: P(850, 140))
tail.addCurve(to: P(834, 264), control1: P(872, 232), control2: P(862, 264))
tail.addCurve(to: P(808, 226), control1: P(810, 264), control2: P(798, 242))
tail.addCurve(to: P(740, 204), control1: P(798, 204), control2: P(770, 204))
tail.closeSubpath()
layer(tail)

// 2. Body: a seated, pear-shaped figure; its top is hidden by the head later.
let body = CGMutablePath()
body.move(to: P(512, 70))
body.addCurve(to: P(236, 190), control1: P(330, 66), control2: P(240, 100))
body.addCurve(to: P(258, 470), control1: P(230, 320), control2: P(244, 420))
body.addQuadCurve(to: P(344, 610), control: P(264, 572))
body.addLine(to: P(680, 610))
body.addQuadCurve(to: P(766, 470), control: P(760, 572))
body.addCurve(to: P(788, 190), control1: P(780, 420), control2: P(794, 320))
body.addCurve(to: P(512, 70), control1: P(784, 100), control2: P(694, 66))
body.closeSubpath()
layer(body)

// 3. Front feet, with toe lines.
for cx in [380.0, 644.0] {
    layer(oval(cx, 92, 74, 40))
    for dx in [-24.0, 24.0] {
        line(P(cx + dx, 60), P(cx + dx, 96), P(cx + dx * 1.15, 78), width: 9)
    }
}

// 4. The koban coin, held in front of the belly.
layer(oval(512, 240, 112, 142))
layer(oval(512, 240, 92, 122), width: 10, hides: false)
// 千万両, "ten million ryō", outlined so the characters can be coloured in.
let font = CTFontCreateWithName(("HiraMinProN-W6" as CFString), 66, nil)
for (glyphText, cy) in [("\u{5343}", 318.0), ("\u{4E07}", 240.0), ("\u{4E21}", 162.0)] {
    var chars = Array(glyphText.utf16), glyphs = [CGGlyph](repeating: 0, count: chars.count)
    CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
    guard let glyphPath = CTFontCreatePathForGlyph(font, glyphs[0], nil) else { continue }
    let box = glyphPath.boundingBoxOfPath
    // Characters are never mirrored, whichever paw is raised.
    var place = CGAffineTransform(translationX: side / 2 - box.midX, y: cy - box.midY)
    if let moved = glyphPath.copy(using: &place) { layer(moved, width: 6, hides: false) }
}

// 5. The other paw, holding the coin's edge.
let hold = CGMutablePath()
hold.move(to: P(698, 456))
hold.addCurve(to: P(748, 360), control1: P(740, 452), control2: P(752, 412))
hold.addCurve(to: P(648, 250), control1: P(744, 290), control2: P(702, 250))
hold.addCurve(to: P(556, 300), control1: P(596, 250), control2: P(556, 262))
hold.addCurve(to: P(612, 346), control1: P(556, 332), control2: P(584, 346))
hold.addCurve(to: P(698, 456), control1: P(660, 350), control2: P(672, 424))
hold.closeSubpath()
layer(hold)
line(P(566, 290), P(588, 294), width: 9)
line(P(568, 316), P(590, 318), width: 9)

// 6. Collar, tucked under the chin.
let collar = CGMutablePath()
collar.move(to: P(282, 548))
collar.addQuadCurve(to: P(742, 548), control: P(512, 424))
collar.addLine(to: P(758, 506))
collar.addQuadCurve(to: P(266, 506), control: P(512, 378))
collar.closeSubpath()
layer(collar)

// 7. The raised paw, beside the head, palm out.
let arm = CGMutablePath()
arm.move(to: P(292, 430))
arm.addCurve(to: P(268, 720), control1: P(300, 540), control2: P(280, 640))
arm.addCurve(to: P(210, 836), control1: P(270, 792), control2: P(250, 836))
arm.addCurve(to: P(150, 730), control1: P(170, 836), control2: P(146, 792))
arm.addCurve(to: P(206, 450), control1: P(156, 640), control2: P(180, 520))
arm.addCurve(to: P(292, 430), control1: P(226, 410), control2: P(270, 410))
arm.closeSubpath()
layer(arm)
layer(oval(210, 758, 34, 26), width: 9, hides: false)
for (px, py, r) in [(178.0, 804.0, 10.0), (210.0, 818.0, 11.0), (242.0, 804.0, 10.0)] {
    layer(oval(px, py, r, r), width: 8, hides: false)
}

// 8. Ears, behind the head.
for flip in [false, true] {
    func q(_ px: CGFloat, _ py: CGFloat) -> CGPoint { P(flip ? side - px : px, py) }
    let outer = CGMutablePath()
    outer.move(to: q(316, 740))
    outer.addCurve(to: q(330, 918), control1: q(300, 820), control2: q(306, 902))
    outer.addCurve(to: q(452, 846), control1: q(360, 932), control2: q(420, 880))
    outer.closeSubpath()
    layer(outer)
    let inner = CGMutablePath()
    inner.move(to: q(340, 790))
    inner.addCurve(to: q(346, 884), control1: q(332, 830), control2: q(334, 872))
    inner.addCurve(to: q(426, 842), control1: q(366, 890), control2: q(404, 866))
    inner.closeSubpath()
    layer(inner, width: 10, hides: false)
}

// 9. Head.
layer(oval(512, 690, 228, 188))

// 10. Bell, hanging from the collar in front of everything.
layer(oval(512, 432, 40, 40))
line(P(476, 446), P(548, 446), P(512, 436), width: 9)
layer(oval(512, 414, 8, 8), width: 7, hides: false)
line(P(512, 405), P(512, 394), width: 7)

// 11. Face.
for ex in [432.0, 592.0] {
    layer(oval(ex, 704, 32, 38), width: 12, hides: false)
    layer(oval(ex + 4, 700, 15, 21), width: 8, hides: false)
    layer(oval(ex + 12, 716, 5, 5), width: 5, hides: false)
}
let nose = CGMutablePath()
nose.move(to: P(495, 654)); nose.addLine(to: P(529, 654))
nose.addQuadCurve(to: P(512, 634), control: P(526, 640))
nose.addQuadCurve(to: P(495, 654), control: P(498, 640))
layer(nose, width: 10, hides: false)
line(P(512, 634), P(484, 618), P(504, 606), width: 10)
line(P(512, 634), P(540, 618), P(520, 606), width: 10)
for (y0, y1) in [(664.0, 680.0), (648.0, 648.0), (632.0, 616.0)] {
    line(P(384, y0), P(302, y1), width: 8)
    line(P(640, y0), P(722, y1), width: 8)
}

// 12. What it hangs by: a short cord and a ring, at the very top and centred,
//     so the rope in the app meets the ring.
line(P(512, 928), P(512, 876), width: 12)
layer(oval(512, 952, 24, 24), width: 12, hides: false)

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))

// Where the drawing's edges fall, since the app hangs it by its top centre.
var minX = Int(side), maxX = 0, maxY = 0
for py in 0..<rep.pixelsHigh { for px in 0..<rep.pixelsWide where rep.colorAt(x: px, y: py)!.alphaComponent > 0.08 {
    minX = min(minX, px); maxX = max(maxX, px); if maxY == 0 { maxY = py }
} }
print("\(output): drawing spans x \(minX)-\(maxX), centre \((minX + maxX) / 2) (ring at 512), top \(maxY)px down")
