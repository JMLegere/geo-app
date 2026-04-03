import { test, expect } from '@playwright/test';

test('check WebGL support', async ({ page }) => {
  // Go to the app
  await page.goto('/');
  
  // Wait for page to load
  await page.waitForTimeout(2000);
  
  // Check WebGL support
  const webglInfo = await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
    if (!gl) return { supported: false, reason: 'No WebGL context' };
    
    const debugInfo = (gl as WebGLRenderingContext).getExtension('WEBGL_debug_renderer_info');
    return {
      supported: true,
      renderer: debugInfo ? (gl as WebGLRenderingContext).getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : 'unknown',
      vendor: debugInfo ? (gl as WebGLRenderingContext).getParameter(debugInfo.UNMASKED_VENDOR_WEBGL) : 'unknown',
      version: (gl as WebGLRenderingContext).getParameter((gl as WebGLRenderingContext).VERSION),
    };
  });
  console.log('WebGL info:', webglInfo);
  
  // Check if Flutter app loaded
  const flutterInfo = await page.evaluate(() => {
    return {
      hasFlutterLoader: typeof (window as any)._flutter !== 'undefined',
      hasFlutterApp: !!document.querySelector('flutter-view, flt-app'),
      bodyChildren: document.body.children.length,
      scripts: document.querySelectorAll('script').length,
    };
  });
  console.log('Flutter info:', flutterInfo);
  
  // Check console for errors
  const errors: string[] = [];
  page.on('console', msg => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });
  
  await page.waitForTimeout(5000);
  
  console.log('Console errors:', errors);
  
  // Take screenshot
  await page.screenshot({ path: 'test-results/webgl-check.png' });
  
  expect(webglInfo.supported).toBe(true);
});
