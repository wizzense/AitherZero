#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Migration wrapper for AitherZero Unified Test Runner
    
.DESCRIPTION
    This script provides a migration path from the legacy test runners to the new unified system.
    It maintains backward compatibility while providing enhanced functionality.
    
    Legacy Compatibility:
    - Run-Tests.ps1 parameters and behavior
    - Run-CI-Tests.ps1 optimizations
    - Run-Installation-Tests.ps1 profile testing
    
    Enhanced Features:
    - Sub-30-second execution for Quick tests
    - Comprehensive CI/CD dashboard reporting
    - Full audit trail and compliance
    - Parallel execution optimization
    - Real-time progress tracking
    
.PARAMETER Quick
    Run quick tests (maps to TestSuite=Quick)
    
.PARAMETER Setup
    Run setup tests (maps to TestSuite=Setup)
    
.PARAMETER All
    Run all tests (maps to TestSuite=All)
    
.PARAMETER CI
    Run in CI mode with optimizations
    
.PARAMETER Distributed
    Use distributed testing framework
    
.PARAMETER Installation
    Run installation tests (maps to TestSuite=Installation)
    
.PARAMETER Modules
    Test specific modules only
    
.PARAMETER MaxParallelJobs
    Maximum parallel jobs (default: 4)
    
.PARAMETER TimeoutMinutes
    Test timeout in minutes (default: 30)
    
.PARAMETER Verbose
    Enable verbose output
    
.PARAMETER ShowProgress
    Show progress indicators
    
.PARAMETER FailFast
    Stop on first failure
    
.PARAMETER Profile
    Installation profile to test
    
.PARAMETER Platform
    Platform-specific testing
    
.PARAMETER OutputFormat
    Output format (Console, JUnit, JSON, HTML, All)
    
.PARAMETER Performance
    Enable performance optimizations
    
.PARAMETER GenerateDashboard
    Generate HTML dashboard
    
.PARAMETER WhatIf
    Show what would be run
    
.EXAMPLE
    ./tests/Run-Tests-Unified.ps1
    # Quick test run (~30 seconds)
    
.EXAMPLE
    ./tests/Run-Tests-Unified.ps1 -Quick
    # Same as above - explicit quick mode
    
.EXAMPLE
    ./tests/Run-Tests-Unified.ps1 -All -CI
    # Full CI test run with reporting
    
.EXAMPLE
    ./tests/Run-Tests-Unified.ps1 -Setup
    # Setup/installation validation
    
.EXAMPLE
    ./tests/Run-Tests-Unified.ps1 -Installation -Profile developer
    # Test developer installation profile
    
.NOTES
    This wrapper maintains backward compatibility while providing unified functionality
#>

[CmdletBinding()]
param(
    # Legacy Run-Tests.ps1 parameters
    [switch]$Quick,
    [switch]$Setup,
    [switch]$All,
    [switch]$CI,
    [switch]$Distributed,
    [switch]$Installation,
    [string[]]$Modules = @(),
    [int]$MaxParallelJobs = 4,
    [int]$TimeoutMinutes = 30,
    [switch]$Verbose,
    [switch]$ShowProgress,
    [switch]$FailFast,
    
    # Legacy Run-Installation-Tests.ps1 parameters
    [ValidateSet('minimal', 'developer', 'full', 'all')]
    [string]$Profile = 'all',
    
    [ValidateSet('Windows', 'Linux', 'macOS', 'Current', 'All')]
    [string]$Platform = 'Current',
    
    # Legacy Run-CI-Tests.ps1 parameters
    [ValidateSet('Console', 'JUnit', 'JSON', 'HTML', 'All')]
    [string]$OutputFormat = 'Console',
    
    [switch]$Performance,
    
    # New unified parameters
    [switch]$GenerateDashboard,
    [switch]$WhatIf
)

# Migration logic to determine test suite
function Get-TestSuite {
    if ($Quick) { return 'Quick' }
    if ($Setup) { return 'Setup' }
    if ($Installation) { return 'Installation' }
    if ($All) { return 'All' }
    if ($CI) { return 'CI' }
    
    # Default to Quick for fast execution
    return 'Quick'
}

# Show migration notice
function Show-MigrationNotice {
    Write-Host ""
    Write-Host "🔄 AitherZero Test Migration Notice" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Using unified test runner with backward compatibility" -ForegroundColor Yellow
    Write-Host "Legacy parameters have been mapped to new unified system" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Migration Benefits:" -ForegroundColor Green
    Write-Host "  ✅ Sub-30-second execution for Quick tests" -ForegroundColor Green
    Write-Host "  ✅ Enhanced CI/CD dashboard reporting" -ForegroundColor Green
    Write-Host "  ✅ Comprehensive audit trail" -ForegroundColor Green
    Write-Host "  ✅ Parallel execution optimization" -ForegroundColor Green
    Write-Host "  ✅ Real-time progress tracking" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Legacy Command Equivalents:" -ForegroundColor Cyan
    Write-Host "  ./tests/Run-Tests.ps1           → ./tests/Run-Tests-Unified.ps1" -ForegroundColor Gray
    Write-Host "  ./tests/Run-Tests.ps1 -Quick    → ./tests/Run-Tests-Unified.ps1 -Quick" -ForegroundColor Gray
    Write-Host "  ./tests/Run-Tests.ps1 -All      → ./tests/Run-Tests-Unified.ps1 -All" -ForegroundColor Gray
    Write-Host "  ./tests/Run-CI-Tests.ps1        → ./tests/Run-Tests-Unified.ps1 -CI" -ForegroundColor Gray
    Write-Host "  ./tests/Run-Installation-Tests.ps1 → ./tests/Run-Tests-Unified.ps1 -Installation" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
try {
    # Show migration notice
    Show-MigrationNotice
    
    # Determine test suite
    $testSuite = Get-TestSuite
    
    # Build parameter set for unified runner
    $unifiedParams = @{
        TestSuite = $testSuite
        Profile = $Profile
        Platform = $Platform
        OutputFormat = $OutputFormat
        MaxParallelJobs = $MaxParallelJobs
        TimeoutMinutes = $TimeoutMinutes
    }
    
    # Add switches
    if ($CI) { $unifiedParams['CI'] = $true }
    if ($Distributed) { $unifiedParams['Distributed'] = $true }
    if ($Verbose) { $unifiedParams['Verbose'] = $true }
    if ($ShowProgress) { $unifiedParams['ShowProgress'] = $true }
    if ($FailFast) { $unifiedParams['FailFast'] = $true }
    if ($Performance) { $unifiedParams['Performance'] = $true }
    if ($GenerateDashboard) { $unifiedParams['GenerateDashboard'] = $true }
    if ($WhatIf) { $unifiedParams['WhatIf'] = $true }
    
    # Add modules if specified
    if ($Modules.Count -gt 0) {
        $unifiedParams['Modules'] = $Modules
    }
    
    # For CI mode, enable dashboard and comprehensive reporting
    if ($CI) {
        $unifiedParams['GenerateDashboard'] = $true
        $unifiedParams['UpdateReadme'] = $true
        if ($OutputFormat -eq 'Console') {
            $unifiedParams['OutputFormat'] = 'All'
        }
    }
    
    # Show what we're about to run
    Write-Host "🚀 Executing Unified Test Runner" -ForegroundColor Green
    Write-Host "Test Suite: $testSuite" -ForegroundColor Cyan
    Write-Host "Configuration:" -ForegroundColor Cyan
    foreach ($param in $unifiedParams.GetEnumerator()) {
        Write-Host "  $($param.Key): $($param.Value)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Execute unified test runner
    $unifiedRunnerPath = Join-Path $PSScriptRoot "Run-UnifiedTests.ps1"
    
    if (Test-Path $unifiedRunnerPath) {
        & $unifiedRunnerPath @unifiedParams
        $exitCode = $LASTEXITCODE
    } else {
        Write-Host "❌ Unified test runner not found: $unifiedRunnerPath" -ForegroundColor Red
        Write-Host "Falling back to legacy test runner..." -ForegroundColor Yellow
        
        # Fallback to legacy runner
        $legacyRunnerPath = Join-Path $PSScriptRoot "Run-Tests.ps1"
        if (Test-Path $legacyRunnerPath) {
            & $legacyRunnerPath @PSBoundParameters
            $exitCode = $LASTEXITCODE
        } else {
            Write-Host "❌ Legacy test runner not found: $legacyRunnerPath" -ForegroundColor Red
            exit 1
        }
    }
    
    exit $exitCode
    
} catch {
    Write-Host "❌ Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}