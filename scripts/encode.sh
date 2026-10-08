#!/usr/bin/env bash
# Encode an animation for the Webflow front-end and print the embed code.
#
# Usage: scripts/encode.sh <input> <slug> [-v N] [-s SIZE] [-p SECONDS] [-b HEXBG]
#   <input>  source animation (mp4/mov/webm/gif/...); alpha is auto-detected
#   <slug>   path under the repo root, mirroring the page: e.g. pricing/enterprise/hero
#            (last segment = file prefix; legacy flat slugs like kleerfi-close still work)
#   -v N     version number (default: highest existing + 1). Old versions are kept.
#   -s SIZE  max width/height in px (default 1920; never upscales)
#   -p SEC   poster frame time in seconds (default 1.0)
#   -b HEX   background for the opaque MP4/poster of transparent sources, and the colour an
#            opaque source fades to with -f (default ffffff)
#   -r FPS   output frame rate (default 30; use 60 for smooth UI motion, ~1.5-2x file size)
#   -f SEC   fade in at the start and out at the end (smooths the loop point)
#   -m A:B   opaque sources: lift the flat baked-in background A (hex) to the page colour B (hex) with a
#            small per-channel gain, so the video blends into the Webflow section (also sets -b to B)
#   -c M:W   quality: x264 CRF for the MP4 and VP9 CRF for the WebM (defaults 23:34; lower = better/bigger)
#   --force  overwrite an existing version (only for versions not yet live in Webflow)
#
# Outputs to <slug>/: <name>-vN.webm, <name>-vN.mp4, <name>-vN-poster.jpg  (name = last slug segment)
# Transparent sources: WebM keeps alpha (Chrome/Firefox). MP4 + poster are flattened onto -b.
# Safari needs an HEVC-alpha .mov (macOS only) -- drop it in as <slug>-vN.mov and re-run
# this script with --embed-only to include it in the embed code.
set -euo pipefail

SIZE=1920; POSTER_T=1.0; BG=ffffff; VER=""; EMBED_ONLY=0; FADE=0; FORCE=0; MATCH=""; BGSET=0; FPS=30; CRF_M=23; CRF_W=34
POS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v) VER="$2"; shift 2;;
    -s) SIZE="$2"; shift 2;;
    -p) POSTER_T="$2"; shift 2;;
    -b) BG="${2#\#}"; BGSET=1; shift 2;;
    -m) MATCH="$2"; shift 2;;
    -c) CRF_M="${2%%:*}"; CRF_W="${2##*:}"; shift 2;;
    -r) FPS="$2"; shift 2;;
    -f) FADE="$2"; shift 2;;
    --force) FORCE=1; shift;;
    --embed-only) EMBED_ONLY=1; shift;;
    -h|--help) sed -n '2,15p' "$0"; exit 0;;
    *) POS+=("$1"); shift;;
  esac
done
[[ ${#POS[@]} -ge 2 ]] || { sed -n '2,15p' "$0"; exit 1; }
IN="${POS[0]}"; SLUG="${POS[1]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SLUG="${SLUG#/}"; SLUG="${SLUG%/}"; BASENAME="${SLUG##*/}"
DIR="$ROOT/$SLUG"; mkdir -p "$DIR"

if [[ -z "$VER" ]]; then
  last=$(ls "$DIR" 2>/dev/null | sed -nE "s/^${BASENAME}-v([0-9]+)[.-].*/\1/p" | sort -n | tail -1)
  if [[ $EMBED_ONLY == 1 ]]; then VER="${last:-1}"; else VER=$(( ${last:-0} + 1 )); fi
fi
NAME="${BASENAME}-v${VER}"; OUT="$DIR/$NAME"
BASE_URL="https://media.getkleercard.com/$SLUG/$NAME"

if [[ $EMBED_ONLY == 0 ]]; then
  [[ -f "$IN" ]] || { echo "Input not found: $IN" >&2; exit 1; }
  [[ -e "$OUT.mp4" && $FORCE == 0 ]] && { echo "$NAME already exists; pass -v to choose another version" >&2; exit 1; }

  PIXFMT=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$IN")
  ALPHA_TAG=$(ffprobe -v error -select_streams v:0 -show_entries stream_tags=alpha_mode -of csv=p=0 "$IN" || true)
  HAS_ALPHA=0
  [[ "$PIXFMT" =~ (yuva|rgba|bgra|argb|abgr|gbrap|pal8|ya8) || "$ALPHA_TAG" == 1 ]] && HAS_ALPHA=1

  # Scale down to fit SIZE, keep aspect, even dimensions, 30fps, never upscale.
  VF="scale='min($SIZE,iw)':'min($SIZE,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2,fps=$FPS"
  if [[ -n "$MATCH" ]]; then
    SRC_BG="${MATCH%%:*}"; TGT="${MATCH##*:}"; TGT="${TGT#\#}"; [[ $BGSET == 0 ]] && BG="$TGT"
    GAINS=$(python3 -c "
a,b='$SRC_BG'.lstrip('#'),'$TGT'
print(*[round(int(b[i:i+2],16)/int(a[i:i+2],16),4) for i in (0,2,4)])")
    read -r GR GG GB <<<"$GAINS"
    VF="colorchannelmixer=rr=$GR:gg=$GG:bb=$GB,$VF"
  fi
  FADE_RGB=""; FADE_A=""
  if [[ "$FADE" != 0 ]]; then
    DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$IN")
    OST=$(awk -v d="$DUR" -v f="$FADE" 'BEGIN{printf "%.3f", d-f}')
    FADE_RGB=",fade=t=in:st=0:d=$FADE:color=0x$BG,fade=t=out:st=$OST:d=$FADE:color=0x$BG"
    FADE_A=",fade=t=in:st=0:d=$FADE:alpha=1,fade=t=out:st=$OST:d=$FADE:alpha=1"
  fi
  # libvpx needs to be told to decode alpha from VP9 webm sources.
  DEC=(); [[ "$IN" == *.webm ]] && DEC=(-c:v libvpx-vp9)

  echo "Encoding $NAME (alpha: $HAS_ALPHA) ..."
  if [[ $HAS_ALPHA == 1 ]]; then
    ffmpeg -hide_banner -loglevel error -y "${DEC[@]}" -i "$IN" -an -vf "$VF,format=yuva420p$FADE_A" \
      -c:v libvpx-vp9 -pix_fmt yuva420p -b:v 0 -crf $CRF_W -row-mt 1 -auto-alt-ref 0 "$OUT.webm"
    FLAT="color=c=0x$BG:s=2x2,format=rgba[bg];[bg][0:v]scale2ref[bg2][v];[bg2][v]overlay=shortest=1,$VF,format=yuv420p"
    FLATV="${FLAT}${FADE_RGB}"
    ffmpeg -hide_banner -loglevel error -y "${DEC[@]}" -i "$IN" -an -filter_complex "$FLATV" \
      -c:v libx264 -preset slow -crf $CRF_M -movflags +faststart "$OUT.mp4"
    ffmpeg -hide_banner -loglevel error -y "${DEC[@]}" -ss "$POSTER_T" -i "$IN" -filter_complex "$FLAT" \
      -frames:v 1 -q:v 3 "$OUT-poster.jpg"
  else
    ffmpeg -hide_banner -loglevel error -y -i "$IN" -an -vf "$VF,format=yuv420p$FADE_RGB" \
      -c:v libvpx-vp9 -b:v 0 -crf $CRF_W -row-mt 1 "$OUT.webm"
    ffmpeg -hide_banner -loglevel error -y -i "$IN" -an -vf "$VF,format=yuv420p$FADE_RGB" \
      -c:v libx264 -preset slow -crf $CRF_M -movflags +faststart "$OUT.mp4"
    ffmpeg -hide_banner -loglevel error -y -ss "$POSTER_T" -i "$IN" -vf "$VF" -frames:v 1 -q:v 3 "$OUT-poster.jpg"
  fi
fi

MOV=""
[[ -f "$OUT.mov" ]] && MOV="  <source src=\"$BASE_URL.mov\" type='video/mp4; codecs=\"hvc1\"'>
"
echo; echo "Files in $SLUG/:"; ls -lh "$DIR" | grep "$NAME" | awk '{print "  "$5"  "$9}'
cat <<HTML

----- Paste into a Webflow Embed element -----
<video autoplay muted loop playsinline preload="metadata"
       poster="$BASE_URL-poster.jpg"
       style="width:100%;height:100%;display:block;">
${MOV}  <source src="$BASE_URL.webm" type="video/webm">
  <source src="$BASE_URL.mp4" type="video/mp4">
</video>
----------------------------------------------
HTML
