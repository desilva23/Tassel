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

## Rules for adding assets

1. Original work, or something under a licence that permits redistribution
   (CC0, CC-BY with attribution recorded here, or public domain).
2. Never trace, re-colour, or "redraw from" another app's artwork.
3. Add a row to the table in the same commit that adds the file.
