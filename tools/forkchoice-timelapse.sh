#!/usr/bin/env bash
set -euo pipefail

# Periodically snapshot fork choice and render sequence of PNGs for later animation.
# Requirements: curl, jq, dot (graphviz), optional ffmpeg to stitch video.

ENDPOINT="${1:-http://localhost:7777}"
OUT_DIR="${2:-./logs/forkchoice-timelapse}"
INTERVAL="${3:-2}"
COUNT="${4:-150}"

mkdir -p "$OUT_DIR"

for i in $(seq 1 "$COUNT"); do
  /bin/bash "$(dirname "$0")/export_forkchoice.sh" "$ENDPOINT" "$OUT_DIR" "frame" >/dev/null 2>&1 || true
  sleep "$INTERVAL"
done

echo "Frames saved to: $OUT_DIR"
echo "To make a video (if ffmpeg installed):"
echo "  ffmpeg -y -framerate 5 -pattern_type glob -i '$OUT_DIR/frame-*.png' -c:v libx264 -pix_fmt yuv420p $OUT_DIR/forkchoice.mp4"


