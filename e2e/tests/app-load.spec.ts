import { test, expect } from '@playwright/test';

test('check app loading state', async ({ page }) => {
  // Capture ALL console messages
  const messages: { type: string; text: string }[] = [];
  page.on('console', msg => {
    messages.push({ type: msg.type(), text: msg.text() });
  });
  
  // Capture errors
  const errors: string[] = [];
  page.on('pageerror', error => {
    errors.push(error.message);
  });
  
  // Go to the app
  await page.goto('/');
  
  // Wait for Flutter to initialize
  await page.waitForTimeout(10000);
  
  // Check what's in the DOM
  const domInfo = await page.evaluate(() => {
    const body = document.body;
    const canvases = document.querySelectorAll('canvas');
    const fltElements = document.querySelectorAll('[class*="flt"], [class*="flutter"]');
    const loadingElements = document.querySelectorAll('[class*="loading"], [class*="spinner"]');
    
    return {
      bodyHTML: body.innerHTML.substring(0, 3000),
      canvasCount: canvases.length,
      fltElementCount: fltElements.length,
      loadingElementCount: loadingElements.length,
      bodyClasses: body.className,
    };
  });
  
  console.log('\n--- DOM Info ---');
  console.log('Canvas count:', domInfo.canvasCount);
  console.log('FLT elements:', domInfo.fltElementCount);
  console.log('Loading elements:', domInfo.loadingElementCount);
  console.log('Body classes:', domInfo.bodyClasses);
  
  console.log('\n--- Console Messages (last 30) ---');
  messages.slice(-30).forEach(m => {
    if (m.type === 'error' || m.text.includes('error') || m.text.includes('Error') || m.text.includes('AUTH') || m.text.includes('NAV')) {
      console.log(`[${m.type}] ${m.text}`);
    }
  });
  
  console.log('\n--- JS Errors ---');
  errors.forEach(e => console.log(e));
  
  // Take screenshot
  await page.screenshot({ path: 'test-results/app-load.png', fullPage: true });
  
  // Print body HTML for debugging
  console.log('\n--- Body HTML (first 2000 chars) ---');
  console.log(domInfo.bodyHTML);
});
