import { defineConfig, devices } from '@playwright/test';

/**
 * EarthNova E2E test configuration.
 *
 * Expects a running Flutter web build at BASE_URL (default: http://localhost:8080).
 * 
 * Usage:
 *   # Build and serve Flutter web locally first:
 *   flutter build web --profile && python3 -m http.server 8080 -d build/web
 *   
 *   # Then run tests:
 *   cd e2e && npm test
 *   
 *   # Or against production:
 *   BASE_URL=https://geo-app-production-47b0.up.railway.app npm test
 */
export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  expect: {
    timeout: 10_000,
  },
  fullyParallel: false, // Sequential — single Flutter app instance
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 1,
  reporter: 'html',

  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:8080',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    // Generous viewport — MapLibre needs space
    viewport: { width: 1280, height: 900 },
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
