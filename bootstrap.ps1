#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Bootstrap script for AitherZero Infrastructure Automation

.DESCRIPTION
    Simple bootstrap script that clones the repository and launches AitherCore.
    This replaces the old kicker-git.ps1 approach.

.PARAMETER LocalPath
    Local path to clone the repository (default: .\AitherZero)

.PARAMETER Branch
    Git branch to clone (default: main)

.PARAMETER Launch
    Automatically launch AitherCore after cloning (default: $true)

.EXAMPLE
    .\bootstrap.ps1

.EXAMPLE
    .\bootstrap.ps1 -LocalPath "C:\Labs\AitherZero" -Branch "develop"
#>

[CmdletBinding()]
param(    [string]$LocalPath = '.\AitherZero',
    [string]$Branch = 'main',
    [switch]$Launch
)

Write-Host '🚀 AitherZero Bootstrap v1.0' -ForegroundColor Green
Write-Host 'Cloning repository...' -ForegroundColor Cyan

try {
    # Clone the repository
    if (Test-Path $LocalPath) {
        Write-Host 'Directory already exists, updating...' -ForegroundColor Yellow
        Set-Location $LocalPath
        git pull origin $Branch
    } else {
        git clone --branch $Branch https://github.com/wizzense/AitherZero.git $LocalPath
        Set-Location $LocalPath
    }

    Write-Host "✅ Repository ready at: $(Get-Location)" -ForegroundColor Green    if ($Launch) {
        Write-Host '🎯 Launching AitherCore...' -ForegroundColor Cyan

        # Check if PowerShell 7 is available
        $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshPath) {
            & pwsh -File './aither-core/aither-core.ps1'
        } else {
            Write-Warning 'PowerShell 7 not found, using Windows PowerShell...'
            & powershell.exe -File './aither-core/aither-core.ps1'
        }
    } else {
        Write-Host '📋 To launch AitherCore manually:' -ForegroundColor Yellow
        Write-Host '  pwsh -File ./aither-core/aither-core.ps1' -ForegroundColor White
        Write-Host '  Use -Launch switch to auto-launch next time' -ForegroundColor Gray
    }

} catch {
    Write-Error "Bootstrap failed: $($_.Exception.Message)"
    exit 1
}
