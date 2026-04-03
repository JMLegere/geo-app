import { test, expect } from '@playwright/test';

test('debug map initialization', async ({ page }) => {
  // Capture console messages
  const consoleMessages: string[] = [];
  page.on('console', msg => {
    consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
  });
  
  // Capture JS errors
  const errors: string[] = [];
  page.on('pageerror', error => {
    errors.push(error.message);
  });
  
  // Go to the app
  await page.goto('/');
  
  // Wait for Flutter canvas
  await page.waitForSelector('canvas', { timeout: 10000 });
  
  // Wait for app to initialize
  await page.waitForTimeout(8000);
  
  // Check what's in the DOM
  const bodyHTML = await page.evaluate(() => document.body.innerHTML.substring(0, 2000));
  console.log('Body HTML (first 2000 chars):\n', bodyHTML);
  
  // Check for MapLibre
  const maplibreExists = await page.evaluate(() => {
    return {
      hasMapLibreGL: typeof (window as any).maplibregl !== 'undefined',
      hasMapContainer: !!document.querySelector('.maplibregl-map'),
      hasFlutterCanvas: !!document.querySelector('flt-canvas-view'),
    };
  });
  console.log('MapLibre state:', maplibreExists);
  
  // Print console messages
  console.log('\n--- Console Messages ---');
  consoleMessages.slice(-20).forEach(m => console.log(m));
  
  // Print errors
  if (errors.length > 0) {
    console.log('\n--- JS Errors ---');
    errors.forEach(e => console.log(e));
  }
  
  // Take screenshot
  await page.screenshot({ path: 'test-results/map-debug.png', fullPage: true });
  
  // Check if the dark background is visible
  const pixelData = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return null;
    const ctx = (canvas as any).getContext('2d');
    if (!ctx) return null;
    // Get a sample pixel from the center
    const width = canvas.width;
    const height = canvas.height;
    const imageData = ctx.getImageData(Math.floor(width/2), Math.floor(height/2), 1, 1);
    return { r: imageData.data[0], g: imageData.data[1], b: imageData.data[2], a: imageData.data[3] };
  });
  console.log('Center pixel color:', pixelData);
  
  expect(true).toBe(true); // Always pass - we just want the debug output
});
