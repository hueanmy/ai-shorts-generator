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

The video has no audio. To add ElevenLabs narration:

```bash
# Generate 6 clips on ElevenLabs (one per scene), save clip1.mp3 … clip6.mp3
# Pad each to scene duration and concatenate:
ffmpeg -i clip1.mp3 -i clip2.mp3 ... \
  -filter_complex "\
    [0:a]apad=whole_dur=3[a1];\
    [1:a]apad=whole_dur=4[a2];\
    [2:a]apad=whole_dur=5[a3];\
    [3:a]apad=whole_dur=6[a4];\
    [4:a]apad=whole_dur=4[a5];\
    [5:a]apad=whole_dur=4[a6];\
    [a1][a2][a3][a4][a5][a6]concat=n=6:v=0:a=1[out]" \
  -map "[out]" voice.mp3

# Mux into the video:
ffmpeg -i output/DATE-SLUG/SLUG-16x9.mp4 -i voice.mp3 \
  -c:v copy -c:a aac -shortest output/DATE-SLUG/SLUG-16x9-final.mp4
```

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
