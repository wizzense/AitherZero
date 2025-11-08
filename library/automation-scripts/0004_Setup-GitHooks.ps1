#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Setup Git hooks for AitherZero development
.DESCRIPTION
    Configures Git to use the custom hooks in .githooks/ directory.
    These hooks help maintain code quality by validating changes before commits.
    Also configures Git merge strategy for auto-generated files.
    
    This script is part of the Environment Setup stage (0000-0099).
.EXAMPLE
    ./automation-scripts/0004_Setup-GitHooks.ps1
    
    Configures Git to use AitherZero hooks and merge strategy
.NOTES
    Stage: Environment
    Order: 0004
    Dependencies: None
    Tags: git, hooks, development, setup, environment
    
    Run this once after cloning the repository to enable pre-commit validation.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Import script utilities
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $ProjectRoot "aithercore/automation/ScriptUtilities.psm1") -Force -ErrorAction SilentlyContinue

Write-ScriptLog "Setting up Git hooks for AitherZero..." -Level 'Information'

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-ScriptLog "Not in a Git repository!" -Level 'Error'
    Write-ScriptLog "Please run this script from the repository root directory." -Level 'Warning'
    exit 1
}

# Check if .githooks directory exists
if (-not (Test-Path ".githooks")) {
    Write-ScriptLog ".githooks directory not found at: $PWD/.githooks" -Level 'Error'
    exit 1
}

# Configure Git to use .githooks
try {
    git config core.hooksPath .githooks
    Write-ScriptLog "Git hooks path configured: .githooks" -Level 'Information'
} catch {
    Write-ScriptLog "Failed to configure Git hooks path: $_" -Level 'Error'
    exit 1
}

# Make hooks executable (Unix-like systems)
if ($IsLinux -or $IsMacOS) {
    Write-ScriptLog "Making hooks executable..." -Level 'Information'
    
    Get-ChildItem -Path ".githooks" -Filter "*" -File | ForEach-Object {
        if ($_.Name -notlike "*.md" -and $_.Name -notlike "*.txt") {
            chmod +x $_.FullName
            Write-ScriptLog "  Made executable: $($_.Name)" -Level 'Information'
        }
    }
}

# Display available hooks
$hooks = Get-ChildItem -Path ".githooks" -Filter "*" -File | 
    Where-Object { $_.Name -notlike "*.md" -and $_.Name -notlike "*.txt" }

if ($hooks) {
    Write-ScriptLog "Available hooks: $($hooks.Name -join ', ')" -Level 'Information'
} else {
    Write-ScriptLog "No hooks found in .githooks directory" -Level 'Warning'
}

Write-ScriptLog "Git hooks setup complete" -Level 'Information'

# Configure Git merge strategy for auto-generated files
Write-ScriptLog "Configuring Git merge strategy for auto-generated files..." -Level 'Information'
try {
    # Configure the merge.ours driver
    git config --local merge.ours.name "Always use our version for auto-generated files"
    git config --local merge.ours.driver "true"
    Write-ScriptLog "Git merge configuration complete" -Level 'Information'
    
    # Verify attributes are set
    $indexMdMerge = git check-attr merge automation-scripts/index.md 2>$null
    if ($indexMdMerge -match "ours") {
        Write-ScriptLog "Merge attribute correctly applied to index.md files" -Level 'Information'
    } else {
        Write-ScriptLog "Merge attribute not found in .gitattributes (Expected: **/index.md merge=ours)" -Level 'Warning'
    }
} catch {
    Write-ScriptLog "Failed to configure Git merge strategy: $_" -Level 'Warning'
}

# Summary
Write-ScriptLog "Git hooks and merge strategy configured successfully" -Level 'Information'
Write-ScriptLog "Pre-commit hook: Validates config.psd1 before commits" -Level 'Information'
Write-ScriptLog "Merge strategy: Auto-generated files use 'ours' strategy" -Level 'Information'

exit 0
