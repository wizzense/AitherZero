#!/usr/bin/env pwsh
# Load shared test helpers for environment setup
. (Join-Path $PSScriptRoot 'helpers' 'TestHelpers.ps1')
#Requires -Version 7.0

<#
.SYNOPSIS
Master test runner for OpenTofu Lab Automation project

.DESCRIPTION
Orchestrates comprehensive testing across PowerShell modules, Python packages,
and project infrastructure. Provides unified reporting and CI/CD integration.

.PARAMETER TestSuite
Which test suite to run: All, PowerShell, Python, Smoke, Integration

.PARAMETER OutputFormat
Output format: Console, JUnit, JSON, HTML

.PARAMETER Parallel
Run tests in parallel where possible

.PARAMETER CreateReport
Generate comprehensive HTML report

.EXAMPLE
.\Run-MasterTests.ps1 -TestSuite All -OutputFormat HTML -CreateReport
Run all tests and generate HTML report

.EXAMPLE
.\Run-MasterTests.ps1 -TestSuite Smoke
Quick smoke test run
#>

param(
    [ValidateSet('All', 'PowerShell', 'Python', 'Smoke', 'Integration')]
    [string]$TestSuite,

    [ValidateSet('Console', 'JUnit', 'JSON', 'HTML')]
    [string]$OutputFormat,

    [switch]$Parallel,

    [switch]$CreateReport
)

# Set default values
if (-not $TestSuite) { $TestSuite = 'Smoke' }
if (-not $OutputFormat) { $OutputFormat = 'Console' }

# Set up environment
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent
$TestsRoot = $PSScriptRoot
$ResultsDir = Join-Path $TestsRoot "results"
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Environment setup
$env:PROJECT_ROOT = $ProjectRoot
$env:PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH
$env:PYTHON_MODULES_PATH = Join-Path $ProjectRoot "src/python"

# Ensure results directory exists
if (-not (Test-Path $ResultsDir)) {
    if (-not (Test-Path $ResultsDir)) { New-Item -Path $ResultsDir -ItemType Directory -Force | Out-Null }
}

Write-Information " -InformationAction ContinueDEPLOY OpenTofu Lab Automation - Master Test Runner" -ForegroundColor Cyan
Write-Information " -InformationAction Continue=" * 60 -ForegroundColor Gray
Write-Information " -InformationAction ContinueProject Root: $ProjectRoot" -ForegroundColor Gray
Write-Information " -InformationAction ContinueTest Suite: $TestSuite" -ForegroundColor Gray
Write-Information " -InformationAction ContinueOutput Format: $OutputFormat" -ForegroundColor Gray
Write-Information " -InformationAction ContinueTimestamp: $Timestamp" -ForegroundColor Gray
Write-Information " -InformationAction Continue=" * 60 -ForegroundColor Gray

# Test execution results
$testResults = @{
    PowerShell = $null
    Python = $null
    StartTime = Get-Date
    EndTime = $null
    TotalDuration = $null
    OverallStatus = 'UNKNOWN'
}

# PowerShell Tests
if ($TestSuite -in @('All', 'PowerShell', 'Smoke', 'Integration')) {    Write-Information " -InformationAction Continue`nPACKAGE Running PowerShell Tests..." -ForegroundColor Yellow

    try {
        $psTestScript = Join-Path $TestsRoot "Invoke-IntelligentTests.ps1"
        if (Test-Path $psTestScript) {
            $testType = if ($TestSuite -eq 'Smoke') { 'Smoke' }
                       elseif ($TestSuite -eq 'Integration') { 'Integration' }
                       elseif ($TestSuite -eq 'PowerShell') { 'All' }
                       else { 'All' }

            $psResult = & $psTestScript -TestType $testType -OutputFormat $OutputFormat
            $testResults.PowerShell = @{
                Status = if ($LASTEXITCODE -eq 0) { 'PASSED' } else { 'FAILED' }
                ExitCode = $LASTEXITCODE
                Output = $psResult
            }

            if ($LASTEXITCODE -eq 0) {
                Write-Information " -InformationAction ContinuePASS PowerShell tests completed successfully" -ForegroundColor Green
            } else {
                Write-Information " -InformationAction ContinueFAIL PowerShell tests failed" -ForegroundColor Red
            }
        } else {
            Write-Warning "PowerShell test script not found: $psTestScript"
            $testResults.PowerShell = @{
                Status = 'SKIPPED'
                Reason = 'Test script not found'
            }
        }
    }
    catch {
        Write-Error "Error running PowerShell tests: $($_.Exception.Message)"
        $testResults.PowerShell = @{
            Status = 'ERROR'
            Error = $_.Exception.Message
        }
    }
}

# Python Tests
if ($TestSuite -in @('All', 'Python', 'Smoke')) {
    Write-Information " -InformationAction Continue`n[SYMBOL] Running Python Tests..." -ForegroundColor Yellow

    try {
        $pythonTestScript = Join-Path $TestsRoot "test_python_modules.py"
        if (Test-Path $pythonTestScript) {
            # Check for Python
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonCmd) {
                $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
            }

            if ($pythonCmd) {
                $pyResult = & $pythonCmd.Source $pythonTestScript
                $testResults.Python = @{
                    Status = if ($LASTEXITCODE -eq 0) { 'PASSED' } else { 'FAILED' }
                    ExitCode = $LASTEXITCODE
                    Output = $pyResult
                }

                if ($LASTEXITCODE -eq 0) {
                    Write-Information " -InformationAction ContinuePASS Python tests completed successfully" -ForegroundColor Green
                } else {
                    Write-Information " -InformationAction ContinueFAIL Python tests failed" -ForegroundColor Red
                }
            } else {
                Write-Warning "Python not found in PATH"
                $testResults.Python = @{
                    Status = 'SKIPPED'
                    Reason = 'Python not available'
                }
            }
        } else {
            Write-Warning "Python test script not found: $pythonTestScript"
            $testResults.Python = @{
                Status = 'SKIPPED'
                Reason = 'Test script not found'
            }
        }
    }
    catch {
        Write-Error "Error running Python tests: $($_.Exception.Message)"
        $testResults.Python = @{
            Status = 'ERROR'
            Error = $_.Exception.Message
        }
    }
}

# Calculate overall results
$testResults.EndTime = Get-Date
$testResults.TotalDuration = $testResults.EndTime - $testResults.StartTime

# Determine overall status
$statuses = @()
if ($testResults.PowerShell) { $statuses += $testResults.PowerShell.Status }
if ($testResults.Python) { $statuses += $testResults.Python.Status }

if ($statuses -contains 'FAILED' -or $statuses -contains 'ERROR') {
    $testResults.OverallStatus = 'FAILED'
} elseif ($statuses -contains 'SKIPPED' -and $statuses.Count -eq ($statuses | Where-Object { $_ -eq 'SKIPPED' }).Count) {
    $testResults.OverallStatus = 'SKIPPED'
} elseif ($statuses -contains 'PASSED') {
    $testResults.OverallStatus = 'PASSED'
} else {
    $testResults.OverallStatus = 'UNKNOWN'
}

# Generate summary report
Write-Information " -InformationAction Continue`nREPORT Test Results Summary" -ForegroundColor Cyan
Write-Information " -InformationAction Continue=" * 60 -ForegroundColor Gray

if ($testResults.PowerShell) {
    $psStatusColor = switch ($testResults.PowerShell.Status) {
        'PASSED' { 'Green' }
        'FAILED' { 'Red' }
        'SKIPPED' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }
    Write-Information " -InformationAction ContinuePowerShell Tests: $($testResults.PowerShell.Status)" -ForegroundColor $psStatusColor
}

if ($testResults.Python) {
    $pyStatusColor = switch ($testResults.Python.Status) {
        'PASSED' { 'Green' }
        'FAILED' { 'Red' }
        'SKIPPED' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'Gray' }
    }
    Write-Information " -InformationAction ContinuePython Tests: $($testResults.Python.Status)" -ForegroundColor $pyStatusColor
}

$overallColor = switch ($testResults.OverallStatus) {
    'PASSED' { 'Green' }
    'FAILED' { 'Red' }
    'SKIPPED' { 'Yellow' }
    default { 'Gray' }
}

Write-Information " -InformationAction Continue=" * 60 -ForegroundColor Gray
Write-Information " -InformationAction ContinueOverall Status: $($testResults.OverallStatus)" -ForegroundColor $overallColor
Write-Information " -InformationAction ContinueTotal Duration: $($testResults.TotalDuration.ToString('mm\:ss'))" -ForegroundColor Gray

# Save results to JSON
$jsonReport = @{
    TestSuite = $TestSuite
    OutputFormat = $OutputFormat
    Timestamp = $Timestamp
    ProjectRoot = $ProjectRoot
    Results = $testResults
    Environment = @{
        OS = $PSVersionTable.OS
        PSVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        ProjectRoot = $env:PROJECT_ROOT
        ModulesPath = $env:PWSH_MODULES_PATH
        PythonPath = $env:PYTHON_MODULES_PATH
    }
} | ConvertTo-Json -Depth 10

$jsonReportPath = Join-Path $ResultsDir "master_test_results_$Timestamp.json"
$jsonReport | Out-File -FilePath $jsonReportPath -Encoding UTF8

Write-Information " -InformationAction Continue`n[SYMBOL] Results saved to: $jsonReportPath" -ForegroundColor Gray

# Generate HTML report if requested
if ($CreateReport) {
    Write-Information " -InformationAction Continue`nNOTE Generating HTML report..." -ForegroundColor Yellow

    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>OpenTofu Lab Automation - Test Results</title>
    <meta charset="utf-8">
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .status { font-weight: bold; padding: 5px 15px; border-radius: 4px; display: inline-block; }
        .passed { background: #d5edda; color: #155724; }
        .failed { background: #f8d7da; color: #721c24; }
        .skipped { background: #fff3cd; color: #856404; }
        .error { background: #f8d7da; color: #721c24; }
        .summary { background: #e9ecef; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .meta { color: #6c757d; font-size: 0.9em; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .duration { font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>DEPLOY OpenTofu Lab Automation - Test Results</h1>

        <div class="summary">
            <h2>Summary</h2>
            <p><strong>Test Suite:</strong> $TestSuite</p>
            <p><strong>Timestamp:</strong> $Timestamp</p>
            <p><strong>Duration:</strong> <span class="duration">$($testResults.TotalDuration.ToString('mm\:ss'))</span></p>
            <p><strong>Overall Status:</strong> <span class="status $($testResults.OverallStatus.ToLower())">$($testResults.OverallStatus)</span></p>
        </div>

        <h2>Test Results</h2>
"@

    if ($testResults.PowerShell) {
        $psStatus = $testResults.PowerShell.Status.ToLower()
        $htmlReport += @"
        <h3>PACKAGE PowerShell Tests</h3>
        <p><strong>Status:</strong> <span class="status $psStatus">$($testResults.PowerShell.Status)</span></p>
"@
        if ($testResults.PowerShell.ExitCode) {
            $htmlReport += "<p><strong>Exit Code:</strong> $($testResults.PowerShell.ExitCode)</p>"
        }
    }

    if ($testResults.Python) {
        $pyStatus = $testResults.Python.Status.ToLower()
        $htmlReport += @"
        <h3>[SYMBOL] Python Tests</h3>
        <p><strong>Status:</strong> <span class="status $pyStatus">$($testResults.Python.Status)</span></p>
"@
        if ($testResults.Python.ExitCode) {
            $htmlReport += "<p><strong>Exit Code:</strong> $($testResults.Python.ExitCode)</p>"
        }
    }

    $htmlReport += @"

        <h2>Environment</h2>
        <div class="meta">
            <p><strong>OS:</strong> $($PSVersionTable.OS)</p>
            <p><strong>PowerShell:</strong> $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))</p>
            <p><strong>Project Root:</strong> $ProjectRoot</p>
            <p><strong>Modules Path:</strong> $env:PWSH_MODULES_PATH</p>
            <p><strong>Python Path:</strong> $env:PYTHON_MODULES_PATH</p>
        </div>

        <h2>Raw Results</h2>
        <pre>$($jsonReport)</pre>

        <hr style="margin-top: 40px; border: 0; border-top: 1px solid #dee2e6;">
        <p class="meta">Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') by OpenTofu Lab Automation Master Test Runner</p>
    </div>
</body>
</html>
"@

    $htmlReportPath = Join-Path $ResultsDir "test_report_$Timestamp.html"
    $htmlReport | Out-File -FilePath $htmlReportPath -Encoding UTF8

    Write-Information " -InformationAction Continue[SYMBOL] HTML report saved to: $htmlReportPath" -ForegroundColor Green
}

# Exit with appropriate code
Write-Information " -InformationAction Continue`n" -NoNewline
switch ($testResults.OverallStatus) {
    'PASSED' {
        Write-Information " -InformationAction ContinueCOMPLETED All tests completed successfully!" -ForegroundColor Green
        exit 0
    }
    'FAILED' {
        Write-Information " -InformationAction Continue[SYMBOL] Some tests failed. Check the results above." -ForegroundColor Red
        exit 1
    }
    'SKIPPED' {
        Write-Information " -InformationAction ContinueWARNING  Tests were skipped. Check configuration." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Information " -InformationAction Continue[SYMBOL] Test status unknown. Check logs." -ForegroundColor Gray
        exit 1
    }
}
