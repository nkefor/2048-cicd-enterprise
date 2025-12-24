#!/bin/bash

###############################################################################
# TFSec Security Scanner
# Scans Terraform code for security vulnerabilities and misconfigurations
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

echo "========================================="
echo "TFSec Security Scan"
echo "========================================="

# Check if infra directory exists
if [ ! -d "$INFRA_DIR" ]; then
  echo "⚠️  Warning: infra/ directory does not exist yet"
  echo "This test will pass until Terraform infrastructure is added"
  echo ""
  echo "TFSec will scan for:"
  echo "  - Unencrypted resources"
  echo "  - Publicly accessible resources"
  echo "  - Missing security groups"
  echo "  - Weak encryption settings"
  echo "  - IAM policy issues"
  echo "  - And more..."
  exit 0
fi

echo "✓ Found infra/ directory"
echo ""

# Check if tfsec is installed
if ! command -v tfsec &> /dev/null; then
  echo "⚠️  Warning: tfsec is not installed"
  echo "Installing tfsec is recommended for security scanning"
  echo ""
  echo "To install tfsec:"
  echo "  macOS:   brew install tfsec"
  echo "  Linux:   curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash"
  echo "  Windows: choco install tfsec"
  echo ""
  echo "Skipping tfsec scan..."
  exit 0
fi

TFSEC_VERSION=$(tfsec --version 2>&1 | head -n1 || echo "unknown")
echo "✓ tfsec found: $TFSEC_VERSION"
echo ""

# Run tfsec scan
echo "Running tfsec security scan..."
echo ""

# Run tfsec with various options
# --soft-fail: Don't exit with error code
# --format: Output format
# --minimum-severity: Only show issues of this severity or higher

if tfsec "$INFRA_DIR" \
  --format lovely \
  --minimum-severity MEDIUM \
  --exclude-downloaded-modules; then
  echo ""
  echo "✅ No security issues found by tfsec"
else
  EXIT_CODE=$?
  echo ""
  echo "❌ Security issues found by tfsec"
  echo "Please review and fix the issues above"
  exit $EXIT_CODE
fi

echo ""
echo "========================================="
echo "✅ TFSec security scan completed"
echo "========================================="
