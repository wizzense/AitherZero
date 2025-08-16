#!/bin/bash
# AitherZero Playbook Runner - Simple tool for Claude to run playbooks
# Usage: pb <playbook> [options]

PLAYBOOK="$1"
shift

# If no playbook specified, list available
if [ -z "$PLAYBOOK" ]; then
    echo "📋 Available Playbooks:"
    echo ""
    echo "Testing:"
    echo "  pb test-quick         - Fast validation (2 min)"
    echo "  pb test-full          - Complete tests (10 min)"
    echo "  pb test-fix-workflow  - Fix failing tests with AI"
    echo ""
    echo "Building:"
    echo "  pb build-release      - Build production release"
    echo "  pb deploy-staging     - Deploy to staging"
    echo "  pb deploy-prod        - Deploy to production"
    echo ""
    echo "Auditing:"
    echo "  pb audit-full         - Complete audit"
    echo "  pb audit-security     - Security scan"
    echo ""
    echo "Reporting:"
    echo "  pb report-dashboard   - Executive dashboard"
    echo "  pb report-weekly      - Weekly report"
    echo ""
    echo "Usage: pb <playbook> [options]"
    exit 0
fi

cd /workspaces/AitherZero

echo "🎭 Running playbook: $PLAYBOOK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run playbook with progress indicator
pwsh -NoProfile -Command "
    \$ProgressPreference = 'Continue'
    ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook '$PLAYBOOK' -NonInteractive $*
"

EXIT_CODE=$?

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Playbook '$PLAYBOOK' completed successfully"
else
    echo "❌ Playbook '$PLAYBOOK' failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE