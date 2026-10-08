# Short version: paste into a Claude Design prompt or the design system's notes

**KleerCard product animation video: render and export rules**

**Motion**
- Use fractional (sub-pixel) transforms only. Never round or snap positions, sizes or rotations to whole pixels.
- Every ease is smooth and monotonic and settles on an exact frame at exactly 0 px/frame.
- After an element settles, it holds at exactly 0.00 px of movement. No idle float, drift, bob, wobble, parallax or
  slow camera zoom. For life during a hold, animate something discrete (text, values, a chart drawing), not position.
- The background is one flat off-white, constant for the whole clip. No animated gradient, grain or noise.

**Render**
- A deterministic frame-by-frame render: frame k is at t = k/60, driven by the frame number. Never a real-time
  capture. Constant 60 fps, frame count = duration x 60, no dropped or repeated frames inside motion.
- Render at 2x (3840x2160) or higher and downscale to 1920x1080.

**Export**
- MP4, H.264 High, level 4.2, **yuv420p**, no audio, constant quality (x264 CRF 14-16, preset slow).
- A keyframe about every 60 frames (`-g 60`). **Never shorter. Never pad the file. There is no minimum file size.**
- Under 28 MB. If it is too big, raise the CRF slightly (17-18); do not change the frame rate or keyframe interval.

**Deliver two files per animation**
1. 16:9, 1920x1080 (desktop).
2. A re-composed square, 1080x1080 (phones), with the same story beats and timing, rearranged so everything stays
   readable at about 390 px wide. Not a crop of the 16:9.
- Name them `kleercard-<page>-<name>-16x9-60fps.mp4` and `...-1x1-60fps.mp4`, and tell me the page path and the
  video's short name.

**Before handing over the file, confirm:** the frame count, constant 60 fps, the keyframe interval (about 60), that
nothing is snapped to whole pixels, that every element at rest has exactly 0.00 px of movement, that a still region
has exactly 0.000 change between frames, the background hex, and the file size. If you cannot guarantee that, say
why instead of handing over the file.
