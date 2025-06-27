#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced Bulletproof Validation with Parallel Execution Support

.DESCRIPTION
    This script runs the actual Pester test suite with enhanced parallel execution capabilities
    to provide fast, reliable validation of the AitherZero infrastructure automation framework.

.PARAMETER ValidationLevel
    The level of validation to run: Quick, Standard, or Complete

.PARAMETER FailFast
    Stop execution on first test failure

.PARAMETER CI
    Optimize output for CI/CD environments

.PARAMETER MaxParallelJobs
    Maximum number of parallel jobs for test execution (default: 4)

.EXAMPLE
    .\Run-BulletproofValidation.ps1 -ValidationLevel Quick

.EXAMPLE
    .\Run-BulletproofValidation.ps1 -ValidationLevel Standard -MaxParallelJobs 6

.EXAMPLE
    .\Run-BulletproofValidation.ps1 -ValidationLevel Complete -CI -FailFast

.NOTES
    This replaces the previous basic validation with comprehensive Pester test execution
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Quick', 'Standard', 'Complete')]
    [string]$ValidationLevel = 'Standard',

    [Parameter()]
    [switch]$FailFast,

    [Parameter()]
    [switch]$CI,

    [Parameter()]
    [int]$MaxParallelJobs = 4
)

Write-Host '� Bulletproof Validation - Enhanced with Parallel Execution' -ForegroundColor Cyan
Write-Host "Validation Level: $ValidationLevel | Max Parallel Jobs: $MaxParallelJobs" -ForegroundColor Yellow

# Initialize environment
$ErrorActionPreference = 'Stop'
$startTime = Get-Date

# Find project root with enhanced logic for CI/CD environments
if (Test-Path "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1") {
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot

    # Validate that we found the correct project root for AitherZero
    if (-not (Test-Path (Join-Path $projectRoot 'aither-core/modules'))) {
        Write-Host '⚠️ Find-ProjectRoot found wrong directory, using fallback detection...' -ForegroundColor Yellow
        $projectRoot = $null
    }
} else {
    $projectRoot = $null
}

# Fallback project root detection
if (-not $projectRoot) {
    # Start from script location and work upward
    $projectRoot = $PSScriptRoot
    while ($projectRoot -and -not (Test-Path (Join-Path $projectRoot 'aither-core'))) {
        $projectRoot = Split-Path $projectRoot -Parent
        # Prevent infinite loop at filesystem root
        if ($projectRoot -eq (Split-Path $projectRoot -Parent)) {
            break
        }
    }

    # If still not found, use script parent as last resort
    if (-not $projectRoot -or -not (Test-Path (Join-Path $projectRoot 'aither-core'))) {
        $projectRoot = Split-Path $PSScriptRoot -Parent
    }
}

Write-Host "Using project root: $projectRoot" -ForegroundColor Cyan

# Import required modules
try {
    Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction Stop
    Import-Module "$projectRoot/aither-core/modules/ParallelExecution" -Force -ErrorAction Stop
    Write-Host '✅ Required modules loaded successfully' -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not load modules, proceeding with basic functionality: $($_.Exception.Message)" -ForegroundColor Yellow
}

$testPaths = switch ($ValidationLevel) {
    'Quick' {
        @(
            'tests/unit/modules/Logging',
            'tests/unit/modules/LabRunner',
            'tests/unit/modules/BackupManager'
        )
    }
    'Standard' {
        @(
            'tests/unit/modules',
            'tests/unit/scripts'
        )
    }
    'Complete' {
        @(
            'tests/unit',
            'tests/integration'
        )
    }
}

$config = @{
    Run    = @{
        Path     = $testPaths
        PassThru = $true
    }
    Output = @{
        Verbosity = if ($CI) { 'Normal' } else { 'Detailed' }
    }
    Should = @{
        ErrorAction = if ($FailFast) { 'Stop' } else { 'Continue' }
    }
}

# Configure parallel execution for Pester if we have multiple test paths
if ($testPaths.Count -gt 1 -and $MaxParallelJobs -gt 1) {
    Write-Host '🔄 Configuring parallel test execution...' -ForegroundColor Cyan

    # Split test paths into parallel jobs
    $testJobs = @()
    for ($i = 0; $i -lt $testPaths.Count; $i += [Math]::Max(1, [Math]::Floor($testPaths.Count / $MaxParallelJobs))) {
        $jobPaths = $testPaths[$i..($i + [Math]::Max(1, [Math]::Floor($testPaths.Count / $MaxParallelJobs)) - 1)]
        $testJobs += , @($jobPaths | Where-Object { $_ })
    }

    Write-Host "📊 Split $($testPaths.Count) test paths into $($testJobs.Count) parallel jobs" -ForegroundColor Yellow
}

try {
    if ($testPaths.Count -gt 1 -and $MaxParallelJobs -gt 1 -and (Get-Command 'Invoke-ParallelOperation' -ErrorAction SilentlyContinue)) {
        Write-Host '🚀 Executing tests in parallel...' -ForegroundColor Cyan

        # Create parallel test operations
        $operations = foreach ($jobPaths in $testJobs) {
            {
                param($TestPaths)
                $config = @{
                    Run    = @{ Path = $TestPaths; PassThru = $true }
                    Output = @{ Verbosity = 'Normal' }
                }
                Invoke-Pester -Configuration $config
            }
        }

        # Execute parallel operations
        $parallelResults = Invoke-ParallelOperation -Operations $operations -MaxParallelJobs $MaxParallelJobs

        # Aggregate results
        $result = @{
            PassedCount  = ($parallelResults | ForEach-Object { $_.PassedCount } | Measure-Object -Sum).Sum
            FailedCount  = ($parallelResults | ForEach-Object { $_.FailedCount } | Measure-Object -Sum).Sum
            SkippedCount = ($parallelResults | ForEach-Object { $_.SkippedCount } | Measure-Object -Sum).Sum
            TotalCount   = ($parallelResults | ForEach-Object { $_.TotalCount } | Measure-Object -Sum).Sum
        }

        Write-Host '✅ Parallel execution completed' -ForegroundColor Green
    } else {
        Write-Host '� Executing tests sequentially...' -ForegroundColor Cyan
        $result = Invoke-Pester -Configuration $config
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    Write-Host ''
    Write-Host "📊 Test Results (completed in $([math]::Round($duration, 2))s):" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor Red
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Total: $($result.TotalCount)" -ForegroundColor White

    if ($result.FailedCount -gt 0) {
        Write-Host ''
        Write-Host "❌ VALIDATION FAILED - $($result.FailedCount) test failures found" -ForegroundColor Red
        if ($CI) {
            Write-Host 'Fix these failures before merging.' -ForegroundColor Yellow
        }
        exit 1
    } else {
        Write-Host ''
        Write-Host '✅ All tests passed! System is healthy.' -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "💥 Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    exit 1
}
