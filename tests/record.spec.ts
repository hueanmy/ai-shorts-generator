import { test } from '@playwright/test';

const STORYBOARD = process.env.STORYBOARD_PATH || 'storyboards/sglang-cve.json';

test.setTimeout(180_000);

test('render storyboard', async ({ page }) => {
  await page.goto(`/engine/render.html?storyboard=/${STORYBOARD}`);

  // Engine sets window.__renderDone = true at the end of the timeline.
  await page.waitForFunction(() => (window as any).__renderDone === true, {
    timeout: 170_000,
  });

  // Tail buffer so the final scene holds in-frame.
  await page.waitForTimeout(800);
});
