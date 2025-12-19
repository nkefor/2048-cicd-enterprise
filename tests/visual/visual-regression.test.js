const { test, expect } = require('@playwright/test');

/**
 * Test suite: Visual Regression Testing
 * Detects unintended visual changes using screenshot comparisons
 */

test.describe('Visual Regression - Desktop', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('should match initial game state screenshot', async ({ page }) => {
    // Wait for game to fully render
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-initial-state.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('should match game board layout', async ({ page }) => {
    const gameBoard = page.locator('.game-container, #game-container, .container').first();
    await expect(gameBoard).toHaveScreenshot('game-board.png', {
      maxDiffPixels: 50,
    });
  });

  test('should match header/title area', async ({ page }) => {
    const header = page.locator('header, .heading, .title, h1').first();
    if (await header.isVisible()) {
      await expect(header).toHaveScreenshot('game-header.png');
    }
  });

  test('should match score display', async ({ page }) => {
    const scoreContainer = page.locator('.score-container, .scores, [class*="score"]').first();
    if (await scoreContainer.isVisible()) {
      await expect(scoreContainer).toHaveScreenshot('score-display.png', {
        // Scores change, so allow some difference
        maxDiffPixels: 200,
      });
    }
  });

  test('should match game controls/buttons', async ({ page }) => {
    const controls = page.locator('button, .button, .restart-button').first();
    if (await controls.isVisible()) {
      await expect(controls).toHaveScreenshot('game-controls.png');
    }
  });
});

test.describe('Visual Regression - Mobile Viewports', () => {
  test('should match mobile portrait layout (iPhone)', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-mobile-portrait.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('should match mobile landscape layout', async ({ page }) => {
    await page.setViewportSize({ width: 667, height: 375 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-mobile-landscape.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });

  test('should match tablet layout (iPad)', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-tablet.png', {
      fullPage: true,
      maxDiffPixels: 100,
    });
  });
});

test.describe('Visual Regression - Game States', () => {
  test('should match game state after moves', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Make some moves
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(300);
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(300);

    const gameBoard = page.locator('.game-container, #game-container, .container').first();
    await expect(gameBoard).toHaveScreenshot('game-after-moves.png', {
      maxDiffPixels: 500, // Allow more difference since tiles move
    });
  });

  test('should match new game button hover state', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const newGameButton = page.locator('button, .restart-button, .new-game').first();
    if (await newGameButton.isVisible()) {
      await newGameButton.hover();
      await page.waitForTimeout(100);

      await expect(newGameButton).toHaveScreenshot('button-hover-state.png');
    }
  });
});

test.describe('Visual Regression - Dark Mode (if supported)', () => {
  test('should handle dark mode preference', async ({ page }) => {
    // Emulate dark color scheme
    await page.emulateMedia({ colorScheme: 'dark' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-dark-mode.png', {
      fullPage: true,
      maxDiffPixels: 200,
    });
  });

  test('should handle light mode preference', async ({ page }) => {
    // Emulate light color scheme
    await page.emulateMedia({ colorScheme: 'light' });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-light-mode.png', {
      fullPage: true,
      maxDiffPixels: 200,
    });
  });
});

test.describe('Visual Regression - Responsive Breakpoints', () => {
  const viewports = [
    { name: 'small-mobile', width: 320, height: 568 },
    { name: 'medium-mobile', width: 375, height: 667 },
    { name: 'large-mobile', width: 414, height: 896 },
    { name: 'tablet', width: 768, height: 1024 },
    { name: 'desktop', width: 1280, height: 720 },
    { name: 'large-desktop', width: 1920, height: 1080 },
  ];

  for (const viewport of viewports) {
    test(`should match ${viewport.name} (${viewport.width}x${viewport.height})`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/');
      await page.waitForLoadState('networkidle');
      await page.waitForTimeout(500);

      await expect(page).toHaveScreenshot(`game-${viewport.name}.png`, {
        fullPage: true,
        maxDiffPixels: 100,
      });
    });
  }
});

test.describe('Visual Regression - Edge Cases', () => {
  test('should handle very narrow viewport', async ({ page }) => {
    await page.setViewportSize({ width: 280, height: 600 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-narrow-viewport.png', {
      fullPage: true,
    });
  });

  test('should handle very wide viewport', async ({ page }) => {
    await page.setViewportSize({ width: 2560, height: 1440 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(500);

    await expect(page).toHaveScreenshot('game-wide-viewport.png', {
      fullPage: true,
    });
  });
});
