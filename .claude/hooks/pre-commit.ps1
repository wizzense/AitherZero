#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude pre-commit hook to enforce orchestrated playbook workflow
.DESCRIPTION
    Ensures all commits go through the proper orchestration playbook.
    This hook validates that Claude-initiated commits follow the proper
    orchestration workflow by checking for an orchestration marker file.
.PARAMETER CommitMessage
    Optional commit message (from environment variable CLAUDE_COMMIT_MESSAGE)
.PARAMETER Branch
    Optional branch name (defaults to current branch)
.EXAMPLE
    ./.claude/hooks/pre-commit.ps1
    Run pre-commit validation in interactive mode
.EXAMPLE
    $env:CLAUDE_CI = 'true'; ./.claude/hooks/pre-commit.ps1
    Skip orchestration check in CI environment
#>

[CmdletBinding()]
param(
    [string]$CommitMessage = $env:CLAUDE_COMMIT_MESSAGE,
    [string]$Branch = (git branch --show-current)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Logging helper function
function Write-HookLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    # Try using the project logging system first
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source 'PreCommitHook'
    } else {
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'Cyan'
        }[$Level]
        Write-Host $Message -ForegroundColor $color
    }
}

try {
    Write-HookLog -Message "Claude Pre-Commit Hook: Enforcing orchestrated workflow..." -Level Information

    # Parameters are available for future enhancements (e.g., commit message validation, branch-specific rules)
    if ($CommitMessage) {
        Write-HookLog -Message "Processing commit with message length: $($CommitMessage.Length)" -Level Information
    }
    if ($Branch) {
        Write-HookLog -Message "Current branch: $Branch" -Level Information
    }

    # Check if we're in a CI environment
    if ($env:CI -eq 'true' -or $env:CLAUDE_CI -eq 'true') {
        Write-HookLog -Message "CI environment detected, skipping orchestration check" -Level Information
        exit 0
    }

    # Check if orchestration was used
    $orchestrationMarker = ".claude/.orchestration-used"
    Write-HookLog -Message "Checking for orchestration marker: $orchestrationMarker" -Level Information

    if (-not (Test-Path $orchestrationMarker)) {
        Write-HookLog -Message "Commits must use orchestrated playbook workflow!" -Level Error
        Write-Host "Please use: ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook claude-commit-workflow" -ForegroundColor Yellow

        # Provide quick action
        $response = Read-Host "Would you like to run the orchestration now? (y/n)"
        if ($response -eq 'y') {
            Write-HookLog -Message "Starting orchestration workflow..." -Level Information
            ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook claude-commit-workflow -NonInteractive
            exit $LASTEXITCODE
        }
        Write-HookLog -Message "Pre-commit validation failed - no orchestration marker" -Level Error
        exit 1
    }

    # Clean up marker
    try {
        Remove-Item $orchestrationMarker -Force -ErrorAction Stop
        Write-HookLog -Message "Orchestration marker cleaned up successfully" -Level Information
    } catch {
        Write-HookLog -Message "Failed to remove orchestration marker: $_" -Level Warning
        # Not critical, continue
    }

    Write-HookLog -Message "Orchestration verified successfully" -Level Information
    exit 0

} catch {
    Write-HookLog -Message "Pre-commit hook failed: $_" -Level Error
    exit 1
}