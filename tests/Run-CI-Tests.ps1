#Requires -Version 7.0

<#
.SYNOPSIS
    Optimized test runner for CI/CD environments
.DESCRIPTION
    Runs focused, fast tests suitable for CI/CD pipelines with minimal dependencies
.PARAMETER TestSuite
    Which test suite to run: Core, Entry, PowerShell, All
.PARAMETER OutputFormat
    Output format: Console, JUnit, Both
.PARAMETER Timeout
    Test execution timeout in seconds (default: 300)
.EXAMPLE
    ./Run-CI-Tests.ps1 -TestSuite All -OutputFormat Both
#>

param(
    [ValidateSet('Core', 'Entry', 'PowerShell', 'All')]
    [string]$TestSuite = 'All',
    
    [ValidateSet('Console', 'JUnit', 'Both')]
    [string]$OutputFormat = 'Both',
    
    [int]$Timeout = 300
)

# Set error handling
$ErrorActionPreference = 'Stop'

Write-Host "`n🚀 AitherZero CI Test Runner" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Test Suite: $TestSuite" -ForegroundColor Yellow
Write-Host "Output Format: $OutputFormat" -ForegroundColor Yellow
Write-Host "Timeout: ${Timeout}s" -ForegroundColor Yellow
Write-Host ""

# Ensure Pester is available
if (-not (Get-Module -ListAvailable Pester)) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -AllowClobber -Scope CurrentUser -MinimumVersion 5.0.0
}

Import-Module Pester -Force

# Test definitions
$tests = @{
    'Core' = @{
        Path = './tests/Core.Tests.ps1'
        Description = 'Core functionality and module loading'
        OutputFile = 'core-test-results.xml'
    }
    'Entry' = @{
        Path = './tests/EntryPoint-Validation.Tests.ps1'
        Description = 'Entry point validation and launcher scripts'
        OutputFile = 'entry-test-results.xml'
    }
    'PowerShell' = @{
        Path = './tests/PowerShell-Version.Tests.ps1'
        Description = 'PowerShell version compatibility'
        OutputFile = 'ps-version-test-results.xml'
    }
}

# Determine which tests to run
$testsToRun = if ($TestSuite -eq 'All') { 
    $tests.Keys 
} else { 
    @($TestSuite) 
}

$allResults = @()
$totalTests = 0
$totalPassed = 0
$totalFailed = 0
$startTime = Get-Date

try {
    foreach ($testName in $testsToRun) {
        $test = $tests[$testName]
        
        # Check if test file exists
        if (-not (Test-Path $test.Path)) {
            Write-Warning "Test file not found: $($test.Path)"
            continue
        }
        
        Write-Host "📋 Running $testName Tests: $($test.Description)" -ForegroundColor Yellow
        
        # Configure Pester
        $config = New-PesterConfiguration
        $config.Run.Path = $test.Path
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Normal'
        
        # Set timeout if supported (Pester 5.4+)
        try {
            $config.Run.Timeout = $Timeout
        } catch {
            Write-Verbose "Timeout property not supported in this Pester version"
        }
        
        # Configure output formats
        if ($OutputFormat -in @('JUnit', 'Both')) {
            $config.TestResult.Enabled = $true
            $config.TestResult.OutputFormat = 'JUnitXml'
            $config.TestResult.OutputPath = $test.OutputFile
        }
        
        # Run tests with timeout
        $testStartTime = Get-Date
        $results = Invoke-Pester -Configuration $config
        $testDuration = (Get-Date) - $testStartTime
        
        # Store results
        $allResults += [PSCustomObject]@{
            TestSuite = $testName
            TotalCount = $results.TotalCount
            PassedCount = $results.PassedCount
            FailedCount = $results.FailedCount
            SkippedCount = $results.SkippedCount
            Duration = $testDuration.TotalSeconds
            Result = if ($results.FailedCount -eq 0) { 'Passed' } else { 'Failed' }
        }
        
        $totalTests += $results.TotalCount
        $totalPassed += $results.PassedCount
        $totalFailed += $results.FailedCount
        
        # Report individual test suite results
        $status = if ($results.FailedCount -eq 0) { "✅ PASSED" } else { "❌ FAILED" }
        Write-Host "  $status - $($results.PassedCount)/$($results.TotalCount) tests in $([math]::Round($testDuration.TotalSeconds, 2))s" -ForegroundColor $(if ($results.FailedCount -eq 0) { 'Green' } else { 'Red' })
        
        if ($results.FailedCount -gt 0) {
            Write-Host "  Failed tests:" -ForegroundColor Red
            foreach ($failure in $results.Failed) {
                Write-Host "    - $($failure.ExpandedName)" -ForegroundColor Red
            }
        }
        
        Write-Host ""
    }
    
    # Final summary
    $totalDuration = (Get-Date) - $startTime
    Write-Host "📊 CI Test Summary" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $totalPassed" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -eq 0) { 'Green' } else { 'Red' })
    Write-Host "Duration: $([math]::Round($totalDuration.TotalSeconds, 2))s" -ForegroundColor Cyan
    Write-Host ""
    
    # Detailed results table
    if ($allResults.Count -gt 1) {
        Write-Host "📋 Test Suite Details:" -ForegroundColor Cyan
        $allResults | Format-Table -Property TestSuite, TotalCount, PassedCount, FailedCount, @{Name='Duration(s)'; Expression={[math]::Round($_.Duration, 2)}}, Result -AutoSize
    }
    
    # Generate summary file for CI
    $summary = @{
        TotalTests = $totalTests
        TotalPassed = $totalPassed
        TotalFailed = $totalFailed
        TotalDuration = $totalDuration.TotalSeconds
        TestSuites = $allResults
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Success = ($totalFailed -eq 0)
    }
    
    $summaryPath = 'ci-test-summary.json'
    $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $summaryPath -Encoding UTF8
    Write-Host "📄 Test summary exported to: $summaryPath" -ForegroundColor Blue
    
    # Exit with appropriate code
    if ($totalFailed -gt 0) {
        Write-Host "❌ CI Tests Failed: $totalFailed tests failed" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ All CI Tests Passed!" -ForegroundColor Green
        exit 0
    }
    
} catch {
    Write-Host "💥 CI Test Execution Failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}