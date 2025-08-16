#!/bin/bash
# Check for test failures after Bash commands that run tests

# Read input from stdin
INPUT=$(cat)

# Extract command from the input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Check if the command was running tests
if echo "$COMMAND" | grep -qE "(Invoke-Pester|Run-UnitTests|0402|seq.*0402)"; then
    echo "🔍 Detected test execution. Checking for failures..." >&2
    
    cd "$CLAUDE_PROJECT_DIR"
    
    # Check if test-fix-tracker.json has open issues
    if [ -f "test-fix-tracker.json" ]; then
        OPEN_ISSUES=$(jq '[.issues[] | select(.status == "open")] | length' test-fix-tracker.json 2>/dev/null)
        
        if [ "$OPEN_ISSUES" -gt 0 ]; then
            echo "" >&2
            echo "⚠️ Found $OPEN_ISSUES failing tests!" >&2
            echo "💡 To fix automatically, run: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-workflow -NonInteractive" >&2
            echo "" >&2
            
            # Optionally return context for Claude
            echo "There are $OPEN_ISSUES failing tests that can be fixed with the test-fix-workflow playbook."
        fi
    fi
fi

exit 0