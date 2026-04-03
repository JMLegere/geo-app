import { test, expect, Page } from '@playwright/test';

/**
 * Login via mock auth (OTP is always '123456')
 */
async function loginViaMockAuth(page: Page) {
  // Wait for login screen
  await page.waitForSelector('input[type="tel"], input[placeholder*="phone"], input[type="text"]', { timeout: 10000 });
  
  // Fill in phone number (E.164 format)
  const phoneInput = await page.$('input[type="tel"], input[type="text"]');
  if (phoneInput) {
    await phoneInput.fill('+15555555555');
  }
  
  // Click send OTP
  const sendOtpBtn = await page.$('button:has-text("Send"), button:has-text("Continue"), button[type="submit"]');
  if (sendOtpBtn) {
    await sendOtpBtn.click();
  }
  
  // Wait for OTP screen
  await page.waitForTimeout(1000);
  
  // Fill in OTP code (mock always accepts '123456')
  const otpInputs = await page.$$('input[type="text"], input[type="tel"], input[inputmode="numeric"]');
  if (otpInputs.length >= 6) {
    // Individual digit inputs
    for (let i = 0; i < 6; i++) {
      await otpInputs[i].fill('1');
      await otpInputs[i].fill('2');
      await otpInputs[i].fill('3');
      await otpInputs[i].fill('4');
      await otpInputs[i].fill('5');
      await otpInputs[i].fill('6');
    }
  } else {
    // Single input for all digits
    const otpInput = await page.$('input[type="text"], input[inputmode="numeric"]');
    if (otpInput) {
      await otpInput.fill('123456');
    }
  }
  
  // Click verify
  const verifyBtn = await page.$('button:has-text("Verify"), button:has-text("Continue"), button[type="submit"]');
  if (verifyBtn) {
    await verifyBtn.click();
  }
  
  // Wait for navigation to complete
  await page.waitForTimeout(3000);
}

test('map loads tiles after auth', async ({ page }) => {
  // Capture console messages
  const consoleMessages: string[] = [];
  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warning' || msg.text().includes('openfreemap')) {
      consoleMessages.push(`[${msg.type()}] ${msg.text()}`);
    }
  });
  
  // Capture network requests for tiles
  const tileRequests: string[] = [];
  page.on('request', request => {
    if (request.url().includes('openfreemap') || request.url().includes('tile')) {
      tileRequests.push(request.url());
    }
  });
  
  // Go to the app
  await page.goto('/');
  
  // Wait for Flutter to initialize
  await page.waitForSelector('canvas', { timeout: 15000 });
  await page.waitForTimeout(2000);
  
  // Try to login
  try {
    await loginViaMockAuth(page);
  } catch (e) {
    console.log('Login attempt failed (may already be logged in):', e);
  }
  
  // Wait for map to potentially load
  await page.waitForTimeout(5000);
  
  // Take screenshot
  await page.screenshot({ path: 'test-results/map-after-auth.png', fullPage: true });
  
  // Check for tile requests
  console.log('Tile requests:', tileRequests.length);
  tileRequests.slice(0, 3).forEach(url => console.log('  ', url));
  
  // Check console for errors
  console.log('\n--- Console Errors/Warnings ---');
  consoleMessages.forEach(m => console.log(m));
  
  // Check MapLibre state
  const maplibreState = await page.evaluate(() => {
    return {
      hasMapLibreGL: typeof (window as any).maplibregl !== 'undefined',
      hasMapContainer: !!document.querySelector('.maplibregl-map'),
      bodyText: document.body.innerText.substring(0, 500),
    };
  });
  console.log('\n--- MapLibre State ---');
  console.log(maplibreState);
  
  // Basic assertion
  expect(tileRequests.length).toBeGreaterThan(0);
});
