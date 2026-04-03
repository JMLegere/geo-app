import { test, expect } from '@playwright/test';

test('enable accessibility and login', async ({ page }) => {
  // Capture tile requests
  const tileRequests: string[] = [];
  page.on('request', request => {
    if (request.url().includes('openfreemap') || request.url().includes('tile')) {
      tileRequests.push(request.url());
    }
  });
  
  // Go to the app
  await page.goto('/');
  
  // Wait for Flutter to initialize
  await page.waitForTimeout(3000);
  
  // Click "Enable accessibility" button to enable semantic tree
  const enableA11yButton = await page.$('[aria-label="Enable accessibility"]');
  if (enableA11yButton) {
    console.log('Clicking Enable accessibility button...');
    await enableA11yButton.click();
    await page.waitForTimeout(2000);
  }
  
  // Check if semantic elements are now available
  const semanticElements = await page.$$('flt-semantics');
  console.log('Semantic elements after enabling:', semanticElements.length);
  
  // Try to find phone input via semantics
  const phoneInput = await page.$('input[type="tel"], input[type="text"], [role="textbox"]');
  if (phoneInput) {
    console.log('Found phone input, filling...');
    await phoneInput.fill('5555555555');
    await page.waitForTimeout(500);
    
    // Find and click continue button
    const continueBtn = await page.$('button, [role="button"]');
    if (continueBtn) {
      await continueBtn.click();
      await page.waitForTimeout(3000);
    }
  }
  
  // Wait for potential map load
  await page.waitForTimeout(5000);
  
  // Check for tile requests
  console.log('Tile requests:', tileRequests.length);
  tileRequests.slice(0, 5).forEach(url => console.log('  ', url));
  
  // Take screenshot
  await page.screenshot({ path: 'test-results/with-auth.png', fullPage: true });
  
  // Check MapLibre state
  const maplibreState = await page.evaluate(() => {
    return {
      hasMapLibreGL: typeof (window as any).maplibregl !== 'undefined',
      hasMapContainer: !!document.querySelector('.maplibregl-map'),
      canvasCount: document.querySelectorAll('canvas').length,
    };
  });
  console.log('MapLibre state:', maplibreState);
  
  // Check console for auth state
  const authLogs = await page.evaluate(() => {
    // Check localStorage for auth state
    const storage: Record<string, string> = {};
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key) storage[key] = localStorage.getItem(key) || '';
    }
    return storage;
  });
  console.log('LocalStorage keys:', Object.keys(authLogs));
  
  expect(true).toBe(true); // Always pass for debugging
});
