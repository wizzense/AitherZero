#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize AitherZero environment - backward compatibility wrapper
.DESCRIPTION
    This script is maintained for backward compatibility.
    It now imports the AitherZero module using the PowerShell
    module manifest (AitherZero.psd1).
.PARAMETER Persistent
    Make environment changes persistent in PowerShell profile
.PARAMETER Force
    Force reload of all modules even if already initialized
.PARAMETER Silent
    Suppress output messages for use in scripts
#>

[CmdletBinding()]
param(
    [switch]$Persistent,
    [switch]$Force,
    [switch]$Silent
)

# Import the AitherZero module using the manifest
$moduleManifest = Join-Path $PSScriptRoot "AitherZero.psd1"

if (Test-Path $moduleManifest) {
    if (-not $Silent) {
        Import-Module $moduleManifest -Force:$Force -Global
    } else {
        Import-Module $moduleManifest -Force:$Force -Global | Out-Null
    }
    
    # Handle persistent flag manually if needed
    if ($Persistent -and -not $Silent) {
        Write-Host "Note: Use bootstrap.ps1 for persistent installation" -ForegroundColor Yellow
    }
} else {
    if (-not $Silent) {
        Write-Error "AitherZero.psd1 not found at: $moduleManifest"
    }
    exit 1
}