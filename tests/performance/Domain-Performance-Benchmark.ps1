#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive performance benchmarking and load testing for AitherZero domain architecture
.DESCRIPTION
    This script provides comprehensive performance analysis for the AitherZero domain architecture,
    comparing domain loading vs traditional module loading, memory usage, startup times, and
    concurrent operation performance.
    
    Key Areas Tested:
    1. Domain loading performance vs module loading
    2. Memory usage comparison and optimization
    3. Startup time analysis with different profiles
    4. Concurrent operation load testing
    5. Memory leak detection
    6. Performance regression analysis
    7. Critical workflow profiling
.NOTES
    Performance Test Agent 7 - Mission Critical Performance Validation
    Target: Performance maintained or improved with domain structure
.PARAMETER BenchmarkMode
    Specific benchmark mode: All, DomainVsModule, Memory, Startup, Concurrent, LoadTest
.PARAMETER Iterations
    Number of benchmark iterations for statistical significance
.PARAMETER DetailedOutput
    Enable detailed performance metrics and analysis
.PARAMETER CreateBaseline
    Create new performance baseline for future comparisons
.PARAMETER CompareToBaseline
    Compare current performance to existing baseline
.PARAMETER MemoryProfiler
    Enable memory profiling and leak detection
.PARAMETER ConcurrentUsers
    Number of concurrent users for load testing
.PARAMETER TestDuration
    Duration for load testing in seconds
.EXAMPLE
    ./Domain-Performance-Benchmark.ps1 -BenchmarkMode All -Iterations 5 -DetailedOutput
.EXAMPLE
    ./Domain-Performance-Benchmark.ps1 -BenchmarkMode DomainVsModule -CreateBaseline
.EXAMPLE
    ./Domain-Performance-Benchmark.ps1 -BenchmarkMode LoadTest -ConcurrentUsers 50 -TestDuration 300
#>

param(
    [Parameter()]
    [ValidateSet('All', 'DomainVsModule', 'Memory', 'Startup', 'Concurrent', 'LoadTest', 'Regression')]
    [string]$BenchmarkMode = 'All',
    
    [Parameter()]
    [int]$Iterations = 10,
    
    [Parameter()]
    [switch]$DetailedOutput,
    
    [Parameter()]
    [switch]$CreateBaseline,
    
    [Parameter()]
    [switch]$CompareToBaseline,
    
    [Parameter()]
    [switch]$MemoryProfiler,
    
    [Parameter()]
    [int]$ConcurrentUsers = 25,
    
    [Parameter()]
    [int]$TestDuration = 120
)

$ErrorActionPreference = 'Stop'

# ==============================================================================
# PERFORMANCE BENCHMARK FRAMEWORK
# ==============================================================================

$script:BenchmarkResults = @{
    StartTime = Get-Date
    TestResults = @()
    MemoryProfiles = @()
    LoadTestResults = @()
    RegressionTests = @()
    SystemInfo = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OS = $PSVersionTable.OS
        ProcessorCount = [Environment]::ProcessorCount
        TotalMemory = if ($IsWindows) { 
            try { [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2) }
            catch { "Unknown" }
        } else { 
            try { 
                $memInfo = Get-Content /proc/meminfo | Where-Object { $_ -match "^MemTotal:" }
                if ($memInfo) {
                    $memKB = [int]($memInfo -split '\s+')[1]
                    [math]::Round($memKB / 1MB, 2)
                } else { "Unknown" }
            } catch { "Unknown" }
        }
        WorkingDirectory = $PWD.Path
    }
}

# Find project root
$ProjectRoot = $PSScriptRoot
while ($ProjectRoot -and -not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    $ProjectRoot = Split-Path $ProjectRoot -Parent
}

if (-not $ProjectRoot) {
    throw "Could not find project root (git repository)"
}

Write-Host "🚀 AitherZero Domain Performance Benchmark Suite" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Benchmark Mode: $BenchmarkMode" -ForegroundColor Yellow
Write-Host "Iterations: $Iterations" -ForegroundColor Yellow
Write-Host "System: $([Environment]::ProcessorCount) cores, $($script:BenchmarkResults.SystemInfo.TotalMemory) GB RAM" -ForegroundColor Gray
Write-Host "=" * 80 -ForegroundColor DarkGray

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

function Write-BenchmarkLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO',
        [string]$Component = 'BENCHMARK'
    )
    
    $timestamp = (Get-Date).ToString('HH:mm:ss.fff')
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'INFO' { 'Cyan' }
        default { 'White' }
    }
    
    Write-Host "[$timestamp] [$Component] [$Level] $Message" -ForegroundColor $color
}

function Measure-PerformanceMetrics {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName,
        [hashtable]$ExpectedLimits = @{},
        [switch]$EnableMemoryProfiling
    )
    
    # Force garbage collection for accurate measurement
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    $startTime = Get-Date
    $startMemory = [System.GC]::GetTotalMemory($false)
    $startCpu = (Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds
    $startHandles = (Get-Process -Id $PID).HandleCount
    
    $result = $null
    $exception = $null
    $success = $false
    
    try {
        $result = & $ScriptBlock
        $success = $true
    } catch {
        $exception = $_.Exception
        $result = $exception.Message
    }
    
    $endTime = Get-Date
    $endMemory = [System.GC]::GetTotalMemory($false)
    $endCpu = (Get-Process -Id $PID).TotalProcessorTime.TotalMilliseconds
    $endHandles = (Get-Process -Id $PID).HandleCount
    
    $metrics = @{
        OperationName = $OperationName
        Success = $success
        Result = $result
        Exception = $exception
        StartTime = $startTime
        EndTime = $endTime
        Duration = ($endTime - $startTime).TotalMilliseconds
        MemoryUsed = ($endMemory - $startMemory) / 1MB
        MemoryStart = $startMemory / 1MB
        MemoryEnd = $endMemory / 1MB
        CpuTime = $endCpu - $startCpu
        HandleDelta = $endHandles - $startHandles
        Timestamp = Get-Date
    }
    
    # Performance assessment
    if ($ExpectedLimits.Count -gt 0) {
        $assessment = @{
            WithinDurationLimit = if ($ExpectedLimits.MaxDuration) { $metrics.Duration -le $ExpectedLimits.MaxDuration } else { $true }
            WithinMemoryLimit = if ($ExpectedLimits.MaxMemory) { $metrics.MemoryUsed -le $ExpectedLimits.MaxMemory } else { $true }
            WithinCpuLimit = if ($ExpectedLimits.MaxCpu) { $metrics.CpuTime -le $ExpectedLimits.MaxCpu } else { $true }
            WithinHandleLimit = if ($ExpectedLimits.MaxHandles) { $metrics.HandleDelta -le $ExpectedLimits.MaxHandles } else { $true }
        }
        
        $metrics.PerformanceAssessment = $assessment
        $metrics.OverallPerformance = $assessment.WithinDurationLimit -and $assessment.WithinMemoryLimit -and $assessment.WithinCpuLimit -and $assessment.WithinHandleLimit
    }
    
    return $metrics
}

function Invoke-BenchmarkTest {
    param(
        [scriptblock]$TestBlock,
        [string]$TestName,
        [int]$Iterations = 10,
        [int]$WarmupIterations = 2,
        [hashtable]$ExpectedLimits = @{}
    )
    
    Write-BenchmarkLog "Starting benchmark test: $TestName ($Iterations iterations, $WarmupIterations warmup)"
    
    # Warmup iterations
    for ($i = 1; $i -le $WarmupIterations; $i++) {
        try {
            & $TestBlock | Out-Null
        } catch {
            # Ignore warmup errors
        }
    }
    
    # Force garbage collection after warmup
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    # Benchmark iterations
    $measurements = @()
    for ($i = 1; $i -le $Iterations; $i++) {
        Write-Progress -Activity "Benchmark Test: $TestName" -Status "Iteration $i of $Iterations" -PercentComplete (($i / $Iterations) * 100)
        
        $measurement = Measure-PerformanceMetrics -ScriptBlock $TestBlock -OperationName "$TestName-Iteration-$i" -ExpectedLimits $ExpectedLimits
        $measurements += $measurement
        
        # Small delay between iterations for stability
        Start-Sleep -Milliseconds 50
    }
    
    Write-Progress -Activity "Benchmark Test: $TestName" -Completed
    
    # Calculate statistics
    $durations = $measurements | ForEach-Object { $_.Duration }
    $memoryUsages = $measurements | ForEach-Object { $_.MemoryUsed }
    $cpuTimes = $measurements | ForEach-Object { $_.CpuTime }
    $successfulMeasurements = $measurements | Where-Object { $_.Success }
    
    $statistics = @{
        TestName = $TestName
        Iterations = $Iterations
        WarmupIterations = $WarmupIterations
        SuccessfulIterations = $successfulMeasurements.Count
        FailedIterations = $Iterations - $successfulMeasurements.Count
        SuccessRate = $successfulMeasurements.Count / $Iterations
        
        # Duration statistics
        MinDuration = ($durations | Measure-Object -Minimum).Minimum
        MaxDuration = ($durations | Measure-Object -Maximum).Maximum
        AverageDuration = ($durations | Measure-Object -Average).Average
        MedianDuration = ($durations | Sort-Object)[[math]::Floor($durations.Count / 2)]
        P95Duration = ($durations | Sort-Object)[[math]::Floor($durations.Count * 0.95)]
        P99Duration = ($durations | Sort-Object)[[math]::Floor($durations.Count * 0.99)]
        StandardDeviation = [math]::Sqrt(($durations | ForEach-Object { [math]::Pow($_ - ($durations | Measure-Object -Average).Average, 2) } | Measure-Object -Sum).Sum / $durations.Count)
        
        # Memory statistics
        MinMemoryUsage = ($memoryUsages | Measure-Object -Minimum).Minimum
        MaxMemoryUsage = ($memoryUsages | Measure-Object -Maximum).Maximum
        AverageMemoryUsage = ($memoryUsages | Measure-Object -Average).Average
        
        # CPU statistics
        MinCpuTime = ($cpuTimes | Measure-Object -Minimum).Minimum
        MaxCpuTime = ($cpuTimes | Measure-Object -Maximum).Maximum
        AverageCpuTime = ($cpuTimes | Measure-Object -Average).Average
        
        # Raw measurements
        Measurements = $measurements
        Timestamp = Get-Date
    }
    
    Write-BenchmarkLog "Completed benchmark test: $TestName" -Level SUCCESS
    Write-BenchmarkLog "  Success Rate: $([math]::Round($statistics.SuccessRate * 100, 2))%" -Level INFO
    Write-BenchmarkLog "  Average Duration: $([math]::Round($statistics.AverageDuration, 2))ms" -Level INFO
    Write-BenchmarkLog "  P95 Duration: $([math]::Round($statistics.P95Duration, 2))ms" -Level INFO
    Write-BenchmarkLog "  Average Memory: $([math]::Round($statistics.AverageMemoryUsage, 2))MB" -Level INFO
    
    $script:BenchmarkResults.TestResults += $statistics
    return $statistics
}

function Start-LoadTestScenario {
    param(
        [scriptblock]$Operation,
        [int]$ConcurrentUsers = 10,
        [int]$DurationSeconds = 60,
        [string]$TestName = "LoadTest"
    )
    
    Write-BenchmarkLog "Starting load test: $TestName ($ConcurrentUsers concurrent users, $DurationSeconds seconds)"
    
    $loadTestId = [System.Guid]::NewGuid().ToString().Substring(0, 8)
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($DurationSeconds)
    $runspaces = @()
    
    # Create runspace pool
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $ConcurrentUsers)
    $runspacePool.Open()
    
    try {
        # Start concurrent operations
        for ($i = 1; $i -le $ConcurrentUsers; $i++) {
            $runspace = [powershell]::Create()
            $runspace.RunspacePool = $runspacePool
            
            $runspace.AddScript({
                param($Operation, $EndTime, $UserId)
                
                $userResults = @()
                $operationCount = 0
                
                while ((Get-Date) -lt $EndTime) {
                    $operationStart = Get-Date
                    try {
                        $result = & $Operation
                        $success = $true
                        $error = $null
                    } catch {
                        $result = $null
                        $success = $false
                        $error = $_.Exception.Message
                    }
                    $operationEnd = Get-Date
                    
                    $userResults += @{
                        UserId = $UserId
                        OperationNumber = ++$operationCount
                        StartTime = $operationStart
                        EndTime = $operationEnd
                        Duration = ($operationEnd - $operationStart).TotalMilliseconds
                        Success = $success
                        Error = $error
                        Result = $result
                    }
                    
                    Start-Sleep -Milliseconds 10
                }
                
                return @{
                    UserId = $UserId
                    OperationCount = $operationCount
                    Results = $userResults
                }
            }).AddArgument($Operation).AddArgument($endTime).AddArgument($i) | Out-Null
            
            $runspaces += @{
                Runspace = $runspace
                Handle = $runspace.BeginInvoke()
                UserId = $i
            }
        }
        
        # Monitor progress
        $progressUpdateInterval = 5
        $lastUpdate = Get-Date
        
        while ((Get-Date) -lt $endTime) {
            $now = Get-Date
            if (($now - $lastUpdate).TotalSeconds -ge $progressUpdateInterval) {
                $elapsed = ($now - $startTime).TotalSeconds
                $remaining = ($endTime - $now).TotalSeconds
                Write-Progress -Activity "Load Test: $TestName" -Status "$ConcurrentUsers users, $([math]::Round($elapsed, 1))s elapsed, $([math]::Round($remaining, 1))s remaining" -PercentComplete (($elapsed / $DurationSeconds) * 100)
                $lastUpdate = $now
            }
            Start-Sleep -Milliseconds 500
        }
        
        Write-Progress -Activity "Load Test: $TestName" -Status "Collecting results..." -PercentComplete 100
        
        # Wait for completion and collect results
        $operations = @()
        foreach ($runspaceInfo in $runspaces) {
            $result = $runspaceInfo.Runspace.EndInvoke($runspaceInfo.Handle)
            $operations += $result
            $runspaceInfo.Runspace.Dispose()
        }
        
    } finally {
        $runspacePool.Close()
        $runspacePool.Dispose()
        Write-Progress -Activity "Load Test: $TestName" -Completed
    }
    
    $actualEndTime = Get-Date
    $actualDuration = ($actualEndTime - $startTime).TotalSeconds
    
    # Analyze results
    $allOperationResults = $operations | ForEach-Object { $_.Results }
    $totalOperations = ($operations | Measure-Object -Property OperationCount -Sum).Sum
    $successfulOperations = ($allOperationResults | Where-Object { $_.Success }).Count
    $failedOperations = $totalOperations - $successfulOperations
    
    $durations = $allOperationResults | ForEach-Object { $_.Duration }
    $averageResponseTime = if ($durations.Count -gt 0) { ($durations | Measure-Object -Average).Average } else { 0 }
    $p95ResponseTime = if ($durations.Count -gt 0) { ($durations | Sort-Object)[[math]::Floor($durations.Count * 0.95)] } else { 0 }
    $throughput = if ($actualDuration -gt 0) { $totalOperations / $actualDuration } else { 0 }
    
    $loadTestResult = @{
        LoadTestId = $loadTestId
        TestName = $TestName
        StartTime = $startTime
        EndTime = $actualEndTime
        PlannedDuration = $DurationSeconds
        ActualDuration = $actualDuration
        ConcurrentUsers = $ConcurrentUsers
        TotalOperations = $totalOperations
        SuccessfulOperations = $successfulOperations
        FailedOperations = $failedOperations
        SuccessRate = if ($totalOperations -gt 0) { $successfulOperations / $totalOperations } else { 0 }
        AverageResponseTime = $averageResponseTime
        P95ResponseTime = $p95ResponseTime
        Throughput = $throughput
        Operations = $operations
        AllResults = $allOperationResults
    }
    
    $script:BenchmarkResults.LoadTestResults += $loadTestResult
    
    Write-BenchmarkLog "Completed load test: $TestName" -Level SUCCESS
    Write-BenchmarkLog "  Total Operations: $totalOperations" -Level INFO
    Write-BenchmarkLog "  Success Rate: $([math]::Round($loadTestResult.SuccessRate * 100, 2))%" -Level INFO
    Write-BenchmarkLog "  Throughput: $([math]::Round($throughput, 2)) ops/sec" -Level INFO
    Write-BenchmarkLog "  Average Response Time: $([math]::Round($averageResponseTime, 2))ms" -Level INFO
    Write-BenchmarkLog "  P95 Response Time: $([math]::Round($p95ResponseTime, 2))ms" -Level INFO
    
    return $loadTestResult
}

# ==============================================================================
# DOMAIN VS MODULE LOADING BENCHMARKS
# ==============================================================================

function Test-DomainVsModulePerformance {
    Write-BenchmarkLog "=== DOMAIN VS MODULE LOADING PERFORMANCE ===" -Level INFO
    
    # Test 1: Domain Loading Performance
    $domainLoadingTest = Invoke-BenchmarkTest -TestName "DomainLoading" -Iterations $Iterations -ExpectedLimits @{
        MaxDuration = 15000  # 15 seconds
        MaxMemory = 100      # 100MB
        MaxCpu = 10000      # 10 seconds CPU time
    } -TestBlock {
        # Import AitherCore with domain loading
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        # Initialize with domain loading
        $result = Initialize-CoreApplication -RequiredOnly:$false -Force:$true
        
        # Get loaded components status
        $status = Get-CoreModuleStatus
        $domainCount = ($status | Where-Object { $_.Type -eq 'Domain' -and $_.Loaded }).Count
        $moduleCount = ($status | Where-Object { $_.Type -eq 'Module' -and $_.Loaded }).Count
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result
            DomainsLoaded = $domainCount
            ModulesLoaded = $moduleCount
            TotalComponents = $domainCount + $moduleCount
        }
    }
    
    # Test 2: Traditional Module Loading Performance
    $moduleLoadingTest = Invoke-BenchmarkTest -TestName "TraditionalModuleLoading" -Iterations $Iterations -ExpectedLimits @{
        MaxDuration = 20000  # 20 seconds (expected to be slower)
        MaxMemory = 120      # 120MB
        MaxCpu = 12000      # 12 seconds CPU time
    } -TestBlock {
        # Load modules individually (traditional approach)
        $moduleNames = @(
            "Logging",
            "BackupManager", 
            "ConfigurationCore",
            "AIToolsIntegration",
            "ConfigurationCarousel",
            "DevEnvironment",
            "PatchManager",
            "TestingFramework",
            "ParallelExecution",
            "ProgressTracking"
        )
        
        $loadedModules = 0
        foreach ($moduleName in $moduleNames) {
            $modulePath = Join-Path $ProjectRoot "aither-core/modules/$moduleName"
            if (Test-Path $modulePath) {
                try {
                    Import-Module $modulePath -Force -Global -ErrorAction Stop
                    $loadedModules++
                } catch {
                    # Continue with other modules
                }
            }
        }
        
        # Clean up
        Get-Module | Where-Object { $_.Name -in $moduleNames } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $loadedModules -gt 0
            ModulesLoaded = $loadedModules
            TotalAttempted = $moduleNames.Count
        }
    }
    
    # Test 3: Parallel Module Loading Performance
    $parallelLoadingTest = Invoke-BenchmarkTest -TestName "ParallelModuleLoading" -Iterations $Iterations -ExpectedLimits @{
        MaxDuration = 12000  # 12 seconds (should be faster)
        MaxMemory = 110      # 110MB
        MaxCpu = 15000      # 15 seconds CPU time (higher due to parallelism)
    } -TestBlock {
        # Import AitherCore
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        # Use parallel loading
        $parallelImportPath = Join-Path $ProjectRoot "aither-core/Private/Import-CoreModulesParallel.ps1"
        if (Test-Path $parallelImportPath) {
            . $parallelImportPath
            $result = Import-CoreModulesParallel -RequiredOnly:$false -Force:$true
        } else {
            # Fallback to standard import
            $result = Import-CoreModules -RequiredOnly:$false -Force:$true
        }
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result.ImportedCount -gt 0
            ImportedCount = $result.ImportedCount
            FailedCount = $result.FailedCount
            SkippedCount = $result.SkippedCount
            Duration = $result.Duration
        }
    }
    
    # Compare results
    Write-BenchmarkLog "=== DOMAIN VS MODULE LOADING COMPARISON ===" -Level SUCCESS
    Write-BenchmarkLog "Domain Loading:" -Level INFO
    Write-BenchmarkLog "  Average Duration: $([math]::Round($domainLoadingTest.AverageDuration, 2))ms" -Level INFO
    Write-BenchmarkLog "  Average Memory: $([math]::Round($domainLoadingTest.AverageMemoryUsage, 2))MB" -Level INFO
    Write-BenchmarkLog "  Success Rate: $([math]::Round($domainLoadingTest.SuccessRate * 100, 2))%" -Level INFO
    
    Write-BenchmarkLog "Traditional Module Loading:" -Level INFO
    Write-BenchmarkLog "  Average Duration: $([math]::Round($moduleLoadingTest.AverageDuration, 2))ms" -Level INFO
    Write-BenchmarkLog "  Average Memory: $([math]::Round($moduleLoadingTest.AverageMemoryUsage, 2))MB" -Level INFO
    Write-BenchmarkLog "  Success Rate: $([math]::Round($moduleLoadingTest.SuccessRate * 100, 2))%" -Level INFO
    
    Write-BenchmarkLog "Parallel Module Loading:" -Level INFO
    Write-BenchmarkLog "  Average Duration: $([math]::Round($parallelLoadingTest.AverageDuration, 2))ms" -Level INFO
    Write-BenchmarkLog "  Average Memory: $([math]::Round($parallelLoadingTest.AverageMemoryUsage, 2))MB" -Level INFO
    Write-BenchmarkLog "  Success Rate: $([math]::Round($parallelLoadingTest.SuccessRate * 100, 2))%" -Level INFO
    
    # Performance comparison
    $domainVsModule = @{
        DomainFasterThanTraditional = $domainLoadingTest.AverageDuration -lt $moduleLoadingTest.AverageDuration
        DomainVsTraditionalSpeedup = if ($moduleLoadingTest.AverageDuration -gt 0) { $moduleLoadingTest.AverageDuration / $domainLoadingTest.AverageDuration } else { 0 }
        ParallelFasterThanDomain = $parallelLoadingTest.AverageDuration -lt $domainLoadingTest.AverageDuration
        ParallelVsDomainSpeedup = if ($domainLoadingTest.AverageDuration -gt 0) { $domainLoadingTest.AverageDuration / $parallelLoadingTest.AverageDuration } else { 0 }
        DomainMemoryEfficiency = $domainLoadingTest.AverageMemoryUsage -lt $moduleLoadingTest.AverageMemoryUsage
        MemorySavings = $moduleLoadingTest.AverageMemoryUsage - $domainLoadingTest.AverageMemoryUsage
    }
    
    Write-BenchmarkLog "=== PERFORMANCE ANALYSIS ===" -Level SUCCESS
    Write-BenchmarkLog "Domain vs Traditional: $($domainVsModule.DomainFasterThanTraditional)" -Level INFO
    Write-BenchmarkLog "Domain Speedup: $([math]::Round($domainVsModule.DomainVsTraditionalSpeedup, 2))x" -Level INFO
    Write-BenchmarkLog "Parallel vs Domain: $($domainVsModule.ParallelFasterThanDomain)" -Level INFO
    Write-BenchmarkLog "Parallel Speedup: $([math]::Round($domainVsModule.ParallelVsDomainSpeedup, 2))x" -Level INFO
    Write-BenchmarkLog "Domain Memory Efficiency: $($domainVsModule.DomainMemoryEfficiency)" -Level INFO
    Write-BenchmarkLog "Memory Savings: $([math]::Round($domainVsModule.MemorySavings, 2))MB" -Level INFO
    
    return @{
        DomainLoading = $domainLoadingTest
        TraditionalLoading = $moduleLoadingTest
        ParallelLoading = $parallelLoadingTest
        Comparison = $domainVsModule
    }
}

# ==============================================================================
# STARTUP TIME ANALYSIS
# ==============================================================================

function Test-StartupTimeAnalysis {
    Write-BenchmarkLog "=== STARTUP TIME ANALYSIS ===" -Level INFO
    
    # Test different startup profiles
    $profiles = @(
        @{ Name = "Minimal"; RequiredOnly = $true; Description = "Required modules only" },
        @{ Name = "Standard"; RequiredOnly = $false; Description = "All available modules" },
        @{ Name = "Full"; RequiredOnly = $false; Description = "All modules with parallel loading" }
    )
    
    $startupResults = @{}
    
    foreach ($profile in $profiles) {
        Write-BenchmarkLog "Testing startup profile: $($profile.Name)" -Level INFO
        
        $startupTest = Invoke-BenchmarkTest -TestName "Startup-$($profile.Name)" -Iterations $Iterations -ExpectedLimits @{
            MaxDuration = if ($profile.Name -eq "Minimal") { 8000 } elseif ($profile.Name -eq "Standard") { 15000 } else { 12000 }
            MaxMemory = if ($profile.Name -eq "Minimal") { 50 } elseif ($profile.Name -eq "Standard") { 100 } else { 110 }
        } -TestBlock {
            $startupStart = Get-Date
            
            # Import AitherCore
            $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
            Import-Module $aitherCorePath -Force -Global
            
            # Initialize based on profile
            if ($profile.Name -eq "Full") {
                # Use parallel loading for full profile
                $parallelImportPath = Join-Path $ProjectRoot "aither-core/Private/Import-CoreModulesParallel.ps1"
                if (Test-Path $parallelImportPath) {
                    . $parallelImportPath
                    $result = Import-CoreModulesParallel -RequiredOnly:$profile.RequiredOnly -Force:$true
                } else {
                    $result = Initialize-CoreApplication -RequiredOnly:$profile.RequiredOnly -Force:$true
                }
            } else {
                $result = Initialize-CoreApplication -RequiredOnly:$profile.RequiredOnly -Force:$true
            }
            
            $startupEnd = Get-Date
            $startupDuration = ($startupEnd - $startupStart).TotalMilliseconds
            
            # Get status
            $status = Get-CoreModuleStatus
            $loadedCount = ($status | Where-Object { $_.Loaded }).Count
            
            # Clean up
            Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
            
            return @{
                Success = $result
                StartupDuration = $startupDuration
                LoadedComponents = $loadedCount
                Profile = $profile.Name
            }
        }
        
        $startupResults[$profile.Name] = $startupTest
    }
    
    # Compare startup times
    Write-BenchmarkLog "=== STARTUP TIME COMPARISON ===" -Level SUCCESS
    foreach ($profile in $profiles) {
        $result = $startupResults[$profile.Name]
        Write-BenchmarkLog "$($profile.Name) Profile:" -Level INFO
        Write-BenchmarkLog "  Average Duration: $([math]::Round($result.AverageDuration, 2))ms" -Level INFO
        Write-BenchmarkLog "  P95 Duration: $([math]::Round($result.P95Duration, 2))ms" -Level INFO
        Write-BenchmarkLog "  Average Memory: $([math]::Round($result.AverageMemoryUsage, 2))MB" -Level INFO
        Write-BenchmarkLog "  Success Rate: $([math]::Round($result.SuccessRate * 100, 2))%" -Level INFO
    }
    
    return $startupResults
}

# ==============================================================================
# MEMORY USAGE AND LEAK DETECTION
# ==============================================================================

function Test-MemoryUsageAnalysis {
    Write-BenchmarkLog "=== MEMORY USAGE ANALYSIS ===" -Level INFO
    
    # Test 1: Memory usage during normal operations
    $memoryUsageTest = Invoke-BenchmarkTest -TestName "MemoryUsage" -Iterations $Iterations -ExpectedLimits @{
        MaxMemory = 200  # 200MB
        MaxHandles = 100 # 100 handles
    } -TestBlock {
        $memoryStart = [System.GC]::GetTotalMemory($false)
        
        # Import AitherCore
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        # Initialize with various operations
        $result = Initialize-CoreApplication -RequiredOnly:$false -Force:$true
        
        # Simulate various operations
        $status = Get-CoreModuleStatus
        $toolset = Get-IntegratedToolset
        
        # Test configuration operations if available
        if (Get-Command Get-CoreConfiguration -ErrorAction SilentlyContinue) {
            try {
                $config = Get-CoreConfiguration
            } catch {
                # Ignore if config not available
            }
        }
        
        $memoryEnd = [System.GC]::GetTotalMemory($false)
        $memoryUsed = ($memoryEnd - $memoryStart) / 1MB
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result
            MemoryUsed = $memoryUsed
            ComponentsLoaded = $status.Count
            ToolsetComponents = $toolset.CoreModules.Count
        }
    }
    
    # Test 2: Memory leak detection
    if ($MemoryProfiler) {
        Write-BenchmarkLog "Running memory leak detection..." -Level INFO
        
        $memoryLeakTest = Invoke-BenchmarkTest -TestName "MemoryLeakDetection" -Iterations ($Iterations * 2) -TestBlock {
            $memoryBefore = [System.GC]::GetTotalMemory($true)
            
            # Repeated load/unload cycles
            for ($i = 1; $i -le 5; $i++) {
                # Import AitherCore
                $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
                Import-Module $aitherCorePath -Force -Global
                
                # Initialize
                $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
                
                # Clean up
                Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
                
                # Force garbage collection
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
            }
            
            $memoryAfter = [System.GC]::GetTotalMemory($true)
            $memoryLeak = ($memoryAfter - $memoryBefore) / 1MB
            
            return @{
                Success = $result
                MemoryLeak = $memoryLeak
                Cycles = 5
            }
        }
        
        $script:BenchmarkResults.MemoryProfiles += $memoryLeakTest
    }
    
    return @{
        MemoryUsage = $memoryUsageTest
        MemoryLeak = if ($MemoryProfiler) { $memoryLeakTest } else { $null }
    }
}

# ==============================================================================
# CONCURRENT OPERATIONS AND LOAD TESTING
# ==============================================================================

function Test-ConcurrentOperations {
    Write-BenchmarkLog "=== CONCURRENT OPERATIONS TESTING ===" -Level INFO
    
    # Test 1: Concurrent module loading
    $concurrentLoadTest = Start-LoadTestScenario -TestName "ConcurrentModuleLoading" -ConcurrentUsers $ConcurrentUsers -DurationSeconds ($TestDuration / 2) -Operation {
        # Import AitherCore
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        # Initialize
        $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
        
        # Get random status
        $status = Get-CoreModuleStatus
        $randomModule = $status | Get-Random
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result
            RandomModule = $randomModule.Name
            LoadedCount = $status.Count
        }
    }
    
    # Test 2: Concurrent configuration operations
    $concurrentConfigTest = Start-LoadTestScenario -TestName "ConcurrentConfigOperations" -ConcurrentUsers ($ConcurrentUsers / 2) -DurationSeconds ($TestDuration / 2) -Operation {
        # Import AitherCore
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        # Initialize
        $result = Initialize-CoreApplication -RequiredOnly:$false -Force:$true
        
        # Test various operations
        $operations = @()
        
        # Get module status
        if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
            $status = Get-CoreModuleStatus
            $operations += "GetStatus"
        }
        
        # Get toolset
        if (Get-Command Get-IntegratedToolset -ErrorAction SilentlyContinue) {
            $toolset = Get-IntegratedToolset
            $operations += "GetToolset"
        }
        
        # Test health
        if (Get-Command Test-CoreApplicationHealth -ErrorAction SilentlyContinue) {
            $health = Test-CoreApplicationHealth
            $operations += "TestHealth"
        }
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result
            Operations = $operations
            OperationCount = $operations.Count
        }
    }
    
    return @{
        ConcurrentLoading = $concurrentLoadTest
        ConcurrentOperations = $concurrentConfigTest
    }
}

# ==============================================================================
# PERFORMANCE REGRESSION ANALYSIS
# ==============================================================================

function Test-PerformanceRegression {
    Write-BenchmarkLog "=== PERFORMANCE REGRESSION ANALYSIS ===" -Level INFO
    
    # Define performance baseline targets
    $baselineTargets = @{
        DomainLoadingTime = 15000    # 15 seconds max
        MemoryUsage = 100           # 100MB max
        StartupTime = 12000         # 12 seconds max
        ConcurrentThroughput = 5    # 5 ops/sec min
    }
    
    $regressionTests = @()
    
    # Test 1: Domain loading regression
    $domainRegressionTest = Invoke-BenchmarkTest -TestName "DomainLoadingRegression" -Iterations 5 -ExpectedLimits @{
        MaxDuration = $baselineTargets.DomainLoadingTime
        MaxMemory = $baselineTargets.MemoryUsage
    } -TestBlock {
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        $result = Initialize-CoreApplication -RequiredOnly:$false -Force:$true
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result
            Regression = "None"
        }
    }
    
    $regressionTests += @{
        TestName = "DomainLoadingRegression"
        Result = $domainRegressionTest
        Baseline = $baselineTargets.DomainLoadingTime
        Passed = $domainRegressionTest.AverageDuration -le $baselineTargets.DomainLoadingTime
    }
    
    # Test 2: Memory usage regression
    $memoryRegressionTest = Invoke-BenchmarkTest -TestName "MemoryUsageRegression" -Iterations 5 -ExpectedLimits @{
        MaxMemory = $baselineTargets.MemoryUsage
    } -TestBlock {
        $memoryStart = [System.GC]::GetTotalMemory($true)
        
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global
        
        $result = Initialize-CoreApplication -RequiredOnly:$false -Force:$true
        
        $status = Get-CoreModuleStatus
        $toolset = Get-IntegratedToolset
        
        $memoryEnd = [System.GC]::GetTotalMemory($false)
        $memoryUsed = ($memoryEnd - $memoryStart) / 1MB
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $result
            MemoryUsed = $memoryUsed
            ComponentsLoaded = $status.Count
        }
    }
    
    $regressionTests += @{
        TestName = "MemoryUsageRegression"
        Result = $memoryRegressionTest
        Baseline = $baselineTargets.MemoryUsage
        Passed = $memoryRegressionTest.AverageMemoryUsage -le $baselineTargets.MemoryUsage
    }
    
    $script:BenchmarkResults.RegressionTests = $regressionTests
    
    Write-BenchmarkLog "=== REGRESSION TEST RESULTS ===" -Level SUCCESS
    foreach ($test in $regressionTests) {
        $status = if ($test.Passed) { "PASSED" } else { "FAILED" }
        $statusColor = if ($test.Passed) { "SUCCESS" } else { "ERROR" }
        Write-BenchmarkLog "$($test.TestName): $status" -Level $statusColor
    }
    
    return $regressionTests
}

# ==============================================================================
# BASELINE MANAGEMENT
# ==============================================================================

function Save-PerformanceBaseline {
    $baselinePath = Join-Path $ProjectRoot "tests/performance/baseline.json"
    
    # Create baseline from current results
    $baseline = @{
        CreatedDate = Get-Date
        SystemInfo = $script:BenchmarkResults.SystemInfo
        BaselineMetrics = @{
            DomainLoadingTime = if ($script:BenchmarkResults.TestResults) { 
                ($script:BenchmarkResults.TestResults | Where-Object { $_.TestName -eq "DomainLoading" }).AverageDuration 
            } else { 15000 }
            MemoryUsage = if ($script:BenchmarkResults.TestResults) { 
                ($script:BenchmarkResults.TestResults | Where-Object { $_.TestName -eq "MemoryUsage" }).AverageMemoryUsage 
            } else { 100 }
            StartupTime = if ($script:BenchmarkResults.TestResults) { 
                ($script:BenchmarkResults.TestResults | Where-Object { $_.TestName -like "Startup-*" }).AverageDuration | Measure-Object -Average
            } else { 12000 }
        }
        TestResults = $script:BenchmarkResults.TestResults
    }
    
    $baseline | ConvertTo-Json -Depth 10 | Set-Content -Path $baselinePath
    Write-BenchmarkLog "Performance baseline saved to: $baselinePath" -Level SUCCESS
}

function Compare-ToBaseline {
    $baselinePath = Join-Path $ProjectRoot "tests/performance/baseline.json"
    
    if (-not (Test-Path $baselinePath)) {
        Write-BenchmarkLog "No baseline found at: $baselinePath" -Level WARNING
        return $null
    }
    
    $baseline = Get-Content $baselinePath | ConvertFrom-Json
    
    Write-BenchmarkLog "=== BASELINE COMPARISON ===" -Level INFO
    Write-BenchmarkLog "Baseline Created: $($baseline.CreatedDate)" -Level INFO
    Write-BenchmarkLog "Baseline System: $($baseline.SystemInfo.OS)" -Level INFO
    
    # Compare key metrics
    $currentDomainTime = ($script:BenchmarkResults.TestResults | Where-Object { $_.TestName -eq "DomainLoading" }).AverageDuration
    $baselineDomainTime = $baseline.BaselineMetrics.DomainLoadingTime
    
    if ($currentDomainTime -and $baselineDomainTime) {
        $domainTimeChange = (($currentDomainTime - $baselineDomainTime) / $baselineDomainTime) * 100
        Write-BenchmarkLog "Domain Loading Time Change: $([math]::Round($domainTimeChange, 2))%" -Level INFO
    }
    
    return @{
        Baseline = $baseline
        CurrentResults = $script:BenchmarkResults
        Comparison = @{
            DomainTimeChange = $domainTimeChange
        }
    }
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

try {
    # Execute based on benchmark mode
    switch ($BenchmarkMode) {
        'All' {
            $domainVsModuleResults = Test-DomainVsModulePerformance
            $startupResults = Test-StartupTimeAnalysis
            $memoryResults = Test-MemoryUsageAnalysis
            $concurrentResults = Test-ConcurrentOperations
            $regressionResults = Test-PerformanceRegression
        }
        'DomainVsModule' {
            $domainVsModuleResults = Test-DomainVsModulePerformance
        }
        'Memory' {
            $memoryResults = Test-MemoryUsageAnalysis
        }
        'Startup' {
            $startupResults = Test-StartupTimeAnalysis
        }
        'Concurrent' {
            $concurrentResults = Test-ConcurrentOperations
        }
        'LoadTest' {
            $concurrentResults = Test-ConcurrentOperations
        }
        'Regression' {
            $regressionResults = Test-PerformanceRegression
        }
    }
    
    # Save baseline if requested
    if ($CreateBaseline) {
        Save-PerformanceBaseline
    }
    
    # Compare to baseline if requested
    if ($CompareToBaseline) {
        $baselineComparison = Compare-ToBaseline
    }
    
    # Generate final report
    $script:BenchmarkResults.EndTime = Get-Date
    $script:BenchmarkResults.TotalDuration = ($script:BenchmarkResults.EndTime - $script:BenchmarkResults.StartTime).TotalSeconds
    
    Write-BenchmarkLog "=== BENCHMARK COMPLETION ===" -Level SUCCESS
    Write-BenchmarkLog "Total Duration: $([math]::Round($script:BenchmarkResults.TotalDuration, 2)) seconds" -Level INFO
    Write-BenchmarkLog "Tests Executed: $($script:BenchmarkResults.TestResults.Count)" -Level INFO
    Write-BenchmarkLog "Load Tests: $($script:BenchmarkResults.LoadTestResults.Count)" -Level INFO
    
    # Save detailed results
    if ($DetailedOutput) {
        $resultsPath = Join-Path $ProjectRoot "tests/performance/benchmark-results-$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').json"
        $script:BenchmarkResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath
        Write-BenchmarkLog "Detailed results saved to: $resultsPath" -Level SUCCESS
    }
    
    # Performance summary
    $successfulTests = $script:BenchmarkResults.TestResults | Where-Object { $_.SuccessRate -gt 0.9 }
    $performanceMetrics = @{
        OverallSuccess = ($successfulTests.Count / $script:BenchmarkResults.TestResults.Count) * 100
        AverageTestDuration = ($script:BenchmarkResults.TestResults | Measure-Object -Property AverageDuration -Average).Average
        AverageMemoryUsage = ($script:BenchmarkResults.TestResults | Measure-Object -Property AverageMemoryUsage -Average).Average
        TotalLoadTestOperations = ($script:BenchmarkResults.LoadTestResults | Measure-Object -Property TotalOperations -Sum).Sum
        AverageLoadTestThroughput = ($script:BenchmarkResults.LoadTestResults | Measure-Object -Property Throughput -Average).Average
    }
    
    Write-BenchmarkLog "=== PERFORMANCE SUMMARY ===" -Level SUCCESS
    Write-BenchmarkLog "Overall Success Rate: $([math]::Round($performanceMetrics.OverallSuccess, 2))%" -Level INFO
    Write-BenchmarkLog "Average Test Duration: $([math]::Round($performanceMetrics.AverageTestDuration, 2))ms" -Level INFO
    Write-BenchmarkLog "Average Memory Usage: $([math]::Round($performanceMetrics.AverageMemoryUsage, 2))MB" -Level INFO
    
    if ($script:BenchmarkResults.LoadTestResults.Count -gt 0) {
        Write-BenchmarkLog "Total Load Test Operations: $($performanceMetrics.TotalLoadTestOperations)" -Level INFO
        Write-BenchmarkLog "Average Load Test Throughput: $([math]::Round($performanceMetrics.AverageLoadTestThroughput, 2)) ops/sec" -Level INFO
    }
    
    # Performance verdict
    $overallPerformanceGood = $performanceMetrics.OverallSuccess -ge 80 -and 
                             $performanceMetrics.AverageTestDuration -le 20000 -and
                             $performanceMetrics.AverageMemoryUsage -le 150
    
    if ($overallPerformanceGood) {
        Write-BenchmarkLog "✅ PERFORMANCE VERDICT: ACCEPTABLE" -Level SUCCESS
        Write-BenchmarkLog "Domain architecture performance is within acceptable limits" -Level SUCCESS
    } else {
        Write-BenchmarkLog "❌ PERFORMANCE VERDICT: NEEDS OPTIMIZATION" -Level ERROR
        Write-BenchmarkLog "Domain architecture requires performance optimization" -Level ERROR
    }
    
} catch {
    Write-BenchmarkLog "Benchmark execution failed: $($_.Exception.Message)" -Level ERROR
    Write-BenchmarkLog "Stack trace: $($_.Exception.StackTrace)" -Level ERROR
    exit 1
}

Write-BenchmarkLog "🎯 Performance benchmark completed successfully!" -Level SUCCESS