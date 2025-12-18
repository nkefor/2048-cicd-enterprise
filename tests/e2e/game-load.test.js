const { test, expect } = require('@playwright/test');

/**
 * Test suite: Game Loading and Initialization
 * Verifies the 2048 game loads correctly and all UI elements are present
 */

test.describe('2048 Game - Page Load', () => {
  test('should load the game page successfully', async ({ page }) => {
    await page.goto('/');

    // Verify page loads
    await expect(page).toHaveTitle(/2048/);

    // Check for no JavaScript errors
    const errors = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    await page.waitForLoadState('networkidle');
    expect(errors).toHaveLength(0);
  });

  test('should display game container', async ({ page }) => {
    await page.goto('/');

    // Main game container should be visible
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('should display score elements', async ({ page }) => {
    await page.goto('/');

    // Score display should be present
    const scoreContainer = page.locator('.score-container, .score, #score');
    await expect(scoreContainer.first()).toBeVisible();
  });

  test('should have game title', async ({ page }) => {
    await page.goto('/');

    // Title should contain "2048"
    const heading = page.locator('h1, .title, .heading').first();
    await expect(heading).toContainText(/2048/i);
  });

  test('should not have accessibility violations', async ({ page }) => {
    await page.goto('/');

    // Check for basic accessibility
    // Page should have a lang attribute
    const html = page.locator('html');
    const lang = await html.getAttribute('lang');
    expect(lang).toBeTruthy();
  });
});

test.describe('2048 Game - Viewport Responsiveness', () => {
  test('should be responsive on mobile devices', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');

    // Game should still be visible
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('should be responsive on tablet devices', async ({ page }) => {
    // Set tablet viewport
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');

    // Game should still be visible
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('should be responsive on desktop', async ({ page }) => {
    // Set desktop viewport
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');

    // Game should still be visible
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });
});
