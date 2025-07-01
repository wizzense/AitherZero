#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Claude command wrapper for enhanced testing infrastructure
.DESCRIPTION
    Provides CLI interface for AitherZero's enhanced testing capabilities with parallel execution,
    adaptive throttling, and comprehensive validation through Claude commands
.PARAMETER Action
    The testing action to perform (production, quick, module, validation, release, performance, monitor)
.PARAMETER Arguments
    Additional arguments passed from Claude command
#>

param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet("production", "quick", "module", "validation", "release", "performance", "monitor")]
    [string]$Action = "production",
    
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

# Cross-platform script location detection
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$projectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)

# Import required modules
try {
    . (Join-Path $projectRoot "aither-core/shared/Find-ProjectRoot.ps1")
    $projectRoot = Find-ProjectRoot
    
    # Import Logging module for consistent output
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging" 
    Import-Module $loggingPath -Force -ErrorAction SilentlyContinue
    
    # Import SystemMonitoring for resource detection
    $systemMonitoringPath = Join-Path $projectRoot "aither-core/modules/SystemMonitoring"
    Import-Module $systemMonitoringPath -Force -ErrorAction SilentlyContinue
    
    # Import ParallelExecution for parallel capabilities
    $parallelExecutionPath = Join-Path $projectRoot "aither-core/modules/ParallelExecution"
    Import-Module $parallelExecutionPath -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    exit 1
}

# Helper function for consistent logging
function Write-TestingLog {
    param($Message, $Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        $prefix = switch ($Level) {
            "ERROR" { "[ERROR]" }
            "WARN" { "[WARN]" }
            "SUCCESS" { "[SUCCESS]" }
            default { "[INFO]" }
        }
        Write-Host "$prefix $Message"
    }
}

# Execute the requested testing action
try {
    # Parse arguments inline
    $params = @{}
    $i = 0
    
    while ($i -lt $Arguments.Count) {
        $arg = $Arguments[$i]
        
        switch -Regex ($arg) {
            "^--suite$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.TestSuite = $Arguments[++$i]
                }
            }
            "^--parallel$" {
                $params.EnableParallel = $true
            }
            "^--throttling$" {
                $params.UseIntelligentThrottling = $true
            }
            "^--create-issues$" {
                $params.CreateIssues = $true
            }
            "^--html$" {
                $params.GenerateHTML = $true
            }
            "^--coverage$" {
                $params.ShowCoverage = $true
            }
            "^--ci$" {
                $params.CI = $true
            }
            "^--fail-fast$" {
                $params.FailFast = $true
            }
            "^--output-path$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.OutputPath = $Arguments[++$i]
                }
            }
            "^--dry-run$" {
                $params.DryRun = $true
            }
            "^--report-level$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.ReportLevel = $Arguments[++$i]
                }
            }
            "^--watch$" {
                $params.Watch = $true
            }
            "^--modules$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.Modules = $Arguments[++$i] -split ','
                }
            }
            "^--name$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.ModuleName = $Arguments[++$i]
                }
            }
            "^--integration$" {
                $params.IncludeIntegration = $true
            }
            "^--scope$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.ValidationScope = $Arguments[++$i]
                }
            }
            "^--parallel-optimization$" {
                $params.TestParallelOptimization = $true
            }
            "^--resource-detection$" {
                $params.ValidateResourceDetection = $true
            }
            "^--adaptive-throttling$" {
                $params.TestAdaptiveThrottling = $true
            }
            "^--generate-report$" {
                $params.GenerateReport = $true
            }
            "^--create-baselines$" {
                $params.CreateBaselines = $true
            }
            "^--parallel-stages$" {
                $params.UseParallelStages = $true
            }
            "^--performance-validation$" {
                $params.IncludePerformanceValidation = $true
            }
            "^--create-artifacts$" {
                $params.CreateArtifacts = $true
            }
            "^--workload$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.WorkloadType = $Arguments[++$i]
                }
            }
            "^--create-baseline$" {
                $params.CreateBaseline = $true
            }
            "^--sequential$" {
                $params.IncludeSequential = $true
            }
            "^--iterations$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.BaselineIterations = [int]$Arguments[++$i]
                }
            }
            "^--max-threads$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.MaxParallelThreads = [int]$Arguments[++$i]
                }
            }
            "^--export-format$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.ExportFormat = $Arguments[++$i]
                }
            }
            "^--interval$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.MonitoringInterval = [int]$Arguments[++$i]
                }
            }
            "^--duration$" {
                if ($i + 1 -lt $Arguments.Count) {
                    $params.MaxMonitoringDuration = [int]$Arguments[++$i]
                }
            }
            "^--pressure-callback$" {
                $params.EnablePressureCallback = $true
            }
            default {
                # If no flag prefix, treat as test suite or module name
                if (-not $params.TestSuite -and -not $params.ModuleName -and $arg -notmatch "^--") {
                    if ($Action -eq "module") {
                        $params.ModuleName = $arg
                    } else {
                        $params.TestSuite = $arg
                    }
                }
            }
        }
        $i++
    }
    
    switch ($Action) {
        "production" {
            Write-TestingLog "🚀 Executing enhanced production test suite..." -Level "INFO"
            
            # Set intelligent defaults
            if (-not $params.TestSuite) { $params.TestSuite = "Critical" }
            if (-not $params.ReportLevel) { $params.ReportLevel = "Standard" }
            if (-not $params.OutputPath) { $params.OutputPath = "./tests/TestResults" }
            
            # Build command path
            $testScript = Join-Path $projectRoot "tests/Run-ProductionTests.ps1"
            if (-not (Test-Path $testScript)) {
                Write-TestingLog "Production test script not found: $testScript" -Level "ERROR"
                exit 1
            }
            
            # Execute enhanced production tests
            Write-TestingLog "Test Suite: $($params.TestSuite)" -Level "INFO"
            Write-TestingLog "Parallel Execution: $($params.EnableParallel -eq $true)" -Level "INFO"
            Write-TestingLog "Intelligent Throttling: $($params.UseIntelligentThrottling -eq $true)" -Level "INFO"
            
            & $testScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestingLog "Enhanced production test suite completed successfully" -Level "SUCCESS"
            } else {
                Write-TestingLog "Production test suite failed with exit code: $LASTEXITCODE" -Level "ERROR"
                exit $LASTEXITCODE
            }
        }
        
        "quick" {
            Write-TestingLog "⚡ Executing quick tests with parallel optimization..." -Level "INFO"
            
            $testScript = Join-Path $projectRoot "tests/Invoke-QuickTests.ps1"
            if (-not (Test-Path $testScript)) {
                Write-TestingLog "Quick test script not found: $testScript" -Level "ERROR"
                exit 1
            }
            
            & $testScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestingLog "Quick tests completed successfully" -Level "SUCCESS"
            } else {
                Write-TestingLog "Quick tests failed with exit code: $LASTEXITCODE" -Level "ERROR"
                exit $LASTEXITCODE
            }
        }
        
        "module" {
            Write-TestingLog "🧩 Executing module-specific testing..." -Level "INFO"
            
            if (-not $params.ModuleName) {
                Write-TestingLog "Error: --name is required for module testing" -Level "ERROR"
                exit 1
            }
            
            $testScript = Join-Path $projectRoot "tests/Test-Module.ps1"
            if (-not (Test-Path $testScript)) {
                Write-TestingLog "Module test script not found: $testScript" -Level "ERROR"
                exit 1
            }
            
            Write-TestingLog "Testing module: $($params.ModuleName)" -Level "INFO"
            & $testScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestingLog "Module testing completed successfully" -Level "SUCCESS"
            } else {
                Write-TestingLog "Module testing failed with exit code: $LASTEXITCODE" -Level "ERROR"
                exit $LASTEXITCODE
            }
        }
        
        "validation" {
            Write-TestingLog "🔍 Executing infrastructure validation..." -Level "INFO"
            
            if (-not $params.ValidationScope) { $params.ValidationScope = "Standard" }
            
            $validationScript = Join-Path $projectRoot "tests/Validate-CompleteTestingInfrastructure.ps1"
            if (-not (Test-Path $validationScript)) {
                Write-TestingLog "Validation script not found: $validationScript" -Level "ERROR"
                exit 1
            }
            
            Write-TestingLog "Validation Scope: $($params.ValidationScope)" -Level "INFO"
            & $validationScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestingLog "Infrastructure validation completed successfully" -Level "SUCCESS"
            } else {
                Write-TestingLog "Infrastructure validation failed with exit code: $LASTEXITCODE" -Level "ERROR"
                exit $LASTEXITCODE
            }
        }
        
        "release" {
            Write-TestingLog "🚀 Executing release validation..." -Level "INFO"
            
            if (-not $params.ValidationScope) { $params.ValidationScope = "Standard" }
            
            $releaseScript = Join-Path $projectRoot "tests/Invoke-ReleaseValidation.ps1"
            if (-not (Test-Path $releaseScript)) {
                Write-TestingLog "Release validation script not found: $releaseScript" -Level "ERROR"
                exit 1
            }
            
            & $releaseScript @params
            
            if ($LASTEXITCODE -eq 0) {
                Write-TestingLog "Release validation completed successfully" -Level "SUCCESS"
            } else {
                Write-TestingLog "Release validation failed with exit code: $LASTEXITCODE" -Level "ERROR"
                exit $LASTEXITCODE
            }
        }
        
        "performance" {
            Write-TestingLog "📊 Executing performance baseline operations..." -Level "INFO"
            
            if (-not $params.WorkloadType) { $params.WorkloadType = "Test" }
            
            # Check if SystemMonitoring module is available
            if (-not (Get-Command New-ParallelExecutionBaseline -ErrorAction SilentlyContinue)) {
                Write-TestingLog "SystemMonitoring module not available for performance baselines" -Level "ERROR"
                exit 1
            }
            
            Write-TestingLog "Workload Type: $($params.WorkloadType)" -Level "INFO"
            
            try {
                $baseline = New-ParallelExecutionBaseline @params
                Write-TestingLog "Performance baseline created successfully" -Level "SUCCESS"
                
                if ($baseline.OptimalConfiguration) {
                    Write-TestingLog "Optimal Threads: $($baseline.OptimalConfiguration.OptimalThreads)" -Level "INFO"
                    Write-TestingLog "Performance Improvement: $($baseline.OptimalConfiguration.PerformanceImprovement)%" -Level "INFO"
                }
            } catch {
                Write-TestingLog "Performance baseline creation failed: $($_.Exception.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        "monitor" {
            Write-TestingLog "📈 Starting resource monitoring..." -Level "INFO"
            
            if (-not $params.MonitoringInterval) { $params.MonitoringInterval = 5 }
            if (-not $params.MaxMonitoringDuration) { $params.MaxMonitoringDuration = 60 }
            
            # Check if SystemMonitoring module is available
            if (-not (Get-Command Watch-SystemResourcePressure -ErrorAction SilentlyContinue)) {
                Write-TestingLog "SystemMonitoring module not available for resource monitoring" -Level "ERROR"
                exit 1
            }
            
            try {
                $monitoringResult = Watch-SystemResourcePressure @params
                Write-TestingLog "Resource monitoring completed successfully" -Level "SUCCESS"
                
                if ($params.GenerateReport) {
                    $report = Get-ResourcePressureReport -MonitoringData $monitoringResult -ReportType Summary
                    Write-TestingLog "Resource monitoring report generated" -Level "SUCCESS"
                    Write-Host $report
                }
            } catch {
                Write-TestingLog "Resource monitoring failed: $($_.Exception.Message)" -Level "ERROR"
                exit 1
            }
        }
        
        default {
            Write-TestingLog "Unknown testing action: $Action" -Level "ERROR"
            Write-TestingLog "Available actions: production, quick, module, validation, release, performance, monitor" -Level "INFO"
            exit 1
        }
    }
    
} catch {
    Write-TestingLog "Testing command execution failed: $($_.Exception.Message)" -Level "ERROR"
    Write-TestingLog "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}

Write-TestingLog "Testing operation completed successfully" -Level "SUCCESS"