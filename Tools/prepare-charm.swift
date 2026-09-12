// Turns a drawing exported from the iPad into a charm file: clears stray marks,
// trims the empty page and fits what is left onto the 1024 canvas every charm
// uses, its top 40px down.
//
//   swift Tools/prepare-charm.swift drawing.png Resources/Charms/name.png
//
// A stray mark is a separate piece that is tiny beside the drawing — a speck of
// a soft brush, a dot from a stylus resting. Nearly invisible ones still count
// as drawing to the app, and one above the loop becomes the point the rope
// attaches to. Size across is what decides, not pixel count: a ring floating
// inside another ring is a small piece too, and is meant to be there. Every
// piece removed is listed, so check them.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift Tools/prepare-charm.swift drawing.png Resources/Charms/name.png")
    exit(1)
}

let canvas = 1024
let margin = 40
// A piece whose longest side is under this fraction of the largest piece's
// height is a stray mark, not part of the charm.
let strayFraction = 0.02

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: arguments[1]) as CFURL, nil),
      let drawing = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    print("could not read \(arguments[1])")
    exit(1)
}

let width = drawing.width, height = drawing.height
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let page = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
    space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
page.draw(drawing, in: CGRect(x: 0, y: 0, width: width, height: height))
let pixels = page.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)

// Label every separate piece: pixels that are drawn at all, joined at edges or corners.
var piece = [Int32](repeating: -1, count: width * height)
var sizes: [Int] = []
var boxes: [(minX: Int, minY: Int, maxX: Int, maxY: Int)] = []
var stack: [Int] = []
for start in 0..<(width * height) where pixels[start * 4 + 3] > 0 && piece[start] < 0 {
    let label = Int32(sizes.count)
    var count = 0
    var box = (minX: width, minY: height, maxX: 0, maxY: 0)
    piece[start] = label
    stack.append(start)
    while let index = stack.popLast() {
        count += 1
        let x = index % width, y = index / width
        box = (min(box.minX, x), min(box.minY, y), max(box.maxX, x), max(box.maxY, y))
        for dy in -1...1 {
            for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, ny >= 0, nx < width, ny < height else { continue }
                let next = ny * width + nx
                if piece[next] < 0 && pixels[next * 4 + 3] > 0 {
                    piece[next] = label
                    stack.append(next)
                }
            }
        }
    }
    sizes.append(count)
    boxes.append(box)
}

guard let largest = sizes.indices.max(by: { sizes[$0] < sizes[$1] }) else {
    print("\(arguments[1]) is empty")
    exit(1)
}
let smallest = Double(boxes[largest].maxY - boxes[largest].minY + 1) * strayFraction
let keep = boxes.map { Double(max($0.maxX - $0.minX, $0.maxY - $0.minY) + 1) >= smallest }

for (label, kept) in keep.enumerated() where !kept {
    let box = boxes[label]
    print("removed a stray mark of \(sizes[label]) pixels at x \(box.minX)...\(box.maxX), y \(box.minY)...\(box.maxY)")
}
for index in 0..<(width * height) where piece[index] >= 0 && !keep[Int(piece[index])] {
    for channel in 0..<4 { pixels[index * 4 + channel] = 0 }
}

// Trim to what is left. Rows run top-down here; CG rectangles run bottom-up.
let kept = boxes.indices.filter { keep[$0] }.map { boxes[$0] }
let minX = kept.map(\.minX).min()!, maxX = kept.map(\.maxX).max()!
let minY = kept.map(\.minY).min()!, maxY = kept.map(\.maxY).max()!
let trimmed = page.makeImage()!.cropping(to: CGRect(
    x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1
))!

// Fit onto the canvas: centred across, its top on the template's anchor line.
let room = Double(canvas - 2 * margin)
let scale = min(room / Double(trimmed.width), room / Double(trimmed.height))
let fittedWidth = Double(trimmed.width) * scale, fittedHeight = Double(trimmed.height) * scale
let charm = CGContext(
    data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: canvas * 4,
    space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
charm.interpolationQuality = .high
charm.draw(trimmed, in: CGRect(
    x: (Double(canvas) - fittedWidth) / 2,
    y: Double(canvas - margin) - fittedHeight,
    width: fittedWidth,
    height: fittedHeight
))

let output = URL(fileURLWithPath: arguments[2])
guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    print("could not write \(arguments[2])")
    exit(1)
}
CGImageDestinationAddImage(destination, charm.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else {
    print("could not write \(arguments[2])")
    exit(1)
}
print("kept \(keep.filter { $0 }.count) piece(s), \(trimmed.width)x\(trimmed.height) fitted to \(Int(fittedWidth))x\(Int(fittedHeight)) on a \(canvas) canvas")
