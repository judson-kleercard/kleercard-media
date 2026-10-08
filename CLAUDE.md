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
- Encode flags: `-f SEC` fade in/out for a smooth loop, `-p SEC` poster time, `-b HEX` background, `--force` overwrites a version that is not yet live.
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
