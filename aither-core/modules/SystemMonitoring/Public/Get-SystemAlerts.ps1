#Requires -Version 7.0

<#
.SYNOPSIS
    Manages system alerts and notifications for AitherZero infrastructure.

.DESCRIPTION
    This function provides comprehensive alert management including viewing active alerts,
    acknowledging alerts, setting up notifications, and managing alert thresholds.
    Integrates with the monitoring system to provide real-time alerting.

.PARAMETER Active
    Shows only currently active alerts.

.PARAMETER Severity
    Filters alerts by severity level (Critical, High, Medium, Low).

.PARAMETER Acknowledge
    Acknowledges specified alert IDs.

.PARAMETER AlertIds
    Specific alert IDs to acknowledge when using -Acknowledge.

.PARAMETER Mute
    Temporarily mutes alerts for the specified duration.

.PARAMETER Duration
    Duration for muting alerts (e.g., '30m', '2h', '1d').

.PARAMETER Export
    Exports alert data to JSON format.

.EXAMPLE
    Get-SystemAlerts -Active
    
    Shows all currently active alerts.

.EXAMPLE
    Get-SystemAlerts -Severity Critical
    
    Shows only critical severity alerts.

.EXAMPLE
    Get-SystemAlerts -Acknowledge -AlertIds "ALT001","ALT002"
    
    Acknowledges specific alerts.

.NOTES
    Part of the AitherZero SystemMonitoring module for comprehensive
    infrastructure alert management.
#>

function Get-SystemAlerts {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Active,
        
        [Parameter()]
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$Severity,
        
        [Parameter()]
        [switch]$Acknowledge,
        
        [Parameter()]
        [string[]]$AlertIds,
        
        [Parameter()]
        [switch]$Mute,
        
        [Parameter()]
        [string]$Duration,
        
        [Parameter()]
        [switch]$Export
    )

    begin {
        Write-CustomLog -Message "Processing system alerts request" -Level "INFO"
        
        # Initialize alert storage if not exists
        if (-not $script:AlertHistory) {
            $script:AlertHistory = @()
        }
        
        if (-not $script:MutedAlerts) {
            $script:MutedAlerts = @()
        }
    }

    process {
        try {
            # Generate current system alerts
            $currentAlerts = Get-CurrentSystemAlerts
            
            # Handle acknowledgment
            if ($Acknowledge -and $AlertIds) {
                foreach ($alertId in $AlertIds) {
                    $alert = $script:AlertHistory | Where-Object { $_.Id -eq $alertId }
                    if ($alert) {
                        $alert.Acknowledged = $true
                        $alert.AcknowledgedBy = $env:USERNAME ?? $env:USER ?? "System"
                        $alert.AcknowledgedAt = Get-Date
                        Write-CustomLog -Message "Alert $alertId acknowledged by $($alert.AcknowledgedBy)" -Level "INFO"
                    }
                }
                Write-Host "✅ Acknowledged $($AlertIds.Count) alerts" -ForegroundColor Green
                return
            }
            
            # Handle muting
            if ($Mute -and $Duration) {
                $muteUntil = Add-DurationToDate -Date (Get-Date) -Duration $Duration
                $muteEntry = @{
                    MutedAt = Get-Date
                    MutedUntil = $muteUntil
                    MutedBy = $env:USERNAME ?? $env:USER ?? "System"
                    Duration = $Duration
                }
                $script:MutedAlerts += $muteEntry
                Write-Host "🔇 Alerts muted until $($muteUntil.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
                Write-CustomLog -Message "Alerts muted for $Duration by $($muteEntry.MutedBy)" -Level "INFO"
                return
            }
            
            # Filter alerts based on parameters
            $filteredAlerts = $currentAlerts
            
            if ($Active) {
                $filteredAlerts = $filteredAlerts | Where-Object { -not $_.Resolved }
            }
            
            if ($Severity) {
                $filteredAlerts = $filteredAlerts | Where-Object { $_.Severity -eq $Severity }
            }
            
            # Display alerts
            Show-AlertSummary -Alerts $filteredAlerts
            
            # Export if requested
            if ($Export) {
                $exportData = @{
                    Timestamp = Get-Date
                    TotalAlerts = $filteredAlerts.Count
                    ActiveAlerts = ($filteredAlerts | Where-Object { -not $_.Resolved }).Count
                    CriticalAlerts = ($filteredAlerts | Where-Object { $_.Severity -eq 'Critical' }).Count
                    Alerts = $filteredAlerts
                    MutedAlerts = $script:MutedAlerts
                }
                
                $exportPath = Join-Path $env:TEMP "system-alerts-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                $exportData | ConvertTo-Json -Depth 5 | Set-Content -Path $exportPath -Encoding UTF8
                Write-CustomLog -Message "Alerts exported to: $exportPath" -Level "SUCCESS"
                Write-Host "📊 Alerts exported to: $exportPath" -ForegroundColor Green
            }
            
            return $filteredAlerts
            
        } catch {
            Write-CustomLog -Message "Failed to process system alerts: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Get-CurrentSystemAlerts {
    $alerts = @()
    $alertId = 1
    
    # Check if alerts are currently muted
    $currentlyMuted = $script:MutedAlerts | Where-Object { 
        $_.MutedUntil -gt (Get-Date) 
    } | Select-Object -First 1
    
    # Get current system metrics
    $dashboard = Get-SystemDashboard -Format JSON | ConvertFrom-Json
    
    # Generate alerts from current metrics
    foreach ($alert in $dashboard.Alerts) {
        $alertObj = @{
            Id = "ALT{0:D3}" -f $alertId++
            Type = $alert.Type
            Severity = $alert.Severity
            Message = $alert.Message
            Timestamp = [datetime]$alert.Timestamp
            Resolved = $false
            Acknowledged = $false
            Source = "SystemMonitoring"
            Details = @{}
            Muted = $null -ne $currentlyMuted
        }
        
        # Add type-specific details
        switch ($alert.Type) {
            'CPU' {
                $alertObj.Details.CurrentUsage = $dashboard.Metrics.CPU.Usage
                $alertObj.Details.Threshold = $script:AlertThresholds.CPU[$alert.Severity]
                $alertObj.Details.Cores = $dashboard.Metrics.CPU.Cores
            }
            'Memory' {
                $alertObj.Details.CurrentUsage = $dashboard.Metrics.Memory.UsagePercent
                $alertObj.Details.Threshold = $script:AlertThresholds.Memory[$alert.Severity]
                $alertObj.Details.TotalGB = $dashboard.Metrics.Memory.TotalGB
                $alertObj.Details.UsedGB = $dashboard.Metrics.Memory.UsedGB
            }
            'Disk' {
                $diskInfo = $dashboard.Metrics.Disk | Where-Object { $alert.Message -like "*$($_.Drive)*" } | Select-Object -First 1
                if ($diskInfo) {
                    $alertObj.Details.CurrentUsage = $diskInfo.UsagePercent
                    $alertObj.Details.Threshold = $script:AlertThresholds.Disk[$alert.Severity]
                    $alertObj.Details.Drive = $diskInfo.Drive
                    $alertObj.Details.TotalGB = $diskInfo.TotalGB
                    $alertObj.Details.FreeGB = $diskInfo.FreeGB
                }
            }
        }
        
        $alerts += $alertObj
    }
    
    # Add service alerts
    $stoppedServices = $dashboard.Services | Where-Object { $_.Status -ne 'Running' }
    foreach ($service in $stoppedServices) {
        $alerts += @{
            Id = "SVC{0:D3}" -f $alertId++
            Type = "Service"
            Severity = "High"
            Message = "Service '$($service.Name)' is not running"
            Timestamp = Get-Date
            Resolved = $false
            Acknowledged = $false
            Source = "ServiceMonitoring"
            Details = @{
                ServiceName = $service.Name
                DisplayName = $service.DisplayName
                CurrentStatus = $service.Status
                ExpectedStatus = "Running"
            }
            Muted = $null -ne $currentlyMuted
        }
    }
    
    # Store in alert history
    foreach ($alert in $alerts) {
        $existingAlert = $script:AlertHistory | Where-Object { 
            $_.Type -eq $alert.Type -and 
            $_.Message -eq $alert.Message -and
            -not $_.Resolved
        } | Select-Object -First 1
        
        if (-not $existingAlert) {
            $script:AlertHistory += $alert
        } else {
            # Update existing alert timestamp
            $existingAlert.Timestamp = $alert.Timestamp
        }
    }
    
    return $alerts
}

function Show-AlertSummary {
    param($Alerts)
    
    Write-Host "`n🚨 SYSTEM ALERTS SUMMARY" -ForegroundColor Red
    Write-Host "=" * 50 -ForegroundColor Red
    Write-Host "📊 Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
    if ($Alerts.Count -eq 0) {
        Write-Host "`n✅ No alerts to display" -ForegroundColor Green
        return
    }
    
    # Summary statistics
    $criticalCount = ($Alerts | Where-Object { $_.Severity -eq 'Critical' }).Count
    $highCount = ($Alerts | Where-Object { $_.Severity -eq 'High' }).Count
    $mediumCount = ($Alerts | Where-Object { $_.Severity -eq 'Medium' }).Count
    $lowCount = ($Alerts | Where-Object { $_.Severity -eq 'Low' }).Count
    $acknowledgedCount = ($Alerts | Where-Object { $_.Acknowledged }).Count
    $mutedCount = ($Alerts | Where-Object { $_.Muted }).Count
    
    Write-Host "`n📈 Alert Statistics:" -ForegroundColor Yellow
    Write-Host "   Total Alerts: $($Alerts.Count)" -ForegroundColor White
    if ($criticalCount -gt 0) { Write-Host "   Critical: $criticalCount" -ForegroundColor Red }
    if ($highCount -gt 0) { Write-Host "   High: $highCount" -ForegroundColor DarkRed }
    if ($mediumCount -gt 0) { Write-Host "   Medium: $mediumCount" -ForegroundColor Yellow }
    if ($lowCount -gt 0) { Write-Host "   Low: $lowCount" -ForegroundColor Gray }
    if ($acknowledgedCount -gt 0) { Write-Host "   Acknowledged: $acknowledgedCount" -ForegroundColor Green }
    if ($mutedCount -gt 0) { Write-Host "   Muted: $mutedCount" -ForegroundColor DarkGray }
    
    # Display individual alerts
    Write-Host "`n🔍 Alert Details:" -ForegroundColor Yellow
    
    foreach ($alert in $Alerts | Sort-Object Severity, Timestamp -Descending) {
        $severityColor = switch ($alert.Severity) {
            'Critical' { 'Red' }
            'High' { 'DarkRed' }
            'Medium' { 'Yellow' }
            'Low' { 'Gray' }
            default { 'White' }
        }
        
        $statusIcons = @()
        if ($alert.Acknowledged) { $statusIcons += "✅" }
        if ($alert.Muted) { $statusIcons += "🔇" }
        if ($alert.Resolved) { $statusIcons += "✔️" }
        
        $statusText = if ($statusIcons.Count -gt 0) { " " + ($statusIcons -join " ") } else { "" }
        
        Write-Host "`n   [$($alert.Id)] $($alert.Severity.ToUpper()) - $($alert.Type)" -ForegroundColor $severityColor
        Write-Host "   📄 $($alert.Message)$statusText" -ForegroundColor White
        Write-Host "   🕒 $($alert.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        
        if ($alert.Details.Count -gt 0) {
            Write-Host "   📋 Details:" -ForegroundColor Gray
            foreach ($detail in $alert.Details.GetEnumerator()) {
                Write-Host "      • $($detail.Key): $($detail.Value)" -ForegroundColor DarkGray
            }
        }
        
        if ($alert.Acknowledged) {
            Write-Host "   ✅ Acknowledged by $($alert.AcknowledgedBy) at $($alert.AcknowledgedAt.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
        }
    }
    
    # Check for muted alerts
    $activeMutes = $script:MutedAlerts | Where-Object { $_.MutedUntil -gt (Get-Date) }
    if ($activeMutes.Count -gt 0) {
        Write-Host "`n🔇 Alert Muting Active:" -ForegroundColor DarkGray
        foreach ($mute in $activeMutes) {
            $timeLeft = $mute.MutedUntil - (Get-Date)
            Write-Host "   Muted by $($mute.MutedBy) - $([math]::Round($timeLeft.TotalMinutes, 0)) minutes remaining" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`n" + "=" * 50 -ForegroundColor Red
    
    # Provide actionable suggestions
    if ($criticalCount -gt 0) {
        Write-Host "`n⚠️  IMMEDIATE ACTION REQUIRED:" -ForegroundColor Red
        Write-Host "   $criticalCount critical alert(s) need attention" -ForegroundColor Red
        Write-Host "   Consider scaling resources or investigating issues" -ForegroundColor Yellow
    }
    
    if ($highCount -gt 0) {
        Write-Host "`n📊 HIGH PRIORITY:" -ForegroundColor DarkRed
        Write-Host "   $highCount high-priority alert(s) should be addressed soon" -ForegroundColor DarkRed
    }
}

function Add-DurationToDate {
    param($Date, $Duration)
    
    if ($Duration -match '(\d+)([smhd])') {
        $value = [int]$matches[1]
        $unit = $matches[2]
        
        switch ($unit) {
            's' { return $Date.AddSeconds($value) }
            'm' { return $Date.AddMinutes($value) }
            'h' { return $Date.AddHours($value) }
            'd' { return $Date.AddDays($value) }
        }
    }
    
    throw "Invalid duration format. Use format like '30m', '2h', '1d'"
}