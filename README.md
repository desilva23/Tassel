# Tassel

A charm that hangs from your Mac menu bar, sways gently while you work, and stays
out of the way of every click — until you reach for it.

Tassel is a menu bar accessory: no Dock icon, no window to manage. A cord drops
from your status item with a charm on the end, driven by an actual damped
pendulum, so it drifts on an ambient breeze and swings when you call it.

## Status

Working v0. The charm hangs, sways, swings on a hotkey, and can be swapped for
any emoji you like. See [Not done yet](#not-done-yet) for the gaps.

## Requirements

macOS 14 or later. Xcode is **not** required — the Command Line Tools are enough:

```bash
xcode-select --install
```

## Build and run

```bash
make run
```

That builds the package, assembles `.build/Tassel.app`, ad-hoc signs it, and
launches it. A clover appears in your menu bar with a cord hanging below it.

Other targets:

```bash
make app     # build the .app bundle without launching it
make check   # run the simulation checks
make clean   # remove .build
```

To quit, use **Quit Tassel** in the menu bar item, or:

```bash
pkill -x Tassel
```

## Using it

| Action | How |
|---|---|
| Bat it around | Sweep the pointer through it |
| Swing it | Click it, or <kbd>⌥</kbd><kbd>⌘</kbd><kbd>L</kbd>, or **Drop In** in the menu |
| Move it | Drag it anywhere — let go while moving to sling it |
| Swing it in place | <kbd>⌘</kbd>-drag it |
| Send it to a corner | **Position** submenu |
| Change the charm | **Charm** submenu — eight built-ins, or **Custom Emoji…** |
| Hide it | **Hide Charm** |

### Reaching for it

Sweep the pointer past the charm and it gets knocked aside, then swings back.
The push is scaled by how fast the pointer is moving, so a pointer parked next to
the charm leaves it alone instead of pinning it to one side.

Put the pointer on the charm and a faint ring appears: that is the one spot on
the screen where the app is listening. Click it for a swing. **Drag it and it
moves** — the charm follows your pointer and stays where you let go, cord
lengthening or shortening to suit. Release while still moving and it carries the
speed, so it can be slung into its new spot rather than just appearing there.

<kbd>⌘</kbd>-drag swings it on its cord without moving it.

**Grab With Pointer** in the menu turns all of that off. The charm still sways
and can still be batted around by the pointer, but it stops taking clicks
entirely.

### Where it hangs

By default the charm hangs from the menu bar item and follows it around. The
**Position** submenu also offers the four corners, and **Move…** lets you put it
anywhere: the screen dims, and wherever you click or drag to is where the charm
comes to rest.

The cord always falls from the top edge of the screen, so a charm parked near the
bottom hangs on a long cord and swings slowly, the way a long pendulum actually
does. The breeze eases off as the cord grows — without that, a charm hung near
the bottom flails, because the same swing angle covers far more distance on a
long cord.

Positions are stored as fractions of the screen, so they survive a resolution
change. They are stored per placement, not per display: multi-display placement
is not modelled yet, and the charm always hangs on the screen that owns the menu
bar.

**Move… captures every click on the screen while it is active**, since you have
to be able to click anywhere to choose a spot. It exits the moment you click, and
gives up on its own after 20 seconds if you never do — an app that can trap your
mouse should not depend on you knowing the way out.

The hotkey is registered through Carbon's `RegisterEventHotKey`, which needs no
permissions. Tassel deliberately does not use a global `NSEvent` monitor: that
would put up an Accessibility prompt, and a decorative toy has no business
asking to observe every keystroke you type.

## How it works

```
Sources/
  TasselCore/          no AppKit — runnable and checkable without a screen
    Pendulum.swift     damped pendulum with a movable pivot
    Charm.swift        the glyphs that hang on the cord
    Placement.swift    where the charm hangs, and the solver that resolves it
    Preferences.swift  UserDefaults, with every value clamped on read
  Tassel/              the AppKit layer
    main.swift         launch, as an .accessory app
    AppDelegate.swift  status item, menu, hotkey, anchor tracking
    OverlayWindow.swift transparent click-through panel
    CharmView.swift    the frame loop and the drawing
  TasselChecks/        assertions over TasselCore
```

Three details carry most of the behaviour:

**The window never takes a click.** `OverlayWindow` is a borderless
`.nonactivatingPanel` with `ignoresMouseEvents = true`, sitting one level below
`.statusBar` so it floats over ordinary windows without covering a pulled-down
menu. `canBecomeKey` is `false`, so it can never steal focus from whatever you
are typing in. Its collection behaviour includes `.canJoinAllSpaces` and
`.stationary`, so it follows you between Spaces instead of sliding around.

**The physics is real, and it is testable.** `Pendulum` is a plain value type
with no AppKit in sight: `θ'' = −(g/L)·sinθ − (aₓcosθ + a_y sinθ)/L − b·θ'`,
integrated with semi-implicit Euler at a fixed 1/240 s substep. The pivot's own
acceleration enters as a pseudo-force, which is what makes the charm lag behind
when its anchor is yanked sideways. Long frames are clamped, so waking from
sleep does not fling the charm into orbit.

**It reacts without ever watching you.** The pointer is polled from
`NSEvent.mouseLocation` in the frame loop rather than watched with a global event
monitor, so the charm can respond to the pointer without the app asking for
permission to observe input it has no business seeing.

**Nothing re-resolves the position mid-drag.** The menu bar poll re-derives the
charm's position from its stored placement twice a second, which would yank the
charm out of your hand while you were dragging it. It stands down whenever
`CharmView.isInteracting` is set, and the new placement is written only on
release — not on every frame of the drag.

**It takes clicks only where the charm is.** `ignoresMouseEvents` is a
whole-window switch, and the window covers the entire screen, so leaving it off
would swallow every click you make. `CharmView` instead flips it on only while
the pointer is within grabbing distance of the charm, and back off the moment it
leaves. Everywhere else on the screen, and at every other moment, clicks pass
straight through.

**The anchor moves.** Menu bar items slide around as other apps come and go, and
AppKit posts no notification for it, so `AppDelegate` polls the status item's
window frame twice a second. The pivot is clamped to the top of the visible
screen: on some display configurations AppKit reports the status item *above*
`NSScreen.frame.maxY`, and anchoring blindly there would hang the cord from a
point nobody can see.

Because the charm can be anywhere, the overlay window covers the whole screen,
which would make a full-bounds redraw every frame expensive. `CharmView`
invalidates only the region the cord and charm actually sweep between frames.

## Checks

`make check` runs the assertions in `Sources/TasselChecks`. They cover the parts
that are easy to get quietly wrong: that a pendulum at rest stays at rest, that
damping actually removes energy, that an *undamped* swing conserves its
amplitude (which is the real test of the integrator — explicit Euler fails this
one), that a 12-second frame stays bounded, that a push along the cord is eaten
by the cord while a push across it is not, that letting go of a drag throws the
charm in the direction it was moving, that every placement keeps the charm on
screen and hanging below its pivot, that dragging the charm somewhere and
resolving it again puts it back in the same spot, and that preferences clamp junk
that lands in `UserDefaults`.

They live in an executable rather than a `.testTarget` on purpose. XCTest and
swift-testing both ship with Xcode, not with the Command Line Tools, so
`swift test` fails outright on a CLT-only machine. `make check` works anywhere
Swift does. If you install full Xcode and would rather have XCTest, move the
files into `Tests/TasselCoreTests` and add a `.testTarget` back to
`Package.swift`.

## Not done yet

- No app icon, and no preferences window — cord length and charm size are
  honoured from `UserDefaults` but nothing writes them yet.
- The hotkey is hard-coded in `AppDelegate.setUpHotKey()`.
- Placement is single-display: the charm always hangs on the menu bar screen.
- The grab area is a circle around the charm, not its actual glyph shape, so a
  click just outside a thin charm still passes through to whatever is behind it.
- Dragging can put the charm somewhere you cannot easily reach it again if the
  cord is very short; **Position ▸ Menu Bar** puts it back.
- Cord length is only adjustable indirectly, by moving the charm up or down.
- No Developer ID signature or notarisation, so anyone but you will meet
  Gatekeeper. `make app` ad-hoc signs, which is enough to run locally.
- Bundle identifier is still `com.example.tassel` in `Resources/Info.plist`.
- The `LICENSE` file says `YOUR NAME HERE`. Put your name in it before you push.

## Provenance

This is an independent implementation. It was written from scratch against
public AppKit APIs; no other application's code, binary, or artwork was
examined, decompiled, or copied in the making of it. The charms are Unicode code
points drawn with the system emoji font, and nothing else ships as an asset —
see [ASSETS.md](ASSETS.md), and keep it current as you add things.

The idea of a decorative charm hanging in a desktop UI is not original to this
project and is not claimed as such. Ideas and functionality are not
copyrightable; specific code, artwork, names, and copy are. This project
reimplements the former and borrows none of the latter.

## Renaming it

`Tassel` is a placeholder. To claim a name of your own, check it is free on the
App Store and as a domain, then:

```bash
grep -rl Tassel . --exclude-dir=.build --exclude-dir=.git
```

and rename the directories under `Sources/` to match.

## Licence

MIT — see [LICENSE](LICENSE).
