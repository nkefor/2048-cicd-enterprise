import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

/**
 * k6 Load Testing Script for 2048 Game
 *
 * This script tests the application under various load conditions
 * to ensure it can handle production traffic.
 *
 * Run with: k6 run tests/load/k6-load-test.js
 * Run with options: k6 run --vus 100 --duration 30s tests/load/k6-load-test.js
 */

// Custom metrics
const errorRate = new Rate('errors');
const pageLoadTime = new Trend('page_load_time');

// Test configuration
export const options = {
  // Stages define the load pattern
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 50 },    // Ramp up to 50 users
    { duration: '2m', target: 100 },   // Ramp up to 100 users
    { duration: '1m', target: 100 },   // Stay at 100 users
    { duration: '30s', target: 0 },    // Ramp down to 0 users
  ],

  // Thresholds define pass/fail criteria
  thresholds: {
    // HTTP errors should be less than 1%
    'http_req_failed': ['rate<0.01'],

    // 95% of requests should complete within 300ms
    'http_req_duration': ['p(95)<300'],

    // 99% of requests should complete within 500ms
    'http_req_duration': ['p(99)<500'],

    // Error rate should be less than 1%
    'errors': ['rate<0.01'],
  },

  // Test metadata
  tags: {
    test_type: 'load_test',
    application: '2048-game',
  },
};

// Base URL - override with environment variable
const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

/**
 * Main test function - runs for each virtual user
 */
export default function () {
  // Test 1: Load homepage
  const homeResponse = http.get(BASE_URL);

  // Record custom metric
  pageLoadTime.add(homeResponse.timings.duration);

  // Validate response
  const homeCheckResult = check(homeResponse, {
    'homepage status is 200': (r) => r.status === 200,
    'homepage has content': (r) => r.body.length > 0,
    'homepage contains 2048': (r) => r.body.includes('2048'),
    'response time < 300ms': (r) => r.timings.duration < 300,
  });

  // Record errors
  errorRate.add(!homeCheckResult);

  // Validate security headers
  check(homeResponse, {
    'has X-Frame-Options': (r) => r.headers['X-Frame-Options'] === 'DENY',
    'has X-Content-Type-Options': (r) => r.headers['X-Content-Type-Options'] === 'nosniff',
    'has X-XSS-Protection': (r) => r.headers['X-Xss-Protection'] === '1; mode=block',
    'has Referrer-Policy': (r) => r.headers['Referrer-Policy'] === 'no-referrer-when-downgrade',
  });

  // Simulate user think time
  sleep(1);

  // Test 2: Simulate multiple page loads (user refreshing)
  const refreshResponse = http.get(BASE_URL);

  check(refreshResponse, {
    'refresh status is 200': (r) => r.status === 200,
    'refresh response time < 200ms': (r) => r.timings.duration < 200,
  });

  // Simulate user interaction time
  sleep(2);
}

/**
 * Setup function - runs once before the test
 */
export function setup() {
  console.log(`Starting load test against ${BASE_URL}`);

  // Verify the application is reachable
  const healthCheck = http.get(BASE_URL);

  if (healthCheck.status !== 200) {
    throw new Error(`Application health check failed. Status: ${healthCheck.status}`);
  }

  console.log('Application is healthy. Starting load test...');

  return { startTime: new Date().toISOString() };
}

/**
 * Teardown function - runs once after the test
 */
export function teardown(data) {
  console.log(`Load test completed. Started at: ${data.startTime}`);
}

/**
 * Handle summary - customize the end-of-test summary
 */
export function handleSummary(data) {
  return {
    'test-results/k6-summary.json': JSON.stringify(data, null, 2),
    'stdout': textSummary(data, { indent: ' ', enableColors: true }),
  };
}

/**
 * Helper function to create text summary
 */
function textSummary(data, options) {
  const indent = options.indent || '';
  const colors = options.enableColors || false;

  let summary = '\n' + indent + '=== Load Test Summary ===\n\n';

  // Test duration
  const testDuration = data.state.testRunDurationMs / 1000;
  summary += indent + `Test Duration: ${testDuration.toFixed(2)}s\n`;

  // Request stats
  const httpReqs = data.metrics.http_reqs.values.count;
  const httpReqRate = data.metrics.http_reqs.values.rate;
  summary += indent + `Total Requests: ${httpReqs}\n`;
  summary += indent + `Request Rate: ${httpReqRate.toFixed(2)} req/s\n\n`;

  // Response times
  const p95 = data.metrics.http_req_duration.values['p(95)'];
  const p99 = data.metrics.http_req_duration.values['p(99)'];
  const avg = data.metrics.http_req_duration.values.avg;
  summary += indent + `Response Times:\n`;
  summary += indent + `  Average: ${avg.toFixed(2)}ms\n`;
  summary += indent + `  p95: ${p95.toFixed(2)}ms\n`;
  summary += indent + `  p99: ${p99.toFixed(2)}ms\n\n`;

  // Error rate
  const errorRate = data.metrics.http_req_failed.values.rate * 100;
  summary += indent + `Error Rate: ${errorRate.toFixed(2)}%\n`;

  return summary;
}
