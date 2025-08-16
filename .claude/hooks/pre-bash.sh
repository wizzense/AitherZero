#!/bin/bash
# Pre-bash hook - validate and suggest improvements for commands

# Read input from stdin
INPUT=$(cat)

# Extract command from the input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Check for common patterns that could use playbooks
if echo "$COMMAND" | grep -qE "Invoke-Pester.*-Path.*tests"; then
    echo "💡 Tip: Consider using 'az 0402' or test-quick playbook for running tests" >&2
fi

if echo "$COMMAND" | grep -qE "git add.*git commit"; then
    echo "💡 Tip: Use 'az 0702' for conventional commits with validation" >&2
fi

# Warn about long-running commands without background flag
if echo "$COMMAND" | grep -qE "(npm install|npm run build|docker build)"; then
    RUN_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false')
    if [ "$RUN_BG" != "true" ]; then
        echo "⚠️ Long-running command detected. Consider using run_in_background flag" >&2
    fi
fi

exit 0