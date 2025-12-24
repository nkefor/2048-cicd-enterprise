#!/bin/bash

###############################################################################
# Checkov Policy Scanner
# Scans infrastructure-as-code for policy violations and security issues
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

echo "========================================="
echo "Checkov Policy Scan"
echo "========================================="

# Check if infra directory exists
if [ ! -d "$INFRA_DIR" ]; then
  echo "⚠️  Warning: infra/ directory does not exist yet"
  echo "This test will pass until Terraform infrastructure is added"
  echo ""
  echo "Checkov will check for:"
  echo "  - CIS compliance violations"
  echo "  - Cloud security best practices"
  echo "  - Resource misconfigurations"
  echo "  - Compliance framework violations"
  echo "  - And more..."
  exit 0
fi

echo "✓ Found infra/ directory"
echo ""

# Check if checkov is installed
if ! command -v checkov &> /dev/null; then
  echo "⚠️  Warning: checkov is not installed"
  echo "Installing checkov is recommended for policy scanning"
  echo ""
  echo "To install checkov:"
  echo "  pip3 install checkov"
  echo "  or"
  echo "  brew install checkov"
  echo ""
  echo "Skipping checkov scan..."
  exit 0
fi

CHECKOV_VERSION=$(checkov --version 2>&1 | head -n1 || echo "unknown")
echo "✓ checkov found: $CHECKOV_VERSION"
echo ""

# Run checkov scan
echo "Running checkov policy scan..."
echo ""

# Run checkov with various options
# --directory: Directory to scan
# --framework: Only scan specific frameworks
# --quiet: Reduce output verbosity
# --compact: More readable output
# --output: Output format

if checkov \
  --directory "$INFRA_DIR" \
  --framework terraform \
  --compact \
  --quiet; then
  echo ""
  echo "✅ No policy violations found by checkov"
else
  EXIT_CODE=$?
  echo ""
  echo "❌ Policy violations found by checkov"
  echo "Please review and fix the issues above"

  # Exit code 1 means issues found but not critical
  if [ $EXIT_CODE -eq 1 ]; then
    echo ""
    echo "Note: Some findings may be acceptable depending on your security requirements"
    echo "Review each finding and apply exceptions if needed"
  fi

  exit $EXIT_CODE
fi

echo ""
echo "========================================="
echo "✅ Checkov policy scan completed"
echo "========================================="
