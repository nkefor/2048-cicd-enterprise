const { test, expect } = require('@playwright/test');
const AxeBuilder = require('axe-playwright').default;

/**
 * Test suite: Accessibility (A11y)
 * Tests WCAG 2.1 compliance and accessibility best practices
 */

test.describe('Accessibility Tests', () => {
  test('should not have automatically detectable accessibility issues', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have proper page title', async ({ page }) => {
    await page.goto('/');
    const title = await page.title();

    expect(title).toBeTruthy();
    expect(title.length).toBeGreaterThan(0);
  });

  test('should have proper HTML lang attribute', async ({ page }) => {
    await page.goto('/');
    const htmlLang = await page.locator('html').getAttribute('lang');

    expect(htmlLang).toBeTruthy();
  });

  test('should have sufficient color contrast', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['cat.color'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have keyboard accessible controls', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Test keyboard navigation
    await page.keyboard.press('Tab');

    // Check if any element is focused
    const focusedElement = await page.evaluate(() => {
      return document.activeElement.tagName;
    });

    expect(focusedElement).not.toBe('BODY');
  });

  test('should have proper heading hierarchy', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['cat.structure'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should not have images without alt text', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withRules(['image-alt'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have proper ARIA attributes', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['cat.aria'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should be navigable with keyboard only', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Test arrow key navigation (game controls)
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(200);
    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(200);
    await page.keyboard.press('ArrowLeft');
    await page.waitForTimeout(200);
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(200);

    // Game should still be functional
    const gameContainer = page.locator('.game-container, #game-container, .container');
    await expect(gameContainer.first()).toBeVisible();
  });

  test('should have visible focus indicators', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Tab to first focusable element
    await page.keyboard.press('Tab');
    await page.waitForTimeout(100);

    // Check if focused element has visible outline or focus style
    const hasFocusStyle = await page.evaluate(() => {
      const element = document.activeElement;
      const styles = window.getComputedStyle(element);
      const outline = styles.getPropertyValue('outline');
      const boxShadow = styles.getPropertyValue('box-shadow');
      const border = styles.getPropertyValue('border');

      return outline !== 'none' || boxShadow !== 'none' || border !== 'none';
    });

    expect(hasFocusStyle).toBeTruthy();
  });
});

test.describe('Accessibility - Screen Reader Support', () => {
  test('should have proper landmarks', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['cat.semantics'])
      .analyze();

    // Check for critical violations only
    const criticalViolations = accessibilityScanResults.violations.filter(
      v => v.impact === 'critical' || v.impact === 'serious'
    );

    expect(criticalViolations).toEqual([]);
  });

  test('should not have duplicate IDs', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withRules(['duplicate-id'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });
});

test.describe('Accessibility - Mobile & Responsive', () => {
  test('should be accessible on mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have proper touch target sizes', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Find all interactive elements
    const buttons = page.locator('button, a, input, [role="button"]');
    const count = await buttons.count();

    if (count > 0) {
      // Check first button has reasonable size (minimum 44x44 for touch)
      const box = await buttons.first().boundingBox();
      if (box) {
        expect(box.width).toBeGreaterThanOrEqual(40);
        expect(box.height).toBeGreaterThanOrEqual(40);
      }
    }
  });
});
