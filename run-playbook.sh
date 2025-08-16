#!/bin/bash
# Simple playbook runner - NO TIMEOUTS, just run until complete

PLAYBOOK="$1"
shift

cd /workspaces/AitherZero

echo "Running playbook: $PLAYBOOK"
pwsh -NoProfile -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook '$PLAYBOOK' -NonInteractive $*"

echo "Playbook $PLAYBOOK completed with exit code: $?"