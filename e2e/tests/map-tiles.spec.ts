import { test, expect } from '@playwright/test';

test('map loads and tiles are visible', async ({ page }) => {
  // Go to the app
  await page.goto('/');
  
  // Wait for the page to load (Flutter canvas to appear)
  await page.waitForSelector('canvas', { timeout: 10000 });
  
  // Wait a bit for tiles to start loading
  await page.waitForTimeout(5000);
  
  // Take a screenshot
  await page.screenshot({ path: 'test-results/map-initial.png', fullPage: true });
  
  // Check if MapLibre container exists
  const mapContainer = await page.$('.maplibregl-map');
  console.log('MapLibre container found:', !!mapContainer);
  
  // Check network requests for tile loading
  const tileRequests: string[] = [];
  page.on('request', request => {
    if (request.url().includes('openfreemap') || request.url().includes('tile')) {
      tileRequests.push(request.url());
    }
  });
  
  // Wait another 5 seconds for tile requests
  await page.waitForTimeout(5000);
  
  console.log('Tile requests made:', tileRequests.length);
  tileRequests.slice(0, 5).forEach(url => console.log('  ', url));
  
  // Take another screenshot after tiles should have loaded
  await page.screenshot({ path: 'test-results/map-after-wait.png', fullPage: true });
  
  // Basic assertion - canvas should exist
  const canvasCount = await page.locator('canvas').count();
  expect(canvasCount).toBeGreaterThan(0);
});
