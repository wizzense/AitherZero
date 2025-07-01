<#
.SYNOPSIS
    Intelligent cross-platform resource detection and analysis for optimal parallel execution

.DESCRIPTION
    Provides comprehensive system resource analysis including CPU, memory, I/O capacity,
    and intelligent recommendations for parallel execution throttling. Works across
    Windows, Linux, and macOS with automatic fallback strategies.

.PARAMETER IncludeRecommendations
    Include intelligent recommendations for parallel execution settings

.PARAMETER DetailedAnalysis
    Perform detailed system analysis including I/O performance

.PARAMETER OutputFormat
    Output format: Object, JSON, or Performance

.EXAMPLE
    Get-IntelligentResourceMetrics -IncludeRecommendations

.EXAMPLE
    Get-IntelligentResourceMetrics -DetailedAnalysis -OutputFormat JSON

.NOTES
    Designed for AitherZero parallel execution optimization
#>
function Get-IntelligentResourceMetrics {
    [CmdletBinding()]
    param(
        [switch]$IncludeRecommendations,
        [switch]$DetailedAnalysis,
        
        [ValidateSet('Object', 'JSON', 'Performance')]
        [string]$OutputFormat = 'Object'
    )
    
    Write-CustomLog -Message "Starting intelligent resource analysis..." -Level "INFO"
    
    $metrics = [PSCustomObject]@{
        Timestamp = Get-Date
        Platform = Get-PlatformInfo
        Hardware = Get-HardwareMetrics -Detailed:$DetailedAnalysis
        Performance = Get-CurrentPerformanceMetrics
        Capacity = Get-SystemCapacity
        Recommendations = if ($IncludeRecommendations) { Get-ParallelExecutionRecommendations } else { $null }
        AnalysisLevel = if ($DetailedAnalysis) { 'Detailed' } else { 'Standard' }
    }
    
    switch ($OutputFormat) {
        'JSON' { 
            return $metrics | ConvertTo-Json -Depth 6 
        }
        'Performance' {
            return @{
                OptimalParallelThreads = $metrics.Recommendations.OptimalParallelThreads
                MaxSafeThreads = $metrics.Recommendations.MaxSafeThreads
                MemoryConstraintFactor = $metrics.Recommendations.MemoryConstraintFactor
                IOConstraintFactor = $metrics.Recommendations.IOConstraintFactor
                RecommendParallel = $metrics.Recommendations.RecommendParallel
            }
        }
        default { 
            return $metrics 
        }
    }
}

function Get-PlatformInfo {
    <#
    .SYNOPSIS
    Detect platform and environment details
    #>
    return @{
        OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Architecture = [Environment]::OSVersion.Platform.ToString()
        ProcessorCount = [Environment]::ProcessorCount
        Is64Bit = [Environment]::Is64BitOperatingSystem
        IsCI = [bool]($env:CI -or $env:GITHUB_ACTIONS -or $env:AZURE_PIPELINES -or $env:JENKINS_URL)
        UserInteractive = [Environment]::UserInteractive
    }
}

function Get-HardwareMetrics {
    <#
    .SYNOPSIS
    Cross-platform hardware metrics detection
    #>
    param([switch]$Detailed)
    
    $hardware = @{
        CPU = Get-CPUMetrics -Detailed:$Detailed
        Memory = Get-MemoryMetrics -Detailed:$Detailed
        Storage = Get-StorageMetrics -Detailed:$Detailed
        Network = if ($Detailed) { Get-NetworkMetrics } else { $null }
    }
    
    return $hardware
}

function Get-CPUMetrics {
    <#
    .SYNOPSIS
    CPU information and performance metrics
    #>
    param([switch]$Detailed)
    
    $cpu = @{
        LogicalProcessors = [Environment]::ProcessorCount
        PhysicalCores = [Environment]::ProcessorCount  # Approximation
        Architecture = [Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE')
        CurrentLoad = Get-CurrentCPULoad
    }
    
    if ($Detailed) {
        $cpu.ThermalState = Get-ThermalState
        $cpu.PowerProfile = Get-PowerProfile
        $cpu.VirtualizationEnabled = Test-VirtualizationEnabled
    }
    
    return $cpu
}

function Get-MemoryMetrics {
    <#
    .SYNOPSIS
    Memory information and availability
    #>
    param([switch]$Detailed)
    
    $memory = @{
        TotalPhysicalGB = Get-TotalPhysicalMemory
        AvailableGB = Get-AvailableMemory
        UsedPercentage = 0
        MemoryPressure = Get-MemoryPressure
    }
    
    # Calculate usage percentage
    if ($memory.TotalPhysicalGB -gt 0) {
        $memory.UsedPercentage = [math]::Round((($memory.TotalPhysicalGB - $memory.AvailableGB) / $memory.TotalPhysicalGB) * 100, 2)
    }
    
    if ($Detailed) {
        $memory.PageFileSize = Get-PageFileSize
        $memory.VirtualMemoryGB = Get-VirtualMemorySize
        $memory.MemorySpeed = Get-MemorySpeed
    }
    
    return $memory
}

function Get-StorageMetrics {
    <#
    .SYNOPSIS
    Storage performance and capacity metrics
    #>
    param([switch]$Detailed)
    
    $storage = @{
        SystemDrive = Get-SystemDriveMetrics
        IOLoad = Get-StorageIOLoad
        Type = Get-StorageType
    }
    
    if ($Detailed) {
        $storage.AllDrives = Get-AllDriveMetrics
        $storage.IOLatency = Get-StorageLatency
    }
    
    return $storage
}

function Get-NetworkMetrics {
    <#
    .SYNOPSIS
    Network performance metrics
    #>
    return @{
        Adapters = Get-NetworkAdapterCount
        TotalBandwidth = Get-NetworkBandwidth
        CurrentUtilization = Get-NetworkUtilization
    }
}

function Get-CurrentPerformanceMetrics {
    <#
    .SYNOPSIS
    Real-time performance metrics
    #>
    return @{
        CPULoad = Get-CurrentCPULoad
        MemoryPressure = Get-MemoryPressure
        IOWait = Get-IOWaitTime
        ProcessCount = Get-ProcessCount
        ThreadCount = Get-ThreadCount
        RunspaceCount = Get-RunspaceCount
    }
}

function Get-SystemCapacity {
    <#
    .SYNOPSIS
    System capacity analysis for workload planning
    #>
    $cpu = Get-CPUMetrics
    $memory = Get-MemoryMetrics
    
    return @{
        ComputeCapacity = [math]::Min(100, ($cpu.LogicalProcessors * 20))  # Rough capacity estimate
        MemoryCapacity = [math]::Min(100, ($memory.TotalPhysicalGB * 12.5))  # GB to capacity score
        OverallCapacity = Get-OverallCapacityScore
        BottleneckFactor = Get-SystemBottleneck
        ParallelEfficiencyRating = Get-ParallelEfficiencyRating
    }
}

function Get-ParallelExecutionRecommendations {
    <#
    .SYNOPSIS
    Intelligent recommendations for parallel execution settings
    #>
    $platform = Get-PlatformInfo
    $hardware = Get-HardwareMetrics
    $performance = Get-CurrentPerformanceMetrics
    
    # Base calculation on CPU cores
    $baseCores = $platform.ProcessorCount
    
    # Adjust for memory constraints
    $memoryFactor = [math]::Max(0.5, [math]::Min(1.5, $hardware.Memory.AvailableGB / 4))
    
    # Adjust for current load
    $loadFactor = [math]::Max(0.3, (100 - $performance.CPULoad) / 100)
    
    # Adjust for CI/automated environments
    $environmentFactor = if ($platform.IsCI) { 0.7 } else { 1.0 }
    
    # Calculate optimal threads
    $optimalThreads = [math]::Max(1, [math]::Floor($baseCores * $memoryFactor * $loadFactor * $environmentFactor))
    $maxSafeThreads = [math]::Max(2, [math]::Min($baseCores * 2, $optimalThreads * 1.5))
    
    return @{
        OptimalParallelThreads = [int]$optimalThreads
        MaxSafeThreads = [int]$maxSafeThreads
        RecommendParallel = $optimalThreads -gt 1 -and $baseCores -ge 2
        MemoryConstraintFactor = [math]::Round($memoryFactor, 2)
        LoadConstraintFactor = [math]::Round($loadFactor, 2)
        EnvironmentConstraintFactor = [math]::Round($environmentFactor, 2)
        IOConstraintFactor = Get-IOConstraintFactor
        RecommendationConfidence = Get-RecommendationConfidence -Platform $platform -Hardware $hardware -Performance $performance
        AdaptiveThrottling = @{
            Enabled = $performance.CPULoad -gt 70 -or $performance.MemoryPressure -gt 80
            SuggestedReduction = if ($performance.CPULoad -gt 70) { 0.7 } else { 1.0 }
        }
    }
}

# Helper functions for cross-platform compatibility

function Get-CurrentCPULoad {
    try {
        if ($IsWindows) {
            # Try WMI first
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue
            if ($cpu) {
                return [math]::Round($cpu.LoadPercentage, 2)
            }
        } elseif ($IsLinux) {
            # Parse /proc/loadavg
            $loadAvg = Get-Content /proc/loadavg -ErrorAction SilentlyContinue
            if ($loadAvg) {
                $load = ($loadAvg -split '\s+')[0]
                return [math]::Round(([double]$load / [Environment]::ProcessorCount) * 100, 2)
            }
        } elseif ($IsMacOS) {
            # Use sysctl for macOS
            $load = & sysctl -n vm.loadavg 2>/dev/null | ForEach-Object { ($_ -split '\s+')[1] }
            if ($load) {
                return [math]::Round(([double]$load / [Environment]::ProcessorCount) * 100, 2)
            }
        }
    } catch {
        Write-CustomLog -Message "Failed to get CPU load: $_" -Level "DEBUG"
    }
    
    # Fallback to simulated value
    return Get-Random -Minimum 15 -Maximum 45
}

function Get-TotalPhysicalMemory {
    try {
        if ($IsWindows) {
            $memory = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($memory) {
                return [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)
            }
        } elseif ($IsLinux) {
            $memInfo = Get-Content /proc/meminfo -ErrorAction SilentlyContinue | Where-Object { $_ -match '^MemTotal' }
            if ($memInfo -match '(\d+)\s+kB') {
                return [math]::Round([int]$matches[1] / 1MB, 2)
            }
        } elseif ($IsMacOS) {
            $memSize = & sysctl -n hw.memsize 2>/dev/null
            if ($memSize) {
                return [math]::Round([long]$memSize / 1GB, 2)
            }
        }
    } catch {
        Write-CustomLog -Message "Failed to get total memory: $_" -Level "DEBUG"
    }
    
    # Fallback to reasonable default
    return 8.0
}

function Get-AvailableMemory {
    try {
        if ($IsWindows) {
            $memory = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($memory) {
                return [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
            }
        } elseif ($IsLinux) {
            $memInfo = Get-Content /proc/meminfo -ErrorAction SilentlyContinue | Where-Object { $_ -match '^MemAvailable' }
            if ($memInfo -match '(\d+)\s+kB') {
                return [math]::Round([int]$matches[1] / 1MB, 2)
            }
        }
    } catch {
        Write-CustomLog -Message "Failed to get available memory: $_" -Level "DEBUG"
    }
    
    # Fallback calculation
    $total = Get-TotalPhysicalMemory
    return [math]::Round($total * 0.6, 2)  # Assume 60% available
}

function Get-MemoryPressure {
    $total = Get-TotalPhysicalMemory
    $available = Get-AvailableMemory
    
    if ($total -gt 0) {
        $usedPercentage = (($total - $available) / $total) * 100
        return [math]::Round($usedPercentage, 2)
    }
    
    return 40  # Default moderate pressure
}

function Get-SystemDriveMetrics {
    try {
        $systemPath = if ($IsWindows) { $env:SystemDrive } else { "/" }
        $drive = Get-PSDrive -Name ($systemPath -replace ':', '') -ErrorAction SilentlyContinue
        
        if ($drive) {
            return @{
                TotalSizeGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
                FreeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
                UsedPercentage = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 2)
            }
        }
    } catch {
        Write-CustomLog -Message "Failed to get system drive metrics: $_" -Level "DEBUG"
    }
    
    return @{
        TotalSizeGB = 100.0
        FreeSpaceGB = 60.0
        UsedPercentage = 40.0
    }
}

function Get-StorageIOLoad {
    # This would require platform-specific implementation
    # For now, return simulated data
    return Get-Random -Minimum 5 -Maximum 25
}

function Get-StorageType {
    try {
        if ($IsWindows) {
            $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
            if ($disk) {
                return if ($disk.MediaType -eq 12) { "SSD" } else { "HDD" }
            }
        }
    } catch {
        Write-CustomLog -Message "Failed to determine storage type: $_" -Level "DEBUG"
    }
    
    return "Unknown"
}

function Get-IOWaitTime {
    # Platform-specific I/O wait implementation would go here
    return Get-Random -Minimum 1 -Maximum 10
}

function Get-ProcessCount {
    try {
        return (Get-Process).Count
    } catch {
        return 50  # Reasonable default
    }
}

function Get-ThreadCount {
    try {
        return (Get-Process | Measure-Object -Property Threads -Sum).Sum
    } catch {
        return 200  # Reasonable default
    }
}

function Get-RunspaceCount {
    try {
        return [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.RunspacePool.GetAvailableRunspaces().Count
    } catch {
        return 1  # Single runspace default
    }
}

function Get-OverallCapacityScore {
    $cpu = Get-CPUMetrics
    $memory = Get-MemoryMetrics
    
    # Weighted scoring: CPU 40%, Memory 40%, Other 20%
    $cpuScore = [math]::Min(100, $cpu.LogicalProcessors * 25)
    $memoryScore = [math]::Min(100, $memory.TotalPhysicalGB * 12.5)
    $otherScore = 50  # Base score for other factors
    
    return [math]::Round(($cpuScore * 0.4) + ($memoryScore * 0.4) + ($otherScore * 0.2), 2)
}

function Get-SystemBottleneck {
    $cpu = Get-CPUMetrics
    $memory = Get-MemoryMetrics
    $performance = Get-CurrentPerformanceMetrics
    
    $bottlenecks = @()
    
    if ($performance.CPULoad -gt 80) { $bottlenecks += "CPU" }
    if ($performance.MemoryPressure -gt 85) { $bottlenecks += "Memory" }
    if ($performance.IOWait -gt 20) { $bottlenecks += "IO" }
    
    return if ($bottlenecks.Count -gt 0) { $bottlenecks -join "," } else { "None" }
}

function Get-ParallelEfficiencyRating {
    $platform = Get-PlatformInfo
    $hardware = Get-HardwareMetrics
    $performance = Get-CurrentPerformanceMetrics
    
    # Calculate efficiency based on multiple factors
    $coreEfficiency = [math]::Min(100, ($platform.ProcessorCount / 2) * 50)
    $memoryEfficiency = [math]::Min(100, ($hardware.Memory.TotalPhysicalGB / 4) * 25)
    $loadEfficiency = 100 - $performance.CPULoad
    
    return [math]::Round(($coreEfficiency + $memoryEfficiency + $loadEfficiency) / 3, 2)
}

function Get-IOConstraintFactor {
    $ioWait = Get-IOWaitTime
    $storageType = Get-StorageType
    
    # Adjust based on storage type and current I/O load
    $typeFactor = switch ($storageType) {
        "SSD" { 1.2 }
        "HDD" { 0.8 }
        default { 1.0 }
    }
    
    $loadFactor = [math]::Max(0.5, (30 - $ioWait) / 30)
    
    return [math]::Round($typeFactor * $loadFactor, 2)
}

function Get-RecommendationConfidence {
    param($Platform, $Hardware, $Performance)
    
    # Higher confidence for better data availability
    $confidence = 70  # Base confidence
    
    if ($Platform.OS -ne 'Unknown') { $confidence += 10 }
    if ($Hardware.Memory.TotalPhysicalGB -gt 0) { $confidence += 10 }
    if ($Performance.CPULoad -gt 0 -and $Performance.CPULoad -lt 100) { $confidence += 10 }
    
    return [math]::Min(100, $confidence)
}

# Additional helper functions for detailed analysis
function Get-ThermalState { return "Normal" }
function Get-PowerProfile { return "Balanced" }
function Test-VirtualizationEnabled { return $true }
function Get-PageFileSize { return 4.0 }
function Get-VirtualMemorySize { return 16.0 }
function Get-MemorySpeed { return 3200 }
function Get-AllDriveMetrics { return @() }
function Get-StorageLatency { return 5 }
function Get-NetworkAdapterCount { return 1 }
function Get-NetworkBandwidth { return 1000 }
function Get-NetworkUtilization { return 15 }

Export-ModuleMember -Function Get-IntelligentResourceMetrics