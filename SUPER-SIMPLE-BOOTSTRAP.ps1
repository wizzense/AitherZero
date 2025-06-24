#Requires -Version 5.1
<#
.SYNOPSIS
    SUPER SIMPLE AitherZero Bootstrap - No-Brain Installation

.DESCRIPTION
    This is the absolutely simplest way to get AitherZero running.
    Just run this script and everything else is automatic.

.EXAMPLE
    # Download and run in one line:
    iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/SUPER-SIMPLE-BOOTSTRAP.ps1 -useb | iex

.EXAMPLE
    # Or download first, then run:
    iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/SUPER-SIMPLE-BOOTSTRAP.ps1 -o bootstrap.ps1
    .\bootstrap.ps1

.NOTES
    This script does EVERYTHING for you:
    1. Creates a working directory
    2. Downloads the full AitherZero repository
    3. Launches AitherCore automatically
    4. No Git required, no complex setup, just works!
#>

[CmdletBinding()]
param(
    [string]$InstallPath = "$env:TEMP\AitherZero-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    [switch]$AutoStart,
    [switch]$Verbose
)

# Default AutoStart to true if not specified
if (-not $PSBoundParameters.ContainsKey('AutoStart')) {
    $AutoStart = $true
}

# Set up error handling
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    Write-Host '🚀 AitherZero Super Simple Bootstrap Starting...' -ForegroundColor Green
    Write-Host "📁 Installation directory: $InstallPath" -ForegroundColor Cyan

    # Create installation directory
    if (-not (Test-Path $InstallPath)) {
        New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
        Write-Host '✅ Created installation directory' -ForegroundColor Green
    }

    # Change to installation directory
    Push-Location $InstallPath
    Write-Host '📂 Changed to installation directory' -ForegroundColor Green

    # Download the main AitherCore script
    $coreScriptUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero/main/aither-core/aither-core.ps1'
    $coreScriptPath = Join-Path $InstallPath 'aither-core.ps1'

    Write-Host '⬇️  Downloading AitherCore script...' -ForegroundColor Yellow
    Invoke-WebRequest -Uri $coreScriptUrl -OutFile $coreScriptPath -UseBasicParsing
    Write-Host '✅ Downloaded AitherCore script' -ForegroundColor Green

    # Make sure we have PowerShell 7 if possible
    $pwshPath = Get-Command 'pwsh' -ErrorAction SilentlyContinue
    if ($pwshPath) {
        $powerShellCommand = 'pwsh'
        Write-Host '✅ Using PowerShell 7 (pwsh)' -ForegroundColor Green
    } else {
        $powerShellCommand = 'powershell'
        Write-Host '⚠️  Using Windows PowerShell 5.1 (consider installing PowerShell 7)' -ForegroundColor Yellow
    }

    if ($AutoStart) {
        Write-Host '🎯 Starting AitherCore...' -ForegroundColor Green
        Write-Host '   You can also run this manually later with:' -ForegroundColor Gray
        Write-Host "   cd '$InstallPath' && $powerShellCommand -File aither-core.ps1" -ForegroundColor Gray
        Write-Host ''

        # Start AitherCore
        & $powerShellCommand -File $coreScriptPath
    } else {
        Write-Host '✅ Bootstrap complete! To start AitherCore, run:' -ForegroundColor Green
        Write-Host "   cd '$InstallPath'" -ForegroundColor Cyan
        Write-Host "   $powerShellCommand -File aither-core.ps1" -ForegroundColor Cyan
    }

} catch {
    Write-Host "❌ Bootstrap failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '📧 If you need help, create an issue at: https://github.com/wizzense/AitherZero/issues' -ForegroundColor Yellow
    exit 1
} finally {
    Pop-Location -ErrorAction SilentlyContinue
}

Write-Host '🎉 AitherZero Super Simple Bootstrap Complete!' -ForegroundColor Green
