import { defineConfig } from '@playwright/test';

// The CLI (scripts/render.sh) sets STORYBOARD_PATH before invoking playwright.
// The test reads it and passes ?storyboard=<path> to render.html.
const STORYBOARD = process.env.STORYBOARD_PATH || 'storyboards/sglang-cve.json';
const SLUG = process.env.STORYBOARD_SLUG || 'video';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  retries: 0,
  timeout: 180_000,

  use: {
    baseURL: 'http://localhost:8787',
  },

  projects: [
    {
      name: `${SLUG}-16x9`,
      use: {
        viewport: { width: 1920, height: 1080 },
        video:    { mode: 'on', size: { width: 1920, height: 1080 } },
      },
    },
    {
      name: `${SLUG}-9x16`,
      use: {
        viewport: { width: 1080, height: 1920 },
        video:    { mode: 'on', size: { width: 1080, height: 1920 } },
      },
    },
  ],

  webServer: {
    command: 'python3 -m http.server 8787',
    port: 8787,
    reuseExistingServer: true,
    stdout: 'ignore',
    stderr: 'pipe',
  },

  outputDir: './videos-raw',
});

export { STORYBOARD };
