#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Reporting Engine Module (Enhanced)
.DESCRIPTION
    Provides comprehensive reporting capabilities including real-time dashboards,
    historical analysis, test result visualization, and multi-format exports.
    Enhanced to consolidate functionality from automation scripts 0500-0599.
.NOTES
    Copyright © 2025 Aitherium Corporation
    Consolidates: 0500_Validate-Environment.ps1, 0501_Get-SystemInfo.ps1,
                  0510_Generate-ProjectReport.ps1, 0511_Show-ProjectDashboard.ps1,
                  0512_Generate-Dashboard.ps1, 0520_Analyze-*.ps1 scripts,
                  0530_View-Logs.ps1, and other reporting automation
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:ReportingState = @{
    CurrentDashboard = $null
    ReportHistory = @()
    MetricsCache = @{}
    RefreshInterval = 5
    Config = $null
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
$script:TestingModule = Join-Path $script:ProjectRoot "domains/testing/TestingFramework.psm1"
$script:ConfigModule = Join-Path $script:ProjectRoot "domains/configuration/Configuration.psm1"

# Import logging if available (only if not already loaded)
if (-not (Get-Module -Name "Logging")) {
    if (Test-Path $script:LoggingModule) {
        Import-Module $script:LoggingModule -Force
    }
}
$script:LoggingAvailable = (Get-Module -Name "Logging") -ne $null

# Import configuration module (only if not already loaded)
if (-not (Get-Module -Name "Configuration")) {
    if (Test-Path $script:ConfigModule) {
        Import-Module $script:ConfigModule -Force
    }
}
$script:ConfigAvailable = (Get-Module -Name "Configuration") -ne $null

function Initialize-ReportingEngine {
    <#
    .SYNOPSIS
        Initialize the ReportingEngine with configuration
    .PARAMETER Configuration
        Configuration object or path to config file
    #>
    [CmdletBinding()]
    param(
        [object]$Configuration
    )

    # Load configuration
    $reportConfig = $null
    if ($Configuration) {
        $reportConfig = if ($Configuration.Reporting) { $Configuration.Reporting } else { $null }
    } elseif ($script:ConfigAvailable -and (Get-Command Get-Configuration -ErrorAction SilentlyContinue)) {
        $reportConfig = Get-Configuration -Section 'Reporting'
    }

    # Apply configuration settings
    if ($reportConfig) {
        $script:ReportingState.Config = $reportConfig

        # Update state with config values
        $script:ReportingState.DefaultFormat = if ($reportConfig.DefaultFormat) { $reportConfig.DefaultFormat } else { 'HTML' }
        $script:ReportingState.AutoGenerateReports = if ($null -ne $reportConfig.AutoGenerateReports) { $reportConfig.AutoGenerateReports } else { $true }
        $script:ReportingState.ReportPath = if ($reportConfig.ReportPath) { $reportConfig.ReportPath } else { './reports' }
        $script:ReportingState.IncludeSystemInfo = if ($null -ne $reportConfig.IncludeSystemInfo) { $reportConfig.IncludeSystemInfo } else { $true }
        $script:ReportingState.IncludeExecutionLogs = if ($null -ne $reportConfig.IncludeExecutionLogs) { $reportConfig.IncludeExecutionLogs } else { $true }
        $script:ReportingState.IncludeScreenshots = if ($null -ne $reportConfig.IncludeScreenshots) { $reportConfig.IncludeScreenshots } else { $false }
        $script:ReportingState.CompressReports = if ($null -ne $reportConfig.CompressReports) { $reportConfig.CompressReports } else { $false }
        $script:ReportingState.EmailReports = if ($null -ne $reportConfig.EmailReports) { $reportConfig.EmailReports } else { $false }
        $script:ReportingState.UploadToCloud = if ($null -ne $reportConfig.UploadToCloud) { $reportConfig.UploadToCloud } else { $false }
        $script:ReportingState.DashboardEnabled = if ($null -ne $reportConfig.DashboardEnabled) { $reportConfig.DashboardEnabled } else { $true }
        $script:ReportingState.DashboardPort = if ($null -ne $reportConfig.DashboardPort) { $reportConfig.DashboardPort } else { 8080 }
        $script:ReportingState.DashboardAutoOpen = if ($null -ne $reportConfig.DashboardAutoOpen) { $reportConfig.DashboardAutoOpen } else { $false }
        $script:ReportingState.MetricsCollection = if ($null -ne $reportConfig.MetricsCollection) { $reportConfig.MetricsCollection } else { $true }
        $script:ReportingState.MetricsRetentionDays = if ($null -ne $reportConfig.MetricsRetentionDays) { $reportConfig.MetricsRetentionDays } else { 90 }
        $script:ReportingState.ExportFormats = if ($reportConfig.ExportFormats) { $reportConfig.ExportFormats } else { @('HTML', 'JSON', 'CSV', 'PDF', 'Markdown') }
        $script:ReportingState.TemplateEngine = if ($reportConfig.TemplateEngine) { $reportConfig.TemplateEngine } else { 'Default' }

        # Create report directory if it doesn't exist
        if (-not (Test-Path $script:ReportingState.ReportPath)) {
            New-Item -ItemType Directory -Path $script:ReportingState.ReportPath -Force | Out-Null
        }

        Write-ReportLog "Reporting engine initialized with configuration"
    }
}

function Write-ReportLog {
    param(
        [string]$Message,
        [string]$Level = 'Information'
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "ReportingEngine"
    } else {
        Write-Host "[$Level] $Message"
    }
}

function New-ExecutionDashboard {
    <#
    .SYNOPSIS
        Create a real-time execution dashboard
    .DESCRIPTION
        Creates an interactive dashboard showing current execution status,
        metrics, and progress for orchestration sequences
    #>
    [CmdletBinding()]
    param(
        [string]$Title = "AitherZero Execution Dashboard",

        [ValidateSet('Compact', 'Standard', 'Detailed')]
        [string]$Layout = 'Standard',

        [int]$RefreshInterval = 5,

        [switch]$AutoRefresh,

        [switch]$ShowMetrics,

        [switch]$ShowLogs
    )

    Write-ReportLog "Creating execution dashboard: $Title"

    $dashboard = @{
        Title = $Title
        Layout = $Layout
        RefreshInterval = $RefreshInterval
        AutoRefresh = $AutoRefresh
        StartTime = Get-Date
        Components = @{
            Header = @{
                Type = 'Header'
                Content = $Title
            }
            Status = @{
                Type = 'StatusPanel'
                Position = 'Top'
            }
            Progress = @{
                Type = 'ProgressBar'
                Position = 'Middle'
            }
        }
    }

    if ($ShowMetrics) {
        $dashboard.Components.Metrics = @{
            Type = 'MetricsGrid'
            Position = 'Right'
            Metrics = @('CPU', 'Memory', 'Disk', 'Network')
        }
    }

    if ($ShowLogs) {
        $dashboard.Components.Logs = @{
            Type = 'LogViewer'
            Position = 'Bottom'
            MaxLines = 20
        }
    }

    $script:ReportingState.CurrentDashboard = $dashboard

    # Start dashboard render loop if auto-refresh
    if ($AutoRefresh) {
        Start-DashboardRefresh -Dashboard $dashboard
    }

    return $dashboard
}

function Update-ExecutionDashboard {
    <#
    .SYNOPSIS
        Update the current execution dashboard with new data
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Dashboard = $script:ReportingState.CurrentDashboard,

        [hashtable]$Status,

        [hashtable]$Progress,

        [hashtable]$Metrics,

        [string[]]$LogEntries
    )

    if (-not $Dashboard) {
        Write-ReportLog "No active dashboard to update" -Level Warning
        return
    }

    # Update status
    if ($Status) {
        $Dashboard.Components.Status.Data = $Status
    }

    # Update progress
    if ($Progress) {
        $Dashboard.Components.Progress.Data = $Progress
    }

    # Update metrics
    if ($Metrics -and $Dashboard.Components.ContainsKey('Metrics')) {
        $Dashboard.Components.Metrics.Data = $Metrics
    }

    # Update logs
    if ($LogEntries -and $Dashboard.Components.ContainsKey('Logs')) {
        if (-not $Dashboard.Components.Logs.Data) {
            $Dashboard.Components.Logs.Data = @()
        }
        $Dashboard.Components.Logs.Data += $LogEntries

        # Keep only last MaxLines
        $maxLines = $Dashboard.Components.Logs.MaxLines
        if ($Dashboard.Components.Logs.Data.Count -gt $maxLines) {
            $Dashboard.Components.Logs.Data = $Dashboard.Components.Logs.Data[-$maxLines..-1]
        }
    }

    # Render dashboard
    Show-Dashboard -Dashboard $Dashboard
}

function Show-Dashboard {
    <#
    .SYNOPSIS
        Render the dashboard to console
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Dashboard
    )

    Clear-Host

    # Header
    Write-Host "`n$($Dashboard.Title)" -ForegroundColor Cyan
    Write-Host ("=" * $Dashboard.Title.Length) -ForegroundColor Cyan
    Write-Host "Started: $($Dashboard.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    if ($Dashboard.StartTime) {
        $runtime = New-TimeSpan -Start $Dashboard.StartTime -End (Get-Date)
        Write-Host "Runtime: $runtime" -ForegroundColor Gray
    }

    # Status panel
    if ($Dashboard.Components.Status.Data) {
        Write-Host "`nStatus:" -ForegroundColor Yellow
        foreach ($key in $Dashboard.Components.Status.Data.Keys) {
            $value = $Dashboard.Components.Status.Data[$key]
            $color = switch ($value) {
                'Running' { 'Green' }
                'Failed' { 'Red' }
                'Warning' { 'Yellow' }
                default { 'White' }
            }
            Write-Host "  $key : $value" -ForegroundColor $color
        }
    }

    # Progress bar
    if ($Dashboard.Components.Progress.Data) {
        $progress = $Dashboard.Components.Progress.Data
        Write-Host "`nProgress:" -ForegroundColor Yellow

        $completed = $progress.Completed ?? 0
        $total = $progress.Total ?? 100
        $percent = if ($total -gt 0) { [Math]::Round(($completed / $total) * 100) } else { 0 }

        $barLength = 50
        $filledLength = [Math]::Round(($percent / 100) * $barLength)
        $bar = "[" + ("█" * $filledLength) + ("░" * ($barLength - $filledLength)) + "]"

        Write-Host "  $bar $percent% ($completed/$total)" -ForegroundColor Green

        if ($progress.CurrentTask) {
            Write-Host "  Current: $($progress.CurrentTask)" -ForegroundColor Gray
        }
    }

    # Metrics grid
    if ($Dashboard.Components.ContainsKey('Metrics') -and $Dashboard.Components.Metrics.Data) {
        Write-Host "`nMetrics:" -ForegroundColor Yellow
        $metrics = $Dashboard.Components.Metrics.Data

        foreach ($metric in $Dashboard.Components.Metrics.Metrics) {
            if ($metrics.ContainsKey($metric)) {
                $value = $metrics[$metric]
                Write-Host "  $metric : $value" -ForegroundColor Cyan
            }
        }
    }

    # Log viewer
    if ($Dashboard.Components.ContainsKey('Logs') -and $Dashboard.Components.Logs.Data) {
        Write-Host "`nRecent Logs:" -ForegroundColor Yellow
        foreach ($log in $Dashboard.Components.Logs.Data) {
            Write-Host "  $log" -ForegroundColor Gray
        }
    }

    Write-Host "`n[Press Ctrl+C to exit dashboard]" -ForegroundColor DarkGray
}

function Start-DashboardRefresh {
    <#
    .SYNOPSIS
        Start auto-refresh loop for dashboard
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Dashboard
    )

    $timer = New-Object System.Timers.Timer
    $timer.Interval = $Dashboard.RefreshInterval * 1000
    $timer.AutoReset = $true

    Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
        $dashboard = $EventName.MessageData
        Show-Dashboard -Dashboard $dashboard
    } -MessageData $Dashboard | Out-Null

    $timer.Start()

    # Store timer reference
    $Dashboard.Timer = $timer
}

function Stop-DashboardRefresh {
    <#
    .SYNOPSIS
        Stop dashboard auto-refresh
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Dashboard = $script:ReportingState.CurrentDashboard
    )

    if ($Dashboard -and $Dashboard.Timer) {
        $Dashboard.Timer.Stop()
        $Dashboard.Timer.Dispose()
        $Dashboard.Remove('Timer')
    }
}

function Get-ExecutionMetrics {
    <#
    .SYNOPSIS
        Collect current execution metrics
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeSystem,

        [switch]$IncludeProcess,

        [switch]$IncludeCustom
    )

    $metrics = @{}

    if ($IncludeSystem) {
        # CPU usage
        $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
        $metrics['CPU'] = "{0:N1}%" -f $cpu

        # Memory usage
        $os = Get-CimInstance Win32_OperatingSystem
        $memUsed = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100
        $metrics['Memory'] = "{0:N1}%" -f $memUsed

        # Disk usage
        $disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -and $_.Used }
        $diskUsed = ($disk.Used | Measure-Object -Sum).Sum
        $diskTotal = (($disk.Used + $disk.Free) | Measure-Object -Sum).Sum
        $metrics['Disk'] = "{0:N1}%" -f (($diskUsed / $diskTotal) * 100)
    }

    if ($IncludeProcess) {
        $process = Get-Process -Id $PID
        $metrics['ProcessCPU'] = "{0:N1}%" -f $process.CPU
        $metrics['ProcessMemory'] = "{0:N0}MB" -f ($process.WorkingSet64 / 1MB)
        $metrics['ProcessThreads'] = $process.Threads.Count
    }

    if ($IncludeCustom -and $script:LoggingAvailable) {
        # Get performance traces
        if (Get-Command Get-PerformanceTraces -ErrorAction SilentlyContinue) {
            $traces = Get-PerformanceTraces
            if ($traces) {
                $metrics['ActiveTraces'] = $traces.Count
            }
        }
    }

    return $metrics
}

function New-TestReport {
    <#
    .SYNOPSIS
        Generate comprehensive test report
    .DESCRIPTION
        Creates detailed test reports with results, coverage, and analysis
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('HTML', 'Markdown', 'JSON', 'PDF', 'Excel')]
        [string]$Format = $script:ReportingState.DefaultFormat,

        [string]$Title = "AitherZero Test Report",

        [string]$OutputPath = $script:ReportingState.ReportPath,

        [switch]$IncludeTests,

        [switch]$IncludeCoverage,

        [switch]$IncludeAnalysis,

        [switch]$IncludeTrends,

        [hashtable]$TestResults,

        [hashtable]$CoverageData,

        [hashtable]$AnalysisResults
    )

    Write-ReportLog "Generating $Format test report: $Title"

    # Collect data if not provided
    if ($IncludeTests -and -not $TestResults) {
        $TestResults = Get-LatestTestResults
    }

    if ($IncludeCoverage -and -not $CoverageData) {
        $CoverageData = Get-LatestCoverageData
    }

    if ($IncludeAnalysis -and -not $AnalysisResults) {
        $AnalysisResults = Get-LatestAnalysisResults
    }

    # Create report structure
    $report = @{
        Title = $Title
        Generated = Get-Date
        Format = $Format
        Environment = @{
            Platform = $PSVersionTable.Platform
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            User = if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER }
            Computer = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { $env:HOSTNAME }
        }
    }

    # Add test results
    if ($TestResults) {
        $report.TestResults = @{
            Summary = @{
                Total = $TestResults.TotalCount
                Passed = $TestResults.PassedCount
                Failed = $TestResults.FailedCount
                Skipped = $TestResults.SkippedCount
                Duration = $TestResults.Duration
                SuccessRate = if ($TestResults.TotalCount -gt 0) {
                    [Math]::Round(($TestResults.PassedCount / $TestResults.TotalCount) * 100, 2)
                } else { 0 }
            }
            Details = $TestResults.Tests
        }
    }

    # Add coverage data
    if ($CoverageData) {
        $report.Coverage = @{
            Overall = $CoverageData.CoveragePercent
            Files = $CoverageData.Files
            UncoveredLines = $CoverageData.MissedLines
        }
    }

    # Add analysis results
    if ($AnalysisResults) {
        $report.Analysis = @{
            IssueCount = $AnalysisResults.Count
            BySeverity = $AnalysisResults | Group-Object Severity | ForEach-Object {
                @{ $_.Name = $_.Count }
            }
            ByRule = $AnalysisResults | Group-Object RuleName | ForEach-Object {
                @{ $_.Name = $_.Count }
            }
        }
    }

    # Set output path
    if (-not $OutputPath) {
        $OutputPath = Join-Path $script:ProjectRoot "tests/reports"
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $filename = "TestReport-$timestamp.$($Format.ToLower())"
    $reportPath = Join-Path $OutputPath $filename

    # Generate report based on format
    switch ($Format) {
        'JSON' {
            $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
        }

        'Markdown' {
            $markdown = New-MarkdownReport -Report $report
            $markdown | Set-Content -Path $reportPath
        }

        'HTML' {
            $html = New-HtmlReport -Report $report
            $html | Set-Content -Path $reportPath
        }

        'PDF' {
            Write-ReportLog "PDF generation not yet implemented" -Level Warning
            return $null
        }

        'Excel' {
            Write-ReportLog "Excel generation not yet implemented" -Level Warning
            return $null
        }
    }

    # Store in history
    $script:ReportingState.ReportHistory += @{
        Path = $reportPath
        Format = $Format
        Generated = $report.Generated
        Title = $Title
    }

    Write-ReportLog "Report generated: $reportPath"
    return $reportPath
}

function New-MarkdownReport {
    param([hashtable]$Report)

    $md = @"
# $($Report.Title)

Generated: $($Report.Generated.ToString('yyyy-MM-dd HH:mm:ss'))

## Environment

- **Platform**: $($Report.Environment.Platform)
- **PowerShell**: $($Report.Environment.PowerShellVersion)
- **User**: $($Report.Environment.User)
- **Computer**: $($Report.Environment.Computer)

"@

    if ($Report.TestResults) {
        $md += @"
## Test Results

### Summary

| Metric | Value |
|--------|-------|
| Total Tests | $($Report.TestResults.Summary.Total) |
| Passed | $($Report.TestResults.Summary.Passed) |
| Failed | $($Report.TestResults.Summary.Failed) |
| Skipped | $($Report.TestResults.Summary.Skipped) |
| Success Rate | $($Report.TestResults.Summary.SuccessRate)% |
| Duration | $($Report.TestResults.Summary.Duration) |

"@
    }

    if ($Report.Coverage) {
        $md += @"
## Code Coverage

- **Overall Coverage**: $($Report.Coverage.Overall)%
- **Files Analyzed**: $($Report.Coverage.Files.Count)
- **Uncovered Lines**: $($Report.Coverage.UncoveredLines)

"@
    }

    if ($Report.Analysis) {
        $md += @"
## Code Analysis

- **Total Issues**: $($Report.Analysis.IssueCount)

### By Severity

"@
        foreach ($severity in $Report.Analysis.BySeverity) {
            foreach ($key in $severity.Keys) {
                $md += "- **$key**: $($severity[$key])`n"
            }
        }
    }

    return $md
}

function New-HtmlReport {
    param([hashtable]$Report)

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>$($Report.Title) - Aitherium™</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            background: linear-gradient(135deg, #add8e6 0%, #e0bbf0 50%, #ffb6c1 100%);
            color: white;
            padding: 30px;
            text-align: center;
            position: relative;
        }
        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.1);
            z-index: 0;
        }
        .header-content {
            position: relative;
            z-index: 1;
        }
        .brand {
            font-size: 0.9em;
            opacity: 0.95;
            margin-top: 10px;
            letter-spacing: 2px;
            text-transform: uppercase;
        }
        .content {
            padding: 30px;
        }
        h1 {
            margin: 0;
            font-size: 2.5em;
        }
        h2 {
            color: #007acc;
            border-bottom: 2px solid #007acc;
            padding-bottom: 10px;
            margin-top: 30px;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            transition: transform 0.2s;
        }
        .metric:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .metric h3 {
            margin: 0 0 10px 0;
            color: #666;
            font-size: 14px;
            text-transform: uppercase;
        }
        .metric .value {
            font-size: 36px;
            font-weight: bold;
            color: #333;
        }
        .metric.success .value { color: #28a745; }
        .metric.warning .value { color: #ffc107; }
        .metric.danger .value { color: #dc3545; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th {
            background-color: #007acc;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .timestamp {
            color: #666;
            font-size: 14px;
            text-align: center;
            margin-top: 10px;
        }
        .chart {
            margin: 20px 0;
            height: 300px;
            background: #f8f9fa;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-content">
                <h1>$($Report.Title)</h1>
                <div class="brand">Aitherium™ AitherZero Platform</div>
                <div class="timestamp">Generated: $($Report.Generated.ToString('yyyy-MM-dd HH:mm:ss'))</div>
            </div>
        </div>

        <div class="content">
"@

    # Environment section
    $html += @"
            <h2>Environment</h2>
            <table>
                <tr><th>Property</th><th>Value</th></tr>
                <tr><td>Platform</td><td>$($Report.Environment.Platform)</td></tr>
                <tr><td>PowerShell Version</td><td>$($Report.Environment.PowerShellVersion)</td></tr>
                <tr><td>User</td><td>$($Report.Environment.User)</td></tr>
                <tr><td>Computer</td><td>$($Report.Environment.Computer)</td></tr>
            </table>
"@

    # Test results section
    if ($Report.TestResults) {
        $successRate = $Report.TestResults.Summary.SuccessRate
        $rateClass = if ($successRate -ge 80) { 'success' } elseif ($successRate -ge 60) { 'warning' } else { 'danger' }

        $html += @"
            <h2>Test Results</h2>
            <div class="metrics">
                <div class="metric">
                    <h3>Total Tests</h3>
                    <div class="value">$($Report.TestResults.Summary.Total)</div>
                </div>
                <div class="metric success">
                    <h3>Passed</h3>
                    <div class="value">$($Report.TestResults.Summary.Passed)</div>
                </div>
                <div class="metric danger">
                    <h3>Failed</h3>
                    <div class="value">$($Report.TestResults.Summary.Failed)</div>
                </div>
                <div class="metric warning">
                    <h3>Skipped</h3>
                    <div class="value">$($Report.TestResults.Summary.Skipped)</div>
                </div>
                <div class="metric $rateClass">
                    <h3>Success Rate</h3>
                    <div class="value">$successRate%</div>
                </div>
            </div>
"@
    }

    # Coverage section
    if ($Report.Coverage) {
        $coverageClass = if ($Report.Coverage.Overall -ge 80) { 'success' } elseif ($Report.Coverage.Overall -ge 60) { 'warning' } else { 'danger' }

        $html += @"
            <h2>Code Coverage</h2>
            <div class="metrics">
                <div class="metric $coverageClass">
                    <h3>Overall Coverage</h3>
                    <div class="value">$($Report.Coverage.Overall)%</div>
                </div>
                <div class="metric">
                    <h3>Files Analyzed</h3>
                    <div class="value">$($Report.Coverage.Files.Count)</div>
                </div>
                <div class="metric">
                    <h3>Uncovered Lines</h3>
                    <div class="value">$($Report.Coverage.UncoveredLines)</div>
                </div>
            </div>
"@
    }

    # Analysis section
    if ($Report.Analysis) {
        $html += @"
            <h2>Code Analysis</h2>
            <div class="metrics">
                <div class="metric">
                    <h3>Total Issues</h3>
                    <div class="value">$($Report.Analysis.IssueCount)</div>
                </div>
            </div>

            <h3>Issues by Severity</h3>
            <table>
                <tr><th>Severity</th><th>Count</th></tr>
"@
        foreach ($severity in $Report.Analysis.BySeverity) {
            foreach ($key in $severity.Keys) {
                $html += "<tr><td>$key</td><td>$($severity[$key])</td></tr>"
            }
        }
        $html += "</table>"
    }

    $html += @"
        </div>
        <div style="background: linear-gradient(135deg, #add8e6 0%, #e0bbf0 50%, #ffb6c1 100%); color: white; padding: 20px; text-align: center; margin-top: 40px;">
            <div style="font-size: 12px; opacity: 0.9;">
                Powered by <strong>Aitherium™</strong> Enterprise Infrastructure Automation Platform<br>
                © $(Get-Date -Format 'yyyy') Aitherium Corporation - AitherZero v1.0
            </div>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

function Get-LatestTestResults {
    <#
    .SYNOPSIS
        Get the latest test results from the test directory
    #>
    [CmdletBinding()]
    param()

    $resultsPath = Join-Path $script:ProjectRoot "tests/results"
    if (-not (Test-Path $resultsPath)) {
        return $null
    }

    $latestResult = Get-ChildItem -Path $resultsPath -Filter "*-Summary.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestResult) {
        return Get-Content $latestResult.FullName | ConvertFrom-Json -AsHashtable
    }

    return $null
}

function Get-LatestCoverageData {
    <#
    .SYNOPSIS
        Get the latest coverage data
    #>
    [CmdletBinding()]
    param()

    $coveragePath = Join-Path $script:ProjectRoot "tests/coverage"
    if (-not (Test-Path $coveragePath)) {
        return $null
    }

    $latestCoverage = Get-ChildItem -Path $coveragePath -Filter "coverage-summary.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestCoverage) {
        return Get-Content $latestCoverage.FullName | ConvertFrom-Json -AsHashtable
    }

    return $null
}

function Get-LatestAnalysisResults {
    <#
    .SYNOPSIS
        Get the latest PSScriptAnalyzer results
    #>
    [CmdletBinding()]
    param()

    $analysisPath = Join-Path $script:ProjectRoot "tests/analysis"
    if (-not (Test-Path $analysisPath)) {
        return $null
    }

    $latestAnalysis = Get-ChildItem -Path $analysisPath -Filter "PSScriptAnalyzer-*.csv" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestAnalysis) {
        return Import-Csv $latestAnalysis.FullName
    }

    return $null
}

function Show-TestTrends {
    <#
    .SYNOPSIS
        Display test result trends over time
    #>
    [CmdletBinding()]
    param(
        [int]$Days = 7,

        [switch]$IncludeCoverage,

        [switch]$IncludeAnalysis
    )

    Write-Host "`nTest Result Trends (Last $Days days)" -ForegroundColor Cyan
    Write-Host ("=" * 40) -ForegroundColor Cyan

    # This is a simplified version - real implementation would aggregate historical data
    $resultsPath = Join-Path $script:ProjectRoot "tests/results"
    $cutoffDate = (Get-Date).AddDays(-$Days)

    $summaryFiles = Get-ChildItem -Path $resultsPath -Filter "*-Summary.json" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $cutoffDate } |
        Sort-Object LastWriteTime

    if ($summaryFiles.Count -eq 0) {
        Write-Host "No test results found in the specified period" -ForegroundColor Yellow
        return
    }

    Write-Host "`nDate`t`t`tTotal`tPassed`tFailed`tRate" -ForegroundColor Yellow
    Write-Host ("-" * 60) -ForegroundColor Gray

    foreach ($file in $summaryFiles) {
        $data = Get-Content $file.FullName | ConvertFrom-Json
        $rate = if ($data.TotalTests -gt 0) {
            [Math]::Round(($data.Passed / $data.TotalTests) * 100, 1)
        } else { 0 }

        $rateColor = if ($rate -ge 80) { 'Green' } elseif ($rate -ge 60) { 'Yellow' } else { 'Red' }

        Write-Host "$($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))`t$($data.TotalTests)`t$($data.Passed)`t$($data.Failed)`t" -NoNewline
        Write-Host "$rate%" -ForegroundColor $rateColor
    }
}

function Export-MetricsReport {
    <#
    .SYNOPSIS
        Export detailed metrics report
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,

        [ValidateSet('CSV', 'JSON', 'HTML')]
        [string]$Format = 'CSV',

        [datetime]$StartDate,

        [datetime]$EndDate = (Get-Date),

        [string[]]$MetricTypes = @('Tests', 'Coverage', 'Performance', 'Quality')
    )

    Write-ReportLog "Exporting metrics report in $Format format"

    $metrics = @{
        Period = @{
            Start = $StartDate
            End = $EndDate
        }
        CollectedAt = Get-Date
        Metrics = @{}
    }

    # Collect metrics based on types
    foreach ($type in $MetricTypes) {
        switch ($type) {
            'Tests' {
                $metrics.Metrics.Tests = Get-LatestTestResults
            }
            'Coverage' {
                $metrics.Metrics.Coverage = Get-LatestCoverageData
            }
            'Performance' {
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    # Get performance metrics from logs
                    $metrics.Metrics.Performance = @{
                        AverageExecutionTime = "N/A"
                        PeakMemoryUsage = "N/A"
                    }
                }
            }
            'Quality' {
                $metrics.Metrics.Quality = @{
                    CodeIssues = (Get-LatestAnalysisResults | Measure-Object).Count
                }
            }
        }
    }

    # Set output path
    if (-not $OutputPath) {
        $OutputPath = Join-Path $script:ProjectRoot "tests/reports"
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $filename = "Metrics-$timestamp.$($Format.ToLower())"
    $reportPath = Join-Path $OutputPath $filename

    # Export based on format
    switch ($Format) {
        'JSON' {
            $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
        }
        'CSV' {
            # Flatten metrics for CSV
            $flatMetrics = @()
            foreach ($category in $metrics.Metrics.Keys) {
                $categoryData = $metrics.Metrics[$category]
                if ($categoryData -is [hashtable]) {
                    foreach ($metric in $categoryData.Keys) {
                        $flatMetrics += [PSCustomObject]@{
                            Timestamp = $metrics.CollectedAt
                            Category = $category
                            Metric = $metric
                            Value = $categoryData[$metric]
                        }
                    }
                }
            }
            $flatMetrics | Export-Csv -Path $reportPath -NoTypeInformation
        }
        'HTML' {
            # Simple HTML table
            $html = "<html><head><title>Metrics Report</title></head><body>"
            $html += "<h1>Metrics Report</h1>"
            $html += "<p>Generated: $($metrics.CollectedAt)</p>"
            $html += "<table border='1'><tr><th>Category</th><th>Metric</th><th>Value</th></tr>"

            foreach ($category in $metrics.Metrics.Keys) {
                $categoryData = $metrics.Metrics[$category]
                if ($categoryData -is [hashtable]) {
                    foreach ($metric in $categoryData.Keys) {
                        $html += "<tr><td>$category</td><td>$metric</td><td>$($categoryData[$metric])</td></tr>"
                    }
                }
            }

            $html += "</table></body></html>"
            $html | Set-Content -Path $reportPath
        }
    }

    Write-ReportLog "Metrics report exported to: $reportPath"
    return $reportPath
}

# Initialize on module load
Initialize-ReportingEngine

######################################################################################
# CONSOLIDATED REPORTING FUNCTIONS (from automation scripts 0500-0599)
######################################################################################

function Test-EnvironmentValidation {
    <#
    .SYNOPSIS
        Validate AitherZero environment configuration
    .DESCRIPTION
        Comprehensive environment validation and reporting
        Consolidates 0500_Validate-Environment.ps1
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed,
        [string]$OutputPath = (Join-Path $script:ProjectRoot "reports")
    )

    Write-ReportLog "Running environment validation"

    $validation = @{
        Timestamp = Get-Date
        Overall = $true
        PowerShell = @{}
        Modules = @{}
        Directories = @{}
        Tools = @{}
        Configuration = @{}
        Issues = @()
    }

    # PowerShell validation
    $validation.PowerShell = @{
        Version = $PSVersionTable.PSVersion
        Compatible = $PSVersionTable.PSVersion.Major -ge 7
        Edition = $PSVersionTable.PSEdition
        OS = $PSVersionTable.OS
    }

    if (-not $validation.PowerShell.Compatible) {
        $validation.Issues += "PowerShell 7+ required, found $($PSVersionTable.PSVersion)"
        $validation.Overall = $false
    }

    # Module validation
    $requiredModules = @('Pester', 'PSScriptAnalyzer')
    foreach ($moduleName in $requiredModules) {
        $module = Get-Module -ListAvailable -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
        $validation.Modules[$moduleName] = @{
            Available = $null -ne $module
            Version = if ($module) { $module.Version } else { $null }
        }

        if (-not $module) {
            $validation.Issues += "Required module missing: $moduleName"
            $validation.Overall = $false
        }
    }

    # Directory structure validation
    $requiredDirs = @('logs', 'test-results', 'reports', 'domains')
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $script:ProjectRoot $dir
        $validation.Directories[$dir] = @{
            Exists = Test-Path $dirPath
            Path = $dirPath
        }

        if (-not (Test-Path $dirPath)) {
            $validation.Issues += "Missing directory: $dir"
            $validation.Overall = $false
        }
    }

    # External tools validation
    $tools = @('git', 'node', 'python', 'docker')
    foreach ($tool in $tools) {
        $command = Get-Command $tool -ErrorAction SilentlyContinue
        $validation.Tools[$tool] = @{
            Available = $null -ne $command
            Path = if ($command) { $command.Source } else { $null }
        }
    }

    Write-ReportLog "Environment validation completed. Overall status: $($validation.Overall)"

    return $validation
}

function Get-SystemInformation {
    <#
    .SYNOPSIS
        Gather comprehensive system information
    .DESCRIPTION
        Collects detailed system and environment information
        Consolidates 0501_Get-SystemInfo.ps1
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeHardware,
        [switch]$IncludeNetwork,
        [switch]$IncludeProcesses
    )

    Write-ReportLog "Gathering system information"

    $systemInfo = @{
        Timestamp = Get-Date
        Environment = @{
            OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            OSVersion = [System.Environment]::OSVersion
            Architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
            ProcessorCount = [System.Environment]::ProcessorCount
            MachineName = [System.Environment]::MachineName
            UserName = [System.Environment]::UserName
            WorkingDirectory = Get-Location
        }
        PowerShell = @{
            Version = $PSVersionTable.PSVersion
            Edition = $PSVersionTable.PSEdition
            Host = $Host.Name
            ExecutionPolicy = Get-ExecutionPolicy
            Modules = (Get-Module | Measure-Object).Count
        }
        AitherZero = @{
            ProjectRoot = $script:ProjectRoot
            Version = if (Test-Path (Join-Path $script:ProjectRoot "VERSION")) {
                Get-Content (Join-Path $script:ProjectRoot "VERSION") -Raw
            } else { "Unknown" }
            ModulesLoaded = (Get-Module | Where-Object { $_.Path -like "*$script:ProjectRoot*" }).Count
        }
    }

    if ($IncludeHardware) {
        $systemInfo.Hardware = @{
            TotalMemory = [System.GC]::GetTotalMemory($true)
            AvailableMemory = if ($IsWindows) {
                try {
                    Get-WmiObject -Class Win32_OperatingSystem | ForEach-Object { $_.FreePhysicalMemory * 1KB }
                } catch { "N/A" }
            } else { "N/A" }
        }
    }

    if ($IncludeNetwork) {
        $systemInfo.Network = @{
            HostName = [System.Net.Dns]::GetHostName()
            IPAddresses = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | ForEach-Object { $_.IPAddressToString }
        }
    }

    if ($IncludeProcesses) {
        $systemInfo.Processes = @{
            Total = (Get-Process | Measure-Object).Count
            PowerShellProcesses = (Get-Process -Name pwsh, powershell -ErrorAction SilentlyContinue | Measure-Object).Count
        }
    }

    Write-ReportLog "System information gathered successfully"

    return $systemInfo
}

function New-ProjectReport {
    <#
    .SYNOPSIS
        Generate comprehensive project report
    .DESCRIPTION
        Creates detailed project status and metrics report
        Consolidates 0510_Generate-ProjectReport.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$OutputPath = (Join-Path $script:ProjectRoot "reports"),
        [ValidateSet('Standard', 'Detailed', 'Executive')]
        [string]$ReportType = 'Standard',
        [string]$Format = 'HTML',
        [switch]$ShowAll
    )

    Write-ReportLog "Generating $ReportType project report"

    $report = @{
        GeneratedAt = Get-Date
        ReportType = $ReportType
        ProjectInfo = @{
            Name = "AitherZero"
            Root = $script:ProjectRoot
            Version = if (Test-Path (Join-Path $script:ProjectRoot "VERSION")) {
                Get-Content (Join-Path $script:ProjectRoot "VERSION") -Raw
            } else { "Unknown" }
        }
        Environment = Get-SystemInformation
        Validation = Test-EnvironmentValidation
        Statistics = @{}
        TestResults = @{}
        CodeMetrics = @{}
    }

    # Gather project statistics
    $report.Statistics = @{
        TotalFiles = (Get-ChildItem -Path $script:ProjectRoot -Recurse -File | Measure-Object).Count
        PowerShellFiles = (Get-ChildItem -Path $script:ProjectRoot -Recurse -Include "*.ps1", "*.psm1", "*.psd1" | Measure-Object).Count
        ModuleFiles = (Get-ChildItem -Path (Join-Path $script:ProjectRoot "domains") -Recurse -Filter "*.psm1" | Measure-Object).Count
        AutomationScripts = (Get-ChildItem -Path (Join-Path $script:ProjectRoot "automation-scripts") -Filter "*.ps1" | Measure-Object).Count
        TestFiles = if (Test-Path (Join-Path $script:ProjectRoot "tests")) {
            (Get-ChildItem -Path (Join-Path $script:ProjectRoot "tests") -Recurse -Filter "*.Tests.ps1" | Measure-Object).Count
        } else { 0 }
    }

    # Export report
    if (-not (Test-Path $OutputPath)) {
        if ($PSCmdlet.ShouldProcess($OutputPath, "Create reports directory")) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportFileName = "ProjectReport-$ReportType-$timestamp"

    if ($Format -eq 'HTML') {
        $htmlPath = Join-Path $OutputPath "$reportFileName.html"
        $htmlContent = ConvertTo-ProjectReportHTML -Report $report
        if ($PSCmdlet.ShouldProcess($htmlPath, "Save HTML report")) {
            Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8
            Write-ReportLog "Project report saved: $htmlPath"
        }
        return $htmlPath
    } else {
        $jsonPath = Join-Path $OutputPath "$reportFileName.json"
        if ($PSCmdlet.ShouldProcess($jsonPath, "Save JSON report")) {
            $report | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
            Write-ReportLog "Project report saved: $jsonPath"
        }
        return $jsonPath
    }
}

function Show-ProjectDashboard {
    <#
    .SYNOPSIS
        Display interactive project dashboard
    .DESCRIPTION
        Shows real-time project metrics and status
        Consolidates 0511_Show-ProjectDashboard.ps1
    #>
    [CmdletBinding()]
    param(
        [switch]$Continuous,
        [int]$RefreshSeconds = 30
    )

    Write-ReportLog "Launching project dashboard"

    do {
        Clear-Host

        # Header
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    AitherZero Dashboard                      ║" -ForegroundColor Cyan
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""

        # Get current status
        $validation = Test-EnvironmentValidation
        $systemInfo = Get-SystemInformation

        # Environment Status
        Write-Host "🔧 Environment Status" -ForegroundColor Yellow
        $statusIcon = if ($validation.Overall) { "✅" } else { "❌" }
        Write-Host "   Overall Status: $statusIcon $($validation.Overall)" -ForegroundColor $(if ($validation.Overall) { 'Green' } else { 'Red' })
        Write-Host "   PowerShell: $($systemInfo.PowerShell.Version) ($($systemInfo.PowerShell.Edition))"
        Write-Host "   OS: $($systemInfo.Environment.OS) $($systemInfo.Environment.Architecture)"
        Write-Host ""

        # Project Info
        Write-Host "📊 Project Information" -ForegroundColor Yellow
        Write-Host "   Root: $($script:ProjectRoot)"
        Write-Host "   Modules Loaded: $($systemInfo.AitherZero.ModulesLoaded)"
        Write-Host ""

        # Issues
        if ($validation.Issues.Count -gt 0) {
            Write-Host "⚠️  Issues Found:" -ForegroundColor Red
            foreach ($issue in $validation.Issues) {
                Write-Host "   • $issue" -ForegroundColor DarkRed
            }
            Write-Host ""
        }

        if ($Continuous) {
            Write-Host "Dashboard refreshing every $RefreshSeconds seconds. Press Ctrl+C to exit." -ForegroundColor Gray
            Start-Sleep -Seconds $RefreshSeconds
        }

    } while ($Continuous)
}

function ConvertTo-ProjectReportHTML {
    <#
    .SYNOPSIS
        Convert project report to HTML format
    #>
    param([hashtable]$Report)

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Project Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 15px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { color: green; }
        .error { color: red; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>AitherZero Project Report</h1>
        <p>Generated: $($Report.GeneratedAt)</p>
        <p>Type: $($Report.ReportType)</p>
    </div>

    <div class="section">
        <h2>Project Information</h2>
        <table>
            <tr><td><strong>Name</strong></td><td>$($Report.ProjectInfo.Name)</td></tr>
            <tr><td><strong>Version</strong></td><td>$($Report.ProjectInfo.Version)</td></tr>
            <tr><td><strong>Root Path</strong></td><td>$($Report.ProjectInfo.Root)</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>Environment Status</h2>
        <p class="$($Report.Validation.Overall ? 'success' : 'error')">
            Overall Status: $($Report.Validation.Overall ? 'Valid' : 'Issues Found')
        </p>
    </div>
</body>
</html>
"@

    return $html
}

# Export functions (original + consolidated)
Export-ModuleMember -Function @(
    # Original exports
    'Initialize-ReportingEngine',
    'New-ExecutionDashboard',
    'Update-ExecutionDashboard',
    'Show-Dashboard',
    'Stop-DashboardRefresh',
    'Get-ExecutionMetrics',
    'New-TestReport',
    'Show-TestTrends',
    'Export-MetricsReport',

    # New consolidated exports (from automation scripts 0500-0599)
    'Test-EnvironmentValidation',
    'Get-SystemInformation',
    'New-ProjectReport',
    'Show-ProjectDashboard'
)