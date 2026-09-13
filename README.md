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

## Install

With [Homebrew](https://brew.sh):

```bash
brew install desilva23/tap/tassel
```

Then open **Tassel** from Applications or Spotlight. `brew upgrade tassel` keeps
it up to date.

### From source

```bash
make install
```

Builds a release bundle, puts it in `/Applications`, and opens it. From then on
it is an ordinary Mac app: double-click it, launch it from Spotlight, or tick
**Open at Login** in its menu to have it start with the machine. Nothing needs a
terminal again.

**Open at Login** stays greyed out until the app is installed somewhere
permanent. `SMAppService` registers the bundle by path, so ticking it while
running out of `.build` would point macOS at something the next `make clean`
deletes. macOS may also list the app under System Settings ▸ General ▸ Login
Items awaiting your approval the first time.

To quit, use **Quit Tassel** in the menu bar item. To remove it, `make uninstall`.

### Giving it to someone

```bash
make dist
```

Makes `.build/Tassel-<version>.dmg`: the app, built to run on both Apple Silicon
and Intel, beside a shortcut to Applications to drag it onto.

The app is not signed with a Developer ID or notarized, so the first time it is
opened macOS refuses and says it cannot check it. Click **Done**, then in
**System Settings ▸ Privacy & Security** scroll down and click **Open Anyway**
beside Tassel. That is needed once; after that it opens like anything else.
Opening with no warning at all needs an Apple Developer Program membership.

It is also published through a Homebrew tap, which installs it with no warning:

```bash
brew install desilva23/tap/tassel
```

To publish a new version there, from a clean `main`:

```bash
make release VERSION=0.1.2 NOTES="What changed."
```

That runs the checks, bumps the version, builds the disk image, releases it on
[desilva23/homebrew-tap](https://github.com/desilva23/homebrew-tap), points the
cask at it and confirms the public download matches the build. It expects the tap
checked out beside this repository, at `../homebrew-tap`. Anyone who has it
already picks the new version up with `brew upgrade tassel`.

## Working on it

```bash
make run     # debug build, assembled and launched from .build
make app     # build the bundle without launching it
make check   # run the simulation checks
make clean   # remove .build
```

## Using it

| Action | How |
|---|---|
| Bat it around | Sweep the pointer through it |
| Swing it | Click it, or <kbd>⌥</kbd><kbd>⌘</kbd><kbd>L</kbd>, or **Drop In** in the menu |
| Move it left or right | Drag the **rope** |
| Pull it and let it recoil | Drag the **charm** |
| Send it to a set spot | **Position** submenu, or **Place…** |
| Bead it, or not | **Beads on the Rope** |
| Resize it | **Size** submenu |
| Change the charm | **Charm** submenu — twelve built-ins, or **Custom Emoji…** |
| Tend it | **Right-click the charm**, or the ritual at the top of the menu |
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

Right-click the charm — or Control-click it — and its ritual is offered right
there: **Make a Wish** on a blank daruma, **Ring It** on the bell. No trip to
the menu bar.

The charm and its rope are the only places on the screen where the app is
listening — everywhere else, clicks go straight through. Click the charm for a
swing.

**What you take hold of decides what the drag does.** Grab the *rope* and drag,
and the whole thing moves to another column. Grab the *charm* and drag, and the
rope stretches and recoils — the charm always comes back where it was.

The pointer says which is which: it becomes an open hand over anything that can
be taken hold of, and a closed one while you are holding it. Cursor *rects*
would be the tidy way to manage that, but they only apply to the key window and
this app never becomes key, so the cursor is set directly, and re-set every
frame — AppKit resets the cursor as the pointer moves inside a window with no
cursor rects of its own, so setting it once does not stick.

Splitting the two across a modifier was tried first and was a mistake twice over.
It is undiscoverable, and the obvious modifier is booby-trapped: macOS reserves
Command-drag on the window of an *inactive* app for its own "move a background
window" gesture, and this app is never active, so a Command-drag may never reach
the charm at all. Two parts of the same object that behave differently is a
better answer than a modifier, and needs no explaining.

### Rituals

The real objects are not ornaments you hang and forget. A daruma waits with a
blank eye until the wish it was bought for comes true. A nimbu mirchi dries out
and is replaced, traditionally on a Saturday. A guardian weathers and is
repainted. So every charm here carries the upkeep its own object asks for —
**Ring It**, **Wipe It Clear**, **Turn Back the Eye**, **Hang a Fresh One** —
and the top item in the menu is whatever that charm needs.

Some objects are not maintained but *progressed*, and for those the ritual
advances through stages instead. The daruma is bought blank; **Make a Wish**
paints one eye, **My Wish Came True** paints the other, and **Start a New Wish**
retires it for a fresh blank one. It never fades — a daruma left one-eyed for
months is a wish still pending, not a neglected charm.

Left alone, any other charm fades. It never fades to nothing: a charm nobody has touched
in a year should look neglected, not disappear. Performing the ritual restores
it, and the menu says *due* once it is more than half gone. The dates are kept
per charm, so tending one does not quietly refresh every other one you might
switch to. A charm that has never been tended starts fresh rather than derelict —
hanging one up is itself the first observance.

### tassel:// URLs

The app answers a `tassel://` URL, so anything that can run a shell command can
ask it for something — a git hook, a Shortcut, a CI script, a cron job. No
integration, no API, no daemon.

```bash
open "tassel://bless"              # before a deploy, a demo, a big meeting
open "tassel://ritual"             # tend the charm
open "tassel://charm?name=Dragon"  # switch charms
open "tassel://show"               # and hide
```

Commands arrive from outside the app, so the parser is a boundary and behaves
like one: it accepts only the verbs it knows, and `charm` resolves only against
the built-in names. A URL can never put arbitrary content on screen. Anything
unrecognised is ignored rather than guessed at.

### What is on the rope

Threading is per charm. Most of them get two beads and a smaller copy of the
charm, which is how these things are actually strung. The beads are coloured
against the charm rather than to match it — gold on the red daruma, red on the
white maneki neko, the red of its thread on the bronze Yansheng — so they read as
beads, not as bits of the charm. The nazar, the bell and the pysanka keep plain
bone. **Nimbu Mirchi** — a lemon under a row of chillies, hung over a doorway to
turn away bad luck — gets the chillies instead, lying across the string and
pointing left and right by turns. **Beads on the Rope** turns the threading off.

Each piece is placed a set number of charm-widths above the charm, not at a fixed
fraction of the rope. A fraction that clears a small charm puts a bead squarely
behind a large one, and the charm is resizable. Where each one lands is then
measured *along* the rope rather than down the screen, so the threading keeps its
spacing while the rope bends, swings and stretches.

A set that will not fit has pieces left off the top rather than squeezed
together. Squeezing keeps the count and ruins the spacing: on a short rope under
a large charm it presses the lowest piece inside the charm itself. Threading on
fewer looks like a choice; threading on all of them badly looks like a bug.

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
    Charm.swift        the glyphs that hang on the cord, and their rituals
    Ritual.swift       upkeep: how a charm fades, and what restores it
    Command.swift      the tassel:// URL boundary
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

The third is **`stretchRecovery`**, which sets how long the snap back takes. It
defaults to a quick snap, which is what looks right; it is a dial because two
more obvious approaches do not work at all, and it is worth recording why.
Damping does nothing: the charm comes back because its *position* is being
corrected by the solver, not because it carries velocity, so damping velocity
leaves the timing untouched — measured across a 30× range, the return stayed at
17–25ms. Softening the rope cannot do it either, because a spring's static sag
and its period are the same number in disguise: `T = 2π√(sag/g)`. Any rope slack
enough to return over half a second also hangs about eighteen points long doing
nothing. So the rope's *rest length itself* recovers instead — stretching raises
the length the constraints aim for, and letting go lets it creep back down. How
the rope hangs is untouched: resting sag is identical whether recovery takes
25ms or 1.5s, which the checks assert.

A held rope needs care that a hanging one does not. While the charm is gripped,
the length the constraints aim for tracks the *span* between the anchor and the
hand — not the rope's own measured length, which includes however much it is
bowing and so lets the bow justify itself, leaving the rope permanently slack.
And every segment is then held to that span, because a rope pinned at both ends
carries its own weight in compression along the lower half, a rope cannot carry
compression, and it buckles: it settles into a stable belly hanging below the
charm, which is real physics and looks like a bug.

The fourth is **`constraintDamping`**, and it is the subtle one. Because a Verlet
constraint is satisfied by moving a node, and moving a node *is* velocity, a
solver that has not fully converged feeds a trickle of velocity in on every step
— and ordinary damping never sees it, because that runs before the solve. Left
alone the charm never comes to rest: it settles into a permanent faint quiver of
about two points, and adding relaxation passes only slows the bleed rather than
stopping it. Damping the velocity *after* the solve fixes it outright, and a
small value does the job — measured over ten seconds, residual motion goes from
roughly 14 points per second to zero while a throw keeps most of its carry.

**Drawn charms hang by their drawing, not their page.** Artwork is placed by
finding the opaque part of the image and hanging the charm from the top of that.
Anchoring to the canvas instead means every millimetre of empty margin somebody
leaves above their drawing becomes a length of bare rope, and two charms drawn
at different sizes on the page hang at different sizes on screen. Neither is
something an illustrator should have to think about. Across, the rope meets the
middle of the drawing's topmost sliver — its loop — rather than the middle of the
whole drawing, which a maneki neko's raised paw pulls well off to one side.

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
charm cannot be dragged above its anchor, that no placement changes how far the charm hangs, that clicking the charm never
leaves a loop of rope dangling below it, that a rope pulled taut really is taut
rather than bowing, that everything threaded on the rope stays on it however the
rope is bent or stretched, that no charm's threading hides behind it or collides
with itself at any of the four charm sizes, that a chilli lies across the string
rather than standing upright, that a neglected charm fades but never vanishes,
that a clock jumping backwards cannot make a charm more than fresh, that every
charm carries an upkeep of its own rather than a shared placeholder, that every
`tassel://` verb parses and everything else is refused, and that a URL cannot
invent a charm that does not exist, that lowering the recovery rate really
does slow the return, that recovery speed does not affect how the rope hangs, that dragging the charm somewhere and
resolving it again puts it back in the same spot, and that preferences clamp junk
that lands in `UserDefaults`.

They live in an executable rather than a `.testTarget` on purpose. XCTest and
swift-testing both ship with Xcode, not with the Command Line Tools, so
`swift test` fails outright on a CLT-only machine. `make check` works anywhere
Swift does. If you install full Xcode and would rather have XCTest, move the
files into `Tests/TasselCoreTests` and add a `.testTarget` back to
`Package.swift`.

## Not done yet

- No preferences window — cord length and charm size are
  honoured from `UserDefaults` but nothing writes them yet.
- The hotkey is hard-coded in `AppDelegate.setUpHotKey()`.
- Placement is single-display: the charm always hangs on the menu bar screen.
- One charm that needs drawing is still undrawn: a vegvisir. The maneki neko,
  the pysanka, the daruma and the Yansheng are drawn; see [ASSETS.md](ASSETS.md)
  for how to add another.
- The grab area is a circle around the charm, not its actual glyph shape, so a
  click just outside a thin charm still passes through to whatever is behind it.
- The rope always hangs from the very top of the screen, so it crosses the menu
  bar on its way down.
- The charm cannot be carried closer to its anchor than `minimumSlack` allows. A
  rope with far more length than gap has nowhere to put the excess but a loop,
  and a real rope would; this one is simply not allowed to get there.
- Cord length has no interface: it is read from `UserDefaults`, but nothing
  writes it. `defaults write com.example.tassel cordLength -float 220` works.
- No Developer ID signature or notarisation, so anyone but you will meet
  Gatekeeper. The build ad-hoc signs, which is enough to run on this machine but
  not to hand to anybody else.
- Bundle identifier is still `com.example.tassel` in `Resources/Info.plist`.

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

The code is MIT — see [LICENSE](LICENSE). The drawings (`Resources/Charms`,
`Resources/Templates` and the app icon) are © Desilva Stalin under
[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/): share and adapt
them with credit, but not commercially — see [LICENSE-ART](LICENSE-ART).
