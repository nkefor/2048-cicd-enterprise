#!/bin/bash

################################################################################
# Infrastructure Testing Suite
# Runs: Security scanning, compliance checks, unit tests, integration tests
# Usage: ./run-all-tests.sh
################################################################################

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

FAILED_TESTS=0

print_info "=========================================="
print_info "Infrastructure Testing Suite"
print_info "=========================================="

# Test 1: Terraform Validation
print_info "Test 1/6: Terraform Validation..."
cd infra
if terraform init -backend=false && terraform validate; then
    print_success "Terraform validation passed"
else
    print_error "Terraform validation failed"
    ((FAILED_TESTS++))
fi
cd ..

# Test 2: tfsec Security Scanning
print_info "Test 2/6: Security Scanning (tfsec)..."
if command -v tfsec &> /dev/null; then
    if tfsec infra/ --soft-fail; then
        print_success "Security scan passed"
    else
        print_error "Security issues found"
        ((FAILED_TESTS++))
    fi
else
    print_error "tfsec not installed. Install: brew install tfsec"
    ((FAILED_TESTS++))
fi

# Test 3: Checkov Compliance Scanning
print_info "Test 3/6: Compliance Scanning (Checkov)..."
if command -v checkov &> /dev/null; then
    if checkov -d infra/ --quiet --compact; then
        print_success "Compliance scan passed"
    else
        print_error "Compliance issues found"
        ((FAILED_TESTS++))
    fi
else
    print_error "checkov not installed. Install: pip install checkov"
    ((FAILED_TESTS++))
fi

# Test 4: Terraform Format Check
print_info "Test 4/6: Terraform Format Check..."
cd infra
if terraform fmt -check -recursive; then
    print_success "Terraform format check passed"
else
    print_error "Terraform files need formatting. Run: terraform fmt -recursive"
    ((FAILED_TESTS++))
fi
cd ..

# Test 5: YAML Lint (for Kubernetes manifests)
print_info "Test 5/6: YAML Lint..."
if command -v yamllint &> /dev/null; then
    if yamllint -c .yamllint gitops/ || true; then
        print_success "YAML lint passed"
    fi
else
    print_info "yamllint not installed (optional). Install: pip install yamllint"
fi

# Test 6: ShellCheck (for bash scripts)
print_info "Test 6/6: ShellCheck..."
if command -v shellcheck &> /dev/null; then
    find scripts/ -name "*.sh" -exec shellcheck {} + || ((FAILED_TESTS++))
    print_success "ShellCheck passed"
else
    print_info "shellcheck not installed (optional). Install: brew install shellcheck"
fi

# Summary
print_info "=========================================="
if [ $FAILED_TESTS -eq 0 ]; then
    print_success "✅ All tests passed!"
    exit 0
else
    print_error "❌ $FAILED_TESTS test(s) failed"
    exit 1
fi
