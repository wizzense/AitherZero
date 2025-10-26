#Requires -Version 7.0

<#
.SYNOPSIS
    Centralized Reporting and Monitoring Dashboard for AitherZero
.DESCRIPTION
    Provides unified view of all logs, test results, code analysis, and system metrics.
    Consolidates reporting across all AitherZero components.
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
$script:CentralizedLoggingModule = Join-Path $script:ProjectRoot "domains/utilities/CentralizedLogging.psm1"
$script:ReportingEngineModule = Join-Path $script:ProjectRoot "domains/reporting/ReportingEngine.psm1"

# Import modules
foreach ($module in @($script:LoggingModule, $script:CentralizedLoggingModule, $script:ReportingEngineModule)) {
    if (Test-Path $module) {
        Import-Module $module -Force -ErrorAction SilentlyContinue
    }
}

function Show-CentralizedDashboard {
    <#
    .SYNOPSIS
        Display unified centralized dashboard
    .DESCRIPTION
        Shows comprehensive view of logs, tests, analysis, and system metrics
    .PARAMETER RefreshInterval
        Auto-refresh interval in seconds (0 = no auto-refresh)
    .PARAMETER ShowTests
        Include test results section
    .PARAMETER ShowAnalysis
        Include code analysis section
    .PARAMETER ShowLogs
        Include recent logs section
    .PARAMETER ShowMetrics
        Include system metrics section
    .EXAMPLE
        Show-CentralizedDashboard -RefreshInterval 30 -ShowTests -ShowAnalysis
    #>
    [CmdletBinding()]
    param(
        [int]$RefreshInterval = 0,
        [switch]$ShowTests,
        [switch]$ShowAnalysis,
        [switch]$ShowLogs = $true,
        [switch]$ShowMetrics,
        [switch]$ShowAll
    )

    if ($ShowAll) {
        $ShowTests = $true
        $ShowAnalysis = $true
        $ShowLogs = $true
        $ShowMetrics = $true
    }

    $continueLoop = $true

    while ($continueLoop) {
        Clear-Host

        # Header
        Write-Host ""
        Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║                    AITHERZERO CENTRALIZED DASHBOARD                           ║" -ForegroundColor Cyan
        Write-Host "║                  Logging, Testing & Analysis Monitor                          ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host "  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""

        # Log Summary Section
        if ($ShowLogs) {
            Write-Host "┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Yellow
            Write-Host "│ 📋 LOG SUMMARY (Last 24 hours)                                               │" -ForegroundColor Yellow
            Write-Host "└─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Yellow

            $logPath = Join-Path $script:ProjectRoot "logs"

            if (Test-Path $logPath) {
                $logFiles = Get-ChildItem -Path $logPath -Filter "*.log" -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) }

                $logStats = @{
                    'aitherzero' = @{ Count = 0; Size = 0; Color = 'White' }
                    'errors' = @{ Count = 0; Size = 0; Color = 'Red' }
                    'warnings' = @{ Count = 0; Size = 0; Color = 'Yellow' }
                    'critical' = @{ Count = 0; Size = 0; Color = 'Magenta' }
                    'debug' = @{ Count = 0; Size = 0; Color = 'Gray' }
                    'trace' = @{ Count = 0; Size = 0; Color = 'DarkGray' }
                }

                foreach ($file in $logFiles) {
                    $lines = (Get-Content $file.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
                    $sizeKB = [Math]::Round($file.Length / 1KB, 2)

                    foreach ($key in $logStats.Keys) {
                        if ($file.Name -like "$key*") {
                            $logStats[$key].Count = $lines
                            $logStats[$key].Size = $sizeKB
                            break
                        }
                    }
                }

                Write-Host "  Combined Log:  " -NoNewline
                Write-Host "$($logStats['aitherzero'].Count) lines, $($logStats['aitherzero'].Size) KB" -ForegroundColor $logStats['aitherzero'].Color

                Write-Host "  Errors:        " -NoNewline
                Write-Host "$($logStats['errors'].Count) entries, $($logStats['errors'].Size) KB" -ForegroundColor $logStats['errors'].Color

                Write-Host "  Warnings:      " -NoNewline
                Write-Host "$($logStats['warnings'].Count) entries, $($logStats['warnings'].Size) KB" -ForegroundColor $logStats['warnings'].Color

                Write-Host "  Critical:      " -NoNewline
                Write-Host "$($logStats['critical'].Count) entries, $($logStats['critical'].Size) KB" -ForegroundColor $logStats['critical'].Color

                Write-Host "  Debug:         " -NoNewline
                Write-Host "$($logStats['debug'].Count) entries, $($logStats['debug'].Size) KB" -ForegroundColor $logStats['debug'].Color

                Write-Host ""
                Write-Host "  Log Directory: $logPath" -ForegroundColor DarkGray
            } else {
                Write-Host "  No logs found" -ForegroundColor Yellow
            }
            Write-Host ""
        }

        # Test Results Section
        if ($ShowTests) {
            Write-Host "┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Green
            Write-Host "│ ✓ TEST RESULTS (Latest Run)                                                 │" -ForegroundColor Green
            Write-Host "└─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Green

            $resultsPath = Join-Path $script:ProjectRoot "tests/results"
            $latestResults = $null

            if (Test-Path $resultsPath) {
                $summaryFile = Get-ChildItem -Path $resultsPath -Filter "*-Summary.json" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

                if ($summaryFile) {
                    try {
                        $latestResults = Get-Content $summaryFile.FullName | ConvertFrom-Json
                    } catch {
                        Write-Host "  Unable to parse test results" -ForegroundColor Yellow
                    }
                }
            }

            if ($latestResults) {
                $total = if ($latestResults.TotalCount) { $latestResults.TotalCount } elseif ($latestResults.TotalTests) { $latestResults.TotalTests } else { 0 }
                $passed = if ($latestResults.PassedCount) { $latestResults.PassedCount } elseif ($latestResults.Passed) { $latestResults.Passed } else { 0 }
                $failed = if ($latestResults.FailedCount) { $latestResults.FailedCount } elseif ($latestResults.Failed) { $latestResults.Failed } else { 0 }
                $skipped = if ($latestResults.SkippedCount) { $latestResults.SkippedCount } elseif ($latestResults.Skipped) { $latestResults.Skipped } else { 0 }

                $successRate = if ($total -gt 0) { [Math]::Round(($passed / $total) * 100, 2) } else { 0 }

                Write-Host "  Total Tests:    " -NoNewline
                Write-Host $total -ForegroundColor White

                Write-Host "  Passed:         " -NoNewline
                Write-Host $passed -ForegroundColor Green

                Write-Host "  Failed:         " -NoNewline
                Write-Host $failed -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Gray' })

                Write-Host "  Skipped:        " -NoNewline
                Write-Host $skipped -ForegroundColor $(if ($skipped -gt 0) { 'Yellow' } else { 'Gray' })

                Write-Host "  Success Rate:   " -NoNewline
                $rateColor = if ($successRate -ge 80) { 'Green' } elseif ($successRate -ge 60) { 'Yellow' } else { 'Red' }
                Write-Host "$successRate%" -ForegroundColor $rateColor

                if ($latestResults.Duration) {
                    Write-Host "  Duration:       " -NoNewline
                    Write-Host $latestResults.Duration -ForegroundColor Gray
                }
            } else {
                Write-Host "  No test results available" -ForegroundColor Yellow
            }
            Write-Host ""
        }

        # Code Analysis Section
        if ($ShowAnalysis) {
            Write-Host "┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Magenta
            Write-Host "│ 🔍 CODE ANALYSIS (Latest Scan)                                               │" -ForegroundColor Magenta
            Write-Host "└─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Magenta

            $analysisPath = Join-Path $script:ProjectRoot "tests/analysis"
            $latestAnalysis = $null

            if (Test-Path $analysisPath) {
                $analysisFile = Get-ChildItem -Path $analysisPath -Filter "PSScriptAnalyzer-*.csv" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

                if ($analysisFile) {
                    try {
                        $latestAnalysis = Import-Csv $analysisFile.FullName
                    } catch {
                        Write-Host "  Unable to parse analysis results" -ForegroundColor Yellow
                    }
                }
            }

            if ($latestAnalysis) {
                $totalIssues = ($latestAnalysis | Measure-Object).Count
                $errors = ($latestAnalysis | Where-Object { $_.Severity -eq 'Error' } | Measure-Object).Count
                $warnings = ($latestAnalysis | Where-Object { $_.Severity -eq 'Warning' } | Measure-Object).Count
                $informational = ($latestAnalysis | Where-Object { $_.Severity -eq 'Information' } | Measure-Object).Count

                Write-Host "  Total Issues:   " -NoNewline
                Write-Host $totalIssues -ForegroundColor $(if ($totalIssues -gt 0) { 'Yellow' } else { 'Green' })

                Write-Host "  Errors:         " -NoNewline
                Write-Host $errors -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Gray' })

                Write-Host "  Warnings:       " -NoNewline
                Write-Host $warnings -ForegroundColor $(if ($warnings -gt 0) { 'Yellow' } else { 'Gray' })

                Write-Host "  Informational:  " -NoNewline
                Write-Host $informational -ForegroundColor Gray

                # Show top issues
                if ($totalIssues -gt 0) {
                    $topIssues = $latestAnalysis | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 3
                    Write-Host ""
                    Write-Host "  Top Issues:" -ForegroundColor DarkGray
                    foreach ($issue in $topIssues) {
                        Write-Host "    • $($issue.Name): $($issue.Count) occurrences" -ForegroundColor DarkGray
                    }
                }
            } else {
                Write-Host "  No analysis results available" -ForegroundColor Yellow
            }
            Write-Host ""
        }

        # System Metrics Section
        if ($ShowMetrics) {
            Write-Host "┌─────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor Blue
            Write-Host "│ 📊 SYSTEM METRICS                                                            │" -ForegroundColor Blue
            Write-Host "└─────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor Blue

            try {
                $process = Get-Process -Id $PID
                $memoryMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
                $threadsCount = $process.Threads.Count

                Write-Host "  Process Memory: $memoryMB MB" -ForegroundColor Cyan
                Write-Host "  Threads:        $threadsCount" -ForegroundColor Cyan
                Write-Host "  CPU Cores:      $([System.Environment]::ProcessorCount)" -ForegroundColor Cyan

                if ($IsWindows) {
                    try {
                        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                        if ($os) {
                            $freeMemGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
                            $totalMemGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
                            $memPercent = [Math]::Round((($totalMemGB - $freeMemGB) / $totalMemGB) * 100, 1)
                            Write-Host "  System Memory:  $freeMemGB GB free / $totalMemGB GB total ($memPercent% used)" -ForegroundColor Cyan
                        }
                    } catch {
                        # Silently skip if CIM query fails
                    }
                }
            } catch {
                Write-Host "  Unable to retrieve system metrics" -ForegroundColor Yellow
            }
            Write-Host ""
        }

        # Footer
        Write-Host "─────────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

        if ($RefreshInterval -gt 0) {
            Write-Host "  Auto-refresh in $RefreshInterval seconds. Press Ctrl+C to exit." -ForegroundColor DarkGray
            Start-Sleep -Seconds $RefreshInterval
        } else {
            $continueLoop = $false
        }
    }
}

function Export-CentralizedReport {
    <#
    .SYNOPSIS
        Export comprehensive centralized report
    .DESCRIPTION
        Generates a complete report combining logs, tests, analysis, and metrics
    .PARAMETER OutputPath
        Path for the report file
    .PARAMETER Format
        Report format (HTML, JSON, Markdown)
    .PARAMETER IncludeTests
        Include test results
    .PARAMETER IncludeAnalysis
        Include code analysis
    .PARAMETER IncludeLogs
        Include log summary
    .PARAMETER IncludeMetrics
        Include system metrics
    .EXAMPLE
        Export-CentralizedReport -Format HTML -IncludeTests -IncludeAnalysis
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,

        [ValidateSet('HTML', 'JSON', 'Markdown')]
        [string]$Format = 'HTML',

        [switch]$IncludeTests,
        [switch]$IncludeAnalysis,
        [switch]$IncludeLogs = $true,
        [switch]$IncludeMetrics,
        [switch]$IncludeAll
    )

    if ($IncludeAll) {
        $IncludeTests = $true
        $IncludeAnalysis = $true
        $IncludeLogs = $true
        $IncludeMetrics = $true
    }

    Write-Host "Generating centralized report..." -ForegroundColor Cyan

    $report = @{
        Title = "AitherZero Centralized Report"
        Generated = Get-Date
        Format = $Format
        Sections = @{}
    }

    # Collect data for each section
    if ($IncludeLogs) {
        $logPath = Join-Path $script:ProjectRoot "logs"
        if (Test-Path $logPath) {
            $logFiles = Get-ChildItem -Path $logPath -Filter "*.log" -ErrorAction SilentlyContinue
            $report.Sections.Logs = @{
                TotalFiles = $logFiles.Count
                Files = $logFiles | ForEach-Object {
                    @{
                        Name = $_.Name
                        Lines = (Get-Content $_.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
                        SizeKB = [Math]::Round($_.Length / 1KB, 2)
                        LastModified = $_.LastWriteTime
                    }
                }
            }
        }
    }

    if ($IncludeTests) {
        if (Get-Command Get-LatestTestResults -ErrorAction SilentlyContinue) {
            $report.Sections.Tests = Get-LatestTestResults
        }
    }

    if ($IncludeAnalysis) {
        if (Get-Command Get-LatestAnalysisResults -ErrorAction SilentlyContinue) {
            $report.Sections.Analysis = Get-LatestAnalysisResults
        }
    }

    if ($IncludeMetrics) {
        $report.Sections.Metrics = @{
            ProcessMemoryMB = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB, 2)
            Threads = (Get-Process -Id $PID).Threads.Count
            CPUCores = [System.Environment]::ProcessorCount
        }
    }

    # Set output path
    if (-not $OutputPath) {
        $reportsPath = Join-Path $script:ProjectRoot "reports"
        if (-not (Test-Path $reportsPath)) {
            New-Item -ItemType Directory -Path $reportsPath -Force | Out-Null
        }
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $OutputPath = Join-Path $reportsPath "CentralizedReport-$timestamp.$($Format.ToLower())"
    }

    # Export based on format
    switch ($Format) {
        'JSON' {
            $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
        }
        'Markdown' {
            $md = "# $($report.Title)`n`nGenerated: $($report.Generated)`n`n"
            foreach ($section in $report.Sections.Keys) {
                $md += "## $section`n`n"
                $md += ($report.Sections[$section] | ConvertTo-Json -Depth 5) + "`n`n"
            }
            $md | Set-Content -Path $OutputPath
        }
        'HTML' {
            # Use the ReportingEngine's HTML generation if available
            if (Get-Command New-HtmlReport -ErrorAction SilentlyContinue) {
                $html = New-HtmlReport -Report $report
                $html | Set-Content -Path $OutputPath
            } else {
                # Simple fallback HTML
                $html = @"
<!DOCTYPE html>
<html>
<head><title>$($report.Title)</title></head>
<body>
<h1>$($report.Title)</h1>
<p>Generated: $($report.Generated)</p>
<pre>$($report | ConvertTo-Json -Depth 10)</pre>
</body>
</html>
"@
                $html | Set-Content -Path $OutputPath
            }
        }
    }

    Write-Host "Report generated: $OutputPath" -ForegroundColor Green
    return $OutputPath
}

function Get-LogFileAnalysis {
    <#
    .SYNOPSIS
        Analyze log files for patterns and issues
    .DESCRIPTION
        Provides statistical analysis of log files
    .PARAMETER Hours
        Number of hours to analyze (default: 24)
    #>
    [CmdletBinding()]
    param(
        [int]$Hours = 24
    )

    $logPath = Join-Path $script:ProjectRoot "logs"
    $cutoff = (Get-Date).AddHours(-$Hours)

    $analysis = @{
        Period = $Hours
        Timestamp = Get-Date
        ErrorCount = 0
        WarningCount = 0
        CriticalCount = 0
        TopSources = @{}
        TopErrors = @{}
    }

    if (Test-Path $logPath) {
        # Analyze error log
        $errorLog = Join-Path $logPath "errors-$(Get-Date -Format 'yyyy-MM-dd').log"
        if (Test-Path $errorLog) {
            $errors = Get-Content $errorLog -ErrorAction SilentlyContinue
            $analysis.ErrorCount = ($errors | Measure-Object -Line).Lines

            # Extract sources
            foreach ($line in $errors) {
                if ($line -match '\[([^\]]+)\]\s+\[([^\]]+)\]') {
                    $source = $Matches[2]
                    if (-not $analysis.TopSources.ContainsKey($source)) {
                        $analysis.TopSources[$source] = 0
                    }
                    $analysis.TopSources[$source]++
                }
            }
        }

        # Analyze warning log
        $warningLog = Join-Path $logPath "warnings-$(Get-Date -Format 'yyyy-MM-dd').log"
        if (Test-Path $warningLog) {
            $warnings = Get-Content $warningLog -ErrorAction SilentlyContinue
            $analysis.WarningCount = ($warnings | Measure-Object -Line).Lines
        }

        # Analyze critical log
        $criticalLog = Join-Path $logPath "critical-$(Get-Date -Format 'yyyy-MM-dd').log"
        if (Test-Path $criticalLog) {
            $critical = Get-Content $criticalLog -ErrorAction SilentlyContinue
            $analysis.CriticalCount = ($critical | Measure-Object -Line).Lines
        }
    }

    return $analysis
}

# Export functions
Export-ModuleMember -Function @(
    'Show-CentralizedDashboard',
    'Export-CentralizedReport',
    'Get-LogFileAnalysis'
)
