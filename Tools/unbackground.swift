import AppKit

// Remove a flat white background from a flattened export.
//
//   swift Tools/unbackground.swift in.png out.png [x,y ...]
//
// Not "delete every white pixel" — the daruma's face is white too, and that
// would leave a hole. Instead the background is found by flooding inward from
// the edges: only white that is *connected to the border* is background. White
// enclosed by the drawing is unreachable and survives.
//
// Which is right for a face and wrong for a hole. A coin's square hole is white
// enclosed by bronze, and has to be cleared so the wallpaper shows through it.
// So any `x,y` given after the file names — fractions across and down from the
// top-left, `0.5,0.52` for the middle of a coin — seeds a flood there too. The
// tool cannot tell a face from a hole on its own; that has to be said.

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let source = NSImage(contentsOfFile: inputPath) else { exit(1) }
let size = source.size
// NSImage.size is in points and honours the file's DPI, which for a 4096px
// export can be far smaller. Use the pixel dimensions.
let pixels = (source.representations.first as? NSBitmapImageRep)
let w = pixels?.pixelsWide ?? Int(size.width)
let h = pixels?.pixelsHigh ?? Int(size.height)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    // Premultiplied: CoreGraphics has no 8-bit non-premultiplied RGBA context,
    // and asking for one leaves the context nil and the bitmap untouched.
    colorSpaceName: .deviceRGB, bitmapFormat: [],
    bytesPerRow: w * 4, bitsPerPixel: 32
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
source.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
NSGraphicsContext.restoreGraphicsState()

let data = rep.bitmapData!
@inline(__always) func offset(_ x: Int, _ y: Int) -> Int { (y * w + x) * 4 }

/// How background-like a pixel is: bright and unsaturated.
@inline(__always) func whiteness(_ i: Int) -> Double {
    let r = Double(data[i]), g = Double(data[i+1]), b = Double(data[i+2])
    let maxC = max(r, max(g, b)), minC = min(r, min(g, b))
    guard maxC > 0 else { return 0 }
    let brightness = maxC / 255
    let saturation = (maxC - minC) / maxC
    return brightness > 0.88 && saturation < 0.12 ? brightness : 0
}

var isBackground = [Bool](repeating: false, count: w * h)
var queue: [Int] = []
for x in 0..<w {
    for y in [0, h - 1] where whiteness(offset(x, y)) > 0 {
        let index = y * w + x
        if !isBackground[index] { isBackground[index] = true; queue.append(index) }
    }
}
for y in 0..<h {
    for x in [0, w - 1] where whiteness(offset(x, y)) > 0 {
        let index = y * w + x
        if !isBackground[index] { isBackground[index] = true; queue.append(index) }
    }
}

// Enclosed areas to clear as well, named on the command line.
for argument in CommandLine.arguments.dropFirst(3) {
    let parts = argument.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 2 else {
        FileHandle.standardError.write(Data("ignoring \(argument): expected x,y as fractions\n".utf8))
        continue
    }
    let x = min(w - 1, max(0, Int(parts[0] * Double(w))))
    let y = min(h - 1, max(0, Int(parts[1] * Double(h))))
    let index = y * w + x
    guard whiteness(offset(x, y)) > 0 else {
        FileHandle.standardError.write(Data("ignoring \(argument): not white there\n".utf8))
        continue
    }
    if !isBackground[index] { isBackground[index] = true; queue.append(index) }
}

var head = 0
while head < queue.count {
    let index = queue[head]; head += 1
    let x = index % w, y = index / w
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
        let next = ny * w + nx
        guard !isBackground[next], whiteness(offset(nx, ny)) > 0 else { continue }
        isBackground[next] = true
        queue.append(next)
    }
}

// Clear the background, and soften the pixels beside it. Antialiased edges were
// blended against white, so leaving them opaque draws a pale halo.
var cleared = 0
for index in 0..<(w * h) {
    let i = index * 4
    if isBackground[index] {
        data[i+3] = 0
        cleared += 1
        continue
    }
    let x = index % w, y = index / w
    var touchesBackground = false
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)] {
        let nx = x + dx, ny = y + dy
        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
        if isBackground[ny * w + nx] { touchesBackground = true; break }
    }
    if touchesBackground {
        let white = whiteness(i)
        if white > 0 {
            // Premultiplied, so the colour channels have to come down with the
            // alpha or the edge stays bright where it should be fading out.
            let alpha = max(0.0, min(1.0, 1 - white))
            data[i+3] = UInt8(255 * alpha)
            for channel in 0..<3 {
                data[i + channel] = UInt8(Double(data[i + channel]) * alpha)
            }
        }
    }
}

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outputPath))
let sample = offset(2, 2)
print("size \(w)x\(h), border pixel rgba: \(data[sample]),\(data[sample+1]),\(data[sample+2]),\(data[sample+3])")
print("cleared \(cleared) background pixels of \(w * h) (\(cleared * 100 / (w * h))%)")
