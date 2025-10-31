#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude pre-commit hook to enforce orchestrated playbook workflow
.DESCRIPTION
    Ensures all commits go through the proper orchestration playbook
#>

param(
    [string]$CommitMessage = $env:CLAUDE_COMMIT_MESSAGE,
    [string]$Branch = (git branch --show-current)
)

Write-Host "🔍 Claude Pre-Commit Hook: Enforcing orchestrated workflow..." -ForegroundColor Cyan

# Check if we're in a CI environment
if ($env:CI -eq 'true' -or $env:CLAUDE_CI -eq 'true') {
    Write-Host "✅ CI environment detected, skipping orchestration check" -ForegroundColor Green
    exit 0
}

# Check if orchestration was used
$orchestrationMarker = ".claude/.orchestration-used"
if (-not (Test-Path $orchestrationMarker)) {
    Write-Host "❌ Commits must use orchestrated playbook workflow!" -ForegroundColor Red
    Write-Host "Please use: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook claude-commit-workflow" -ForegroundColor Yellow

    # Provide quick action
    $response = Read-Host "Would you like to run the orchestration now? (y/n)"
    if ($response -eq 'y') {
        ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook claude-commit-workflow -NonInteractive
        exit $LASTEXITCODE
    }
    exit 1
}

# Clean up marker
Remove-Item $orchestrationMarker -Force -ErrorAction SilentlyContinue

Write-Host "✅ Orchestration verified" -ForegroundColor Green
exit 0