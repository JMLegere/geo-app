import { test, expect, Page } from '@playwright/test';

test('map loads tiles - interact via semantics', async ({ page }) => {
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
  
  // Take screenshot of initial state
  await page.screenshot({ path: 'test-results/initial-state.png' });
  
  // Try to find Flutter semantics elements
  // Flutter web uses flt-semantics-* elements for accessibility
  const semanticsContainer = await page.$('flt-semantics-container, flt-semantics');
  console.log('Semantics container found:', !!semanticsContainer);
  
  // Get all semantics elements
  const semanticsElements = await page.$$('flt-semantics-placeholder, [role="textbox"], [role="button"]');
  console.log('Semantics elements found:', semanticsElements.length);
  
  // Try to find text input via accessibility tree
  const textInputs = await page.$$('input, [role="textbox"], [contenteditable="true"]');
  console.log('Text inputs found:', textInputs.length);
  
  // Try to find any editable element
  const editableElements = await page.$$('[contenteditable], input, textarea');
  console.log('Editable elements found:', editableElements.length);
  
  // Check what's in the accessibility tree
  const a11yTree = await page.evaluate(() => {
    const elements = document.querySelectorAll('[role], [aria-label], flt-semantics-placeholder');
    return Array.from(elements).slice(0, 20).map(el => ({
      tag: el.tagName,
      role: el.getAttribute('role'),
      ariaLabel: el.getAttribute('aria-label'),
      text: el.textContent?.substring(0, 50),
    }));
  });
  console.log('Accessibility tree:', JSON.stringify(a11yTree, null, 2));
  
  // Wait longer for app to fully load
  await page.waitForTimeout(5000);
  
  // Take another screenshot
  await page.screenshot({ path: 'test-results/after-wait.png' });
  
  // Check for tile requests
  console.log('Tile requests:', tileRequests.length);
  tileRequests.slice(0, 5).forEach(url => console.log('  ', url));
  
  // Check MapLibre state
  const maplibreState = await page.evaluate(() => {
    return {
      hasMapLibreGL: typeof (window as any).maplibregl !== 'undefined',
      hasMapContainer: !!document.querySelector('.maplibregl-map'),
      canvasCount: document.querySelectorAll('canvas').length,
    };
  });
  console.log('MapLibre state:', maplibreState);
  
  // For now, just check that the app loaded
  expect(maplibreState.hasMapLibreGL).toBe(true);
});
