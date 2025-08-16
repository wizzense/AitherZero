#!/bin/bash
# Pre file change hook - warn about critical files

# Read input from stdin
INPUT=$(cat)

# Extract file path from the input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# Warn about critical file modifications
if [[ "$FILE_PATH" == *"AitherZero.psd1" ]] || [[ "$FILE_PATH" == *"AitherZero.psm1" ]]; then
    echo "⚠️ Modifying core module file: $FILE_PATH" >&2
    echo "   Ensure changes are tested with 'az 0402'" >&2
fi

if [[ "$FILE_PATH" == */orchestration/playbooks-psd1/*.psd1 ]]; then
    echo "📋 Modifying playbook: $FILE_PATH" >&2
    echo "   Test with: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook <name> -WhatIf" >&2
fi

if [[ "$FILE_PATH" == */.github/workflows/*.yml ]] || [[ "$FILE_PATH" == */.github/workflows/*.yaml ]]; then
    echo "🔄 Modifying GitHub workflow: $FILE_PATH" >&2
    echo "   Validate with: az 0440" >&2
fi

exit 0