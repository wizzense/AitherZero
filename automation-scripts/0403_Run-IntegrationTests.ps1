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
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = (Join-Path (Split-Path $PSScriptRoot -Parent) "tests/integration"),
    [string]$OutputPath,
    [switch]$DryRun,
    [switch]$PassThru,
    [switch]$IncludeE2E
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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
$projectRoot = Split-Path $PSScriptRoot -Parent
$testingModule = Join-Path $projectRoot "domains/testing/TestingFramework.psm1"
$loggingModule = Join-Path $projectRoot "domains/utilities/Logging.psm1"

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
    $testingConfig = if (Test-Path $configPath) {
        $config = Import-PowerShellDataFile $configPath
        $config.Testing
    } else {
        @{
            Framework = 'Pester'
            MinVersion = '5.0.0'
            Parallel = $false  # Integration tests often can't run in parallel
        }
    }

    # Ensure Pester is available
    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [Version]$testingConfig.MinVersion } | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $pesterModule) {
        Write-ScriptLog -Level Error -Message "Pester $($testingConfig.MinVersion) or higher is required. Run 0400_Install-TestingTools.ps1 first."
        exit 2
    }
    
    Write-ScriptLog -Message "Loading Pester version $($pesterModule.Version)"
    Import-Module Pester -MinimumVersion $testingConfig.MinVersion -Force

    # Import all domain modules for integration testing
    Write-ScriptLog -Message "Loading domain modules for integration testing"
    $domainModules = Get-ChildItem -Path (Join-Path $projectRoot "domains") -Filter "*.psm1" -Recurse
    foreach ($module in $domainModules) {
        Write-ScriptLog -Level Debug -Message "Loading module: $($module.Name)"
        Import-Module $module.FullName -Force
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
    $pesterConfig.Run.PassThru = if ($pesterSettings.Run.PassThru -ne $null) { $pesterSettings.Run.PassThru } else { $true }
    $pesterConfig.Run.Exit = if ($pesterSettings.Run.Exit -ne $null) { $pesterSettings.Run.Exit } else { $false }
    
    # Apply parallel execution settings from config
    if ($pesterSettings.Parallel -and $pesterSettings.Parallel.Enabled) {
        $pesterConfig.Run.Parallel = $true
        if ($pesterSettings.Parallel.BlockSize) {
            $pesterConfig.Run.ParallelBlockSize = $pesterSettings.Parallel.BlockSize
        }
        Write-ScriptLog -Message "Parallel execution enabled with block size: $($pesterSettings.Parallel.BlockSize ?? 4)"
    }

    # Filter for integration tests
    $tags = @('Integration')
    if ($IncludeE2E) {
        $tags += 'E2E'
        Write-ScriptLog -Message "Including End-to-End tests"
    }
    
    $pesterConfig.Filter.Tag = $tags
    $pesterConfig.Filter.ExcludeTag = @('Unit', 'Performance')

    # Disable parallel execution for integration tests
    $pesterConfig.Run.Parallel = $false

    # Output configuration
    if (-not $OutputPath) {
        $OutputPath = Join-Path $projectRoot "tests/results"
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

    # Set environment variables for tests
    if ($PSCmdlet.ShouldProcess("Environment variables", "Set test mode variables")) {
        $env:AITHERZERO_TEST_MODE = "Integration"
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
            Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed

            # For integration tests, provide more context
            if ($_.ErrorRecord.TargetObject) {
                Write-Host "    Context: $($_.ErrorRecord.TargetObject)" -ForegroundColor DarkYellow
            }
        }
    }

    # Check for specific integration test results
    $criticalTests = $result.Tests | Where-Object { $_.Tags -contains 'Critical' }
    if ($criticalTests) {
        $criticalFailed = $criticalTests | Where-Object { $_.Result -eq 'Failed' }
        if ($criticalFailed.Count -gt 0) {
            Write-ScriptLog -Level Error -Message "Critical integration tests failed!" -Data @{
                FailedCritical = $criticalFailed.Name
            }
        }
    }

    # Save result summary
    $summaryPath = Join-Path $OutputPath "IntegrationTests-Summary-$timestamp.json"
    $extendedSummary = $testSummary + @{
        TestCategories = $result.Tests | Group-Object { $_.Tags -join ',' } | ForEach-Object {
            @{
                Tags = $_.Name
                Count = $_.Count
                Failed = ($_.Group | Where-Object { $_.Result -eq 'Failed' }).Count
            }
        }
    }
    if ($PSCmdlet.ShouldProcess($summaryPath, "Save test summary")) {
        $extendedSummary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath
    }
    Write-ScriptLog -Message "Test summary saved to: $summaryPath"

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
    Write-ScriptLog -Level Error -Message "Integration test execution failed: $_" -Data @{ 
        Exception = $_.Exception.Message 
        ScriptStackTrace = $_.ScriptStackTrace
    }
    exit 2
}