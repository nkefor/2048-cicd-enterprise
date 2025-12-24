#!/bin/bash

###############################################################################
# Terraform Validation Test
# Validates Terraform configuration syntax and consistency
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

echo "========================================="
echo "Terraform Validation Test"
echo "========================================="

# Check if infra directory exists
if [ ! -d "$INFRA_DIR" ]; then
  echo "⚠️  Warning: infra/ directory does not exist yet"
  echo "This test will pass until Terraform infrastructure is added"
  echo ""
  echo "To add Terraform infrastructure:"
  echo "  1. Create infra/ directory"
  echo "  2. Add Terraform configuration files"
  echo "  3. Run this test again"
  exit 0
fi

echo "✓ Found infra/ directory"
echo ""

# Change to infra directory
cd "$INFRA_DIR"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
  echo "❌ Error: Terraform is not installed"
  echo "Please install Terraform: https://www.terraform.io/downloads"
  exit 1
fi

TERRAFORM_VERSION=$(terraform version | head -n1)
echo "✓ Terraform found: $TERRAFORM_VERSION"
echo ""

# Run terraform fmt check
echo "Running terraform fmt -check..."
if terraform fmt -check -recursive; then
  echo "✅ Terraform formatting is correct"
else
  echo "❌ Terraform formatting issues found"
  echo "Run: terraform fmt -recursive"
  exit 1
fi
echo ""

# Initialize Terraform (backend=false for validation only)
echo "Initializing Terraform (validation mode)..."
if terraform init -backend=false > /dev/null 2>&1; then
  echo "✅ Terraform initialized successfully"
else
  echo "❌ Terraform initialization failed"
  exit 1
fi
echo ""

# Validate Terraform configuration
echo "Running terraform validate..."
if terraform validate; then
  echo "✅ Terraform configuration is valid"
else
  echo "❌ Terraform validation failed"
  exit 1
fi
echo ""

echo "========================================="
echo "✅ All Terraform validation tests passed"
echo "========================================="
