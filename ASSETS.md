# Asset provenance

Every visual element that ships with Tassel is listed here, with where it came
from. Keep this file current: if the project is ever accused of borrowing
someone else's artwork, this is the document that answers it.

| Asset | Source | Licence |
|---|---|---|
| Charm glyphs | Unicode code points, rendered at runtime by the system emoji font | Unicode code points are not copyrightable; the font is Apple's and is never redistributed |
| Threading (beads, chillies) | Beads drawn at runtime with `NSBezierPath`; chillies are Unicode, as above | Original / not copyrightable |
| Cord | Drawn at runtime with `NSBezierPath` in `CharmView.draw(_:)` | Original |
| App icon | Not yet made | — |
| `Resources/Charms/TEMPLATE.png` | Drawn at runtime by a script, checked in as a guide | Original |

## Drawing a charm

Charms can be drawn rather than borrowed from the emoji font, and several want
to be: a maneki neko, a daruma, a vegvisir and a pysanka have no emoji at all.

**Start from `Resources/Charms/TEMPLATE.png`.** It is a 1024 square with the
guides on it. Send it to the iPad, open it as a layer, draw on a layer above it,
then hide the template layer before exporting.

| | |
|---|---|
| Canvas | 1024 x 1024, square |
| Background | Transparent. The template's checkerboard shows where that is |
| The anchor | 40px down from the top edge, horizontally centred |
| Safe area | Inside the dashed circle |
| Export | PNG, transparency on |
| File name | Lowercase letters, digits and hyphens: `maneki-neko.png` |

**The anchor is the one measurement that matters.** The rope stops exactly
there, so whatever the charm hangs by — a loop, a knot, the top of its head —
belongs at that crosshair. Everything else is taste. A charm drawn with its top
somewhere else will hang as though the string is growing out of its middle.

Then drop the file in `Resources/Charms/` and add the charm in
`Sources/TasselCore/Charm.swift`:

```swift
Charm(
    glyph: "\u{1F431}",                       // stand-in for menus
    name: "Maneki Neko",
    ritual: Ritual(name: "Wind the Paw", days: 9),
    artwork: "maneki-neko"                     // the file, without .png
)
```

The glyph stays required on purpose. It is what shows in the menu and the menu
bar, and it is what gets drawn if the artwork file is ever renamed or lost — a
charm should never fail to appear because of a missing file.

## Rules for adding assets

1. Original work, or something under a licence that permits redistribution
   (CC0, CC-BY with attribution recorded here, or public domain).
2. Never trace, re-colour, or "redraw from" another app's artwork.
3. Add a row to the table in the same commit that adds the file.
