#!/bin/bash
# Direct playbook executor for Claude Code
# This allows Claude to run playbooks like native tools

PLAYBOOK="$1"
shift

if [ -z "$PLAYBOOK" ]; then
    echo "Error: No playbook specified" >&2
    echo "Usage: playbook <name> [options]" >&2
    echo "" >&2
    echo "Available playbooks:" >&2
    ls -1 /workspaces/AitherZero/orchestration/playbooks-psd1/**/*.psd1 2>/dev/null | xargs -n1 basename | sed 's/\.psd1$//' | sed 's/^/  - /' >&2
    exit 1
fi

cd "$CLAUDE_PROJECT_DIR"

echo "🎭 Executing playbook: $PLAYBOOK" >&2

# Run the playbook through AitherZero
pwsh -NoProfile -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook '$PLAYBOOK' -NonInteractive $*" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Playbook '$PLAYBOOK' completed successfully"
else
    echo "❌ Playbook '$PLAYBOOK' failed with exit code $EXIT_CODE" >&2
    exit $EXIT_CODE
fi