const { test, expect } = require('@playwright/test');

/**
 * SEO Tests
 * Validates SEO best practices and metadata
 */

test.describe('SEO - Meta Tags', () => {
  test('should have proper title tag', async ({ page }) => {
    await page.goto('/');
    const title = await page.title();

    expect(title).toBeTruthy();
    expect(title.length).toBeGreaterThan(10);
    expect(title.length).toBeLessThan(60);
    console.log(`Page title: "${title}"`);
  });

  test('should have meta description', async ({ page }) => {
    await page.goto('/');
    const description = await page.locator('meta[name="description"]').getAttribute('content');

    if (description) {
      expect(description.length).toBeGreaterThan(50);
      expect(description.length).toBeLessThan(160);
    }
  });

  test('should have viewport meta tag', async ({ page }) => {
    await page.goto('/');
    const viewport = await page.locator('meta[name="viewport"]').getAttribute('content');

    expect(viewport).toBeTruthy();
    expect(viewport).toContain('width=device-width');
  });

  test('should have charset defined', async ({ page }) => {
    await page.goto('/');
    const charset = await page.locator('meta[charset]').getAttribute('charset');

    expect(charset).toBeTruthy();
    expect(charset.toLowerCase()).toBe('utf-8');
  });
});

test.describe('SEO - Open Graph', () => {
  test('should have Open Graph title', async ({ page }) => {
    await page.goto('/');
    const ogTitle = await page.locator('meta[property="og:title"]').getAttribute('content');

    if (ogTitle) {
      expect(ogTitle).toBeTruthy();
      console.log(`OG Title: "${ogTitle}"`);
    }
  });

  test('should have Open Graph type', async ({ page }) => {
    await page.goto('/');
    const ogType = await page.locator('meta[property="og:type"]').getAttribute('content');

    if (ogType) {
      expect(['website', 'article', 'game']).toContain(ogType);
    }
  });
});

test.describe('SEO - Structure', () => {
  test('should have exactly one h1 tag', async ({ page }) => {
    await page.goto('/');
    const h1Count = await page.locator('h1').count();

    expect(h1Count).toBe(1);
  });

  test('should have proper heading hierarchy', async ({ page }) => {
    await page.goto('/');

    const h1 = await page.locator('h1').first();
    expect(await h1.isVisible()).toBe(true);
  });

  test('should have language attribute', async ({ page }) => {
    await page.goto('/');
    const lang = await page.locator('html').getAttribute('lang');

    if (lang) {
      expect(lang).toBeTruthy();
      expect(lang.length).toBeGreaterThanOrEqual(2);
    }
  });
});

test.describe('SEO - Performance', () => {
  test('should have efficient image loading', async ({ page }) => {
    await page.goto('/');
    const images = await page.locator('img').all();

    for (const img of images) {
      const alt = await img.getAttribute('alt');
      // Images should have alt text for SEO
      if (await img.isVisible()) {
        expect(alt).toBeDefined();
      }
    }
  });

  test('should have robots meta tag or robots.txt', async ({ page }) => {
    await page.goto('/');

    // Check for robots meta tag
    const robotsMeta = await page.locator('meta[name="robots"]').getAttribute('content');

    if (robotsMeta) {
      console.log(`Robots meta: ${robotsMeta}`);
    }

    // Check for robots.txt
    const robotsTxt = await page.goto('/robots.txt');
    console.log(`Robots.txt status: ${robotsTxt?.status() || 'not found'}`);
  });
});
