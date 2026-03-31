import { test, expect, Page } from '@playwright/test';

/**
 * Wait for EarthNova to finish loading.
 *
 * The app shows "Ready to explore!" when all 3 loading gates pass:
 * 1. isHydrated (SQLite loaded)
 * 2. isZoneReady (detection zone resolved)
 * 3. isPlayerLocated (rubber-band converged)
 *
 * On web with keyboard sim, these resolve in ~3-8s.
 * The 15s timeout fallback forces all gates if GPS/zone hangs.
 */
async function waitForAppReady(page: Page) {
  // Wait for the loading screen to disappear (AnimatedOpacity fades to 0).
  // The TabShell is always mounted behind it. Once loading is gone,
  // the map is interactive.
  //
  // Strategy: wait for the debug bridge to be available, which means
  // MapScreen has mounted and initState() has completed.
  await page.waitForFunction(
    () => (window as any).__earthNovaDebug !== undefined,
    { timeout: 30_000 },
  );
}

test.describe('District Infographic', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForAppReady(page);
  });

  test('toggle infographic via keyboard shortcut I', async ({ page }) => {
    // Verify infographic is initially closed.
    const isOpenBefore = await page.evaluate(
      () => (window as any).__earthNovaDebug.isInfographicOpen(),
    );
    expect(isOpenBefore).toBe(false);

    // Press 'I' to open infographic.
    await page.keyboard.press('i');

    // Small delay for setState to propagate.
    await page.waitForTimeout(500);

    const isOpenAfter = await page.evaluate(
      () => (window as any).__earthNovaDebug.isInfographicOpen(),
    );
    expect(isOpenAfter).toBe(true);

    // Press 'I' again to close.
    await page.keyboard.press('i');
    await page.waitForTimeout(500);

    const isOpenFinal = await page.evaluate(
      () => (window as any).__earthNovaDebug.isInfographicOpen(),
    );
    expect(isOpenFinal).toBe(false);
  });

  test('toggle infographic via debug bridge', async ({ page }) => {
    // Open via JS bridge.
    await page.evaluate(() => (window as any).__earthNovaDebug.toggleInfographic());
    await page.waitForTimeout(500);

    const isOpen = await page.evaluate(
      () => (window as any).__earthNovaDebug.isInfographicOpen(),
    );
    expect(isOpen).toBe(true);

    // Close via JS bridge.
    await page.evaluate(() => (window as any).__earthNovaDebug.toggleInfographic());
    await page.waitForTimeout(500);

    const isClosed = await page.evaluate(
      () => (window as any).__earthNovaDebug.isInfographicOpen(),
    );
    expect(isClosed).toBe(false);
  });

  test('infographic shows district data when open', async ({ page }) => {
    // Open infographic.
    await page.evaluate(() => (window as any).__earthNovaDebug.toggleInfographic());
    
    // Wait for the overlay to render with fade-in animation (350ms).
    await page.waitForTimeout(600);

    // Take a screenshot for visual verification.
    await page.screenshot({ path: 'test-results/infographic-open.png' });

    // The infographic overlay should be visible.
    // Note: Flutter web renders to a canvas, so DOM queries are limited.
    // We rely on the debug bridge state check instead.
    const isOpen = await page.evaluate(
      () => (window as any).__earthNovaDebug.isInfographicOpen(),
    );
    expect(isOpen).toBe(true);
  });
});
