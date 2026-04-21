#!/usr/bin/env bash
# Generate ElevenLabs voice narration and mux into existing rendered videos.
#
# Usage:
#   ELEVENLABS_API_KEY=xxx bash scripts/voice.sh output/2026-04-21-sglang-cve-2026-5760/
#
# Reads from <out-dir>:  storyboard.json, script.txt, *-16x9.mp4, *-9x16.mp4
# Writes to <out-dir>:   voice.mp3, *-16x9-final.mp4, *-9x16-final.mp4

set -euo pipefail

OUT_DIR="${1:-}"
if [ -z "$OUT_DIR" ]; then
  echo "usage: bash scripts/voice.sh <output-dir>" >&2
  echo "  required in <output-dir>: storyboard.json, script.txt, *-16x9.mp4, *-9x16.mp4" >&2
  exit 1
fi
OUT_DIR="${OUT_DIR%/}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$ROOT/.env.local" ]; then
  set -a; . "$ROOT/.env.local"; set +a
fi

: "${ELEVENLABS_API_KEY:?ELEVENLABS_API_KEY not set. Add to .env.local or export it}"
VOICE_ID="${ELEVENLABS_VOICE_ID:-JfznbVXrGXYh0gZo9Lcp}"
MODEL_ID="${ELEVENLABS_MODEL:-eleven_turbo_v2_5}"

STORYBOARD="$OUT_DIR/storyboard.json"
SCRIPT_FILE="$OUT_DIR/script.txt"
[ -f "$STORYBOARD" ] || { echo "missing: $STORYBOARD" >&2; exit 1; }
[ -f "$SCRIPT_FILE" ] || { echo "missing: $SCRIPT_FILE" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "→ parsing storyboard.json for scene durations"
N_SCENES=$(node -e '
  const fs = require("fs");
  const sb = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  sb.scenes.forEach((s, i) => {
    fs.writeFileSync(process.argv[2] + "/dur-" + (i+1) + ".txt", String(s.duration ?? 4));
  });
  console.log(sb.scenes.length);
' "$STORYBOARD" "$TMP_DIR")
echo "  ${N_SCENES} scenes"

echo "→ parsing script.txt for narration per scene"
FOUND=$(node -e '
  const fs = require("fs");
  const text = fs.readFileSync(process.argv[1], "utf8");
  const tmp = process.argv[2];
  const re = /^\[Scene (\d+)[^\]]*\][ \t]*\r?\n([\s\S]*?)(?=\r?\n[\s\S]*?^\[Scene |\r?\n[─—]{5,}|\r?\nGhi chú|$)/gm;
  let m, found = 0;
  while ((m = re.exec(text)) !== null) {
    const n = parseInt(m[1], 10);
    const body = m[2].replace(/\r?\n[─—]{5,}[\s\S]*$/, "").trim();
    if (body) {
      fs.writeFileSync(tmp + "/text-" + n + ".txt", body);
      found++;
    }
  }
  console.log(found);
' "$SCRIPT_FILE" "$TMP_DIR")
echo "  ${FOUND} narration blocks extracted"

if [ "$FOUND" != "$N_SCENES" ]; then
  echo "  warning: found $FOUND narration blocks but $N_SCENES scenes — check script.txt markers" >&2
fi

echo "→ calling ElevenLabs TTS (voice=$VOICE_ID, model=$MODEL_ID)"
for i in $(seq 1 "$N_SCENES"); do
  TEXT_FILE="$TMP_DIR/text-$i.txt"
  if [ ! -f "$TEXT_FILE" ]; then
    echo "  scene $i: no narration — skipping" >&2
    continue
  fi
  BODY_FILE="$TMP_DIR/body-$i.json"
  node -e '
    const fs = require("fs");
    const text = fs.readFileSync(process.argv[1], "utf8").trim();
    const body = {
      text,
      model_id: process.argv[2],
      voice_settings: {
        stability: 0.75,
        similarity_boost: 0.95,
        style: 0.0,
        use_speaker_boost: true,
        speed: 1.1
      }
    };
    fs.writeFileSync(process.argv[3], JSON.stringify(body));
  ' "$TEXT_FILE" "$MODEL_ID" "$BODY_FILE"

  HTTP_CODE=$(curl -sS -o "$TMP_DIR/clip$i.mp3" -w "%{http_code}" \
    -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -H "Content-Type: application/json" \
    -d "@$BODY_FILE")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "  scene $i: HTTP $HTTP_CODE" >&2
    head -c 500 "$TMP_DIR/clip$i.mp3" >&2
    echo >&2
    exit 1
  fi
  SIZE=$(wc -c < "$TMP_DIR/clip$i.mp3" | tr -d ' ')
  echo "  scene $i: ok (${SIZE} bytes)"
done

echo "→ padding + concatenating with ffmpeg"
INPUTS=""
FILTER=""
CONCAT=""
for i in $(seq 1 "$N_SCENES"); do
  DUR=$(cat "$TMP_DIR/dur-$i.txt")
  [ -f "$TMP_DIR/clip$i.mp3" ] || { echo "missing clip$i.mp3" >&2; exit 1; }
  INPUTS="$INPUTS -i $TMP_DIR/clip$i.mp3"
  idx=$((i-1))
  FILTER="${FILTER}[${idx}:a]atrim=end=${DUR},apad=whole_dur=${DUR},asetpts=PTS-STARTPTS[a${i}];"
  CONCAT="${CONCAT}[a${i}]"
done
FILTER="${FILTER}${CONCAT}concat=n=${N_SCENES}:v=0:a=1[out]"

ffmpeg -y -loglevel error $INPUTS \
  -filter_complex "$FILTER" \
  -map "[out]" \
  "$OUT_DIR/voice.mp3"
echo "  → $OUT_DIR/voice.mp3"

echo "→ muxing voice.mp3 into videos"
shopt -s nullglob
MUXED=0
for VIDEO in "$OUT_DIR"/*-16x9.mp4 "$OUT_DIR"/*-9x16.mp4; do
  BASE="${VIDEO%.mp4}"
  OUT="${BASE}-final.mp4"
  ffmpeg -y -loglevel error -i "$VIDEO" -i "$OUT_DIR/voice.mp3" \
    -c:v copy -c:a aac -shortest "$OUT"
  echo "  → $OUT"
  MUXED=$((MUXED+1))
done
shopt -u nullglob

if [ "$MUXED" = "0" ]; then
  echo "  warning: no *-16x9.mp4 or *-9x16.mp4 found to mux" >&2
fi

echo "✓ done"
