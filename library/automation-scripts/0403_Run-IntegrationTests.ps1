#Requires -Version 7.0

<#
.SYNOPSIS
    Execute integration tests for AitherZero
.DESCRIPTION
    Runs all integration tests that validate component interactions

    Exit Codes:
    0   - All tests passed
    1   - One or more tests failed
    2   - Test execution error

.NOTES
    Stage: Testing
    Order: 0403
    Dependencies: 0400
    Tags: testing, integration-tests, pester, e2e
    AllowParallel: false
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "tests/integration"),
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$PassThru,
    [switch]$IncludeE2E
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Ensure TERM is set for terminal operations (required in CI environments)
if (-not $env:TERM) {
    $env:TERM = 'xterm-256color'
}

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0403
    Dependencies = @('0400')
    Tags = @('testing', 'integration-tests', 'pester', 'e2e')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$testingModule = Join-Path $projectRoot "aithercore/testing/TestingFramework.psm1"
$loggingModule = Join-Path $projectRoot "aithercore/utilities/Logging.psm1"

if (Test-Path $testingModule) {
    Import-Module $testingModule -Force
}

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0403_Run-IntegrationTests" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

try {
    Write-ScriptLog -Message "Starting integration test execution"

    # Check if running in DryRun mode
    if ($DryRun) {
        Write-ScriptLog -Message "DRY RUN: Would execute integration tests"
        Write-ScriptLog -Message "Test path: $Path"
        Write-ScriptLog -Message "Include E2E: $IncludeE2E"

        # List test files that would be run
        if (Test-Path $Path) {
            $testFiles = Get-ChildItem -Path $Path -Filter "*.Tests.ps1" -Recurse
            Write-ScriptLog -Message "Found $($testFiles.Count) test files:"
            foreach ($file in $testFiles) {
                Write-ScriptLog -Message "  - $($file.Name)"
            }
        }
        exit 0
    }

    # Verify test path exists
    if (-not (Test-Path $Path)) {
        Write-ScriptLog -Level Warning -Message "Test path not found: $Path"
        Write-ScriptLog -Message "No integration tests to run"
        exit 0
    }

    # Get test files
    $testFiles = Get-ChildItem -Path $Path -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue

    if ($testFiles.Count -eq 0) {
        Write-ScriptLog -Level Warning -Message "No test files found in: $Path"
        exit 0
    }

    Write-ScriptLog -Message "Found $($testFiles.Count) integration test files"

    # Load configuration
    $configPath = Join-Path $projectRoot "config.psd1"
    $pesterMinVersion = '5.0.0'  # Default minimum version
    
    if (Test-Path $configPath) {
        try {
            # Use scriptblock evaluation instead of Import-PowerShellDataFile
        # because config.psd1 contains PowerShell expressions ($true/$false) that
        # Import-PowerShellDataFile treats as "dynamic expressions"
        $configContent = Get-Content -Path $configPath -Raw
        $scriptBlock = [scriptblock]::Create($configContent)
        $config = & $scriptBlock
        if (-not $config -or $config -isnot [hashtable]) {
            throw "Config file did not return a valid hashtable"
        }
            
            # Try multiple locations for MinVersion in config structure
            if ($config.Manifest -and $config.Manifest.FeatureDependencies -and 
                $config.Manifest.FeatureDependencies.Testing -and 
                $config.Manifest.FeatureDependencies.Testing.Pester -and
                $config.Manifest.FeatureDependencies.Testing.Pester.MinVersion) {
                $pesterMinVersion = $config.Manifest.FeatureDependencies.Testing.Pester.MinVersion
            }
            elseif ($config.Features -and $config.Features.Testing -and 
                    $config.Features.Testing.Pester -and 
                    $config.Features.Testing.Pester.Version) {
                # Parse version string like '5.0.0+' to '5.0.0'
                $versionString = $config.Features.Testing.Pester.Version
                $pesterMinVersion = $versionString -replace '\+$', ''
            }
        }
        catch {
            Write-ScriptLog -Level Warning -Message "Could not parse config file, using default Pester version: $_"
        }
    }
    
    Write-ScriptLog -Message "Using Pester minimum version: $pesterMinVersion"

    # Ensure Pester is available
    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]$pesterMinVersion } | Sort-Object Version -Descending | Select-Object -First 1

    if (-not $pesterModule) {
        Write-ScriptLog -Level Error -Message "Pester $pesterMinVersion or higher is required. Run 0400_Install-TestingTools.ps1 first."
        exit 2
    }

    Write-ScriptLog -Message "Loading Pester version $($pesterModule.Version)"
    Import-Module Pester -MinimumVersion $pesterMinVersion -Force

    # Set test mode BEFORE loading modules to prevent transcript I/O overhead
    # This ensures the AitherZero module skips transcript initialization
    $env:AITHERZERO_TEST_MODE = "Integration"

    # Import AitherZero main module which loads all domains efficiently
    # This is much faster than loading individual modules
    Write-ScriptLog -Message "Loading AitherZero module for integration testing"
    $mainModule = Join-Path $projectRoot "AitherZero.psd1"
    
    if (Test-Path $mainModule) {
        try {
            Write-ScriptLog -Level Debug -Message "Loading main module: AitherZero"
            Import-Module $mainModule -Force -ErrorAction Stop -DisableNameChecking
            Write-ScriptLog -Message "AitherZero module loaded successfully"
        }
        catch {
            Write-ScriptLog -Level Warning -Message "Failed to load main module, falling back to individual modules: $_"
            
            # Fallback: Load domain modules individually
            $domainModules = Get-ChildItem -Path (Join-Path $projectRoot "aithercore") -Filter "*.psm1" -Recurse
            foreach ($module in $domainModules) {
                try {
                    Write-ScriptLog -Level Debug -Message "Loading module: $($module.Name)"
                    Import-Module $module.FullName -Force -ErrorAction Stop
                }
                catch {
                    Write-ScriptLog -Level Warning -Message "Failed to load module $($module.Name): $_"
                    # Continue with other modules - some may have parse errors
                }
            }
        }
    } else {
        Write-ScriptLog -Level Warning -Message "Main module not found, loading individual domain modules"
        
        # Load domain modules individually
        $domainModules = Get-ChildItem -Path (Join-Path $projectRoot "aithercore") -Filter "*.psm1" -Recurse
        foreach ($module in $domainModules) {
            try {
                Write-ScriptLog -Level Debug -Message "Loading module: $($module.Name)"
                Import-Module $module.FullName -Force -ErrorAction Stop
            }
            catch {
                Write-ScriptLog -Level Warning -Message "Failed to load module $($module.Name): $_"
                # Continue with other modules - some may have parse errors
            }
        }
    }

    # Get Pester settings from configuration
    $pesterSettings = if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) {
        $config = Get-Configuration
        if ($config.Testing -and $config.Testing.Pester) {
            $config.Testing.Pester
        } else {
            @{}
        }
    } else {
        @{}
    }

    # Build Pester configuration
    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = $Path
    
    # Check for Run settings with StrictMode-safe access
    if ($pesterSettings.ContainsKey('Run') -and $pesterSettings.Run) {
        $pesterConfig.Run.PassThru = if ($null -ne $pesterSettings.Run.PassThru) { $pesterSettings.Run.PassThru } else { $true }
        $pesterConfig.Run.Exit = if ($null -ne $pesterSettings.Run.Exit) { $pesterSettings.Run.Exit } else { $false }
    } else {
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Run.Exit = $false
    }

    # Filter for integration tests first
    $tags = @('Integration')
    if ($IncludeE2E) {
        $tags += 'E2E'
        Write-ScriptLog -Message "Including End-to-End tests"
    }

    $pesterConfig.Filter.Tag = $tags
    $pesterConfig.Filter.ExcludeTag = @('Unit', 'Performance')

    # Apply parallel execution settings from config (if supported)
    # Enable parallel for integration tests to improve performance
    $parallelEnabled = $false
    if ($pesterSettings.ContainsKey('Parallel') -and $pesterSettings.Parallel -and $pesterSettings.Parallel.Enabled) {
        try {
            # Check if Pester supports parallel execution
            if ((Get-Command Invoke-Pester).Parameters.ContainsKey('Configuration')) {
                $pesterConfig.Run.Parallel = $true
                
                # Use configured block size directly (config already optimized for integration tests)
                # Integration tests load modules and execute scripts, so they need
                # smaller batches to avoid overwhelming workers and maintain responsiveness
                $blockSize = if ($pesterSettings.Parallel.BlockSize) { 
                    [Math]::Max(2, [Math]::Floor($pesterSettings.Parallel.BlockSize))
                } else { 
                    2 
                }
                $pesterConfig.Run.ParallelBlockSize = $blockSize
                
                # Configure worker count
                # Use config value or optimize for CI performance
                if ($env:CI -or $env:AITHERZERO_CI) {
                    # Use available CPU cores in CI
                    $workers = [Math]::Min([Environment]::ProcessorCount, 4)
                    Write-ScriptLog -Message "CI detected: Using $workers parallel workers"
                } elseif ($pesterSettings.Parallel.Workers) {
                    $workers = $pesterSettings.Parallel.Workers
                } else {
                    $workers = 4  # Default
                }
                $pesterConfig.Run.ParallelWorkers = $workers
                
                $parallelEnabled = $true
                Write-ScriptLog -Message "Parallel execution enabled for integration tests (workers: $workers, block size: $blockSize)" -Level Information
            } else {
                Write-ScriptLog -Level Warning -Message "Parallel execution not supported in this Pester version"
            }
        }
        catch {
            Write-ScriptLog -Level Warning -Message "Failed to enable parallel execution: $_"
        }
    }
    
    if (-not $parallelEnabled) {
        Write-ScriptLog -Level Information -Message "Running integration tests sequentially"
    }

    # Optimize output verbosity for performance (especially in CI)
    if ($pesterSettings.ContainsKey('Output') -and $pesterSettings.Output) {
        if ($pesterSettings.Output.Verbosity) {
            $pesterConfig.Output.Verbosity = $pesterSettings.Output.Verbosity
        }
        if ($pesterSettings.Output.StackTraceVerbosity) {
            $pesterConfig.Output.StackTraceVerbosity = $pesterSettings.Output.StackTraceVerbosity
        }
    } else {
        # Default to minimal output for speed in CI
        if ($env:CI -or $env:AITHERZERO_CI) {
            $pesterConfig.Output.Verbosity = 'Minimal'
            $pesterConfig.Output.StackTraceVerbosity = 'FirstLine'
            Write-ScriptLog -Message "CI environment: Using minimal output verbosity for performance"
        }
    }

    # Output configuration
    if (-not $OutputPath) {
        $OutputPath = Join-Path $projectRoot "library/tests/results"
    }

    if (-not (Test-Path $OutputPath)) {
        if ($PSCmdlet.ShouldProcess($OutputPath, "Create output directory")) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "IntegrationTests-$timestamp.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

    # Performance tracking
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Start-PerformanceTrace -Name "IntegrationTests" -Description "Integration test execution"
    }

    Write-ScriptLog -Message "Executing integration tests..."
    Write-Host "`nRunning integration tests. This may take several minutes..." -ForegroundColor Yellow

    # Create test environment
    $testDrive = Join-Path ([System.IO.Path]::GetTempPath()) "AitherZero-IntegrationTest-$timestamp"
    if ($PSCmdlet.ShouldProcess($testDrive, "Create test environment directory")) {
        New-Item -Path $testDrive -ItemType Directory -Force | Out-Null
    }

    # Set test drive environment variable
    # Note: AITHERZERO_TEST_MODE is already set earlier before module loading
    if ($PSCmdlet.ShouldProcess("Environment variables", "Set test drive variable")) {
        $env:AITHERZERO_TEST_DRIVE = $testDrive
    }

    try {
        if ($PSCmdlet.ShouldProcess("Integration tests in $Path", "Execute Pester tests")) {
            $result = Invoke-Pester -Configuration $pesterConfig
        } else {
            Write-ScriptLog -Message "WhatIf: Would execute integration tests with Pester configuration"
            return
        }
    }
    finally {
        # Cleanup test environment
        if ($PSCmdlet.ShouldProcess($testDrive, "Remove test environment")) {
            Remove-Item -Path $testDrive -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($PSCmdlet.ShouldProcess("Environment variables", "Remove test mode variables")) {
            Remove-Item Env:\AITHERZERO_TEST_MODE -ErrorAction SilentlyContinue
            Remove-Item Env:\AITHERZERO_TEST_DRIVE -ErrorAction SilentlyContinue
        }
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        $duration = Stop-PerformanceTrace -Name "IntegrationTests"
    }

    # Log results
    $testSummary = @{
        TotalTests = $result.TotalCount
        Passed = $result.PassedCount
        Failed = $result.FailedCount
        Skipped = $result.SkippedCount
        Duration = if ($duration) { $duration.TotalSeconds } else { $result.Duration.TotalSeconds }
    }

    Write-ScriptLog -Message "Integration test execution completed" -Data $testSummary

    # Display summary
    Write-Host "`nIntegration Test Summary:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($result.TotalCount)"
    Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Duration: $($result.Duration.TotalSeconds.ToString('F2'))s"

    # Display failed tests
    if ($result.FailedCount -gt 0) {
        Write-Host "`nFailed Tests:" -ForegroundColor Red
        $result.Failed | ForEach-Object {
            Write-Host "  - $($_.ExpandedPath)" -ForegroundColor Red
            
            # Get error message safely
            $errorMessage = if ($_.ErrorRecord) {
                if ($_.ErrorRecord.Exception) {
                    $_.ErrorRecord.Exception.Message
                } elseif ($_.ErrorRecord.DisplayErrorMessage) {
                    $_.ErrorRecord.DisplayErrorMessage
                } else {
                    $_.ErrorRecord.ToString()
                }
            } else {
                "Test failed"
            }
            Write-Host "    $errorMessage" -ForegroundColor DarkRed

            # For integration tests, provide more context
            if ($_.ErrorRecord -and $_.ErrorRecord.TargetObject) {
                Write-Host "    Context: $($_.ErrorRecord.TargetObject)" -ForegroundColor DarkYellow
            }
        }
    }

    # Check for specific integration test results
    if ($result.Tests) {
        try {
            $criticalTests = $result.Tests | Where-Object { 
                $_ -and (Get-Member -InputObject $_ -Name 'Tags' -MemberType Properties) -and ($_.Tags -contains 'Critical')
            }
            if ($criticalTests) {
                $criticalFailed = $criticalTests | Where-Object { $_.Result -eq 'Failed' }
                if ($criticalFailed.Count -gt 0) {
                    Write-ScriptLog -Level Error -Message "Critical integration tests failed!" -Data @{
                        FailedCritical = $criticalFailed.Name
                    }
                }
            }
        }
        catch {
            Write-ScriptLog -Level Debug -Message "Could not check for critical tests: $_"
        }
    }

    # Save result summary (legacy format)
    $summaryPath = Join-Path $OutputPath "IntegrationTests-Summary-$timestamp.json"
    $extendedSummary = $testSummary + @{
        TestCategories = try {
            $result.Tests | Where-Object { Get-Member -InputObject $_ -Name 'Tags' -MemberType Properties } | Group-Object { 
                if ($_.Tags) { $_.Tags -join ',' } else { 'Untagged' }
            } | ForEach-Object {
                @{
                    Tags = $_.Name
                    Count = $_.Count
                    Failed = ($_.Group | Where-Object { $_.Result -eq 'Failed' }).Count
                }
            }
        }
        catch {
            @()
        }
    }
    if ($PSCmdlet.ShouldProcess($summaryPath, "Save test summary")) {
        $extendedSummary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath
    }
    Write-ScriptLog -Message "Test summary saved to: $summaryPath"

    # Save comprehensive report for dashboard/CI (TestReport format)
    $testReportPath = Join-Path $OutputPath "TestReport-Integration-$timestamp.json"
    if ($PSCmdlet.ShouldProcess($testReportPath, "Save comprehensive test report")) {
        $comprehensiveReport = @{
            TestType = 'Integration'
            Timestamp = (Get-Date).ToString('o')
            TotalCount = $result.TotalCount
            PassedCount = $result.PassedCount
            FailedCount = $result.FailedCount
            SkippedCount = $result.SkippedCount
            Duration = $result.Duration.TotalSeconds
            TestResults = @{
                Summary = @{
                    Total = $result.TotalCount
                    Passed = $result.PassedCount
                    Failed = $result.FailedCount
                    Skipped = $result.SkippedCount
                }
                Details = @()
            }
        }

        # Add failed test details
        if ($result.Failed -and $result.Failed.Count -gt 0) {
            foreach ($failedTest in $result.Failed) {
                $testDetail = @{
                    Result = 'Failed'
                    Name = $failedTest.Name ?? $failedTest.ExpandedName ?? $failedTest.ExpandedPath ?? 'Unknown Test'
                    ExpandedPath = $failedTest.ExpandedPath
                    ErrorRecord = if ($failedTest.ErrorRecord) {
                        @{
                            Exception = @{
                                Message = if ($failedTest.ErrorRecord.Exception) {
                                    $failedTest.ErrorRecord.Exception.Message
                                } else {
                                    $failedTest.ErrorRecord.ToString()
                                }
                            }
                            ScriptStackTrace = $failedTest.ErrorRecord.ScriptStackTrace
                        }
                    } else { $null }
                    ScriptBlock = if ($failedTest.ScriptBlock) {
                        @{
                            File = $failedTest.ScriptBlock.File
                            StartPosition = @{
                                Line = $failedTest.ScriptBlock.StartPosition.StartLine
                            }
                        }
                    } else { $null }
                    Duration = if ($failedTest.Duration) { $failedTest.Duration.TotalSeconds } else { 0 }
                }
                $comprehensiveReport.TestResults.Details += $testDetail
            }
        }

        $comprehensiveReport | ConvertTo-Json -Depth 10 | Set-Content -Path $testReportPath
        Write-ScriptLog -Message "Comprehensive test report saved to: $testReportPath"
    }

    # Return result if PassThru
    if ($PassThru) {
        return $result
    }

    # Exit based on test results
    if ($result.FailedCount -eq 0) {
        Write-ScriptLog -Message "All integration tests passed!"
        exit 0
    } else {
        Write-ScriptLog -Level Error -Message "$($result.FailedCount) integration tests failed"
        exit 1
    }
}
catch {
    # Extract error info once to avoid duplication
    $errorMessage = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    $errorStackTrace = if ($_.ScriptStackTrace) { $_.ScriptStackTrace } else { 'N/A' }
    
    Write-ScriptLog -Level Error -Message "Integration test execution failed: $_" -Data @{
        Exception = $errorMessage
        ScriptStackTrace = $errorStackTrace
    }
    
    # CRITICAL: Always create TestReport file even on catastrophic failure
    # This ensures CI/CD aggregation can process results
    # Use $PSScriptRoot instead of $projectRoot to ensure variable is always available
    $scriptProjectRoot = Split-Path $PSScriptRoot -Parent
    
    if (-not $OutputPath) {
        $OutputPath = Join-Path $scriptProjectRoot "library/tests/results"
    }
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $testReportPath = Join-Path $OutputPath "TestReport-Integration-$timestamp.json"
    
    # Create minimal failure report
    $failureReport = @{
        TestType = 'Integration'
        Timestamp = (Get-Date).ToString('o')
        TotalCount = 0
        PassedCount = 0
        FailedCount = 0
        SkippedCount = 0
        Duration = 0
        ExecutionError = @{
            Message = $errorMessage
            ScriptStackTrace = $errorStackTrace
        }
        TestResults = @{
            Summary = @{
                Total = 0
                Passed = 0
                Failed = 0
                Skipped = 0
            }
            Details = @()
        }
    }
    
    $failureReport | ConvertTo-Json -Depth 10 | Set-Content -Path $testReportPath
    Write-ScriptLog -Message "Failure report saved to: $testReportPath"
    
    exit 2
}