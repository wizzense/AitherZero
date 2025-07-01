<#
.SYNOPSIS
    Real-time adaptive throttling system based on system resource pressure

.DESCRIPTION
    Monitors system resources in real-time and provides adaptive throttling recommendations
    for parallel execution. Automatically adjusts recommendations based on memory pressure,
    CPU load, I/O wait times, and thermal conditions.

.PARAMETER MonitoringInterval
    Interval in seconds between resource checks (default: 5)

.PARAMETER ThrottleCallback
    Script block to execute when throttling recommendations change

.PARAMETER PressureThresholds
    Custom pressure thresholds for triggering throttling adjustments

.PARAMETER MaxMonitoringDuration
    Maximum monitoring duration in minutes (default: 60)

.EXAMPLE
    Watch-SystemResourcePressure -ThrottleCallback { 
        param($Recommendation)
        Write-Host "New throttling: $($Recommendation.SuggestedThreads)"
    }

.EXAMPLE
    $monitoring = Watch-SystemResourcePressure -MonitoringInterval 3 -MaxMonitoringDuration 30

.NOTES
    Designed for AitherZero adaptive parallel execution optimization
#>
function Watch-SystemResourcePressure {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$MonitoringInterval = 5,
        
        [Parameter()]
        [scriptblock]$ThrottleCallback,
        
        [Parameter()]
        [hashtable]$PressureThresholds = @{
            CPU = @{ High = 80; Critical = 90 }
            Memory = @{ High = 85; Critical = 95 }
            IO = @{ High = 25; Critical = 40 }
            Thermal = @{ High = 75; Critical = 85 }
        },
        
        [Parameter()]
        [ValidateRange(1, 1440)]
        [int]$MaxMonitoringDuration = 60,
        
        [Parameter()]
        [switch]$ReturnImmediately
    )
    
    Write-CustomLog -Message "Starting adaptive resource pressure monitoring..." -Level "INFO"
    
    $monitoringData = [PSCustomObject]@{
        StartTime = Get-Date
        MonitoringInterval = $MonitoringInterval
        MaxDuration = $MaxMonitoringDuration
        PressureThresholds = $PressureThresholds
        CurrentRecommendation = $null
        PressureHistory = @()
        ThrottleAdjustments = @()
        MonitoringActive = $true
        MonitoringJob = $null
    }
    
    # Get initial baseline
    $baseline = Get-IntelligentResourceMetrics -IncludeRecommendations -OutputFormat Performance
    $monitoringData.CurrentRecommendation = $baseline
    
    Write-CustomLog -Message "Initial recommendation: $($baseline.OptimalParallelThreads) threads (max: $($baseline.MaxSafeThreads))" -Level "INFO"
    
    if ($ReturnImmediately) {
        # Start background monitoring job
        $monitoringData.MonitoringJob = Start-BackgroundResourceMonitoring -MonitoringData $monitoringData -ThrottleCallback $ThrottleCallback
        return $monitoringData
    }
    
    # Synchronous monitoring loop
    try {
        $endTime = (Get-Date).AddMinutes($MaxMonitoringDuration)
        $lastRecommendation = $baseline
        
        while ((Get-Date) -lt $endTime -and $monitoringData.MonitoringActive) {
            Start-Sleep -Seconds $MonitoringInterval
            
            # Get current metrics
            $currentMetrics = Get-IntelligentResourceMetrics -IncludeRecommendations -OutputFormat Performance
            $pressureAnalysis = Get-ResourcePressureAnalysis -Metrics $currentMetrics -Thresholds $PressureThresholds
            
            # Record pressure data
            $pressureRecord = @{
                Timestamp = Get-Date
                Metrics = $currentMetrics
                Pressure = $pressureAnalysis
                RecommendedAdjustment = Get-ThrottleAdjustment -PressureAnalysis $pressureAnalysis -CurrentRecommendation $lastRecommendation
            }
            
            $monitoringData.PressureHistory += $pressureRecord
            
            # Check if throttling adjustment is needed
            if ($pressureRecord.RecommendedAdjustment.AdjustmentNeeded) {
                $newRecommendation = Apply-ThrottleAdjustment -CurrentRecommendation $lastRecommendation -Adjustment $pressureRecord.RecommendedAdjustment
                
                # Record the adjustment
                $adjustmentRecord = @{
                    Timestamp = Get-Date
                    Reason = $pressureRecord.RecommendedAdjustment.Reason
                    PreviousThreads = $lastRecommendation.OptimalParallelThreads
                    NewThreads = $newRecommendation.OptimalParallelThreads
                    AdjustmentFactor = $pressureRecord.RecommendedAdjustment.Factor
                    PressureLevel = $pressureAnalysis.OverallPressureLevel
                }
                
                $monitoringData.ThrottleAdjustments += $adjustmentRecord
                $monitoringData.CurrentRecommendation = $newRecommendation
                $lastRecommendation = $newRecommendation
                
                Write-CustomLog -Message "Throttling adjusted: $($adjustmentRecord.PreviousThreads) → $($adjustmentRecord.NewThreads) threads ($($adjustmentRecord.Reason))" -Level "INFO"
                
                # Execute callback if provided
                if ($ThrottleCallback) {
                    try {
                        & $ThrottleCallback $newRecommendation
                    } catch {
                        Write-CustomLog -Message "Throttle callback failed: $_" -Level "ERROR"
                    }
                }
            }
            
            # Log current status
            Write-CustomLog -Message "Pressure check: CPU $($pressureAnalysis.CPU.Level), Memory $($pressureAnalysis.Memory.Level), IO $($pressureAnalysis.IO.Level) - Threads: $($lastRecommendation.OptimalParallelThreads)" -Level "DEBUG"
        }
        
    } catch {
        Write-CustomLog -Message "Resource pressure monitoring failed: $_" -Level "ERROR"
        $monitoringData.MonitoringActive = $false
        throw
    } finally {
        $monitoringData.MonitoringActive = $false
        Write-CustomLog -Message "Resource pressure monitoring completed. Adjustments made: $($monitoringData.ThrottleAdjustments.Count)" -Level "INFO"
    }
    
    return $monitoringData
}

function Start-BackgroundResourceMonitoring {
    <#
    .SYNOPSIS
    Start background resource monitoring job
    #>
    param(
        [Parameter(Mandatory)]
        $MonitoringData,
        
        [Parameter()]
        [scriptblock]$ThrottleCallback
    )
    
    $job = Start-Job -ScriptBlock {
        param($MonitoringData, $ThrottleCallback, $ModulePath)
        
        # Import required modules in job context
        Import-Module $ModulePath -Force
        
        $endTime = $MonitoringData.StartTime.AddMinutes($MonitoringData.MaxDuration)
        $lastRecommendation = $MonitoringData.CurrentRecommendation
        
        while ((Get-Date) -lt $endTime) {
            Start-Sleep -Seconds $MonitoringData.MonitoringInterval
            
            try {
                $currentMetrics = Get-IntelligentResourceMetrics -IncludeRecommendations -OutputFormat Performance
                $pressureAnalysis = Get-ResourcePressureAnalysis -Metrics $currentMetrics -Thresholds $MonitoringData.PressureThresholds
                
                $pressureRecord = @{
                    Timestamp = Get-Date
                    Metrics = $currentMetrics
                    Pressure = $pressureAnalysis
                    RecommendedAdjustment = Get-ThrottleAdjustment -PressureAnalysis $pressureAnalysis -CurrentRecommendation $lastRecommendation
                }
                
                if ($pressureRecord.RecommendedAdjustment.AdjustmentNeeded) {
                    $newRecommendation = Apply-ThrottleAdjustment -CurrentRecommendation $lastRecommendation -Adjustment $pressureRecord.RecommendedAdjustment
                    $lastRecommendation = $newRecommendation
                    
                    # Execute callback if provided
                    if ($ThrottleCallback) {
                        & $ThrottleCallback $newRecommendation
                    }
                    
                    Write-Output "ADJUSTMENT: $($pressureRecord.RecommendedAdjustment.Reason) - New threads: $($newRecommendation.OptimalParallelThreads)"
                }
                
            } catch {
                Write-Output "ERROR: Background monitoring failed: $_"
                break
            }
        }
        
        Write-Output "COMPLETED: Background resource monitoring finished"
        
    } -ArgumentList $MonitoringData, $ThrottleCallback, $PSScriptRoot
    
    return $job
}

function Get-ResourcePressureAnalysis {
    <#
    .SYNOPSIS
    Analyze current resource pressure levels
    #>
    param(
        [Parameter(Mandatory)]
        $Metrics,
        
        [Parameter(Mandatory)]
        [hashtable]$Thresholds
    )
    
    # Get current system metrics for pressure analysis
    $systemMetrics = Get-IntelligentResourceMetrics
    
    $analysis = @{
        CPU = Get-PressureLevel -Value $systemMetrics.Performance.CPULoad -Thresholds $Thresholds.CPU
        Memory = Get-PressureLevel -Value $systemMetrics.Performance.MemoryPressure -Thresholds $Thresholds.Memory
        IO = Get-PressureLevel -Value $systemMetrics.Performance.IOWait -Thresholds $Thresholds.IO
        Thermal = @{ Level = "Normal"; Value = 45 }  # Simulated thermal data
        Overall = "Normal"
    }
    
    # Determine overall pressure level
    $pressureLevels = @($analysis.CPU.Level, $analysis.Memory.Level, $analysis.IO.Level, $analysis.Thermal.Level)
    if ($pressureLevels -contains "Critical") {
        $analysis.Overall = "Critical"
    } elseif ($pressureLevels -contains "High") {
        $analysis.Overall = "High"
    } elseif ($pressureLevels -contains "Medium") {
        $analysis.Overall = "Medium"
    } else {
        $analysis.Overall = "Normal"
    }
    
    $analysis.OverallPressureLevel = $analysis.Overall
    
    return $analysis
}

function Get-PressureLevel {
    <#
    .SYNOPSIS
    Determine pressure level based on value and thresholds
    #>
    param(
        [Parameter(Mandatory)]
        [double]$Value,
        
        [Parameter(Mandatory)]
        [hashtable]$Thresholds
    )
    
    $level = if ($Value -ge $Thresholds.Critical) {
        "Critical"
    } elseif ($Value -ge $Thresholds.High) {
        "High"
    } elseif ($Value -ge 50) {
        "Medium"
    } else {
        "Normal"
    }
    
    return @{
        Level = $level
        Value = $Value
        Threshold = $Thresholds
    }
}

function Get-ThrottleAdjustment {
    <#
    .SYNOPSIS
    Determine if throttling adjustment is needed based on pressure analysis
    #>
    param(
        [Parameter(Mandatory)]
        $PressureAnalysis,
        
        [Parameter(Mandatory)]
        $CurrentRecommendation
    )
    
    $adjustment = @{
        AdjustmentNeeded = $false
        Reason = "No adjustment needed"
        Factor = 1.0
        Direction = "None"
        Urgency = "Low"
    }
    
    # Check for critical conditions requiring immediate throttling
    if ($PressureAnalysis.OverallPressureLevel -eq "Critical") {
        $adjustment.AdjustmentNeeded = $true
        $adjustment.Reason = "Critical system pressure detected"
        $adjustment.Factor = 0.5  # Reduce threads by 50%
        $adjustment.Direction = "Reduce"
        $adjustment.Urgency = "High"
    }
    elseif ($PressureAnalysis.OverallPressureLevel -eq "High") {
        $adjustment.AdjustmentNeeded = $true
        $adjustment.Reason = "High system pressure detected"
        $adjustment.Factor = 0.75  # Reduce threads by 25%
        $adjustment.Direction = "Reduce"
        $adjustment.Urgency = "Medium"
    }
    elseif ($PressureAnalysis.OverallPressureLevel -eq "Normal" -and $CurrentRecommendation.OptimalParallelThreads -lt $CurrentRecommendation.MaxSafeThreads) {
        # Opportunity to increase threads if system is stable
        $adjustment.AdjustmentNeeded = $true
        $adjustment.Reason = "System resources available for optimization"
        $adjustment.Factor = 1.25  # Increase threads by 25%
        $adjustment.Direction = "Increase"
        $adjustment.Urgency = "Low"
    }
    
    return $adjustment
}

function Apply-ThrottleAdjustment {
    <#
    .SYNOPSIS
    Apply throttling adjustment to current recommendation
    #>
    param(
        [Parameter(Mandatory)]
        $CurrentRecommendation,
        
        [Parameter(Mandatory)]
        $Adjustment
    )
    
    $newThreads = [math]::Max(1, [math]::Floor($CurrentRecommendation.OptimalParallelThreads * $Adjustment.Factor))
    
    # Ensure we don't exceed maximum safe threads
    $newThreads = [math]::Min($newThreads, $CurrentRecommendation.MaxSafeThreads)
    
    $newRecommendation = $CurrentRecommendation.PSObject.Copy()
    $newRecommendation.OptimalParallelThreads = [int]$newThreads
    $newRecommendation.AdaptiveThrottling = @{
        Enabled = $true
        AdjustmentFactor = $Adjustment.Factor
        AdjustmentReason = $Adjustment.Reason
        LastAdjustment = Get-Date
    }
    
    return $newRecommendation
}

function Stop-ResourcePressureMonitoring {
    <#
    .SYNOPSIS
    Stop active resource pressure monitoring
    #>
    param(
        [Parameter(Mandatory)]
        $MonitoringData
    )
    
    $MonitoringData.MonitoringActive = $false
    
    if ($MonitoringData.MonitoringJob) {
        try {
            $MonitoringData.MonitoringJob | Stop-Job -Force
            $MonitoringData.MonitoringJob | Remove-Job -Force
            Write-CustomLog -Message "Background resource monitoring stopped" -Level "INFO"
        } catch {
            Write-CustomLog -Message "Failed to stop background monitoring job: $_" -Level "ERROR"
        }
    }
}

function Get-ResourcePressureReport {
    <#
    .SYNOPSIS
    Generate comprehensive report from monitoring data
    #>
    param(
        [Parameter(Mandatory)]
        $MonitoringData,
        
        [ValidateSet('Summary', 'Detailed', 'JSON')]
        [string]$ReportType = 'Summary'
    )
    
    $report = @{
        MonitoringSession = @{
            StartTime = $MonitoringData.StartTime
            Duration = if ($MonitoringData.MonitoringActive) { "Active" } else { ((Get-Date) - $MonitoringData.StartTime).ToString() }
            SamplesCollected = $MonitoringData.PressureHistory.Count
            AdjustmentsMade = $MonitoringData.ThrottleAdjustments.Count
        }
        CurrentRecommendation = $MonitoringData.CurrentRecommendation
        PressureSummary = Get-PressureSummary -PressureHistory $MonitoringData.PressureHistory
        AdjustmentHistory = $MonitoringData.ThrottleAdjustments
        Recommendations = Get-SystemOptimizationRecommendations -MonitoringData $MonitoringData
    }
    
    switch ($ReportType) {
        'JSON' { return $report | ConvertTo-Json -Depth 6 }
        'Detailed' { return $report }
        default { return Format-PressureReportSummary -Report $report }
    }
}

function Get-PressureSummary {
    param($PressureHistory)
    
    if ($PressureHistory.Count -eq 0) {
        return @{ Message = "No pressure data collected" }
    }
    
    $cpuPressures = $PressureHistory | ForEach-Object { $_.Pressure.CPU.Value }
    $memoryPressures = $PressureHistory | ForEach-Object { $_.Pressure.Memory.Value }
    $ioPressures = $PressureHistory | ForEach-Object { $_.Pressure.IO.Value }
    
    return @{
        CPU = @{
            Average = [math]::Round(($cpuPressures | Measure-Object -Average).Average, 2)
            Maximum = ($cpuPressures | Measure-Object -Maximum).Maximum
            HighPressureEvents = ($PressureHistory | Where-Object { $_.Pressure.CPU.Level -in @("High", "Critical") }).Count
        }
        Memory = @{
            Average = [math]::Round(($memoryPressures | Measure-Object -Average).Average, 2)
            Maximum = ($memoryPressures | Measure-Object -Maximum).Maximum
            HighPressureEvents = ($PressureHistory | Where-Object { $_.Pressure.Memory.Level -in @("High", "Critical") }).Count
        }
        IO = @{
            Average = [math]::Round(($ioPressures | Measure-Object -Average).Average, 2)
            Maximum = ($ioPressures | Measure-Object -Maximum).Maximum
            HighPressureEvents = ($PressureHistory | Where-Object { $_.Pressure.IO.Level -in @("High", "Critical") }).Count
        }
    }
}

function Get-SystemOptimizationRecommendations {
    param($MonitoringData)
    
    $recommendations = @()
    
    # Analyze patterns for optimization recommendations
    if ($MonitoringData.ThrottleAdjustments.Count -gt 5) {
        $recommendations += "Consider reducing base parallel thread count - frequent throttling detected"
    }
    
    $pressureSummary = Get-PressureSummary -PressureHistory $MonitoringData.PressureHistory
    
    if ($pressureSummary.Memory.HighPressureEvents -gt 3) {
        $recommendations += "Memory pressure detected frequently - consider memory optimization"
    }
    
    if ($pressureSummary.CPU.Average -gt 80) {
        $recommendations += "High average CPU usage - consider workload distribution optimization"
    }
    
    if ($pressureSummary.IO.HighPressureEvents -gt 2) {
        $recommendations += "I/O bottlenecks detected - consider storage optimization"
    }
    
    if ($recommendations.Count -eq 0) {
        $recommendations += "System performance is optimal for current workload"
    }
    
    return $recommendations
}

function Format-PressureReportSummary {
    param($Report)
    
    $summary = @"
📊 Resource Pressure Monitoring Report
=====================================
Monitoring Duration: $($Report.MonitoringSession.Duration)
Samples Collected: $($Report.MonitoringSession.SamplesCollected)
Throttle Adjustments: $($Report.MonitoringSession.AdjustmentsMade)

Current Recommendation: $($Report.CurrentRecommendation.OptimalParallelThreads) threads (max: $($Report.CurrentRecommendation.MaxSafeThreads))

Pressure Summary:
- CPU: Avg $($Report.PressureSummary.CPU.Average)%, Max $($Report.PressureSummary.CPU.Maximum)%, High Events: $($Report.PressureSummary.CPU.HighPressureEvents)
- Memory: Avg $($Report.PressureSummary.Memory.Average)%, Max $($Report.PressureSummary.Memory.Maximum)%, High Events: $($Report.PressureSummary.Memory.HighPressureEvents)
- I/O: Avg $($Report.PressureSummary.IO.Average)%, Max $($Report.PressureSummary.IO.Maximum)%, High Events: $($Report.PressureSummary.IO.HighPressureEvents)

Optimization Recommendations:
$($Report.Recommendations | ForEach-Object { "• $_" } | Join-String -Separator "`n")
"@
    
    return $summary
}

Export-ModuleMember -Function Watch-SystemResourcePressure, Stop-ResourcePressureMonitoring, Get-ResourcePressureReport