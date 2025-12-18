#!/bin/bash
set -euo pipefail

##############################################################################
# Docker Test Suite Runner
# Runs all Docker-related tests in sequence
##############################################################################

echo "╔════════════════════════════════════════════════════════╗"
echo "║        Docker Test Suite for 2048 CI/CD               ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Function to run a test
run_test() {
    local test_name="$1"
    local test_script="$2"

    echo ""
    echo "Running: $test_name"
    echo "----------------------------------------"

    if bash "$test_script"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo ""
        echo "✅ $test_name: PASSED"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$test_name")
        echo ""
        echo "❌ $test_name: FAILED"
    fi

    echo "----------------------------------------"
}

# Run all tests
run_test "Docker Build Test" "tests/docker/test-build.sh"
run_test "Health Check Test" "tests/docker/test-health.sh"
run_test "Security Headers Test" "tests/docker/test-security-headers.sh"

# Print summary
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                   Test Summary                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo "Passed: $TESTS_PASSED ✅"
echo "Failed: $TESTS_FAILED ❌"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo "Failed Tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    echo "❌ TEST SUITE FAILED"
    exit 1
else
    echo "✅ ALL TESTS PASSED"
    exit 0
fi
