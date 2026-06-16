# ai-shorts-generator

AI-powered social shorts generator: turn any URL or piece of content into **16:9 + 9:16 MP4s** ready for YouTube Shorts, Reels, TikTok, LinkedIn.

Two modes:

- **News**: daily tech / security news clips (25–32s)
- **Promo**: GitHub project marketing videos (25–32s)

Both share the same render engine — only the storyboard content differs.

## Requirements

- Node 18+
- `ffmpeg` (`brew install ffmpeg`)
- `python3` (for the static web server during render)

## Install

```bash
npm install
npm run install:browsers     # playwright chromium
```

## Render a video

```bash
bash scripts/render.sh storyboards/sglang-cve.json
```

Output lands in `output/YYYY-MM-DD-<slug>/`:
- `<slug>-16x9.mp4` — desktop / YouTube / LinkedIn
- `<slug>-9x16.mp4` — Reels / Shorts / TikTok
- `storyboard.json` — copy of the source for provenance

## Generate a storyboard with Claude Code

Inside this project directory, run Claude Code and use the slash skills:

```
/news https://thehackernews.com/...          # tech news URL → storyboard
/promo https://github.com/owner/repo         # GitHub repo → storyboard
```

Claude reads the source, drafts `storyboards/<slug>.json`, shows it for review, and (on approval) calls `scripts/render.sh`.

See [.claude/skills/news/SKILL.md](.claude/skills/news/SKILL.md) and [.claude/skills/promo/SKILL.md](.claude/skills/promo/SKILL.md) for the exact flow.

## Storyboard schema

```json
{
  "meta": {
    "title": "Human-readable title",
    "slug": "kebab-case-slug",
    "theme": "default|danger|warning|success",
    "source": "https://source-url"
  },
  "scenes": [
    { "type": "hero-text",  "duration": 3, "headline": "...", "caption": { "en": "...", "vi": "..." } },
    { "type": "stats-grid", "duration": 4, "stats": [{ "big": "9.8", "label": "CVSS", "accent": true }] },
    { "type": "terminal",   "duration": 5, "lines": [{ "type": "prompt", "text": "$ ..." }] },
    { "type": "code-diff",  "duration": 6, "bad": "...", "good": "..." },
    { "type": "quote",      "duration": 4, "text": "...", "attr": "..." },
    { "type": "iframe",     "duration": 5, "src": "https://...", "badge": "⭐ 1.2k" },
    { "type": "cta-url",    "duration": 4, "label": "...", "url": "...", "sub": "..." }
  ]
}
```

Supported scene types and all fields live in [engine/render.html](engine/render.html) (search for `builders = {`).

## Adding voice-over

The rendered video has no audio. `scripts/voice.sh` generates narration and muxes
it in automatically. It supports two TTS providers, selected with `VOICE_PROVIDER`
(default `elevenlabs`) — the output pipeline is identical either way.

### Inputs (in the output dir)

The script reads these from `output/YYYY-MM-DD-<slug>/`:

- `storyboard.json` — for per-scene `duration` (copied here by `render.sh`)
- `script.txt` — the narration script, split per scene with `[Scene N]` markers
- `<slug>-16x9.mp4` / `<slug>-9x16.mp4` — the silent videos to mux into

> `render.sh` does **not** create `script.txt` — add it yourself (or have Claude
> draft it) before running the voice step.

### ElevenLabs (default)

```bash
ELEVENLABS_API_KEY=xxx bash scripts/voice.sh output/YYYY-MM-DD-<slug>/
```

### 60db

```bash
VOICE_PROVIDER=60db SIXTYDB_API_KEY=xxx bash scripts/voice.sh output/YYYY-MM-DD-<slug>/
```

Find a 60db `voice_id` from `curl https://api.60db.ai/myvoices -H "Authorization: Bearer $SIXTYDB_API_KEY"`.

### Config (env vars or `.env.local`, which is auto-sourced)

| Variable | Provider | Default | Notes |
|----------|----------|---------|-------|
| `VOICE_PROVIDER` | both | `elevenlabs` | `elevenlabs` or `60db` |
| `ELEVENLABS_API_KEY` | elevenlabs | — | required |
| `ELEVENLABS_VOICE_ID` | elevenlabs | `JfznbVXrGXYh0gZo9Lcp` | |
| `ELEVENLABS_MODEL` | elevenlabs | `eleven_turbo_v2_5` | |
| `SIXTYDB_API_KEY` | 60db | — | required |
| `SIXTYDB_VOICE_ID` | 60db | `fbb75ed2-…-38e30524a9a1` | from `/myvoices` |

Example `.env.local`:

```bash
VOICE_PROVIDER=60db
SIXTYDB_API_KEY=sk_live_...
SIXTYDB_VOICE_ID=<your-uuid>
```

### What it outputs

Per scene, it calls the provider's TTS API, fits each clip to its scene `duration`
(pads short clips, speeds up over-long ones up to 1.3×), concatenates to `voice.mp3`,
then muxes into both aspect ratios:

- `output/YYYY-MM-DD-<slug>/voice.mp3`
- `output/YYYY-MM-DD-<slug>/<slug>-16x9-final.mp4`
- `output/YYYY-MM-DD-<slug>/<slug>-9x16-final.mp4`

### How the providers differ (handled internally)

| | ElevenLabs | 60db |
|---|---|---|
| Endpoint | `POST /v1/text-to-speech/{voice_id}` | `POST /tts-synthesize` (REST, non-streaming) |
| Auth | `xi-api-key:` header | `Authorization: Bearer` header |
| Response | raw MP3 bytes | JSON with base64 audio (decoded to MP3) |

Both produce identical `clip<n>.mp3` files, so timing, concat, and mux are shared.

## Project layout

```
ai-shorts-generator/
├── engine/render.html          # the renderer (HTML+CSS+JS, data-driven)
├── storyboards/*.json          # one per video
├── scripts/render.sh           # orchestration: record → convert → move
├── tests/record.spec.ts        # Playwright recorder
├── playwright.config.ts        # 2 projects: -16x9 and -9x16
├── .claude/skills/
│   ├── news/SKILL.md           # /news <url>
│   └── promo/SKILL.md          # /promo <github-url>
└── output/                     # gitignored — generated videos
```
