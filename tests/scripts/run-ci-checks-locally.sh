#!/bin/bash
#
# Run CI checks locally before pushing
# Simulates GitHub Actions workflows
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

echo "============================================="
echo "Running CI Checks Locally"
echo "============================================="
echo ""

# Track failures
FAILED_CHECKS=()

# YAML Validation
echo "📋 YAML Validation"
echo "-------------------"

if command -v yamllint &> /dev/null; then
    if yamllint . 2>&1; then
        echo "✅ YAML linting passed"
    else
        echo "❌ YAML linting failed"
        FAILED_CHECKS+=("yamllint")
    fi
else
    echo "⚠️  yamllint not installed - skipping"
fi

echo ""

# Kubeval
if command -v kubeval &> /dev/null; then
    echo "Validating Kubernetes manifests..."
    KUBEVAL_FAILED=0

    find . -type f \( -name "*.yaml" -o -name "*.yml" \) \
        -not -path "./.git/*" \
        -not -path "./.github/*" \
        -exec grep -l "apiVersion:" {} \; | while read -r file; do

        if ! grep -q "kind: Kustomization" "$file"; then
            if ! kubeval --strict --ignore-missing-schemas "$file" 2>&1; then
                KUBEVAL_FAILED=1
            fi
        fi
    done

    if [ $KUBEVAL_FAILED -eq 0 ]; then
        echo "✅ Kubeval passed"
    else
        echo "❌ Kubeval failed"
        FAILED_CHECKS+=("kubeval")
    fi
else
    echo "⚠️  kubeval not installed - skipping"
fi

echo ""

# Shell Script Testing
echo "🐚 Shell Script Testing"
echo "------------------------"

if command -v shellcheck &> /dev/null; then
    echo "Running ShellCheck..."
    SHELLCHECK_FAILED=0

    find . -type f -name "*.sh" \
        -not -path "./.git/*" \
        -not -path "./node_modules/*" | while read -r script; do

        if ! shellcheck -S warning "$script" 2>&1; then
            SHELLCHECK_FAILED=1
        fi
    done

    if [ $SHELLCHECK_FAILED -eq 0 ]; then
        echo "✅ ShellCheck passed"
    else
        echo "❌ ShellCheck failed"
        FAILED_CHECKS+=("shellcheck")
    fi
else
    echo "⚠️  shellcheck not installed - skipping"
fi

echo ""

# Bash syntax check
echo "Checking Bash syntax..."
SYNTAX_FAILED=0

find . -type f -name "*.sh" \
    -not -path "./.git/*" | while read -r script; do

    if ! bash -n "$script" 2>&1; then
        echo "  ❌ Syntax error: $script"
        SYNTAX_FAILED=1
    fi
done

if [ $SYNTAX_FAILED -eq 0 ]; then
    echo "✅ Bash syntax check passed"
else
    echo "❌ Bash syntax check failed"
    FAILED_CHECKS+=("bash-syntax")
fi

echo ""

# Security Scan
echo "🔒 Security Scan"
echo "----------------"

echo "Scanning for potential secrets..."
SECRET_FOUND=0

PATTERNS=(
    "password\s*=\s*['\"][^'\"]+['\"]"
    "api[_-]?key\s*=\s*['\"][^'\"]+['\"]"
)

for pattern in "${PATTERNS[@]}"; do
    if grep -r -i -E "$pattern" . \
        --exclude-dir=.git \
        --exclude-dir=node_modules \
        --exclude="*.md" \
        --exclude="run-ci-checks-locally.sh" 2>/dev/null; then
        SECRET_FOUND=1
    fi
done

if [ $SECRET_FOUND -eq 0 ]; then
    echo "✅ No obvious secrets detected"
else
    echo "⚠️  Potential secrets found - review manually"
fi

echo ""

# Pre-commit hooks
echo "🪝 Pre-commit Hooks"
echo "-------------------"

if command -v pre-commit &> /dev/null; then
    if pre-commit run --all-files 2>&1; then
        echo "✅ Pre-commit hooks passed"
    else
        echo "❌ Pre-commit hooks failed"
        FAILED_CHECKS+=("pre-commit")
    fi
else
    echo "⚠️  pre-commit not installed"
    echo "Install with: pip install pre-commit"
fi

echo ""

# Summary
echo "============================================="
echo "Summary"
echo "============================================="

if [ ${#FAILED_CHECKS[@]} -eq 0 ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "You're ready to push your changes."
    exit 0
else
    echo "❌ Some checks failed:"
    for check in "${FAILED_CHECKS[@]}"; do
        echo "  - $check"
    done
    echo ""
    echo "Please fix the issues before pushing."
    exit 1
fi
