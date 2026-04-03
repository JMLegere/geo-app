import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // Sequential — app state matters
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'list',
  timeout: 120_000, // 120s per test — Flutter WASM in headless Chrome is slow
  expect: {
    timeout: 30_000, // 30s for assertions
  },
  use: {
    baseURL: 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: {
    command: 'npx serve ../build/web -l 8080 -s --no-clipboard',
    port: 8080,
    timeout: 30_000,
    reuseExistingServer: !process.env.CI,
    cwd: __dirname,
  },
});
