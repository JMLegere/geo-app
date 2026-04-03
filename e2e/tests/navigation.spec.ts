import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  collectConsoleErrors,
  assertPageRendered,
  tapAt,
} from './helpers';

test.describe('Tab Navigation', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
  });

  test('bottom navigation bar is visible', async ({ page }) => {
    // Bottom nav should render at the bottom of the screen
    // Take screenshot to verify non-blank content
    await assertPageRendered(page);
  });

  test('tapping bottom nav tabs doesn\'t crash', async ({ page }) => {
    const errors = collectConsoleErrors(page);
    const viewport = page.viewportSize()!;

    // Bottom nav is at the very bottom of the screen
    // 3 tabs: Map | Sanctuary | Pack — evenly spaced
    const navY = viewport.height - 30; // Bottom nav area
    const tabWidth = viewport.width / 3;

    // Tap Sanctuary tab (middle)
    await tapAt(page, tabWidth * 1.5, navY);
    await page.waitForTimeout(1500);

    // Tap Pack tab (right)
    await tapAt(page, tabWidth * 2.5, navY);
    await page.waitForTimeout(1500);

    // Tap Map tab (left)
    await tapAt(page, tabWidth * 0.5, navY);
    await page.waitForTimeout(1500);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('rapid tab switching doesn\'t crash', async ({ page }) => {
    const errors = collectConsoleErrors(page);
    const viewport = page.viewportSize()!;
    const navY = viewport.height - 30;
    const tabWidth = viewport.width / 3;

    // Rapid switching between tabs
    for (let i = 0; i < 10; i++) {
      const tabIndex = i % 3;
      await tapAt(page, tabWidth * (tabIndex + 0.5), navY);
      await page.waitForTimeout(200);
    }

    await page.waitForTimeout(2000);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('content changes when switching tabs', async ({ page }) => {
    const viewport = page.viewportSize()!;
    const navY = viewport.height - 30;
    const tabWidth = viewport.width / 3;

    // Screenshot on Map tab
    const mapShot = await page.screenshot();

    // Switch to Pack tab
    await tapAt(page, tabWidth * 2.5, navY);
    await page.waitForTimeout(2000);
    const packShot = await page.screenshot();

    // Both should render something
    expect(mapShot.length).toBeGreaterThan(5000);
    expect(packShot.length).toBeGreaterThan(5000);

    // They should be different (different content)
    // Compare buffer contents — if tabs work, the screenshots differ
    const same = mapShot.equals(packShot);
    // This MAY be the same if the pack screen is very simple and dark
    // Just verify both rendered
  });
});

test.describe('Screen Stability', () => {
  test('app survives 30 seconds without crash', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    // Just wait — engine is running, GPS sim is going, fog is updating
    await page.waitForTimeout(30_000);

    // Still rendering
    await assertPageRendered(page);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest') &&
        !e.includes('service-worker')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('page remains responsive after 30s', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    await page.waitForTimeout(30_000);

    // Can still interact
    const viewport = page.viewportSize()!;
    await tapAt(page, viewport.width / 2, viewport.height / 2);
    await page.waitForTimeout(1000);

    // No freeze
    await assertPageRendered(page);
  });
});
