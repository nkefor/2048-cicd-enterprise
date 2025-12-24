#!/bin/bash
set -euo pipefail

##############################################################################
# Install Git Hooks
# Sets up pre-commit hooks for automated testing
##############################################################################

echo "╔════════════════════════════════════════════════════════╗"
echo "║              Installing Git Hooks                      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Change to project root
cd "$(dirname "$0")/../.."

# Check if .git directory exists
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository"
    echo "   Run this script from the project root directory"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Install pre-commit hook
echo "📝 Installing pre-commit hook..."

cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Auto-generated pre-commit hook
# Run tests before allowing commit

exec bash tests/scripts/pre-commit-test.sh
EOF

chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed"
echo ""

# Install commit-msg hook (optional - for commit message validation)
echo "📝 Installing commit-msg hook..."

cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash
# Auto-generated commit-msg hook
# Validate commit message format

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Check if commit message follows conventional commits format
# Format: <type>: <description>
# Types: feat, fix, docs, style, refactor, test, chore, ci

if ! echo "$COMMIT_MSG" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|ci|perf|build|revert)(\(.+\))?: .{1,}$'; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Commit messages must follow Conventional Commits format:"
    echo "  <type>: <description>"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore, ci"
    echo ""
    echo "Examples:"
    echo "  feat: Add new feature to game"
    echo "  fix: Correct health check endpoint"
    echo "  docs: Update testing documentation"
    echo "  test: Add comprehensive test suite improvements"
    echo ""
    exit 1
fi
EOF

chmod +x .git/hooks/commit-msg

echo "✅ Commit-msg hook installed"
echo ""

echo "╔════════════════════════════════════════════════════════╗"
echo "║              Git Hooks Installation Complete           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Installed hooks:"
echo "  ✓ pre-commit  - Runs tests before commit"
echo "  ✓ commit-msg  - Validates commit message format"
echo ""
echo "To bypass hooks (not recommended):"
echo "  git commit --no-verify"
echo ""
echo "To uninstall hooks:"
echo "  rm .git/hooks/pre-commit"
echo "  rm .git/hooks/commit-msg"
echo ""
