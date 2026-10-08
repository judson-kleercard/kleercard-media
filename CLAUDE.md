# KleerCard media

Static media host for `https://media.getkleercard.com` (GitHub Pages, see `CNAME`).
Webflow embeds videos by absolute URL, so **never delete or rename a published file** --
publish a new version instead.

## Workflow: user supplies an animation
1. Save/locate the source (anything ffmpeg reads; transparency is auto-detected). Raw sources go in
   `source/` (git-ignored) -- do not commit masters.
2. Run `scripts/encode.sh <input> <slug>` (use `-v N`, `-s SIZE`, `-p POSTER_SECONDS`, `-b BGHEX` as needed).
   It writes `<slug>/<slug>-vN.webm`, `.mp4`, and `-poster.jpg`, auto-incrementing the version.
3. Commit the new files and push to the working branch.
4. Give the user the `<video>` embed code the script prints (WebM first, MP4 fallback, poster for slow
   connections; `autoplay muted loop playsinline preload="metadata"`).
5. Tell the user the URLs only work after the branch is merged to the Pages branch.

## Transparency
- WebM (VP9 + alpha) covers Chrome/Firefox/Edge. MP4 and poster are flattened onto `-b` (default white).
- Safari needs an HEVC-alpha `.mov` (`hvc1`), which can only be exported on macOS. If the user supplies
  one, save it as `<slug>/<slug>-vN.mov` and run `scripts/encode.sh x <slug> --embed-only` to get embed
  code with that source listed first.

## Conventions
- **New videos:** the slug is a path mirroring the getkleercard.com page the video lives on, e.g.
  `pricing/enterprise/hero` -> `pricing/enterprise/hero/hero-v1.{webm,mp4}` + `hero-v1-poster.jpg`
  -> `https://media.getkleercard.com/pricing/enterprise/hero/hero-v1.webm`. Ask the user for the page path
  and a short name for the video if not given.
- Webflow home hero section background is `#fbf9f8` (variable "Neutral Secondary"). For opaque sources with a flat baked-in background, use `-m SRCHEX:PAGEHEX` to lift it to the page colour (measure the source with ffmpeg first; hero used `-m f5f3f1:fcfafa -b fbf9f8`).
- Encode flags: `-c M:W` (x264 CRF : VP9 CRF, default 23:34; hero used 17:26 to preserve sub-pixel edge precision), `-r FPS` (default 30; use 60 for smooth UI motion), `-f SEC` fade in/out for a smooth loop, `-p SEC` poster time, `-b HEX` background, `--force` overwrites a version that is not yet live.
- **Legacy flat folders are live in Webflow -- never move or rename:** `kleerfi-close`, `kleerfi-reporting`,
  `kleerfi-fund-accounting`, `close-the-books` (files `<slug>-vN.*`). New versions of these stay in place.
- Source aspect ratio is preserved (square 1920x1920 and 16:9 1920x1080 both occur); max edge 1920, never upscaled; 30fps, no audio.
- `close.*`, `close-poster.jpg` and `index.html` at the root are an old test page.

## Merging
Do not merge to `main` (or open a PR) on your own. When the user says to merge, merge the working branch
into `main` (via PR + merge, using the GitHub tools), then tell them the URLs go live once Pages rebuilds.

## Network access: READ-ONLY. READ-ONLY. READ-ONLY.
The sandbox may be allowed to reach `getkleercard.com`, `*.getkleercard.com` (www, media, ...) and
`kleercard-2026.webflow.io`. That allowlist cannot restrict request types, so this rule is on us:

- **READ ONLY.** Only `GET`/`HEAD` requests to look at pages, headers and files (e.g. confirm a video URL
  returns 200, or read a page's CSS to find a background colour).
- **NEVER WRITE.** No `POST`, `PUT`, `PATCH`, `DELETE`, no form submissions, no uploads, no logins, no
  API calls that change anything on those hosts.
- **READ-ONLY, ALWAYS.** If a task seems to need a write to those hosts, stop and ask the user.

## Checking an animation for jitter
Count repeated frames only where nothing should be paused: a zero-change frame with real motion on both sides
(within ~3 frames) is stutter; zero-change frames in holds between scenes are intentional. Also confirm constant
frame rate (even timestamps) and the expected frame count. Ask Claude Design for a frame-by-frame render at constant
60 fps (not a real-time recording). Drive/GitHub web uploads are capped (10 MB Drive connector download, 25 MB GitHub
web upload, 30 MB chat upload), so ask for a single MP4 under 28 MB and attach it in chat. **Never ask for a minimum file size**: it makes the
exporter pad the file (e.g. a keyframe every 3 frames), which bakes a 20 Hz flicker onto every edge. Ask for a
normal keyframe interval (~1/second, `-g 60`) and constant-quality H.264 (CRF 14-16). Verify with
`ffprobe -show_entries frame=pict_type` (I-frames should be ~60 frames apart) and by checking that a still region
has exactly 0.000 frame-to-frame change.

## Phone compatibility and responsive embeds
- **Always 4:2:0.** MP4 must be H.264 High yuv420p (level 4.2) and WebM VP9 Profile 0 yuv420p. 4:4:4 output
  (what fades/colour filters can silently produce) plays on desktop but phones refuse it and show only the
  poster. `scripts/encode.sh` now forces this; after encoding, confirm with
  `ffprobe -show_entries stream=profile,pix_fmt` (never `yuv444p`/`gbrp`/`High 4:4:4`).
- **`<source media="...">` does nothing for video**, so a lighter mobile file needs a small script. For a hero
  that has a mobile twin (`home/hero` + `home/hero-mobile`, encoded with `-s 1280`), use:

```html
<video autoplay muted loop playsinline preload="metadata"
       poster="https://media.getkleercard.com/home/hero/hero-v1-poster.jpg"
       style="width:100%;height:100%;display:block;">
  <source src="https://media.getkleercard.com/home/hero/hero-v1.webm" type="video/webm">
  <source src="https://media.getkleercard.com/home/hero/hero-v1.mp4" type="video/mp4">
</video>
<script>
(function () {
  var v = document.currentScript.previousElementSibling;
  if (!v || v.tagName !== 'VIDEO') return;
  if (window.matchMedia('(max-width: 767px)').matches) {
    var b = 'https://media.getkleercard.com/home/hero-mobile/hero-mobile-v1';
    v.poster = b + '-poster.jpg';
    v.innerHTML = '<source src="' + b + '.webm" type="video/webm"><source src="' + b + '.mp4" type="video/mp4">';
    v.load();
  }
  var p = v.play();
  if (p && p.catch) p.catch(function () {});
})();
</script>
```
- The poster shows until the first frame decodes, if no source is playable, or if autoplay is blocked (iPhone
  Low Power Mode, some data savers). There is no other switching logic.
