#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick one-command release after PR merge
.DESCRIPTION
    Simplest way to create a release tag after your PR has been merged.
    Just run this script and it handles everything.
.EXAMPLE
    ./quick-release.ps1
    Creates release using VERSION file
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host "`n🚀 Quick Release for AitherZero" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

try {
    # Just call the main script
    $scriptPath = Join-Path $PSScriptRoot "create-release-tag.ps1"
    & $scriptPath
} catch {
    Write-Host "`n❌ Quick release failed: $_" -ForegroundColor Red
    exit 1
}