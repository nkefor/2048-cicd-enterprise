const { test, expect } = require('@playwright/test');
const AxeBuilder = require('@axe-core/playwright').default;

/**
 * Test suite: Accessibility (a11y) Testing
 * Tests WCAG 2.1 Level AA compliance and keyboard navigation
 *
 * Priority: CRITICAL - Legal/compliance risk (ADA, Section 508)
 */

test.describe('Accessibility - WCAG Compliance', () => {
  test('should not have critical accessibility violations (WCAG 2.1 AA)', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
      .analyze();

    const violations = accessibilityScanResults.violations;

    if (violations.length > 0) {
      console.log('\n❌ Accessibility Violations Found:');
      violations.forEach(violation => {
        console.log(`\n  Rule: ${violation.id}`);
        console.log(`  Impact: ${violation.impact}`);
        console.log(`  Description: ${violation.description}`);
        console.log(`  Help: ${violation.helpUrl}`);
        console.log(`  Affected elements: ${violation.nodes.length}`);
      });
    }

    expect(violations).toEqual([]);
  });

  test('should pass best practices accessibility checks', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['best-practice'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have proper HTML structure', async ({ page }) => {
    await page.goto('/');

    // Check for valid lang attribute
    const htmlLang = await page.getAttribute('html', 'lang');
    expect(htmlLang).toBeTruthy();

    // Check for proper title
    const title = await page.title();
    expect(title.length).toBeGreaterThan(0);
    expect(title).not.toBe('');
  });

  test('should have proper meta tags for accessibility', async ({ page }) => {
    await page.goto('/');

    // Check viewport meta tag
    const viewport = await page.locator('meta[name="viewport"]').getAttribute('content');
    expect(viewport).toContain('width=device-width');

    // Check charset
    const charset = await page.locator('meta[charset]').count();
    expect(charset).toBeGreaterThan(0);
  });
});

test.describe('Accessibility - Keyboard Navigation', () => {
  test('should support full keyboard navigation', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Tab through all interactive elements
    await page.keyboard.press('Tab');

    // Verify something is focused
    const focusedElement = await page.evaluate(() => {
      return document.activeElement.tagName;
    });

    expect(focusedElement).toBeTruthy();
    expect(focusedElement).not.toBe('BODY');
  });

  test('should have visible focus indicators', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Tab to first interactive element
    await page.keyboard.press('Tab');

    // Check if focused element has visible outline or focus style
    const hasFocusStyle = await page.evaluate(() => {
      const el = document.activeElement;
      const styles = window.getComputedStyle(el);

      // Check for outline, box-shadow, or border that indicates focus
      return styles.outline !== 'none' ||
             styles.outlineWidth !== '0px' ||
             styles.boxShadow !== 'none' ||
             el.matches(':focus-visible');
    });

    expect(hasFocusStyle).toBeTruthy();
  });

  test('should allow keyboard interaction with game controls', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Arrow keys should be functional (game control)
    await page.keyboard.press('ArrowUp');
    await page.waitForTimeout(200);

    await page.keyboard.press('ArrowDown');
    await page.waitForTimeout(200);

    await page.keyboard.press('ArrowLeft');
    await page.waitForTimeout(200);

    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(200);

    // Page should still be functional
    const container = page.locator('.container');
    await expect(container).toBeVisible();
  });
});

test.describe('Accessibility - Screen Reader Support', () => {
  test('should have meaningful alt text for images', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Get all images
    const images = await page.locator('img').all();

    for (const img of images) {
      const alt = await img.getAttribute('alt');
      // Alt should exist (can be empty for decorative images)
      expect(alt).not.toBeNull();
    }
  });

  test('should have proper heading hierarchy', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Get all headings
    const h1Count = await page.locator('h1').count();

    // Should have exactly one h1
    expect(h1Count).toBe(1);

    // H1 should not be empty
    const h1Text = await page.locator('h1').first().textContent();
    expect(h1Text.trim().length).toBeGreaterThan(0);
  });

  test('should have descriptive button labels', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const buttons = await page.locator('button').all();

    for (const button of buttons) {
      // Check if button has text content or aria-label
      const text = await button.textContent();
      const ariaLabel = await button.getAttribute('aria-label');
      const ariaLabelledBy = await button.getAttribute('aria-labelledby');

      const hasLabel = (text && text.trim().length > 0) || ariaLabel || ariaLabelledBy;
      expect(hasLabel).toBeTruthy();
    }
  });

  test('should not have empty links', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const links = await page.locator('a').all();

    for (const link of links) {
      const text = await link.textContent();
      const ariaLabel = await link.getAttribute('aria-label');
      const ariaLabelledBy = await link.getAttribute('aria-labelledby');

      const hasContent = (text && text.trim().length > 0) || ariaLabel || ariaLabelledBy;

      if (!hasContent) {
        const href = await link.getAttribute('href');
        console.log(`Empty link found: ${href}`);
      }

      expect(hasContent).toBeTruthy();
    }
  });
});

test.describe('Accessibility - Color Contrast', () => {
  test('should have sufficient color contrast', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Run color contrast check
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2aa'])
      .include('body')
      .analyze();

    const colorContrastViolations = accessibilityScanResults.violations.filter(
      v => v.id === 'color-contrast'
    );

    if (colorContrastViolations.length > 0) {
      console.log('\n❌ Color Contrast Violations:');
      colorContrastViolations.forEach(violation => {
        violation.nodes.forEach(node => {
          console.log(`  Element: ${node.html}`);
          console.log(`  Issue: ${node.failureSummary}`);
        });
      });
    }

    expect(colorContrastViolations).toEqual([]);
  });
});

test.describe('Accessibility - Form Elements', () => {
  test('should have proper labels for form inputs', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const inputs = await page.locator('input, select, textarea').all();

    for (const input of inputs) {
      const id = await input.getAttribute('id');
      const ariaLabel = await input.getAttribute('aria-label');
      const ariaLabelledBy = await input.getAttribute('aria-labelledby');

      // Check if input has associated label
      let hasLabel = ariaLabel || ariaLabelledBy;

      if (id && !hasLabel) {
        const label = page.locator(`label[for="${id}"]`);
        hasLabel = await label.count() > 0;
      }

      if (!hasLabel) {
        const type = await input.getAttribute('type');
        console.log(`Input without label found: type=${type}, id=${id}`);
      }

      expect(hasLabel).toBeTruthy();
    }
  });
});

test.describe('Accessibility - Responsive Design', () => {
  test('should be accessible on mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should be accessible on tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });
});
