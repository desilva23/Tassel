import AppKit

// The one-eye stage, made from the two drawings rather than painted by hand:
// the blank daruma, with the finished daruma's pupil copied into one eye. Both
// files came out of the same drawing through the same pipeline, so they line up
// pixel for pixel and the copy leaves no seam.
let side = 1024
func load(_ path: String) -> NSBitmapImageRep {
    let image = NSImage(contentsOfFile: path)!
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bitmapFormat: [], bytesPerRow: side * 4, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let charms = "/Users/des/Desktop/Ideas/Tassel/Resources/Charms/"
let blank = load(charms + "daruma-blank.png")
let full = load(charms + "daruma.png")
let b = blank.bitmapData!, f = full.bitmapData!

// Find the pupils as the places the two drawings disagree.
var diff = [Bool](repeating: false, count: side * side)
for i in 0..<(side * side) {
    let o = i * 4
    let delta = max(abs(Int(b[o]) - Int(f[o])), abs(Int(b[o+1]) - Int(f[o+1])), abs(Int(b[o+2]) - Int(f[o+2])))
    diff[i] = delta > 40
}
var leftX = 0.0, leftY = 0.0, leftN = 0.0, rightX = 0.0, rightY = 0.0, rightN = 0.0
for i in 0..<(side * side) where diff[i] {
    let x = Double(i % side), y = Double(i / side)
    if x < Double(side) / 2 { leftX += x; leftY += y; leftN += 1 } else { rightX += x; rightY += y; rightN += 1 }
}
guard leftN > 500, rightN > 500 else { print("could not find both pupils"); exit(1) }
let pupil = (x: rightX / rightN, y: rightY / rightN)
let radius = sqrt(rightN / .pi)

// The doll's own left eye opens first — on the right as you look at it. Copy a
// disc a little wider than the pupil, so its soft edge comes across with it.
var copied = 0
for y in 0..<side { for x in 0..<side {
    guard hypot(Double(x) - pupil.x, Double(y) - pupil.y) <= radius * 1.25 else { continue }
    let o = (y * side + x) * 4
    for c in 0..<4 { b[o + c] = f[o + c] }
    copied += 1
} }

try! blank.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: charms + "daruma-one-eye.png"))
print(String(format: "pupils found either side of centre: left %.0f px, right %.0f px", leftN, rightN))
print(String(format: "opened the right-hand eye at (%.0f, %.0f), radius %.0f", pupil.x, pupil.y, radius))
