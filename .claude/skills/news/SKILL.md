---
name: news
description: Generate a 25–32s tech-news video from a news article URL. Fetches the article, drafts a 6-scene storyboard.json, and runs scripts/render.sh to produce 16:9 + 9:16 MP4s. Use when the user pastes a news URL with `/news` or says "make a news video from this link".
---

# /news — tech-news video from a URL

## When the skill fires

- `/news https://thehackernews.com/...`
- `/news` (URL is in the immediately preceding user message)
- User says anything like "dựng video tin này" / "news video from this"

## Step-by-step

### 1. Fetch the article

Use `WebFetch` with a targeted extraction prompt:
> "Extract the key facts: one-sentence headline summary, CVE number (if any), CVSS score, affected product and version, what the bug does (RCE / data leak / DoS / privilege escalation), root cause in 1-2 sentences, patch status, one notable quote or striking number, and who's affected."

If WebFetch returns 403 or an empty body, **fall back to `WebSearch`** with the article title and use 2-3 alternate sources to reconstruct the facts. Always note the original source URL in `meta.source`.

### 2. Classify the tone/theme

| Signal | Theme |
|---|---|
| Critical CVE, active exploitation, no patch | `danger` |
| Moderate CVE, patch available | `warning` |
| Product launch, funding, acquisition | `default` |
| Positive metric (open-sourced, milestone) | `success` |

### 3. Draft a 6-scene storyboard

Aim for **25–32 seconds total**. Suggested structure (adjust for the story):

| # | Type | Budget | What goes here |
|---|---|---|---|
| 1 | `hero-text` | 3s | ⚠️/🔥/🚀 emoji + biggest single number/word (CVSS, $M funding, "10×") + sub = CVE ID or product name |
| 2 | `stats-grid` | 4s | 3–4 key stats (severity · type · target · patch; or users · revenue · speed · region) |
| 3 | `terminal` *or* `quote` | 5–6s | Attack trace for security; striking quote/number for product news |
| 4 | `code-diff` *or* `stats-grid` | 5–6s | Before/after fix for security; feature lineup for product |
| 5 | `quote` | 4–5s | Warning or key insight from the article — cite source |
| 6 | `cta-url` | 4s | CVE ID or product URL · sub = specific action |

### 4. Write `storyboards/<slug>.json`

- `slug`: kebab-case, readable — e.g. `sglang-cve-2026-5760`, `nvidia-q1-earnings`
- `meta.source`: the original URL
- `meta.theme`: as classified above
- Each scene has **`caption: { en, vi }`**:
  - `en`: big on-screen headline, ≤10 words, punchy
  - `vi`: small Vietnamese narration, full sentence (1–2), natural spoken cadence

### 5. Show the JSON and ask

Print the storyboard inline. Ask:
> "OK storyboard này thì render, hay chỉnh gì? (đổi caption / swap scene type / đổi duration)"

### 6. On approval, render

```bash
bash scripts/render.sh storyboards/<slug>.json
```

Then `open output/<date>-<slug>/<slug>-16x9.mp4` for preview.

## Scene schema reference

Engine lives in [engine/render.html](../../../engine/render.html). Scene types:

| Type | Fields |
|---|---|
| `hero-text` | `emoji`, `headline`, `accent` (bool), `sub`, `caption` |
| `stats-grid` | `stats: [{ big, label, accent }]` (2–4 items), `caption` |
| `terminal` | `title`, `lines: [{ type: "prompt"\|"output"\|"error"\|"success", text }]`, `caption` |
| `code-diff` | `badLabel`, `bad`, `goodLabel`, `good` (strings preserve \n), `caption` |
| `quote` | `text`, `attr`, `caption` |
| `iframe` | `src`, `badge`, `caption` |
| `cta-url` | `label`, `url`, `sub`, `caption` |

Every scene also accepts `duration: <seconds>` (default 4).

## Writing tips

- **Security articles**: terminal scene showing the exploit step-by-step is the most cinematic; keep lines ≤ 60 chars to avoid wrap.
- **Product news**: two `stats-grid` scenes beats one long one (alternate with a `quote` for rhythm).
- Caption EN should be speakable in < budget − 1s (Vietnamese TTS later).
- Never bury the main number — put it in scene 1 or 2.
- If the article is paywalled / 403s both fetchers, tell the user and ask them to paste 2-3 key sentences.
