#Requires -Version 7.0

<#
.SYNOPSIS
    One-command setup for OpenTofu Lab Automation environment
    
.DESCRIPTION
    Quickly sets up the development environment with all required modules and environment variables.
    This is a simplified version that focuses on the essentials.
    
.EXAMPLE
    .\Quick-Setup.ps1
    
.EXAMPLE
    .\Quick-Setup.ps1 -ImportAllModules
#>

[CmdletBinding()]
param(
    [switch]$ImportAllModules
)

Write-Host "🚀 Setting up OpenTofu Lab Automation environment..." -ForegroundColor Cyan

# Set environment variables
$env:PROJECT_ROOT = (Get-Location).Path
$env:PWSH_MODULES_PATH = "$env:PROJECT_ROOT/aither-core/modules"

Write-Host "✓ Environment variables configured" -ForegroundColor Green
Write-Host "  PROJECT_ROOT: $env:PROJECT_ROOT"
Write-Host "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH"

# Import essential modules
$essentialModules = @('Logging', 'PatchManager')
if ($ImportAllModules) {
    $essentialModules = Get-ChildItem "$env:PWSH_MODULES_PATH" -Directory | Select-Object -ExpandProperty Name
}

Write-Host "📦 Importing modules..." -ForegroundColor Cyan

# Use the Preload-Modules script for consistent setup
& "$env:PROJECT_ROOT/core-runner/Preload-Modules.ps1"

Write-Host "`n🎉 Setup complete! You can now use:" -ForegroundColor Green
Write-Host "  Import-Module PatchManager -Force" -ForegroundColor Cyan
Write-Host "  Import-Module BackupManager -Force" -ForegroundColor Cyan
Write-Host "  Or any other module without explicit paths!" -ForegroundColor Cyan
