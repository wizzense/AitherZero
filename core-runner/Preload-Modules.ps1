#Requires -Version 7.0

<#
.SYNOPSIS
    Preload all project modules with proper environment setup
    
.DESCRIPTION
    This script sets up the environment and imports all modules from the core-runner/modules
    directory. It provides a simple way to avoid using explicit module paths.
#>

# Ensure PROJECT_ROOT is set
if (-not $env:PROJECT_ROOT) {
    $env:PROJECT_ROOT = (Get-Location).Path
    Write-Host "Setting PROJECT_ROOT to $(Get-Location)" -ForegroundColor Yellow
}

# Set PWSH_MODULES_PATH
$env:PWSH_MODULES_PATH = "$env:PROJECT_ROOT/core-runner/modules"

Write-Host "Environment setup:" -ForegroundColor Cyan
Write-Host "  PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor Gray
Write-Host "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor Gray

# Add the modules path to PSModulePath if not already there
if ($env:PSModulePath -notlike "*$env:PWSH_MODULES_PATH*") {
    $env:PSModulePath = "$env:PWSH_MODULES_PATH;$env:PSModulePath"
    Write-Host "✓ Added modules path to PSModulePath" -ForegroundColor Green
}

# Import all modules using standard Import-Module with direct paths
Write-Host "`nImporting all project modules..." -ForegroundColor Cyan
Get-ChildItem -Path "$env:PWSH_MODULES_PATH" -Directory | ForEach-Object {
    $modulePath = $_.FullName
    $moduleName = $_.Name
    
    try {
        Import-Module $modulePath -Force
        Write-Host "  ✓ $moduleName" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠ $moduleName - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Module preloading complete!" -ForegroundColor Green
Write-Host "You can now use modules without explicit paths:" -ForegroundColor Cyan
Write-Host "  Import-Module PatchManager -Force" -ForegroundColor Gray
Write-Host "  Import-Module BackupManager -Force" -ForegroundColor Gray
Write-Host "  Import-Module DevEnvironment -Force" -ForegroundColor Gray
