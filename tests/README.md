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
- **Security Tests**: Vulnerability scanning and header validation

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
├── integration/                # Integration tests (future)
│   └── (placeholder)
│
└── security/                   # Security-specific tests (future)
    └── (placeholder)
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

### 4. Security Tests

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
| Security Tests | 100% | 4 | ✅ Passing |

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

## Resources

- [Playwright Documentation](https://playwright.dev/)
- [k6 Documentation](https://k6.io/docs/)
- [Hadolint Rules](https://github.com/hadolint/hadolint)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

**Last Updated**: 2025-12-18
**Maintained by**: DevOps Team
