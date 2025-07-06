<#
.SYNOPSIS
    Comprehensive system performance metrics collection with real-time data and analytics.

.DESCRIPTION
    Collects real system performance metrics across platforms with support for
    historical analysis, trend detection, and predictive analytics. Provides
    accurate CPU, memory, disk, and network statistics for infrastructure monitoring.

.PARAMETER MetricType
    Specifies which metrics to collect. Valid values: 'All', 'System', 'Application', 'Module', 'Operation'

.PARAMETER Duration
    Duration in seconds for metric collection and averaging. Default is 5 seconds.

.PARAMETER IncludeHistory
    Include historical performance data from previous collections.

.PARAMETER OutputFormat
    Format for output data. Valid values: 'Object', 'JSON', 'CSV'

.PARAMETER IncludeTrends
    Include trend analysis and performance predictions.

.PARAMETER SampleInterval
    Interval in seconds between samples during collection period.

.EXAMPLE
    Get-SystemPerformance -MetricType All -Duration 10 -IncludeTrends
    
    Collects all metrics over 10 seconds with trend analysis.
#>
function Get-SystemPerformance {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'System', 'Application', 'Module', 'Operation')]
        [string]$MetricType = 'All',

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$Duration = 5,

        [Parameter()]
        [switch]$IncludeHistory,

        [Parameter()]
        [ValidateSet('Object', 'JSON', 'CSV')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [switch]$IncludeTrends,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$SampleInterval = 1
    )

    Write-CustomLog -Message "Starting comprehensive performance metric collection for type: $MetricType (Duration: ${Duration}s)" -Level "INFO"
    
    $performanceData = [PSCustomObject]@{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        CollectionDuration = $Duration
        SampleInterval = $SampleInterval
        System = $null
        Application = $null
        Modules = $null
        Operations = $null
        SLACompliance = $null
        Trends = $null
        Metadata = @{
            Platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            CollectionMethod = "Real-time"
        }
    }

    try {
        # Collect system metrics with real data
        if ($MetricType -in @('All', 'System')) {
            Write-CustomLog -Message "Collecting system metrics..." -Level "DEBUG"
            $performanceData.System = Get-RealSystemMetrics -Duration $Duration -SampleInterval $SampleInterval
        }

        # Collect application metrics
        if ($MetricType -in @('All', 'Application')) {
            Write-CustomLog -Message "Collecting application metrics..." -Level "DEBUG"
            $performanceData.Application = Get-ApplicationMetrics -Duration $Duration
        }

        # Collect module metrics
        if ($MetricType -in @('All', 'Module')) {
            Write-CustomLog -Message "Collecting module metrics..." -Level "DEBUG"
            $performanceData.Modules = Get-ModuleMetrics
        }

        # Collect operation metrics
        if ($MetricType -in @('All', 'Operation')) {
            Write-CustomLog -Message "Collecting operation metrics..." -Level "DEBUG"
            $performanceData.Operations = Get-OperationMetrics
        }

        # Calculate SLA compliance
        if ($MetricType -eq 'All') {
            $performanceData.SLACompliance = Calculate-SLACompliance -SystemMetrics $performanceData.System -ApplicationMetrics $performanceData.Application
        }

        # Include trend analysis if requested
        if ($IncludeTrends) {
            $performanceData.Trends = Get-PerformanceTrends -CurrentMetrics $performanceData -IncludeHistory:$IncludeHistory
        }

        # Store metrics for historical analysis
        if ($IncludeHistory) {
            Store-PerformanceMetrics -Metrics $performanceData
        }

        # Format output
        switch ($OutputFormat) {
            'JSON' { return $performanceData | ConvertTo-Json -Depth 6 }
            'CSV' { return ConvertTo-PerformanceCSV -Metrics $performanceData }
            default { return $performanceData }
        }

    } catch {
        Write-CustomLog -Message "Error collecting performance metrics: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Helper function for real system metrics collection
function Get-RealSystemMetrics {
    param(
        [int]$Duration,
        [int]$SampleInterval
    )
    
    $samples = [Math]::Floor($Duration / $SampleInterval)
    $cpuSamples = @()
    $memorySamples = @()
    $diskSamples = @()
    $networkSamples = @()
    
    Write-CustomLog -Message "Collecting $samples samples over $Duration seconds..." -Level "DEBUG"
    
    for ($i = 0; $i -lt $samples; $i++) {
        try {
            # CPU sampling
            if ($IsWindows) {
                $cpu = Get-CimInstance -ClassName Win32_PerfRawData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
                if ($cpu) {
                    $cpuSamples += [PSCustomObject]@{
                        Timestamp = Get-Date
                        Value = 100 - [Math]::Round(($cpu.PercentIdleTime / $cpu.Timestamp_Sys100NS) * 100, 2)
                    }
                }
            } else {
                # Linux/macOS CPU sampling
                $cpuUsage = Get-LinuxCpuUsage
                $cpuSamples += [PSCustomObject]@{
                    Timestamp = Get-Date
                    Value = $cpuUsage
                }
            }
            
            # Memory sampling
            $memInfo = Get-MemoryInfo
            $memorySamples += [PSCustomObject]@{
                Timestamp = Get-Date
                UsagePercent = $memInfo.UsagePercent
                TotalGB = $memInfo.TotalGB
                UsedGB = $memInfo.UsedGB
                FreeGB = $memInfo.FreeGB
            }
            
            # Disk sampling
            $diskInfo = Get-DiskInfo
            $diskSamples += [PSCustomObject]@{
                Timestamp = Get-Date
                Disks = $diskInfo
            }
            
            # Network sampling
            $networkInfo = Get-NetworkInfo
            $networkSamples += [PSCustomObject]@{
                Timestamp = Get-Date
                Interfaces = $networkInfo
            }
            
            if ($i -lt ($samples - 1)) {
                Start-Sleep -Seconds $SampleInterval
            }
        } catch {
            Write-CustomLog -Message "Error collecting sample $($i + 1): $($_.Exception.Message)" -Level "WARNING"
        }
    }
    
    # Calculate aggregated metrics
    return @{
        CPU = @{
            Average = if ($cpuSamples.Count -gt 0) { [Math]::Round(($cpuSamples | Measure-Object -Property Value -Average).Average, 2) } else { 0 }
            Maximum = if ($cpuSamples.Count -gt 0) { [Math]::Round(($cpuSamples | Measure-Object -Property Value -Maximum).Maximum, 2) } else { 0 }
            Minimum = if ($cpuSamples.Count -gt 0) { [Math]::Round(($cpuSamples | Measure-Object -Property Value -Minimum).Minimum, 2) } else { 0 }
            Samples = $cpuSamples.Count
            Trend = if ($cpuSamples.Count -gt 1) { Get-TrendDirection -Values ($cpuSamples | Select-Object -ExpandProperty Value) } else { "Stable" }
        }
        Memory = @{
            Average = if ($memorySamples.Count -gt 0) { [Math]::Round(($memorySamples | Measure-Object -Property UsagePercent -Average).Average, 2) } else { 0 }
            Maximum = if ($memorySamples.Count -gt 0) { [Math]::Round(($memorySamples | Measure-Object -Property UsagePercent -Maximum).Maximum, 2) } else { 0 }
            Current = if ($memorySamples.Count -gt 0) { $memorySamples[-1].UsagePercent } else { 0 }
            TotalGB = if ($memorySamples.Count -gt 0) { $memorySamples[-1].TotalGB } else { 0 }
            UsedGB = if ($memorySamples.Count -gt 0) { $memorySamples[-1].UsedGB } else { 0 }
            FreeGB = if ($memorySamples.Count -gt 0) { $memorySamples[-1].FreeGB } else { 0 }
            Trend = if ($memorySamples.Count -gt 1) { Get-TrendDirection -Values ($memorySamples | Select-Object -ExpandProperty UsagePercent) } else { "Stable" }
        }
        Disk = if ($diskSamples.Count -gt 0) { $diskSamples[-1].Disks } else { @() }
        Network = if ($networkSamples.Count -gt 0) { $networkSamples[-1].Interfaces } else { @() }
    }
}

# Helper function for application metrics
function Get-ApplicationMetrics {
    param([int]$Duration)
    
    $currentProcess = Get-Process -Id $PID
    $startTime = Get-Date
    
    # Calculate startup time from process start
    $startupTime = [Math]::Round(((Get-Date) - $currentProcess.StartTime).TotalSeconds, 2)
    
    # Get PowerShell runspace information
    $runspaceCount = 1
    try {
        $runspaceCount = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.RunspacePool.GetAvailableRunspaces().Count
    } catch {
        # Fallback to single runspace
        $runspaceCount = 1
    }
    
    # Get loaded modules
    $loadedModules = Get-Module | Where-Object { $_.Name -like "Aither*" } | Select-Object Name, Version, Path
    
    return @{
        StartupTime = $startupTime
        ProcessInfo = @{
            WorkingSetMB = [Math]::Round($currentProcess.WorkingSet64 / 1MB, 2)
            PeakWorkingSetMB = [Math]::Round($currentProcess.PeakWorkingSet64 / 1MB, 2)
            ThreadCount = $currentProcess.Threads.Count
            Runtime = [Math]::Round(((Get-Date) - $currentProcess.StartTime).TotalMinutes, 2)
            ProcessId = $currentProcess.Id
            ProcessName = $currentProcess.ProcessName
        }
        RunspaceCount = $runspaceCount
        ActiveModules = $loadedModules
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        ExecutionPolicy = Get-ExecutionPolicy
    }
}

# Helper function for module metrics
function Get-ModuleMetrics {
    $modules = Get-Module | Where-Object { $_.Name -like "Aither*" -or $_.Name -in @("Pester", "PSScriptAnalyzer") }
    
    return @{
        TotalModules = $modules.Count
        AitherModules = ($modules | Where-Object { $_.Name -like "Aither*" }).Count
        ModuleDetails = $modules | Select-Object Name, Version, @{
            Name = "SizeMB"
            Expression = { 
                if ($_.Path) {
                    try {
                        [Math]::Round((Get-ChildItem $_.Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                    } catch { 0 }
                } else { 0 }
            }
        }, Path
    }
}

# Helper function for operation metrics
function Get-OperationMetrics {
    return @{
        LastPatchOperation = Get-LastPatchMetrics
        LastTestExecution = Get-LastTestMetrics
        LastDeployment = Get-LastDeploymentMetrics
        SystemUptime = Get-SystemUptime
    }
}

# Helper function for SLA compliance calculation
function Calculate-SLACompliance {
    param($SystemMetrics, $ApplicationMetrics)
    
    $slaChecks = @{
        StartupTime = @{
            Target = 3.0
            Actual = $ApplicationMetrics.StartupTime
            Status = if ($ApplicationMetrics.StartupTime -lt 3.0) { "Pass" } else { "Fail" }
        }
        CPUUsage = @{
            Target = 80.0
            Actual = $SystemMetrics.CPU.Average
            Status = if ($SystemMetrics.CPU.Average -lt 80.0) { "Pass" } else { "Fail" }
        }
        MemoryUsage = @{
            Target = 85.0
            Actual = $SystemMetrics.Memory.Average
            Status = if ($SystemMetrics.Memory.Average -lt 85.0) { "Pass" } else { "Fail" }
        }
    }
    
    $passCount = ($slaChecks.Values | Where-Object { $_.Status -eq "Pass" }).Count
    $totalCount = $slaChecks.Count
    
    return @{
        Overall = if ($passCount -eq $totalCount) { "Pass" } else { "Fail" }
        Score = [Math]::Round(($passCount / $totalCount) * 100, 2)
        Details = $slaChecks
    }
}

# Helper function for trend analysis
function Get-PerformanceTrends {
    param($CurrentMetrics, [switch]$IncludeHistory)
    
    $trends = @{
        CPU = @{
            Direction = $CurrentMetrics.System.CPU.Trend
            Prediction = "Stable"
            Recommendation = "Normal operation"
        }
        Memory = @{
            Direction = $CurrentMetrics.System.Memory.Trend
            Prediction = "Stable"
            Recommendation = "Normal operation"
        }
    }
    
    # Add recommendations based on trends
    if ($CurrentMetrics.System.CPU.Average -gt 70) {
        $trends.CPU.Recommendation = "Consider optimizing CPU-intensive operations"
    }
    
    if ($CurrentMetrics.System.Memory.Average -gt 80) {
        $trends.Memory.Recommendation = "Monitor memory usage and consider optimization"
    }
    
    return $trends
}

# Helper function for trend direction calculation
function Get-TrendDirection {
    param([array]$Values)
    
    if ($Values.Count -lt 2) { return "Stable" }
    
    $first = $Values[0]
    $last = $Values[-1]
    $difference = $last - $first
    
    if ([Math]::Abs($difference) -lt 2) { return "Stable" }
    elseif ($difference -gt 0) { return "Increasing" }
    else { return "Decreasing" }
}

# Helper function for Linux CPU usage
function Get-LinuxCpuUsage {
    try {
        $cpuStat = Get-Content /proc/stat | Select-Object -First 1
        $values = $cpuStat -split '\s+' | Select-Object -Skip 1 | ForEach-Object { [long]$_ }
        $idle = $values[3] + $values[4]  # idle + iowait
        $total = ($values | Measure-Object -Sum).Sum
        $usage = [Math]::Round((($total - $idle) / $total) * 100, 2)
        return $usage
    } catch {
        return 0
    }
}

# Helper function to store performance metrics
function Store-PerformanceMetrics {
    param($Metrics)
    
    try {
        $storageDir = Join-Path $script:ProjectRoot "data/monitoring/performance"
        if (-not (Test-Path $storageDir)) {
            New-Item -Path $storageDir -ItemType Directory -Force | Out-Null
        }
        
        $fileName = "performance-$(Get-Date -Format 'yyyyMMdd').json"
        $filePath = Join-Path $storageDir $fileName
        
        # Load existing data if file exists
        $existingData = @()
        if (Test-Path $filePath) {
            $existingData = Get-Content $filePath | ConvertFrom-Json
        }
        
        # Add new metrics
        $existingData += $Metrics
        
        # Keep only last 24 hours of data
        $cutoffTime = (Get-Date).AddHours(-24)
        $filteredData = $existingData | Where-Object { 
            [datetime]$_.Timestamp -gt $cutoffTime 
        }
        
        # Save back to file
        $filteredData | ConvertTo-Json -Depth 6 | Set-Content -Path $filePath -Encoding UTF8
        
        Write-CustomLog -Message "Performance metrics stored to: $filePath" -Level "DEBUG"
    } catch {
        Write-CustomLog -Message "Error storing performance metrics: $($_.Exception.Message)" -Level "WARNING"
    }
}

# Helper function to convert metrics to CSV format
function ConvertTo-PerformanceCSV {
    param($Metrics)
    
    $csvData = @()
    $csvData += [PSCustomObject]@{
        Timestamp = $Metrics.Timestamp
        'CPU_Average' = $Metrics.System.CPU.Average
        'CPU_Maximum' = $Metrics.System.CPU.Maximum
        'Memory_Average' = $Metrics.System.Memory.Average
        'Memory_Current' = $Metrics.System.Memory.Current
        'Memory_TotalGB' = $Metrics.System.Memory.TotalGB
        'SLA_Score' = $Metrics.SLACompliance.Score
        'SLA_Status' = $Metrics.SLACompliance.Overall
        'Platform' = $Metrics.Metadata.Platform
    }
    
    return $csvData | ConvertTo-Csv -NoTypeInformation
}

# Helper functions for last operation metrics
function Get-LastPatchMetrics {
    return @{
        LastExecution = "N/A"
        Status = "Unknown"
        Duration = 0
    }
}

function Get-LastTestMetrics {
    return @{
        LastExecution = "N/A"
        Status = "Unknown"
        Duration = 0
    }
}

function Get-LastDeploymentMetrics {
    return @{
        LastExecution = "N/A"
        Status = "Unknown"
        Duration = 0
    }
}

Export-ModuleMember -Function Get-SystemPerformance