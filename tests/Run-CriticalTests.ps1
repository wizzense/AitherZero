#Requires -Version 7.0
<#
.SYNOPSIS
    Runs critical infrastructure tests with comprehensive reporting
.DESCRIPTION
    Executes all critical infrastructure tests and generates detailed reports
    including HTML, XML, and JSON formats with code coverage analysis
#>

param(
    [ValidateSet('Minimal', 'Standard', 'Detailed', 'Diagnostic')]
    [string]$ReportLevel = 'Detailed',
    
    [switch]$ShowCoverage,
    [switch]$GenerateHTML,
    [switch]$FailFast,
    [string]$OutputPath = './tests/TestResults'
)

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

Write-Host "`n🧪 AitherZero Critical Infrastructure Test Suite" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Report Level: $ReportLevel" -ForegroundColor Yellow
Write-Host "Output Path: $OutputPath" -ForegroundColor Yellow
Write-Host ""

# Configure Pester
$pesterConfig = New-PesterConfiguration

# Test discovery
$pesterConfig.Run.Path = './tests/Critical'
$pesterConfig.Run.PassThru = $true
$pesterConfig.Run.Exit = $false
$pesterConfig.Run.SkipRun = $false

# Output configuration
$pesterConfig.Output.Verbosity = $ReportLevel
$pesterConfig.Output.StackTraceVerbosity = 'Filtered'
$pesterConfig.Output.CIFormat = 'Auto'

# Test results
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "critical-tests-$timestamp.xml"
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'

# Code coverage if requested
if ($ShowCoverage) {
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = @(
        './aither-core/*.ps1',
        './aither-core/modules/*/Public/*.ps1',
        './aither-core/modules/*/Private/*.ps1'
    )
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "coverage-$timestamp.xml"
    $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
}

# Should configuration
$pesterConfig.Should.ErrorAction = if ($FailFast) { 'Stop' } else { 'Continue' }

Write-Host "🔍 Discovering tests..." -ForegroundColor Yellow
$discoveryStart = Get-Date

# Run tests
$testResults = Invoke-Pester -Configuration $pesterConfig

$discoveryEnd = Get-Date
$discoveryTime = ($discoveryEnd - $discoveryStart).TotalSeconds

Write-Host "`n📊 Test Execution Summary" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Generate summary report
$summary = @"
Test Run Summary
================
Execution Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Total Duration: $([math]::Round($testResults.Duration.TotalSeconds, 2)) seconds
Discovery Time: $([math]::Round($discoveryTime, 2)) seconds

Test Statistics
===============
Total Tests:     $($testResults.TotalCount)
Passed:          $($testResults.PassedCount) ✅
Failed:          $($testResults.FailedCount) ❌
Skipped:         $($testResults.SkippedCount) ⏭️
NotRun:          $($testResults.NotRunCount) ⏸️
Success Rate:    $([math]::Round(($testResults.PassedCount / $testResults.TotalCount) * 100, 2))%

Container Summary
=================
Total Containers: $($testResults.Containers.Count)
"@

Write-Host $summary

# Detailed failure report if any
if ($testResults.FailedCount -gt 0) {
    Write-Host "`n❌ Failed Tests Detail" -ForegroundColor Red
    Write-Host "=" * 60 -ForegroundColor Red
    
    $failedTests = $testResults.Tests | Where-Object { $_.Result -eq 'Failed' }
    foreach ($test in $failedTests) {
        Write-Host "`nTest: $($test.Name)" -ForegroundColor Yellow
        Write-Host "File: $($test.ScriptBlock.File):$($test.ScriptBlock.StartPosition.StartLine)" -ForegroundColor Gray
        Write-Host "Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor Red
        if ($ReportLevel -in @('Detailed', 'Diagnostic')) {
            Write-Host "Stack Trace:" -ForegroundColor Gray
            Write-Host $test.ErrorRecord.ScriptStackTrace -ForegroundColor DarkGray
        }
    }
}

# Container breakdown
Write-Host "`n📦 Test Container Breakdown" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$containerReport = @()
foreach ($container in $testResults.Containers) {
    if ($container.Type -eq 'File') {
        $fileName = Split-Path $container.Name -Leaf
        $containerStats = @{
            File = $fileName
            Total = $container.TotalCount
            Passed = $container.PassedCount
            Failed = $container.FailedCount
            Duration = [math]::Round($container.Duration.TotalSeconds, 2)
        }
        $containerReport += [PSCustomObject]$containerStats
        
        $status = if ($container.FailedCount -eq 0) { "✅" } else { "❌" }
        Write-Host "$status $fileName - Passed: $($container.PassedCount)/$($container.TotalCount) (Duration: $($containerStats.Duration)s)"
    }
}

# Save detailed JSON report
$jsonReport = @{
    Summary = @{
        ExecutionDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TotalDuration = $testResults.Duration.TotalSeconds
        DiscoveryTime = $discoveryTime
        TotalTests = $testResults.TotalCount
        PassedTests = $testResults.PassedCount
        FailedTests = $testResults.FailedCount
        SkippedTests = $testResults.SkippedCount
        SuccessRate = [math]::Round(($testResults.PassedCount / $testResults.TotalCount) * 100, 2)
    }
    Containers = $containerReport
    FailedTests = $failedTests | ForEach-Object {
        @{
            Name = $_.Name
            File = $_.ScriptBlock.File
            Line = $_.ScriptBlock.StartPosition.StartLine
            Error = $_.ErrorRecord.Exception.Message
            StackTrace = $_.ErrorRecord.ScriptStackTrace
        }
    }
    Tags = @{
        Critical = ($testResults.Tests | Where-Object { 'Critical' -in $_.Tag }).Count
        Infrastructure = ($testResults.Tests | Where-Object { 'Infrastructure' -in $_.Tag }).Count
        E2E = ($testResults.Tests | Where-Object { 'E2E' -in $_.Tag }).Count
        Integration = ($testResults.Tests | Where-Object { 'Integration' -in $_.Tag }).Count
    }
}

$jsonReportPath = Join-Path $OutputPath "critical-tests-report-$timestamp.json"
$jsonReport | ConvertTo-Json -Depth 10 | Out-File $jsonReportPath -Encoding UTF8

Write-Host "`n📄 Reports Generated:" -ForegroundColor Green
Write-Host "  • XML Test Results: $(Join-Path $OutputPath "critical-tests-$timestamp.xml")" -ForegroundColor White
Write-Host "  • JSON Report: $jsonReportPath" -ForegroundColor White

# Code coverage report
if ($ShowCoverage -and $testResults.CodeCoverage) {
    Write-Host "`n📈 Code Coverage Summary" -ForegroundColor Magenta
    Write-Host "=" * 60 -ForegroundColor Magenta
    
    $coverage = $testResults.CodeCoverage
    $coveragePercent = [math]::Round(($coverage.CoveragePercent ?? 0), 2)
    
    Write-Host "Overall Coverage: $coveragePercent%" -ForegroundColor $(
        if ($coveragePercent -ge 80) { 'Green' }
        elseif ($coveragePercent -ge 60) { 'Yellow' }
        else { 'Red' }
    )
    
    if ($coverage.AnalyzedFiles) {
        Write-Host "`nFile Coverage:" -ForegroundColor Yellow
        foreach ($file in $coverage.AnalyzedFiles) {
            $fileCoverage = [math]::Round($file.CoveragePercent ?? 0, 2)
            Write-Host "  • $(Split-Path $file.Path -Leaf): $fileCoverage%" -ForegroundColor White
        }
    }
    
    Write-Host "  • Coverage Report: $(Join-Path $OutputPath "coverage-$timestamp.xml")" -ForegroundColor White
}

# Generate HTML report if requested
if ($GenerateHTML) {
    Write-Host "`n🌐 Generating HTML Report..." -ForegroundColor Yellow
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Critical Infrastructure Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007acc; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border: 1px solid #dee2e6; }
        .stat-card h3 { margin: 0 0 10px 0; color: #495057; }
        .stat-card .value { font-size: 2em; font-weight: bold; }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .skipped { color: #ffc107; }
        .info { color: #17a2b8; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        th { background-color: #007acc; color: white; }
        tr:hover { background-color: #f8f9fa; }
        .tag { display: inline-block; padding: 3px 8px; margin: 2px; background: #e9ecef; border-radius: 3px; font-size: 0.85em; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #dee2e6; text-align: center; color: #6c757d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🧪 AitherZero Critical Infrastructure Test Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        
        <div class="summary">
            <div class="stat-card">
                <h3>Total Tests</h3>
                <div class="value info">$($testResults.TotalCount)</div>
            </div>
            <div class="stat-card">
                <h3>Passed</h3>
                <div class="value passed">$($testResults.PassedCount)</div>
            </div>
            <div class="stat-card">
                <h3>Failed</h3>
                <div class="value failed">$($testResults.FailedCount)</div>
            </div>
            <div class="stat-card">
                <h3>Success Rate</h3>
                <div class="value $(if ($jsonReport.Summary.SuccessRate -ge 95) { 'passed' } elseif ($jsonReport.Summary.SuccessRate -ge 80) { 'skipped' } else { 'failed' })">$($jsonReport.Summary.SuccessRate)%</div>
            </div>
            <div class="stat-card">
                <h3>Duration</h3>
                <div class="value info">$([math]::Round($testResults.Duration.TotalSeconds, 2))s</div>
            </div>
        </div>
        
        <h2>📊 Test Files Summary</h2>
        <table>
            <tr>
                <th>Test File</th>
                <th>Total</th>
                <th>Passed</th>
                <th>Failed</th>
                <th>Duration (s)</th>
                <th>Status</th>
            </tr>
"@
    
    foreach ($container in $containerReport) {
        $status = if ($container.Failed -eq 0) { "✅ Pass" } else { "❌ Fail" }
        $htmlContent += @"
            <tr>
                <td>$($container.File)</td>
                <td>$($container.Total)</td>
                <td class="passed">$($container.Passed)</td>
                <td class="failed">$($container.Failed)</td>
                <td>$($container.Duration)</td>
                <td>$status</td>
            </tr>
"@
    }
    
    $htmlContent += @"
        </table>
        
        <h2>🏷️ Test Categories</h2>
        <p>
"@
    
    foreach ($tag in $jsonReport.Tags.GetEnumerator()) {
        $htmlContent += "<span class='tag'>$($tag.Key): $($tag.Value)</span>"
    }
    
    if ($testResults.FailedCount -gt 0) {
        $htmlContent += @"
        
        <h2>❌ Failed Tests</h2>
        <table>
            <tr>
                <th>Test Name</th>
                <th>File</th>
                <th>Error Message</th>
            </tr>
"@
        foreach ($failed in $jsonReport.FailedTests) {
            $htmlContent += @"
            <tr>
                <td>$($failed.Name)</td>
                <td>$($failed.File):$($failed.Line)</td>
                <td>$($failed.Error)</td>
            </tr>
"@
        }
        $htmlContent += "</table>"
    }
    
    $htmlContent += @"
        </p>
        
        <div class="footer">
            <p>AitherZero Infrastructure Test Suite v2.0</p>
        </div>
    </div>
</body>
</html>
"@
    
    $htmlPath = Join-Path $OutputPath "critical-tests-report-$timestamp.html"
    $htmlContent | Out-File $htmlPath -Encoding UTF8
    Write-Host "  • HTML Report: $htmlPath" -ForegroundColor White
}

# Final status
Write-Host "`n" -NoNewline
if ($testResults.FailedCount -eq 0) {
    Write-Host "✅ All critical infrastructure tests passed!" -ForegroundColor Green -BackgroundColor DarkGreen
} else {
    Write-Host "❌ Some tests failed. Review the reports for details." -ForegroundColor Red -BackgroundColor DarkRed
}

Write-Host "`n🏁 Test execution completed.`n" -ForegroundColor Cyan

# Return results for automation
return @{
    Success = $testResults.FailedCount -eq 0
    Results = $testResults
    ReportPaths = @{
        XML = Join-Path $OutputPath "critical-tests-$timestamp.xml"
        JSON = $jsonReportPath
        HTML = if ($GenerateHTML) { Join-Path $OutputPath "critical-tests-report-$timestamp.html" } else { $null }
        Coverage = if ($ShowCoverage) { Join-Path $OutputPath "coverage-$timestamp.xml" } else { $null }
    }
}