#!/usr/bin/env pwsh
#Requires -Version 7.0
# Stage: Environment
# Dependencies: None
# Tags: git, hooks, development, setup
<#
.SYNOPSIS
    Setup Git hooks for AitherZero development
.DESCRIPTION
    Configures Git to use the custom hooks in .githooks/ directory.
    These hooks help maintain code quality by validating changes before commits.
    
    This script is part of the Environment Setup stage (0000-0099).
.EXAMPLE
    ./automation-scripts/0003_Setup-GitHooks.ps1
    
    Configures Git to use AitherZero hooks
.NOTES
    Run this once after cloning the repository to enable pre-commit validation.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "🔧 Setting up Git hooks for AitherZero..." -ForegroundColor Cyan
Write-Host ""

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Host "❌ Not in a Git repository!" -ForegroundColor Red
    Write-Host "Please run this script from the repository root directory." -ForegroundColor Yellow
    exit 1
}

# Check if .githooks directory exists
if (-not (Test-Path ".githooks")) {
    Write-Host "❌ .githooks directory not found!" -ForegroundColor Red
    Write-Host "Expected at: $PWD/.githooks" -ForegroundColor Yellow
    exit 1
}

# Configure Git to use .githooks
try {
    git config core.hooksPath .githooks
    Write-Host "✅ Git hooks path configured: .githooks" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to configure Git hooks path" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    exit 1
}

# Make hooks executable (Unix-like systems)
if ($IsLinux -or $IsMacOS) {
    Write-Host ""
    Write-Host "Making hooks executable..." -ForegroundColor Cyan
    
    Get-ChildItem -Path ".githooks" -Filter "*" -File | ForEach-Object {
        if ($_.Name -notlike "*.md" -and $_.Name -notlike "*.txt") {
            chmod +x $_.FullName
            Write-Host "  ✅ $($_.Name)" -ForegroundColor Green
        }
    }
}

# Display available hooks
Write-Host ""
Write-Host "📋 Available hooks:" -ForegroundColor Cyan
$hooks = Get-ChildItem -Path ".githooks" -Filter "*" -File | 
    Where-Object { $_.Name -notlike "*.md" -and $_.Name -notlike "*.txt" }

if ($hooks) {
    $hooks | ForEach-Object {
        Write-Host "  • $($_.Name)" -ForegroundColor White
    }
} else {
    Write-Host "  (No hooks found)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ Git hooks setup complete!" -ForegroundColor Green
Write-Host ""

# Configure Git merge strategy for auto-generated files
Write-Host "🔧 Configuring Git merge strategy for auto-generated files..." -ForegroundColor Cyan
try {
    # Configure the merge.ours driver
    git config --local merge.ours.name "Always use our version for auto-generated files"
    git config --local merge.ours.driver "true"
    Write-Host "✅ Git merge configuration complete!" -ForegroundColor Green
    
    # Verify attributes are set
    $indexMdMerge = git check-attr merge automation-scripts/index.md 2>$null
    if ($indexMdMerge -match "ours") {
        Write-Host "✅ Merge attribute correctly applied to index.md files" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Warning: Merge attribute not found in .gitattributes" -ForegroundColor Yellow
        Write-Host "   Expected: **/index.md merge=ours" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️  Failed to configure Git merge strategy: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "What's enabled:" -ForegroundColor Cyan
Write-Host "  • pre-commit: Validates config.psd1 before commits" -ForegroundColor White
Write-Host "  • merge.ours: Auto-generated files use 'ours' strategy" -ForegroundColor White
Write-Host ""
Write-Host "To disable hooks (not recommended):" -ForegroundColor Yellow
Write-Host "  git config --unset core.hooksPath" -ForegroundColor Gray
Write-Host ""
Write-Host "To bypass a specific commit:" -ForegroundColor Yellow
Write-Host "  git commit --no-verify" -ForegroundColor Gray
Write-Host ""
Write-Host "For more information, see .githooks/README.md" -ForegroundColor Cyan
Write-Host ""
