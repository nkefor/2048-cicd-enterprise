#!/bin/bash
set -euo pipefail

##############################################################################
# Pre-Commit Test Hook
# Runs before git commit to ensure code quality
##############################################################################

echo "🔍 Running pre-commit tests..."
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if any checks fail
CHECKS_FAILED=0

# Function to run check
check() {
    local name="$1"
    local command="$2"

    printf "  ▶ %-40s" "$name..."

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# 1. Check for secrets/sensitive data
if command -v grep &> /dev/null; then
    check "Checking for AWS credentials" \
        "! git diff --cached | grep -i 'aws_access_key\\|aws_secret'"

    check "Checking for private keys" \
        "! git diff --cached | grep -i 'BEGIN.*PRIVATE KEY'"

    check "Checking for passwords" \
        "! git diff --cached | grep -i 'password.*=.*['\\\"].*['\\\"]'"
fi

# 2. Check Dockerfile if changed
if git diff --cached --name-only | grep -q "2048/Dockerfile"; then
    if command -v hadolint &> /dev/null; then
        check "Linting Dockerfile" \
            "hadolint 2048/Dockerfile"
    else
        echo -e "  ${YELLOW}⚠${NC}  Dockerfile changed but hadolint not installed"
    fi
fi

# 3. Check if container builds (if Dockerfile or app changed)
if git diff --cached --name-only | grep -qE "2048/(Dockerfile|www/)"; then
    check "Docker build test" \
        "docker build -t 2048-precommit-test ./2048 && docker rmi 2048-precommit-test"
fi

# 4. Check test files syntax (if test files changed)
if git diff --cached --name-only | grep -q "tests/.*\.js$"; then
    if command -v node &> /dev/null; then
        git diff --cached --name-only | grep "tests/.*\.js$" | while read -r file; do
            if [ -n "$file" ]; then
                check "Syntax check: $(basename "$file")" \
                    "node -c \"$file\""
            fi
        done
    fi
fi

# 5. Check shell scripts syntax (if shell scripts changed)
if git diff --cached --name-only | grep -q "\.sh$"; then
    git diff --cached --name-only | grep "\.sh$" | while read -r file; do
        if [ -f "$file" ]; then
            check "Syntax check: $(basename "$file")" \
                "bash -n \"$file\""
        fi
    done
fi

# Print results
echo ""
if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ $CHECKS_FAILED pre-commit check(s) failed!${NC}"
    echo ""
    echo "Fix the issues above before committing."
    echo "To bypass these checks (not recommended):"
    echo "  git commit --no-verify"
    echo ""
    exit 1
fi
