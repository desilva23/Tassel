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
        /// How far across the image the drawing hangs from: its loop.
        let hookX: Double
        let aspect: Double
    }

    private nonisolated(unsafe) static var cache: [String: NSImage?] = [:]
    private nonisolated(unsafe) static var loaded: [String: Loaded?] = [:]

    static func artwork(named name: String) -> Loaded? {
        if let cached = loaded[name] {
            return cached
        }
        let result = image(named: name).map { image in
            let measured = measure(image)
            return Loaded(
                image: image,
                content: measured.content,
                hookX: measured.hookX,
                aspect: image.size.width / max(image.size.height, 1)
            )
        }
        loaded[name] = result
        return result
    }

    /// Where the drawing is on its canvas and where it hangs from, ignoring
    /// transparent margin. Sampled on a grid: this runs once per charm.
    private static func measure(_ image: NSImage) -> (content: CGRect, hookX: Double) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return (CGRect(x: 0, y: 0, width: 1, height: 1), 0.5) }

        let width = rep.pixelsWide, height = rep.pixelsHigh
        return Artwork.measure(width: width, height: height, step: min(width, height) / 200) { x, y in
            // A low threshold, so a soft edge still counts as drawing.
            (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.08
        }
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
