#!/usr/bin/env bash
# Render a storyboard JSON → 16:9 + 9:16 MP4s under output/{date}-{slug}/
# Usage: bash scripts/render.sh storyboards/sglang-cve.json
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ $# -lt 1 ]; then
  echo "usage: $0 <storyboard.json>"
  exit 1
fi

STORYBOARD_PATH="$1"
if [ ! -f "$STORYBOARD_PATH" ]; then
  echo "error: $STORYBOARD_PATH not found"
  exit 1
fi

command -v ffmpeg >/dev/null || { echo "ffmpeg missing (brew install ffmpeg)"; exit 1; }
command -v python3 >/dev/null || { echo "python3 missing (needed for http server)"; exit 1; }

# Extract slug + title from JSON (python avoids jq dependency).
SLUG=$(python3 -c "import json,sys; d=json.load(open('$STORYBOARD_PATH')); print(d.get('meta',{}).get('slug','video'))")
TITLE=$(python3 -c "import json,sys; d=json.load(open('$STORYBOARD_PATH')); print(d.get('meta',{}).get('title','untitled'))")
DATE=$(date +%Y-%m-%d)
OUT_DIR="$PROJECT_ROOT/output/${DATE}-${SLUG}"

echo "▸ storyboard: $STORYBOARD_PATH"
echo "▸ slug:       $SLUG"
echo "▸ title:      $TITLE"
echo "▸ output:     $OUT_DIR"

# Clean previous raw recording, keep output/ history.
rm -rf "$PROJECT_ROOT/videos-raw"

export STORYBOARD_PATH
export STORYBOARD_SLUG="$SLUG"

echo ""
echo "▸ recording with playwright…"
npx playwright test

echo ""
echo "▸ converting webm → mp4…"
mkdir -p "$OUT_DIR"

find "$PROJECT_ROOT/videos-raw" -name 'video.webm' | while read -r src; do
  project="$(basename "$(dirname "$src")")"
  case "$project" in
    *16x9*) out="$OUT_DIR/${SLUG}-16x9.mp4" ;;
    *9x16*) out="$OUT_DIR/${SLUG}-9x16.mp4" ;;
    *)      out="$OUT_DIR/$project.mp4" ;;
  esac
  echo "  $src → $(basename "$out")"
  ffmpeg -y -nostdin -loglevel error -i "$src" \
    -c:v libx264 -crf 20 -preset slow -pix_fmt yuv420p \
    -movflags +faststart \
    "$out"
done

# Copy the storyboard alongside the video so we have provenance.
cp "$STORYBOARD_PATH" "$OUT_DIR/storyboard.json"

echo ""
echo "✓ Done."
echo "  $OUT_DIR/${SLUG}-16x9.mp4"
echo "  $OUT_DIR/${SLUG}-9x16.mp4"
echo ""
echo "Next steps:"
echo "  • Preview:        open \"$OUT_DIR/${SLUG}-16x9.mp4\""
echo "  • Voice-over:     generate audio on ElevenLabs, then:"
echo "                    ffmpeg -i \"$OUT_DIR/${SLUG}-16x9.mp4\" -i voice.mp3 \\"
echo "                           -c:v copy -c:a aac -shortest \"$OUT_DIR/${SLUG}-16x9-final.mp4\""
