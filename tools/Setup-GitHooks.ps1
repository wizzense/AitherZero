#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Setup Git hooks for AitherZero development
.DESCRIPTION
    Configures Git to use the custom hooks in .githooks/ directory.
    These hooks help maintain code quality by validating changes before commits.
.EXAMPLE
    ./tools/Setup-GitHooks.ps1
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
Write-Host "What's enabled:" -ForegroundColor Cyan
Write-Host "  • pre-commit: Validates config.psd1 before commits" -ForegroundColor White
Write-Host ""
Write-Host "To disable hooks (not recommended):" -ForegroundColor Yellow
Write-Host "  git config --unset core.hooksPath" -ForegroundColor Gray
Write-Host ""
Write-Host "To bypass a specific commit:" -ForegroundColor Yellow
Write-Host "  git commit --no-verify" -ForegroundColor Gray
Write-Host ""
Write-Host "For more information, see .githooks/README.md" -ForegroundColor Cyan
Write-Host ""
