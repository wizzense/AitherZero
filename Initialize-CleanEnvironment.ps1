#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Clean environment initializer for AitherZero
.DESCRIPTION
    Ensures a clean PowerShell environment before loading AitherZero modules
.PARAMETER Force
    Force reload even if already initialized
#>
[CmdletBinding()]
param(
    [switch]$Force
)

# Clear any conflicting modules - EXPANDED LIST
$conflictingModules = @(
    'AitherRun',
    'CoreApp',
    'ConfigurationManager',
    'SecurityAutomation',
    'UtilityServices',
    'ConfigurationCore',
    'ConfigurationCarousel',
    'ModuleCommunication',
    'ConfigurationRepository',
    'StartupExperience',
    'LabRunner',
    'OpenTofuProvider',
    'PSScriptAnalyzerIntegration',
    'SemanticVersioning',
    'LicenseManager'
)

Write-Host "🔧 Cleaning PowerShell environment..." -ForegroundColor Cyan

# Remove conflicting modules
foreach ($module in $conflictingModules) {
    if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
        Write-Host "  Removing conflicting module: $module" -ForegroundColor Yellow
        Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
    }
}

# Clean PSModulePath of any conflicting references
if ($env:PSModulePath) {
    $cleanPaths = $env:PSModulePath -split [IO.Path]::PathSeparator | 
        Where-Object { 
            $_ -notlike "*Aitherium*" -and 
            $_ -notlike "*AitherRun*" -and
            $_ -notlike "*aither-core*" -and
            $_ -notlike "*CoreApp*"
        }
    $env:PSModulePath = $cleanPaths -join [IO.Path]::PathSeparator
}

# Also clean PATH
if ($env:PATH) {
    $cleanPaths = $env:PATH -split [IO.Path]::PathSeparator | 
        Where-Object { 
            $_ -notlike "*aither-core*" -and
            $_ -notlike "*Aitherium*"
        }
    $env:PATH = $cleanPaths -join [IO.Path]::PathSeparator
}

# Set AitherZero root
$script:ProjectRoot = $PSScriptRoot
$env:AITHERZERO_ROOT = $script:ProjectRoot

# Clean any lingering environment variables
@('AITHERIUM_ROOT', 'AITHERRUN_ROOT', 'COREAPP_ROOT', 'AITHER_CORE_PATH', 'PWSH_MODULES_PATH') | ForEach-Object {
    Remove-Item "env:$_" -ErrorAction SilentlyContinue
}

# Set flags to prevent auto-loading
$env:DISABLE_COREAPP = "1"
$env:SKIP_AUTO_MODULES = "1"
$env:AITHERZERO_ONLY = "1"

Write-Host "✓ Environment cleaned" -ForegroundColor Green

# Now load AitherZero
Write-Host "📦 Loading AitherZero modules..." -ForegroundColor Cyan

try {
    # Import the module manifest
    Import-Module (Join-Path $script:ProjectRoot "AitherZero.psd1") -Force -Global
    
    Write-Host "✓ AitherZero environment loaded successfully" -ForegroundColor Green
    
    # Show loaded modules
    $loadedModules = Get-Module | Where-Object { $_.Path -like "*$script:ProjectRoot*" }
    Write-Host "  Loaded $($loadedModules.Count) modules" -ForegroundColor Gray
    
    # Verify critical functions
    $criticalFunctions = @(
        'Write-CustomLog',
        'Show-UIMenu',
        'Invoke-OrchestrationSequence'
    )
    
    $missingFunctions = @()
    foreach ($func in $criticalFunctions) {
        if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
            $missingFunctions += $func
        }
    }
    
    if ($missingFunctions.Count -gt 0) {
        Write-Warning "Some functions are missing: $($missingFunctions -join ', ')"
        Write-Host "Try running: ./Initialize-AitherEnvironment.ps1" -ForegroundColor Yellow
    } else {
        Write-Host "✓ All critical functions available" -ForegroundColor Green
    }
    
    # Set aliases
    Set-Alias -Name 'az' -Value (Join-Path $script:ProjectRoot 'az.ps1') -Scope Global -Force
    Set-Alias -Name 'seq' -Value 'Invoke-OrchestrationSequence' -Scope Global -Force
    
    Write-Host "`n🚀 AitherZero is ready!" -ForegroundColor Cyan
    Write-Host "  Use 'az <number>' to run automation scripts" -ForegroundColor Gray
    Write-Host "  Use './Start-AitherZero.ps1' for interactive menu" -ForegroundColor Gray
    
} catch {
    Write-Error "Failed to load AitherZero: $_"
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Ensure you're in PowerShell 7+" -ForegroundColor Gray
    Write-Host "  2. Check that all module files exist in ./domains/" -ForegroundColor Gray
    Write-Host "  3. Try: Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process" -ForegroundColor Gray
    exit 1
}