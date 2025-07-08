<#
.SYNOPSIS
    Stops the active system monitoring session.

.DESCRIPTION
    Stop-SystemMonitoring gracefully terminates the running monitoring session,
    collects final metrics, generates a summary report, and optionally exports
    the monitoring data for analysis.

.PARAMETER ExportReport
    Export a detailed monitoring report to file.

.PARAMETER Format
    Report format. Valid values: 'JSON', 'HTML', 'CSV'

.PARAMETER Force
    Force stop monitoring without collecting final metrics.

.EXAMPLE
    Stop-SystemMonitoring
    Stops monitoring and displays summary.

.EXAMPLE
    Stop-SystemMonitoring -ExportReport -Format HTML
    Stops monitoring and exports an HTML report.
#>
function Stop-SystemMonitoring {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ExportReport,

        [Parameter()]
        [ValidateSet('JSON', 'HTML', 'CSV')]
        [string]$Format = 'JSON',

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Message "Stopping system monitoring" -Level "INFO"

        # Check if monitoring is running
        if (-not $script:MonitoringJob) {
            Write-CustomLog -Message "No active monitoring session found" -Level "WARNING"
            return
        }

        $jobState = $script:MonitoringJob.State
        if ($jobState -ne 'Running' -and -not $Force) {
            Write-CustomLog -Message "Monitoring job is not running (State: $jobState)" -Level "WARNING"
            return
        }
    }

    process {
        try {
            $summary = $null

            if (-not $Force) {
                # Wait for job to complete gracefully
                Write-CustomLog -Message "Waiting for monitoring job to complete..." -Level "INFO"

                # Signal job to stop (would need inter-process communication in real implementation)
                Stop-Job -Job $script:MonitoringJob

                # Collect job results
                $summary = Receive-Job -Job $script:MonitoringJob -Wait
            } else {
                # Force stop
                Stop-Job -Job $script:MonitoringJob -Force
                Write-CustomLog -Message "Monitoring forcefully stopped" -Level "WARNING"
            }

            # Remove job
            Remove-Job -Job $script:MonitoringJob -Force

            # Generate report if we have summary data
            if ($summary) {
                # Create comprehensive report
                $report = @{
                    SessionInfo = @{
                        StartTime = $summary.StartTime
                        EndTime = $summary.EndTime
                        Duration = [Math]::Round(($summary.EndTime - $summary.StartTime).TotalMinutes, 2)
                        Profile = $script:MonitoringConfig.MonitoringProfile
                    }
                    AlertSummary = @{
                        TotalAlerts = $summary.TotalAlerts
                        ByLevel = $summary.AlertsByLevel
                    }
                    FinalMetrics = $summary.FinalMetrics
                    PerformanceAnalysis = Analyze-MonitoringResults -Summary $summary
                }

                # Display summary
                Write-Host "`n=== System Monitoring Summary ===" -ForegroundColor Cyan
                Write-Host "Duration: $($report.SessionInfo.Duration) minutes"
                Write-Host "Total Alerts: $($report.AlertSummary.TotalAlerts)"

                if ($report.AlertSummary.ByLevel) {
                    Write-Host "`nAlerts by Level:"
                    $report.AlertSummary.ByLevel | ForEach-Object {
                        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor $(
                            switch ($_.Name) {
                                'CRITICAL' { 'Red' }
                                'WARNING' { 'Yellow' }
                                default { 'Gray' }
                            }
                        )
                    }
                }

                if ($report.PerformanceAnalysis.Issues) {
                    Write-Host "`nPerformance Issues Detected:" -ForegroundColor Yellow
                    $report.PerformanceAnalysis.Issues | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor Yellow
                    }
                }

                # Export report if requested
                if ($ExportReport) {
                    Export-MonitoringReport -Report $report -Format $Format
                }

                # Return report object
                return $report
            }

            # Clear monitoring data
            $script:MonitoringJob = $null
            $script:MonitoringConfig = $null
            $script:MonitoringStartTime = $null
            $script:MonitoringData = @{}

        } catch {
            Write-CustomLog -Message "Error stopping monitoring: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function to analyze monitoring results
function Analyze-MonitoringResults {
    param($Summary)

    $analysis = @{
        Issues = @()
        Recommendations = @()
        Trends = @{}
    }

    # Analyze alerts
    if ($Summary.TotalAlerts -gt 0) {
        $criticalCount = ($Summary.AlertsByLevel | Where-Object { $_.Name -eq 'CRITICAL' }).Count
        $warningCount = ($Summary.AlertsByLevel | Where-Object { $_.Name -eq 'WARNING' }).Count

        if ($criticalCount -gt 0) {
            $analysis.Issues += "$criticalCount critical alerts detected"
            $analysis.Recommendations += "Investigate critical performance issues immediately"
        }

        if ($warningCount -gt 5) {
            $analysis.Issues += "High number of warning alerts ($warningCount)"
            $analysis.Recommendations += "Review system capacity and resource allocation"
        }
    }

    # Analyze final metrics
    if ($Summary.FinalMetrics) {
        # Check system metrics
        if ($Summary.FinalMetrics.System) {
            $cpu = $Summary.FinalMetrics.System.CPU.Average
            $memory = $Summary.FinalMetrics.System.Memory.Average

            if ($cpu -gt 80) {
                $analysis.Issues += "High CPU usage: $cpu%"
                $analysis.Recommendations += "Consider scaling compute resources or optimizing workloads"
            }

            if ($memory -gt 85) {
                $analysis.Issues += "High memory usage: $memory%"
                $analysis.Recommendations += "Review memory-intensive operations and consider increasing RAM"
            }
        }

        # Check SLA compliance
        if ($Summary.FinalMetrics.SLACompliance -and $Summary.FinalMetrics.SLACompliance.Overall -eq "Fail") {
            $failedSLAs = $Summary.FinalMetrics.SLACompliance.Details |
                Where-Object { $_.Value.Status -eq "Fail" } |
                ForEach-Object { $_.Key }

            $analysis.Issues += "SLA violations detected: $($failedSLAs -join ', ')"
            $analysis.Recommendations += "Review and optimize operations failing SLA targets"
        }
    }

    # Performance trends (would analyze historical data in full implementation)
    $analysis.Trends = @{
        CPUTrend = "Stable"  # Placeholder
        MemoryTrend = "Stable"
        AlertTrend = if ($Summary.TotalAlerts -gt 10) { "Increasing" } else { "Normal" }
    }

    return $analysis
}

# Helper function to export monitoring report
function Export-MonitoringReport {
    param($Report, $Format)

    try {
        $reportPath = Join-Path $script:ProjectRoot "reports/monitoring"
        if (-not (Test-Path $reportPath)) {
            New-Item -Path $reportPath -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $filename = "monitoring-report-$timestamp"

        switch ($Format) {
            'JSON' {
                $filepath = Join-Path $reportPath "$filename.json"
                $Report | ConvertTo-Json -Depth 10 | Out-File -FilePath $filepath -Encoding UTF8
            }

            'HTML' {
                $filepath = Join-Path $reportPath "$filename.html"
                $html = ConvertTo-MonitoringHtml -Report $Report
                $html | Out-File -FilePath $filepath -Encoding UTF8
            }

            'CSV' {
                $filepath = Join-Path $reportPath "$filename.csv"
                # Flatten report structure for CSV
                $csvData = @()

                # Session info
                $csvData += [PSCustomObject]@{
                    Category = "Session"
                    Metric = "Duration"
                    Value = "$($Report.SessionInfo.Duration) minutes"
                }
                $csvData += [PSCustomObject]@{
                    Category = "Session"
                    Metric = "TotalAlerts"
                    Value = $Report.AlertSummary.TotalAlerts
                }

                # Alert breakdown
                if ($Report.AlertSummary.ByLevel) {
                    $Report.AlertSummary.ByLevel | ForEach-Object {
                        $csvData += [PSCustomObject]@{
                            Category = "Alerts"
                            Metric = $_.Name
                            Value = $_.Count
                        }
                    }
                }

                $csvData | Export-Csv -Path $filepath -NoTypeInformation
            }
        }

        Write-CustomLog -Message "Monitoring report exported to: $filepath" -Level "SUCCESS"
        Write-Host "Report saved to: $filepath" -ForegroundColor Green

    } catch {
        Write-CustomLog -Message "Error exporting report: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Helper function to convert report to HTML
function ConvertTo-MonitoringHtml {
    param($Report)

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Monitoring Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin: 20px 0; }
        .info-card { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007acc; }
        .metric { font-size: 24px; font-weight: bold; color: #007acc; }
        .label { color: #666; font-size: 14px; }
        .alert-critical { color: #dc3545; }
        .alert-warning { color: #ffc107; }
        .issues { background-color: #fff3cd; border-left-color: #ffc107; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .recommendations { background-color: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #007acc; color: white; }
        tr:hover { background-color: #f5f5f5; }
    </style>
</head>
<body>
    <div class="container">
        <h1>AitherZero System Monitoring Report</h1>

        <div class="info-grid">
            <div class="info-card">
                <div class="label">Monitoring Duration</div>
                <div class="metric">$($Report.SessionInfo.Duration) min</div>
            </div>
            <div class="info-card">
                <div class="label">Total Alerts</div>
                <div class="metric">$($Report.AlertSummary.TotalAlerts)</div>
            </div>
            <div class="info-card">
                <div class="label">Profile Used</div>
                <div class="metric">$($Report.SessionInfo.Profile)</div>
            </div>
        </div>

        <h2>Alert Summary</h2>
        <table>
            <tr><th>Alert Level</th><th>Count</th></tr>
"@

    if ($Report.AlertSummary.ByLevel) {
        $Report.AlertSummary.ByLevel | ForEach-Object {
            $cssClass = switch ($_.Name) {
                'CRITICAL' { 'alert-critical' }
                'WARNING' { 'alert-warning' }
                default { '' }
            }
            $html += "<tr><td class='$cssClass'>$($_.Name)</td><td>$($_.Count)</td></tr>"
        }
    }

    $html += "</table>"

    if ($Report.PerformanceAnalysis.Issues.Count -gt 0) {
        $html += @"
        <h2>Performance Issues</h2>
        <div class="issues">
            <ul>
"@
        $Report.PerformanceAnalysis.Issues | ForEach-Object {
            $html += "<li>$_</li>"
        }
        $html += "</ul></div>"
    }

    if ($Report.PerformanceAnalysis.Recommendations.Count -gt 0) {
        $html += @"
        <h2>Recommendations</h2>
        <div class="recommendations">
            <ul>
"@
        $Report.PerformanceAnalysis.Recommendations | ForEach-Object {
            $html += "<li>$_</li>"
        }
        $html += "</ul></div>"
    }

    $html += @"
        <p style="text-align: center; color: #666; margin-top: 40px;">
            Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        </p>
    </div>
</body>
</html>
"@

    return $html
}

# Export public function
Export-ModuleMember -Function Stop-SystemMonitoring
