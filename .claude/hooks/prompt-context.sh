#!/bin/bash
# User prompt submit hook - add context based on prompt content

# Read input from stdin
INPUT=$(cat)

# Extract prompt from the input
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)

cd "$CLAUDE_PROJECT_DIR"

# Check if user is asking about tests, playbooks, or orchestration
if echo "$PROMPT" | grep -qiE "(test|playbook|orchestrat|fix|fail|error|broken)"; then
    
    # Check current test status
    if [ -f "test-fix-tracker.json" ]; then
        OPEN=$(jq '[.issues[] | select(.status == "open")] | length' test-fix-tracker.json 2>/dev/null)
        
        if [ "$OPEN" -gt 0 ]; then
            echo "ℹ️ Current test status: $OPEN failing tests" >&2
            echo "Context: There are currently $OPEN failing tests. The test-fix-workflow playbook can fix them automatically."
        fi
    fi
    
    # List available playbooks if asking about playbooks
    if echo "$PROMPT" | grep -qiE "(playbook|orchestrat)"; then
        echo ""
        echo "Available playbooks in /orchestration/playbooks-psd1/:"
        ls -1 /workspaces/AitherZero/orchestration/playbooks-psd1/**/*.psd1 2>/dev/null | xargs -n1 basename | sed 's/\.psd1$//'
    fi
fi

# Check if user is asking about running or executing something
if echo "$PROMPT" | grep -qiE "(run|execute|start|launch|invoke)"; then
    echo ""
    echo "Quick execution examples:"
    echo "- Run tests: az 0402"
    echo "- Run playbook: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -NonInteractive"
    echo "- Fix tests: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-workflow -NonInteractive"
fi

exit 0