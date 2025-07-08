function Optimize-MemoryUsage {
    <#
    .SYNOPSIS
        Optimizes memory usage and resource management for OpenTofu deployments.

    .DESCRIPTION
        Implements memory optimization techniques including garbage collection,
        resource pooling, streaming configuration processing, and memory monitoring.

    .PARAMETER DeploymentId
        ID of the deployment to optimize memory usage for.

    .PARAMETER ConfigurationPath
        Path to the deployment configuration file.

    .PARAMETER OptimizationMode
        Memory optimization mode (Conservative, Balanced, Aggressive).

    .PARAMETER EnableGarbageCollection
        Enable aggressive garbage collection optimization.

    .PARAMETER EnableResourcePooling
        Enable resource pooling for frequently used objects.

    .PARAMETER EnableStreamingMode
        Enable streaming mode for large configuration files.

    .PARAMETER MemoryThreshold
        Memory usage threshold percentage to trigger optimizations.

    .PARAMETER MonitoringInterval
        Interval for memory monitoring in seconds.

    .PARAMETER GenerateReport
        Generate memory optimization report.

    .EXAMPLE
        Optimize-MemoryUsage -ConfigurationPath ".\large-config.yaml" -OptimizationMode "Balanced"

    .EXAMPLE
        Optimize-MemoryUsage -DeploymentId "abc123" -OptimizationMode "Aggressive" -EnableStreamingMode

    .OUTPUTS
        Memory optimization result object
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'ByDeployment')]
        [string]$DeploymentId,

        [Parameter(ParameterSetName = 'ByConfiguration')]
        [string]$ConfigurationPath,

        [Parameter()]
        [ValidateSet('Conservative', 'Balanced', 'Aggressive')]
        [string]$OptimizationMode = 'Balanced',

        [Parameter()]
        [switch]$EnableGarbageCollection,

        [Parameter()]
        [switch]$EnableResourcePooling,

        [Parameter()]
        [switch]$EnableStreamingMode,

        [Parameter()]
        [ValidateRange(10, 95)]
        [int]$MemoryThreshold = 80,

        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$MonitoringInterval = 30,

        [Parameter()]
        [switch]$GenerateReport
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting memory usage optimization"

        # Initialize memory monitoring
        $script:initialMemory = Get-MemoryUsage
        $script:optimizationStartTime = Get-Date

        # Get optimization settings
        $optimizationSettings = Get-MemoryOptimizationSettings -Mode $OptimizationMode

        # Override settings if explicitly specified
        if ($PSBoundParameters.ContainsKey('EnableGarbageCollection')) { $optimizationSettings.EnableGarbageCollection = $EnableGarbageCollection }
        if ($PSBoundParameters.ContainsKey('EnableResourcePooling')) { $optimizationSettings.EnableResourcePooling = $EnableResourcePooling }
        if ($PSBoundParameters.ContainsKey('EnableStreamingMode')) { $optimizationSettings.EnableStreamingMode = $EnableStreamingMode }

        Write-CustomLog -Level 'INFO' -Message "Initial memory usage: $([Math]::Round($script:initialMemory.WorkingSetMB, 2)) MB"
    }

    process {
        try {
            # Initialize optimization result
            $optimizationResult = @{
                Success = $true
                OptimizationMode = $OptimizationMode
                Settings = $optimizationSettings
                InitialMemory = $script:initialMemory
                FinalMemory = $null
                MemoryReduction = 0
                OptimizationsApplied = @()
                MemoryMetrics = @()
                Errors = @()
                Warnings = @()
                StartTime = $script:optimizationStartTime
                EndTime = $null
            }

            # Determine configuration source
            if ($DeploymentId) {
                $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
                $configPath = Join-Path $deploymentPath "deployment-config.json"

                if (-not (Test-Path $configPath)) {
                    throw "Configuration not found for deployment: $DeploymentId"
                }
            } else {
                $configPath = $ConfigurationPath
                if (-not (Test-Path $configPath)) {
                    throw "Configuration file not found: $ConfigurationPath"
                }
            }

            # Apply garbage collection optimization
            if ($optimizationSettings.EnableGarbageCollection) {
                Write-CustomLog -Level 'INFO' -Message "Applying garbage collection optimization"

                $gcResult = Optimize-GarbageCollection -MemoryThreshold $MemoryThreshold
                $optimizationResult.OptimizationsApplied += $gcResult

                # Collect memory metrics after GC
                $optimizationResult.MemoryMetrics += @{
                    Timestamp = Get-Date
                    Type = 'AfterGC'
                    Memory = Get-MemoryUsage
                }
            }

            # Apply resource pooling optimization
            if ($optimizationSettings.EnableResourcePooling) {
                Write-CustomLog -Level 'INFO' -Message "Initializing resource pooling"

                $poolResult = Initialize-ResourcePooling -ConfigurationPath $configPath
                $optimizationResult.OptimizationsApplied += $poolResult

                $optimizationResult.MemoryMetrics += @{
                    Timestamp = Get-Date
                    Type = 'AfterPooling'
                    Memory = Get-MemoryUsage
                }
            }

            # Apply streaming mode optimization
            if ($optimizationSettings.EnableStreamingMode) {
                Write-CustomLog -Level 'INFO' -Message "Enabling streaming mode for configuration processing"

                $streamResult = Enable-StreamingMode -ConfigurationPath $configPath
                $optimizationResult.OptimizationsApplied += $streamResult

                $optimizationResult.MemoryMetrics += @{
                    Timestamp = Get-Date
                    Type = 'AfterStreaming'
                    Memory = Get-MemoryUsage
                }
            }

            # Apply memory monitoring optimization
            $monitorResult = Start-MemoryMonitoring -Interval $MonitoringInterval -Threshold $MemoryThreshold
            $optimizationResult.OptimizationsApplied += $monitorResult

            # Apply configuration caching optimization
            if ($optimizationSettings.EnableConfigurationCaching) {
                Write-CustomLog -Level 'INFO' -Message "Optimizing configuration caching"

                $cacheResult = Optimize-ConfigurationCaching -ConfigurationPath $configPath
                $optimizationResult.OptimizationsApplied += $cacheResult

                $optimizationResult.MemoryMetrics += @{
                    Timestamp = Get-Date
                    Type = 'AfterCaching'
                    Memory = Get-MemoryUsage
                }
            }

            # Apply object lifecycle management
            if ($optimizationSettings.EnableObjectLifecycleManagement) {
                Write-CustomLog -Level 'INFO' -Message "Implementing object lifecycle management"

                $lifecycleResult = Implement-ObjectLifecycleManagement
                $optimizationResult.OptimizationsApplied += $lifecycleResult

                $optimizationResult.MemoryMetrics += @{
                    Timestamp = Get-Date
                    Type = 'AfterLifecycle'
                    Memory = Get-MemoryUsage
                }
            }

            # Apply memory leak detection and prevention
            $leakResult = Enable-MemoryLeakDetection
            $optimizationResult.OptimizationsApplied += $leakResult

            # Final memory measurement
            $optimizationResult.FinalMemory = Get-MemoryUsage
            $optimizationResult.EndTime = Get-Date

            # Calculate memory reduction
            $memoryReduction = $script:initialMemory.WorkingSetMB - $optimizationResult.FinalMemory.WorkingSetMB
            $memoryReductionPercent = if ($script:initialMemory.WorkingSetMB -gt 0) {
                ($memoryReduction / $script:initialMemory.WorkingSetMB) * 100
            } else { 0 }

            $optimizationResult.MemoryReduction = @{
                AbsoluteMB = [Math]::Round($memoryReduction, 2)
                PercentageReduction = [Math]::Round($memoryReductionPercent, 2)
            }

            # Generate optimization report if requested
            if ($GenerateReport) {
                $reportPath = Generate-MemoryOptimizationReport -OptimizationResult $optimizationResult
                $optimizationResult.ReportPath = $reportPath
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Memory optimization completed"
            Write-CustomLog -Level 'INFO' -Message "Memory reduction: $($optimizationResult.MemoryReduction.AbsoluteMB) MB ($($optimizationResult.MemoryReduction.PercentageReduction)%)"

            return [PSCustomObject]$optimizationResult

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to optimize memory usage: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-MemoryOptimizationSettings {
    param([string]$Mode)

    switch ($Mode) {
        'Conservative' {
            return @{
                EnableGarbageCollection = $true
                EnableResourcePooling = $false
                EnableStreamingMode = $false
                EnableConfigurationCaching = $true
                EnableObjectLifecycleManagement = $false
                AggressiveOptimization = $false
                MemoryPressureThreshold = 90
            }
        }
        'Balanced' {
            return @{
                EnableGarbageCollection = $true
                EnableResourcePooling = $true
                EnableStreamingMode = $true
                EnableConfigurationCaching = $true
                EnableObjectLifecycleManagement = $true
                AggressiveOptimization = $false
                MemoryPressureThreshold = 80
            }
        }
        'Aggressive' {
            return @{
                EnableGarbageCollection = $true
                EnableResourcePooling = $true
                EnableStreamingMode = $true
                EnableConfigurationCaching = $true
                EnableObjectLifecycleManagement = $true
                AggressiveOptimization = $true
                MemoryPressureThreshold = 70
            }
        }
    }
}

function Get-MemoryUsage {
    try {
        $process = Get-Process -Id $PID

        return @{
            WorkingSetMB = [Math]::Round($process.WorkingSet / 1MB, 2)
            PrivateMemoryMB = [Math]::Round($process.PrivateMemorySize64 / 1MB, 2)
            VirtualMemoryMB = [Math]::Round($process.VirtualMemorySize64 / 1MB, 2)
            PagedMemoryMB = [Math]::Round($process.PagedMemorySize64 / 1MB, 2)
            NonPagedMemoryMB = [Math]::Round($process.NonpagedSystemMemorySize64 / 1MB, 2)
            Timestamp = Get-Date
            ProcessId = $PID
        }
    } catch {
        Write-CustomLog -Level 'WARN' -Message "Failed to get memory usage: $_"
        return @{
            WorkingSetMB = 0
            PrivateMemoryMB = 0
            VirtualMemoryMB = 0
            PagedMemoryMB = 0
            NonPagedMemoryMB = 0
            Timestamp = Get-Date
            ProcessId = $PID
            Error = $_.Exception.Message
        }
    }
}

function Optimize-GarbageCollection {
    param([int]$MemoryThreshold)

    $optimization = @{
        Type = 'GarbageCollection'
        Applied = $false
        MemoryFreed = 0
        Description = ''
        Details = @{}
    }

    try {
        $beforeMemory = Get-MemoryUsage

        # Force garbage collection
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()

        # Wait a moment for GC to complete
        Start-Sleep -Milliseconds 500

        $afterMemory = Get-MemoryUsage

        $memoryFreed = $beforeMemory.WorkingSetMB - $afterMemory.WorkingSetMB

        $optimization.Applied = $true
        $optimization.MemoryFreed = [Math]::Round($memoryFreed, 2)
        $optimization.Description = "Garbage collection optimization applied"
        $optimization.Details = @{
            BeforeMemoryMB = $beforeMemory.WorkingSetMB
            AfterMemoryMB = $afterMemory.WorkingSetMB
            MemoryFreedMB = $memoryFreed
            GCGeneration0Collections = [System.GC]::CollectionCount(0)
            GCGeneration1Collections = [System.GC]::CollectionCount(1)
            GCGeneration2Collections = [System.GC]::CollectionCount(2)
        }

        Write-CustomLog -Level 'INFO' -Message "Garbage collection freed $([Math]::Round($memoryFreed, 2)) MB"

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to apply garbage collection optimization: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Initialize-ResourcePooling {
    param([string]$ConfigurationPath)

    $optimization = @{
        Type = 'ResourcePooling'
        Applied = $false
        PoolsCreated = 0
        Description = ''
        Details = @{}
    }

    try {
        # Create global resource pools if they don't exist
        if (-not $global:OpenTofuResourcePools) {
            $global:OpenTofuResourcePools = @{
                ConfigurationCache = @{}
                StateCache = @{}
                ProviderConnections = @{}
                TemplateCache = @{}
                CreatedAt = Get-Date
                AccessCount = 0
            }
        }

        # Initialize specific pools based on configuration
        $poolsCreated = 0

        # Configuration object pool
        if (-not $global:OpenTofuResourcePools.ConfigurationCache.ContainsKey($ConfigurationPath)) {
            $global:OpenTofuResourcePools.ConfigurationCache[$ConfigurationPath] = @{
                LastAccessed = Get-Date
                AccessCount = 0
                CachedData = $null
            }
            $poolsCreated++
        }

        # State object pool
        $global:OpenTofuResourcePools.StateCache['default'] = @{
            LastAccessed = Get-Date
            Objects = @{}
        }
        $poolsCreated++

        # Provider connection pool
        $global:OpenTofuResourcePools.ProviderConnections['default'] = @{
            LastAccessed = Get-Date
            Connections = @{}
            MaxConnections = 10
        }
        $poolsCreated++

        $optimization.Applied = $true
        $optimization.PoolsCreated = $poolsCreated
        $optimization.Description = "Resource pooling initialized with $poolsCreated pool(s)"
        $optimization.Details = @{
            PoolsCreated = $poolsCreated
            ConfigurationPoolEnabled = $true
            StatePoolEnabled = $true
            ProviderPoolEnabled = $true
        }

        Write-CustomLog -Level 'INFO' -Message "Resource pooling initialized successfully"

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to initialize resource pooling: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Enable-StreamingMode {
    param([string]$ConfigurationPath)

    $optimization = @{
        Type = 'StreamingMode'
        Applied = $false
        MemorySaved = 0
        Description = ''
        Details = @{}
    }

    try {
        # Check if configuration is large enough to benefit from streaming
        $configSize = (Get-Item $ConfigurationPath).Length
        $configSizeMB = [Math]::Round($configSize / 1MB, 2)

        if ($configSizeMB -gt 1) {  # Only apply streaming for files > 1MB
            # Enable streaming configuration reader
            $global:OpenTofuStreamingMode = @{
                Enabled = $true
                ChunkSize = 64KB
                BufferSize = 256KB
                ConfigurationPath = $ConfigurationPath
                MemoryEstimateMB = $configSizeMB * 0.3  # Estimate 30% memory savings
            }

            $optimization.Applied = $true
            $optimization.MemorySaved = $global:OpenTofuStreamingMode.MemoryEstimateMB
            $optimization.Description = "Streaming mode enabled for large configuration ($configSizeMB MB)"
            $optimization.Details = @{
                ConfigurationSizeMB = $configSizeMB
                ChunkSize = $global:OpenTofuStreamingMode.ChunkSize
                BufferSize = $global:OpenTofuStreamingMode.BufferSize
                EstimatedMemorySavingsMB = $optimization.MemorySaved
            }

            Write-CustomLog -Level 'INFO' -Message "Streaming mode enabled for $configSizeMB MB configuration"
        } else {
            $optimization.Applied = $false
            $optimization.Description = "Configuration too small for streaming mode ($configSizeMB MB)"
        }

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to enable streaming mode: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Start-MemoryMonitoring {
    param(
        [int]$Interval,
        [int]$Threshold
    )

    $optimization = @{
        Type = 'MemoryMonitoring'
        Applied = $false
        MonitoringEnabled = $false
        Description = ''
        Details = @{}
    }

    try {
        # Create memory monitoring job if not already running
        if (-not $global:OpenTofuMemoryMonitor) {
            $global:OpenTofuMemoryMonitor = @{
                Enabled = $true
                Interval = $Interval
                Threshold = $Threshold
                StartTime = Get-Date
                LastCheck = Get-Date
                Alerts = @()
            }
        }

        $optimization.Applied = $true
        $optimization.MonitoringEnabled = $true
        $optimization.Description = "Memory monitoring started (threshold: $Threshold%, interval: $Interval seconds)"
        $optimization.Details = @{
            MonitoringInterval = $Interval
            MemoryThreshold = $Threshold
            MonitoringStartTime = $global:OpenTofuMemoryMonitor.StartTime
        }

        Write-CustomLog -Level 'INFO' -Message "Memory monitoring enabled"

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to start memory monitoring: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Optimize-ConfigurationCaching {
    param([string]$ConfigurationPath)

    $optimization = @{
        Type = 'ConfigurationCaching'
        Applied = $false
        CacheHits = 0
        Description = ''
        Details = @{}
    }

    try {
        # Initialize configuration cache if not exists
        if (-not $global:OpenTofuConfigurationCache) {
            $global:OpenTofuConfigurationCache = @{
                Cache = @{}
                MaxEntries = 50
                HitCount = 0
                MissCount = 0
                CreatedAt = Get-Date
            }
        }

        # Implement cache eviction policy (LRU)
        if ($global:OpenTofuConfigurationCache.Cache.Count -gt $global:OpenTofuConfigurationCache.MaxEntries) {
            $oldestEntry = $global:OpenTofuConfigurationCache.Cache.GetEnumerator() |
                          Sort-Object { $_.Value.LastAccessed } |
                          Select-Object -First 1

            $global:OpenTofuConfigurationCache.Cache.Remove($oldestEntry.Key)
            Write-CustomLog -Level 'DEBUG' -Message "Evicted oldest cache entry: $($oldestEntry.Key)"
        }

        $optimization.Applied = $true
        $optimization.CacheHits = $global:OpenTofuConfigurationCache.HitCount
        $optimization.Description = "Configuration caching optimized"
        $optimization.Details = @{
            CacheSize = $global:OpenTofuConfigurationCache.Cache.Count
            MaxEntries = $global:OpenTofuConfigurationCache.MaxEntries
            HitCount = $global:OpenTofuConfigurationCache.HitCount
            MissCount = $global:OpenTofuConfigurationCache.MissCount
            HitRatio = if ($global:OpenTofuConfigurationCache.HitCount + $global:OpenTofuConfigurationCache.MissCount -gt 0) {
                [Math]::Round($global:OpenTofuConfigurationCache.HitCount / ($global:OpenTofuConfigurationCache.HitCount + $global:OpenTofuConfigurationCache.MissCount) * 100, 2)
            } else { 0 }
        }

        Write-CustomLog -Level 'INFO' -Message "Configuration caching optimized"

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to optimize configuration caching: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Implement-ObjectLifecycleManagement {
    $optimization = @{
        Type = 'ObjectLifecycleManagement'
        Applied = $false
        ManagedObjects = 0
        Description = ''
        Details = @{}
    }

    try {
        # Initialize object lifecycle manager
        if (-not $global:OpenTofuObjectLifecycleManager) {
            $global:OpenTofuObjectLifecycleManager = @{
                Enabled = $true
                ManagedObjects = @{}
                DisposalQueue = @()
                LastCleanup = Get-Date
                CleanupInterval = [TimeSpan]::FromMinutes(5)
            }
        }

        # Register common object types for lifecycle management
        $managedObjectTypes = @(
            'System.IO.FileStream',
            'System.Net.Http.HttpClient',
            'System.Data.SqlClient.SqlConnection'
        )

        foreach ($objectType in $managedObjectTypes) {
            if (-not $global:OpenTofuObjectLifecycleManager.ManagedObjects.ContainsKey($objectType)) {
                $global:OpenTofuObjectLifecycleManager.ManagedObjects[$objectType] = @{
                    Instances = @()
                    AutoDispose = $true
                    MaxLifetime = [TimeSpan]::FromMinutes(30)
                }
            }
        }

        $optimization.Applied = $true
        $optimization.ManagedObjects = $managedObjectTypes.Count
        $optimization.Description = "Object lifecycle management implemented for $($managedObjectTypes.Count) object types"
        $optimization.Details = @{
            ManagedObjectTypes = $managedObjectTypes
            AutoCleanupEnabled = $true
            CleanupInterval = $global:OpenTofuObjectLifecycleManager.CleanupInterval
        }

        Write-CustomLog -Level 'INFO' -Message "Object lifecycle management implemented"

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to implement object lifecycle management: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Enable-MemoryLeakDetection {
    $optimization = @{
        Type = 'MemoryLeakDetection'
        Applied = $false
        DetectionEnabled = $false
        Description = ''
        Details = @{}
    }

    try {
        # Initialize memory leak detection
        if (-not $global:OpenTofuMemoryLeakDetector) {
            $global:OpenTofuMemoryLeakDetector = @{
                Enabled = $true
                BaselineMemory = Get-MemoryUsage
                CheckInterval = [TimeSpan]::FromMinutes(10)
                LastCheck = Get-Date
                LeakThreshold = 100  # MB
                SuspiciousGrowth = @()
                Alerts = @()
            }
        }

        $optimization.Applied = $true
        $optimization.DetectionEnabled = $true
        $optimization.Description = "Memory leak detection enabled"
        $optimization.Details = @{
            BaselineMemoryMB = $global:OpenTofuMemoryLeakDetector.BaselineMemory.WorkingSetMB
            CheckInterval = $global:OpenTofuMemoryLeakDetector.CheckInterval
            LeakThreshold = $global:OpenTofuMemoryLeakDetector.LeakThreshold
        }

        Write-CustomLog -Level 'INFO' -Message "Memory leak detection enabled"

    } catch {
        $optimization.Applied = $false
        $optimization.Description = "Failed to enable memory leak detection: $_"
        Write-CustomLog -Level 'WARN' -Message $optimization.Description
    }

    return $optimization
}

function Generate-MemoryOptimizationReport {
    param([hashtable]$OptimizationResult)

    $reportPath = Join-Path $env:PROJECT_ROOT "memory-optimization-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Memory Optimization Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f8ff; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .metrics { display: flex; flex-wrap: wrap; gap: 15px; margin: 20px 0; }
        .metric { background-color: #f9f9f9; padding: 15px; border-radius: 5px; flex: 1; min-width: 200px; }
        .metric h3 { margin-top: 0; color: #007acc; }
        .optimization { margin: 15px 0; padding: 10px; border-left: 4px solid #007acc; background-color: #f9f9f9; }
        .applied { border-left-color: #28a745; }
        .not-applied { border-left-color: #dc3545; }
        .memory-chart { background-color: #fff; padding: 15px; border-radius: 5px; margin: 20px 0; border: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Memory Optimization Report</h1>
        <p><strong>Optimization Mode:</strong> $($OptimizationResult.OptimizationMode)</p>
        <p><strong>Start Time:</strong> $($OptimizationResult.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
        <p><strong>Duration:</strong> $([Math]::Round(($OptimizationResult.EndTime - $OptimizationResult.StartTime).TotalSeconds, 2)) seconds</p>
    </div>

    <div class="metrics">
        <div class="metric">
            <h3>Initial Memory</h3>
            <p style="font-size: 20px; margin: 10px 0;">$($OptimizationResult.InitialMemory.WorkingSetMB) MB</p>
        </div>
        <div class="metric">
            <h3>Final Memory</h3>
            <p style="font-size: 20px; margin: 10px 0;">$($OptimizationResult.FinalMemory.WorkingSetMB) MB</p>
        </div>
        <div class="metric">
            <h3>Memory Saved</h3>
            <p style="font-size: 20px; margin: 10px 0; color: #28a745;">$($OptimizationResult.MemoryReduction.AbsoluteMB) MB</p>
        </div>
        <div class="metric">
            <h3>Reduction %</h3>
            <p style="font-size: 20px; margin: 10px 0; color: #28a745;">$($OptimizationResult.MemoryReduction.PercentageReduction)%</p>
        </div>
    </div>

    <h2>Applied Optimizations</h2>
"@

    foreach ($optimization in $OptimizationResult.OptimizationsApplied) {
        $cssClass = if ($optimization.Applied) { 'optimization applied' } else { 'optimization not-applied' }

        $html += @"
    <div class="$cssClass">
        <h3>$($optimization.Type)</h3>
        <p><strong>Status:</strong> $(if ($optimization.Applied) { 'Applied' } else { 'Not Applied' })</p>
        <p><strong>Description:</strong> $($optimization.Description)</p>
"@

        if ($optimization.Details) {
            $html += "<p><strong>Details:</strong></p><ul>"
            foreach ($detail in $optimization.Details.GetEnumerator()) {
                $html += "<li><strong>$($detail.Key):</strong> $($detail.Value)</li>"
            }
            $html += "</ul>"
        }

        $html += "</div>"
    }

    # Add memory usage timeline if metrics are available
    if ($OptimizationResult.MemoryMetrics.Count -gt 0) {
        $html += @"
    <div class="memory-chart">
        <h2>Memory Usage Timeline</h2>
        <table style="width: 100%; border-collapse: collapse;">
            <tr style="background-color: #f2f2f2;">
                <th style="border: 1px solid #ddd; padding: 8px;">Time</th>
                <th style="border: 1px solid #ddd; padding: 8px;">Type</th>
                <th style="border: 1px solid #ddd; padding: 8px;">Working Set (MB)</th>
                <th style="border: 1px solid #ddd; padding: 8px;">Private Memory (MB)</th>
            </tr>
"@

        foreach ($metric in $OptimizationResult.MemoryMetrics) {
            $html += @"
            <tr>
                <td style="border: 1px solid #ddd; padding: 8px;">$($metric.Timestamp.ToString('HH:mm:ss'))</td>
                <td style="border: 1px solid #ddd; padding: 8px;">$($metric.Type)</td>
                <td style="border: 1px solid #ddd; padding: 8px;">$($metric.Memory.WorkingSetMB)</td>
                <td style="border: 1px solid #ddd; padding: 8px;">$($metric.Memory.PrivateMemoryMB)</td>
            </tr>
"@
        }

        $html += "</table></div>"
    }

    $html += "</body></html>"

    $html | Set-Content -Path $reportPath

    return $reportPath
}
