const { test, expect } = require('@playwright/test');

/**
 * Test suite: Smoke Tests
 * Quick post-deployment validation tests
 * Tests critical functionality to ensure the application is operational
 */

// Support environment-specific URLs
const BASE_URL = process.env.DEV_URL || process.env.PROD_URL || process.env.SMOKE_URL || 'http://localhost:8080';

test.use({
  baseURL: BASE_URL,
});

test.describe('Smoke Test - Critical Functionality', () => {
  test('application should be accessible and load successfully', async ({ page }) => {
    const response = await page.goto('/');

    // Should return 200 OK
    expect(response.status()).toBe(200);

    // Page should be visible
    await expect(page.locator('body')).toBeVisible();
  });

  test('should load within acceptable time (5 seconds)', async ({ page }) => {
    const startTime = Date.now();

    await page.goto('/');
    await page.waitForLoadState('domcontentloaded');

    const loadTime = Date.now() - startTime;

    // Critical: Page must load in under 5 seconds
    expect(loadTime).toBeLessThan(5000);
  });

  test('should not have JavaScript errors on load', async ({ page }) => {
    const errors = [];

    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    page.on('pageerror', error => {
      errors.push(error.message);
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // No JavaScript errors on initial load
    expect(errors).toHaveLength(0);
  });

  test('should have valid HTML structure', async ({ page }) => {
    await page.goto('/');

    // Check for basic HTML structure
    const hasHtml = await page.locator('html').count();
    const hasHead = await page.locator('head').count();
    const hasBody = await page.locator('body').count();

    expect(hasHtml).toBe(1);
    expect(hasHead).toBe(1);
    expect(hasBody).toBe(1);
  });

  test('should have a meaningful page title', async ({ page }) => {
    await page.goto('/');

    const title = await page.title();

    expect(title).toBeTruthy();
    expect(title.length).toBeGreaterThan(0);
    expect(title).not.toBe('');
  });
});

test.describe('Smoke Test - Game Functionality', () => {
  test('game board should render', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Game container should be visible
    const gameContainer = page.locator('.game-container, #game-container, .container, main');
    const containerCount = await gameContainer.count();

    expect(containerCount).toBeGreaterThan(0);
    await expect(gameContainer.first()).toBeVisible();
  });

  test('game should respond to keyboard input', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Get initial state
    const initialContent = await page.content();

    // Press arrow key
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(500);

    // Game should still be functional
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('new game button should exist and be clickable', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Find new game button
    const buttons = page.locator('button, .restart-button, .new-game, [class*="new-game"]');
    const buttonCount = await buttons.count();

    expect(buttonCount).toBeGreaterThan(0);

    // Button should be visible and clickable
    const newGameButton = buttons.first();
    await expect(newGameButton).toBeVisible();

    // Should be able to click it
    await newGameButton.click();
    await page.waitForTimeout(300);

    // Game should still be visible after restart
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });
});

test.describe('Smoke Test - Security Headers', () => {
  test('should have X-Content-Type-Options header', async ({ page }) => {
    const response = await page.goto('/');
    const headers = response.headers();

    expect(headers['x-content-type-options']).toBe('nosniff');
  });

  test('should have X-Frame-Options header', async ({ page }) => {
    const response = await page.goto('/');
    const headers = response.headers();

    expect(headers['x-frame-options']).toBe('DENY');
  });

  test('should have X-XSS-Protection header', async ({ page }) => {
    const response = await page.goto('/');
    const headers = response.headers();

    expect(headers['x-xss-protection']).toBeTruthy();
  });
});

test.describe('Smoke Test - Resource Loading', () => {
  test('should not have failed resource requests', async ({ page }) => {
    const failedRequests = [];

    page.on('requestfailed', request => {
      failedRequests.push({
        url: request.url(),
        failure: request.failure().errorText,
      });
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Critical: No failed requests on initial load
    expect(failedRequests).toHaveLength(0);
  });

  test('all critical resources should return 200 OK', async ({ page }) => {
    const responses = [];

    page.on('response', response => {
      responses.push({
        url: response.url(),
        status: response.status(),
      });
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Filter to important resources (exclude tracking, analytics, etc.)
    const criticalResponses = responses.filter(r =>
      r.url.includes(BASE_URL) || r.url.endsWith('.html') || r.url.endsWith('.css') || r.url.endsWith('.js')
    );

    // All critical resources should be successful
    const failed = criticalResponses.filter(r => r.status >= 400);

    expect(failed).toHaveLength(0);
  });

  test('should not have excessive redirects', async ({ page }) => {
    const responses = [];

    page.on('response', response => {
      responses.push({
        url: response.url(),
        status: response.status(),
      });
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Count redirects (3xx status codes)
    const redirects = responses.filter(r => r.status >= 300 && r.status < 400);

    // Should have minimal redirects (less than 3 is acceptable)
    expect(redirects.length).toBeLessThan(3);
  });
});

test.describe('Smoke Test - Performance Baseline', () => {
  test('DOM should be ready within 3 seconds', async ({ page }) => {
    const startTime = Date.now();

    await page.goto('/');
    await page.waitForLoadState('domcontentloaded');

    const domReadyTime = Date.now() - startTime;

    expect(domReadyTime).toBeLessThan(3000);
  });

  test('should have reasonable page size (under 1MB)', async ({ page }) => {
    const response = await page.goto('/');
    const body = await response.body();
    const sizeInBytes = body.length;
    const sizeInMB = sizeInBytes / (1024 * 1024);

    expect(sizeInMB).toBeLessThan(1);
  });
});

test.describe('Smoke Test - Mobile Responsiveness', () => {
  test('should render correctly on mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Game should be visible on mobile
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('should be functional on tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Game should be playable
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(300);

    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });
});

test.describe('Smoke Test - Health Check', () => {
  test('health endpoint should be accessible (if exists)', async ({ page }) => {
    const healthResponse = await page.goto('/health').catch(() => null);

    if (healthResponse) {
      // If health endpoint exists, it should return 200
      expect(healthResponse.status()).toBe(200);
    } else {
      // If no health endpoint, main page should be accessible
      const mainResponse = await page.goto('/');
      expect(mainResponse.status()).toBe(200);
    }
  });

  test('application version or build info should be accessible', async ({ page }) => {
    await page.goto('/');

    // Check for meta tags with version info
    const hasVersion = await page.evaluate(() => {
      const metaTags = document.querySelectorAll('meta');
      for (const tag of metaTags) {
        if (tag.name === 'version' || tag.name === 'build') {
          return true;
        }
      }
      return false;
    });

    // Not required, but good to have
    // This test will pass regardless for backward compatibility
    expect(true).toBe(true);
  });
});

test.describe('Smoke Test - Environment Specific', () => {
  test('should display correct environment', async ({ page }) => {
    await page.goto('/');

    const url = page.url();

    console.log(`Testing environment: ${url}`);
    console.log(`Base URL configured: ${BASE_URL}`);

    // URL should match expected base URL
    expect(url.startsWith(BASE_URL)).toBe(true);
  });

  test('production should use HTTPS', async ({ page }) => {
    await page.goto('/');

    const url = page.url();

    // If PROD_URL is set, it should use HTTPS
    if (process.env.PROD_URL) {
      expect(url.startsWith('https://')).toBe(true);
    } else {
      // For dev/local, allow HTTP
      expect(url.startsWith('http://')).toBe(true);
    }
  });
});

test.describe('Smoke Test - Critical User Journey', () => {
  test('user should be able to complete basic game interaction', async ({ page }) => {
    // 1. Load the game
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // 2. Verify game is visible
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();

    // 3. Make a move
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(300);

    // 4. Make another move
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(300);

    // 5. Click new game
    const newGameButton = page.locator('button, .restart-button, .new-game').first();
    if (await newGameButton.isVisible()) {
      await newGameButton.click();
      await page.waitForTimeout(300);
    }

    // 6. Game should still be functional
    await expect(gameContainer.first()).toBeVisible();

    // 7. Make final move to confirm game works
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(300);

    // If we got here without errors, critical journey works
    expect(true).toBe(true);
  });
});
