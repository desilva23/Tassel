# The launch video

`brag.mp4` — 31.4s, 1920x1080, with `brag.jpg` baked in as its first frame so it
has a poster. `share-copy.txt` is the text that goes with it.

Every moving shot is rendered from Tassel's own physics and drawings, on a
desktop drawn at its real size: a 1440x900-point screen, a 24pt menu bar, a 44pt
charm on a 150pt cord. Nothing is drawn larger than life; a camera pushes in for
the close work instead.

## How it is built

`clip-renderer/main.swift` renders the screen frame by frame from `TasselCore`,
camera and all:

```sh
swiftc -O Sources/TasselCore/*.swift brag-output/clip-renderer/main.swift -o /tmp/render
BG=dusk /tmp/render . main /tmp/frames          # 852 PNGs at 3840x2160
ffmpeg -framerate 30 -i /tmp/frames/%04d.png -vf scale=1920:1080:flags=lanczos \
  -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p \
  brag-output/composition/assets/clips/main.mp4
```

`BG` picks the wallpaper (`dusk`, `aurora`, `desk`). `STILL_AT=9.5` writes that
one frame only, and `PROBE="9.5,10.3"` prints where the charm is at those times —
both for checking a change without rendering the lot.

`composition/` lays the captions, menus, pointer and audio over that clip with
[Hyperframes](https://hyperframes.heygen.com). The menus and the pointer sit on
a `#stage` layer carrying the same camera transform as the clip, so they are
drawn at the size macOS would draw them:

```sh
cd brag-output/composition
npm run check     # must pass with 0 errors
npm run render    # writes renders/composition_<date>.mp4
```

Then the poster is baked into the first frame:

```sh
ffmpeg -ss 5.85 -i renders/<render>.mp4 -frames:v 1 -q:v 3 ../brag.jpg
ffmpeg -i renders/<render>.mp4 -i ../brag.jpg \
  -filter_complex "[1:v]scale=1920:1080,setsar=1[p];[0:v][p]overlay=enable='lt(n,1)'" \
  -c:v libx264 -preset slow -crf 21 -pix_fmt yuv420p -c:a aac -b:a 192k ../brag.mp4
```

`brag-plan.md` is the storyboard and `composition-brief.md` the creative brief;
both describe the video as it stands.

## What is not in here

The music bed is not committed. It is a cut of "Happy Beats / Business Moves
vol. 9" from [ende.app](https://ende.app/en), whose redistribution terms are not
documented, so only the finished video carries it. To rebuild it:

```sh
ffmpeg -i <the track>.mp3 -t 31.37 \
  -af "afade=t=in:st=0:d=1.0,afade=t=out:st=29.77:d=1.6:curve=qsin" \
  -c:a libmp3lame -b:a 192k composition/assets/music/bed.mp3
```

`composition/renders/` is not committed either — it is where a render lands
before the poster is baked in.

The sound effects in `composition/assets/sfx/` are from
[Kenney](https://kenney.nl/), released under CC0.
