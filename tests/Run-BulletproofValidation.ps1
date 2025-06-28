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
    [int]$MaxParallelJobs = 4,

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [switch]$EnforceCoverageThresholds
)

Write-Host '🛡️ Bulletproof Validation - Enhanced with Parallel Execution' -ForegroundColor Cyan
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
    # Ensure environment variables are set
    if (-not $env:PROJECT_ROOT) {
        $env:PROJECT_ROOT = $projectRoot
    }
    if (-not $env:PWSH_MODULES_PATH) {
        $env:PWSH_MODULES_PATH = Join-Path $projectRoot 'aither-core/modules'
    }
    
    Write-Host "Module path: $env:PWSH_MODULES_PATH" -ForegroundColor Yellow
    
    if (Test-Path $env:PWSH_MODULES_PATH) {
        Import-Module "$env:PWSH_MODULES_PATH/Logging" -Force -ErrorAction Stop
        Import-Module "$env:PWSH_MODULES_PATH/ParallelExecution" -Force -ErrorAction Stop
        Write-Host '✅ Required modules loaded successfully' -ForegroundColor Green
    } else {
        throw "Module path does not exist: $env:PWSH_MODULES_PATH"
    }
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

# Configure code coverage if enabled
if ($CodeCoverage) {
    Write-Host '📊 Enabling code coverage analysis...' -ForegroundColor Cyan
    
    # Set coverage paths based on validation level
    $coveragePaths = switch ($ValidationLevel) {
        'Quick' {
            @(
                Join-Path $projectRoot 'aither-core/modules/Logging/*.ps1',
                Join-Path $projectRoot 'aither-core/modules/LabRunner/*.ps1',
                Join-Path $projectRoot 'aither-core/modules/BackupManager/*.ps1'
            )
        }
        'Standard' {
            @(
                Join-Path $projectRoot 'aither-core/modules/*/*.ps1',
                Join-Path $projectRoot 'aither-core/modules/*/*.psm1'
            )
        }
        'Complete' {
            @(
                Join-Path $projectRoot 'aither-core/*.ps1',
                Join-Path $projectRoot 'aither-core/*.psm1',
                Join-Path $projectRoot 'aither-core/modules/*/*.ps1',
                Join-Path $projectRoot 'aither-core/modules/*/*.psm1',
                Join-Path $projectRoot 'aither-core/shared/*.ps1'
            )
        }
    }
    
    $config.CodeCoverage = @{
        Enabled = $true
        Path = $coveragePaths
        OutputFormat = if ($CI) { 'JaCoCo' } else { 'CoverageGutters' }
        OutputPath = Join-Path $projectRoot "tests/results/bulletproof-coverage.$($config.CodeCoverage.OutputFormat.ToLower())"
        OutputEncoding = 'UTF8'
        ExcludeTests = $true
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
        CoveragePercentTarget = 80
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
        Write-Host '🚀 Executing tests sequentially...' -ForegroundColor Cyan
        
        # Create proper Pester configuration
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $config.Run.Path
        $pesterConfig.Run.PassThru = $config.Run.PassThru
        $pesterConfig.Output.Verbosity = $config.Output.Verbosity
        $pesterConfig.Should.ErrorAction = $config.Should.ErrorAction
        
        # Add code coverage if configured
        if ($config.CodeCoverage) {
            $pesterConfig.CodeCoverage.Enabled = $config.CodeCoverage.Enabled
            $pesterConfig.CodeCoverage.Path = $config.CodeCoverage.Path
            $pesterConfig.CodeCoverage.OutputFormat = $config.CodeCoverage.OutputFormat
            $pesterConfig.CodeCoverage.OutputPath = $config.CodeCoverage.OutputPath
            $pesterConfig.CodeCoverage.OutputEncoding = $config.CodeCoverage.OutputEncoding
            $pesterConfig.CodeCoverage.ExcludeTests = $config.CodeCoverage.ExcludeTests
            $pesterConfig.CodeCoverage.UseBreakpoints = $config.CodeCoverage.UseBreakpoints
            $pesterConfig.CodeCoverage.SingleHitBreakpoints = $config.CodeCoverage.SingleHitBreakpoints
        }
        
        $result = Invoke-Pester -Configuration $pesterConfig
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    Write-Host ''
    Write-Host "📊 Test Results (completed in $([math]::Round($duration, 2))s):" -ForegroundColor White
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor Red
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Total: $($result.TotalCount)" -ForegroundColor White
    
    # Display code coverage results if enabled
    if ($CodeCoverage -and $result.CodeCoverage) {
        $coverage = $result.CodeCoverage
        $coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) {
            [Math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2)
        } else { 0 }
        
        Write-Host ''
        Write-Host '📊 Code Coverage Results:' -ForegroundColor Cyan
        Write-Host "  Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' })
        Write-Host "  Commands Analyzed: $($coverage.NumberOfCommandsAnalyzed)" -ForegroundColor White
        Write-Host "  Commands Executed: $($coverage.NumberOfCommandsExecuted)" -ForegroundColor White
        Write-Host "  Commands Missed: $($coverage.NumberOfCommandsAnalyzed - $coverage.NumberOfCommandsExecuted)" -ForegroundColor White
        Write-Host "  Report: $($config.CodeCoverage.OutputPath)" -ForegroundColor Gray
        
        # Enforce coverage thresholds if requested
        if ($EnforceCoverageThresholds -and $coveragePercent -lt 80) {
            Write-Host ''
            Write-Host "❌ COVERAGE THRESHOLD NOT MET - Required: 80%, Actual: $coveragePercent%" -ForegroundColor Red
            exit 1
        }
    }

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

