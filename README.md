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
| Pull it down | Drag it — it stretches, and springs back when you let go |
| Move it left or right | <kbd>⌘</kbd>-drag it, or the **Position** submenu |
| Resize it | **Size** submenu |
| Change the charm | **Charm** submenu — eight built-ins, or **Custom Emoji…** |
| Hide it | **Hide Charm** |

### Reaching for it

Sweep the pointer through the rope and it gets swept aside, then swings back.
The shove acts on whichever part of the rope is nearby rather than on the charm
alone, so brushing the middle of the rope bends it *there* — the rope curves
rather than swinging as one rigid piece. The push is scaled by how fast the
pointer is moving, so a pointer parked against the rope leaves it alone instead
of pinning it to one side.

Drag the charm past where the rope reaches and the rope stretches to follow, up
to a limit; let go and it recoils.

Put the pointer on the charm and a faint ring appears: that is the one spot on
the screen where the app is listening. Click it for a swing.

**Drag it and the rope stretches.** The charm follows your pointer, the rope
gives — up to about a third longer — and letting go springs it back to exactly
where it started. The rope's resting length never changes, no matter how often
it is pulled. The charm can be pulled down and aside but never lifted above the
point it hangs from, which would fold the rope over itself.

<kbd>⌘</kbd>-drag slides it sideways into a different column instead, keeping its
hanging height.

**Grab With Pointer** in the menu turns all of that off. The charm still sways
and can still be batted around by the pointer, but it stops taking clicks
entirely.

### Where it hangs

By default the charm hangs from the menu bar item and follows it around. The
**Position** submenu offers **Left**, **Centre** and **Right**, and **Place…**
lets you pick any column: the screen dims and you click where you want it.

**Position is horizontal only.** Moving the charm changes which column it hangs
in, never how far down it hangs. That is deliberate: the drop is what the rope
stretches and springs back along, so if a drag could also change the resting
height there would be no way to tell a stretch from a move — you would pull the
charm down and it would simply stay there. How far it hangs is set once, by
`cordLength`, and everything else plays within it.

Positions are stored as a fraction of the screen width, so they survive a
resolution change. Multi-display placement is not modelled yet: the charm always
hangs on the screen that owns the menu bar.

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
    Rope.swift         a flexible rope: Verlet chain with distance constraints
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

**It is a rope, not a pendulum.** This matters more than it sounds. A single
rigid pendulum has exactly one degree of freedom — the angle at its pivot — so
it can only sweep left and right. It is mathematically incapable of bending,
curving, whipping, or going slack, no matter how it is drawn. `Rope` is a chain
of 24 point masses joined by distance constraints: every node moves on its own,
and rope-like motion is what those constraints add up to.

It is integrated with Verlet at a fixed 1/240 s substep. Verlet stores velocity
implicitly, as the gap between a node's current and previous position, which
means satisfying a constraint by simply *moving* a node updates its velocity for
free — so letting go of a rope you were swinging throws it correctly, and a
stretched rope recoils, with no extra bookkeeping for either.

Three details earn their keep. The relaxation sweep **alternates direction** each
pass: a single-direction sweep carries tension only one node per pass, so on a
24-node rope the far end never learns it is being pulled and the rope bows
instead of going taut. And the rope has real **give** — pull the charm past
where the rope reaches and it stretches to follow, then snaps back when released
— bounded by a hard ceiling so a heavy shove cannot tear it apart. Long frames are
clamped, so waking from sleep does not blow the solver up.

The third is **`constraintDamping`**, and it is the subtle one. Because a Verlet
constraint is satisfied by moving a node, and moving a node *is* velocity, a
solver that has not fully converged feeds a trickle of velocity in on every step
— and ordinary damping never sees it, because that runs before the solve. Left
alone the charm never comes to rest: it settles into a permanent faint quiver of
about two points, and adding relaxation passes only slows the bleed rather than
stopping it. Damping the velocity *after* the solve fixes it outright, and a
small value does the job — measured over ten seconds, residual motion goes from
roughly 14 points per second to zero while a throw keeps most of its carry.

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
damping actually settles it, that a push in the middle actually *bends* the rope
(a rigid pendulum scores zero on this one no matter how hard it is pushed, which
is the whole reason the rope exists), that a 12-second frame stays bounded, that the rope holds its
length under an ordinary pointer sweep and survives an absurd one, that letting
go of a drag throws the charm in the direction it was moving, that a stretched
rope recoils past where it was released rather than oozing back, that a stretched
rope comes back to the exact length and resting spot it started from, that the
charm cannot be dragged above its anchor, that no placement changes how far the
charm hangs, that dragging the charm somewhere and
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
- The rope always hangs from the very top of the screen, so it crosses the menu
  bar on its way down.
- Cord length has no interface: it is read from `UserDefaults`, but nothing
  writes it. `defaults write com.example.tassel cordLength -float 220` works.
- No Developer ID signature or notarisation, so anyone but you will meet
  Gatekeeper. `make app` ad-hoc signs, which is enough to run locally.
- Bundle identifier is still `com.example.tassel` in `Resources/Info.plist`.
- The `LICENSE` file says `YOUR NAME HERE`. Put your name in it before you push.

## Provenance

This is an independent implementation, written from scratch against public
AppKit APIs. No other application's code, binary, or artwork has been examined,
decompiled, or copied. Another product's public marketing page was looked at, as
rendered, to understand a behaviour it describes — that its cord bends rather
than swinging rigidly. That is an observation about physics, which is not
something anyone owns; none of its source, assets, copy, or design was taken. The charms are Unicode code
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
