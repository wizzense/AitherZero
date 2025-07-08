#Requires -Module Pester

<#
.SYNOPSIS
    Integration Test Runner for AitherZero Module Interactions

.DESCRIPTION
    Comprehensive integration test runner that orchestrates end-to-end testing of:
    - Module-to-module interactions
    - Complete workflows spanning multiple modules
    - CLI entry points and scripts
    - Real-world scenarios with multiple components
    - Error scenarios and edge cases
    - Module communication and API interactions

.PARAMETER TestSuite
    Test suite to run: All, Core, Configuration, PatchManager, CLI, Communication, Smoke

.PARAMETER IncludeSlowTests
    Include slow/long-running integration tests

.PARAMETER CI
    Run in CI mode (optimized for automation)

.PARAMETER OutputPath
    Path to output test results

.PARAMETER Parallel
    Run tests in parallel where possible

.EXAMPLE
    ./Run-IntegrationTests.ps1 -TestSuite All
    # Run all integration tests

.EXAMPLE
    ./Run-IntegrationTests.ps1 -TestSuite Core -CI
    # Run core integration tests in CI mode

.EXAMPLE
    ./Run-IntegrationTests.ps1 -TestSuite PatchManager -IncludeSlowTests
    # Run PatchManager integration tests including slow tests
#>

[CmdletBinding()]
param(
    [ValidateSet("All", "Core", "Configuration", "PatchManager", "CLI", "Communication", "Smoke")]
    [string]$TestSuite = "Core",
    
    [switch]$IncludeSlowTests,
    [switch]$CI,
    [string]$OutputPath,
    [switch]$Parallel
)

$ErrorActionPreference = 'Stop'

# Initialize test environment
$testPath = $PSScriptRoot
$projectRoot = Split-Path (Split-Path $testPath -Parent) -Parent
$integrationTestsPath = Join-Path $testPath "integration"

# Ensure output directory exists
if (-not $OutputPath) {
    $OutputPath = Join-Path $testPath "results/integration"
}
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Test environment configuration
$testEnvironment = @{
    ProjectRoot = $projectRoot
    TestPath = $testPath
    IntegrationPath = $integrationTestsPath
    OutputPath = $OutputPath
    CI = $CI
    IncludeSlowTests = $IncludeSlowTests
    Parallel = $Parallel
    TestDrive = $null
}

# Function to get all integration test files
function Get-IntegrationTests {
    param(
        [string]$TestSuite,
        [hashtable]$Environment
    )
    
    $testFiles = @()
    $basePath = $Environment.IntegrationPath
    
    switch ($TestSuite) {
        "All" {
            $testFiles = Get-ChildItem -Path $basePath -Filter "*.Integration.Tests.ps1" -Recurse
        }
        "Core" {
            $testFiles = @(
                "ModuleLoading.Integration.Tests.ps1",
                "CoreWorkflow.Integration.Tests.ps1",
                "EntryPoint.Integration.Tests.ps1"
            ) | ForEach-Object { Join-Path $basePath $_ } | Where-Object { Test-Path $_ }
        }
        "Configuration" {
            $testFiles = @(
                "ConfigurationManagement.EndToEnd.Tests.ps1",
                "ConfigurationModules.Integration.Tests.ps1"
            ) | ForEach-Object { Join-Path $basePath $_ } | Where-Object { Test-Path $_ }
        }
        "PatchManager" {
            $testFiles = @(
                "PatchManager.Integration.Tests.ps1",
                "GitWorkflow.Integration.Tests.ps1"
            ) | ForEach-Object { Join-Path $basePath $_ } | Where-Object { Test-Path $_ }
        }
        "CLI" {
            $testFiles = @(
                "CLI.Integration.Tests.ps1",
                "EntryPoint.Integration.Tests.ps1"
            ) | ForEach-Object { Join-Path $basePath $_ } | Where-Object { Test-Path $_ }
        }
        "Communication" {
            $testFiles = @(
                "ModuleCommunication.Integration.Tests.ps1",
                "EventSystem.Integration.Tests.ps1"
            ) | ForEach-Object { Join-Path $basePath $_ } | Where-Object { Test-Path $_ }
        }
        "Smoke" {
            $testFiles = @(
                "SmokeTests.Integration.Tests.ps1"
            ) | ForEach-Object { Join-Path $basePath $_ } | Where-Object { Test-Path $_ }
        }
    }
    
    return $testFiles | Where-Object { $_ -and (Test-Path $_) }
}

# Function to prepare test environment
function Initialize-IntegrationTestEnvironment {
    param([hashtable]$Environment)
    
    Write-Host "🔧 Initializing integration test environment..." -ForegroundColor Cyan
    
    # Set environment variables for tests
    $env:INTEGRATION_TEST_MODE = "true"
    $env:PROJECT_ROOT = $Environment.ProjectRoot
    $env:TEST_OUTPUT_PATH = $Environment.OutputPath
    $env:CI_MODE = $Environment.CI.ToString()
    
    # Initialize test drive
    $testDrive = Join-Path $Environment.OutputPath "TestDrive"
    if (Test-Path $testDrive) {
        Remove-Item -Path $testDrive -Recurse -Force
    }
    New-Item -ItemType Directory -Path $testDrive -Force | Out-Null
    $Environment.TestDrive = $testDrive
    
    # Import required modules
    $requiredModules = @(
        "Pester",
        (Join-Path $Environment.ProjectRoot "aither-core/modules/TestingFramework"),
        (Join-Path $Environment.ProjectRoot "aither-core/modules/Logging")
    )
    
    foreach ($module in $requiredModules) {
        if (Test-Path $module) {
            try {
                Import-Module $module -Force -ErrorAction Stop
                Write-Host "  ✅ Imported: $module" -ForegroundColor Green
            } catch {
                Write-Host "  ❌ Failed to import: $module - $($_.Exception.Message)" -ForegroundColor Red
            }
        } elseif ($module -eq "Pester") {
            try {
                Import-Module Pester -MinimumVersion 5.0.0 -Force -ErrorAction Stop
                Write-Host "  ✅ Imported: Pester" -ForegroundColor Green
            } catch {
                Write-Host "  ❌ Failed to import Pester: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    Write-Host "  📁 Test drive: $testDrive" -ForegroundColor Cyan
    Write-Host "  📊 Output path: $($Environment.OutputPath)" -ForegroundColor Cyan
    Write-Host "  🌟 Ready for integration testing!" -ForegroundColor Green
}

# Function to run integration tests
function Invoke-IntegrationTests {
    param(
        [string[]]$TestFiles,
        [hashtable]$Environment
    )
    
    if ($TestFiles.Count -eq 0) {
        Write-Host "⚠️  No integration test files found for suite: $TestSuite" -ForegroundColor Yellow
        return @{
            TotalCount = 0
            Passed = 0
            Failed = 0
            Skipped = 0
            Duration = [TimeSpan]::Zero
            Results = @()
        }
    }
    
    Write-Host "🧪 Running integration tests..." -ForegroundColor Cyan
    Write-Host "  Files: $($TestFiles.Count)" -ForegroundColor White
    
    foreach ($file in $TestFiles) {
        $fileName = Split-Path $file -Leaf
        Write-Host "  • $fileName" -ForegroundColor Gray
    }
    
    # Configure Pester
    $pesterConfig = @{
        Path = $TestFiles
        PassThru = $true
        Output = if ($Environment.CI) { 'Minimal' } else { 'Detailed' }
    }
    
    # Add tags for filtering
    if (-not $Environment.IncludeSlowTests) {
        $pesterConfig.TagFilter = @{ ExcludeTag = @('Slow', 'LongRunning') }
    }
    
    # Run tests
    $startTime = Get-Date
    try {
        $results = Invoke-Pester @pesterConfig
        $duration = (Get-Date) - $startTime
        
        # Generate detailed results
        $detailedResults = @{
            TotalCount = $results.TotalCount
            Passed = $results.Passed
            Failed = $results.Failed
            Skipped = $results.Skipped
            Duration = $duration
            Results = $results
            TestFiles = $TestFiles
            Environment = $Environment
        }
        
        return $detailedResults
    } catch {
        Write-Host "❌ Integration test execution failed: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# Function to generate integration test report
function New-IntegrationTestReport {
    param(
        [hashtable]$TestResults,
        [string]$TestSuite,
        [hashtable]$Environment
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportPath = Join-Path $Environment.OutputPath "integration-test-report-$timestamp.md"
    
    $report = @"
# Integration Test Report - $TestSuite

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Test Suite:** $TestSuite
**Duration:** $($TestResults.Duration.ToString("hh\:mm\:ss"))

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | $($TestResults.TotalCount) |
| Passed | $($TestResults.Passed) |
| Failed | $($TestResults.Failed) |
| Skipped | $($TestResults.Skipped) |
| Success Rate | $(if ($TestResults.TotalCount -gt 0) { [math]::Round(($TestResults.Passed / $TestResults.TotalCount) * 100, 2) } else { 0 })% |

## Test Files

$($TestResults.TestFiles | ForEach-Object { "- $(Split-Path $_ -Leaf)" } | Out-String)

## Environment

- **Project Root:** $($Environment.ProjectRoot)
- **CI Mode:** $($Environment.CI)
- **Include Slow Tests:** $($Environment.IncludeSlowTests)
- **Parallel Execution:** $($Environment.Parallel)

## Results

$(if ($TestResults.Failed -gt 0) { "### ❌ Failed Tests`n" } else { "### ✅ All Tests Passed`n" })

$(if ($TestResults.Results.TestResult) {
    $TestResults.Results.TestResult | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object {
        "- **$($_.Name):** $($_.ErrorRecord.Exception.Message)"
    } | Out-String
} else { "No detailed failure information available." })

---
*Generated by AitherZero Integration Test Runner*
"@
    
    Set-Content -Path $reportPath -Value $report
    Write-Host "📄 Integration test report: $reportPath" -ForegroundColor Cyan
    
    return $reportPath
}

# Function to cleanup test environment
function Reset-IntegrationTestEnvironment {
    param([hashtable]$Environment)
    
    Write-Host "🧹 Cleaning up integration test environment..." -ForegroundColor Cyan
    
    # Remove test drive
    if ($Environment.TestDrive -and (Test-Path $Environment.TestDrive)) {
        try {
            Remove-Item -Path $Environment.TestDrive -Recurse -Force
            Write-Host "  ✅ Cleaned up test drive" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Could not clean up test drive: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Clear environment variables
    $env:INTEGRATION_TEST_MODE = $null
    $env:PROJECT_ROOT = $null
    $env:TEST_OUTPUT_PATH = $null
    $env:CI_MODE = $null
    
    Write-Host "  ✅ Environment cleaned up" -ForegroundColor Green
}

# Main execution
try {
    Write-Host "🚀 AitherZero Integration Test Runner" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green
    Write-Host "Test Suite: $TestSuite" -ForegroundColor White
    Write-Host "Include Slow Tests: $IncludeSlowTests" -ForegroundColor White
    Write-Host "CI Mode: $CI" -ForegroundColor White
    Write-Host "Parallel: $Parallel" -ForegroundColor White
    Write-Host ""
    
    # Initialize environment
    Initialize-IntegrationTestEnvironment -Environment $testEnvironment
    
    # Get test files
    $testFiles = Get-IntegrationTests -TestSuite $TestSuite -Environment $testEnvironment
    
    if ($testFiles.Count -eq 0) {
        Write-Host "⚠️  No integration tests found for suite: $TestSuite" -ForegroundColor Yellow
        Write-Host "Available test files:" -ForegroundColor Yellow
        Get-ChildItem -Path $integrationTestsPath -Filter "*.Integration.Tests.ps1" | ForEach-Object {
            Write-Host "  • $($_.Name)" -ForegroundColor Gray
        }
        exit 0
    }
    
    # Run tests
    $results = Invoke-IntegrationTests -TestFiles $testFiles -Environment $testEnvironment
    
    # Generate report
    $reportPath = New-IntegrationTestReport -TestResults $results -TestSuite $TestSuite -Environment $testEnvironment
    
    # Display results
    Write-Host ""
    Write-Host "🏁 Integration Test Results" -ForegroundColor Green
    Write-Host "===========================" -ForegroundColor Green
    Write-Host "Total Tests: $($results.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($results.Passed)" -ForegroundColor Green
    Write-Host "Failed: $($results.Failed)" -ForegroundColor $(if ($results.Failed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Skipped: $($results.Skipped)" -ForegroundColor Yellow
    Write-Host "Duration: $($results.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host "Success Rate: $(if ($results.TotalCount -gt 0) { [math]::Round(($results.Passed / $results.TotalCount) * 100, 2) } else { 0 })%" -ForegroundColor White
    Write-Host ""
    Write-Host "📄 Report: $reportPath" -ForegroundColor Cyan
    
    # Exit with appropriate code
    if ($CI -and $results.Failed -gt 0) {
        exit 1
    }
    
} catch {
    Write-Host "❌ Integration test execution failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($CI) {
        exit 1
    }
    throw
} finally {
    # Cleanup
    Reset-IntegrationTestEnvironment -Environment $testEnvironment
}