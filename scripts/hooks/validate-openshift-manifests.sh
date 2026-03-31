#!/bin/bash
#
# Pre-commit hook: Validate OpenShift / Kubernetes resource manifests (kubeval)
# Usage: Called by pre-commit framework
#

set -e

# Check if kubeval is installed
if ! command -v kubeval &> /dev/null; then
    echo "⚠️  kubeval not installed - skipping OpenShift manifest validation"
    echo "Install: wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz"
    exit 0
fi

FAIL_COUNT=0

for file in "$@"; do
    # Only process files that look like API resource manifests
    if grep -q "apiVersion:" "$file" 2>/dev/null; then
        # Skip Kustomization files
        if grep -q "kind: Kustomization" "$file"; then
            continue
        fi

        echo "Validating: $file"

        if ! kubeval --strict --ignore-missing-schemas "$file" 2>&1; then
            echo "  ❌ Validation failed: $file"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
done

if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo "❌ $FAIL_COUNT OpenShift manifest(s) failed validation"
    exit 1
fi

exit 0
