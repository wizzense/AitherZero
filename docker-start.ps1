#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Simplified Docker container startup script for AitherZero

.DESCRIPTION
    This script handles the quirks of running AitherZero in a container:
    - Ensures we're in the correct directory (/opt/aitherzero)
    - Properly imports and initializes the module
    - Provides an interactive PowerShell session with AitherZero ready to use
    - Automatically runs Start-AitherZero if needed

.PARAMETER Interactive
    Start an interactive PowerShell session (default)

.PARAMETER Command
    Execute a specific command instead of starting interactive session

.EXAMPLE
    docker exec -it aitherzero-pr-1634 pwsh /opt/aitherzero/docker-start.ps1
    
.EXAMPLE
    docker exec aitherzero-pr-1634 pwsh /opt/aitherzero/docker-start.ps1 -Command "./az.ps1 0402"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Command = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Interactive
)

# Always work from the AitherZero installation directory
Set-Location /opt/aitherzero

# Ensure module is loaded
if (-not (Get-Module -Name AitherZero)) {
    Write-Host "📦 Loading AitherZero module..." -ForegroundColor Cyan
    Import-Module ./AitherZero.psd1 -Force -WarningAction SilentlyContinue
    
    # Wait a moment for module to fully initialize
    Start-Sleep -Milliseconds 500
}

# If a command was provided, execute it
if (-not [string]::IsNullOrWhiteSpace($Command)) {
    Write-Host "🚀 Executing: $Command" -ForegroundColor Cyan
    Invoke-Expression $Command
    exit $LASTEXITCODE
}

# Interactive mode - show welcome and start shell
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    🚀 AitherZero Container                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ AitherZero is ready to use!" -ForegroundColor Green
Write-Host ""
Write-Host "📍 You are in: " -NoNewline -ForegroundColor Gray
Write-Host "/opt/aitherzero" -ForegroundColor White
Write-Host ""
Write-Host "💡 Quick commands:" -ForegroundColor Cyan
Write-Host "   Start-AitherZero           - Launch interactive menu" -ForegroundColor Gray
Write-Host "   az 0402                    - Run unit tests" -ForegroundColor Gray
Write-Host "   az 0510                    - Generate project report" -ForegroundColor Gray
Write-Host "   ./Start-AitherZero.ps1 -Mode List" -ForegroundColor Gray
Write-Host "                              - List available scripts" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 Type 'Get-Command -Module AitherZero' to see all available commands" -ForegroundColor Yellow
Write-Host ""

# Start interactive PowerShell session
# Use a minimal prompt and stay in this directory
$Host.UI.RawUI.WindowTitle = "AitherZero Container"

# Keep the session alive
Write-Host "Press Ctrl+C to exit or type 'exit' to close." -ForegroundColor Gray
Write-Host ""

# Run pwsh interactively
# The user will be in an interactive PowerShell session with AitherZero loaded
pwsh -NoLogo -NoExit -WorkingDirectory /opt/aitherzero
