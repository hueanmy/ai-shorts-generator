---
name: promo
description: Generate a 25–32s promo/marketing video for a GitHub project. Reads README + repo metadata via `gh` CLI, drafts a 6-scene storyboard.json, and runs scripts/render.sh. Use when the user pastes a GitHub URL with `/promo` or says "marketing video for this repo".
---

# /promo — GitHub project promo video

## When the skill fires

- `/promo https://github.com/owner/repo`
- `/promo` (URL in preceding message)
- User says "làm video quảng cáo cho repo này" / "promo video for this"

## Step-by-step

### 1. Fetch repo metadata

```bash
# Metadata (stars, language, description, topics, homepage)
gh api repos/<owner>/<repo> --jq '{
  name,
  description,
  stars: .stargazers_count,
  forks: .forks_count,
  language,
  topics,
  homepage,
  license: .license.spdx_id,
  created_at,
  pushed_at
}'

# README (first 300 lines — enough to extract hook, install, features)
gh api repos/<owner>/<repo>/readme -H "Accept: application/vnd.github.raw" | head -300
```

Fallback if `gh` isn't authed: `WebFetch` the repo URL and the raw README URL (`https://raw.githubusercontent.com/<owner>/<repo>/main/README.md`).

### 2. Identify the story

Read the README to find:
- **Problem/pain** the project solves (hook)
- **One-liner tagline** (usually the repo `description` or README h1/subtitle)
- **Install / hello-world command** (usually first code block)
- **3–4 headline features** (bullet list after "Features" or from the demo section)
- **Notable number** (stars, users, benchmark, %savings)

### 3. Classify theme

| Project vibe | Theme |
|---|---|
| Developer tool, general-purpose | `default` (blue) |
| Security / risk / alerting | `warning` or `danger` |
| Cost-savings / eco / efficiency | `success` (green) |
| AI / ML / data | `default` |

### 4. Draft the 6-scene storyboard

Aim for 25–32s.

| # | Type | Budget | What goes here |
|---|---|---|---|
| 1 | `hero-text` | 3s | Pain statement from user's POV — e.g. "Burning tokens on Opus?" · emoji 💸/⚡ |
| 2 | `hero-text` | 3s | Project name (accent color) + one-liner tagline + sub = `github.com/...` |
| 3 | `terminal` | 5s | Install + use commands. Show 1-2 prompt lines and a clean success output |
| 4 | `stats-grid` | 5s | 3–4 feature highlights (NOT the metadata numbers — features). Use short labels. |
| 5 | `iframe` *or* `quote` | 5s | **iframe**: `src` = the GitHub URL, badge = "⭐ Nstars" — shows the live repo. Or **quote**: user testimonial / striking README line. |
| 6 | `cta-url` | 4s | `github.com/<owner>/<repo>` · sub = "Star · Install · Contribute" |

### 5. Write `storyboards/<slug>.json`

- `slug`: the repo name kebab-cased (e.g. `claude-token-monitor`)
- `meta.source`: the GitHub URL
- Per-scene captions: EN punchy value-prop (≤10 words), VI narration full sentence

### 6. Review + render

Show the JSON, ask for approval, then:
```bash
bash scripts/render.sh storyboards/<slug>.json
```

Preview: `open output/<date>-<slug>/<slug>-16x9.mp4`.

## Example: `/promo https://github.com/hueanmy/claude-token-monitor`

This is our own project — reference storyboard should echo the marketing video we built ([reference](../../../../claude-token-monitor/plugin/tests/record/marketing.html)):

- Scene 1 hero: 💸 + "Don't burn money on Claude"
- Scene 2 hero: "claude-token-monitor" accent + "Track Claude usage. Catch Opus waste."
- Scene 3 terminal: `python monitor.py summary` → output preview
- Scene 4 stats: "73 suggestions · $2.7K savings · 3 models · 0 setup"
- Scene 5 iframe: GitHub repo live
- Scene 6 cta-url: `github.com/emtyty/claude-token-monitor`

## Schema reference

Same as [/news skill](../news/SKILL.md) — see [engine/render.html](../../../engine/render.html) for builders.

## Writing tips

- **Don't just list features** — frame each as a benefit. `"Runs on Sonnet auto"` beats `"Tier-2 routing via hooks"`.
- **Show, don't tell**: the terminal scene + iframe scene are more convincing than 3 stat grids.
- **Star count is optional** — if < 100 stars, skip it. Focus on what the tool does.
- Captions EN: verbs and outcomes. Captions VI: natural Vietnamese sentences, not translations.
