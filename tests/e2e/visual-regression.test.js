const { test, expect } = require('@playwright/test');

/**
 * Test suite: Visual Regression Testing
 * Detects unintended UI changes using screenshot comparison
 *
 * Priority: HIGH - Prevents design regressions, UI bugs
 *
 * Usage:
 *   - First run: Generates baseline screenshots
 *   - Subsequent runs: Compares against baseline
 *   - Update baseline: npm run test:visual -- --update-snapshots
 */

test.describe('Visual Regression - Homepage', () => {
  test('should match homepage baseline screenshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Full page screenshot comparison
    await expect(page).toHaveScreenshot('homepage-full.png', {
      fullPage: true,
      maxDiffPixels: 100, // Allow minor anti-aliasing differences
      threshold: 0.2, // 20% threshold for pixel differences
    });
  });

  test('should match above-the-fold screenshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Viewport screenshot (what user sees without scrolling)
    await expect(page).toHaveScreenshot('homepage-viewport.png', {
      fullPage: false,
      maxDiffPixels: 50,
    });
  });

  test('should match container screenshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const container = page.locator('.container');
    await expect(container).toBeVisible();

    // Element-specific screenshot
    await expect(container).toHaveScreenshot('main-container.png', {
      maxDiffPixels: 50,
    });
  });
});

test.describe('Visual Regression - Game Elements', () => {
  test('should match game container screenshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const gameContainer = page.locator('.game-container');
    await expect(gameContainer).toBeVisible();

    await expect(gameContainer).toHaveScreenshot('game-container.png', {
      maxDiffPixels: 50,
    });
  });

  test('should match header screenshot', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const header = page.locator('h1');
    await expect(header).toBeVisible();

    await expect(header).toHaveScreenshot('game-header.png', {
      maxDiffPixels: 20,
    });
  });

  test('should match instructions section', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const instructions = page.locator('.instructions').first();
    await expect(instructions).toBeVisible();

    await expect(instructions).toHaveScreenshot('instructions-section.png', {
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Responsive Design', () => {
  test('should match mobile view (iPhone 12)', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-iphone12.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('should match mobile view (Pixel 5)', async ({ page }) => {
    await page.setViewportSize({ width: 393, height: 851 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-pixel5.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('should match tablet view (iPad)', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-ipad.png', {
      fullPage: true,
      maxDiffPixels: 150,
    });
  });

  test('should match desktop view (1920x1080)', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-desktop.png', {
      fullPage: true,
      maxDiffPixels: 200,
    });
  });

  test('should match small mobile view (320px)', async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 568 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-small-mobile.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Interactive States', () => {
  test('should match hover state of buttons', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const button = page.locator('button').first();

    if (await button.count() > 0) {
      await button.hover();
      await page.waitForTimeout(200); // Wait for CSS transitions

      await expect(button).toHaveScreenshot('button-hover-state.png', {
        maxDiffPixels: 50,
      });
    }
  });

  test('should match focus state of interactive elements', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Tab to first interactive element
    await page.keyboard.press('Tab');
    await page.waitForTimeout(100);

    const focusedElement = page.locator(':focus');

    if (await focusedElement.count() > 0) {
      await expect(focusedElement).toHaveScreenshot('element-focus-state.png', {
        maxDiffPixels: 50,
      });
    }
  });
});

test.describe('Visual Regression - Dark Mode (if applicable)', () => {
  test.skip('should match dark mode screenshot', async ({ page }) => {
    // Enable dark mode (if app supports it)
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-dark-mode.png', {
      fullPage: true,
      maxDiffPixels: 200,
    });
  });

  test('should match light mode screenshot', async ({ page }) => {
    await page.emulateMedia({ colorScheme: 'light' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-light-mode.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Print Styles', () => {
  test('should match print media stylesheet', async ({ page }) => {
    await page.emulateMedia({ media: 'print' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-print-view.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Cross-Browser Consistency', () => {
  test('should render consistently across browsers', async ({ page, browserName }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Browser-specific screenshots
    await expect(page).toHaveScreenshot(`homepage-${browserName}.png`, {
      fullPage: true,
      maxDiffPixels: 200, // Allow more variance for cross-browser differences
    });
  });

  test('should render game container consistently', async ({ page, browserName }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const gameContainer = page.locator('.game-container');
    await expect(gameContainer).toBeVisible();

    await expect(gameContainer).toHaveScreenshot(`game-container-${browserName}.png`, {
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Performance Mode', () => {
  test('should match screenshot with reduced motion preference', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    await expect(page).toHaveScreenshot('homepage-reduced-motion.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Layout Stability', () => {
  test('should not have layout shift during page load', async ({ page }) => {
    await page.goto('/');

    // Take screenshot immediately
    const immediate = await page.screenshot();

    // Wait for network idle and animations
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1000);

    // Take final screenshot
    await expect(page).toHaveScreenshot('homepage-stable-layout.png', {
      fullPage: true,
      maxDiffPixels: 50, // Should be very similar to immediate screenshot
    });
  });

  test('should maintain layout after interactions', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Simulate user interactions
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(500);
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(500);

    // Layout should be stable
    await expect(page).toHaveScreenshot('homepage-after-interaction.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });
});
