import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  collectConsoleErrors,
  assertPageRendered,
  tapAt,
  pressKey,
} from './helpers';

test.describe('Resilience', () => {
  test('survives page reload', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    // Reload
    await page.reload();
    await waitForFlutterReady(page);

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

  test('survives rapid keyboard input', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    // Spam keys rapidly
    const keys = ['w', 'a', 's', 'd', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'];
    for (let i = 0; i < 50; i++) {
      await page.keyboard.press(keys[i % keys.length]);
    }

    await page.waitForTimeout(3000);
    await assertPageRendered(page);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('survives rapid mouse clicks', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    const viewport = page.viewportSize()!;

    // Click rapidly at various positions
    for (let i = 0; i < 20; i++) {
      const x = Math.random() * viewport.width;
      const y = Math.random() * viewport.height;
      await page.mouse.click(x, y);
    }

    await page.waitForTimeout(3000);
    await assertPageRendered(page);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('survives zoom extremes', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    const viewport = page.viewportSize()!;
    const cx = viewport.width / 2;
    const cy = viewport.height / 2;

    // Zoom way in
    await page.mouse.move(cx, cy);
    for (let i = 0; i < 20; i++) {
      await page.mouse.wheel(0, -200);
      await page.waitForTimeout(100);
    }

    await page.waitForTimeout(1000);

    // Zoom way out
    for (let i = 0; i < 40; i++) {
      await page.mouse.wheel(0, 200);
      await page.waitForTimeout(100);
    }

    await page.waitForTimeout(2000);
    await assertPageRendered(page);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('survives window resize', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    // Resize to mobile
    await page.setViewportSize({ width: 375, height: 667 });
    await page.waitForTimeout(2000);

    // Resize to tablet
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.waitForTimeout(2000);

    // Resize to desktop
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.waitForTimeout(2000);

    await assertPageRendered(page);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('survives offline mode', async ({ page, context }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    // Go offline
    await context.setOffline(true);
    await page.waitForTimeout(5000);

    // Still rendered
    await assertPageRendered(page);

    // Go back online
    await context.setOffline(false);
    await page.waitForTimeout(3000);

    await assertPageRendered(page);
  });
});

test.describe('Long Running', () => {
  test('60 second stress test — keyboard movement + tab switching', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    const viewport = page.viewportSize()!;
    const navY = viewport.height - 30;
    const tabWidth = viewport.width / 3;
    const keys = ['w', 'a', 's', 'd'];

    // 60 seconds of mixed interaction
    const start = Date.now();
    while (Date.now() - start < 60_000) {
      // Move with keyboard
      for (let i = 0; i < 5; i++) {
        await page.keyboard.press(keys[Math.floor(Math.random() * 4)]);
        await page.waitForTimeout(50);
      }

      // Switch tabs occasionally
      if (Math.random() < 0.1) {
        const tab = Math.floor(Math.random() * 3);
        await tapAt(page, tabWidth * (tab + 0.5), navY);
      }

      await page.waitForTimeout(500);
    }

    await assertPageRendered(page);

    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('Deprecation') &&
        !e.includes('manifest') &&
        !e.includes('service-worker')
    );

    console.log(`Errors during 60s stress test: ${fatalErrors.length}`);
    for (const err of fatalErrors.slice(0, 5)) {
      console.log(`  → ${err}`);
    }

    expect(fatalErrors).toHaveLength(0);
  });
});
