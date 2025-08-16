#!/bin/bash
# Post file change hook - runs validation after file modifications

# Read input from stdin
INPUT=$(cat)

# Extract file path from the input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // ""' 2>/dev/null)

# If a PowerShell file was modified, run syntax validation
if [[ "$FILE_PATH" == *.ps1 ]] || [[ "$FILE_PATH" == *.psm1 ]] || [[ "$FILE_PATH" == *.psd1 ]]; then
    echo "🔍 Running syntax validation for: $FILE_PATH" >&2
    
    # Run the validation playbook
    cd "$CLAUDE_PROJECT_DIR"
    pwsh -NoProfile -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -NonInteractive" 2>&1 | tail -n 20
    
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo "⚠️ Validation failed. Consider running test-fix-workflow playbook." >&2
        exit 0  # Don't block, just warn
    fi
fi

exit 0