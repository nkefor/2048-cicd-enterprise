#!/bin/bash
set -euo pipefail

##############################################################################
# Generate Test Summary
# Creates a comprehensive summary of all test results
##############################################################################

echo "╔════════════════════════════════════════════════════════╗"
echo "║              Test Results Summary                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Check if results exist
if [ ! -d "test-results" ]; then
    echo "⚠️  No test results found. Run tests first."
    exit 1
fi

# Function to print section header
print_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Docker test results
print_section "Docker Tests"
if [ -f "test-results/docker-summary.txt" ]; then
    cat test-results/docker-summary.txt
else
    echo "  No Docker test results available"
fi

# E2E test results
print_section "End-to-End Tests"
if [ -f "test-results/e2e-summary.json" ]; then
    if command -v jq &> /dev/null; then
        echo "  Total: $(jq '.total' test-results/e2e-summary.json)"
        echo "  Passed: $(jq '.passed' test-results/e2e-summary.json)"
        echo "  Failed: $(jq '.failed' test-results/e2e-summary.json)"
        echo "  Skipped: $(jq '.skipped' test-results/e2e-summary.json)"
    else
        cat test-results/e2e-summary.json
    fi
else
    echo "  No E2E test results available"
fi

# Security test results
print_section "Security Tests"
if [ -f "test-results/security-summary.txt" ]; then
    cat test-results/security-summary.txt
else
    echo "  No security test results available"
fi

# Performance test results
print_section "Performance Tests"
if [ -f "test-results/lighthouse/lighthouse-summary.json" ]; then
    if command -v jq &> /dev/null; then
        echo "  Performance Score: $(jq '.performance' test-results/lighthouse/lighthouse-summary.json)"
        echo "  Accessibility Score: $(jq '.accessibility' test-results/lighthouse/lighthouse-summary.json)"
        echo "  Best Practices Score: $(jq '.bestPractices' test-results/lighthouse/lighthouse-summary.json)"
        echo "  SEO Score: $(jq '.seo' test-results/lighthouse/lighthouse-summary.json)"
    else
        cat test-results/lighthouse/lighthouse-summary.json
    fi
else
    echo "  No performance test results available"
fi

# Overall summary
print_section "Overall Status"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Count tests from various sources
if [ -f "test-results/e2e-summary.json" ] && command -v jq &> /dev/null; then
    E2E_TOTAL=$(jq '.total' test-results/e2e-summary.json)
    E2E_PASSED=$(jq '.passed' test-results/e2e-summary.json)
    TOTAL_TESTS=$((TOTAL_TESTS + E2E_TOTAL))
    PASSED_TESTS=$((PASSED_TESTS + E2E_PASSED))
fi

echo "  Total Tests Run: $TOTAL_TESTS"
echo "  Passed: $PASSED_TESTS ✅"
echo "  Failed: $FAILED_TESTS ❌"
echo ""

if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL_TESTS -gt 0 ]; then
    echo "  🎉 All tests passed!"
elif [ $TOTAL_TESTS -eq 0 ]; then
    echo "  ⚠️  No test results found"
else
    echo "  ⚠️  Some tests failed - review results above"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Generated at: $(date)"
echo "Reports available:"
echo "  - HTML Report: playwright-report/index.html"
echo "  - Test Results: test-results/"
echo ""
