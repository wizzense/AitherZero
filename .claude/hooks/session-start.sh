#!/bin/bash
# Session start hook - load context and check project status

cd "$CLAUDE_PROJECT_DIR"

echo "🚀 AitherZero Session Started" >&2
echo "📂 Working directory: $CLAUDE_PROJECT_DIR" >&2

# Check current git branch
BRANCH=$(git branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "🌿 Current branch: $BRANCH" >&2
fi

# Check for test issues
if [ -f "test-fix-tracker.json" ]; then
    OPEN=$(jq '[.issues[] | select(.status == "open")] | length' test-fix-tracker.json 2>/dev/null)
    RESOLVED=$(jq '[.issues[] | select(.status == "resolved")] | length' test-fix-tracker.json 2>/dev/null)
    
    if [ "$OPEN" -gt 0 ] || [ "$RESOLVED" -gt 0 ]; then
        echo "" >&2
        echo "📊 Test Status:" >&2
        [ "$OPEN" -gt 0 ] && echo "  🔴 Open issues: $OPEN" >&2
        [ "$RESOLVED" -gt 0 ] && echo "  ✅ Resolved: $RESOLVED" >&2
    fi
fi

# Return context for Claude
cat <<EOF
## AitherZero Project Context

Current branch: $BRANCH

### Available Playbooks:
- test-quick: Fast validation (syntax, linting)
- test-full: Complete test suite  
- test-fix-workflow: Automatically fix failing tests
- test-ci: CI/CD test suite

### Quick Commands:
- Run tests: az 0402
- Fix tests: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-fix-workflow -NonInteractive
- Validate: seq 0404,0407
- Create PR: az 0703

### Orchestration:
Use './Start-AitherZero.ps1 -Mode Orchestrate -Playbook <name>' to run playbooks.
EOF

exit 0