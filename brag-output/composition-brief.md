# Hyperframes Composition Brief: Tassel

## Objective
Create a short launch-style brag video for Tassel.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 31.4 seconds

## Source Material
- Project root: `~/Desktop/Ideas/Tassel`
- Primary files read: README.md, Sources/TasselCore (Rope, Charm, Ornament, Artwork),
  Sources/Tassel/CharmView.swift and AppDelegate.swift (menus, pointer push, breeze)
- Product name: Tassel
- Tagline / strongest claim: "A hand-drawn lucky charm that hangs from your Mac's menu bar."
- Key UI to recreate: the user's own screen, 1440x900 points — 24pt menu bar, the
  app's default 44pt charm on its 150pt cord; the Tassel menu, its Charm and Size
  submenus, and the charm's right-click menu (section header with the charm's
  name, then its ritual item)
- Copy that must appear verbatim:
  - Make a Wish
  - My Wish Came True
  - Daruma
  - Tassel

## Creative Direction
- Tone preset: default
- Creative direction: cosy handmade charm film — warm, tactile, a little magical
- Interpretation: comfortable pacing; the physics gets room to play out; short warm
  lines; soft crossfades.
- Angle: the charm behaves like a real object. Every moving shot is rendered from
  Tassel's own rope physics and drawings.
- Hook: "Your menu bar is missing something." — then the maneki neko drops out of
  the menu bar on its cord.
- Outro / punchline: icon, "Tassel", "Free & open source · macOS 14+", GitHub address.
- Avoid: generic SaaS language; abstract filler; redesigning the charms.

## Visual Identity
- Background: an original dusk wallpaper drawn for the video (#141A3C → #3B2D66 →
  #8C4F7E → #F0A07A, starfield, three hill silhouettes)
- Text: #FFFFFF; secondary rgba(255,255,255,0.72)
- Accent: #E8B53A (bead gold), #E5453A (icon red)
- Display / body font: SF Pro via system-ui
- Visual references: docs/demo.gif, docs/charms.png, Resources/AppIcon.icns

## Physics clips (rendered outside Hyperframes)
The charm shots are MP4 clips rendered frame by frame from `TasselCore.Rope` by
`brag-output/clip-renderer/main.swift`, so the rope motion is the app's real
motion. Hyperframes layers text, the context menu and audio over them.
- `assets/clips/main.mp4` — one continuous 28.4s shot on one cord: the drop-in at
  1.05s, a flick at 7.32s, the charm taken hold of at 9.50s and dragged down until
  the cord stretches to 1.3x, released at 10.60s, switched to the pysanka at 14.76s
  and the daruma at 16.85s (each with the app's Drop In swing), its eyes painted at
  19.00s and 21.03s, and resized to Small at 23.64s and Extra Large at 25.72s.
  The grab runs through the app's own holdEnd/releaseEnd, and the open and closed
  hands are the cursors the app sets.
- The screen is drawn at its real size and a camera frames it: wide (its full
  width, 1.333x) until 4.18s, pushed into the top-right corner at 2.3x from
  5.22s, and back out to wide between 25.95s and 27.05s. The composition puts the
  menus and the pointer on a 1440x900 `#stage` layer carrying the same transform,
  so they sit on the screen at the size macOS would draw them — which is why the
  submenus open to the left, as they would with the status item at x=1210.

## Storyboard
Use the storyboard in `brag-output/brag-plan.md` as the creative contract.

1. Hook — 0–3.70s — hook line; charm drops in, on the whole screen
2. Reveal — 3.70–6.34s — icon + "Tassel" + tagline; the camera pushes in
3. Flick — 6.34–8.44s — "Flick it. It's a real rope." / "It bends, swings and settles."
4. Pull — 8.44–12.65s — "Or take hold and pull it down." / "Let go, and the cord springs back."
5. Pick a charm — 12.65–17.37s — Tassel menu, Charm ▸ submenu, pysanka then daruma
6. Ritual — 17.37–22.07s — right-click menus, both eyes painted
7. Size — 22.07–27.82s — Size ▸ Small then Extra Large; the camera pulls back to the whole screen
8. Outro — 27.82–31.37s — icon, name, "Free & open source · macOS 14+", GitHub address

## Audio
- Audio role: warm bed with a few tactile accents
- Music: happy-beats-business-moves-vol-9-by-ende-dot-app.mp3, 0.32, fade in, fade out under the outro
- Music cue guidance: bundled preset; lock 3.70s (title), 10.54s (the release), 12.65s (menu cut), 27.82s (outro)
- Audio-reactive treatment: none
- SFX: drop on the charm landing, a swish on the flick, a click as the hand takes
  hold, a swish as it lets go and a soft thud as the cord snaps back, clicks on
  right-click and menu click, a small sparkle on the first eye, soft bell on the
  second, bell on the logo. Low/medium HF risk only.

## Hyperframes Instructions
Plain HTML + GSAP composition following `hyperframes docs` (compositions,
data-attributes, gsap). Show the real clips; keep all text readable; run
`npx hyperframes check` before render.
