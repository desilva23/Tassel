# Brag Plan: Tassel

## What is this app?
A free, open-source macOS menu-bar app that hangs a hand-drawn lucky charm from
the menu bar on a real little rope: it sways, bends when flicked, and each charm
asks for its own ritual — paint the daruma's eye when your wish comes true.

## The angle
A tiny good-luck ritual for your Mac, filmed like a cosy product short. The brag
is that the charm *behaves like a real object*: it drops out of the menu bar on
its cord, the rope bends where the pointer flicks it, and the daruma actually
gets its eyes painted as the wish progresses. Every moving shot is rendered from
Tassel's own rope physics (`TasselCore.Rope`) and its own drawings, not faked.

## Hook (first 2-3 seconds)
A quiet Mac desktop. "Your menu bar is missing something." Then a maneki neko
drops out of the menu bar on its beaded cord and bounces to a stop.

## Key moments (the middle)
- The flick: the pointer whips through the cord and it bends into an S-curve,
  and the cat swings out and settles.
- The pull: the hand comes back, takes hold of the cat, drags it right down
  until the cord is stretched taut, and lets go — the cord springs back and
  throws the cat into a tumbling swing.
- The size: the Size submenu sets the charm to Small, then to Extra Large, and
  the camera pulls back to the whole screen so the size reads against it.
- The ritual: right-click the daruma → "Make a Wish" → one eye is painted.
  Right-click again → "My Wish Came True" → the other eye.
- Picking a charm: the Tassel menu opens from the menu bar, Charm ▸ lists every
  charm with its own drawing, and the charm on the cord is swapped — first to the
  pysanka, then to the daruma — each arriving with the app's own Drop In swing.

## Outro / punchline
App icon, "Tassel", "Free & open source · macOS 14+", the GitHub address.

## User flow worth showing
Install → the charm drops from the menu bar → flick it → pull it down and let
go → pick a charm → set its size → right-click the charm →
"Make a Wish" → the eye is painted → "My Wish Came True" → the second eye.

## Tone
- Preset: default
- Creative direction: cosy handmade charm film — warm, tactile, a little magical
- Interpretation: comfortable pacing with room for the physics to play out; short
  warm lines, no hype words; soft crossfades; the motion is the star.

## Format: landscape — 1920x1080
## Duration: 31.4s

## Visual identity (from the project)
- Background: an original dusk wallpaper drawn for the video — starfield over a
  sunset glow (#141A3C → #3B2D66 → #8C4F7E → #F0A07A) with three hill silhouettes;
  the outro keeps the same palette
- Accent: bead gold #E8B53A; icon red #E5453A; cord #BD8F42
- Text: #FFFFFF, secondary rgba(255,255,255,0.72)
- Display font: SF Pro (system-ui), bold
- Body font: SF Pro (system-ui)
- Strongest visual element: the charm swinging on its beaded cord under the menu bar

## Share copy (draft)
I made Tassel: a hand-drawn lucky charm that hangs from your Mac's menu bar, swings
when you flick it, and asks you to paint the daruma's eye when your wish comes true.

## Audio direction
- Role: warm bed with a few tactile accents
- Music: happy-beats-business-moves-vol-9 (laid-back, 114.8 BPM)
- Music treatment: 0.32 volume, short fade-in, fade out under the outro
- Music cue guidance: preset `happy-beats-business-moves-vol-9-by-ende-dot-app.music-cues.json`.
  Strong cues: 3.70s (title), 6.34s (flick scene), 10.54s (the cord at full
  stretch), 12.65s (menu cut), 14.76s (first charm swap).
  Beat 23.17s for the logo landing.
- Audio-reactive treatment: none — the charm's own motion is the living element.
- SFX posture: sparse, motion-matched, warm (low/medium HF risk)
- Audio-coupled moments: charm drop landing; taking hold of the charm; the
  release and the cord springing back; right-clicks and menu clicks; eye
  painted (small sparkle); wish came true (soft bell); logo land.
- Restraint rule: no sound for every bead or every flick; nothing sharp or glassy on repeat.

## Storyboard

Everything on screen is at its real size: a 1440x900-point desktop — this Mac's
own, a 2560x1600 panel at 2x — with a 24pt menu bar and the app's own 44pt charm
on its 150pt cord. Wide, the frame is the screen's full width (the empty bottom
90pt fall outside a 16:9 frame). A camera pushes into the top-right corner of
that screen (2.3x) for the close work and pulls back out at the end, so nothing
is ever drawn larger than life.

### Scene 1 — Hook — 0.0–3.70s — the whole screen
Mock Mac desktop at 1440x900 points: wallpaper, menu bar with Finder's menus,
the system icons and the Tassel status item left of the battery. Left: "Your menu bar is missing something." At 1.05s the
maneki neko drops out of the menu bar on its cord and bounces — small, where it
really hangs.
Audio: settles in, then a soft landing.

### Scene 2 — Reveal — 3.70–6.34s — the camera pushes in (4.18–5.22s)
"Tassel" with the app icon, then "Hand-drawn lucky charms for your menu bar."
Audio: the title lands on the 3.70s strong beat.

### Scene 3 — The flick — 6.34–8.44s
"Flick it. It's a real rope." The pointer whips through the cord at 7.32s; it
bends into a curve and swings the cat out. "It bends, swings and settles."

### Scene 4 — The pull — 8.44–12.65s
"Or take hold and pull it down." The hand comes back for the cat, nudges it on
the way in and waits for it to swing back, closes on it at 9.50s and drags it
down until the cord is stretched to 1.3x its length. At 10.60s it lets go: the
cord springs back, throws the cat up past its resting place and it tumbles into
a swing. "Let go, and the cord springs back."
All of it runs through the app's own holdEnd/releaseEnd, with the open and
closed hand cursors the app sets.

### Scene 5 — Picking a charm — 12.65–17.37s
The pointer clicks the Tassel icon; the real menu drops down, Charm ▸ lists
every charm with its drawing, Pysanka is chosen (14.76s) and then Daruma
(16.85s), each arriving with the app's Drop In swing. "Pick your charm. /
Change it any time from the menu bar."

### Scene 6 — The ritual — 17.37–22.07s
Right-click the daruma → "Make a Wish" → one eye painted (19.00s). Right-click
again → "My Wish Came True" → the other eye (21.03s). "Every charm has a
ritual."

### Scene 7 — The size — 22.07–27.82s
"Any size you like. Small, medium, large — or extra large." Size ▸ Small at
23.64s and the charm shrinks; Size ▸ Extra Large at 25.72s and it grows. From
25.95s the camera pulls back to the whole screen, where the big charm hangs at
the size it really would.

### Scene 8 — Outro — 27.82–31.37s
Navy card: app icon, "Tassel", "Free & open source · macOS 14+",
"github.com/desilva23/Tassel".

**Music mood for this video:** upbeat, warm
**Audio summary:** a laid-back bed that fades in, tactile clicks through the
menus, a swish on the flick and the release, a sparkle and a bell during the
ritual, and a bell as the logo lands before the music fades.
