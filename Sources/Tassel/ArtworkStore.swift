import AppKit
import TasselCore

/// Loads drawn charm artwork out of the app bundle, once each.
///
/// Missing or unreadable files are remembered as misses, so a renamed file
/// costs one failed lookup rather than one per frame. Nothing here throws or
/// complains: a charm whose artwork cannot be found falls back to its glyph,
/// because a charm failing to appear is far worse than a charm looking plain.
enum ArtworkStore {
    /// An image and where its drawing actually sits on its canvas.
    struct Loaded {
        let image: NSImage
        /// The opaque part, in unit coordinates of the image, y up.
        let content: CGRect
        let aspect: Double
    }

    private nonisolated(unsafe) static var cache: [String: NSImage?] = [:]
    private nonisolated(unsafe) static var loaded: [String: Loaded?] = [:]

    static func artwork(named name: String) -> Loaded? {
        if let cached = loaded[name] {
            return cached
        }
        let result = image(named: name).map { image in
            Loaded(
                image: image,
                content: contentBounds(of: image),
                aspect: image.size.width / max(image.size.height, 1)
            )
        }
        loaded[name] = result
        return result
    }

    /// The box the drawing actually occupies, ignoring transparent margin.
    ///
    /// Sampled on a grid rather than every pixel: this runs once per charm and
    /// a few thousand samples locate an edge closely enough for placement, where
    /// a million would just be slower.
    private static func contentBounds(of image: NSImage) -> CGRect {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return CGRect(x: 0, y: 0, width: 1, height: 1) }

        let width = rep.pixelsWide, height = rep.pixelsHigh
        guard width > 0, height > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let step = max(1, min(width, height) / 200)

        var minX = width, maxX = -1, minY = height, maxY = -1
        for x in stride(from: 0, to: width, by: step) {
            for y in stride(from: 0, to: height, by: step) {
                // A low threshold, so a soft edge still counts as drawing.
                guard let colour = rep.colorAt(x: x, y: y), colour.alphaComponent > 0.08 else { continue }
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return CGRect(x: 0, y: 0, width: 1, height: 1) }

        // colorAt has y increasing downward; unit coordinates here are y up.
        let w = Double(width), h = Double(height)
        return CGRect(
            x: Double(minX) / w,
            y: 1 - Double(maxY + step) / h,
            width: Double(maxX + step - minX) / w,
            height: Double(maxY + step - minY) / h
        )
    }

    static func image(named name: String) -> NSImage? {
        guard Artwork.isValidName(name) else { return nil }
        if let cached = cache[name] {
            return cached
        }

        let image = Bundle.main.url(forResource: name, withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
        cache[name] = image
        return image
    }

    /// For when artwork is replaced while the app is running.
    static func forget() {
        cache.removeAll()
        loaded.removeAll()
    }
}
