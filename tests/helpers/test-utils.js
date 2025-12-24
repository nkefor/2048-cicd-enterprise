/**
 * Test Utilities and Helpers
 * Shared utilities for test suites
 */

/**
 * Wait for condition with timeout
 * @param {Function} condition - Function that returns boolean
 * @param {Object} options - Options {timeout, interval, message}
 * @returns {Promise<void>}
 */
async function waitForCondition(condition, options = {}) {
  const {
    timeout = 10000,
    interval = 100,
    message = 'Condition not met within timeout'
  } = options;

  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (await condition()) {
      return;
    }
    await sleep(interval);
  }

  throw new Error(message);
}

/**
 * Sleep for specified milliseconds
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Retry function with exponential backoff
 * @param {Function} fn - Function to retry
 * @param {Object} options - Retry options
 * @returns {Promise<any>}
 */
async function retry(fn, options = {}) {
  const {
    maxAttempts = 3,
    initialDelay = 1000,
    maxDelay = 10000,
    backoffMultiplier = 2,
    onRetry = null
  } = options;

  let lastError;
  let delay = initialDelay;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (attempt < maxAttempts) {
        if (onRetry) {
          onRetry(attempt, error);
        }

        await sleep(delay);
        delay = Math.min(delay * backoffMultiplier, maxDelay);
      }
    }
  }

  throw lastError;
}

/**
 * Assert response has expected security headers
 * @param {Response} response - HTTP response
 * @param {Object} expectedHeaders - Expected headers
 */
function assertSecurityHeaders(response, expectedHeaders = {}) {
  const headers = response.headers();
  const defaultExpectedHeaders = {
    'x-content-type-options': 'nosniff',
    'x-frame-options': 'DENY',
    'x-xss-protection': '1; mode=block',
    ...expectedHeaders
  };

  const missing = [];
  const incorrect = [];

  for (const [header, expectedValue] of Object.entries(defaultExpectedHeaders)) {
    const actualValue = headers[header.toLowerCase()];

    if (!actualValue) {
      missing.push(header);
    } else if (expectedValue && actualValue.toLowerCase() !== expectedValue.toLowerCase()) {
      incorrect.push({ header, expected: expectedValue, actual: actualValue });
    }
  }

  if (missing.length > 0 || incorrect.length > 0) {
    const errors = [];
    if (missing.length > 0) {
      errors.push(`Missing headers: ${missing.join(', ')}`);
    }
    if (incorrect.length > 0) {
      errors.push(`Incorrect headers: ${incorrect.map(h => `${h.header} (expected: ${h.expected}, got: ${h.actual})`).join(', ')}`);
    }
    throw new Error(`Security header validation failed:\n${errors.join('\n')}`);
  }
}

/**
 * Generate random test data
 * @param {string} type - Data type to generate
 * @returns {any}
 */
function generateTestData(type) {
  const generators = {
    email: () => `test${Date.now()}@example.com`,
    uuid: () => `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    timestamp: () => new Date().toISOString(),
    randomString: (length = 10) => Math.random().toString(36).substr(2, length),
    randomNumber: (min = 0, max = 100) => Math.floor(Math.random() * (max - min + 1)) + min
  };

  return generators[type] ? generators[type]() : null;
}

/**
 * Measure execution time of async function
 * @param {Function} fn - Async function to measure
 * @returns {Promise<{result: any, duration: number}>}
 */
async function measureTime(fn) {
  const startTime = Date.now();
  const result = await fn();
  const duration = Date.now() - startTime;
  return { result, duration };
}

/**
 * Check if URL is accessible
 * @param {string} url - URL to check
 * @param {number} timeout - Timeout in ms
 * @returns {Promise<boolean>}
 */
async function isUrlAccessible(url, timeout = 5000) {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), timeout);

    const response = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    return response.ok;
  } catch (error) {
    return false;
  }
}

/**
 * Extract metrics from page
 * @param {Page} page - Playwright page object
 * @returns {Promise<Object>}
 */
async function extractPageMetrics(page) {
  const metrics = await page.evaluate(() => {
    const perfData = window.performance.timing;
    const navigation = performance.getEntriesByType('navigation')[0];

    return {
      domContentLoaded: perfData.domContentLoadedEventEnd - perfData.navigationStart,
      loadComplete: perfData.loadEventEnd - perfData.navigationStart,
      firstPaint: navigation?.responseStart ? navigation.responseStart - navigation.startTime : null,
      domInteractive: perfData.domInteractive - perfData.navigationStart,
      resourceCount: performance.getEntriesByType('resource').length
    };
  });

  return metrics;
}

module.exports = {
  waitForCondition,
  sleep,
  retry,
  assertSecurityHeaders,
  generateTestData,
  measureTime,
  isUrlAccessible,
  extractPageMetrics
};
