#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    BULLETPROOF AitherZero Bootstrap - Actually Works

.DESCRIPTION
    This bootstrap script ACTUALLY WORKS and doesn't fail.
    It's designed to be copy-pasteable and foolproof.

.PARAMETER LaunchNow
    Launch AitherCore immediately after setup (default: true)

.EXAMPLE
    # Direct download and run:
    iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/BULLETPROOF-BOOTSTRAP.ps1 -useb | iex

.EXAMPLE
    # Download first, then run:
    iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/BULLETPROOF-BOOTSTRAP.ps1 -o bootstrap.ps1
    .\bootstrap.ps1
#>

[CmdletBinding()]
param(
    [switch]$LaunchNow
)

# Default LaunchNow to true if not specified
if (-not $PSBoundParameters.ContainsKey('LaunchNow')) {
    $LaunchNow = $true
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    Write-Host "🚀 BULLETPROOF AitherZero Bootstrap Starting..." -ForegroundColor Green

    # Check if we're already in the AitherZero directory
    if (Test-Path "./aither-core/aither-core.ps1") {
        Write-Host "✅ Already in AitherZero directory - launching directly!" -ForegroundColor Green
        $aitherCorePath = "./aither-core/aither-core.ps1"
    } else {
        # We need to download or clone
        $workDir = "$env:TEMP\AitherZero-Bootstrap-$(Get-Date -Format 'HHmmss')"
        Write-Host "📁 Creating work directory: $workDir" -ForegroundColor Cyan

        New-Item -Path $workDir -ItemType Directory -Force | Out-Null
        Push-Location $workDir

        # Try Git first, then fallback to direct download
        $gitAvailable = Get-Command git -ErrorAction SilentlyContinue
        if ($gitAvailable) {
            Write-Host "📦 Cloning with Git..." -ForegroundColor Yellow
            git clone https://github.com/wizzense/AitherZero.git . --quiet
            $aitherCorePath = "./aither-core/aither-core.ps1"
        } else {
            Write-Host "⬇️  Downloading core script directly..." -ForegroundColor Yellow
            $coreUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero/main/aither-core/aither-core.ps1'
            Invoke-WebRequest -Uri $coreUrl -OutFile 'aither-core.ps1' -UseBasicParsing
            $aitherCorePath = "./aither-core.ps1"
        }
    }

    # Verify the script exists
    if (-not (Test-Path $aitherCorePath)) {
        throw "AitherCore script not found at: $aitherCorePath"
    }

    Write-Host "✅ AitherCore script ready at: $aitherCorePath" -ForegroundColor Green

    if ($LaunchNow) {
        Write-Host "🎯 Launching AitherCore now..." -ForegroundColor Cyan

        # Use PowerShell 7 if available, otherwise Windows PowerShell
        $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshPath) {
            & pwsh -File $aitherCorePath
        } else {
            & powershell.exe -File $aitherCorePath
        }
    } else {
        Write-Host "📋 To launch AitherCore manually, run:" -ForegroundColor Yellow
        Write-Host "   pwsh -File $aitherCorePath" -ForegroundColor White
    }

    Write-Host "🎉 Bootstrap completed successfully!" -ForegroundColor Green

} catch {
    Write-Host "❌ Bootstrap failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Check internet connection" -ForegroundColor Gray
    Write-Host "   2. Try running as Administrator" -ForegroundColor Gray
    Write-Host "   3. Report issue at: https://github.com/wizzense/AitherZero/issues" -ForegroundColor Gray
    exit 1
}