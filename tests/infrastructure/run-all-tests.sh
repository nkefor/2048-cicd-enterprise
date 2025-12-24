#!/bin/bash

###############################################################################
# Infrastructure Test Suite Runner
# Runs all infrastructure-as-code tests
###############################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Infrastructure Test Suite"
echo "========================================"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to run a test script
run_test() {
  local test_name="$1"
  local test_script="$2"

  echo "Running: $test_name"
  echo "----------------------------------------"

  if [ ! -x "$test_script" ]; then
    chmod +x "$test_script"
  fi

  if "$test_script"; then
    echo "✅ PASSED: $test_name"
    ((TESTS_PASSED++))
  else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
      echo "⚠️  SKIPPED: $test_name"
      ((TESTS_SKIPPED++))
    else
      echo "❌ FAILED: $test_name (exit code: $EXIT_CODE)"
      ((TESTS_FAILED++))
    fi
  fi

  echo ""
}

# Run all tests
run_test "Terraform Validation" "$SCRIPT_DIR/terraform-validate.sh"
run_test "TFSec Security Scan" "$SCRIPT_DIR/tfsec-scan.sh"
run_test "Checkov Policy Scan" "$SCRIPT_DIR/checkov-scan.sh"

# Print summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Passed:  $TESTS_PASSED"
echo "Failed:  $TESTS_FAILED"
echo "Skipped: $TESTS_SKIPPED"
echo "========================================"

if [ $TESTS_FAILED -gt 0 ]; then
  echo "❌ Infrastructure tests failed"
  exit 1
else
  echo "✅ All infrastructure tests passed"
  exit 0
fi
