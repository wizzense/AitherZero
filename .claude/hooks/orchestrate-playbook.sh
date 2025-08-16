#!/bin/bash
# Master orchestration hook - runs playbooks based on triggers
# Usage: orchestrate-playbook.sh <playbook-name> [additional-args]

PLAYBOOK=${1:-test-quick}
shift

cd "$CLAUDE_PROJECT_DIR"

echo "🎭 Running playbook: $PLAYBOOK" >&2

# Execute the playbook through AitherZero orchestration
pwsh -NoProfile -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook $PLAYBOOK -NonInteractive $*" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Playbook '$PLAYBOOK' completed successfully" >&2
else
    echo "❌ Playbook '$PLAYBOOK' failed with exit code $EXIT_CODE" >&2
fi

exit $EXIT_CODE