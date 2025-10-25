#Requires -Version 7.0

<#
.SYNOPSIS
    Parse Pester test results for analysis
.DESCRIPTION
    Parses Pester XML/JSON output files to extract test failures,
    coverage data, and performance metrics.
.NOTES
    Stage: Testing
    Category: Analysis
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResultsFile,

    [ValidateSet('XML', 'JSON', 'Auto')]
    [string]$Format = 'Auto',

    [switch]$FailuresOnly,

    [switch]$IncludeCoverage,

    [switch]$IncludePerformance,

    [switch]$GroupByDescribe,

    [ValidateSet('Summary', 'Detailed', 'Full')]
    [string]$OutputFormat = 'Summary'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Parsing Pester results..." -ForegroundColor Cyan

# Validate file exists
if (-not (Test-Path $ResultsFile)) {
    Write-Error "Results file not found: $ResultsFile"
    exit 1
}

# Detect format
if ($Format -eq 'Auto') {
    $extension = [System.IO.Path]::GetExtension($ResultsFile).ToLower()
    $Format = switch ($extension) {
        '.xml' { 'XML' }
        '.json' { 'JSON' }
        default { 'XML' }
    }
}

Write-Host "Format: $Format" -ForegroundColor Gray

# Parse results
$results = @{
    TotalTests = 0
    Passed = 0
    Failed = 0
    Skipped = 0
    Pending = 0
    Failures = @()
    Coverage = $null
    Performance = @()
    Duration = 0
}

if ($Format -eq 'XML') {
    # Parse NUnit XML format
    $xml = [xml](Get-Content $ResultsFile)

    # Get summary
    $testRun = $xml.SelectSingleNode('//test-run')
    if ($testRun) {
        $results.TotalTests = [int]$testRun.GetAttribute('total')
        $results.Passed = [int]$testRun.GetAttribute('passed')
        $results.Failed = [int]$testRun.GetAttribute('failed')
        $results.Skipped = [int]$testRun.GetAttribute('skipped')
        $results.Duration = [double]$testRun.GetAttribute('duration')
    }

    # Get failures
    $failedTests = $xml.SelectNodes("//test-case[@result='Failed']")
    foreach ($test in $failedTests) {
        $failure = $test.SelectSingleNode('failure')

        $results.Failures += [PSCustomObject]@{
            Describe = $test.GetAttribute('classname')
            Context = $test.GetAttribute('methodname')
            Name = $test.GetAttribute('name')
            Message = $failure.GetAttribute('message')
            StackTrace = $failure.InnerText
            Duration = [double]$test.GetAttribute('duration')
            File = $null  # Not available in NUnit format
            Line = $null
        }
    }

    # Get skipped/pending
    $skippedTests = $xml.SelectNodes("//test-case[@result='Skipped']")
    $results.Skipped = $skippedTests.Count

} else {
    # Parse JSON format (Pester 5+)
    $json = Get-Content $ResultsFile | ConvertFrom-Json

    # Get summary
    $results.TotalTests = $json.TotalCount
    $results.Passed = $json.PassedCount
    $results.Failed = $json.FailedCount
    $results.Skipped = $json.SkippedCount
    $results.Pending = $json.PendingCount
    $results.Duration = $json.Duration.TotalSeconds

    # Recursive function to extract tests
    function Get-Tests {
        param($Container)

        foreach ($block in $Container.Blocks) {
            foreach ($test in $block.Tests) {
                if ($test.Result -eq 'Failed' -or -not $FailuresOnly) {
                    [PSCustomObject]@{
                        Describe = $block.Name
                        Context = $block.Parent.Name
                        Name = $test.Name
                        Result = $test.Result
                        Message = $test.ErrorRecord.DisplayErrorMessage
                        StackTrace = $test.ErrorRecord.DisplayStackTrace
                        Duration = $test.Duration.TotalSeconds
                        File = $test.ScriptBlock.File
                        Line = $test.ScriptBlock.StartPosition.StartLine
                    }
                }
            }

            # Recurse into nested blocks
            if ($block.Blocks) {
                Get-Tests -Container $block
            }
        }
    }

    # Extract all tests
    $allTests = foreach ($container in $json.Containers) {
        Get-Tests -Container $container
    }

    $results.Failures = $allTests | Where-Object { $_.Result -eq 'Failed' }

    # Get coverage if available
    if ($json.CodeCoverage -and $IncludeCoverage) {
        $results.Coverage = [PSCustomObject]@{
            CoveragePercent = $json.CodeCoverage.CoveragePercent
            CommandsExecuted = $json.CodeCoverage.CommandsExecutedCount
            CommandsTotal = $json.CodeCoverage.CommandsAnalyzedCount
            FilesCovered = $json.CodeCoverage.FilesAnalyzedCount
            MissedCommands = $json.CodeCoverage.MissedCommands
        }
    }
}

# Group by Describe if requested
if ($GroupByDescribe -and $results.Failures.Count -gt 0) {
    $grouped = $results.Failures | Group-Object Describe

    Write-Host "`nFailures by test suite:" -ForegroundColor Yellow
    foreach ($group in $grouped | Sort-Object Count -Descending) {
        Write-Host "  $($group.Name): $($group.Count) failures" -ForegroundColor Gray
    }
}

# Performance analysis
if ($IncludePerformance -and $results.Failures.Count -gt 0) {
    $slowTests = $results.Failures | Where-Object { $_.Duration -gt 1 } | Sort-Object Duration -Descending

    if ($slowTests) {
        Write-Host "`nSlow tests (>1 second):" -ForegroundColor Yellow
        foreach ($test in $slowTests | Select-Object -First 5) {
            Write-Host "  $($test.Name): $([Math]::Round($test.Duration, 2))s" -ForegroundColor Gray
        }
    }
}

# Output based on format
switch ($OutputFormat) {
    'Summary' {
        Write-Host "`nTest Results Summary:" -ForegroundColor Cyan
        Write-Host "  Total Tests: $($results.TotalTests)" -ForegroundColor Gray
        Write-Host "  Passed: $($results.Passed)" -ForegroundColor Green
        Write-Host "  Failed: $($results.Failed)" -ForegroundColor Red
        Write-Host "  Skipped: $($results.Skipped)" -ForegroundColor Yellow
        Write-Host "  Duration: $([Math]::Round($results.Duration, 2))s" -ForegroundColor Gray

        if ($results.Coverage) {
            Write-Host "`nCode Coverage:" -ForegroundColor Cyan
            Write-Host "  Coverage: $($results.Coverage.CoveragePercent)%" -ForegroundColor $(if ($results.Coverage.CoveragePercent -ge 80) { 'Green' } elseif ($results.Coverage.CoveragePercent -ge 60) { 'Yellow' } else { 'Red' })
            Write-Host "  Commands: $($results.Coverage.CommandsExecuted)/$($results.Coverage.CommandsTotal)" -ForegroundColor Gray
        }

        if ($results.Failed -gt 0) {
            Write-Host "`nTop Failures:" -ForegroundColor Red
            foreach ($failure in $results.Failures | Select-Object -First 5) {
                Write-Host "  ❌ $($failure.Name)" -ForegroundColor Red
                if ($failure.Message) {
                    Write-Host "     $($failure.Message -split "`n" | Select-Object -First 1)" -ForegroundColor Gray
                }
            }
        }
    }

    'Detailed' {
        # Output detailed results
        $results | ConvertTo-Json -Depth 3
    }

    'Full' {
        # Output full parsed data
        [PSCustomObject]@{
            Summary = [PSCustomObject]@{
                Total = $results.TotalTests
                Passed = $results.Passed
                Failed = $results.Failed
                Skipped = $results.Skipped
                Duration = $results.Duration
            }
            Failures = $results.Failures
            Coverage = $results.Coverage
            Performance = $results.Performance
        } | ConvertTo-Json -Depth 5
    }
}

# Set exit code based on failures
if ($results.Failed -gt 0) {
    exit 1
}