#!/usr/bin/env pwsh
#Requires -Version 7.0
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

<#
.SYNOPSIS
    Comprehensive test runner for AitherZero with 100% coverage goal
.DESCRIPTION
    Executes all test suites with coverage analysis and detailed reporting
.PARAMETER TestType
    Type of tests to run: Unit, Integration, E2E, or All
.PARAMETER Coverage
    Enable code coverage analysis
.PARAMETER OutputFormat
    Output format for results: Console, JUnit, NUnit, HTML
.PARAMETER Parallel
    Run tests in parallel for faster execution
.PARAMETER FailFast
    Stop on first test failure
.EXAMPLE
    ./Run-AllTests.ps1 -TestType All -Coverage -OutputFormat JUnit
#>

[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'E2E', 'All')]
    [string]$TestType = 'All',
    
    [switch]$Coverage,
    
    [ValidateSet('Console', 'JUnit', 'NUnit', 'HTML')]
    [string[]]$OutputFormat = @('Console'),
    
    [switch]$Parallel,
    
    [switch]$FailFast,
    
    [string]$OutputPath = "./tests/results",
    
    [switch]$Detailed
)

# Initialize
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = $PSScriptRoot
$script:TestsRoot = Join-Path $script:ProjectRoot "tests"
$script:StartTime = Get-Date

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

# Import test helpers
$testHelpersPath = Join-Path $script:TestsRoot "TestHelpers.psm1"
if (Test-Path $testHelpersPath) {
    Import-Module $testHelpersPath -Force
}

# Initialize test environment
Write-Host "`n" -NoNewline
Write-Host "═" * 80 -ForegroundColor Cyan
Write-Host "  AitherZero Comprehensive Test Suite" -ForegroundColor Cyan
Write-Host "═" * 80 -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Test Configuration:" -ForegroundColor Yellow
Write-Host "   Test Type: $TestType" -ForegroundColor Gray
Write-Host "   Coverage: $($Coverage ? 'Enabled' : 'Disabled')" -ForegroundColor Gray
Write-Host "   Output Format: $($OutputFormat -join ', ')" -ForegroundColor Gray
Write-Host "   Parallel: $($Parallel ? 'Yes' : 'No')" -ForegroundColor Gray
Write-Host ""

# Define test suites
$testSuites = @{
    Unit = @{
        Path = Join-Path $script:TestsRoot "unit"
        Description = "Unit Tests"
        CriticalFiles = @(
            "bootstrap.ps1",
            "AitherZero.psm1",
            "Initialize-CleanEnvironment.ps1",
            "Start-AitherZero.ps1"
        )
    }
    Integration = @{
        Path = Join-Path $script:TestsRoot "integration"
        Description = "Integration Tests"
        CriticalFiles = @(
            "domains/utilities/Logging.psm1",
            "domains/configuration/Configuration.psm1",
            "domains/automation/OrchestrationEngine.psm1"
        )
    }
    E2E = @{
        Path = Join-Path $script:TestsRoot "e2e"
        Description = "End-to-End Tests"
        CriticalFiles = @(
            "bootstrap.ps1",
            "Start-AitherZero.ps1"
        )
    }
}

# Determine which suites to run
$suitesToRun = if ($TestType -eq 'All') {
    $testSuites.Keys
} else {
    @($TestType)
}

# Prepare Pester configuration
$pesterConfig = New-PesterConfiguration

# Set test paths
$testPaths = @()
foreach ($suite in $suitesToRun) {
    $suitePath = $testSuites[$suite].Path
    if (Test-Path $suitePath) {
        $testPaths += $suitePath
        Write-Host "✓ Found $($testSuites[$suite].Description) at: $suitePath" -ForegroundColor Green
    } else {
        Write-Host "⚠ Missing $($testSuites[$suite].Description) at: $suitePath" -ForegroundColor Yellow
    }
}

if ($testPaths.Count -eq 0) {
    Write-Error "No test paths found for test type: $TestType"
    exit 1
}

$pesterConfig.Run.Path = $testPaths
$pesterConfig.Run.PassThru = $true
$pesterConfig.Run.Exit = $false

# Configure output
$pesterConfig.Output.Verbosity = if ($Detailed) { 'Detailed' } else { 'Normal' }

# Configure code coverage if requested
if ($Coverage) {
    Write-Host "`n📊 Configuring Code Coverage..." -ForegroundColor Yellow
    
    # Get all critical files for coverage
    $coverageFiles = @()
    
    # Add main files
    $coverageFiles += Join-Path $script:ProjectRoot "bootstrap.ps1"
    $coverageFiles += Join-Path $script:ProjectRoot "AitherZero.psm1"
    $coverageFiles += Join-Path $script:ProjectRoot "AitherZero.psd1"
    $coverageFiles += Join-Path $script:ProjectRoot "Initialize-CleanEnvironment.ps1"
    $coverageFiles += Join-Path $script:ProjectRoot "Start-AitherZero.ps1"
    
    # Add all module files
    $moduleFiles = Get-ChildItem -Path (Join-Path $script:ProjectRoot "domains") -Filter "*.psm1" -Recurse
    $coverageFiles += $moduleFiles.FullName
    
    # Add automation scripts
    $automationScripts = Get-ChildItem -Path (Join-Path $script:ProjectRoot "automation-scripts") -Filter "*.ps1" | 
        Where-Object { $_.Name -match '^\d{4}_' }
    $coverageFiles += $automationScripts.FullName
    
    # Filter to existing files
    $coverageFiles = $coverageFiles | Where-Object { Test-Path $_ }
    
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = $coverageFiles
    $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "coverage-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
    $pesterConfig.CodeCoverage.CoveragePercentTarget = 100  # Our goal!
    
    Write-Host "   Analyzing $($coverageFiles.Count) files for coverage" -ForegroundColor Gray
}

# Configure test output formats
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($format in $OutputFormat) {
    switch ($format) {
        'JUnit' {
            $pesterConfig.TestResult.Enabled = $true
            $pesterConfig.TestResult.OutputFormat = 'JUnitXml'
            $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "results-junit-$timestamp.xml"
        }
        'NUnit' {
            $pesterConfig.TestResult.Enabled = $true
            $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
            $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "results-nunit-$timestamp.xml"
        }
    }
}

# Run tests
Write-Host "`n🚀 Running Tests..." -ForegroundColor Cyan
Write-Host "═" * 80 -ForegroundColor DarkGray

try {
    # Clean environment before running tests
    if (Get-Command Clear-TestEnvironment -ErrorAction SilentlyContinue) {
        Clear-TestEnvironment
    }
    
    # Run Pester tests
    $results = Invoke-Pester -Configuration $pesterConfig
    
    # Calculate metrics
    $duration = (Get-Date) - $script:StartTime
    $passRate = if ($results.TotalCount -gt 0) {
        [math]::Round(($results.PassedCount / $results.TotalCount) * 100, 2)
    } else { 0 }
    
    # Display results summary
    Write-Host "`n" -NoNewline
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host "  Test Results Summary" -ForegroundColor Cyan
    Write-Host "═" * 80 -ForegroundColor Cyan
    Write-Host ""
    
    # Test counts
    Write-Host "📈 Test Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Tests: $($results.TotalCount)" -ForegroundColor Gray
    Write-Host "   ✅ Passed: $($results.PassedCount)" -ForegroundColor Green
    Write-Host "   ❌ Failed: $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -eq 0) { 'Gray' } else { 'Red' })
    Write-Host "   ⏭️  Skipped: $($results.SkippedCount)" -ForegroundColor $(if ($results.SkippedCount -eq 0) { 'Gray' } else { 'Yellow' })
    Write-Host "   📊 Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { 'Green' } elseif ($passRate -ge 80) { 'Yellow' } else { 'Red' })
    Write-Host "   ⏱️  Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor Gray
    Write-Host ""
    
    # Coverage results
    if ($Coverage -and $results.CodeCoverage) {
        $coveragePercent = [math]::Round($results.CodeCoverage.CoveragePercent, 2)
        
        Write-Host "📊 Code Coverage:" -ForegroundColor Yellow
        Write-Host "   Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -eq 100) { 'Green' } elseif ($coveragePercent -ge 80) { 'Yellow' } else { 'Red' })
        Write-Host "   Covered Lines: $($results.CodeCoverage.CommandsExecutedCount)" -ForegroundColor Gray
        Write-Host "   Total Lines: $($results.CodeCoverage.CommandsAnalyzedCount)" -ForegroundColor Gray
        Write-Host "   Missed Lines: $($results.CodeCoverage.CommandsMissedCount)" -ForegroundColor $(if ($results.CodeCoverage.CommandsMissedCount -eq 0) { 'Green' } else { 'Yellow' })
        
        # Show files with less than 100% coverage
        if ($results.CodeCoverage.CommandsMissedCount -gt 0 -and $Detailed) {
            Write-Host "`n   Files needing coverage improvement:" -ForegroundColor Yellow
            foreach ($file in $results.CodeCoverage.AnalyzedFiles) {
                $fileCoverage = $results.CodeCoverage.FileCoverage[$file]
                if ($fileCoverage -and $fileCoverage.CoveragePercent -lt 100) {
                    $fileName = Split-Path $file -Leaf
                    Write-Host "     - $fileName`: $([math]::Round($fileCoverage.CoveragePercent, 1))%" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
    
    # Failed test details
    if ($results.FailedCount -gt 0) {
        Write-Host "❌ Failed Tests:" -ForegroundColor Red
        foreach ($test in $results.Failed) {
            Write-Host "   - $($test.ExpandedPath)" -ForegroundColor Red
            if ($Detailed) {
                Write-Host "     Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            }
        }
        Write-Host ""
    }
    
    # Success/Failure message
    if ($results.FailedCount -eq 0 -and $passRate -eq 100) {
        Write-Host "✅ ALL TESTS PASSED! 🎉" -ForegroundColor Green -BackgroundColor DarkGreen
        if ($Coverage -and $results.CodeCoverage.CoveragePercent -eq 100) {
            Write-Host "🏆 100% CODE COVERAGE ACHIEVED! 🏆" -ForegroundColor Green -BackgroundColor DarkGreen
        }
    } else {
        Write-Host "⚠️  Some tests failed or were skipped" -ForegroundColor Yellow
        Write-Host "   Run with -Detailed for more information" -ForegroundColor Gray
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "═" * 80 -ForegroundColor Cyan
    
    # Output file locations
    if ($OutputFormat.Count -gt 1 -or $OutputFormat[0] -ne 'Console') {
        Write-Host "`n📁 Output Files:" -ForegroundColor Yellow
        if ($pesterConfig.TestResult.OutputPath) {
            Write-Host "   Test Results: $($pesterConfig.TestResult.OutputPath)" -ForegroundColor Gray
        }
        if ($pesterConfig.CodeCoverage.OutputPath) {
            Write-Host "   Coverage Report: $($pesterConfig.CodeCoverage.OutputPath)" -ForegroundColor Gray
        }
    }
    
    # Exit code
    $exitCode = if ($results.FailedCount -eq 0) { 0 } else { 1 }
    
    # Check coverage threshold
    if ($Coverage -and $results.CodeCoverage.CoveragePercent -lt 100) {
        Write-Host "`n⚠️  Coverage is below 100% target" -ForegroundColor Yellow
        if ($exitCode -eq 0) { $exitCode = 2 }
    }
    
    exit $exitCode
    
} catch {
    Write-Host "`n❌ Test execution failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 99
}