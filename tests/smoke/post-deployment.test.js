const { test, expect } = require('@playwright/test');

/**
 * Test suite: Post-Deployment Smoke Tests
 * Run against deployed environments to verify deployment success
 *
 * Priority: HIGH - Catches broken deployments before users do
 *
 * Usage:
 *   DEV_URL=https://dev.example.com npm run test:smoke
 *   STAGING_URL=https://staging.example.com npm run test:smoke
 *   PROD_URL=https://prod.example.com npm run test:smoke
 *
 * Environment Variables:
 *   - DEV_URL: Development environment URL
 *   - STAGING_URL: Staging environment URL
 *   - PROD_URL: Production environment URL
 *   - BASE_URL: Default to localhost if not specified
 */

const ENVIRONMENTS = {
  dev: process.env.DEV_URL,
  staging: process.env.STAGING_URL,
  prod: process.env.PROD_URL,
  local: process.env.BASE_URL || 'http://localhost:8080',
};

// Filter out undefined environments
const activeEnvironments = Object.entries(ENVIRONMENTS).filter(([_, url]) => url);

// If no environments configured, default to local
if (activeEnvironments.length === 0) {
  activeEnvironments.push(['local', 'http://localhost:8080']);
}

for (const [envName, baseUrl] of activeEnvironments) {
  test.describe(`Smoke Tests - ${envName.toUpperCase()} (${baseUrl})`, () => {

    test(`should be reachable - ${envName}`, async ({ page }) => {
      const response = await page.goto(baseUrl, { timeout: 30000 });

      expect(response).not.toBeNull();
      expect(response.status()).toBe(200);

      console.log(`✓ ${envName.toUpperCase()} is reachable (HTTP ${response.status()})`);
    });

    test(`should have correct content-type header - ${envName}`, async ({ page }) => {
      const response = await page.goto(baseUrl);

      const contentType = response.headers()['content-type'];
      expect(contentType).toContain('text/html');

      console.log(`✓ Content-Type: ${contentType}`);
    });

    test(`should have security headers - ${envName}`, async ({ page }) => {
      const response = await page.goto(baseUrl);
      const headers = response.headers();

      // Required security headers
      expect(headers['x-frame-options']).toBe('DENY');
      expect(headers['x-content-type-options']).toBe('nosniff');
      expect(headers['x-xss-protection']).toBe('1; mode=block');
      expect(headers['referrer-policy']).toBe('no-referrer-when-downgrade');

      console.log('✓ Security headers present:', {
        'X-Frame-Options': headers['x-frame-options'],
        'X-Content-Type-Options': headers['x-content-type-options'],
        'X-XSS-Protection': headers['x-xss-protection'],
        'Referrer-Policy': headers['referrer-policy'],
      });
    });

    test(`should have HTTPS on production - ${envName}`, async ({ page }) => {
      if (envName === 'prod') {
        expect(baseUrl).toMatch(/^https:\/\//);
        console.log('✓ Production uses HTTPS');
      } else if (baseUrl.startsWith('https')) {
        console.log(`✓ ${envName.toUpperCase()} uses HTTPS`);
      } else {
        console.log(`ℹ ${envName.toUpperCase()} uses HTTP (acceptable for non-prod)`);
      }
    });

    test(`should load within acceptable time - ${envName}`, async ({ page }) => {
      const startTime = Date.now();
      await page.goto(baseUrl);
      const loadTime = Date.now() - startTime;

      // Production should be faster than non-prod
      const maxLoadTime = envName === 'prod' ? 2000 : 5000;

      expect(loadTime).toBeLessThan(maxLoadTime);
      console.log(`✓ Page loaded in ${loadTime}ms (threshold: ${maxLoadTime}ms)`);
    });

    test(`should display main content - ${envName}`, async ({ page }) => {
      await page.goto(baseUrl);
      await page.waitForLoadState('networkidle');

      // Check for main container
      const container = page.locator('.container');
      await expect(container).toBeVisible();

      // Check for title
      const h1 = page.locator('h1');
      await expect(h1).toBeVisible();
      const title = await h1.textContent();
      expect(title).toContain('2048');

      console.log('✓ Main content rendered correctly');
    });

    test(`should have valid page title - ${envName}`, async ({ page }) => {
      await page.goto(baseUrl);

      const title = await page.title();
      expect(title.length).toBeGreaterThan(0);
      expect(title).toContain('2048');

      console.log(`✓ Page title: "${title}"`);
    });

    test(`should have no console errors - ${envName}`, async ({ page }) => {
      const errors = [];

      page.on('console', msg => {
        if (msg.type() === 'error') {
          errors.push(msg.text());
        }
      });

      await page.goto(baseUrl);
      await page.waitForLoadState('networkidle');

      // Interact with page to trigger any lazy-loaded errors
      await page.keyboard.press('ArrowUp');
      await page.waitForTimeout(500);

      if (errors.length > 0) {
        console.log('Console errors detected:', errors);
      }

      expect(errors).toHaveLength(0);
      console.log('✓ No console errors');
    });

    test(`should have no JavaScript errors - ${envName}`, async ({ page }) => {
      const pageErrors = [];

      page.on('pageerror', error => {
        pageErrors.push(error.message);
      });

      await page.goto(baseUrl);
      await page.waitForLoadState('networkidle');

      if (pageErrors.length > 0) {
        console.log('JavaScript errors detected:', pageErrors);
      }

      expect(pageErrors).toHaveLength(0);
      console.log('✓ No JavaScript errors');
    });

    test(`should return correct status for 404 pages - ${envName}`, async ({ page }) => {
      const response = await page.goto(`${baseUrl}/nonexistent-page-12345`, {
        waitUntil: 'domcontentloaded',
      }).catch(e => null);

      if (response) {
        // Server should return 404 for non-existent pages
        expect(response.status()).toBe(404);
        console.log('✓ 404 pages handled correctly');
      } else {
        console.log('ℹ 404 handling test skipped (navigation failed)');
      }
    });

    test(`should have responsive viewport meta tag - ${envName}`, async ({ page }) => {
      await page.goto(baseUrl);

      const viewport = await page.locator('meta[name="viewport"]').getAttribute('content');
      expect(viewport).toContain('width=device-width');

      console.log(`✓ Viewport meta: ${viewport}`);
    });

    test(`should have acceptable response size - ${envName}`, async ({ page }) => {
      const response = await page.goto(baseUrl);
      const body = await response.body();
      const sizeInKB = body.length / 1024;

      // Single page app should be under 200KB
      expect(sizeInKB).toBeLessThan(200);
      console.log(`✓ Response size: ${sizeInKB.toFixed(2)}KB`);
    });

    test(`should be interactive quickly - ${envName}`, async ({ page }) => {
      const startTime = Date.now();
      await page.goto(baseUrl);

      // Wait for page to be interactive
      await page.waitForLoadState('domcontentloaded');
      const interactiveTime = Date.now() - startTime;

      // Should be interactive within 3 seconds
      expect(interactiveTime).toBeLessThan(3000);
      console.log(`✓ Time to interactive: ${interactiveTime}ms`);
    });

    test(`should handle mobile viewport - ${envName}`, async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await page.goto(baseUrl);

      const container = page.locator('.container');
      await expect(container).toBeVisible();

      console.log('✓ Mobile viewport renders correctly');
    });

    test(`should not have mixed content warnings - ${envName}`, async ({ page }) => {
      if (baseUrl.startsWith('https')) {
        const warnings = [];

        page.on('console', msg => {
          if (msg.type() === 'warning' && msg.text().includes('mixed content')) {
            warnings.push(msg.text());
          }
        });

        await page.goto(baseUrl);
        await page.waitForLoadState('networkidle');

        expect(warnings).toHaveLength(0);
        console.log('✓ No mixed content warnings');
      } else {
        console.log('ℹ Mixed content check skipped (HTTP site)');
      }
    });

    test(`should handle rapid navigation - ${envName}`, async ({ page }) => {
      await page.goto(baseUrl);
      await expect(page.locator('.container')).toBeVisible();

      // Rapid refresh
      await page.reload();
      await expect(page.locator('.container')).toBeVisible();

      await page.reload();
      await expect(page.locator('.container')).toBeVisible();

      console.log('✓ Handles rapid navigation correctly');
    });

    test(`should have correct charset - ${envName}`, async ({ page }) => {
      await page.goto(baseUrl);

      const charset = await page.locator('meta[charset]').count();
      expect(charset).toBeGreaterThan(0);

      console.log('✓ Charset meta tag present');
    });
  });
}

// Health check test (runs for all environments)
test.describe('Smoke Tests - Health Checks', () => {
  test('should verify all configured environments are accessible', async ({ page }) => {
    const results = [];

    for (const [envName, baseUrl] of activeEnvironments) {
      try {
        const response = await page.goto(baseUrl, { timeout: 10000 });
        results.push({
          env: envName,
          status: response.status(),
          success: response.status() === 200,
        });
      } catch (error) {
        results.push({
          env: envName,
          status: 'ERROR',
          success: false,
          error: error.message,
        });
      }
    }

    console.log('\n=== Environment Health Summary ===');
    results.forEach(result => {
      const icon = result.success ? '✓' : '✗';
      console.log(`${icon} ${result.env.toUpperCase()}: ${result.status}`);
    });

    // All environments should be accessible
    const allHealthy = results.every(r => r.success);
    expect(allHealthy).toBeTruthy();
  });
});

// Performance baseline test
test.describe('Smoke Tests - Performance Baseline', () => {
  test('should meet performance baseline on all environments', async ({ page }) => {
    const performanceResults = [];

    for (const [envName, baseUrl] of activeEnvironments) {
      const startTime = Date.now();
      await page.goto(baseUrl);
      await page.waitForLoadState('networkidle');
      const loadTime = Date.now() - startTime;

      performanceResults.push({
        env: envName,
        loadTime,
        threshold: envName === 'prod' ? 2000 : 5000,
      });
    }

    console.log('\n=== Performance Summary ===');
    performanceResults.forEach(result => {
      const icon = result.loadTime < result.threshold ? '✓' : '⚠';
      console.log(`${icon} ${result.env.toUpperCase()}: ${result.loadTime}ms (threshold: ${result.threshold}ms)`);
    });

    // Check each environment meets its threshold
    performanceResults.forEach(result => {
      expect(result.loadTime).toBeLessThan(result.threshold);
    });
  });
});
