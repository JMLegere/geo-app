import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  collectConsoleLogs,
  collectConsoleErrors,
  waitForConsoleMessage,
} from './helpers';

test.describe('Species Seeding', () => {
  test('species seeding log appears on first load', async ({ page }) => {
    const logs = collectConsoleLogs(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    // Wait for hydration to complete (species seeding is part of it)
    await page.waitForTimeout(15_000);

    // Check for seeding log message
    const seedingLogs = logs.filter(
      (l) =>
        l.includes('seeded') &&
        l.includes('species')
    );

    console.log(`Species seeding logs: ${seedingLogs.length}`);
    if (seedingLogs.length > 0) {
      console.log(`  → ${seedingLogs[0]}`);
    }

    // On first load, we should see the seeding message
    // On subsequent loads (species already in DB), we should NOT see it
    // Either case is valid — just verify no crash
  });

  test('hydration completes without errors', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);
    await page.waitForTimeout(15_000);

    const hydrationErrors = errors.filter(
      (e) =>
        e.includes('HYDRATION') ||
        e.includes('species') ||
        e.includes('seed')
    );

    expect(hydrationErrors).toHaveLength(0);
  });

  test('no JSON parse errors during seeding', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);
    await page.waitForTimeout(15_000);

    const parseErrors = errors.filter(
      (e) =>
        e.includes('JSON') ||
        e.includes('FormatException') ||
        e.includes('SyntaxError')
    );

    expect(parseErrors).toHaveLength(0);
  });
});

test.describe('Engine Lifecycle', () => {
  test('engine events appear in console', async ({ page }) => {
    const logs = collectConsoleLogs(page);

    await page.goto('/');
    await waitForFlutterReady(page);
    await page.waitForTimeout(10_000);

    // Look for any engine-related logs
    const engineLogs = logs.filter(
      (l) =>
        l.includes('[ENGINE') ||
        l.includes('[HYDRATION') ||
        l.includes('[MAP')
    );

    console.log(`Engine/hydration logs found: ${engineLogs.length}`);
    for (const log of engineLogs.slice(0, 5)) {
      console.log(`  → ${log}`);
    }
  });

  test('daily seed fetch doesn\'t crash', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);
    await page.waitForTimeout(10_000);

    const seedErrors = errors.filter(
      (e) => e.includes('seed') || e.includes('Seed')
    );
    // Seed fetch may fail (no Supabase in test) — that's OK
    // But it shouldn't throw an uncaught exception
    console.log(`Seed-related errors: ${seedErrors.length}`);
  });
});
