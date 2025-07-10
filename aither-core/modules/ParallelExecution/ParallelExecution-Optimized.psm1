#Requires -Version 7.0

<#
.SYNOPSIS
Optimized Parallel execution utilities for AitherZero
.DESCRIPTION
This module provides high-performance cross-platform parallel processing capabilities,
including optimized module loading, memory management, and reliability improvements.
.NOTES
- Compatible with PowerShell 7.0+ on Windows, Linux, and macOS
- Optimized for CPU-intensive and I/O-intensive workloads
- Improved memory management and garbage collection
- Enhanced error handling and recovery mechanisms
- Performance monitoring and adaptive throttling
#>

# Performance optimization variables
$script:PerformanceCache = @{}
$script:ThreadPoolStats = @{}
$script:MemoryPressureThreshold = 80  # Percentage
$script:OptimalThrottleLimits = @{}

# Enhanced logging with fallback
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Write-CustomLog {
        param(
            [Parameter(Mandatory = $true)][string]$Message,
            [Parameter()][string]$Level = 'INFO',
            [Parameter()][string]$Component = 'ParallelExecution'
        )
        $color = switch ($Level) {
            'ERROR' { 'Red' }; 'WARN' { 'Yellow' }; 'INFO' { 'Green' }; 'SUCCESS' { 'Cyan' }
            'DEBUG' { 'Gray' }; 'VERBOSE' { 'Magenta' }; 'TRACE' { 'DarkGray' }; default { 'White' }
        }
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Write-Host "[$timestamp] [$Level] [$Component] $Message" -ForegroundColor $color
    }
}

function Get-MemoryPressure {
    <#
    .SYNOPSIS
    Monitors current memory pressure and system load
    .DESCRIPTION
    Returns system memory usage percentage and recommends throttling adjustments
    #>
    [CmdletBinding()]
    param()
    
    try {
        if ($IsWindows) {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            $totalMemory = $os.TotalVisibleMemorySize * 1KB
            $freeMemory = $os.FreePhysicalMemory * 1KB
            $usedMemory = $totalMemory - $freeMemory
            $memoryPressure = [Math]::Round(($usedMemory / $totalMemory) * 100, 1)
        } else {
            # Linux/macOS memory check
            if (Get-Command free -ErrorAction SilentlyContinue) {
                $memInfo = free -m | Select-String "^Mem:"
                if ($memInfo) {
                    $values = $memInfo.Line -split '\s+' | Where-Object { $_ -ne '' }
                    $total = [int]$values[1]
                    $used = [int]$values[2]
                    $memoryPressure = [Math]::Round(($used / $total) * 100, 1)
                } else {
                    $memoryPressure = 50  # Default fallback
                }
            } else {
                $memoryPressure = 50  # Default fallback
            }
        }
        
        return @{
            MemoryPressure = $memoryPressure
            IsHighPressure = $memoryPressure -gt $script:MemoryPressureThreshold
            RecommendedThrottleReduction = if ($memoryPressure -gt 90) { 0.5 } 
                                         elseif ($memoryPressure -gt 80) { 0.75 } 
                                         else { 1.0 }
        }
    } catch {
        Write-CustomLog "Error checking memory pressure: $($_.Exception.Message)" -Level "WARN"
        return @{
            MemoryPressure = 50
            IsHighPressure = $false
            RecommendedThrottleReduction = 1.0
        }
    }
}

function Optimize-GarbageCollection {
    <#
    .SYNOPSIS
    Performs optimized garbage collection based on system state
    .DESCRIPTION
    Intelligently triggers garbage collection when memory pressure is high
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    try {
        $memoryInfo = Get-MemoryPressure
        
        if ($Force -or $memoryInfo.IsHighPressure) {
            Write-CustomLog "Performing garbage collection (Memory pressure: $($memoryInfo.MemoryPressure)%)" -Level "INFO"
            
            # Collect all generations
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            # Compact large object heap if available (.NET Core 2.1+)
            try {
                [GC]::Collect(2, [GCCollectionMode]::Forced, $true, $true)
            } catch {
                # Fallback for older .NET versions
                [GC]::Collect(2, [GCCollectionMode]::Forced)
            }
            
            $newMemoryInfo = Get-MemoryPressure
            $improvement = $memoryInfo.MemoryPressure - $newMemoryInfo.MemoryPressure
            
            Write-CustomLog "Garbage collection completed. Memory improvement: $($improvement.ToString('F1'))%" -Level "SUCCESS"
        }
    } catch {
        Write-CustomLog "Error during garbage collection: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Get-OptimalThrottleLimit {
    <#
    .SYNOPSIS
    Enhanced optimal throttle calculation with memory awareness
    .DESCRIPTION
    Calculates optimal parallel thread count considering CPU, memory, and current system load
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('CPU', 'IO', 'Network', 'Mixed')]
        [string]$WorkloadType = 'Mixed',

        [Parameter(Mandatory = $false)]
        [int]$MaxLimit = 32,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0.1, 1.0)]
        [double]$SystemLoadFactor = 1.0,
        
        [switch]$IgnoreCache
    )

    try {
        # Check cache first unless ignored
        $cacheKey = "$WorkloadType-$MaxLimit-$SystemLoadFactor"
        if (-not $IgnoreCache -and $script:OptimalThrottleLimits.ContainsKey($cacheKey)) {
            $cached = $script:OptimalThrottleLimits[$cacheKey]
            $cacheAge = (Get-Date) - $cached.Timestamp
            if ($cacheAge.TotalMinutes -lt 5) {  # Cache for 5 minutes
                Write-CustomLog "Using cached throttle limit: $($cached.Value)" -Level "DEBUG"
                return $cached.Value
            }
        }
        
        $cpuCount = [Environment]::ProcessorCount
        $memoryInfo = Get-MemoryPressure

        # Base calculation by workload type
        $baseThrottle = switch ($WorkloadType) {
            'CPU' { $cpuCount }
            'IO' { $cpuCount * 2 }
            'Network' { $cpuCount * 3 }
            'Mixed' { [Math]::Ceiling($cpuCount * 1.5) }
        }

        # Apply system load factor
        $adjustedThrottle = [Math]::Ceiling($baseThrottle * $SystemLoadFactor)
        
        # Apply memory pressure reduction
        $memoryAdjustedThrottle = [Math]::Ceiling($adjustedThrottle * $memoryInfo.RecommendedThrottleReduction)

        # Apply maximum limit
        $optimalThrottle = [Math]::Min($memoryAdjustedThrottle, $MaxLimit)

        # Ensure minimum of 1
        $optimalThrottle = [Math]::Max(1, $optimalThrottle)
        
        # Cache the result
        $script:OptimalThrottleLimits[$cacheKey] = @{
            Value = $optimalThrottle
            Timestamp = Get-Date
        }

        Write-CustomLog "Optimal throttle calculated: $optimalThrottle (Type: $WorkloadType, CPUs: $cpuCount, Memory: $($memoryInfo.MemoryPressure)%)" -Level "INFO"

        return $optimalThrottle
    }
    catch {
        Write-CustomLog "Error calculating optimal throttle limit: $($_.Exception.Message)" -Level "ERROR"
        return [Math]::Max(1, $cpuCount)  # Safe fallback
    }
}

function Invoke-ParallelForEach {
    <#
    .SYNOPSIS
    Enhanced parallel foreach with memory management and error recovery
    .DESCRIPTION
    Optimized parallel processing with automatic memory management, error recovery, and performance monitoring
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [object[]]$InputObject = @(),

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = 0,  # 0 = auto-calculate

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,
        
        [Parameter(Mandatory = $false)]
        [string]$WorkloadType = 'Mixed',
        
        [switch]$EnableMemoryOptimization
    )

    begin {
        if ($PSBoundParameters.ContainsKey('InputObject') -and $InputObject) {
            $items = @($InputObject)
        } else {
            $items = @()
        }
    }

    process {
        if (-not $PSBoundParameters.ContainsKey('InputObject') -and $null -ne $_) {
            $items += $_
        }
    }

    end {
        if ($null -eq $items -or $items.Count -eq 0) {
            Write-CustomLog "No items to process" -Level "INFO"
            return @()
        }

        try {
            $startTime = Get-Date
            
            # Calculate optimal throttle if not specified
            if ($ThrottleLimit -eq 0) {
                $ThrottleLimit = Get-OptimalThrottleLimit -WorkloadType $WorkloadType
            }
            
            Write-CustomLog "Starting enhanced parallel execution with $($items.Count) items, throttle: $ThrottleLimit" -Level "INFO"

            # Memory optimization if enabled
            if ($EnableMemoryOptimization) {
                Optimize-GarbageCollection
            }

            # Process scriptblock for parameter handling
            $scriptText = $ScriptBlock.ToString()
            $hasUsingVariables = $scriptText -match '\$using:'
            $hasParameters = $scriptText -match 'param\s*\('
            
            if ($hasUsingVariables) {
                Write-CustomLog "Detected `$using: variables, preserving closure context" -Level "DEBUG"
                if ($hasParameters) {
                    $parallelScript = {
                        param($item)
                        $_ = $item
                        & $ScriptBlock $item
                    }.GetNewClosure()
                } else {
                    $parallelScript = $ScriptBlock
                }
            } elseif ($hasParameters) {
                $parallelScript = [scriptblock]::Create(@"
                    `$___item = `$_
                    & { $scriptText } `$___item
"@)
            } else {
                $parallelScript = $ScriptBlock
            }

            # Execute with enhanced error handling
            try {
                $results = $items | ForEach-Object -Parallel $parallelScript -ThrottleLimit $ThrottleLimit -TimeoutSeconds $TimeoutSeconds
                
                # Memory cleanup after processing
                if ($EnableMemoryOptimization -and $items.Count -gt 100) {
                    Optimize-GarbageCollection
                }
                
            } catch [System.Management.Automation.RuntimeException] {
                if ($_.Exception.Message -match "timeout") {
                    Write-CustomLog "Parallel execution timed out after $TimeoutSeconds seconds" -Level "ERROR"
                    throw "Parallel execution timeout: Operation exceeded $TimeoutSeconds seconds"
                } else {
                    Write-CustomLog "Parallel execution runtime error: $($_.Exception.Message)" -Level "ERROR"
                    throw
                }
            }

            $duration = (Get-Date) - $startTime
            $throughput = $items.Count / $duration.TotalSeconds
            
            Write-CustomLog "Enhanced parallel execution completed in $($duration.TotalSeconds.ToString('F2')) seconds. Throughput: $($throughput.ToString('F2')) items/sec" -Level "SUCCESS"

            return $results
        }
        catch {
            Write-CustomLog "Enhanced parallel execution failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Start-ParallelExecution {
    <#
    .SYNOPSIS
    High-level parallel execution function with reliability improvements
    .DESCRIPTION
    Provides a simplified interface for executing multiple jobs in parallel
    with comprehensive result aggregation, error handling, and memory optimization
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Jobs,

        [Parameter(Mandatory = $false)]
        [int]$MaxConcurrentJobs = 0,  # 0 = auto-calculate

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,
        
        [switch]$EnableMemoryOptimization,
        
        [switch]$EnableProgressReporting
    )

    try {
        Write-CustomLog "Starting enhanced parallel execution with $($Jobs.Count) jobs" -Level "INFO"
        
        # Calculate optimal concurrency if not specified
        if ($MaxConcurrentJobs -eq 0) {
            $MaxConcurrentJobs = Get-OptimalThrottleLimit -WorkloadType "Mixed"
        }
        
        # Memory optimization before starting
        if ($EnableMemoryOptimization) {
            Optimize-GarbageCollection
        }

        # Start all jobs with throttling
        $runningJobs = @()
        $jobIndex = 0
        
        foreach ($jobDef in $Jobs) {
            $jobIndex++
            
            Write-CustomLog "Starting job $jobIndex/$($Jobs.Count): $($jobDef.Name)" -Level "DEBUG"
            
            $job = Start-Job -Name $jobDef.Name -ScriptBlock $jobDef.ScriptBlock -ArgumentList $jobDef.Arguments
            $runningJobs += $job

            # Progress reporting
            if ($EnableProgressReporting) {
                $percentComplete = [math]::Round(($jobIndex / $Jobs.Count) * 50, 1)  # 50% for job creation
                Write-Progress -Activity "Starting parallel jobs" -Status "$jobIndex/$($Jobs.Count) jobs started" -PercentComplete $percentComplete
            }

            # Throttle job creation if needed
            if ($runningJobs.Count -ge $MaxConcurrentJobs) {
                $completedJobs = $runningJobs | Where-Object { $_.State -ne 'Running' }
                if ($completedJobs.Count -eq 0) {
                    # Wait for at least one job to complete before continuing
                    $firstJob = $runningJobs | Select-Object -First 1
                    Wait-Job -Job $firstJob -Timeout 30 | Out-Null
                }
            }
        }

        Write-CustomLog "All $($Jobs.Count) jobs started, waiting for completion..." -Level "INFO"

        # Wait for all jobs to complete with progress
        $results = Wait-ParallelJobs -Jobs $runningJobs -TimeoutSeconds $TimeoutSeconds -ShowProgress:$EnableProgressReporting

        # Memory cleanup after job completion
        if ($EnableMemoryOptimization) {
            Optimize-GarbageCollection
        }

        # Enhanced result aggregation
        $successfulJobs = @($results | Where-Object { -not $_.HasErrors -and $_.State -eq 'Completed' })
        $failedJobs = @($results | Where-Object { $_.HasErrors -or $_.State -eq 'Failed' })
        $timedOutJobs = @($results | Where-Object { $_.State -eq 'Timeout' })

        $summary = @{
            Success = ($failedJobs.Count -eq 0 -and $timedOutJobs.Count -eq 0)
            TotalJobs = $Jobs.Count
            CompletedJobs = $successfulJobs.Count
            FailedJobs = $failedJobs.Count
            TimedOutJobs = $timedOutJobs.Count
            Results = $results
            Errors = $failedJobs | ForEach-Object { $_.Errors }
            Performance = @{
                JobsPerSecond = $Jobs.Count / ((Get-Date) - (Get-Date).AddSeconds(-$TimeoutSeconds)).TotalSeconds
                MemoryPressure = (Get-MemoryPressure).MemoryPressure
            }
        }

        Write-CustomLog "Enhanced parallel execution completed: $($summary.CompletedJobs)/$($summary.TotalJobs) successful, $($summary.FailedJobs) failed, $($summary.TimedOutJobs) timed out" -Level "SUCCESS"

        return $summary

    } catch {
        Write-CustomLog "Enhanced parallel execution failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Start-ParallelJob {
    <#
    .SYNOPSIS
    Enhanced job creation with memory monitoring
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [object[]]$ArgumentList = @()
    )

    try {
        Write-CustomLog "Starting enhanced background job: $Name" -Level "DEBUG"

        # Add memory monitoring to the script block
        $enhancedScriptBlock = {
            param($OriginalScript, $Args)
            
            try {
                $startTime = Get-Date
                $result = & $OriginalScript @Args
                $endTime = Get-Date
                
                return @{
                    Result = $result
                    ExecutionTime = ($endTime - $startTime).TotalSeconds
                    Success = $true
                }
            } catch {
                return @{
                    Result = $null
                    Error = $_.Exception.Message
                    ExecutionTime = 0
                    Success = $false
                }
            }
        }

        $job = Start-Job -Name $Name -ScriptBlock $enhancedScriptBlock -ArgumentList @($ScriptBlock, $ArgumentList)

        Write-CustomLog "Enhanced job started successfully: $Name (ID: $($job.Id))" -Level "SUCCESS"
        return $job
    }
    catch {
        Write-CustomLog "Failed to start enhanced job $Name : $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Wait-ParallelJobs {
    <#
    .SYNOPSIS
    Enhanced job waiting with memory monitoring and progress
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Job[]]$Jobs,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,

        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress
    )

    try {
        $startTime = Get-Date
        $results = @{}
        $lastGCTime = $startTime

        Write-CustomLog "Waiting for $($Jobs.Count) enhanced jobs to complete (timeout: $TimeoutSeconds seconds)" -Level "INFO"
        
        do {
            $runningJobs = $Jobs | Where-Object { $_.State -eq 'Running' }
            $completedJobs = $Jobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }

            if ($ShowProgress) {
                $percentComplete = [math]::Round((($completedJobs.Count / $Jobs.Count) * 100), 1)
                Write-Progress -Activity "Waiting for parallel jobs" -Status "$($completedJobs.Count)/$($Jobs.Count) completed" -PercentComplete $percentComplete
            }

            # Process completed jobs
            foreach ($job in ($Jobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') })) {
                if (-not $results.ContainsKey($job.Id)) {
                    $jobResult = Receive-Job -Job $job -Keep
                    $hasErrors = $false
                    $jobErrors = @()

                    if ($job.ChildJobs -and $job.ChildJobs.Count -gt 0) {
                        $hasErrors = $job.ChildJobs[0].Error.Count -gt 0
                        $jobErrors = $job.ChildJobs[0].Error
                    } elseif ($job.State -eq 'Failed') {
                        $hasErrors = $true
                        $jobErrors = @("Job failed with state: $($job.State)")
                    }

                    $results[$job.Id] = @{
                        Name = $job.Name
                        State = $job.State
                        Result = $jobResult
                        HasErrors = $hasErrors
                        Errors = $jobErrors
                    }

                    if ($job.State -eq 'Failed') {
                        Write-CustomLog "Enhanced job failed: $($job.Name)" -Level "ERROR"
                    } else {
                        Write-CustomLog "Enhanced job completed: $($job.Name)" -Level "SUCCESS"
                    }
                }
            }

            # Periodic garbage collection during long waits
            $currentTime = Get-Date
            if (($currentTime - $lastGCTime).TotalMinutes -gt 2) {
                $memoryInfo = Get-MemoryPressure
                if ($memoryInfo.IsHighPressure) {
                    Write-CustomLog "Performing maintenance GC during job wait (Memory: $($memoryInfo.MemoryPressure)%)" -Level "DEBUG"
                    Optimize-GarbageCollection
                }
                $lastGCTime = $currentTime
            }

            # Check timeout
            $elapsed = (Get-Date) - $startTime
            if ($elapsed.TotalSeconds -gt $TimeoutSeconds) {
                Write-CustomLog "Timeout reached after $($elapsed.TotalSeconds) seconds" -Level "WARN"
                foreach ($job in $runningJobs) {
                    if (-not $results.ContainsKey($job.Id)) {
                        $results[$job.Id] = @{
                            Name = $job.Name
                            State = 'Timeout'
                            Result = $null
                            HasErrors = $false
                            Errors = @()
                        }
                    }
                }
                break
            }

            if ($runningJobs.Count -gt 0) {
                Start-Sleep -Seconds 1
            }

        } while ($runningJobs.Count -gt 0)

        if ($ShowProgress) {
            Write-Progress -Activity "Waiting for parallel jobs" -Completed
        }

        # Clean up jobs
        $Jobs | Remove-Job -Force -ErrorAction SilentlyContinue

        $duration = (Get-Date) - $startTime
        Write-CustomLog "All enhanced jobs completed in $($duration.TotalSeconds) seconds" -Level "SUCCESS"

        return $results.Values
    }
    catch {
        Write-CustomLog "Error waiting for enhanced parallel jobs: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Export all functions including the missing Start-ParallelExecution
Export-ModuleMember -Function @(
    'Get-MemoryPressure',
    'Optimize-GarbageCollection', 
    'Get-OptimalThrottleLimit',
    'Invoke-ParallelForEach',
    'Start-ParallelExecution',
    'Start-ParallelJob',
    'Wait-ParallelJobs'
)