#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Container welcome script for AitherZero
.DESCRIPTION
    Displays a welcome message and loads the AitherZero module when the container starts.
    This script is called by the Dockerfile CMD.
    In detached mode, it keeps the container running with an infinite sleep.
#>

$ErrorActionPreference = 'Continue'

# Import the AitherZero module
Import-Module /opt/aitherzero/AitherZero.psd1 -WarningAction SilentlyContinue

# Display welcome message
Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║                    🚀 AitherZero Container                   ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''
Write-Host '✅ AitherZero loaded. Type Start-AitherZero to begin.' -ForegroundColor Green
Write-Host ''
Write-Host '💡 Quick commands:' -ForegroundColor Cyan
Write-Host '   Start-AitherZero           - Launch interactive menu' -ForegroundColor Gray
Write-Host '   az 0402                    - Run unit tests' -ForegroundColor Gray
Write-Host '   az 0510                    - Generate project report' -ForegroundColor Gray
Write-Host ''
Write-Host '📍 Working directory: /opt/aitherzero' -ForegroundColor Gray
Write-Host '📚 Type Get-Command -Module AitherZero for all commands' -ForegroundColor Gray
Write-Host ''

# Keep container alive when running in detached mode
# This prevents the container from exiting and restarting
# The sleep loop will be interrupted if the user runs commands via docker exec
while ($true) {
    Start-Sleep -Seconds 3600
}
