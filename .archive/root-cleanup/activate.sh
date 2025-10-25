#!/bin/bash
# AitherZero environment activation
export AITHERZERO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$AITHERZERO_ROOT/automation-scripts:$PATH"
alias az="pwsh $AITHERZERO_ROOT/az.ps1"
alias aither="pwsh $AITHERZERO_ROOT/Start-AitherZero.ps1"
echo "✓ AitherZero environment activated"
echo "  Commands: az <num>, aither"
