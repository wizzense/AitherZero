#Requires -Version 7.0

<#
.SYNOPSIS
    Master test runner for all OpenTofu Lab Automation modules

.DESCRIPTION
    This script runs comprehensive tests for all modules in the OpenTofu Lab Automation project.
    It includes unit tests, integration tests, and validation tests for each module.

.PARAMETER ModuleName
    Specific module to test. If not specified, all modules will be tested.

.PARAMETER TestType
    Type of tests to run: Unit, Integration, All (default: All)

.PARAMETER OutputFormat
    Output format for test results: NUnitXml, JUnitXml, NUnit2.5, Console (default: Console)

.PARAMETER OutputFile
    Path to save test results file

.PARAMETER Parallel
    Run tests in parallel for better performance

.PARAMETER PassThru
    Return test results object

.EXAMPLE
    .\Run-AllModuleTests.ps1
    Runs all tests for all modules

.EXAMPLE
    .\Run-AllModuleTests.ps1 -ModuleName "Logging" -TestType Unit
    Runs only unit tests for the Logging module

.EXAMPLE
    .\Run-AllModuleTests.ps1 -Parallel -OutputFile "TestResults.xml" -OutputFormat NUnitXml
    Runs all tests in parallel and saves results to XML file
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Logging", "ParallelExecution", "ScriptManager", "TestingFramework",
                 "BackupManager", "DevEnvironment", "LabRunner", "UnifiedMaintenance", "PatchManager")]
    [string]$ModuleName,

    [Parameter()]
    [ValidateSet("Unit", "Integration", "All")]
    [string]$TestType = "All",

    [Parameter()]
    [ValidateSet("NUnitXml", "JUnitXml", "NUnit2.5", "Console")]
    [string]$OutputFormat = "Console",

    [Parameter()]
    [string]$OutputFile,

    [Parameter()]
    [switch]$Parallel,

    [Parameter()]
    [switch]$PassThru,

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [ValidateSet("JaCoCo", "Cobertura", "CoverageGutters")]
    [string]$CoverageFormat = "JaCoCo",

    [Parameter()]
    [string]$CoverageOutputPath
)

# Set up paths
$projectRoot = Split-Path $PSScriptRoot -Parent
$testsRoot = Join-Path $projectRoot "tests\unit\modules"

Write-Host "🧪 OpenTofu Lab Automation - Module Test Runner" -ForegroundColor Cyan
Write-Host "=" * 60

# Import required modules
if (-not (Get-Module Pester -ListAvailable)) {
    Write-Error "Pester module is required but not installed. Please install Pester 5.0 or later."
    exit 1
}

Import-Module Pester -Force

# Get list of modules to test
$modulesToTest = if ($ModuleName) {
    @($ModuleName)
} else {
    @("Logging", "ParallelExecution", "ScriptManager", "TestingFramework",
      "BackupManager", "DevEnvironment", "LabRunner", "UnifiedMaintenance", "PatchManager")
}

Write-Host "📋 Modules to test: $($modulesToTest -join ', ')" -ForegroundColor Yellow

# Configure Pester
$pesterConfig = @{
    Run = @{
        Path = @()
        PassThru = $true
    }
    Output = @{
        Verbosity = 'Normal'
    }
    Should = @{
        ErrorAction = 'Continue'
    }
}

# Add code coverage configuration if requested
if ($CodeCoverage) {
    Write-Host "  📊 Code coverage enabled - Format: $CoverageFormat" -ForegroundColor Cyan
    
    # Determine coverage paths based on modules being tested
    $coveragePaths = @()
    foreach ($module in $modulesToTest) {
        $modulePath = Join-Path $projectRoot "aither-core\modules\$module"
        if (Test-Path $modulePath) {
            $coveragePaths += Join-Path $modulePath "*.ps1"
            $coveragePaths += Join-Path $modulePath "*.psm1"
        }
    }
    
    $pesterConfig.CodeCoverage = @{
        Enabled = $true
        Path = $coveragePaths
        OutputFormat = $CoverageFormat
        OutputPath = if ($CoverageOutputPath) { 
            $CoverageOutputPath 
        } else { 
            Join-Path $projectRoot "tests\results\coverage.$($CoverageFormat.ToLower())"
        }
        OutputEncoding = 'UTF8'
        ExcludeTests = $true
        UseBreakpoints = $false
        SingleHitBreakpoints = $true
    }
}

# Add test result configuration if output file specified
if ($OutputFile) {
    $pesterConfig.TestResult = @{
        Enabled = $true
        OutputPath = $OutputFile
        OutputFormat = $OutputFormat
    }
}

# Collect test files
$allTestFiles = @()
foreach ($module in $modulesToTest) {
    $moduleTestPath = Join-Path $testsRoot $module
    if (Test-Path $moduleTestPath) {
        $testFiles = Get-ChildItem -Path $moduleTestPath -Filter "*.Tests.ps1" -Recurse

        # Filter by test type if specified
        if ($TestType -ne "All") {
            $testFiles = $testFiles | Where-Object {
                $_.Name -match $TestType -or
                ($TestType -eq "Unit" -and $_.Name -notmatch "Integration")
            }
        }

        $allTestFiles += $testFiles.FullName
        Write-Host "  ✓ Found $($testFiles.Count) test file(s) for $module" -ForegroundColor Green
    } else {
        Write-Warning "No test directory found for module: $module"
    }
}

if ($allTestFiles.Count -eq 0) {
    Write-Error "No test files found matching the criteria."
    exit 1
}

$pesterConfig.Run.Path = $allTestFiles

Write-Host "`n🚀 Starting test execution..." -ForegroundColor Green
Write-Host "Test files: $($allTestFiles.Count)"
Write-Host "Parallel execution: $($Parallel.IsPresent)"

# Run tests
$startTime = Get-Date

if ($Parallel.IsPresent) {
    # Run tests in parallel
    Write-Host "Running tests in parallel..." -ForegroundColor Yellow

    $jobs = @()
    foreach ($testFile in $allTestFiles) {
        $jobs += Start-Job -ScriptBlock {
            param($TestFilePath)
            Import-Module Pester -Force
            $config = New-PesterConfiguration
            $config.Run.Path = $TestFilePath
            $config.Run.PassThru = $true
            $config.Output.Verbosity = 'Minimal'
            Invoke-Pester -Configuration $config
        } -ArgumentList $testFile
    }

    Write-Host "Waiting for $($jobs.Count) test jobs to complete..." -ForegroundColor Yellow
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    # Aggregate results
    $aggregateResult = [PSCustomObject]@{
        TotalCount = ($results | Measure-Object TotalCount -Sum).Sum
        PassedCount = ($results | Measure-Object PassedCount -Sum).Sum
        FailedCount = ($results | Measure-Object FailedCount -Sum).Sum
        SkippedCount = ($results | Measure-Object SkippedCount -Sum).Sum
        Duration = [TimeSpan]::FromMilliseconds(($results | Measure-Object Duration -Property TotalMilliseconds -Sum).Sum)
        Results = $results
    }
} else {
    # Run tests sequentially
    $config = New-PesterConfiguration
    $config.Run.Path = $allTestFiles
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Normal'

    if ($OutputFile) {
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = $OutputFile
        $config.TestResult.OutputFormat = $OutputFormat
    }

    # Add code coverage if enabled
    if ($CodeCoverage) {
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = $pesterConfig.CodeCoverage.Path
        $config.CodeCoverage.OutputFormat = $pesterConfig.CodeCoverage.OutputFormat
        $config.CodeCoverage.OutputPath = $pesterConfig.CodeCoverage.OutputPath
        $config.CodeCoverage.OutputEncoding = $pesterConfig.CodeCoverage.OutputEncoding
        $config.CodeCoverage.ExcludeTests = $true
        $config.CodeCoverage.UseBreakpoints = $false
        $config.CodeCoverage.SingleHitBreakpoints = $true
    }

    $aggregateResult = Invoke-Pester -Configuration $config
}

$endTime = Get-Date
$duration = $endTime - $startTime

# Display results
Write-Host "`n" + "=" * 60
Write-Host "📊 TEST RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60

$passRate = if ($aggregateResult.TotalCount -gt 0) {
    [math]::Round(($aggregateResult.PassedCount / $aggregateResult.TotalCount) * 100, 2)
} else { 0 }

Write-Host "Total Tests:    $($aggregateResult.TotalCount)" -ForegroundColor White
Write-Host "Passed:         $($aggregateResult.PassedCount)" -ForegroundColor Green
Write-Host "Failed:         $($aggregateResult.FailedCount)" -ForegroundColor $(if ($aggregateResult.FailedCount -eq 0) { "Green" } else { "Red" })
Write-Host "Skipped:        $($aggregateResult.SkippedCount)" -ForegroundColor Yellow
Write-Host "Pass Rate:      $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 75) { "Yellow" } else { "Red" })
Write-Host "Duration:       $($duration.ToString('mm\:ss\.fff'))" -ForegroundColor White

if ($OutputFile) {
    Write-Host "Results saved:  $OutputFile" -ForegroundColor Cyan
}

# Display code coverage results if enabled
if ($CodeCoverage -and $aggregateResult.CodeCoverage) {
    $coverage = $aggregateResult.CodeCoverage
    $coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) {
        [Math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2)
    } else { 0 }
    
    Write-Host "`n📊 CODE COVERAGE" -ForegroundColor Cyan
    Write-Host "Coverage:       $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { "Green" } elseif ($coveragePercent -ge 60) { "Yellow" } else { "Red" })
    Write-Host "Commands:       $($coverage.NumberOfCommandsExecuted)/$($coverage.NumberOfCommandsAnalyzed)" -ForegroundColor White
    Write-Host "Report saved:   $($pesterConfig.CodeCoverage.OutputPath)" -ForegroundColor Cyan
}

# Show failed tests details
if ($aggregateResult.FailedCount -gt 0) {
    Write-Host "`n FAILFAILED TESTS:" -ForegroundColor Red
    if ($Parallel.IsPresent -and $aggregateResult.Results) {
        foreach ($result in $aggregateResult.Results) {
            if ($result.FailedCount -gt 0) {
                $result.Failed | ForEach-Object {
                    Write-Host "  • $($_.ExpandedName)" -ForegroundColor Red
                    if ($_.ErrorRecord) {
                        Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
                    }
                }
            }
        }
    } else {
        $aggregateResult.Failed | ForEach-Object {
            Write-Host "  • $($_.ExpandedName)" -ForegroundColor Red
            if ($_.ErrorRecord) {
                Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor DarkRed
            }
        }
    }
}

# Module-specific summary
Write-Host "`n📈 MODULE BREAKDOWN:" -ForegroundColor Cyan
foreach ($module in $modulesToTest) {
    $moduleTests = if ($Parallel.IsPresent -and $aggregateResult.Results) {
        $aggregateResult.Results | Where-Object { $_.Configuration.Run.Path -like "*$module*" }
    } else {
        $aggregateResult.Tests | Where-Object { $_.Path -like "*$module*" }
    }

    if ($moduleTests) {
        $modulePassCount = if ($Parallel.IsPresent) {
            ($moduleTests | Measure-Object PassedCount -Sum).Sum
        } else {
            ($moduleTests | Where-Object Result -eq "Passed").Count
        }

        $moduleTotalCount = if ($Parallel.IsPresent) {
            ($moduleTests | Measure-Object TotalCount -Sum).Sum
        } else {
            $moduleTests.Count
        }

        $modulePassRate = if ($moduleTotalCount -gt 0) {
            [math]::Round(($modulePassCount / $moduleTotalCount) * 100, 1)
        } else { 0 }

        $status = if ($modulePassRate -eq 100) { "✅" } elseif ($modulePassRate -ge 75) { "⚠️" } else { "❌" }
        Write-Host "  $status $module`: $modulePassCount/$moduleTotalCount ($modulePassRate%)" -ForegroundColor White
    }
}

Write-Host "`n🏁 Test execution completed!" -ForegroundColor Green

# Exit with appropriate code
if ($aggregateResult.FailedCount -eq 0) {
    Write-Host "All tests passed! 🎉" -ForegroundColor Green
    $exitCode = 0
} else {
    Write-Host "Some tests failed. Please review the results above." -ForegroundColor Red
    $exitCode = 1
}

if ($PassThru) {
    return $aggregateResult
}

exit $exitCode
