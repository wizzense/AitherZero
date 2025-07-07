function Export-UtilityReport {
    <#
    .SYNOPSIS
        Exports comprehensive utility services report
    
    .DESCRIPTION
        Generates detailed reports covering all utility services including
        service status, metrics, recent operations, and system health
    
    .PARAMETER OutputPath
        Path for the exported report
    
    .PARAMETER Format
        Report format (HTML, JSON, Text)
    
    .PARAMETER TimeRange
        Time range for metrics and activity
    
    .PARAMETER IncludeMetrics
        Whether to include detailed metrics
    
    .EXAMPLE
        Export-UtilityReport -OutputPath "./reports/utility-report.html" -Format HTML
        
        Export HTML report to specified path
    
    .EXAMPLE
        Export-UtilityReport -Format JSON -TimeRange "LastWeek" -IncludeMetrics
        
        Export JSON report with metrics for the last week
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        
        [ValidateSet('HTML', 'JSON', 'Text')]
        [string]$Format = 'HTML',
        
        [ValidateSet('LastHour', 'Last24Hours', 'LastWeek', 'All')]
        [string]$TimeRange = 'Last24Hours',
        
        [switch]$IncludeMetrics
    )
    
    begin {
        Write-UtilityLog "📊 Generating UtilityServices report" -Level "INFO"
        
        if (-not $OutputPath) {
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $extension = switch ($Format) {
                'HTML' { 'html' }
                'JSON' { 'json' }
                'Text' { 'txt' }
            }
            $OutputPath = "./utility-services-report-$timestamp.$extension"
        }
    }
    
    process {
        try {
            # Collect comprehensive data
            $reportData = @{
                GeneratedAt = Get-Date
                TimeRange = $TimeRange
                Format = $Format
                ServiceStatus = Get-UtilityServiceStatus
                Configuration = Get-UtilityConfiguration
                RecentEvents = Get-UtilityEvents -Count 50
                OperationHistory = $script:UtilityServices.IntegratedServices.History
            }
            
            if ($IncludeMetrics) {
                $reportData.Metrics = Get-UtilityMetrics -TimeRange $TimeRange
            }
            
            # Generate report based on format
            $reportContent = switch ($Format) {
                'HTML' { 
                    New-HTMLUtilityReport -Data $reportData 
                }
                'JSON' { 
                    $reportData | ConvertTo-Json -Depth 10 
                }
                'Text' { 
                    New-TextUtilityReport -Data $reportData 
                }
            }
            
            # Write report to file
            $reportContent | Out-File -FilePath $OutputPath -Encoding UTF8
            
            Write-UtilityLog "✅ Report exported successfully: $OutputPath" -Level "SUCCESS"
            
            return @{
                OutputPath = $OutputPath
                Format = $Format
                Size = (Get-Item $OutputPath).Length
                GeneratedAt = Get-Date
                Success = $true
            }
            
        } catch {
            Write-UtilityLog "❌ Failed to export report: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function New-HTMLUtilityReport {
    <#
    .SYNOPSIS
        Generates HTML utility services report
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Data
    )
    
    $healthColor = switch ($Data.ServiceStatus.SystemHealth) {
        'Healthy' { '#28a745' }
        'Degraded' { '#ffc107' }
        'Critical' { '#dc3545' }
        default { '#6c757d' }
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>UtilityServices Report - $($Data.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f8f9fa; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; text-align: center; }
        .header h1 { margin: 0; font-size: 2.5em; }
        .header p { margin: 5px 0 0 0; opacity: 0.9; }
        .section { background: white; padding: 25px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .section h2 { color: #495057; border-bottom: 2px solid #e9ecef; padding-bottom: 10px; margin-top: 0; }
        .status-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin: 15px 0; }
        .status-card { background: #f8f9fa; padding: 15px; border-radius: 8px; border-left: 4px solid #007bff; }
        .status-card.healthy { border-left-color: #28a745; }
        .status-card.degraded { border-left-color: #ffc107; }
        .status-card.critical { border-left-color: #dc3545; }
        .metric { display: inline-block; margin: 10px 15px 10px 0; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: $healthColor; display: block; }
        .metric-label { font-size: 0.9em; color: #6c757d; }
        .event-list { max-height: 300px; overflow-y: auto; }
        .event-item { padding: 8px; border-bottom: 1px solid #e9ecef; font-family: monospace; font-size: 0.9em; }
        .event-item:last-child { border-bottom: none; }
        .health-indicator { display: inline-block; width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; background-color: $healthColor; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #e9ecef; }
        th { background-color: #f8f9fa; font-weight: 600; }
        .config-item { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f1f3f4; }
        .config-item:last-child { border-bottom: none; }
        .timestamp { color: #6c757d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔧 UtilityServices Report</h1>
        <p>Generated: $($Data.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss')) | Time Range: $($Data.TimeRange)</p>
    </div>

    <div class="section">
        <h2>🏥 System Health Overview</h2>
        <div class="status-grid">
            <div class="status-card $(($Data.ServiceStatus.SystemHealth).ToLower())">
                <h3><span class="health-indicator"></span>Overall Health</h3>
                <p><strong>$($Data.ServiceStatus.SystemHealth)</strong></p>
                <p>$($Data.ServiceStatus.Services.Count) services • $($Data.ServiceStatus.IntegratedOperations) active operations</p>
            </div>
        </div>
        
        <div class="metric">
            <span class="metric-value">$((($Data.ServiceStatus.Services.Values | Where-Object Loaded).Count))</span>
            <span class="metric-label">Services Active</span>
        </div>
        <div class="metric">
            <span class="metric-value">$($Data.ServiceStatus.EventSystem.Subscribers)</span>
            <span class="metric-label">Event Subscribers</span>
        </div>
        <div class="metric">
            <span class="metric-value">$($Data.ServiceStatus.EventSystem.EventHistory)</span>
            <span class="metric-label">Events in History</span>
        </div>
    </div>

    <div class="section">
        <h2>🔧 Service Status</h2>
        <table>
            <thead>
                <tr>
                    <th>Service</th>
                    <th>Status</th>
                    <th>Functions</th>
                    <th>Health</th>
                </tr>
            </thead>
            <tbody>
"@

    foreach ($serviceName in $Data.ServiceStatus.Services.Keys) {
        $service = $Data.ServiceStatus.Services[$serviceName]
        $statusIcon = if ($service.Loaded) { "✅" } else { "❌" }
        $statusText = if ($service.Loaded) { "Active" } else { "Inactive" }
        
        $html += @"
                <tr>
                    <td><strong>$serviceName</strong></td>
                    <td>$statusIcon $statusText</td>
                    <td>$($service.FunctionCount) functions</td>
                    <td>$(if ($service.Loaded) { '<span style="color: #28a745;">Healthy</span>' } else { '<span style="color: #dc3545;">Offline</span>' })</td>
                </tr>
"@
    }

    $html += @"
            </tbody>
        </table>
    </div>

    <div class="section">
        <h2>📊 Recent Activity</h2>
        <div class="event-list">
"@

    foreach ($event in ($Data.RecentEvents | Select-Object -First 20)) {
        $timeAgo = ((Get-Date) - $event.Timestamp).TotalMinutes
        $timeDisplay = if ($timeAgo -lt 1) { "< 1m ago" } else { "$([Math]::Floor($timeAgo))m ago" }
        
        $html += @"
            <div class="event-item">
                <strong>$($event.EventType)</strong> from $($event.Source) 
                <span class="timestamp">($timeDisplay)</span>
            </div>
"@
    }

    $html += @"
        </div>
    </div>

    <div class="section">
        <h2>⚙️ Configuration</h2>
"@

    foreach ($configKey in $Data.Configuration.Keys) {
        $html += @"
        <div class="config-item">
            <span><strong>$configKey</strong></span>
            <span>$($Data.Configuration[$configKey])</span>
        </div>
"@
    }

    if ($Data.Metrics) {
        $html += @"
    </div>

    <div class="section">
        <h2>📈 Metrics ($($Data.TimeRange))</h2>
        <div class="metric">
            <span class="metric-value">$($Data.Metrics.IntegratedOperations.Total)</span>
            <span class="metric-label">Total Operations</span>
        </div>
        <div class="metric">
            <span class="metric-value">$($Data.Metrics.IntegratedOperations.Successful)</span>
            <span class="metric-label">Successful</span>
        </div>
        <div class="metric">
            <span class="metric-value">$($Data.Metrics.IntegratedOperations.Failed)</span>
            <span class="metric-label">Failed</span>
        </div>
        <div class="metric">
            <span class="metric-value">$($Data.Metrics.EventSystem.EventsPublished)</span>
            <span class="metric-label">Events Published</span>
        </div>
"@

        if ($Data.Metrics.IntegratedOperations.AverageExecutionTime -gt 0) {
            $html += @"
        <div class="metric">
            <span class="metric-value">${[Math]::Round($Data.Metrics.IntegratedOperations.AverageExecutionTime, 1)}s</span>
            <span class="metric-label">Avg Execution Time</span>
        </div>
"@
        }
    }

    $html += @"
    </div>

    <div class="section">
        <h2>📋 Operation History</h2>
        <p>$($Data.OperationHistory.Count) integrated operations recorded</p>
        <p class="timestamp">Report generated by AitherZero UtilityServices v1.0.0</p>
    </div>

</body>
</html>
"@

    return $html
}

function New-TextUtilityReport {
    <#
    .SYNOPSIS
        Generates text utility services report
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Data
    )
    
    $report = @()
    $report += "=" * 80
    $report += "AitherZero UtilityServices Report"
    $report += "=" * 80
    $report += "Generated: $($Data.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))"
    $report += "Time Range: $($Data.TimeRange)"
    $report += ""
    
    # System Health
    $report += "SYSTEM HEALTH:"
    $report += "  Overall Status: $($Data.ServiceStatus.SystemHealth)"
    $report += "  Active Services: $(($Data.ServiceStatus.Services.Values | Where-Object Loaded).Count)/$($Data.ServiceStatus.Services.Count)"
    $report += "  Integrated Operations: $($Data.ServiceStatus.IntegratedOperations)"
    $report += "  Event Subscribers: $($Data.ServiceStatus.EventSystem.Subscribers)"
    $report += ""
    
    # Service Status
    $report += "SERVICE STATUS:"
    foreach ($serviceName in $Data.ServiceStatus.Services.Keys) {
        $service = $Data.ServiceStatus.Services[$serviceName]
        $status = if ($service.Loaded) { "ACTIVE" } else { "INACTIVE" }
        $report += "  $serviceName`: $status ($($service.FunctionCount) functions)"
    }
    $report += ""
    
    # Configuration
    $report += "CONFIGURATION:"
    foreach ($configKey in $Data.Configuration.Keys) {
        $report += "  $configKey`: $($Data.Configuration[$configKey])"
    }
    $report += ""
    
    # Recent Events
    $report += "RECENT ACTIVITY (Last 10 events):"
    foreach ($event in ($Data.RecentEvents | Select-Object -First 10)) {
        $timeAgo = ((Get-Date) - $event.Timestamp).TotalMinutes
        $timeDisplay = if ($timeAgo -lt 1) { "<1m ago" } else { "$([Math]::Floor($timeAgo))m ago" }
        $report += "  [$timeDisplay] $($event.EventType) from $($event.Source)"
    }
    $report += ""
    
    # Metrics (if included)
    if ($Data.Metrics) {
        $report += "METRICS ($($Data.TimeRange)):"
        $report += "  Integrated Operations:"
        $report += "    Total: $($Data.Metrics.IntegratedOperations.Total)"
        $report += "    Successful: $($Data.Metrics.IntegratedOperations.Successful)"
        $report += "    Failed: $($Data.Metrics.IntegratedOperations.Failed)"
        if ($Data.Metrics.IntegratedOperations.AverageExecutionTime -gt 0) {
            $report += "    Average Execution Time: $([Math]::Round($Data.Metrics.IntegratedOperations.AverageExecutionTime, 2))s"
        }
        $report += "  Event System:"
        $report += "    Events Published: $($Data.Metrics.EventSystem.EventsPublished)"
        $report += ""
    }
    
    $report += "=" * 80
    $report += "End of Report"
    $report += "=" * 80
    
    return $report -join "`n"
}