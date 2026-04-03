import { test, expect } from '@playwright/test';
import {
  waitForFlutterReady,
  collectConsoleErrors,
  collectConsoleLogs,
  assertPageRendered,
  isMapLibreLoaded,
  getPageTitle,
} from './helpers';

test.describe('App Load', () => {
  test('page loads without crashing', async ({ page }) => {
    const errors = collectConsoleErrors(page);

    await page.goto('/');
    await waitForFlutterReady(page);

    // No fatal JS errors
    const fatalErrors = errors.filter(
      (e) =>
        !e.includes('favicon') &&
        !e.includes('manifest') &&
        !e.includes('service-worker') &&
        !e.includes('Deprecation')
    );
    expect(fatalErrors).toHaveLength(0);
  });

  test('renders non-blank content', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    await assertPageRendered(page);
  });

  test('page title is set', async ({ page }) => {
    await page.goto('/');
    const title = await getPageTitle(page);
    expect(title.length).toBeGreaterThan(0);
  });

  test('MapLibre GL JS is loaded', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);
    const loaded = await isMapLibreLoaded(page);
    expect(loaded).toBe(true);
  });

  test('Flutter engine initializes within 30s', async ({ page }) => {
    const start = Date.now();
    await page.goto('/');
    await waitForFlutterReady(page, 30_000);
    const elapsed = Date.now() - start;
    expect(elapsed).toBeLessThan(30_000);
  });

  test('no uncaught exceptions on load', async ({ page }) => {
    const pageErrors: string[] = [];
    page.on('pageerror', (err) => pageErrors.push(err.message));

    await page.goto('/');
    await waitForFlutterReady(page);
    // Wait a bit for any deferred errors
    await page.waitForTimeout(3000);

    expect(pageErrors).toHaveLength(0);
  });

  test('WASM loads successfully', async ({ page }) => {
    const wasmRequests: string[] = [];
    page.on('request', (req) => {
      if (req.url().includes('.wasm')) {
        wasmRequests.push(req.url());
      }
    });

    await page.goto('/');
    await waitForFlutterReady(page);

    // Flutter web loads at least one WASM file (CanvasKit or Skwasm)
    expect(wasmRequests.length).toBeGreaterThan(0);
  });
});

test.describe('App Performance', () => {
  test('initial load completes in < 20s', async ({ page }) => {
    const start = Date.now();
    await page.goto('/');
    await waitForFlutterReady(page);
    const loadTime = Date.now() - start;

    console.log(`Initial load: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(20_000);
  });

  test('main.dart.js loads successfully', async ({ page }) => {
    let jsLoaded = false;

    page.on('response', async (response) => {
      if (response.url().includes('main.dart.js') && response.status() === 200) {
        jsLoaded = true;
      }
    });

    await page.goto('/');
    await waitForFlutterReady(page);

    expect(jsLoaded).toBe(true);
  });

  test('no memory leaks on load (heap < 200MB)', async ({ page }) => {
    await page.goto('/');
    await waitForFlutterReady(page);

    const metrics = await page.evaluate(() => {
      if ((performance as any).memory) {
        return {
          usedJSHeapSize: (performance as any).memory.usedJSHeapSize,
          totalJSHeapSize: (performance as any).memory.totalJSHeapSize,
        };
      }
      return null;
    });

    if (metrics) {
      const usedMB = metrics.usedJSHeapSize / 1024 / 1024;
      console.log(`Heap used: ${usedMB.toFixed(1)}MB`);
      expect(usedMB).toBeLessThan(200);
    }
  });
});
