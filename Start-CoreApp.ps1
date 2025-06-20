<#
.SYNOPSIS
    Quick starter script for OpenTofu Lab Automation CoreApp

.DESCRIPTION
    Imports and initializes the CoreApp module for immediate use.
    This script provides a simple way to relaunch the CoreApp environment
    after the initial bootstrap. Works from the project directory.

.PARAMETER Force
    Force reimport of modules even if already loaded

.PARAMETER RequiredOnly
    Import only required modules

.EXAMPLE
    .\Start-CoreApp.ps1

.EXAMPLE
    .\Start-CoreApp.ps1 -Force

.NOTES
    Alternative: Use .\Relaunch-CoreApp.ps1 for a more comprehensive relaunch.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$RequiredOnly
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting OpenTofu Lab Automation CoreApp..." -ForegroundColor Cyan

    # Import CoreApp module
    $coreAppPath = Join-Path $PSScriptRoot "aither-core/CoreApp.psm1"

    if (-not (Test-Path $coreAppPath)) {
        throw "CoreApp module not found at: $coreAppPath"
    }

    Import-Module $coreAppPath -Force:$Force -Verbose:$VerbosePreference
    Write-Host "✅ CoreApp module imported" -ForegroundColor Green

    # Initialize the ecosystem
    $result = Initialize-CoreApplication -RequiredOnly:$RequiredOnly -Force:$Force

    if ($result) {
        Write-Host "✅ CoreApp ecosystem initialized successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎯 Available CoreApp Functions:" -ForegroundColor Yellow
        Write-Host "  • Get-CoreModuleStatus      - Check module status"
        Write-Host "  • Get-PlatformInfo          - Get platform information"
        Write-Host "  • Test-CoreApplicationHealth - Run health check"
        Write-Host "  • Start-DevEnvironmentSetup - Setup development environment"
        Write-Host "  • Invoke-UnifiedMaintenance - Run maintenance tasks"
        Write-Host ""
        Write-Host "📊 Module Status:" -ForegroundColor Yellow
        Get-CoreModuleStatus | ForEach-Object {
            $status = if ($_.Loaded) { "✅" } else { "⚠️" }
            $required = if ($_.Required) { "(Required)" } else { "(Optional)" }
            Write-Host "  $status $($_.Name) $required - $($_.Description)"
        }
        Write-Host ""
        Write-Host "🎉 CoreApp is ready to use!" -ForegroundColor Green
    } else {
        Write-Warning "CoreApp initialization completed with issues"
    }

} catch {
    Write-Error "Failed to start CoreApp: $($_.Exception.Message)"
    exit 1
}
