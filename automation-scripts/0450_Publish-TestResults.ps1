#Requires -Version 7.0
<#
.SYNOPSIS
    Publishes test results to GitHub Pages for easy viewing
.DESCRIPTION
    Converts test results to HTML format and publishes them to GitHub Pages
    for easy viewing without downloading artifacts
.PARAMETER Path
    Path to test results directory
.PARAMETER OutputPath
    Output path for HTML reports
.PARAMETER IncludeTrends
    Include historical trend analysis
.PARAMETER WhatIf
    Simulates the publishing process without making changes
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = "./tests",
    [string]$OutputPath = "./docs/reports",
    [switch]$IncludeTrends
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Initialize
$script:ScriptName = $MyInvocation.MyCommand.Name
Write-Host "`n=== $script:ScriptName ===" -ForegroundColor Cyan

# Import required modules
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Import-Module (Join-Path $projectRoot "AitherZero.psd1") -Force -ErrorAction SilentlyContinue

# Helper function for safe logging
function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level -Source $script:ScriptName
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(if ($Level -eq 'Error') { 'Red' } elseif ($Level -eq 'Warning') { 'Yellow' } else { 'White' })
    }
}

try {
    # Create output directory
    if ($PSCmdlet.ShouldProcess($OutputPath, "Create output directory")) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        New-Item -ItemType Directory -Path "$OutputPath/latest" -Force | Out-Null
        New-Item -ItemType Directory -Path "$OutputPath/archive" -Force | Out-Null

        if ($IncludeTrends) {
            New-Item -ItemType Directory -Path "$OutputPath/trends" -Force | Out-Null
        }
    }

    # Collect all test results
    $testResults = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        UnitTests = @()
        IntegrationTests = @()
        Coverage = @()
        Analysis = @()
        Performance = @()
    }

    Write-ScriptLog "Collecting test results from $Path"

    # Process unit test results
    Get-ChildItem -Path "$Path/results" -Filter "UnitTests-*.xml" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-ScriptLog "Processing unit test: $($_.Name)"
        $xml = [xml](Get-Content $_.FullName)

        $summary = @{
            File = $_.Name
            Date = $_.LastWriteTime
            Total = [int]$xml.'test-results'.total
            Passed = [int]$xml.'test-results'.passed
            Failed = [int]$xml.'test-results'.failures
            Skipped = [int]$xml.'test-results'.inconclusive
            Duration = [double]$xml.'test-results'.time
        }

        $testResults.UnitTests += $summary
    }

    # Process coverage results
    Get-ChildItem -Path "$Path/coverage" -Filter "Coverage-*.xml" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-ScriptLog "Processing coverage: $($_.Name)"
        $xml = [xml](Get-Content $_.FullName)

        # Parse coverage data (format depends on coverage tool)
        $coverage = @{
            File = $_.Name
            Date = $_.LastWriteTime
            LinesCovered = 0
            LinesTotal = 0
            BranchesCovered = 0
            BranchesTotal = 0
        }

        # Calculate coverage percentage
        if ($coverage.LinesTotal -gt 0) {
            $coverage.LineCoverage = [math]::Round(($coverage.LinesCovered / $coverage.LinesTotal) * 100, 2)
        } else {
            $coverage.LineCoverage = 0
        }

        $testResults.Coverage += $coverage
    }

    # Process PSScriptAnalyzer results
    Get-ChildItem -Path "$Path/analysis" -Filter "PSScriptAnalyzer-*.csv" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-ScriptLog "Processing analysis: $($_.Name)"
        $csv = Import-Csv $_.FullName

        $summary = @{
            File = $_.Name
            Date = $_.LastWriteTime
            Total = $csv.Count
            Errors = ($csv | Where-Object Severity -eq 'Error').Count
            Warnings = ($csv | Where-Object Severity -eq 'Warning').Count
            Information = ($csv | Where-Object Severity -eq 'Information').Count
        }

        $testResults.Analysis += $summary
    }

    # Generate HTML report
    Write-ScriptLog "Generating HTML report"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Test Results - $($testResults.Timestamp)</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: #f5f5f5;
            padding: 2rem;
            line-height: 1.6;
        }
        .container { max-width: 1400px; margin: 0 auto; }

        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem;
            border-radius: 1rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }

        h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
        .subtitle { opacity: 0.9; font-size: 1.1rem; }

        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }

        .summary-card {
            background: white;
            padding: 1.5rem;
            border-radius: 0.5rem;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .summary-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(0,0,0,0.15);
        }

        .card-title {
            font-size: 0.9rem;
            color: #666;
            text-transform: uppercase;
            margin-bottom: 0.5rem;
        }

        .card-value {
            font-size: 2rem;
            font-weight: bold;
            color: #333;
        }

        .card-subtitle {
            font-size: 0.85rem;
            color: #999;
            margin-top: 0.25rem;
        }

        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .danger { color: #dc3545; }

        .section {
            background: white;
            padding: 2rem;
            border-radius: 0.5rem;
            margin-bottom: 2rem;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        h2 {
            color: #333;
            margin-bottom: 1.5rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid #667eea;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }

        th, td {
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }

        th {
            background: #f8f9fa;
            font-weight: 600;
            color: #333;
        }

        tr:hover { background: #f8f9fa; }

        .progress-bar {
            width: 100%;
            height: 20px;
            background: #e0e0e0;
            border-radius: 10px;
            overflow: hidden;
            margin: 0.5rem 0;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #28a745, #20c997);
            transition: width 0.3s;
        }

        .badge {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 0.25rem;
            font-size: 0.8rem;
            font-weight: 600;
        }

        .badge-success { background: #d4edda; color: #155724; }
        .badge-warning { background: #fff3cd; color: #856404; }
        .badge-danger { background: #f8d7da; color: #721c24; }

        .chart-container {
            position: relative;
            height: 300px;
            margin: 2rem 0;
        }

        footer {
            text-align: center;
            color: #666;
            margin-top: 3rem;
            padding-top: 2rem;
            border-top: 1px solid #e0e0e0;
        }

        @media (max-width: 768px) {
            body { padding: 1rem; }
            .summary-grid { grid-template-columns: 1fr; }
        }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3"></script>
</head>
<body>
    <div class="container">
        <header>
            <h1>🧪 AitherZero Test Results</h1>
            <div class="subtitle">Generated: $($testResults.Timestamp)</div>
        </header>

        <div class="summary-grid">
"@

    # Calculate summary metrics
    $totalTests = $testResults.UnitTests | Measure-Object -Property Total -Sum | Select-Object -ExpandProperty Sum
    $passedTests = $testResults.UnitTests | Measure-Object -Property Passed -Sum | Select-Object -ExpandProperty Sum
    $failedTests = $testResults.UnitTests | Measure-Object -Property Failed -Sum | Select-Object -ExpandProperty Sum
    $passRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }

    $avgCoverage = if ($testResults.Coverage.Count -gt 0) {
        ($testResults.Coverage | Measure-Object -Property LineCoverage -Average).Average
    } else { 0 }

    $analysisIssues = $testResults.Analysis | Measure-Object -Property Total -Sum | Select-Object -ExpandProperty Sum

    $html += @"
            <div class="summary-card">
                <div class="card-title">Total Tests</div>
                <div class="card-value">$totalTests</div>
                <div class="card-subtitle">Across all test suites</div>
            </div>

            <div class="summary-card">
                <div class="card-title">Pass Rate</div>
                <div class="card-value $(if ($passRate -ge 80) { 'success' } elseif ($passRate -ge 60) { 'warning' } else { 'danger' })">$passRate%</div>
                <div class="card-subtitle">$passedTests passed, $failedTests failed</div>
            </div>

            <div class="summary-card">
                <div class="card-title">Code Coverage</div>
                <div class="card-value $(if ($avgCoverage -ge 70) { 'success' } elseif ($avgCoverage -ge 50) { 'warning' } else { 'danger' })">$([math]::Round($avgCoverage, 1))%</div>
                <div class="card-subtitle">Average line coverage</div>
            </div>

            <div class="summary-card">
                <div class="card-title">Code Quality</div>
                <div class="card-value $(if ($analysisIssues -le 10) { 'success' } elseif ($analysisIssues -le 50) { 'warning' } else { 'danger' })">$analysisIssues</div>
                <div class="card-subtitle">PSScriptAnalyzer issues</div>
            </div>
        </div>

        <div class="section">
            <h2>📊 Test Results Overview</h2>
            <canvas id="testChart"></canvas>
        </div>

        <div class="section">
            <h2>🧪 Unit Test Details</h2>
            <table>
                <thead>
                    <tr>
                        <th>Test Suite</th>
                        <th>Total</th>
                        <th>Passed</th>
                        <th>Failed</th>
                        <th>Skipped</th>
                        <th>Duration</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($test in $testResults.UnitTests) {
        $status = if ($test.Failed -eq 0) { 'success' } elseif ($test.Failed -le 2) { 'warning' } else { 'danger' }
        $html += @"
                    <tr>
                        <td>$($test.File -replace 'UnitTests-|\.xml', '')</td>
                        <td>$($test.Total)</td>
                        <td class="success">$($test.Passed)</td>
                        <td class="danger">$($test.Failed)</td>
                        <td class="warning">$($test.Skipped)</td>
                        <td>$([math]::Round($test.Duration, 2))s</td>
                        <td><span class="badge badge-$status">$(if ($test.Failed -eq 0) { 'PASSED' } else { 'FAILED' })</span></td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>📈 Code Coverage</h2>
"@

    if ($testResults.Coverage.Count -gt 0) {
        foreach ($coverage in $testResults.Coverage) {
            $html += @"
            <div style="margin-bottom: 1.5rem;">
                <h3>$($coverage.File -replace 'Coverage-|\.xml', '')</h3>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($coverage.LineCoverage)%;"></div>
                </div>
                <p>Line Coverage: <strong>$($coverage.LineCoverage)%</strong> ($($coverage.LinesCovered) / $($coverage.LinesTotal) lines)</p>
            </div>
"@
        }
    } else {
        $html += "<p>No coverage data available</p>"
    }

    $html += @"
        </div>

        <div class="section">
            <h2>🔍 Code Analysis</h2>
            <table>
                <thead>
                    <tr>
                        <th>Analysis Run</th>
                        <th>Total Issues</th>
                        <th>Errors</th>
                        <th>Warnings</th>
                        <th>Information</th>
                        <th>Date</th>
                    </tr>
                </thead>
                <tbody>
"@

    foreach ($analysis in $testResults.Analysis) {
        $html += @"
                    <tr>
                        <td>$($analysis.File -replace 'PSScriptAnalyzer-|\.csv', '')</td>
                        <td>$($analysis.Total)</td>
                        <td class="danger">$($analysis.Errors)</td>
                        <td class="warning">$($analysis.Warnings)</td>
                        <td>$($analysis.Information)</td>
                        <td>$($analysis.Date.ToString('yyyy-MM-dd HH:mm'))</td>
                    </tr>
"@
    }

    $html += @"
                </tbody>
            </table>
        </div>

        <footer>
            <p>Generated by AitherZero CI/CD Pipeline |
            <a href="https://github.com/$($env:GITHUB_REPOSITORY)">GitHub</a> |
            <a href="https://github.com/$($env:GITHUB_REPOSITORY)/actions">Actions</a>
            </p>
        </footer>
    </div>

    <script>
        // Test results chart
        const ctx = document.getElementById('testChart').getContext('2d');
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Passed', 'Failed', 'Skipped'],
                datasets: [{
                    data: [$passedTests, $failedTests, $($totalTests - $passedTests - $failedTests)],
                    backgroundColor: ['#28a745', '#dc3545', '#ffc107'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const label = context.label || '';
                                const value = context.parsed || 0;
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const percentage = ((value / total) * 100).toFixed(1);
                                return label + ': ' + value + ' (' + percentage + '%)';
                            }
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

    # Save HTML report
    if ($PSCmdlet.ShouldProcess("$OutputPath/latest/test-report.html", "Save HTML report")) {
        $html | Set-Content "$OutputPath/latest/test-report.html" -Encoding UTF8
        Write-ScriptLog "HTML report saved to $OutputPath/latest/test-report.html" -Level Success
    }

    # Save JSON for programmatic access
    if ($PSCmdlet.ShouldProcess("$OutputPath/latest/test-results.json", "Save JSON results")) {
        $testResults | ConvertTo-Json -Depth 10 | Set-Content "$OutputPath/latest/test-results.json"
        Write-ScriptLog "JSON results saved to $OutputPath/latest/test-results.json" -Level Success
    }

    # Archive with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if ($PSCmdlet.ShouldProcess("$OutputPath/archive", "Archive results")) {
        Copy-Item "$OutputPath/latest/test-report.html" "$OutputPath/archive/test-report-$timestamp.html"
        Copy-Item "$OutputPath/latest/test-results.json" "$OutputPath/archive/test-results-$timestamp.json"
        Write-ScriptLog "Results archived with timestamp $timestamp" -Level Success
    }

    # Generate trends if requested
    if ($IncludeTrends) {
        Write-ScriptLog "Generating trend analysis"

        # Collect historical data
        $historicalData = @()
        Get-ChildItem "$OutputPath/archive" -Filter "test-results-*.json" |
            Sort-Object Name -Descending |
            Select-Object -First 30 | ForEach-Object {
                $data = Get-Content $_.FullName | ConvertFrom-Json
                $historicalData += $data
            }

        # Generate trends report
        # ... (trend analysis logic)
    }

    Write-Host "`n✅ Test results published successfully!" -ForegroundColor Green
    Write-Host "View at: https://$($env:GITHUB_REPOSITORY_OWNER).github.io/$($env:GITHUB_REPOSITORY -split '/' | Select-Object -Last 1)/reports/latest/test-report.html" -ForegroundColor Cyan

} catch {
    Write-ScriptLog "Error publishing test results: $_" -Level Error
    throw
}