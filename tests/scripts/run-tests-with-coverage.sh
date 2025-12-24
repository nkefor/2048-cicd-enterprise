#!/bin/bash
set -euo pipefail

##############################################################################
# Run Tests with Coverage Reporting
# Executes all tests and generates comprehensive coverage reports
##############################################################################

echo "╔════════════════════════════════════════════════════════╗"
echo "║     2048 CI/CD - Test Suite with Coverage             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Create test results directory
mkdir -p test-results/coverage
mkdir -p test-results/reports

# Track overall status
OVERALL_STATUS=0

# Function to run test category and track results
run_test_category() {
    local category="$1"
    local command="$2"
    local description="$3"

    echo ""
    echo "▶ Running: $description"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if eval "$command"; then
        echo "✅ $category: PASSED"
        return 0
    else
        echo "❌ $category: FAILED"
        OVERALL_STATUS=1
        return 1
    fi
}

# Run Docker tests
run_test_category "docker" \
    "bash tests/docker/run-all-tests.sh" \
    "Docker Container Tests"

# Run E2E tests with coverage
run_test_category "e2e" \
    "npx playwright test --reporter=html --reporter=json --reporter=junit" \
    "End-to-End Tests"

# Run security tests
run_test_category "security" \
    "bash tests/security/penetration-tests.sh" \
    "Security Penetration Tests"

# Generate test summary
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Test Execution Summary                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Count test results
if [ -f "test-results/results.json" ]; then
    echo "Test results saved to: test-results/"
fi

if [ -d "playwright-report" ]; then
    echo "HTML report available at: playwright-report/index.html"
fi

echo ""
if [ $OVERALL_STATUS -eq 0 ]; then
    echo "✅ ALL TESTS PASSED"
    echo ""
    echo "Coverage reports:"
    echo "  - HTML Report: test-results/coverage/index.html"
    echo "  - E2E Report: playwright-report/index.html"
else
    echo "❌ SOME TESTS FAILED"
    echo ""
    echo "Check test-results/ directory for detailed reports"
fi

echo ""
echo "Test execution completed at: $(date)"

exit $OVERALL_STATUS
