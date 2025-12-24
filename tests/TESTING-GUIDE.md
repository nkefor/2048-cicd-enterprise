# Comprehensive Testing Guide

## 📚 Table of Contents

1. [Overview](#overview)
2. [Testing Philosophy](#testing-philosophy)
3. [Test Pyramid](#test-pyramid)
4. [Writing Effective Tests](#writing-effective-tests)
5. [Test Utilities](#test-utilities)
6. [Chaos Engineering](#chaos-engineering)
7. [Performance Testing](#performance-testing)
8. [CI/CD Integration](#cicd-integration)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

This guide provides comprehensive instructions for writing, running, and maintaining tests in the 2048 CI/CD Enterprise platform. Whether you're adding new features or fixing bugs, proper testing ensures reliability and maintainability.

### Test Coverage Summary

| Category | Coverage | Tests | Automation |
|----------|----------|-------|------------|
| Unit Tests | Planned | TBD | ✅ GitHub Actions |
| Integration Tests | ~90% | 50+ | ✅ GitHub Actions |
| E2E Tests | ~85% | 35+ | ✅ GitHub Actions |
| Security Tests | 100% | 12+ | ✅ GitHub Actions |
| Performance Tests | 100% | 10+ | ✅ GitHub Actions |
| Chaos Tests | 100% | 8+ | ⚠️ Manual/Optional |

---

## Testing Philosophy

### Core Principles

1. **Shift Left** - Catch bugs early in development
2. **Fast Feedback** - Tests should run quickly
3. **Reliability** - Tests should be deterministic
4. **Isolation** - Tests should not depend on each other
5. **Maintainability** - Tests should be easy to understand and update

### Testing Goals

- ✅ Prevent regressions
- ✅ Validate new features
- ✅ Ensure security compliance
- ✅ Maintain performance standards
- ✅ Document expected behavior
- ✅ Enable confident refactoring

---

## Test Pyramid

```
                 /\
                /  \
               /    \
              / E2E  \      ← Fewer, Slower, Expensive
             /        \
            /──────────\
           /            \
          / Integration  \   ← Moderate Number
         /                \
        /──────────────────\
       /                    \
      /        Unit          \  ← Many, Fast, Cheap
     /________________________\
```

### Unit Tests

**Purpose**: Test individual functions and components in isolation

**Characteristics**:
- Fast execution (< 100ms per test)
- No external dependencies
- Test single responsibility
- High code coverage

**When to Write**:
- Business logic functions
- Utility functions
- Data transformations
- Input validation

**Example**:
```javascript
// tests/unit/helpers.test.js
describe('formatBytes', () => {
  test('should format bytes correctly', () => {
    expect(formatBytes(0)).toBe('0 Bytes');
    expect(formatBytes(1024)).toBe('1 KB');
    expect(formatBytes(1048576)).toBe('1 MB');
  });
});
```

### Integration Tests

**Purpose**: Test how components work together

**Characteristics**:
- Moderate execution time (< 5s per test)
- Test real interactions
- May use test doubles
- Validate workflows

**When to Write**:
- API endpoints
- Database operations
- Service integrations
- Container orchestration

**Example**:
```bash
# tests/integration/run-integration-tests.sh
# Comprehensive test suite combining multiple test types
bash tests/integration/run-integration-tests.sh
```

### E2E Tests

**Purpose**: Test complete user workflows

**Characteristics**:
- Slower execution (5-30s per test)
- Real browser/environment
- User perspective
- Critical path coverage

**When to Write**:
- User registration flows
- Checkout processes
- Core features
- Cross-browser scenarios

**Example**:
```javascript
// tests/e2e/game-functionality.test.js
test('should load and play game', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('.game-container')).toBeVisible();
  await page.keyboard.press('ArrowUp');
  // Verify game responds to input
});
```

---

## Writing Effective Tests

### Test Structure: AAA Pattern

```javascript
test('descriptive test name', async () => {
  // 1. ARRANGE - Set up test conditions
  const user = { name: 'Test User', age: 25 };
  const mockApi = jest.fn().mockResolvedValue(user);

  // 2. ACT - Perform the action
  const result = await getUserData(mockApi, '123');

  // 3. ASSERT - Verify the outcome
  expect(result).toEqual(user);
  expect(mockApi).toHaveBeenCalledWith('123');
});
```

### Naming Conventions

**Good Test Names**:
- ✅ `should return 404 when user not found`
- ✅ `should validate email format`
- ✅ `should handle concurrent requests`

**Bad Test Names**:
- ❌ `test1`
- ❌ `it works`
- ❌ `edge case`

### Test Data Management

Use **fixtures** for consistent test data:

```javascript
// tests/fixtures/test-data.js
const { securityHeaders, performanceBudgets } = require('./test-data');

test('should have required security headers', async ({ page }) => {
  const response = await page.goto('/');
  const headers = response.headers();

  securityHeaders.required.forEach(header => {
    expect(headers).toHaveProperty(header.toLowerCase());
  });
});
```

### Mocking and Stubbing

**When to Mock**:
- External API calls
- Database queries
- Time-dependent operations
- Random values

**Example**:
```javascript
// Mock external API
jest.mock('../services/api', () => ({
  fetchData: jest.fn().mockResolvedValue({ data: 'mocked' })
}));

test('should handle API response', async () => {
  const result = await myFunction();
  expect(result).toBe('mocked');
});
```

---

## Test Utilities

### Helper Functions

The test suite includes comprehensive utilities in `tests/utils/test-helpers.js`:

```javascript
const { waitFor, retry, sleep } = require('./utils/test-helpers');

// Wait for condition
await waitFor(() => element.isVisible(), 5000);

// Retry with exponential backoff
const result = await retry(async () => {
  return await flakeyOperation();
}, 3, 1000);

// Simple delay
await sleep(1000);
```

### Common Utilities

| Function | Purpose | Example |
|----------|---------|---------|
| `waitFor(condition, timeout)` | Wait for condition | `await waitFor(() => isReady(), 5000)` |
| `retry(fn, maxRetries, delay)` | Retry with backoff | `await retry(apiCall, 3, 1000)` |
| `randomString(length)` | Generate random string | `const id = randomString(10)` |
| `measureTime(fn)` | Measure execution time | `const { duration } = await measureTime(fn)` |
| `withTimeout(promise, ms)` | Add timeout to promise | `await withTimeout(slowOp(), 5000)` |

### CI/CD Helpers

Shell utilities for CI/CD scripts in `tests/utils/ci-helpers.sh`:

```bash
source tests/utils/ci-helpers.sh

# Logging
log_info "Starting tests..."
log_warn "This might take a while"
log_error "Test failed"

# Docker helpers
docker_build_with_retry ./2048 my-image 3
wait_for_container_health my-container 60

# HTTP helpers
wait_for_url "http://localhost:8080" 30
check_http_status "http://localhost:8080" 200

# Test results
init_test_results
record_test_result "My Test" "pass"
print_test_summary
```

---

## Chaos Engineering

### Purpose

Chaos tests verify system resilience under adverse conditions:
- Container failures
- Resource exhaustion
- Network issues
- High load

### Running Chaos Tests

```bash
# Run chaos tests (local environment only!)
npx playwright test tests/chaos/

# Individual chaos test
npx playwright test tests/chaos/container-resilience.test.js
```

### Chaos Test Examples

**Container Restart**:
```javascript
test('should recover from container restart', async ({ page }) => {
  // Start container
  await execAsync(`docker run -d -p 8081:80 --name test ${IMAGE}`);

  // Verify working
  await page.goto('http://localhost:8081');
  await expect(page.locator('body')).toBeVisible();

  // Restart container
  await execAsync(`docker restart test`);
  await sleep(3000);

  // Verify still works
  await page.goto('http://localhost:8081');
  await expect(page.locator('body')).toBeVisible();
});
```

**Resource Constraints**:
```javascript
test('should handle resource constraints', async ({ page }) => {
  // Start with limited resources
  await execAsync(`docker run -d -p 8082:80 \
    --memory=50m --cpus=0.5 \
    --name test-limits ${IMAGE}`);

  // Should still work
  await page.goto('http://localhost:8082');
  await expect(page.locator('body')).toBeVisible();
});
```

### Safety Guidelines

⚠️ **IMPORTANT**: Run chaos tests only in safe environments

- ✅ Local development
- ✅ Dedicated test environments
- ❌ Production
- ❌ Shared staging

---

## Performance Testing

### Load Testing with k6

**Smoke Test** (sanity check):
```bash
k6 run tests/load/k6-smoke-test.js
```

**Load Test** (normal traffic):
```bash
k6 run tests/load/k6-load-test.js --duration 5m --vus 50
```

**Stress Test** (breaking point):
```bash
k6 run tests/load/k6-load-test.js --duration 10m --vus 200
```

### Custom Load Tests

```javascript
// tests/load/custom-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { loadTestConfig } from '../fixtures/test-data.js';

export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up
    { duration: '5m', target: 100 },  // Stay at 100
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get(__ENV.BASE_URL || 'http://localhost:8080');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 300ms': (r) => r.timings.duration < 300,
  });

  sleep(1);
}
```

### Lighthouse Performance

```bash
# Run Lighthouse CI
npm run test:lighthouse

# Custom URL
BASE_URL=https://example.com npm run test:lighthouse
```

**Performance Budgets** (from `tests/fixtures/test-data.js`):
- First Contentful Paint: < 1.5s
- Largest Contentful Paint: < 2.5s
- Time to Interactive: < 3.5s
- Total Blocking Time: < 200ms
- Cumulative Layout Shift: < 0.1

---

## CI/CD Integration

### GitHub Actions Workflows

**Test Workflow** (`.github/workflows/test.yaml`):
- Triggered on: Pull requests to `main`
- Runs: Lint, security, Docker, E2E, load, accessibility tests
- Matrix: Chromium, Firefox, WebKit

**Deploy Workflow** (`.github/workflows/deploy.yaml`):
- Triggered on: Push to `main`
- Runs: Build, deploy, post-deployment smoke tests

### Running Tests in CI

**Parallel Execution**:
```yaml
strategy:
  matrix:
    browser: [chromium, firefox, webkit]

steps:
  - run: npx playwright test --project=${{ matrix.browser }}
```

**Artifact Upload**:
```yaml
- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: test-results/
    retention-days: 7
```

### Local CI Simulation

Run the full CI test suite locally:

```bash
# Full integration test suite
bash tests/integration/run-integration-tests.sh

# With parallelization
PARALLEL=true bash tests/integration/run-integration-tests.sh

# Against specific environment
ENV=staging BASE_URL=https://staging.example.com \
  bash tests/integration/run-integration-tests.sh
```

---

## Troubleshooting

### Common Issues

#### Tests Timing Out

**Problem**: Tests fail with timeout errors

**Solutions**:
```javascript
// Increase timeout for specific test
test('slow operation', async ({ page }) => {
  test.setTimeout(60000); // 60 seconds
  await page.goto('/');
});

// Or in playwright.config.js
timeout: 30 * 1000,
```

#### Flaky Tests

**Problem**: Tests pass sometimes, fail others

**Solutions**:
1. **Add explicit waits**:
```javascript
// Bad
await page.click('.button');
await expect(element).toBeVisible();

// Good
await page.click('.button');
await page.waitForLoadState('networkidle');
await expect(element).toBeVisible();
```

2. **Use auto-retry assertions**:
```javascript
// Playwright auto-retries expect() assertions
await expect(element).toBeVisible(); // Retries for ~5s
```

3. **Avoid fixed delays**:
```javascript
// Bad
await sleep(1000);

// Good
await waitFor(() => element.isVisible());
```

#### Container Issues

**Problem**: Docker tests fail locally

**Solutions**:
```bash
# Check if port is in use
lsof -i :8080

# Clean up containers
docker rm -f $(docker ps -aq)

# Rebuild image
docker build --no-cache -t 2048-test ./2048

# Check logs
docker logs <container-name>
```

#### Test Data Conflicts

**Problem**: Tests interfere with each other

**Solutions**:
1. **Use unique test data**:
```javascript
const testId = randomString(10);
const testUser = `user-${testId}@example.com`;
```

2. **Clean up after tests**:
```javascript
test.afterEach(async () => {
  await cleanup();
});
```

---

## Best Practices

### DO's ✅

1. **Write Descriptive Test Names**
   ```javascript
   // Good
   test('should return 404 when product not found', ...)

   // Bad
   test('product test', ...)
   ```

2. **Keep Tests Independent**
   ```javascript
   // Each test should be runnable alone
   test('test 1', () => { /* complete setup */ });
   test('test 2', () => { /* complete setup */ });
   ```

3. **Use Test Fixtures**
   ```javascript
   const { securityHeaders } = require('./fixtures/test-data');
   ```

4. **Test Edge Cases**
   ```javascript
   test('should handle empty input', ...);
   test('should handle very long input', ...);
   test('should handle special characters', ...);
   ```

5. **Clean Up Resources**
   ```javascript
   test.afterEach(async () => {
     await cleanup();
   });
   ```

### DON'Ts ❌

1. **Don't Use Sleep for Synchronization**
   ```javascript
   // Bad
   await sleep(1000);

   // Good
   await waitFor(() => isReady());
   ```

2. **Don't Test Implementation Details**
   ```javascript
   // Bad
   expect(component.state.counter).toBe(1);

   // Good
   expect(component.text()).toContain('Count: 1');
   ```

3. **Don't Share State Between Tests**
   ```javascript
   // Bad
   let sharedData;
   test('test 1', () => { sharedData = ... });
   test('test 2', () => { use sharedData });

   // Good
   test('test 1', () => { const data = ... });
   test('test 2', () => { const data = ... });
   ```

4. **Don't Skip Tests Without Reason**
   ```javascript
   // Bad
   test.skip('broken test', ...);

   // Good - with explanation
   test.skip('TODO: Fix after API update - Issue #123', ...);
   ```

5. **Don't Ignore Warnings**
   ```bash
   # Address deprecation warnings
   # Fix flaky test warnings
   # Update outdated dependencies
   ```

---

## Test Coverage Goals

| Metric | Target | Current |
|--------|--------|---------|
| Overall Coverage | 80% | TBD |
| Critical Paths | 100% | ~95% |
| Security Features | 100% | 100% |
| Error Handling | 80% | ~75% |
| Edge Cases | 70% | ~65% |

---

## Resources

### Documentation
- [Playwright Docs](https://playwright.dev/)
- [k6 Documentation](https://k6.io/docs/)
- [Jest Documentation](https://jestjs.io/)
- [Testing Library](https://testing-library.com/)

### Tools
- **Playwright**: E2E testing framework
- **k6**: Load testing tool
- **Lighthouse**: Performance auditing
- **Trivy**: Vulnerability scanning
- **Hadolint**: Dockerfile linting

### Internal Resources
- `tests/README.md` - Test suite overview
- `tests/utils/test-helpers.js` - Utility functions
- `tests/fixtures/test-data.js` - Test data
- `tests/utils/ci-helpers.sh` - CI/CD utilities

---

## Contributing

When adding tests:

1. ✅ Follow the test pyramid (more unit, fewer E2E)
2. ✅ Use descriptive names
3. ✅ Add to appropriate directory
4. ✅ Update documentation
5. ✅ Ensure CI passes
6. ✅ Request review

---

**Last Updated**: 2025-12-24
**Maintainer**: DevOps Team
