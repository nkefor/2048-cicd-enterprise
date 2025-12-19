# Test Suite Documentation

Comprehensive test suite for the 2048 CI/CD Enterprise platform.

## 📋 Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests Locally](#running-tests-locally)
- [CI/CD Integration](#cicd-integration)
- [Test Types](#test-types)
- [Coverage Metrics](#coverage-metrics)
- [Troubleshooting](#troubleshooting)

---

## Overview

This test suite provides comprehensive coverage across multiple layers:

- **Docker Tests**: Container build, health, and security validation
- **E2E Tests**: Browser-based functional testing with Playwright
- **Load Tests**: Performance and stress testing with k6
- **Accessibility Tests**: WCAG 2.1 compliance and a11y validation
- **Visual Regression Tests**: Screenshot-based UI regression detection
- **Security Penetration Tests**: XSS, CSRF, and security vulnerability testing
- **Lighthouse Performance Tests**: Web Vitals and performance budgets
- **Smoke Tests**: Post-deployment critical functionality validation

### Test Philosophy

- **Shift Left**: Catch issues early in the development cycle
- **Fast Feedback**: Tests run in parallel for quick results
- **Comprehensive**: Cover functionality, security, and performance
- **Maintainable**: Clear structure and documentation

---

## Test Structure

```
tests/
├── docker/                     # Container validation tests
│   ├── test-build.sh          # Docker build validation
│   ├── test-health.sh         # Health check verification
│   ├── test-security-headers.sh # Security header validation
│   └── run-all-tests.sh       # Test suite runner
│
├── e2e/                        # End-to-end tests (Playwright)
│   ├── game-load.test.js      # Page load and initialization
│   ├── game-functionality.test.js # Game mechanics
│   └── security-headers.test.js   # Security validation
│
├── load/                       # Performance tests (k6)
│   ├── k6-load-test.js        # Full load test
│   └── k6-smoke-test.js       # Quick smoke test
│
├── accessibility/              # Accessibility tests (WCAG 2.1)
│   └── a11y.test.js           # Axe-core accessibility validation
│
├── visual/                     # Visual regression tests
│   └── visual-regression.test.js  # Screenshot comparison tests
│
├── security/                   # Security penetration tests
│   └── security-pentest.test.js   # XSS, CSRF, header validation
│
├── performance/                # Performance benchmarking
│   └── lighthouse-test.js     # Lighthouse & Core Web Vitals
│
└── smoke/                      # Post-deployment smoke tests
    └── smoke-test.test.js     # Critical functionality checks
```

---

## Running Tests Locally

### Prerequisites

**Required:**
- Docker (for container tests)
- Node.js 20+ (for E2E tests)
- Bash (for shell scripts)

**Optional:**
- k6 (for load tests)

### Quick Start

**1. Install Dependencies**
```bash
# Install Node.js dependencies
npm install

# Install Playwright browsers
npx playwright install
```

**2. Run All Tests**
```bash
# Run everything
npm run test:all

# Or run individually:
npm run test:docker    # Docker tests
npm run test:e2e       # E2E tests
npm run test:load      # Load tests
npm run test:a11y      # Accessibility tests
npm run test:visual    # Visual regression (update snapshots)
npm run test:visual:verify  # Visual regression (verify)
npm run test:security  # Security penetration tests
npm run test:lighthouse     # Lighthouse performance tests
npm run test:smoke     # Smoke tests
```

### Docker Tests

**Run all Docker tests:**
```bash
bash tests/docker/run-all-tests.sh
```

**Run individual Docker tests:**
```bash
# Build validation
bash tests/docker/test-build.sh

# Health check validation
bash tests/docker/test-health.sh

# Security headers validation
bash tests/docker/test-security-headers.sh
```

**Expected Output:**
```
╔════════════════════════════════════════════════════════╗
║        Docker Test Suite for 2048 CI/CD               ║
╚════════════════════════════════════════════════════════╝

Running: Docker Build Test
----------------------------------------
✅ Docker build successful
✅ Image size is acceptable (< 100MB)
✅ Image exists in local registry
✅ Layer count is reasonable (< 20)
----------------------------------------
✅ Docker Build Test: PASSED
```

### E2E Tests (Playwright)

**Run all E2E tests:**
```bash
npx playwright test
```

**Run specific test file:**
```bash
npx playwright test tests/e2e/game-load.test.js
```

**Run in headed mode (see browser):**
```bash
npm run test:e2e:headed
```

**Debug mode:**
```bash
npm run test:e2e:debug
```

**Run specific browser:**
```bash
npx playwright test --project=chromium
npx playwright test --project=firefox
npx playwright test --project=webkit
```

**View test report:**
```bash
npm run test:e2e:report
# Opens HTML report in browser
```

**Prerequisites:**
- Container must be running on http://localhost:8080
- Or update `BASE_URL` in playwright.config.js

**Start container for testing:**
```bash
docker build -t 2048-test ./2048
docker run -d -p 8080:80 --name test-container 2048-test
```

### Load Tests (k6)

**Install k6:**
```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**Run smoke test (quick):**
```bash
k6 run tests/load/k6-smoke-test.js
```

**Run full load test:**
```bash
k6 run tests/load/k6-load-test.js
```

**Custom load test:**
```bash
# 50 virtual users for 30 seconds
k6 run --vus 50 --duration 30s tests/load/k6-load-test.js

# Against production
k6 run -e BASE_URL=https://your-app.com tests/load/k6-load-test.js
```

**Expected Output:**
```
     ✓ homepage status is 200
     ✓ homepage has content
     ✓ homepage contains 2048
     ✓ response time < 300ms

     checks.........................: 100.00% ✓ 1200 ✗ 0
     http_req_duration..............: avg=85ms  p(95)=120ms p(99)=180ms
     http_reqs......................: 300     10/s
```

---

## CI/CD Integration

### GitHub Actions Workflows

**1. Test Suite Workflow (`test.yaml`)**
- **Trigger**: Pull requests to `main`
- **Jobs**:
  - Lint & Security checks
  - Docker container tests
  - E2E tests (all browsers)
  - Load tests
- **Purpose**: Validate changes before merge

**2. Deploy Workflow (`deploy.yaml`)**
- **Trigger**: Push to `main` branch
- **Jobs**:
  - Build & deploy to AWS
  - Post-deployment verification
  - Smoke tests on production
- **Purpose**: Deploy and validate production

### Workflow Triggers

**Test Workflow:**
```yaml
on:
  pull_request:
    branches: [ main ]
    paths:
      - '2048/**'
      - 'tests/**'
      - '.github/workflows/**'
```

**Deploy Workflow:**
```yaml
on:
  push:
    branches: [ main ]
    paths:
      - '2048/**'
      - '.github/workflows/deploy.yaml'
```

### Test Execution Order

**In Pull Requests:**
1. Lint Dockerfile (Hadolint)
2. Scan for vulnerabilities (Trivy)
3. Scan for secrets (TruffleHog)
4. Run Docker tests (parallel)
5. Run E2E tests (3 browsers in parallel)
6. Run load tests
7. Aggregate results

**In Deployments:**
1. Lint and validate
2. Build and test locally
3. Scan for vulnerabilities
4. Push to ECR
5. Deploy to ECS
6. Wait for stability
7. Run smoke tests
8. Verify security headers

---

## Test Types

### 1. Docker Container Tests

**Purpose**: Validate Docker image builds correctly and securely

**Tests:**
- ✅ Dockerfile builds without errors
- ✅ Image size is reasonable (< 100MB)
- ✅ Container starts successfully
- ✅ Health checks pass
- ✅ HTTP endpoint responds
- ✅ Security headers present
- ✅ No errors in logs

**Technology**: Bash scripts with Docker CLI

**Location**: `tests/docker/`

**Run Time**: ~30-60 seconds

### 2. End-to-End Tests

**Purpose**: Validate application functionality in real browsers

**Tests:**
- ✅ Page loads successfully
- ✅ Game UI elements visible
- ✅ Responsive design (mobile, tablet, desktop)
- ✅ No JavaScript errors
- ✅ Security headers correct
- ✅ Game mechanics work
- ✅ Performance acceptable

**Technology**: Playwright (Chromium, Firefox, WebKit)

**Location**: `tests/e2e/`

**Run Time**: ~2-5 minutes (parallel execution)

**Coverage:**
- 3 test suites
- 20+ individual tests
- 3 browsers
- 2 mobile viewports

### 3. Load/Performance Tests

**Purpose**: Validate application handles expected traffic

**Tests:**
- ✅ Handles 100 concurrent users
- ✅ Response time p95 < 300ms
- ✅ Response time p99 < 500ms
- ✅ Error rate < 1%
- ✅ No performance degradation

**Technology**: k6

**Location**: `tests/load/`

**Run Time**: ~5 minutes

**Load Pattern:**
- Ramp up: 20 → 50 → 100 users
- Sustain: 100 users for 1 minute
- Ramp down: 100 → 0 users

### 4. Accessibility Tests

**Purpose**: Validate WCAG 2.1 compliance and accessibility best practices

**Tests:**
- ✅ No automatically detectable a11y issues
- ✅ Proper heading hierarchy
- ✅ Sufficient color contrast
- ✅ Keyboard navigation support
- ✅ Screen reader compatibility
- ✅ ARIA attributes validity
- ✅ Image alt text presence
- ✅ Touch target sizes (mobile)

**Technology**: Playwright + axe-core

**Location**: `tests/accessibility/`

**Run Time**: ~1-2 minutes

**Run Command:**
```bash
npm run test:a11y
```

**WCAG Compliance:**
- WCAG 2.1 Level A
- WCAG 2.1 Level AA
- Keyboard-only navigation
- Screen reader support

### 5. Visual Regression Tests

**Purpose**: Detect unintended visual changes through screenshot comparison

**Tests:**
- ✅ Initial game state appearance
- ✅ Game board layout consistency
- ✅ Header/title area styling
- ✅ Button and control appearance
- ✅ Mobile responsive layouts
- ✅ Tablet viewport layouts
- ✅ Dark/light mode theming
- ✅ Multiple viewport sizes

**Technology**: Playwright screenshot comparison

**Location**: `tests/visual/`

**Run Time**: ~3-5 minutes

**Run Commands:**
```bash
# Update baseline screenshots
npm run test:visual

# Verify against baselines
npm run test:visual:verify
```

**Viewports Tested:**
- 320x568 (Small mobile)
- 375x667 (iPhone)
- 414x896 (Large mobile)
- 768x1024 (iPad)
- 1280x720 (Desktop)
- 1920x1080 (Large desktop)

**Snapshot Management:**
- Baselines stored in `tests/visual/*.png-snapshots/`
- Update baselines after intentional UI changes
- Failures show pixel-level diffs

### 6. Security Penetration Tests

**Purpose**: Identify security vulnerabilities and attack vectors

**Tests:**
- ✅ Security headers validation (CSP, X-Frame-Options, etc.)
- ✅ XSS protection mechanisms
- ✅ MIME sniffing prevention
- ✅ Clickjacking protection
- ✅ Information disclosure checks
- ✅ Cookie security attributes
- ✅ Resource loading security
- ✅ Client-side storage safety
- ✅ Input validation robustness
- ✅ Error handling security

**Technology**: Playwright with security test patterns

**Location**: `tests/security/`

**Run Time**: ~2-3 minutes

**Run Command:**
```bash
npm run test:security
```

**Security Checks:**
- **Headers**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Referrer-Policy
- **XSS**: Script injection, DOM manipulation, special character handling
- **Information Disclosure**: Sensitive data in HTML, localStorage, sessionStorage
- **Input Validation**: Long input, special characters, malicious payloads

### 7. Lighthouse Performance Tests

**Purpose**: Validate Core Web Vitals and performance budgets

**Tests:**
- ✅ Performance score ≥ 90
- ✅ Accessibility score ≥ 90
- ✅ Best Practices score ≥ 80
- ✅ SEO score ≥ 80
- ✅ First Contentful Paint < 1.8s
- ✅ Largest Contentful Paint < 2.5s
- ✅ Total Blocking Time < 300ms
- ✅ Cumulative Layout Shift < 0.1
- ✅ Speed Index < 3.0s
- ✅ Time to Interactive < 3.8s

**Technology**: Google Lighthouse

**Location**: `tests/performance/`

**Run Time**: ~1-2 minutes

**Run Commands:**
```bash
# Run against localhost
npm run test:lighthouse

# Run against specific URL
TEST_URL=https://your-app.com npm run test:lighthouse
```

**Performance Budgets:**
- **Performance**: 90/100
- **Accessibility**: 90/100
- **Best Practices**: 80/100
- **SEO**: 80/100

**Core Web Vitals:**
- **FCP**: ≤ 1800ms (First Contentful Paint)
- **LCP**: ≤ 2500ms (Largest Contentful Paint)
- **TBT**: ≤ 300ms (Total Blocking Time)
- **CLS**: ≤ 0.1 (Cumulative Layout Shift)

**Reports:**
- HTML reports saved to `lighthouse-reports/`
- JSON data for CI/CD integration
- Detailed optimization recommendations

### 8. Smoke Tests

**Purpose**: Quick validation of critical functionality post-deployment

**Tests:**
- ✅ Application loads successfully (200 OK)
- ✅ Page loads within 5 seconds
- ✅ No JavaScript errors on load
- ✅ Valid HTML structure
- ✅ Game board renders correctly
- ✅ Keyboard input responsive
- ✅ Security headers present
- ✅ No failed resource requests
- ✅ Mobile responsiveness
- ✅ Critical user journey works

**Technology**: Playwright

**Location**: `tests/smoke/`

**Run Time**: ~30-60 seconds

**Run Commands:**
```bash
# Run against localhost
npm run test:smoke

# Run against development
DEV_URL=https://dev.example.com npm run test:smoke

# Run against production
PROD_URL=https://prod.example.com npm run test:smoke
```

**Use Cases:**
- Post-deployment validation
- Production health checks
- Quick sanity testing
- CI/CD gate checks

**Environment Variables:**
- `DEV_URL`: Development environment URL
- `PROD_URL`: Production environment URL
- `SMOKE_URL`: Custom test URL

### 9. Security Tests (Legacy)

**Purpose**: Identify vulnerabilities and security issues

**Tests:**
- ✅ Dockerfile linting (Hadolint)
- ✅ Container vulnerability scanning (Trivy)
- ✅ Secrets scanning (TruffleHog)
- ✅ Security headers validation
- ✅ XSS protection

**Technology**: Multiple tools

**Location**: Integrated across test suite

**Run Time**: ~1-2 minutes

---

## Coverage Metrics

### Current Coverage

| Test Type | Coverage | Tests | Status |
|-----------|----------|-------|--------|
| Docker Tests | 100% | 12 | ✅ Passing |
| E2E Tests | ~80% | 20+ | ✅ Passing |
| Load Tests | 100% | 2 | ✅ Passing |
| Accessibility Tests | 100% | 11 | ✅ Passing |
| Visual Regression | 100% | 20+ | ✅ Passing |
| Security Penetration | 100% | 30+ | ✅ Passing |
| Lighthouse Performance | 100% | 10+ | ✅ Passing |
| Smoke Tests | 100% | 15+ | ✅ Passing |

### Quality Gates

Tests must pass these thresholds:

**E2E Tests:**
- ✅ 0 console errors
- ✅ All security headers present
- ✅ Page load < 3 seconds
- ✅ Response size < 100KB

**Load Tests:**
- ✅ HTTP error rate < 1%
- ✅ p95 response time < 300ms
- ✅ p99 response time < 500ms

**Security Tests:**
- ✅ 0 CRITICAL vulnerabilities
- ✅ 0 HIGH vulnerabilities
- ✅ No secrets in code
- ✅ Dockerfile best practices

---

## Troubleshooting

### Docker Tests Failing

**Issue**: "Container not responding"
```bash
# Check if port is already in use
lsof -i :8080

# Kill existing container
docker rm -f $(docker ps -aq)

# Try different port
docker run -p 9090:80 2048-test
```

**Issue**: "Image too large"
```bash
# Check image layers
docker history 2048-test

# Optimize Dockerfile (use multi-stage builds, clean cache)
```

### E2E Tests Failing

**Issue**: "Browser not found"
```bash
# Reinstall browsers
npx playwright install --with-deps
```

**Issue**: "Connection refused"
```bash
# Verify container is running
docker ps

# Check container logs
docker logs <container-name>

# Verify endpoint
curl http://localhost:8080
```

**Issue**: "Tests timing out"
```bash
# Increase timeout in playwright.config.js
timeout: 60 * 1000  // 60 seconds
```

### Load Tests Failing

**Issue**: "k6 not found"
```bash
# Install k6 (see installation section above)
```

**Issue**: "Too many failed requests"
```bash
# Check container resources
docker stats

# Reduce load
k6 run --vus 10 --duration 30s tests/load/k6-load-test.js
```

### CI/CD Issues

**Issue**: "Tests pass locally but fail in CI"
```bash
# Check GitHub Actions logs
# Common causes:
# - Different Node.js version
# - Missing dependencies
# - Port conflicts
# - Timing issues (add sleep/waits)
```

**Issue**: "Workflow not triggering"
```bash
# Verify trigger paths match changed files
# Check branch name matches workflow config
```

---

## Best Practices

### Writing Tests

1. **Descriptive names**: Use clear test descriptions
   ```javascript
   test('should display game board with tiles', async ({ page }) => {
   ```

2. **Arrange-Act-Assert**: Structure tests clearly
   ```javascript
   // Arrange: Set up test conditions
   await page.goto('/');

   // Act: Perform actions
   await page.click('.new-game');

   // Assert: Verify results
   await expect(gameContainer).toBeVisible();
   ```

3. **Avoid flaky tests**: Use proper waits
   ```javascript
   await page.waitForLoadState('networkidle');
   await expect(element).toBeVisible();  // Built-in retry
   ```

4. **Clean up**: Always clean up resources
   ```bash
   trap cleanup EXIT
   ```

### Maintaining Tests

1. **Keep tests independent**: Each test should run in isolation
2. **Update tests with code**: Keep tests in sync with features
3. **Review test reports**: Check failures in CI/CD
4. **Optimize slow tests**: Parallelize or optimize selectors

### Adding New Tests

1. **Choose the right test type**:
   - Functionality → E2E
   - Performance → Load
   - Container → Docker
   - Security → Multiple

2. **Follow existing patterns**: Use similar test structure

3. **Update documentation**: Add to this README

4. **Add to CI/CD**: Include in workflows

---

## Contributing

When adding tests:

1. ✅ Follow existing naming conventions
2. ✅ Add clear descriptions and comments
3. ✅ Include both positive and negative test cases
4. ✅ Update this README
5. ✅ Verify tests pass in CI/CD

---

## Running New Test Suites

### Accessibility Tests
```bash
# Run all accessibility tests
npm run test:a11y

# Run specific accessibility tests
npx playwright test tests/accessibility/a11y.test.js

# Run with headed browser
npx playwright test tests/accessibility/ --headed

# Generate accessibility report
npx playwright test tests/accessibility/ --reporter=html
npx playwright show-report
```

### Visual Regression Tests
```bash
# First time setup - generate baseline screenshots
npm run test:visual

# Verify UI against baseline (use this in CI/CD)
npm run test:visual:verify

# Update baselines after intentional UI changes
npm run test:visual -- --update-snapshots

# View visual diff reports
npx playwright show-report
```

### Security Penetration Tests
```bash
# Run all security tests
npm run test:security

# Run with detailed output
npx playwright test tests/security/ --reporter=list

# Run specific security test
npx playwright test tests/security/security-pentest.test.js -g "XSS"
```

### Lighthouse Performance Tests
```bash
# Run against local development
npm run test:lighthouse

# Run against staging
TEST_URL=https://staging.example.com npm run test:lighthouse

# Run against production
TEST_URL=https://prod.example.com npm run test:lighthouse

# View HTML reports
open lighthouse-reports/lighthouse-*.html
```

### Smoke Tests
```bash
# Run against localhost
npm run test:smoke

# Run against development environment
DEV_URL=https://dev.example.com npm run test:smoke

# Run against production environment
PROD_URL=https://prod.example.com npm run test:smoke

# Run with custom URL
SMOKE_URL=https://custom.example.com npm run test:smoke
```

---

## Resources

### Core Testing Tools
- [Playwright Documentation](https://playwright.dev/)
- [k6 Documentation](https://k6.io/docs/)
- [Hadolint Rules](https://github.com/hadolint/hadolint)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub Actions](https://docs.github.com/en/actions)

### Accessibility Testing
- [axe-core Documentation](https://github.com/dequelabs/axe-core)
- [axe-playwright](https://github.com/abhinaba-ghosh/axe-playwright)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [WebAIM Accessibility Resources](https://webaim.org/resources/)

### Performance Testing
- [Google Lighthouse](https://developer.chrome.com/docs/lighthouse/)
- [Core Web Vitals](https://web.dev/vitals/)
- [Chrome DevTools Performance](https://developer.chrome.com/docs/devtools/performance/)
- [Web Performance Working Group](https://www.w3.org/webperf/)

### Security Testing
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Security Headers](https://securityheaders.com/)
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)

### Visual Regression Testing
- [Playwright Screenshots](https://playwright.dev/docs/screenshots)
- [Visual Testing Guide](https://playwright.dev/docs/test-snapshots)

---

**Last Updated**: 2025-12-19
**Maintained by**: DevOps Team
