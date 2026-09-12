// Draws the app icon: the maneki-neko swinging on a beaded cord inside a red
// macOS-style tile, hung by the same maths the app hangs it with. Writes every
// size macOS asks for into Resources/AppIcon.icns.
//
//   make icon

// Compiled together with Sources/TasselCore rather than importing it.
import AppKit

func colour(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// The icon at `side` pixels square, drawn on a 1024 grid.
func render(side: Int, charm: NSImage, hook: (content: CGRect, hookX: Double)) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(side) / 1024, y: CGFloat(side) / 1024)

    // Apple's grid: an 824 tile centred in the 1024 canvas.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    colour(0x9E1B1B).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: colour(0xE5453A), ending: colour(0x9E1B1B))!.draw(in: tile, angle: -90)

    // The cord drops in from above the tile, swung a little to one side.
    let heading = 0.13, cordLength = 250.0
    let pivot = CGPoint(x: 470, y: 1000)
    let end = CGPoint(x: pivot.x + sin(heading) * cordLength, y: pivot.y - cos(heading) * cordLength)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let cord = NSBezierPath()
    cord.move(to: pivot)
    cord.line(to: end)
    cord.lineWidth = 14
    cord.lineCapStyle = .round
    colour(0xF6E3B4).setStroke()
    cord.stroke()
    for along in [0.52, 0.80] {
        let p = CGPoint(x: pivot.x + (end.x - pivot.x) * along, y: pivot.y + (end.y - pivot.y) * along)
        colour(0xF2C94C).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 26, y: p.y - 26, width: 52, height: 52)).fill()
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 14, y: p.y + 2, width: 14, height: 12)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    let rect = Artwork.drawRect(content: hook.content, hookX: hook.hookX, aspect: 1,
                                charmSize: 540 / Artwork.scale, hanging: true)
    context.saveGState()
    context.concatenate(Rope.placement(at: end, heading: heading))
    let drop = NSShadow()
    drop.shadowColor = NSColor.black.withAlphaComponent(0.3)
    drop.shadowBlurRadius = 18
    drop.shadowOffset = NSSize(width: 0, height: -10)
    drop.set()
    charm.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    context.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let charm = NSImage(contentsOfFile: "Resources/Charms/maneki-neko.png")!
let pixels = NSBitmapImageRep(data: charm.tiffRepresentation!)!
let hook = Artwork.measure(width: pixels.pixelsWide, height: pixels.pixelsHigh, step: pixels.pixelsWide / 200) { x, y in
    (pixels.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.08
}

let iconset = URL(fileURLWithPath: ".build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = render(side: points * scale, charm: charm, hook: hook).representation(using: .png, properties: [:])!
        try! png.write(to: iconset.appendingPathComponent(name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote Resources/AppIcon.icns")
