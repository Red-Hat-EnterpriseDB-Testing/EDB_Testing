#!/bin/bash
#
# Pre-commit hook: Check that scripts are executable
# Usage: Called by pre-commit framework
#

NON_EXEC=0

for file in "$@"; do
    if [ ! -x "$file" ]; then
        echo "⚠️  Script not executable: $file"
        echo "   Fix with: chmod +x $file"
        NON_EXEC=$((NON_EXEC + 1))
    fi
done

if [ $NON_EXEC -gt 0 ]; then
    echo ""
    echo "❌ $NON_EXEC script(s) are not executable"
    echo "Run: chmod +x <script-name>"
    exit 1
fi

exit 0
