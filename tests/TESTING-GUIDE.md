# Comprehensive Testing Guide

## 📖 Overview

This guide covers **Phase 1 Test Suite Improvements** for the 2048 CI/CD Enterprise platform. These improvements focus on enhancing test execution, reporting, and developer experience.

---

## 🆕 Phase 1 Improvements

### What's New

✨ **Test Utilities & Helpers**
- Reusable test utilities (`tests/helpers/test-utils.js`)
- Centralized test fixtures (`tests/helpers/fixtures.js`)
- Common assertions and helper functions

✨ **Enhanced Test Execution**
- Quick test runner for rapid feedback (`npm run test:quick`)
- Coverage reporting with detailed metrics (`npm run test:with-coverage`)
- Test summary aggregation (`npm run test:summary`)

✨ **Quality Gates**
- Configurable quality thresholds (`tests/quality-gates.json`)
- Automated PR status checks
- Performance budgets enforcement

✨ **Developer Tools**
- Pre-commit hooks for automated testing
- Git hooks installer (`tests/scripts/install-hooks.sh`)
- Enhanced test scripts with better output

✨ **Better Reporting**
- HTML coverage reports
- JUnit XML for CI integration
- Comprehensive test summaries

---

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install Node.js dependencies
npm install

# Install Playwright browsers
npx playwright install

# Install git hooks (optional but recommended)
bash tests/scripts/install-hooks.sh
```

### 2. Run Tests

**Quick Tests (Fast - for development):**
```bash
npm run test:quick
```

**All Tests with Coverage:**
```bash
npm run test:with-coverage
```

**Specific Test Categories:**
```bash
npm run test:docker      # Docker container tests
npm run test:e2e         # End-to-end tests
npm run test:a11y        # Accessibility tests
npm run test:visual      # Visual regression tests
npm run test:security    # Security tests
npm run test:lighthouse  # Performance tests
```

**View Test Summary:**
```bash
npm run test:summary
```

---

## 🧰 Test Utilities

### Using Test Helpers

The new test utilities provide reusable functions for common testing tasks:

```javascript
const {
  waitForCondition,
  retry,
  assertSecurityHeaders,
  measureTime,
  extractPageMetrics
} = require('../helpers/test-utils');

// Example: Wait for condition with timeout
await waitForCondition(
  async () => await page.locator('.game-board').isVisible(),
  { timeout: 5000, message: 'Game board did not load' }
);

// Example: Retry with exponential backoff
const result = await retry(
  async () => await fetchData(),
  { maxAttempts: 3, initialDelay: 1000 }
);

// Example: Assert security headers
const response = await page.goto('/');
assertSecurityHeaders(response);

// Example: Measure execution time
const { result, duration } = await measureTime(async () => {
  await page.goto('/');
});
console.log(`Page loaded in ${duration}ms`);
```

### Using Test Fixtures

Import centralized test fixtures for consistent test configuration:

```javascript
const {
  SECURITY_HEADERS,
  PERFORMANCE_BUDGETS,
  VIEWPORTS,
  GAME_SELECTORS
} = require('../helpers/fixtures');

// Example: Test with mobile viewport
await page.setViewportSize(VIEWPORTS.mobile);

// Example: Use game selectors
const gameContainer = page.locator(GAME_SELECTORS.container);
await expect(gameContainer).toBeVisible();

// Example: Check performance budget
const loadTime = await measureLoadTime();
expect(loadTime).toBeLessThan(PERFORMANCE_BUDGETS.pageLoad);
```

---

## ⚙️ Quality Gates

### Configuration

Quality gates are defined in `tests/quality-gates.json`. These thresholds ensure code quality:

**Docker:**
- Max image size: 100MB
- Max layers: 20
- No CRITICAL/HIGH vulnerabilities

**Performance:**
- Page load: < 3000ms
- First Contentful Paint: < 1500ms
- Lighthouse Performance: ≥ 90

**Security:**
- Required security headers
- No secrets in repository
- Max 0 critical vulnerabilities

**Accessibility:**
- WCAG 2.1 Level AA compliance
- Max 0 critical violations
- Lighthouse Accessibility: ≥ 95

### Customizing Quality Gates

Edit `tests/quality-gates.json` to adjust thresholds:

```json
{
  "gates": {
    "performance": {
      "budgets": {
        "pageLoadMs": 3000,
        "maxResourceSizeBytes": 102400
      }
    }
  }
}
```

---

## 🔍 Pre-Commit Hooks

### Installation

Install git hooks to run tests automatically before commits:

```bash
bash tests/scripts/install-hooks.sh
```

### What Gets Checked

Pre-commit hooks run the following checks:

1. **Secrets Scanning** - No AWS credentials, private keys, or passwords
2. **Dockerfile Lint** - If Dockerfile changed
3. **Docker Build** - If application code changed
4. **Syntax Checks** - For JavaScript and shell scripts
5. **Commit Message Format** - Conventional Commits validation

### Bypassing Hooks

**Not recommended**, but you can bypass hooks with:

```bash
git commit --no-verify
```

---

## 📊 Test Reporting

### HTML Reports

After running tests, view HTML reports:

```bash
# View Playwright E2E report
npm run test:e2e:report

# Or open manually
open playwright-report/index.html
```

### Coverage Reports

Coverage reports are generated in `test-results/coverage/`:

```bash
# Run tests with coverage
npm run test:with-coverage

# View coverage report
open test-results/coverage/index.html
```

### CI/CD Reports

In GitHub Actions, reports are uploaded as artifacts:
- Playwright HTML reports (7 days retention)
- Test results JSON
- Lighthouse performance reports
- Visual regression screenshots

---

## 🧪 Writing New Tests

### Best Practices

**1. Use Test Helpers:**
```javascript
const { retry, assertSecurityHeaders } = require('../helpers/test-utils');
const { GAME_SELECTORS, VIEWPORTS } = require('../helpers/fixtures');
```

**2. Follow AAA Pattern:**
```javascript
test('should load game board', async ({ page }) => {
  // Arrange
  await page.goto('/');

  // Act
  await page.waitForLoadState('networkidle');

  // Assert
  const gameContainer = page.locator(GAME_SELECTORS.container);
  await expect(gameContainer).toBeVisible();
});
```

**3. Use Descriptive Names:**
```javascript
// ✅ Good
test('should display error message when network request fails', ...)

// ❌ Bad
test('error test', ...)
```

**4. Clean Up Resources:**
```javascript
test.afterEach(async () => {
  // Clean up test data
  await cleanupTestData();
});
```

### Adding New Test Categories

**Step 1:** Create test file in appropriate directory:
```
tests/
├── docker/        # Container tests
├── e2e/           # Browser tests
├── security/      # Security tests
├── performance/   # Performance tests
└── load/          # Load tests
```

**Step 2:** Add npm script in `package.json`:
```json
{
  "scripts": {
    "test:mycategory": "playwright test tests/mycategory/"
  }
}
```

**Step 3:** Update CI workflow (`.github/workflows/test.yaml`)

**Step 4:** Update test documentation

---

## 🔧 Troubleshooting

### Quick Test Fails

**Issue:** Docker build test fails
```bash
# Clean Docker cache
docker system prune -a

# Rebuild image
docker build -t 2048-test ./2048
```

**Issue:** Port already in use
```bash
# Kill process on port 8080
lsof -ti:8080 | xargs kill -9

# Or use different port
docker run -p 9090:80 ...
```

### E2E Tests Fail

**Issue:** Browser not found
```bash
# Reinstall browsers
npx playwright install --with-deps
```

**Issue:** Tests timeout
```javascript
// Increase timeout in test
test('my test', async ({ page }) => {
  test.setTimeout(60000); // 60 seconds
  // ...
});
```

### Pre-Commit Hook Issues

**Issue:** Hook always fails
```bash
# Run hook manually to see errors
bash tests/scripts/pre-commit-test.sh

# Check syntax
bash -n tests/scripts/pre-commit-test.sh
```

**Issue:** Want to disable hooks temporarily
```bash
# Bypass for single commit
git commit --no-verify

# Or uninstall hooks
rm .git/hooks/pre-commit
```

---

## 📈 Performance Optimization

### Parallel Test Execution

Tests run in parallel by default in CI. For local development:

```bash
# Run E2E tests in parallel
npx playwright test --workers=4

# Run on single worker for debugging
npx playwright test --workers=1
```

### Test Sharding

For large test suites, use sharding:

```bash
# Shard 1 of 3
npx playwright test --shard=1/3

# Shard 2 of 3
npx playwright test --shard=2/3

# Shard 3 of 3
npx playwright test --shard=3/3
```

### Selective Test Execution

Run only changed tests:

```bash
# Run specific test file
npx playwright test tests/e2e/game-load.test.js

# Run tests matching pattern
npx playwright test --grep "security headers"

# Skip slow tests
npx playwright test --grep-invert "@slow"
```

---

## 🎯 Test Coverage Goals

### Current Coverage (Phase 1)

| Category | Coverage | Tests | Target |
|----------|----------|-------|--------|
| Docker Tests | 100% | 12 | 100% |
| E2E Functionality | ~85% | 30+ | 90% |
| Security | 100% | 12+ | 100% |
| Accessibility | 100% | 25+ | 100% |
| Performance | 100% | 10+ | 100% |
| Visual Regression | 100% | 35+ | 100% |
| **Overall** | **~92%** | **150+** | **95%** |

### Phase 2 Goals (Future)

- [ ] Increase E2E coverage to 95%
- [ ] Add mutation testing
- [ ] Add chaos engineering tests
- [ ] Implement contract testing
- [ ] Add smoke tests for multiple environments
- [ ] Expand load test scenarios

---

## 🔐 Security Testing

### Automated Security Checks

All tests include security validations:

**1. Security Headers:**
```javascript
const { assertSecurityHeaders } = require('../helpers/test-utils');
const response = await page.goto('/');
assertSecurityHeaders(response);
```

**2. Vulnerability Scanning:**
```bash
# Trivy container scan
docker build -t test-image ./2048
trivy image test-image
```

**3. Secrets Scanning:**
```bash
# TruffleHog scan
trufflehog filesystem ./ --only-verified
```

**4. Penetration Testing:**
```bash
npm run test:security
```

---

## 📝 CI/CD Integration

### GitHub Actions Workflows

**Test Workflow** (`.github/workflows/test.yaml`)
- Runs on: Pull requests
- Jobs: Lint, Docker, E2E, Security, Accessibility, Performance
- Artifacts: Test reports, screenshots, coverage

**Deploy Workflow** (`.github/workflows/deploy.yaml`)
- Runs on: Push to main
- Includes: Build, deploy, post-deployment verification

### Status Checks

Required status checks for PR merges:
- ✅ Dockerfile lint
- ✅ Docker build test
- ✅ Security scan (Trivy)
- ✅ E2E tests (all browsers)
- ✅ Accessibility tests

Optional checks:
- Visual regression
- Load tests
- Performance tests

---

## 📚 Additional Resources

### Documentation
- [Main Test Suite README](./README.md)
- [Playwright Documentation](https://playwright.dev/)
- [k6 Load Testing](https://k6.io/docs/)
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)

### Scripts Reference

| Script | Description | Use Case |
|--------|-------------|----------|
| `npm run test:quick` | Fast critical tests | Local development |
| `npm run test:all` | Full test suite | Before committing |
| `npm run test:with-coverage` | Tests + coverage | Complete validation |
| `npm run test:summary` | View test results | Post-test analysis |
| `npm run precommit` | Pre-commit checks | Manual hook run |
| `npm run test:ci` | CI test suite | GitHub Actions |

### Test File Structure

```
tests/
├── helpers/                    # 🆕 Test utilities
│   ├── test-utils.js          # Reusable functions
│   └── fixtures.js            # Test data & config
├── scripts/                    # 🆕 Test execution scripts
│   ├── quick-test.sh          # Fast test runner
│   ├── run-tests-with-coverage.sh
│   ├── test-summary.sh        # Result aggregation
│   ├── pre-commit-test.sh     # Pre-commit checks
│   └── install-hooks.sh       # Git hooks installer
├── docker/                     # Container tests
├── e2e/                        # Browser tests
├── security/                   # Security tests
├── performance/                # Performance tests
├── load/                       # Load tests
├── smoke/                      # Smoke tests
├── quality-gates.json          # 🆕 Quality thresholds
└── TESTING-GUIDE.md           # 🆕 This guide
```

---

## 🎉 Summary

Phase 1 Test Suite Improvements deliver:

✅ **Better Developer Experience**
- Quick test runners for fast feedback
- Pre-commit hooks catch issues early
- Enhanced test utilities reduce boilerplate

✅ **Improved Code Quality**
- Quality gates enforce standards
- Comprehensive coverage reporting
- Automated security and performance checks

✅ **Enhanced Reporting**
- Detailed test summaries
- HTML and JSON reports
- CI/CD artifact uploads

✅ **Standardization**
- Centralized fixtures and configurations
- Reusable test helpers
- Consistent test patterns

---

**Last Updated:** 2025-12-24
**Version:** 1.0.0 (Phase 1)
**Next Phase:** Phase 2 - Advanced testing strategies (mutation, chaos, contracts)
