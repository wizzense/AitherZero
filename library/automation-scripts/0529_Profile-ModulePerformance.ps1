#Requires -Version 7.0

<#
.SYNOPSIS
    Profiles module load performance and generates metrics for dashboard
.DESCRIPTION
    Measures module loading performance, memory usage, and generates
    comprehensive metrics for inclusion in dashboards and reports.
    
    Exit Codes:
    0   - Success
    1   - Performance issues detected
    2   - Critical error
    
.NOTES
    Stage: Reporting
    Order: 0529
    Dependencies: None
    Tags: performance, profiling, dashboard, metrics
    AllowParallel: false
#>

[CmdletBinding()]
param(
    [switch]$Optimize,
    [switch]$Detailed,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Initialize
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:PerformanceMetrics = @{}

# Logging
function Write-PerfLog {
    param([string]$Message, [string]$Level = 'Information')
    $timestamp = Get-Date -Format 'HH:mm:ss.fff'
    $color = switch ($Level) {
        'Information' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

try {
    Write-PerfLog "Starting module performance profiling" -Level 'Information'
    
    # Baseline memory
    [System.GC]::Collect()
    $baselineMemory = [System.GC]::GetTotalMemory($false)
    Write-PerfLog "Baseline memory: $([Math]::Round($baselineMemory / 1MB, 2)) MB" -Level 'Information'
    
    # Measure module load time
    $env:AITHERZERO_DISABLE_TRANSCRIPT = '1'
    $env:AITHERZERO_DEBUG = '1'  # Enable timing
    
    $loadStart = Get-Date
    $loadOutput = & {
        Import-Module (Join-Path $script:ProjectRoot 'AitherZero.psd1') -Force 2>&1
    }
    $loadEnd = Get-Date
    $loadDuration = ($loadEnd - $loadStart).TotalMilliseconds
    
    # Memory after load
    [System.GC]::Collect()
    $afterLoadMemory = [System.GC]::GetTotalMemory($false)
    $memoryIncrease = $afterLoadMemory - $baselineMemory
    
    # Extract module timings from debug output
    $moduleTimings = @{}
    $loadOutput | Where-Object { $_ -match '(.+\.psm1):\s+(\d+\.?\d*)\s*ms' } | ForEach-Object {
        if ($_ -match '(.+\.psm1):\s+(\d+\.?\d*)') {
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($matches[1])
            $timing = [double]$matches[2]
            $moduleTimings[$moduleName] = $timing
        }
    }
    
    # Get loaded modules (count nested modules from AitherZero)
    $aitherzeroModule = Get-Module AitherZero
    $moduleCount = if ($aitherzeroModule) { 
        ($aitherzeroModule.NestedModules | Measure-Object).Count + 1 
    } else { 
        0 
    }
    
    # Get exported commands
    # $aitherzeroModule already assigned above
    $exportedCommands = if ($aitherzeroModule) {
        ($aitherzeroModule.ExportedCommands.Keys | Measure-Object).Count
    } else {
        0
    }
    
    # Performance metrics
    $script:PerformanceMetrics = @{
        Timestamp = Get-Date -Format 'o'
        ModuleLoadTime = @{
            TotalMs = [Math]::Round($loadDuration, 2)
            TotalSeconds = [Math]::Round($loadDuration / 1000, 2)
            PerModule = if ($moduleCount -gt 0) { [Math]::Round($loadDuration / $moduleCount, 2) } else { 0 }
        }
        Memory = @{
            BaselineMB = [Math]::Round($baselineMemory / 1MB, 2)
            AfterLoadMB = [Math]::Round($afterLoadMemory / 1MB, 2)
            IncreaseMB = [Math]::Round($memoryIncrease / 1MB, 2)
            IncreasePercent = if ($baselineMemory -gt 0) { [Math]::Round(($memoryIncrease / $baselineMemory) * 100, 2) } else { 0 }
        }
        Modules = @{
            Total = $moduleCount
            LoadedCount = $moduleCount
            LoadPercentage = 100.0
            ExportedCommands = $exportedCommands
        }
        ModuleTimings = $moduleTimings
        TopSlowestModules = ($moduleTimings.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
            @{
                Module = $_.Key
                TimeMs = $_.Value
            }
        })
        Performance = @{
            LoadTimeRating = if ($loadDuration -lt 2000) { 'Excellent' } 
                           elseif ($loadDuration -lt 3000) { 'Good' }
                           elseif ($loadDuration -lt 5000) { 'Fair' }
                           else { 'Poor' }
            MemoryRating = if ($memoryIncrease -lt 50MB) { 'Excellent' }
                          elseif ($memoryIncrease -lt 100MB) { 'Good' }
                          elseif ($memoryIncrease -lt 200MB) { 'Fair' }
                          else { 'Poor' }
        }
        Environment = @{
            OS = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            PSVersion = $PSVersionTable.PSVersion.ToString()
            CI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true')
        }
    }
    
    # Display results
    Write-PerfLog "`n=== MODULE LOAD PERFORMANCE ===" -Level 'Success'
    Write-PerfLog "Total Load Time: $($script:PerformanceMetrics.ModuleLoadTime.TotalSeconds)s" -Level 'Information'
    Write-PerfLog "Rating: $($script:PerformanceMetrics.Performance.LoadTimeRating)" -Level 'Success'
    Write-PerfLog "Modules Loaded: $moduleCount" -Level 'Information'
    Write-PerfLog "Exported Commands: $exportedCommands" -Level 'Information'
    
    Write-PerfLog "`n=== MEMORY USAGE ===" -Level 'Success'
    Write-PerfLog "Memory Increase: $($script:PerformanceMetrics.Memory.IncreaseMB) MB" -Level 'Information'
    Write-PerfLog "Rating: $($script:PerformanceMetrics.Performance.MemoryRating)" -Level 'Success'
    
    if ($Detailed -and $moduleTimings.Count -gt 0) {
        Write-PerfLog "`n=== TOP 10 SLOWEST MODULES ===" -Level 'Information'
        $script:PerformanceMetrics.TopSlowestModules | ForEach-Object {
            Write-PerfLog "  $($_.Module): $($_.TimeMs)ms" -Level 'Information'
        }
    }
    
    # Save metrics
    $metricsPath = Join-Path $script:ProjectRoot 'reports/performance-metrics.json'
    $metricsDir = Split-Path $metricsPath -Parent
    if (-not (Test-Path $metricsDir)) {
        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    }
    
    $script:PerformanceMetrics | ConvertTo-Json -Depth 10 | Out-File $metricsPath -Encoding utf8
    Write-PerfLog "`nMetrics saved to: $metricsPath" -Level 'Success'
    
    # Generate dashboard data
    $dashboardData = @{
        title = "AitherZero Module Performance"
        timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        metrics = @(
            @{
                name = "Module Load Time"
                value = "$($script:PerformanceMetrics.ModuleLoadTime.TotalSeconds)s"
                status = $script:PerformanceMetrics.Performance.LoadTimeRating.ToLower()
            }
            @{
                name = "Memory Usage"
                value = "$($script:PerformanceMetrics.Memory.IncreaseMB)MB"
                status = $script:PerformanceMetrics.Performance.MemoryRating.ToLower()
            }
            @{
                name = "Modules Loaded"
                value = "$moduleCount"
                status = "excellent"
            }
            @{
                name = "Exported Commands"
                value = "$exportedCommands"
                status = "excellent"
            }
        )
        charts = @{
            loadTime = @{
                type = "bar"
                data = $script:PerformanceMetrics.TopSlowestModules | Select-Object -First 5
            }
        }
    }
    
    $dashboardPath = Join-Path $script:ProjectRoot 'reports/performance-dashboard.json'
    $dashboardData | ConvertTo-Json -Depth 10 | Out-File $dashboardPath -Encoding utf8
    Write-PerfLog "Dashboard data saved to: $dashboardPath" -Level 'Success'
    
    # Optimization recommendations
    if ($Optimize) {
        Write-PerfLog "`n=== OPTIMIZATION RECOMMENDATIONS ===" -Level 'Information'
        
        if ($loadDuration -gt 3000) {
            Write-PerfLog "⚠ Module load time exceeds 3s - consider lazy loading" -Level 'Warning'
        }
        
        if ($memoryIncrease -gt 100MB) {
            Write-PerfLog "⚠ Memory increase exceeds 100MB - review module dependencies" -Level 'Warning'
        }
        
        $slowModules = $moduleTimings.GetEnumerator() | Where-Object { $_.Value -gt 200 }
        if ($slowModules) {
            Write-PerfLog "⚠ Modules taking >200ms to load:" -Level 'Warning'
            $slowModules | ForEach-Object {
                Write-PerfLog "  - $($_.Key): $($_.Value)ms" -Level 'Warning'
            }
        }
    }
    
    # Exit code based on performance
    if ($loadDuration -gt 5000 -or $memoryIncrease -gt 200MB) {
        Write-PerfLog "`nPerformance issues detected" -Level 'Warning'
        exit 1
    }
    
    Write-PerfLog "`nPerformance profiling completed successfully" -Level 'Success'
    exit 0
    
} catch {
    Write-PerfLog "Critical error during profiling: $_" -Level 'Error'
    Write-PerfLog $_.ScriptStackTrace -Level 'Error'
    exit 2
}
