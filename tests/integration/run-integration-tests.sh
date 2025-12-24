#!/bin/bash
set -euo pipefail

##############################################################################
# Integration Test Runner
#
# Runs comprehensive integration tests including:
# - Docker container tests
# - E2E tests
# - Security tests
# - Performance tests
#
# Usage:
#   bash tests/integration/run-integration-tests.sh
#   ENV=staging bash tests/integration/run-integration-tests.sh
##############################################################################

echo "╔════════════════════════════════════════════════════════╗"
echo "║        Integration Test Suite Runner                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Configuration
ENV=${ENV:-local}
BASE_URL=${BASE_URL:-http://localhost:8080}
CONTAINER_NAME="integration-test-container"
IMAGE_NAME="2048-integration-test"
PARALLEL=${PARALLEL:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=()

# Change to project root
cd "$(dirname "$0")/../.."

##############################################################################
# Helper Functions
##############################################################################

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

run_test_suite() {
  local suite_name="$1"
  local command="$2"

  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "Running: $suite_name"
  echo "════════════════════════════════════════════════════════"
  echo ""

  if eval "$command"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    log_info "$suite_name: PASSED ✅"
  else
    FAILED_SUITES+=("$suite_name")
    log_error "$suite_name: FAILED ❌"
  fi
}

cleanup() {
  log_info "Cleaning up test resources..."

  # Stop and remove test container
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
  docker rmi "$IMAGE_NAME" 2>/dev/null || true

  # Clean up any orphaned containers
  docker ps -a --filter "name=test-container" -q | xargs -r docker rm -f 2>/dev/null || true
}

trap cleanup EXIT

##############################################################################
# Prerequisites Check
##############################################################################

log_info "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
  log_error "Docker is not installed"
  exit 1
fi

# Check Node.js
if ! command -v node &> /dev/null; then
  log_error "Node.js is not installed"
  exit 1
fi

# Check npm dependencies
if [ ! -d "node_modules" ]; then
  log_warn "Node modules not found, installing..."
  npm ci
fi

log_info "Prerequisites check passed"

##############################################################################
# Build Docker Image
##############################################################################

log_info "Building Docker image for integration tests..."

if docker build -t "$IMAGE_NAME" ./2048; then
  log_info "Docker build successful"
else
  log_error "Docker build failed"
  exit 1
fi

##############################################################################
# Start Test Container
##############################################################################

if [ "$ENV" = "local" ]; then
  log_info "Starting test container..."

  # Clean up any existing container
  docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

  # Start fresh container
  if docker run -d -p 8080:80 --name "$CONTAINER_NAME" "$IMAGE_NAME"; then
    log_info "Container started successfully"
  else
    log_error "Failed to start container"
    exit 1
  fi

  # Wait for container to be ready
  log_info "Waiting for container to be ready..."
  sleep 3

  # Verify container is running
  if ! docker ps | grep -q "$CONTAINER_NAME"; then
    log_error "Container is not running"
    docker logs "$CONTAINER_NAME"
    exit 1
  fi

  # Health check
  log_info "Performing health check..."
  MAX_RETRIES=10
  RETRY_COUNT=0

  while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -sf "$BASE_URL" > /dev/null 2>&1; then
      log_info "Health check passed"
      break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_warn "Health check attempt $RETRY_COUNT/$MAX_RETRIES failed, retrying..."
    sleep 2
  done

  if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_error "Health check failed after $MAX_RETRIES attempts"
    docker logs "$CONTAINER_NAME"
    exit 1
  fi
else
  log_info "Using remote environment: $ENV ($BASE_URL)"
fi

##############################################################################
# Run Test Suites
##############################################################################

log_info "Starting test execution..."
echo ""

# 1. Docker Tests
run_test_suite "Docker Container Tests" "bash tests/docker/run-all-tests.sh"

# 2. Security Tests
run_test_suite "Security Penetration Tests" "bash tests/security/penetration-tests.sh"

# 3. E2E Tests (Playwright)
if [ "$PARALLEL" = "true" ]; then
  run_test_suite "E2E Tests (Parallel)" "npx playwright test --workers=3"
else
  run_test_suite "E2E Tests" "npx playwright test"
fi

# 4. Accessibility Tests
run_test_suite "Accessibility Tests" "npx playwright test tests/e2e/accessibility.test.js"

# 5. Visual Regression Tests
run_test_suite "Visual Regression Tests" "npx playwright test tests/e2e/visual-regression.test.js"

# 6. Network Condition Tests
run_test_suite "Network Condition Tests" "npx playwright test tests/e2e/network-conditions.test.js"

# 7. Smoke Tests
run_test_suite "Smoke Tests" "npx playwright test tests/smoke/"

# 8. Chaos Tests (if local)
if [ "$ENV" = "local" ]; then
  run_test_suite "Chaos/Resilience Tests" "npx playwright test tests/chaos/"
fi

# 9. Load Tests (if k6 is available)
if command -v k6 &> /dev/null; then
  run_test_suite "Load Tests (k6 Smoke)" "k6 run tests/load/k6-smoke-test.js"
else
  log_warn "k6 not found, skipping load tests"
fi

# 10. Performance Tests (Lighthouse)
if [ "$ENV" = "local" ]; then
  run_test_suite "Performance Tests (Lighthouse)" "node tests/performance/lighthouse-ci.js"
fi

##############################################################################
# Test Summary
##############################################################################

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Integration Test Summary                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Environment: $ENV"
echo "Base URL: $BASE_URL"
echo ""
echo "Total Suites: $TOTAL_SUITES"
echo "Passed: $PASSED_SUITES ✅"
echo "Failed: ${#FAILED_SUITES[@]} ❌"
echo ""

if [ ${#FAILED_SUITES[@]} -gt 0 ]; then
  echo "Failed Suites:"
  for suite in "${FAILED_SUITES[@]}"; do
    echo "  ❌ $suite"
  done
  echo ""
  log_error "INTEGRATION TESTS FAILED"
  exit 1
else
  log_info "ALL INTEGRATION TESTS PASSED ✅"
  exit 0
fi
