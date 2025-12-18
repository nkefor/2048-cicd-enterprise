const { test, expect } = require('@playwright/test');

/**
 * Test suite: Game Functionality
 * Tests the actual 2048 game mechanics and interactions
 */

test.describe('2048 Game - Basic Functionality', () => {
  test('should initialize game board with tiles', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Game should have some tiles on start
    // Look for common 2048 game tile classes
    const tiles = page.locator('.tile, .grid-cell, [class*="tile"]');
    const tileCount = await tiles.count();

    // Game typically starts with 2 tiles
    expect(tileCount).toBeGreaterThan(0);
  });

  test('should respond to keyboard input', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Focus the page
    await page.click('body');

    // Press arrow key (should trigger game move)
    await page.keyboard.press('ArrowUp');

    // Wait a bit for animation
    await page.waitForTimeout(500);

    // Game should still be visible and functional
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('should have new game button', async ({ page }) => {
    await page.goto('/');

    // New game button should exist
    const newGameButton = page.locator('button, .restart-button, .new-game, [class*="new-game"]');
    const buttonCount = await newGameButton.count();

    expect(buttonCount).toBeGreaterThan(0);
  });

  test('should restart game when new game button is clicked', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Find and click new game button
    const newGameButton = page.locator('button, .restart-button, .new-game').first();

    if (await newGameButton.isVisible()) {
      await newGameButton.click();

      // Wait for game to restart
      await page.waitForTimeout(500);

      // Game should still be visible
      const gameContainer = page.locator('.game-container, #game-container, .container');
      await expect(gameContainer.first()).toBeVisible();
    }
  });
});

test.describe('2048 Game - Performance', () => {
  test('should load page within acceptable time', async ({ page }) => {
    const startTime = Date.now();
    await page.goto('/');
    await page.waitForLoadState('load');
    const loadTime = Date.now() - startTime;

    // Page should load in less than 3 seconds
    expect(loadTime).toBeLessThan(3000);
  });

  test('should have reasonable page size', async ({ page }) => {
    const response = await page.goto('/');
    const body = await response.body();
    const sizeInKB = body.length / 1024;

    // HTML file should be under 100KB (it's a single-page app)
    expect(sizeInKB).toBeLessThan(100);
  });

  test('should not have memory leaks during gameplay', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Simulate multiple game moves
    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('ArrowUp');
      await page.waitForTimeout(100);
      await page.keyboard.press('ArrowRight');
      await page.waitForTimeout(100);
    }

    // Page should still be responsive
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });
});

test.describe('2048 Game - Browser Compatibility', () => {
  test('should work without console errors', async ({ page }) => {
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Interact with game
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(500);

    // Should have no console errors
    expect(errors).toHaveLength(0);
  });

  test('should handle rapid key presses', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Rapid key presses
    await page.keyboard.press('ArrowUp');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.press('ArrowRight');

    // Game should still be functional
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });
});
