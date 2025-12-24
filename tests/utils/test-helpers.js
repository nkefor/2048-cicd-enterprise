/**
 * Test Helper Utilities
 *
 * Common utility functions for tests across the suite
 */

/**
 * Wait for a condition to be true
 * @param {Function} condition - Function that returns boolean
 * @param {number} timeout - Maximum time to wait in ms
 * @param {number} interval - Check interval in ms
 * @returns {Promise<void>}
 */
async function waitFor(condition, timeout = 5000, interval = 100) {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout) {
    if (await condition()) {
      return;
    }
    await sleep(interval);
  }

  throw new Error(`Condition not met within ${timeout}ms`);
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
 * Retry a function with exponential backoff
 * @param {Function} fn - Async function to retry
 * @param {number} maxRetries - Maximum number of retries
 * @param {number} baseDelay - Base delay in ms
 * @returns {Promise<any>}
 */
async function retry(fn, maxRetries = 3, baseDelay = 1000) {
  let lastError;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (attempt < maxRetries) {
        const delay = baseDelay * Math.pow(2, attempt);
        console.log(`Retry attempt ${attempt + 1}/${maxRetries} after ${delay}ms`);
        await sleep(delay);
      }
    }
  }

  throw new Error(`Failed after ${maxRetries} retries: ${lastError.message}`);
}

/**
 * Generate random string
 * @param {number} length - Length of string
 * @returns {string}
 */
function randomString(length = 10) {
  return Math.random().toString(36).substring(2, 2 + length);
}

/**
 * Generate random number in range
 * @param {number} min - Minimum value (inclusive)
 * @param {number} max - Maximum value (inclusive)
 * @returns {number}
 */
function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Format bytes to human readable string
 * @param {number} bytes - Bytes to format
 * @returns {string}
 */
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

/**
 * Check if URL is reachable
 * @param {string} url - URL to check
 * @param {number} timeout - Timeout in ms
 * @returns {Promise<boolean>}
 */
async function isUrlReachable(url, timeout = 5000) {
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
 * Parse environment variable with fallback
 * @param {string} name - Environment variable name
 * @param {any} defaultValue - Default value if not set
 * @returns {any}
 */
function getEnv(name, defaultValue) {
  const value = process.env[name];
  if (value === undefined || value === '') {
    return defaultValue;
  }

  // Try to parse as JSON for complex types
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

/**
 * Create a mock HTTP server response
 * @param {number} statusCode - HTTP status code
 * @param {object} body - Response body
 * @param {object} headers - Response headers
 * @returns {object}
 */
function mockResponse(statusCode = 200, body = {}, headers = {}) {
  return {
    status: statusCode,
    ok: statusCode >= 200 && statusCode < 300,
    headers: new Map(Object.entries({
      'content-type': 'application/json',
      ...headers
    })),
    json: async () => body,
    text: async () => JSON.stringify(body),
    body
  };
}

/**
 * Measure execution time of an async function
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
 * Create a timeout promise
 * @param {number} ms - Milliseconds to wait
 * @param {string} message - Error message
 * @returns {Promise<never>}
 */
function timeoutPromise(ms, message = 'Operation timed out') {
  return new Promise((_, reject) => {
    setTimeout(() => reject(new Error(message)), ms);
  });
}

/**
 * Race a promise against a timeout
 * @param {Promise} promise - Promise to race
 * @param {number} timeout - Timeout in ms
 * @returns {Promise<any>}
 */
async function withTimeout(promise, timeout) {
  return Promise.race([
    promise,
    timeoutPromise(timeout)
  ]);
}

/**
 * Deep clone an object
 * @param {any} obj - Object to clone
 * @returns {any}
 */
function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

/**
 * Assert that a value is defined
 * @param {any} value - Value to check
 * @param {string} message - Error message
 */
function assertDefined(value, message = 'Value is undefined') {
  if (value === undefined || value === null) {
    throw new Error(message);
  }
}

module.exports = {
  waitFor,
  sleep,
  retry,
  randomString,
  randomInt,
  formatBytes,
  isUrlReachable,
  getEnv,
  mockResponse,
  measureTime,
  timeoutPromise,
  withTimeout,
  deepClone,
  assertDefined
};
