import { Page, expect } from '@playwright/test';

/**
 * Wait for Flutter web to finish loading.
 * Flutter emits specific console messages and removes the splash screen.
 */
export async function waitForFlutterReady(page: Page, timeout = 60_000) {
  // Wait for the Flutter engine to initialize.
  // Strategy: wait for either the splash screen removal OR a canvas to appear,
  // whichever comes first. Flutter WASM can take 10-30s in headless Chrome.
  await Promise.race([
    page.waitForFunction(
      () => {
        const splash = document.getElementById('splash-screen-style');
        return !splash || splash.innerHTML === '';
      },
      { timeout }
    ),
    page.waitForSelector('canvas', { timeout }),
  ]);
  // Give Flutter time to render first frame + hydrate
  await page.waitForTimeout(3000);
}

/**
 * Collect console messages of a specific type.
 */
export function collectConsoleLogs(page: Page): string[] {
  const logs: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'log' || msg.type() === 'warning') {
      logs.push(msg.text());
    }
  });
  return logs;
}

/**
 * Collect console errors.
 */
export function collectConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });
  page.on('pageerror', (err) => {
    errors.push(err.message);
  });
  return errors;
}

/**
 * Check that the page has rendered something (not blank/white).
 * Takes a screenshot and verifies it has non-trivial content.
 */
export async function assertPageRendered(page: Page) {
  const screenshot = await page.screenshot();
  expect(screenshot.length).toBeGreaterThan(5000); // Non-trivial image
}

/**
 * Wait for network idle (no requests for 2s).
 */
export async function waitForNetworkIdle(page: Page, timeout = 15_000) {
  await page.waitForLoadState('networkidle', { timeout });
}

/**
 * Check if MapLibre GL JS is loaded.
 */
export async function isMapLibreLoaded(page: Page): Promise<boolean> {
  return page.evaluate(() => typeof (window as any).maplibregl !== 'undefined');
}

/**
 * Get the current page title.
 */
export async function getPageTitle(page: Page): Promise<string> {
  return page.title();
}

/**
 * Check for Flutter semantic nodes (accessibility tree).
 * Flutter web can expose semantics if enabled.
 */
export async function getSemanticsTree(page: Page): Promise<string> {
  return page.evaluate(() => {
    const semanticsHost = document.querySelector('flt-semantics-host');
    return semanticsHost?.innerHTML ?? '';
  });
}

/**
 * Simulate a tap at a specific position on the canvas.
 */
export async function tapAt(page: Page, x: number, y: number) {
  await page.mouse.click(x, y);
}

/**
 * Simulate keyboard input (for WASD movement on web).
 */
export async function pressKey(page: Page, key: string) {
  await page.keyboard.press(key);
}

/**
 * Wait for a specific console log message pattern.
 */
export async function waitForConsoleMessage(
  page: Page,
  pattern: RegExp,
  timeout = 15_000
): Promise<string> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`Timeout waiting for console message matching ${pattern}`)),
      timeout
    );
    page.on('console', (msg) => {
      const text = msg.text();
      if (pattern.test(text)) {
        clearTimeout(timer);
        resolve(text);
      }
    });
  });
}
