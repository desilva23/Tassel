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
| `Resources/Charms/daruma.png` | Drawn by Desilva Stalin | Original |
| `Resources/Charms/daruma-blank.png` | Drawn by Desilva Stalin | Original |
| `Resources/Charms/daruma-one-eye.png` | Made from the two above by `Tools/daruma-one-eye.swift` | Original |
| `Resources/Charms/yansheng.png` | Drawn by Desilva Stalin | Original |
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
| Placement | Roughly centred. Empty margin is trimmed automatically |
| Background | Transparent. The template's checkerboard shows where that is |
| The anchor | 40px down from the top edge, horizontally centred |
| Safe area | Inside the dashed circle |
| Export | PNG, transparency on |
| File name | Lowercase letters, digits and hyphens: `maneki-neko.png` |

**Paint white white.** The most expensive mistake so far: the daruma's face was
left as empty canvas rather than painted, which looks white on the iPad because
the app's own background is white. Exported with transparency it came out as a
hole, and the charm hung on a dark wallpaper with a black face. Anything meant
to be white has to be a white stroke or fill on its own, not the absence of one.

**Export as a file, not to Photos.** Saving to Photos flattens onto white and
loses transparency entirely. Use Export or share into Files. Check it in
Preview: transparent areas show a grey checkerboard, white shows as white.

If you do end up with a flattened export, `Tools/unbackground.swift` recovers it:

```bash
swift Tools/unbackground.swift flattened.png Resources/Charms/name.png
```

It floods inward from the edges rather than deleting every white pixel, so white
that is enclosed by the drawing — a face, an eye — survives. White that is
enclosed but should be *see-through*, like a coin's square hole, has to be named:
add a point inside it as fractions across and down the image.

```bash
swift Tools/unbackground.swift coin.png Resources/Charms/yansheng.png 0.5,0.52 0.5,0.041
```

That clears a coin's hole and the inside of its loop. Better still is to erase
them in the drawing app and export with transparency, which needs no tool at all
— the coin in `Resources/Charms` was finally made that way. Edges that were
antialiased against white are faded out to avoid a pale halo. It is a rescue,
not a substitute: a proper transparent export is always cleaner.

**Draw it bold.** The charm is drawn at roughly 60 points on screen, so a
1024 canvas is being reduced about seventeen times over. Fine linework does not
survive that: hairline strokes merge into a smudge and small features close up.
Think of it the way a road sign is drawn rather than an illustration — few
shapes, thick strokes, strong contrast between the parts that must stay
separate. Check it by shrinking your canvas to 60px and looking at it.

**You do not have to be precise about placement.** The app finds the drawn part
of the image and hangs the charm by the top of *that*, ignoring empty margin, so
a charm drawn a little high or low or small still meets the rope cleanly and
still comes out the same size as every other charm. The crosshair on the
template is a guide, not a requirement.

What does matter is that the top of the drawing is whatever the charm should
hang by — its loop, its knot, the top of its head. Do not leave a stray mark
above it: a single stroke floating near the top of the page is, as far as the
app can tell, the top of the charm, and the rope will attach to that.

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
