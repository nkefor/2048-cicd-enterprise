#!/bin/bash
set -euo pipefail

##############################################################################
# Quick Test Runner
# Fast test suite for local development - runs critical tests only
##############################################################################

echo "╔════════════════════════════════════════════════════════╗"
echo "║         Quick Test Runner (Critical Tests Only)       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Track results
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run test
run_quick_test() {
    local test_name="$1"
    local command="$2"

    echo "▶ $test_name"
    if eval "$command" > /dev/null 2>&1; then
        echo "  ✅ PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "  ❌ FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "Running critical tests..."
echo ""

# 1. Docker build test (fast)
run_quick_test "Docker Build" \
    "docker build -t 2048-quick-test ./2048 && docker rmi 2048-quick-test"

# 2. Container smoke test
run_quick_test "Container Smoke Test" \
    "docker build -t 2048-quick-test ./2048 && \
     docker run -d -p 8081:80 --name quick-test 2048-quick-test && \
     sleep 2 && \
     curl -f http://localhost:8081/ && \
     docker rm -f quick-test && \
     docker rmi 2048-quick-test"

# 3. Dockerfile lint
if command -v hadolint &> /dev/null; then
    run_quick_test "Dockerfile Lint" \
        "hadolint 2048/Dockerfile"
else
    echo "▶ Dockerfile Lint"
    echo "  ⚠️  SKIPPED (hadolint not installed)"
fi

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total: $((TESTS_PASSED + TESTS_FAILED))"
echo "  Passed: $TESTS_PASSED ✅"
echo "  Failed: $TESTS_FAILED ❌"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✅ Quick tests passed! Safe to commit."
    echo ""
    echo "To run full test suite:"
    echo "  npm run test:all"
    exit 0
else
    echo "❌ Quick tests failed! Fix issues before committing."
    echo ""
    echo "To see detailed output:"
    echo "  bash tests/docker/run-all-tests.sh"
    exit 1
fi
