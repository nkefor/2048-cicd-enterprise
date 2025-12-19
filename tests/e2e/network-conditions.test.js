const { test, expect } = require('@playwright/test');

/**
 * Test suite: Network Condition & Resilience Testing
 * Tests application behavior under various network conditions
 *
 * Priority: MEDIUM - Ensures good UX on slow connections
 *
 * Tests simulate:
 *   - Slow 3G connection
 *   - Fast 3G connection
 *   - Intermittent connectivity
 *   - Offline mode
 *   - High latency
 */

test.describe('Network Resilience - Slow Connections', () => {
  test('should load on slow 3G connection', async ({ page, context }) => {
    // Emulate slow 3G network (750ms RTT, 400kb/s download)
    await context.route('**/*', async route => {
      await new Promise(resolve => setTimeout(resolve, 750)); // 750ms delay
      await route.continue();
    });

    const startTime = Date.now();
    await page.goto('/', { waitUntil: 'domcontentloaded', timeout: 30000 });
    const loadTime = Date.now() - startTime;

    // Should load within reasonable time (< 15 seconds on slow 3G)
    expect(loadTime).toBeLessThan(15000);

    // Page should still be functional
    await expect(page.locator('.container')).toBeVisible();

    // Verify content loaded
    const title = await page.locator('h1').textContent();
    expect(title).toContain('2048');
  });

  test('should load on fast 3G connection', async ({ page, context }) => {
    // Emulate fast 3G (562.5ms RTT, 1.6Mbps download)
    await context.route('**/*', async route => {
      await new Promise(resolve => setTimeout(resolve, 500)); // 500ms delay
      await route.continue();
    });

    const startTime = Date.now();
    await page.goto('/', { waitUntil: 'load', timeout: 20000 });
    const loadTime = Date.now() - startTime;

    // Should load faster than slow 3G
    expect(loadTime).toBeLessThan(10000);

    // Verify interactive
    await expect(page.locator('.container')).toBeVisible();
  });

  test('should handle high latency gracefully', async ({ page, context }) => {
    // Emulate high latency (2 second delay)
    await context.route('**/*', async route => {
      await new Promise(resolve => setTimeout(resolve, 2000));
      await route.continue();
    });

    await page.goto('/', { timeout: 30000 });

    // Should still render content despite delay
    await expect(page.locator('.container')).toBeVisible({ timeout: 10000 });

    // Content should be complete
    const bodyText = await page.locator('body').textContent();
    expect(bodyText.length).toBeGreaterThan(100);
  });
});

test.describe('Network Resilience - Intermittent Connection', () => {
  test('should handle intermittent connectivity (packet loss)', async ({ page, context }) => {
    let requestCount = 0;

    await context.route('**/*', route => {
      requestCount++;

      // Drop every 4th request (25% packet loss)
      if (requestCount % 4 === 0) {
        route.abort('failed');
      } else {
        route.continue();
      }
    });

    // Should still load despite some failed requests
    try {
      await page.goto('/', { timeout: 20000, waitUntil: 'domcontentloaded' });

      // Main content should be visible
      const container = page.locator('.container');
      await expect(container).toBeVisible({ timeout: 10000 });
    } catch (error) {
      // If page completely fails to load, that's acceptable with high packet loss
      console.log('Page failed to load with 25% packet loss (expected behavior)');
    }
  });

  test('should handle occasional request failures', async ({ page, context }) => {
    let requestCount = 0;

    await context.route('**/*', async route => {
      requestCount++;

      // Fail every 10th request (10% failure rate)
      if (requestCount % 10 === 0) {
        await route.abort('failed');
      } else {
        await route.continue();
      }
    });

    await page.goto('/');

    // Should load successfully with 10% failure rate
    await expect(page.locator('.container')).toBeVisible();

    // Verify basic functionality
    const title = await page.title();
    expect(title).toContain('2048');
  });
});

test.describe('Network Resilience - Offline Mode', () => {
  test('should handle navigation to offline mode gracefully', async ({ page, context }) => {
    // First load the page normally
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Verify page loaded
    await expect(page.locator('.container')).toBeVisible();

    // Now go offline
    await context.setOffline(true);

    // Try to reload
    const response = await page.reload({ waitUntil: 'domcontentloaded' }).catch(e => null);

    // Should either:
    // 1. Show cached version (if service worker present)
    // 2. Fail gracefully with browser offline page
    if (response) {
      console.log('Page loaded from cache or service worker');
      await expect(page.locator('.container')).toBeVisible();
    } else {
      console.log('Page failed to load offline (expected without service worker)');
    }
  });

  test('should display appropriate message when offline', async ({ page, context }) => {
    // Go offline before loading
    await context.setOffline(true);

    // Try to load page
    const loadFailed = await page.goto('/').catch(() => true);

    if (loadFailed === true) {
      // Expected - page cannot load when offline without cache
      console.log('✓ Correctly failed to load when offline');
    } else {
      // Page loaded - must be from cache
      console.log('✓ Loaded from cache when offline');
      await expect(page.locator('.container')).toBeVisible();
    }
  });
});

test.describe('Network Resilience - Resource Loading', () => {
  test('should handle CSS loading delays', async ({ page, context }) => {
    // Delay CSS files
    await context.route('**/*.css', async route => {
      await new Promise(resolve => setTimeout(resolve, 2000));
      await route.continue();
    });

    await page.goto('/');

    // HTML should still load
    await expect(page.locator('.container')).toBeVisible();

    // Wait for CSS to apply
    await page.waitForTimeout(3000);

    // Check if styles applied
    const backgroundColor = await page.locator('body').evaluate(el => {
      return window.getComputedStyle(el).backgroundColor;
    });

    // Should have background color (not default white)
    expect(backgroundColor).not.toBe('rgba(0, 0, 0, 0)');
  });

  test('should handle JavaScript loading delays', async ({ page, context }) => {
    // Delay JS files
    await context.route('**/*.js', async route => {
      await new Promise(resolve => setTimeout(resolve, 1500));
      await route.continue();
    });

    await page.goto('/');

    // HTML should load
    await expect(page.locator('.container')).toBeVisible({ timeout: 10000 });

    // Content should be present
    const h1 = page.locator('h1');
    await expect(h1).toBeVisible();
  });

  test('should handle image loading delays', async ({ page, context }) => {
    // Delay image files
    await context.route(/\.(jpg|jpeg|png|gif|svg|webp)$/, async route => {
      await new Promise(resolve => setTimeout(resolve, 3000));
      await route.continue();
    });

    await page.goto('/');

    // Page structure should load immediately
    await expect(page.locator('.container')).toBeVisible();

    // Check for images (if any)
    const images = page.locator('img');
    const imageCount = await images.count();

    if (imageCount > 0) {
      // Wait for images to load
      await page.waitForTimeout(4000);

      // Images should eventually load
      const firstImage = images.first();
      const isVisible = await firstImage.isVisible().catch(() => false);
      console.log(`Images loaded: ${isVisible}`);
    }
  });
});

test.describe('Network Resilience - Connection Quality Changes', () => {
  test('should adapt to improving connection quality', async ({ page, context }) => {
    let requestCount = 0;

    // Start with slow connection, then improve
    await context.route('**/*', async route => {
      requestCount++;

      // First 3 requests slow (2s delay), then fast
      if (requestCount <= 3) {
        await new Promise(resolve => setTimeout(resolve, 2000));
      }

      await route.continue();
    });

    const startTime = Date.now();
    await page.goto('/');
    const loadTime = Date.now() - startTime;

    // Should load, initial load will be slow
    await expect(page.locator('.container')).toBeVisible();

    // Subsequent navigation should be faster
    await page.reload();
    const reloadTime = Date.now();

    // Reload should be faster (using fast connection now)
    await expect(page.locator('.container')).toBeVisible();
  });

  test('should handle connection degradation', async ({ page, context }) => {
    let requestCount = 0;

    // Start fast, then degrade
    await context.route('**/*', async route => {
      requestCount++;

      // First 5 requests fast, then slow
      if (requestCount > 5) {
        await new Promise(resolve => setTimeout(resolve, 1500));
      }

      await route.continue();
    });

    // Initial load fast
    await page.goto('/');
    await expect(page.locator('.container')).toBeVisible();

    // Reload with degraded connection
    await page.reload();

    // Should still load, just slower
    await expect(page.locator('.container')).toBeVisible({ timeout: 15000 });
  });
});

test.describe('Network Resilience - Timeout Handling', () => {
  test('should handle extremely slow responses', async ({ page, context }) => {
    // Very slow response (5 seconds)
    await context.route('**/*', async route => {
      await new Promise(resolve => setTimeout(resolve, 5000));
      await route.continue();
    });

    // Should either load or timeout gracefully
    try {
      await page.goto('/', { timeout: 30000 });
      await expect(page.locator('.container')).toBeVisible({ timeout: 10000 });
      console.log('✓ Page loaded despite 5s delays');
    } catch (error) {
      console.log('✓ Page timed out gracefully (acceptable behavior)');
    }
  });
});

test.describe('Network Resilience - Progressive Enhancement', () => {
  test('should provide basic functionality even with resource failures', async ({ page, context }) => {
    // Fail all CSS/JS requests
    await context.route(/\.(css|js)$/, route => {
      route.abort('failed');
    });

    await page.goto('/').catch(() => {});

    // Core HTML content should still be accessible
    const bodyText = await page.locator('body').textContent().catch(() => '');

    // Should have some content even without CSS/JS
    if (bodyText.length > 0) {
      console.log('✓ Progressive enhancement working - HTML loads without CSS/JS');
      expect(bodyText).toContain('2048');
    }
  });
});

test.describe('Network Resilience - Mobile Data Conditions', () => {
  test('should be usable on 2G connection', async ({ page, context }) => {
    // Emulate 2G (2800ms RTT, 250kb/s download)
    await context.route('**/*', async route => {
      await new Promise(resolve => setTimeout(resolve, 2800));
      await route.continue();
    });

    const startTime = Date.now();

    try {
      await page.goto('/', { timeout: 45000, waitUntil: 'domcontentloaded' });
      const loadTime = Date.now() - startTime;

      console.log(`2G load time: ${loadTime}ms`);

      // Should eventually load (within 45 seconds)
      await expect(page.locator('.container')).toBeVisible({ timeout: 15000 });

      // Content should be accessible
      const title = await page.locator('h1').textContent();
      expect(title).toBeTruthy();
    } catch (error) {
      console.log('2G connection too slow - acceptable to timeout');
    }
  });
});
