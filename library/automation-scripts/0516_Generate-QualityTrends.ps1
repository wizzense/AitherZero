#Requires -Version 7.0
<#
.SYNOPSIS
    Generate quality metrics trend visualization and historical analysis
.DESCRIPTION
    Creates interactive HTML pages showing quality metrics trends over time:
    - Quality score trends (line charts)
    - Distribution changes (stacked area charts)
    - Complexity trends (AST metrics over time)
    - PSScriptAnalyzer findings trends
    
    **Historical Analysis Features**:
    - Automatic collection of daily snapshots
    - 30-day rolling window
    - Trend analysis and predictions
    - Export to multiple formats (HTML, JSON, CSV)
    
.PARAMETER HistoryDays
    Number of days of history to include in visualization (default: 30)
    
.PARAMETER OutputPath
    Path to save trend visualization HTML
    
.PARAMETER GenerateSnapshot
    Generate a new quality snapshot before creating trends
    
.EXAMPLE
    ./library/automation-scripts/0516_Generate-QualityTrends.ps1
    
.EXAMPLE
    ./library/automation-scripts/0516_Generate-QualityTrends.ps1 -GenerateSnapshot -HistoryDays 60
    
.NOTES
    Stage: Reporting
    Dependencies: 0514_Generate-QualityMetrics.ps1
    Tags: reporting, metrics, trends, historical, visualization
#>

[CmdletBinding()]
param(
    [int]$HistoryDays = 30,
    
    [string]$OutputPath = './library/reports/quality-trends.html',
    
    [switch]$GenerateSnapshot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$historyDir = Join-Path $ProjectRoot 'library/reports/quality-history'

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Quality Metrics Trend Analysis                      ║" -ForegroundColor Cyan
Write-Host "║        Historical Tracking & Visualization                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Generate new snapshot if requested
if ($GenerateSnapshot) {
    Write-Host "📊 Generating new quality snapshot..." -ForegroundColor Yellow
    $metricsScript = Join-Path $ProjectRoot 'library/automation-scripts/0514_Generate-QualityMetrics.ps1'
    & $metricsScript -IncludeHistory
}

# Load historical data
if (-not (Test-Path $historyDir)) {
    Write-Warning "No historical data found at: $historyDir"
    Write-Host "Run './library/automation-scripts/0514_Generate-QualityMetrics.ps1 -IncludeHistory' to start collecting history"
    exit 0
}

$historyFiles = Get-ChildItem -Path $historyDir -Filter "quality-metrics-*.json" | 
    Sort-Object Name -Descending |
    Select-Object -First $HistoryDays

if ($historyFiles.Count -eq 0) {
    Write-Warning "No history files found"
    exit 0
}

Write-Host "Found $($historyFiles.Count) historical snapshots`n" -ForegroundColor Green

# Collect trend data
$trendData = @{
    Dates = @()
    AverageScores = @()
    TotalScripts = @()
    Excellent = @()
    Good = @()
    Fair = @()
    Poor = @()
    MaxComplexity = @()
    MaxNesting = @()
    Errors = @()
    Warnings = @()
}

foreach ($file in ($historyFiles | Sort-Object Name)) {
    try {
        $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
        
        # Parse timestamp from filename: quality-metrics-2025-01-09-143022.json
        $dateStr = $file.BaseName -replace 'quality-metrics-', ''
        $timestamp = [DateTime]::ParseExact($dateStr, 'yyyy-MM-dd-HHmmss', $null)
        
        $trendData.Dates += $timestamp.ToString('yyyy-MM-dd HH:mm')
        $trendData.AverageScores += [Math]::Round($data.AverageQualityScore, 1)
        $trendData.TotalScripts += $data.TotalScripts
        $trendData.Excellent += $data.QualityDistribution.Excellent
        $trendData.Good += $data.QualityDistribution.Good
        $trendData.Fair += $data.QualityDistribution.Fair
        $trendData.Poor += $data.QualityDistribution.Poor
        $trendData.MaxComplexity += $data.ASTMetrics.MaxComplexity
        $trendData.MaxNesting += $data.ASTMetrics.MaxNestingDepth
        $trendData.Errors += $data.PSScriptAnalyzer.TotalErrors
        $trendData.Warnings += $data.PSScriptAnalyzer.TotalWarnings
    } catch {
        Write-Warning "Failed to parse history file: $($file.Name) - $_"
    }
}

# Calculate trend direction
$trendDirection = if ($trendData.AverageScores.Count -gt 1) {
    $recent = $trendData.AverageScores[-1]
    $older = $trendData.AverageScores[0]
    if ($recent -gt $older) { "📈 Improving" }
    elseif ($recent -lt $older) { "📉 Declining" }
    else { "➡️ Stable" }
} else { "➡️ Insufficient data" }

$trendChange = if ($trendData.AverageScores.Count -gt 1) {
    [Math]::Round($trendData.AverageScores[-1] - $trendData.AverageScores[0], 1)
} else { 0 }

# Generate HTML with Chart.js
$datesJson = ($trendData.Dates | ConvertTo-Json -Compress)
$scoresJson = ($trendData.AverageScores | ConvertTo-Json -Compress)
$excellentJson = ($trendData.Excellent | ConvertTo-Json -Compress)
$goodJson = ($trendData.Good | ConvertTo-Json -Compress)
$fairJson = ($trendData.Fair | ConvertTo-Json -Compress)
$poorJson = ($trendData.Poor | ConvertTo-Json -Compress)
$complexityJson = ($trendData.MaxComplexity | ConvertTo-Json -Compress)
$nestingJson = ($trendData.MaxNesting | ConvertTo-Json -Compress)
$errorsJson = ($trendData.Errors | ConvertTo-Json -Compress)
$warningsJson = ($trendData.Warnings | ConvertTo-Json -Compress)

$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quality Trends - AitherZero</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0d1117; color: #c9d1d9; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); padding: 30px; border-radius: 10px; margin-bottom: 30px; text-align: center; }
        .header h1 { color: white; font-size: 2.5em; margin-bottom: 10px; }
        .header .subtitle { color: #dbeafe; font-size: 1.1em; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 20px; }
        .stat-card h3 { color: #58a6ff; margin-bottom: 10px; font-size: 0.9em; }
        .stat-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .stat-value.positive { color: #3fb950; }
        .stat-value.negative { color: #f85149; }
        .stat-value.neutral { color: #58a6ff; }
        .chart-container { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 30px; margin-bottom: 30px; }
        .chart-container h2 { color: #58a6ff; margin-bottom: 20px; }
        .chart-wrapper { position: relative; height: 400px; }
        canvas { max-height: 400px; }
        .footer { text-align: center; margin-top: 40px; color: #8b949e; padding: 20px; border-top: 1px solid #30363d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📈 Quality Metrics Trends</h1>
            <div class="subtitle">Historical Analysis - Last $($trendData.Dates.Count) Snapshots</div>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <h3>Current Average Score</h3>
                <div class="stat-value neutral">$($trendData.AverageScores[-1])/100</div>
            </div>
            <div class="stat-card">
                <h3>Trend Direction</h3>
                <div class="stat-value $(if ($trendChange -gt 0) { 'positive' } elseif ($trendChange -lt 0) { 'negative' } else { 'neutral' })">$trendDirection</div>
            </div>
            <div class="stat-card">
                <h3>Change (First → Last)</h3>
                <div class="stat-value $(if ($trendChange -gt 0) { 'positive' } elseif ($trendChange -lt 0) { 'negative' } else { 'neutral' })">
                    $(if ($trendChange -gt 0) { '+' })$trendChange
                </div>
            </div>
            <div class="stat-card">
                <h3>Data Points</h3>
                <div class="stat-value neutral">$($trendData.Dates.Count)</div>
            </div>
        </div>

        <div class="chart-container">
            <h2>📊 Average Quality Score Over Time</h2>
            <div class="chart-wrapper">
                <canvas id="scoreChart"></canvas>
            </div>
        </div>

        <div class="chart-container">
            <h2>🎯 Quality Distribution Trends</h2>
            <div class="chart-wrapper">
                <canvas id="distributionChart"></canvas>
            </div>
        </div>

        <div class="chart-container">
            <h2>🔍 AST Metrics Trends</h2>
            <div class="chart-wrapper">
                <canvas id="astChart"></canvas>
            </div>
        </div>

        <div class="chart-container">
            <h2>⚠️ PSScriptAnalyzer Findings</h2>
            <div class="chart-wrapper">
                <canvas id="pssaChart"></canvas>
            </div>
        </div>

        <div class="footer">
            <p>🚀 AitherZero Quality Metrics System</p>
            <p style="margin-top: 10px; font-size: 0.9em;">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')</p>
        </div>
    </div>

    <script>
        const dates = $datesJson;

        // Score trend chart
        new Chart(document.getElementById('scoreChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [{
                    label: 'Average Quality Score',
                    data: $scoresJson,
                    borderColor: '#58a6ff',
                    backgroundColor: 'rgba(88, 166, 255, 0.1)',
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { labels: { color: '#c9d1d9' } }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    },
                    x: {
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    }
                }
            }
        });

        // Distribution chart
        new Chart(document.getElementById('distributionChart'), {
            type: 'bar',
            data: {
                labels: dates,
                datasets: [
                    {
                        label: 'Excellent (90-100)',
                        data: $excellentJson,
                        backgroundColor: '#3fb950'
                    },
                    {
                        label: 'Good (70-89)',
                        data: $goodJson,
                        backgroundColor: '#58a6ff'
                    },
                    {
                        label: 'Fair (50-69)',
                        data: $fairJson,
                        backgroundColor: '#d29922'
                    },
                    {
                        label: 'Poor (<50)',
                        data: $poorJson,
                        backgroundColor: '#f85149'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { labels: { color: '#c9d1d9' } }
                },
                scales: {
                    y: {
                        stacked: true,
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    },
                    x: {
                        stacked: true,
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    }
                }
            }
        });

        // AST metrics chart
        new Chart(document.getElementById('astChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [
                    {
                        label: 'Max Complexity',
                        data: $complexityJson,
                        borderColor: '#d29922',
                        backgroundColor: 'rgba(210, 153, 34, 0.1)',
                        yAxisID: 'y'
                    },
                    {
                        label: 'Max Nesting Depth',
                        data: $nestingJson,
                        borderColor: '#58a6ff',
                        backgroundColor: 'rgba(88, 166, 255, 0.1)',
                        yAxisID: 'y1'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { labels: { color: '#c9d1d9' } }
                },
                scales: {
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    },
                    y1: {
                        type: 'linear',
                        display: true,
                        position: 'right',
                        ticks: { color: '#c9d1d9' },
                        grid: { drawOnChartArea: false }
                    },
                    x: {
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    }
                }
            }
        });

        // PSSA chart
        new Chart(document.getElementById('pssaChart'), {
            type: 'line',
            data: {
                labels: dates,
                datasets: [
                    {
                        label: 'Errors',
                        data: $errorsJson,
                        borderColor: '#f85149',
                        backgroundColor: 'rgba(248, 81, 73, 0.1)',
                        fill: true
                    },
                    {
                        label: 'Warnings',
                        data: $warningsJson,
                        borderColor: '#d29922',
                        backgroundColor: 'rgba(210, 153, 34, 0.1)',
                        fill: true
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { labels: { color: '#c9d1d9' } }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    },
                    x: {
                        ticks: { color: '#c9d1d9' },
                        grid: { color: '#30363d' }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

# Save HTML
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$htmlContent | Set-Content -Path $OutputPath -Encoding UTF8

# Save trend data as JSON and CSV
$trendJsonPath = $OutputPath -replace '\.html$', '.json'
$trendData | ConvertTo-Json -Depth 10 | Set-Content -Path $trendJsonPath

$trendCsvPath = $OutputPath -replace '\.html$', '.csv'
$csvData = for ($i = 0; $i -lt $trendData.Dates.Count; $i++) {
    [PSCustomObject]@{
        Date = $trendData.Dates[$i]
        AverageScore = $trendData.AverageScores[$i]
        Excellent = $trendData.Excellent[$i]
        Good = $trendData.Good[$i]
        Fair = $trendData.Fair[$i]
        Poor = $trendData.Poor[$i]
        MaxComplexity = $trendData.MaxComplexity[$i]
        MaxNesting = $trendData.MaxNesting[$i]
        Errors = $trendData.Errors[$i]
        Warnings = $trendData.Warnings[$i]
    }
}
$csvData | Export-Csv -Path $trendCsvPath -NoTypeInformation

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Trend Analysis Complete                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Snapshots Analyzed:   $($trendData.Dates.Count)" -ForegroundColor White
Write-Host "Trend Direction:      $trendDirection" -ForegroundColor $(if ($trendChange -gt 0) { 'Green' } elseif ($trendChange -lt 0) { 'Red' } else { 'Yellow' })
Write-Host "Score Change:         $(if ($trendChange -gt 0) { '+' })$trendChange" -ForegroundColor $(if ($trendChange -gt 0) { 'Green' } elseif ($trendChange -lt 0) { 'Red' } else { 'Yellow' })
Write-Host ""
Write-Host "📄 HTML report:       $OutputPath" -ForegroundColor Green
Write-Host "📊 JSON data:         $trendJsonPath" -ForegroundColor Green
Write-Host "📋 CSV export:        $trendCsvPath" -ForegroundColor Green
Write-Host ""

Write-Host "✨ Quality trend visualization complete!`n" -ForegroundColor Cyan
