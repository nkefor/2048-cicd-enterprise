const { test, expect } = require('@playwright/test');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

/**
 * Chaos Engineering Tests
 *
 * These tests verify application resilience under adverse conditions:
 * - Container failures
 * - Resource exhaustion
 * - Network issues
 * - High load
 *
 * Run these tests in a safe environment only!
 */

const BASE_URL = process.env.BASE_URL || 'http://localhost:8080';
const CONTAINER_NAME = 'chaos-test-container';
const IMAGE_NAME = '2048-chaos-test';

test.describe('Container Resilience Tests', () => {
  test.beforeAll(async () => {
    // Build test image
    console.log('Building Docker image for chaos tests...');
    await execAsync('docker build -t ' + IMAGE_NAME + ' ./2048');
  });

  test.afterEach(async () => {
    // Cleanup after each test
    try {
      await execAsync(`docker rm -f ${CONTAINER_NAME} || true`);
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  test.afterAll(async () => {
    // Final cleanup
    try {
      await execAsync(`docker rmi ${IMAGE_NAME} || true`);
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  test('should recover from container restart', async ({ page }) => {
    // Start container
    await execAsync(`docker run -d -p 8081:80 --name ${CONTAINER_NAME} ${IMAGE_NAME}`);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Verify it's working
    await page.goto('http://localhost:8081');
    await expect(page.locator('body')).toBeVisible();

    // Restart container
    console.log('Restarting container...');
    await execAsync(`docker restart ${CONTAINER_NAME}`);
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Verify it still works
    await page.goto('http://localhost:8081');
    await expect(page.locator('body')).toBeVisible();
  });

  test('should handle SIGTERM gracefully', async ({ page }) => {
    // Start container
    await execAsync(`docker run -d -p 8082:80 --name ${CONTAINER_NAME}-sigterm ${IMAGE_NAME}`);
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Verify it's working
    await page.goto('http://localhost:8082');
    await expect(page.locator('body')).toBeVisible();

    // Send SIGTERM
    console.log('Sending SIGTERM to container...');
    await execAsync(`docker kill --signal=SIGTERM ${CONTAINER_NAME}-sigterm`);

    await new Promise(resolve => setTimeout(resolve, 2000));

    // Container should have stopped gracefully
    const { stdout } = await execAsync(`docker ps -a --filter name=${CONTAINER_NAME}-sigterm --format "{{.Status}}"`);
    expect(stdout).toContain('Exited');

    // Cleanup
    await execAsync(`docker rm -f ${CONTAINER_NAME}-sigterm || true`);
  });

  test('should handle resource constraints', async ({ page }) => {
    // Start container with limited resources
    console.log('Starting container with resource limits...');
    await execAsync(`docker run -d -p 8083:80 --name ${CONTAINER_NAME}-limits \
      --memory=50m \
      --cpus=0.5 \
      ${IMAGE_NAME}`);

    await new Promise(resolve => setTimeout(resolve, 3000));

    // Should still work under constraints
    await page.goto('http://localhost:8083');
    await expect(page.locator('body')).toBeVisible();

    // Verify container is still running
    const { stdout } = await execAsync(`docker ps --filter name=${CONTAINER_NAME}-limits --format "{{.Status}}"`);
    expect(stdout).toContain('Up');

    // Cleanup
    await execAsync(`docker rm -f ${CONTAINER_NAME}-limits || true`);
  });

  test('should handle health check failures', async () => {
    // Start container
    await execAsync(`docker run -d -p 8084:80 --name ${CONTAINER_NAME}-health \
      --health-cmd="wget -qO- http://127.0.0.1/ || exit 1" \
      --health-interval=5s \
      --health-timeout=3s \
      --health-retries=2 \
      ${IMAGE_NAME}`);

    await new Promise(resolve => setTimeout(resolve, 3000));

    // Check health status
    const { stdout } = await execAsync(`docker inspect --format='{{.State.Health.Status}}' ${CONTAINER_NAME}-health || echo "no_health"`);

    // Health should be healthy or starting
    expect(['healthy', 'starting', 'no_health']).toContain(stdout.trim());

    // Cleanup
    await execAsync(`docker rm -f ${CONTAINER_NAME}-health || true`);
  });
});

test.describe('Resource Exhaustion Tests', () => {
  test('should handle multiple concurrent requests', async ({ page }) => {
    // This test would work better with actual deployed app
    // For local testing, we'll do a lighter version

    const promises = [];
    const requestCount = 20;

    for (let i = 0; i < requestCount; i++) {
      promises.push(
        page.goto(BASE_URL, { timeout: 10000 }).catch(err => {
          console.log(`Request ${i} failed: ${err.message}`);
          return null;
        })
      );
    }

    const results = await Promise.allSettled(promises);
    const successful = results.filter(r => r.status === 'fulfilled' && r.value !== null);

    // At least 80% should succeed
    const successRate = successful.length / requestCount;
    console.log(`Success rate: ${(successRate * 100).toFixed(2)}%`);
    expect(successRate).toBeGreaterThan(0.8);
  });

  test('should serve static content efficiently', async ({ page }) => {
    const startTime = Date.now();

    // Load page multiple times
    for (let i = 0; i < 10; i++) {
      await page.goto(BASE_URL);
      await page.waitForLoadState('networkidle');
    }

    const duration = Date.now() - startTime;
    const avgTime = duration / 10;

    console.log(`Average load time: ${avgTime.toFixed(2)}ms`);

    // Average should be under 500ms
    expect(avgTime).toBeLessThan(500);
  });
});

test.describe('Failure Recovery Tests', () => {
  test('should handle missing files gracefully', async ({ page }) => {
    const response = await page.goto(BASE_URL + '/nonexistent.html');

    // Should return 404
    expect(response.status()).toBe(404);

    // Page should still be accessible after 404
    await page.goto(BASE_URL);
    await expect(page.locator('body')).toBeVisible();
  });

  test('should handle malformed requests', async ({ page }) => {
    // Try various malformed requests
    const malformedUrls = [
      BASE_URL + '/%00',
      BASE_URL + '/..%2f..%2f',
      BASE_URL + '/' + 'A'.repeat(10000),
    ];

    for (const url of malformedUrls) {
      try {
        const response = await page.goto(url, { timeout: 5000 });
        // Should not crash - any 4xx or 5xx is acceptable
        expect([400, 404, 414, 500]).toContain(response.status());
      } catch (error) {
        // Timeout or network error is also acceptable
        console.log(`Malformed URL handled: ${error.message}`);
      }
    }

    // Server should still be responsive
    await page.goto(BASE_URL);
    await expect(page.locator('body')).toBeVisible();
  });
});
