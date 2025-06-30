#!/usr/bin/env pwsh

# Check PowerShell version compatibility
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "PowerShell 5.0 or higher is required. Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit 1
}

Write-Host 'AitherZero Infrastructure Automation Framework v1.1.0' -ForegroundColor Cyan
Write-Host '   Application Package - Essential Components' -ForegroundColor Yellow

$env:PROJECT_ROOT = $PSScriptRoot

# Launch the core application
& (Join-Path $PSScriptRoot 'aither-core.ps1') @args

