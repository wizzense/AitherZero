#!/bin/bash
# Stop hook - check if there are pending tasks when Claude stops

# Read input from stdin
INPUT=$(cat)

cd "$CLAUDE_PROJECT_DIR"

# Check for various pending work
PENDING_WORK=""

# Check for uncommitted changes
if git status --porcelain | grep -q .; then
    PENDING_WORK="${PENDING_WORK}📝 Uncommitted changes detected\n"
fi

# Check for open test issues
if [ -f "test-fix-tracker.json" ]; then
    OPEN_ISSUES=$(jq '[.issues[] | select(.status == "open")] | length' test-fix-tracker.json 2>/dev/null)
    RESOLVED_UNCOMMITTED=$(jq '[.issues[] | select(.status == "resolved" and .fixCommit == null)] | length' test-fix-tracker.json 2>/dev/null)
    
    if [ "$OPEN_ISSUES" -gt 0 ]; then
        PENDING_WORK="${PENDING_WORK}🔴 $OPEN_ISSUES test failures need fixing\n"
    fi
    
    if [ "$RESOLVED_UNCOMMITTED" -gt 0 ]; then
        PENDING_WORK="${PENDING_WORK}✅ $RESOLVED_UNCOMMITTED resolved issues need committing\n"
    fi
fi

# If there's pending work, inform Claude
if [ -n "$PENDING_WORK" ]; then
    echo "" >&2
    echo "📋 Pending work detected:" >&2
    echo -e "$PENDING_WORK" >&2
    
    # Check if stop_hook_active to prevent infinite loops
    STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
    
    if [ "$STOP_ACTIVE" != "true" ] && [ "$OPEN_ISSUES" -gt 0 ]; then
        # Return JSON to continue and run test fix
        cat <<EOF
{
  "decision": "block",
  "reason": "There are $OPEN_ISSUES failing tests. Run the test-fix-workflow playbook to fix them: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-workflow -NonInteractive"
}
EOF
        exit 0
    fi
fi

exit 0