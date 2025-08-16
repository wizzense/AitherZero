#!/bin/bash
# Subagent complete hook - check results of Task tool agents

# Read input from stdin
INPUT=$(cat)

cd "$CLAUDE_PROJECT_DIR"

# Log subagent completion
echo "🤖 Subagent task completed" >&2

# If test-runner agent was used, check for test status
if echo "$INPUT" | jq -e '.tool_input.subagent_type == "test-runner"' >/dev/null 2>&1; then
    echo "🔍 Test-runner agent completed. Checking test status..." >&2
    
    if [ -f "test-fix-tracker.json" ]; then
        OPEN=$(jq '[.issues[] | select(.status == "open")] | length' test-fix-tracker.json 2>/dev/null)
        if [ "$OPEN" -gt 0 ]; then
            echo "   Still $OPEN tests failing" >&2
        else
            echo "   ✅ All tests passing!" >&2
        fi
    fi
fi

exit 0