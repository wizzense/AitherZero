#Requires -Version 7.0
<#
.SYNOPSIS
    AitherZero Next-Generation Test Runner
.DESCRIPTION
    High-performance test runner that replaces the slow 97-file test system.
    Uses the new AitherTestFramework with intelligent caching and parallelization.

    Exit Codes:
    0 - All tests passed
    1 - Some tests failed
    2 - Test execution error

.PARAMETER Category
    Test category to run: Smoke, Unit, Integration, or Full
.PARAMETER Tags
    Filter tests by specific tags
.PARAMETER ExcludeTags
    Exclude tests with specific tags
.PARAMETER Force
    Force execution (ignore cache)
.PARAMETER ClearCache
    Clear test cache before execution
.PARAMETER Parallel
    Enable/disable parallel execution (default: auto-detect)
.PARAMETER MaxJobs
    Maximum parallel jobs (default: based on category)
.PARAMETER OutputPath
    Path for test results (default: ./test-results)
.PARAMETER CI
    Run in CI mode (optimized settings)
.PARAMETER DryRun
    Show what would be executed without running tests

.EXAMPLE
    ./Invoke-AitherTests.ps1 -Category Smoke
    Run smoke tests (< 30 seconds)

.EXAMPLE
    ./Invoke-AitherTests.ps1 -Category Unit -Tags Core
    Run unit tests with Core tag

.EXAMPLE
    ./Invoke-AitherTests.ps1 -Category Full -CI
    Run complete test suite in CI mode

.NOTES
    Copyright © 2025 Aitherium Corporation
    Replaces automation-scripts/0402_Run-UnitTests.ps1 and related testing scripts
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Smoke', 'Unit', 'Integration', 'Full')]
    [string]$Category = 'Unit',

    [string[]]$Tags = @(),

    [string[]]$ExcludeTags = @(),

    [switch]$Force,

    [switch]$ClearCache,

    [bool]$Parallel = $true,

    [int]$MaxJobs = 0,

    [string]$OutputPath = './test-results',

    [switch]$CI,

    [switch]$DryRun,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script metadata
$script:ScriptName = 'Invoke-AitherTests'
$script:Version = '2.0.0'
$script:StartTime = Get-Date

# Paths
$script:ProjectRoot = $PSScriptRoot
$script:TestFrameworkPath = Join-Path $script:ProjectRoot "domains/testing"

# Ensure environment is set
$env:AITHERZERO_ROOT = $script:ProjectRoot
$env:AITHERZERO_TEST_MODE = "1"
$env:AITHERZERO_DISABLE_TRANSCRIPT = "1"  # Disable transcript during tests

function Write-TestRunnerLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    $icon = switch ($Level) {
        'Error' { '❌' }
        'Warning' { '⚠️' }
        'Information' { 'ℹ️' }
        'Success' { '✅' }
        'Debug' { '🔍' }
        default { '•' }
    }

    $color = switch ($Level) {
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        'Information' { 'White' }
        'Success' { 'Green' }
        'Debug' { 'Gray' }
        default { 'White' }
    }

    Write-Host "[$timestamp] $icon $Message" -ForegroundColor $color

    # Also try to log via centralized logging if available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source $script:ScriptName -Data $Data
    }
}

function Show-TestRunnerBanner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  AitherZero Test Runner v$($script:Version)                ║" -ForegroundColor Cyan
    Write-Host "║              High-Performance Testing Framework              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-TestRunnerLog "Starting $Category test execution" -Level Information
}

function Initialize-TestEnvironment {
    Write-TestRunnerLog "Initializing test environment"

    # Import required modules
    try {
        $frameworkModule = Join-Path $script:TestFrameworkPath "AitherTestFramework.psm1"
        $testSuitesModule = Join-Path $script:TestFrameworkPath "CoreTestSuites.psm1"

        if (-not (Test-Path $frameworkModule)) {
            throw "AitherTestFramework module not found: $frameworkModule"
        }

        if (-not (Test-Path $testSuitesModule)) {
            throw "CoreTestSuites module not found: $testSuitesModule"
        }

        Write-TestRunnerLog "Loading AitherTestFramework..."
        Import-Module $frameworkModule -Force -Global

        Write-TestRunnerLog "Loading CoreTestSuites..."
        Import-Module $testSuitesModule -Force -Global

        # Register all test suites
        Write-TestRunnerLog "Registering test suites..."
        Register-CoreTestSuites

        # Import the critical functions directly into current scope
        $frameworkFunctions = Get-Command -Module AitherTestFramework
        foreach ($func in $frameworkFunctions) {
            Set-Item -Path "function:global:$($func.Name)" -Value $func.ScriptBlock
        }

        Write-TestRunnerLog "Test environment initialized successfully" -Level Success

    } catch {
        Write-TestRunnerLog "Failed to initialize test environment: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Invoke-TestExecution {
    Write-TestRunnerLog "Configuring test execution"

    # Build test parameters
    $testParams = @{
        Category = $Category
        Force = $Force
        NoCache = $ClearCache
    }

    if ($Tags.Count -gt 0) {
        $testParams['IncludeTags'] = $Tags
    }

    if ($ExcludeTags.Count -gt 0) {
        $testParams['ExcludeTags'] = $ExcludeTags
    }

    # Configure for CI mode
    if ($CI) {
        Write-TestRunnerLog "Running in CI mode"
        $testParams['Force'] = $true  # Always run fresh in CI
        $script:Parallel = $true     # Force parallel in CI
    }

    Write-TestRunnerLog "Executing $Category tests..." -Data @{
        Category = $Category
        Tags = $Tags
        ExcludeTags = $ExcludeTags
        Force = $Force
        Parallel = $Parallel
        CI = $CI
    }

    if ($DryRun) {
        Write-TestRunnerLog "DRY RUN: Would execute tests with parameters:" -Level Warning
        $testParams | ConvertTo-Json | Write-Host
        return @{
            Success = $true
            Results = @()
            Summary = @{ Message = "Dry run completed" }
            DryRun = $true
        }
    }

    if (-not $PSCmdlet.ShouldProcess("$Category tests", "Execute test suite")) {
        Write-TestRunnerLog "Test execution cancelled by WhatIf"
        return @{
            Success = $true
            Results = @()
            Summary = @{ Message = "WhatIf mode - execution skipped" }
        }
    }

    try {
        # Execute tests using the framework  
        # Call function using the function: provider
        $testResult = & (Get-Item function:Invoke-TestCategory) @testParams

        Write-TestRunnerLog "Test execution completed" -Level Success -Data $testResult.Summary
        return $testResult

    } catch {
        Write-TestRunnerLog "Test execution failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Show-TestResults {
    param([hashtable]$Results)

    if ($Results.DryRun) {
        Write-TestRunnerLog "Dry run completed - no actual tests executed"
        return
    }

    $summary = $Results.Summary
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                        Test Results                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Summary statistics
    Write-Host "📊 Test Summary:" -ForegroundColor Cyan
    Write-Host "   Category: $($summary.Category)" -ForegroundColor White
    Write-Host "   Total Test Suites: $($summary.TotalSuites)" -ForegroundColor White
    Write-Host "   ✅ Passed: $($summary.Passed)" -ForegroundColor Green
    Write-Host "   ❌ Failed: $($summary.Failed)" -ForegroundColor $(if ($summary.Failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host "   ⏭️ Skipped: $($summary.Skipped)" -ForegroundColor Yellow
    Write-Host "   💾 From Cache: $($summary.FromCache)" -ForegroundColor Cyan
    Write-Host "   ⏱️ Duration: $($summary.Duration.ToString('mm\:ss\.fff'))" -ForegroundColor White

    # Performance metrics
    $testsPerSecond = if ($summary.Duration.TotalSeconds -gt 0) {
        [math]::Round($summary.TotalSuites / $summary.Duration.TotalSeconds, 1)
    } else { 0 }
    Write-Host "   🚀 Performance: $testsPerSecond test suites/second" -ForegroundColor Magenta

    # Cache hit rate
    if ($summary.TotalSuites -gt 0) {
        $cacheHitRate = [math]::Round(($summary.FromCache / $summary.TotalSuites) * 100, 1)
        Write-Host "   💾 Cache Hit Rate: $cacheHitRate%" -ForegroundColor Cyan
    }

    # Failed tests details
    if ($summary.Failed -gt 0) {
        Write-Host ""
        Write-Host "❌ Failed Test Suites:" -ForegroundColor Red
        $Results.Results | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object {
            Write-Host "   • $($_.SuiteName)" -ForegroundColor Red
            if ($_.Error) {
                Write-Host "     Error: $($_.Error)" -ForegroundColor DarkRed
            }
        }
    }

    # Success message
    if ($summary.Success) {
        Write-Host ""
        Write-Host "🎉 All tests passed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️  Some tests failed. Please review the errors above." -ForegroundColor Yellow
    }

    Write-Host ""
}

function Export-TestResults {
    param(
        [hashtable]$Results,
        [string]$OutputPath
    )

    if ($Results.DryRun) {
        return
    }

    Write-TestRunnerLog "Exporting test results to: $OutputPath"

    try {
        # Create output directory
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

        # Export summary as JSON
        $summaryPath = Join-Path $OutputPath "AitherTests-Summary-$timestamp.json"
        @{
            Timestamp = Get-Date
            Category = $Results.Category
            Summary = $Results.Summary
            Framework = @{
                Name = 'AitherTestFramework'
                Version = $script:Version
            }
        } | ConvertTo-Json -Depth 10 | Set-Content $summaryPath -Encoding UTF8

        # Export detailed results as JSON
        $resultsPath = Join-Path $OutputPath "AitherTests-Details-$timestamp.json"
        @{
            Timestamp = Get-Date
            Category = $Results.Category
            Results = $Results.Results
            Summary = $Results.Summary
        } | ConvertTo-Json -Depth 10 | Set-Content $resultsPath -Encoding UTF8

        # Export in JUnit XML format for CI integration
        $junitPath = Join-Path $OutputPath "AitherTests-$timestamp.xml"
        Export-JUnitXML -Results $Results -OutputPath $junitPath

        Write-TestRunnerLog "Test results exported successfully" -Level Success -Data @{
            SummaryPath = $summaryPath
            ResultsPath = $resultsPath
            JUnitPath = $junitPath
        }

    } catch {
        Write-TestRunnerLog "Failed to export test results: $($_.Exception.Message)" -Level Warning
    }
}

function Export-JUnitXML {
    param(
        [hashtable]$Results,
        [string]$OutputPath
    )

    $xml = [System.Xml.XmlDocument]::new()
    $declaration = $xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
    $xml.AppendChild($declaration) | Out-Null

    # Create testsuites element
    $testsuites = $xml.CreateElement("testsuites")
    $testsuites.SetAttribute("name", "AitherZero")
    $testsuites.SetAttribute("tests", $Results.Summary.TotalSuites)
    $testsuites.SetAttribute("failures", $Results.Summary.Failed)
    $testsuites.SetAttribute("skipped", $Results.Summary.Skipped)
    $testsuites.SetAttribute("time", $Results.Summary.Duration.TotalSeconds)
    $xml.AppendChild($testsuites) | Out-Null

    # Create testsuite element
    $testsuite = $xml.CreateElement("testsuite")
    $testsuite.SetAttribute("name", $Results.Category)
    $testsuite.SetAttribute("tests", $Results.Summary.TotalSuites)
    $testsuite.SetAttribute("failures", $Results.Summary.Failed)
    $testsuite.SetAttribute("skipped", $Results.Summary.Skipped)
    $testsuite.SetAttribute("time", $Results.Summary.Duration.TotalSeconds)
    $testsuites.AppendChild($testsuite) | Out-Null

    # Add test cases
    foreach ($result in $Results.Results) {
        $testcase = $xml.CreateElement("testcase")
        $testcase.SetAttribute("classname", "AitherZero.$($Results.Category)")
        $testcase.SetAttribute("name", $result.SuiteName)
        $testcase.SetAttribute("time", $result.Duration.TotalSeconds)

        if ($result.Result -eq 'Failed') {
            $failure = $xml.CreateElement("failure")
            $failure.SetAttribute("message", "Test suite failed")
            $failure.InnerText = $result.Error ?? "Unknown error"
            $testcase.AppendChild($failure) | Out-Null
        } elseif ($result.Result -eq 'Skipped') {
            $skipped = $xml.CreateElement("skipped")
            $testcase.AppendChild($skipped) | Out-Null
        }

        $testsuite.AppendChild($testcase) | Out-Null
    }

    $xml.Save($OutputPath)
}

# Main execution
try {
    Show-TestRunnerBanner

    # Initialize test environment
    Initialize-TestEnvironment

    # Execute tests
    $results = Invoke-TestExecution

    # Show results
    Show-TestResults -Results $results

    # Export results
    Export-TestResults -Results $results -OutputPath $OutputPath

    # Calculate final performance metrics
    $totalDuration = (Get-Date) - $script:StartTime
    Write-TestRunnerLog "Total execution time: $($totalDuration.ToString('mm\:ss\.fff'))" -Level Success

    # Return results if PassThru
    if ($PassThru) {
        return $results
    }

    # Exit with appropriate code
    if ($results.Success) {
        Write-TestRunnerLog "All tests completed successfully" -Level Success
        exit 0
    } else {
        Write-TestRunnerLog "Some tests failed" -Level Error
        exit 1
    }

} catch {
    Write-TestRunnerLog "Test execution failed: $($_.Exception.Message)" -Level Error
    Write-TestRunnerLog "Stack trace: $($_.ScriptStackTrace)" -Level Debug
    exit 2
} finally {
    # Cleanup
    Remove-Variable -Name AITHERZERO_TEST_MODE -Scope Global -ErrorAction SilentlyContinue
}