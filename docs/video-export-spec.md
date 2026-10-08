# KleerCard product animation: render and export spec

Standing rules for any product animation that will be exported as video for the KleerCard website.
Every rule below exists because its absence caused a visible problem in a real export. The numbers are measured,
not guessed.

## 1. What good looks like

- Every element eases into place smoothly, settles on an exact frame, and then **does not move at all**.
- Nothing floats, drifts, bobs or wobbles while it is at rest.
- Edges stay crisp and stable. No shimmer, stair-stepping or flicker, including on elements that are standing still.
- The file plays on phones, not just on desktop.

## 2. Motion rules

1. **Sub-pixel motion only.** All movement, scaling and rotation uses fractional `transform` values. Never move
   things with `left` / `top`, and never round or snap a position, size or angle to whole pixels.
   *Failure seen:* a card's ease-out ended in whole-pixel steps (1.0, 1.0, 0.97, 0.93, 0.19, 0.86, 0.10, 0.70 px
   per frame) instead of slowing smoothly. It read as jitter around the card's edges.
2. **Eases are smooth and monotonic.** Speed rises smoothly, falls smoothly, and reaches exactly 0 px per frame on
   a definite frame. No curves with an infinitely long tail, and no overshoot unless it is designed in.
3. **Rest means rest.** Once an element has settled it holds at exactly 0.00 px of movement until its next
   designed move. No idle float, drift, bob, parallax, noise or slow camera zoom.
   *Failure seen:* a slow 3.5% camera zoom plus small sine floats made the phone and a small card wobble about
   +/-0.15 px roughly 5 to 8 times a second for five seconds. Every edge on them shimmered.
4. **If you want life during a hold, animate something discrete** (text appearing, a value changing, a chart
   drawing, a status switching). Do not animate position.
5. **The background is flat and constant.** No gradient animation, grain, noise or vignette that changes over time.
6. **Cross-fades and state changes are fine** (for example a button changing from "Approve" to "Approved"). They
   are content changes, not jitter.

## 3. Render method

1. **Deterministic, frame by frame.** Render frame `k` at exactly `t = k / fps`. Drive every animation from the
   frame number. Never screen-record or capture in real time, and never let a clock or `requestAnimationFrame`
   decide the timing.
2. **Constant 60 fps.** Not variable frame rate. The frame count must equal `duration x 60` exactly.
3. **No dropped or repeated frames inside motion.** A repeated frame is only acceptable inside a designed hold.
4. **Supersample.** Render at 2x (3840x2160) or higher and downscale to 1920x1080 with a good filter (area or
   Lanczos). This is what gives slow movement smooth anti-aliased edges instead of 1 px jumps.
5. **Check the raw frames before encoding.** An element at rest must be byte-identical from frame to frame, and an
   element mid-ease must change by a smaller amount each frame as it slows.

## 4. Export settings

| Setting | Value |
|---|---|
| Container / codec | MP4, H.264 |
| Profile / level | High, level 4.2 |
| Pixel format | **yuv420p** (never 4:4:4; phones refuse it and show only the still image) |
| Frame rate | Constant 60 fps |
| Resolution | 1920x1080 (16:9). A 1080x1080 square is also delivered for phones (see section 5) |
| Audio | None |
| Quality | Constant quality, x264 CRF 14 to 16, preset slow |
| Keyframes | One about every 60 frames (`-g 60 -keyint_min 60`). **Never** shorter |
| File size | Under 28 MB. There is no minimum. **Never pad a file to make it bigger** |

*Failure seen:* a file was padded to hit a minimum size by setting a keyframe every 3 frames. Every third frame was
re-encoded from scratch, so every edge pulsed at 20 times a second, even on elements that were perfectly still.
A still region went from exactly 0.000 frame-to-frame change to a repeating 0.10, 0.015, 0.104 cycle.

If the file would exceed 28 MB, raise the CRF a little (for example 17 or 18). Do not change the frame rate or
keyframe interval to fit.

## 5. What to deliver for each animation

1. **16:9, 1920x1080**, for desktop.
2. **A re-composed square, 1080x1080**, for phones held vertically. This is a new layout for the square frame, not a
   crop of the 16:9: the same story beats in the same order and at the same timing, with elements rearranged and
   resized so everything stays readable at about 390 px wide.
3. Both use the same motion rules, the same flat background and the same duration.
4. File names: `kleercard-<page>-<name>-<aspect>-60fps.mp4`, for example
   `kleercard-home-hero-16x9-60fps.mp4` and `kleercard-home-hero-1x1-60fps.mp4`.
5. State the **page path** the video belongs to (for example `home`, or `pricing/enterprise`) and a short name
   for it (for example `hero`).

## 6. Colour

- The video background must be one flat off-white, constant for the whole clip. Say which hex you used.
- Do not try to make the video transparent. Transparency needs a separate alpha export (ProRes 4444 or a PNG
  sequence). When the background matches the page, none is needed. The pipeline lifts the video's flat background
  to the page colour (currently `#fbf9f8` on the home page) when it encodes.

## 7. Report back before handing the file over

Please confirm, with the real numbers from the file you are delivering:

1. Frame count (should be `duration x 60`) and that the frame rate is constant 60 fps.
2. The keyframe interval (should be about 60).
3. That nothing is rounded or snapped to whole pixels.
4. That every element holds at exactly 0.00 px of movement after its ease finishes.
5. That a still region has exactly 0.000 change between consecutive frames (no flicker).
6. The final file size and the background hex.

If you cannot guarantee points 3 to 5 with this export method, say so and say why. Do not hand over a file that
has the problems above.

## 8. How the file is checked on receipt

Run on the delivered MP4 (these are the same tests used to diagnose the problems above):

```bash
# format: expect h264, High, yuv420p, level 42, 60/1, and the expected frame count
ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,profile,level,pix_fmt,width,height,r_frame_rate,nb_frames -of compact FILE.mp4

# keyframes: expect "I" frames about 60 apart (a gap of 3 means the file was padded)
ffprobe -v error -select_streams v:0 -show_entries frame=pict_type -of csv=p=0 FILE.mp4 | grep -n I | head

# timestamps: expect every gap 0.0167 s
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time -of csv=p=0 FILE.mp4 | head -50
```

Then, on decoded frames:

- A region that should be still must change by exactly 0.000 between consecutive frames.
- An edge tracked through an ease must slow down each frame and land on exactly 0.0, with no alternating big and
  small steps.
- Repeated frames are allowed only inside designed holds, not in the middle of motion.
