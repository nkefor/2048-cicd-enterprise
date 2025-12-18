import http from 'k6/http';
import { check, sleep } from 'k6';

/**
 * k6 Smoke Test for 2048 Game
 *
 * A minimal smoke test to verify basic functionality
 * This runs with minimal load (1-5 users) to catch obvious issues
 *
 * Run with: k6 run tests/load/k6-smoke-test.js
 */

export const options = {
  vus: 3,
  duration: '30s',

  thresholds: {
    'http_req_failed': ['rate<0.01'],
    'http_req_duration': ['p(95)<500'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const response = http.get(BASE_URL);

  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'has game content': (r) => r.body.includes('2048'),
    'has security headers': (r) =>
      r.headers['X-Frame-Options'] === 'DENY' &&
      r.headers['X-Content-Type-Options'] === 'nosniff',
  });

  sleep(1);
}
