const { test, expect } = require('@playwright/test');

/**
 * Performance Regression Tests
 * Validates performance metrics stay within acceptable thresholds
 */

test.describe('Performance Regression', () => {
  test('page load time should be under 3 seconds', async ({ page }) => {
    const startTime = Date.now();
    await page.goto('/');
    await page.waitForLoadState('load');
    const loadTime = Date.now() - startTime;

    console.log(`Page load time: ${loadTime}ms`);
    expect(loadTime).toBeLessThan(3000);
  });

  test('time to interactive should be under 5 seconds', async ({ page }) => {
    const startTime = Date.now();
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    const ttiTime = Date.now() - startTime;

    console.log(`Time to interactive: ${ttiTime}ms`);
    expect(ttiTime).toBeLessThan(5000);
  });

  test('DOM content should be reasonably sized', async ({ page }) => {
    const response = await page.goto('/');
    const body = await response.body();
    const sizeKB = body.length / 1024;

    console.log(`Page size: ${sizeKB.toFixed(2)} KB`);
    expect(sizeKB).toBeLessThan(500); // Should be under 500KB
  });

  test('should have minimal JavaScript execution time', async ({ page }) => {
    await page.goto('/');

    const metrics = await page.evaluate(() => {
      const perf = performance.getEntriesByType('navigation')[0];
      return {
        domContentLoaded: perf.domContentLoadedEventEnd - perf.domContentLoadedEventStart,
        domComplete: perf.domComplete - perf.domLoading
      };
    });

    console.log(`DOM Content Loaded: ${metrics.domContentLoaded}ms`);
    console.log(`DOM Complete: ${metrics.domComplete}ms`);

    expect(metrics.domContentLoaded).toBeLessThan(1000);
  });

  test('should not have memory leaks during interaction', async ({ page }) => {
    await page.goto('/');

    const initialMetrics = await page.evaluate(() => ({
      memory: (performance as any).memory?.usedJSHeapSize || 0
    }));

    // Simulate interactions
    for (let i = 0; i < 20; i++) {
      await page.keyboard.press('ArrowUp');
      await page.waitForTimeout(50);
      await page.keyboard.press('ArrowRight');
      await page.waitForTimeout(50);
    }

    const finalMetrics = await page.evaluate(() => ({
      memory: (performance as any).memory?.usedJSHeapSize || 0
    }));

    if (finalMetrics.memory > 0 && initialMetrics.memory > 0) {
      const memoryIncrease = finalMetrics.memory - initialMetrics.memory;
      const increasePercent = (memoryIncrease / initialMetrics.memory) * 100;

      console.log(`Memory increase: ${(memoryIncrease / 1024 / 1024).toFixed(2)} MB (${increasePercent.toFixed(1)}%)`);

      // Memory shouldn't increase by more than 50%
      expect(increasePercent).toBeLessThan(50);
    }
  });
});
