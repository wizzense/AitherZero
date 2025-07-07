<#
.SYNOPSIS
    Starts continuous system monitoring with real-time alerts and performance tracking.

.DESCRIPTION
    Start-SystemMonitoring initiates a background monitoring session that continuously
    tracks system and application performance metrics, compares them against baselines
    and SLAs, and generates alerts when thresholds are exceeded.

.PARAMETER MonitoringProfile
    The monitoring profile to use. Valid values: 'Basic', 'Standard', 'Comprehensive', 'Custom'

.PARAMETER Duration
    Duration to run monitoring in minutes. Use 0 for continuous monitoring.

.PARAMETER AlertThreshold
    Alert sensitivity level. Valid values: 'Low', 'Medium', 'High'

.PARAMETER LogPerformance
    Log performance metrics to file for historical analysis.

.PARAMETER EnableWebhooks
    Enable webhook notifications for critical alerts.

.PARAMETER WebhookUrl
    URL for webhook notifications (required if EnableWebhooks is true).

.EXAMPLE
    Start-SystemMonitoring -MonitoringProfile Standard -Duration 60
    Starts standard monitoring for 60 minutes.

.EXAMPLE
    Start-SystemMonitoring -MonitoringProfile Comprehensive -Duration 0 -LogPerformance
    Starts continuous comprehensive monitoring with performance logging.
#>
function Start-SystemMonitoring {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Basic', 'Standard', 'Comprehensive', 'Custom')]
        [string]$MonitoringProfile = 'Standard',

        [Parameter()]
        [ValidateRange(0, 1440)]
        [int]$Duration = 60,

        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High')]
        [string]$AlertThreshold = 'Medium',

        [Parameter()]
        [switch]$LogPerformance,

        [Parameter()]
        [switch]$EnableWebhooks,

        [Parameter()]
        [string]$WebhookUrl
    )

    begin {
        # Validate webhook URL if webhooks are enabled
        if ($EnableWebhooks -and -not $WebhookUrl) {
            throw "WebhookUrl is required when EnableWebhooks is specified"
        }
        
        Write-CustomLog -Message "Starting system monitoring with profile: $MonitoringProfile" -Level "INFO"
        
        # Check if monitoring is already running
        if ($script:MonitoringJob -and $script:MonitoringJob.State -eq 'Running') {
            Write-CustomLog -Message "Monitoring is already running. Stop it first with Stop-SystemMonitoring" -Level "WARNING"
            return
        }
        
        # Load baselines if available
        Load-PerformanceBaselines
        
        # Configure monitoring settings
        $monitoringConfig = Get-MonitoringProfileConfig -Profile $MonitoringProfile
        $monitoringConfig.AlertThreshold = $AlertThreshold
        $monitoringConfig.LogPerformance = $LogPerformance
        $monitoringConfig.EnableWebhooks = $EnableWebhooks
        $monitoringConfig.WebhookUrl = $WebhookUrl
        $monitoringConfig.Duration = $Duration
    }

    process {
        try {
            # Create monitoring job
            $script:MonitoringJob = Start-Job -Name "AitherZero-SystemMonitoring" -ScriptBlock {
                param($Config, $ModulePath, $ProjectRoot)
                
                # Import required modules in job
                Import-Module (Join-Path $ModulePath "SystemMonitoring") -Force
                Import-Module (Join-Path $ProjectRoot "aither-core/modules/Logging") -Force
                
                # Initialize monitoring
                $startTime = Get-Date
                $endTime = if ($Config.Duration -eq 0) { [DateTime]::MaxValue } else { $startTime.AddMinutes($Config.Duration) }
                $alertHistory = @()
                $performanceLog = @()
                
                Write-CustomLog -Message "Monitoring session started - Duration: $(if ($Config.Duration -eq 0) { 'Continuous' } else { "$($Config.Duration) minutes" })" -Level "INFO"
                
                # Main monitoring loop
                while ((Get-Date) -lt $endTime) {
                    try {
                        # Collect metrics based on profile
                        $metrics = Get-SystemPerformance -MetricType $Config.MetricTypes -Duration $Config.SampleDuration
                        
                        # Check against thresholds and baselines
                        $alerts = Test-PerformanceThresholds -Metrics $metrics -Config $Config
                        
                        # Process alerts
                        if ($alerts.Count -gt 0) {
                            foreach ($alert in $alerts) {
                                # Log alert
                                Write-CustomLog -Message "ALERT: $($alert.Message)" -Level $alert.Level
                                
                                # Add to history
                                $alertHistory += $alert
                                
                                # Send webhook if enabled and critical
                                if ($Config.EnableWebhooks -and $alert.Level -eq 'CRITICAL') {
                                    Send-WebhookAlert -Alert $alert -Url $Config.WebhookUrl
                                }
                            }
                        }
                        
                        # Log performance data if enabled
                        if ($Config.LogPerformance) {
                            $performanceLog += @{
                                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                                Metrics = $metrics
                                Alerts = $alerts
                            }
                            
                            # Write to file every 10 samples
                            if ($performanceLog.Count % 10 -eq 0) {
                                Export-PerformanceLog -Data $performanceLog
                                $performanceLog = @()  # Clear buffer
                            }
                        }
                        
                        # Update monitoring data for dashboard
                        $script:MonitoringData = @{
                            Status = "Active"
                            StartTime = $startTime
                            LastUpdate = Get-Date
                            CurrentMetrics = $metrics
                            AlertCount = $alertHistory.Count
                            RecentAlerts = $alertHistory | Select-Object -Last 10
                        }
                        
                        # Wait for next sample
                        Start-Sleep -Seconds $Config.SampleInterval
                        
                    } catch {
                        Write-CustomLog -Message "Error in monitoring loop: $($_.Exception.Message)" -Level "ERROR"
                    }
                }
                
                # Final log write
                if ($Config.LogPerformance -and $performanceLog.Count -gt 0) {
                    Export-PerformanceLog -Data $performanceLog
                }
                
                Write-CustomLog -Message "Monitoring session completed - Total alerts: $($alertHistory.Count)" -Level "INFO"
                
                # Return summary
                return @{
                    StartTime = $startTime
                    EndTime = Get-Date
                    TotalAlerts = $alertHistory.Count
                    AlertsByLevel = $alertHistory | Group-Object Level | Select-Object Name, Count
                    FinalMetrics = $metrics
                }
                
            } -ArgumentList $monitoringConfig, $script:ModuleRoot, $script:ProjectRoot
            
            # Store job reference
            $script:MonitoringStartTime = Get-Date
            $script:MonitoringConfig = $monitoringConfig
            
            # Return monitoring handle
            return @{
                JobId = $script:MonitoringJob.Id
                StartTime = $script:MonitoringStartTime
                Profile = $MonitoringProfile
                Duration = if ($Duration -eq 0) { "Continuous" } else { "$Duration minutes" }
                Status = "Running"
            }

        } catch {
            Write-CustomLog -Message "Failed to start monitoring: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function to get monitoring profile configuration
function Get-MonitoringProfileConfig {
    param([string]$Profile)
    
    $profiles = @{
        Basic = @{
            MetricTypes = 'System'
            SampleInterval = 30
            SampleDuration = 2
            Thresholds = @{
                CPU = @{ Warning = 80; Critical = 90 }
                Memory = @{ Warning = 85; Critical = 95 }
            }
        }
        Standard = @{
            MetricTypes = 'All'
            SampleInterval = 15
            SampleDuration = 5
            Thresholds = @{
                CPU = @{ Warning = 75; Critical = 85 }
                Memory = @{ Warning = 80; Critical = 90 }
                ModuleLoad = @{ Warning = 1.5; Critical = 2.0 }
                PatchWorkflow = @{ Warning = 8; Critical = 10 }
            }
        }
        Comprehensive = @{
            MetricTypes = 'All'
            SampleInterval = 10
            SampleDuration = 5
            Thresholds = @{
                CPU = @{ Warning = 70; Critical = 80 }
                Memory = @{ Warning = 75; Critical = 85 }
                Disk = @{ Warning = 85; Critical = 95 }
                Network = @{ Warning = 80; Critical = 90 }
                ModuleLoad = @{ Warning = 1.2; Critical = 2.0 }
                PatchWorkflow = @{ Warning = 7; Critical = 10 }
                InfrastructureDeploy = @{ Warning = 100; Critical = 120 }
                TestExecution = @{ Warning = 240; Critical = 300 }
            }
        }
        Custom = @{
            MetricTypes = 'All'
            SampleInterval = 20
            SampleDuration = 5
            Thresholds = @{}  # Will be populated from baselines
        }
    }
    
    $config = $profiles[$Profile]
    
    # For custom profile, load thresholds from baselines
    if ($Profile -eq 'Custom' -and $script:PerformanceBaselines) {
        foreach ($baseline in $script:PerformanceBaselines.Values) {
            if ($baseline.Thresholds) {
                foreach ($metric in $baseline.Thresholds.Keys) {
                    $config.Thresholds[$metric] = $baseline.Thresholds[$metric]
                }
            }
        }
    }
    
    return $config
}

# Helper function to test performance against thresholds
function Test-PerformanceThresholds {
    param($Metrics, $Config)
    
    $alerts = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Check system metrics
    if ($Metrics.System) {
        # CPU check
        if ($Metrics.System.CPU -and $Config.Thresholds.CPU) {
            $cpuUsage = $Metrics.System.CPU.Average
            if ($cpuUsage -ge $Config.Thresholds.CPU.Critical) {
                $alerts += @{
                    Level = "CRITICAL"
                    Category = "CPU"
                    Message = "CPU usage critical: $cpuUsage% (threshold: $($Config.Thresholds.CPU.Critical)%)"
                    Value = $cpuUsage
                    Threshold = $Config.Thresholds.CPU.Critical
                    Timestamp = $timestamp
                }
            } elseif ($cpuUsage -ge $Config.Thresholds.CPU.Warning) {
                $alerts += @{
                    Level = "WARNING"
                    Category = "CPU"
                    Message = "CPU usage high: $cpuUsage% (threshold: $($Config.Thresholds.CPU.Warning)%)"
                    Value = $cpuUsage
                    Threshold = $Config.Thresholds.CPU.Warning
                    Timestamp = $timestamp
                }
            }
        }
        
        # Memory check
        if ($Metrics.System.Memory -and $Config.Thresholds.Memory) {
            $memUsage = $Metrics.System.Memory.Average
            if ($memUsage -ge $Config.Thresholds.Memory.Critical) {
                $alerts += @{
                    Level = "CRITICAL"
                    Category = "Memory"
                    Message = "Memory usage critical: $memUsage% (threshold: $($Config.Thresholds.Memory.Critical)%)"
                    Value = $memUsage
                    Threshold = $Config.Thresholds.Memory.Critical
                    Timestamp = $timestamp
                }
            } elseif ($memUsage -ge $Config.Thresholds.Memory.Warning) {
                $alerts += @{
                    Level = "WARNING"
                    Category = "Memory"
                    Message = "Memory usage high: $memUsage% (threshold: $($Config.Thresholds.Memory.Warning)%)"
                    Value = $memUsage
                    Threshold = $Config.Thresholds.Memory.Warning
                    Timestamp = $timestamp
                }
            }
        }
    }
    
    # Check SLA compliance
    if ($Metrics.SLACompliance -and $Metrics.SLACompliance.Overall -eq "Fail") {
        foreach ($slaItem in $Metrics.SLACompliance.Details.Keys) {
            if ($Metrics.SLACompliance.Details[$slaItem].Status -eq "Fail") {
                $alerts += @{
                    Level = "CRITICAL"
                    Category = "SLA"
                    Message = "SLA violation: $slaItem - $($Metrics.SLACompliance.Details[$slaItem].Actual) (target: $($Metrics.SLACompliance.Details[$slaItem].Target))"
                    Value = $Metrics.SLACompliance.Details[$slaItem].Actual
                    Threshold = $Metrics.SLACompliance.Details[$slaItem].Target
                    Timestamp = $timestamp
                }
            }
        }
    }
    
    # Filter alerts based on threshold setting
    $alertLevels = switch ($Config.AlertThreshold) {
        'Low' { @('INFO', 'WARNING', 'CRITICAL') }
        'Medium' { @('WARNING', 'CRITICAL') }
        'High' { @('CRITICAL') }
    }
    
    return $alerts | Where-Object { $_.Level -in $alertLevels }
}

# Helper function to send webhook alerts
function Send-WebhookAlert {
    param($Alert, $Url)
    
    try {
        $payload = @{
            text = "AitherZero Performance Alert"
            attachments = @(
                @{
                    color = if ($Alert.Level -eq 'CRITICAL') { 'danger' } else { 'warning' }
                    title = "$($Alert.Level): $($Alert.Category)"
                    text = $Alert.Message
                    fields = @(
                        @{
                            title = "Value"
                            value = $Alert.Value
                            short = $true
                        }
                        @{
                            title = "Threshold"
                            value = $Alert.Threshold
                            short = $true
                        }
                    )
                    footer = "AitherZero Monitoring"
                    ts = [DateTimeOffset]::Now.ToUnixTimeSeconds()
                }
            )
        }
        
        $response = Invoke-RestMethod -Uri $Url -Method Post -Body ($payload | ConvertTo-Json -Depth 5) -ContentType 'application/json'
        Write-CustomLog -Message "Webhook alert sent successfully" -Level "DEBUG"
    } catch {
        Write-CustomLog -Message "Failed to send webhook alert: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Helper function to export performance log
function Export-PerformanceLog {
    param($Data)
    
    try {
        $logPath = Join-Path $script:ProjectRoot "logs/performance"
        if (-not (Test-Path $logPath)) {
            New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        }
        
        $logFile = Join-Path $logPath "performance-$(Get-Date -Format 'yyyyMMdd').json"
        
        # Append to existing file or create new
        if (Test-Path $logFile) {
            $existing = Get-Content $logFile | ConvertFrom-Json
            $combined = @($existing) + $Data
            $combined | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding UTF8
        } else {
            $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding UTF8
        }
        
        Write-CustomLog -Message "Performance data logged to: $logFile" -Level "DEBUG"
    } catch {
        Write-CustomLog -Message "Error exporting performance log: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Helper function to load performance baselines
function Load-PerformanceBaselines {
    try {
        $baselinePath = Join-Path $script:ProjectRoot "configs/performance"
        if (Test-Path $baselinePath) {
            $baselineFiles = Get-ChildItem -Path $baselinePath -Filter "current-baseline-*.json"
            
            $script:PerformanceBaselines = @{}
            foreach ($file in $baselineFiles) {
                $baseline = Get-Content $file.FullName | ConvertFrom-Json
                $script:PerformanceBaselines[$baseline.Type] = $baseline
                Write-CustomLog -Message "Loaded $($baseline.Type) performance baseline" -Level "DEBUG"
            }
        }
    } catch {
        Write-CustomLog -Message "Error loading baselines: $($_.Exception.Message)" -Level "WARNING"
    }
}

# Export public function
Export-ModuleMember -Function Start-SystemMonitoring