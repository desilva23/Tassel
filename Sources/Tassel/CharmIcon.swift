import AppKit
import TasselCore

/// A small picture of a charm, for the menu bar and the Charm menu.
///
/// A drawn charm is shown as its drawing, not its stand-in glyph: the glyph is
/// only there for when a drawing is missing, and showing a lantern for a daruma
/// or a silver coin for a bronze one is exactly the mismatch it should never
/// cause. Every charm gets an image — glyphs are drawn into one too — so the
/// menu's rows line up the same way whichever kind a charm is.
enum CharmIcon {
    static func image(for charm: Charm, stage: Int, side: CGFloat = 18) -> NSImage {
        let names = [charm.artwork(atStage: stage), charm.artwork].compactMap { $0 }
        if let artwork = names.lazy.compactMap(ArtworkStore.artwork(named:)).first {
            return drawing(artwork, side: side)
        }
        return glyph(charm.glyph, side: side)
    }

    /// The drawing, cropped to the part actually drawn — a page's empty margin
    /// would shrink the charm to a speck at menu size — and fitted into a square.
    private static func drawing(_ artwork: ArtworkStore.Loaded, side: CGFloat) -> NSImage {
        let source = artwork.image
        let size = source.size
        let crop = NSRect(
            x: artwork.content.minX * size.width,
            y: artwork.content.minY * size.height,
            width: artwork.content.width * size.width,
            height: artwork.content.height * size.height
        )
        // Drawn on demand, so it is rendered sharp at whatever scale the
        // screen needs rather than scaled up from a small bitmap.
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let fit = min(side / max(crop.width, 1), side / max(crop.height, 1))
            let width = crop.width * fit, height = crop.height * fit
            source.draw(
                in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height),
                from: crop,
                operation: .sourceOver,
                fraction: 1
            )
            return true
        }
    }

    private static func glyph(_ glyph: String, side: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let text = NSAttributedString(
                string: glyph,
                attributes: [.font: NSFont.systemFont(ofSize: side * 0.82)]
            )
            let measured = text.size()
            text.draw(at: NSPoint(x: (side - measured.width) / 2, y: (side - measured.height) / 2))
            return true
        }
    }
}
