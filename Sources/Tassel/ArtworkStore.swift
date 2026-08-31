import AppKit
import TasselCore

/// Loads drawn charm artwork out of the app bundle, once each.
///
/// Missing or unreadable files are remembered as misses, so a renamed file
/// costs one failed lookup rather than one per frame. Nothing here throws or
/// complains: a charm whose artwork cannot be found falls back to its glyph,
/// because a charm failing to appear is far worse than a charm looking plain.
enum ArtworkStore {
    private nonisolated(unsafe) static var cache: [String: NSImage?] = [:]

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
    }
}
