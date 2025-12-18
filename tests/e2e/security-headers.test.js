const { test, expect } = require('@playwright/test');

/**
 * Test suite: Security Headers
 * Validates that all required security headers are present and correctly configured
 */

test.describe('Security Headers', () => {
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

    expect(headers['x-xss-protection']).toBe('1; mode=block');
  });

  test('should have Referrer-Policy header', async ({ page }) => {
    const response = await page.goto('/');
    const headers = response.headers();

    expect(headers['referrer-policy']).toBe('no-referrer-when-downgrade');
  });

  test('should return 200 status code', async ({ page }) => {
    const response = await page.goto('/');
    expect(response.status()).toBe(200);
  });

  test('should have correct Content-Type', async ({ page }) => {
    const response = await page.goto('/');
    const headers = response.headers();

    expect(headers['content-type']).toContain('text/html');
  });
});

test.describe('Security - XSS Protection', () => {
  test('should not execute inline scripts from URL parameters', async ({ page }) => {
    // Attempt XSS via URL parameter (should be blocked)
    const xssAttempt = '/?q=<script>alert("xss")</script>';

    const errors = [];
    page.on('dialog', dialog => {
      errors.push('Dialog appeared: ' + dialog.message());
      dialog.dismiss();
    });

    await page.goto(xssAttempt);

    // No alert should appear
    expect(errors).toHaveLength(0);
  });

  test('should not be embeddable in iframe (X-Frame-Options)', async ({ page }) => {
    // Create a page that tries to iframe our app
    await page.goto('/');

    const iframeTest = `
      <html>
        <body>
          <iframe src="${page.url()}" id="test-frame"></iframe>
        </body>
      </html>
    `;

    // The X-Frame-Options: DENY header should prevent framing
    // We verify the header is set (already checked above)
    const response = await page.goto('/');
    expect(response.headers()['x-frame-options']).toBe('DENY');
  });
});
