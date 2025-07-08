#Requires -Version 7.0

<#
.SYNOPSIS
    Performance benchmarking and demonstration script for ParallelExecution module

.DESCRIPTION
    This script demonstrates the capabilities of the ParallelExecution module through
    various benchmarking scenarios including CPU-intensive, I/O-intensive, and
    mixed workloads. It shows the performance benefits of parallel execution and
    adaptive throttling.

.PARAMETER WorkloadSize
    Size of the workload for benchmarking (Small, Medium, Large)

.PARAMETER IncludeAdaptive
    Include adaptive parallel execution benchmarks

.PARAMETER IncludeOptimalCalculation
    Include optimal throttle limit calculation tests

.PARAMETER OutputPath
    Path to save benchmark results (optional)

.EXAMPLE
    .\ParallelExecution-Benchmark.ps1 -WorkloadSize Medium -IncludeAdaptive

.EXAMPLE
    .\ParallelExecution-Benchmark.ps1 -WorkloadSize Large -OutputPath ".\benchmark-results.json"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Small', 'Medium', 'Large')]
    [string]$WorkloadSize = 'Medium',

    [Parameter()]
    [switch]$IncludeAdaptive,

    [Parameter()]
    [switch]$IncludeOptimalCalculation,

    [Parameter()]
    [string]$OutputPath
)

# Import the ParallelExecution module
$ModulePath = Join-Path $PSScriptRoot ".."
Import-Module $ModulePath -Force

# Configure workload sizes
$WorkloadSizes = @{
    Small = 50
    Medium = 200
    Large = 1000
}

$ItemCount = $WorkloadSizes[$WorkloadSize]

Write-Host "=== ParallelExecution Module Benchmark ===" -ForegroundColor Cyan
Write-Host "Workload Size: $WorkloadSize ($ItemCount items)" -ForegroundColor Yellow
Write-Host "CPU Cores: $([Environment]::ProcessorCount)" -ForegroundColor Yellow
Write-Host ""

# Initialize results collection
$benchmarkResults = @{
    SystemInfo = @{
        CPUCores = [Environment]::ProcessorCount
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Platform = $PSVersionTable.Platform
        WorkloadSize = $WorkloadSize
        ItemCount = $ItemCount
        Timestamp = Get-Date
    }
    Benchmarks = @()
}

function Test-CPUIntensiveWorkload {
    param([int]$ItemCount, [int]$ThrottleLimit)

    Write-Host "Running CPU-intensive workload (throttle: $ThrottleLimit)..." -ForegroundColor Green

    $items = 1..$ItemCount
    $startTime = Get-Date

    $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
        param($item)
        # Simulate CPU-intensive work
        $sum = 0
        for ($i = 1; $i -le 1000; $i++) {
            $sum += [Math]::Sqrt($i * $item)
        }
        return @{
            Item = $item
            Result = $sum
            ProcessorId = $PID
        }
    } -ThrottleLimit $ThrottleLimit

    $endTime = Get-Date
    $metrics = Measure-ParallelPerformance -OperationName "CPU-Intensive" -StartTime $startTime -EndTime $endTime -ItemCount $ItemCount -ThrottleLimit $ThrottleLimit

    return @{
        TestType = "CPU-Intensive"
        ThrottleLimit = $ThrottleLimit
        Results = $results
        Metrics = $metrics
        UniqueProcessors = ($results.ProcessorId | Sort-Object -Unique).Count
    }
}

function Test-IOIntensiveWorkload {
    param([int]$ItemCount, [int]$ThrottleLimit)

    Write-Host "Running I/O-intensive workload (throttle: $ThrottleLimit)..." -ForegroundColor Green

    # Create temporary files for I/O operations
    $tempDir = Join-Path $env:TEMP "ParallelBenchmark"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory | Out-Null
    }

    $items = 1..$ItemCount
    $startTime = Get-Date

    $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
        param($item)
        # Simulate I/O-intensive work
        $tempFile = Join-Path $using:tempDir "temp_$item.txt"
        $content = "Item $item - " + ("x" * 1000)  # 1KB of data

        # Write and read file
        Set-Content -Path $tempFile -Value $content
        $readContent = Get-Content -Path $tempFile -Raw
        Remove-Item -Path $tempFile -ErrorAction SilentlyContinue

        return @{
            Item = $item
            ContentLength = $readContent.Length
            Success = $readContent.Contains("Item $item")
        }
    } -ThrottleLimit $ThrottleLimit

    $endTime = Get-Date
    $metrics = Measure-ParallelPerformance -OperationName "IO-Intensive" -StartTime $startTime -EndTime $endTime -ItemCount $ItemCount -ThrottleLimit $ThrottleLimit

    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    return @{
        TestType = "IO-Intensive"
        ThrottleLimit = $ThrottleLimit
        Results = $results
        Metrics = $metrics
        SuccessRate = ($results | Where-Object { $_.Success }).Count / $results.Count
    }
}

function Test-NetworkIntensiveWorkload {
    param([int]$ItemCount, [int]$ThrottleLimit)

    Write-Host "Running Network-intensive workload (throttle: $ThrottleLimit)..." -ForegroundColor Green

    # Use a reliable public API for testing
    $baseUrls = @(
        "https://httpbin.org/delay/0.1",
        "https://httpbin.org/delay/0.2",
        "https://httpbin.org/delay/0.1"
    )

    $items = 1..$ItemCount
    $startTime = Get-Date

    $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
        param($item)
        try {
            $url = $using:baseUrls[($item % $using:baseUrls.Count)]
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 10 -ErrorAction Stop

            return @{
                Item = $item
                Success = $true
                StatusCode = 200
                ResponseTime = (Get-Date)
                Url = $url
            }
        } catch {
            return @{
                Item = $item
                Success = $false
                Error = $_.Exception.Message
                Url = $url
            }
        }
    } -ThrottleLimit $ThrottleLimit

    $endTime = Get-Date
    $metrics = Measure-ParallelPerformance -OperationName "Network-Intensive" -StartTime $startTime -EndTime $endTime -ItemCount $ItemCount -ThrottleLimit $ThrottleLimit

    return @{
        TestType = "Network-Intensive"
        ThrottleLimit = $ThrottleLimit
        Results = $results
        Metrics = $metrics
        SuccessRate = ($results | Where-Object { $_.Success }).Count / $results.Count
    }
}

function Test-AdaptiveExecution {
    param([int]$ItemCount)

    Write-Host "Running Adaptive Parallel Execution test..." -ForegroundColor Green

    $items = 1..$ItemCount
    $startTime = Get-Date

    $results = Start-AdaptiveParallelExecution -InputObject $items -ScriptBlock {
        param($item)
        # Variable complexity based on item number
        if ($item % 10 -eq 0) {
            # High complexity item (10% of items)
            $sum = 0
            for ($i = 1; $i -le 2000; $i++) {
                $sum += [Math]::Sqrt($i * $item)
            }
            Start-Sleep -Milliseconds 50
        } elseif ($item % 5 -eq 0) {
            # Medium complexity item (20% of items)
            $sum = 0
            for ($i = 1; $i -le 500; $i++) {
                $sum += [Math]::Sqrt($i * $item)
            }
            Start-Sleep -Milliseconds 20
        } else {
            # Low complexity item (70% of items)
            $sum = $item * 2
            Start-Sleep -Milliseconds 5
        }

        return @{
            Item = $item
            Complexity = if ($item % 10 -eq 0) { "High" } elseif ($item % 5 -eq 0) { "Medium" } else { "Low" }
            Result = $sum
        }
    } -InitialThrottle 2 -MaxThrottle 8

    $endTime = Get-Date
    $metrics = Measure-ParallelPerformance -OperationName "Adaptive-Execution" -StartTime $startTime -EndTime $endTime -ItemCount $ItemCount -ThrottleLimit 0

    return @{
        TestType = "Adaptive-Execution"
        Results = $results
        Metrics = $metrics
        ComplexityDistribution = $results | Group-Object Complexity | ForEach-Object { @{ $_.Name = $_.Count } }
    }
}

function Test-OptimalThrottleCalculation {
    Write-Host "Testing Optimal Throttle Limit Calculation..." -ForegroundColor Green

    $workloadTypes = @('CPU', 'IO', 'Network', 'Mixed')
    $results = @{}

    foreach ($workloadType in $workloadTypes) {
        $optimal = Get-OptimalThrottleLimit -WorkloadType $workloadType
        $optimalWithLimit = Get-OptimalThrottleLimit -WorkloadType $workloadType -MaxLimit 8
        $optimalWithLoad = Get-OptimalThrottleLimit -WorkloadType $workloadType -SystemLoadFactor 0.7

        $results[$workloadType] = @{
            Standard = $optimal
            WithMaxLimit = $optimalWithLimit
            WithLoadFactor = $optimalWithLoad
        }
    }

    return @{
        TestType = "Optimal-Throttle-Calculation"
        Results = $results
        CPUCores = [Environment]::ProcessorCount
    }
}

function Compare-SequentialVsParallel {
    param([int]$ItemCount)

    Write-Host "Comparing Sequential vs Parallel Execution..." -ForegroundColor Green

    $items = 1..$ItemCount

    # Sequential execution
    Write-Host "  Running sequential execution..." -ForegroundColor Gray
    $sequentialStart = Get-Date
    $sequentialResults = foreach ($item in $items) {
        # Same workload as parallel version
        $sum = 0
        for ($i = 1; $i -le 500; $i++) {
            $sum += [Math]::Sqrt($i * $item)
        }
        @{ Item = $item; Result = $sum }
    }
    $sequentialEnd = Get-Date
    $sequentialDuration = ($sequentialEnd - $sequentialStart).TotalSeconds

    # Parallel execution
    Write-Host "  Running parallel execution..." -ForegroundColor Gray
    $parallelStart = Get-Date
    $parallelResults = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
        param($item)
        $sum = 0
        for ($i = 1; $i -le 500; $i++) {
            $sum += [Math]::Sqrt($i * $item)
        }
        @{ Item = $item; Result = $sum }
    } -ThrottleLimit ([Environment]::ProcessorCount)
    $parallelEnd = Get-Date
    $parallelDuration = ($parallelEnd - $parallelStart).TotalSeconds

    $speedup = $sequentialDuration / $parallelDuration

    return @{
        TestType = "Sequential-vs-Parallel"
        Sequential = @{
            Duration = $sequentialDuration
            ThroughputPerSecond = $ItemCount / $sequentialDuration
        }
        Parallel = @{
            Duration = $parallelDuration
            ThroughputPerSecond = $ItemCount / $parallelDuration
            ThrottleLimit = [Environment]::ProcessorCount
        }
        SpeedupFactor = $speedup
        EfficiencyPercent = ($speedup / [Environment]::ProcessorCount) * 100
    }
}

# Run benchmarks
Write-Host "Starting benchmarks..." -ForegroundColor Cyan
Write-Host ""

# 1. Sequential vs Parallel comparison
$comparisonResult = Compare-SequentialVsParallel -ItemCount $ItemCount
$benchmarkResults.Benchmarks += $comparisonResult

Write-Host "Sequential Duration: $([Math]::Round($comparisonResult.Sequential.Duration, 2))s" -ForegroundColor Yellow
Write-Host "Parallel Duration: $([Math]::Round($comparisonResult.Parallel.Duration, 2))s" -ForegroundColor Yellow
Write-Host "Speedup: $([Math]::Round($comparisonResult.SpeedupFactor, 2))x" -ForegroundColor Green
Write-Host "Efficiency: $([Math]::Round($comparisonResult.EfficiencyPercent, 1))%" -ForegroundColor Green
Write-Host ""

# 2. CPU-intensive workload with different throttle limits
$cpuThrottleLimits = @(1, 2, [Environment]::ProcessorCount, [Environment]::ProcessorCount * 2)
foreach ($throttle in $cpuThrottleLimits) {
    $cpuResult = Test-CPUIntensiveWorkload -ItemCount $ItemCount -ThrottleLimit $throttle
    $benchmarkResults.Benchmarks += $cpuResult

    Write-Host "CPU Test (Throttle $throttle): $([Math]::Round($cpuResult.Metrics.ThroughputPerSecond, 2)) items/sec" -ForegroundColor Yellow
}
Write-Host ""

# 3. I/O-intensive workload
$ioOptimal = Get-OptimalThrottleLimit -WorkloadType "IO"
$ioResult = Test-IOIntensiveWorkload -ItemCount $ItemCount -ThrottleLimit $ioOptimal
$benchmarkResults.Benchmarks += $ioResult

Write-Host "I/O Test (Throttle $ioOptimal): $([Math]::Round($ioResult.Metrics.ThroughputPerSecond, 2)) items/sec, $([Math]::Round($ioResult.SuccessRate * 100, 1))% success" -ForegroundColor Yellow
Write-Host ""

# 4. Network-intensive workload (if internet available)
try {
    $networkOptimal = Get-OptimalThrottleLimit -WorkloadType "Network" -MaxLimit 5  # Limit to be nice to test API
    $networkResult = Test-NetworkIntensiveWorkload -ItemCount ([Math]::Min($ItemCount, 20)) -ThrottleLimit $networkOptimal
    $benchmarkResults.Benchmarks += $networkResult

    Write-Host "Network Test (Throttle $networkOptimal): $([Math]::Round($networkResult.Metrics.ThroughputPerSecond, 2)) items/sec, $([Math]::Round($networkResult.SuccessRate * 100, 1))% success" -ForegroundColor Yellow
} catch {
    Write-Host "Network test skipped (no internet connection)" -ForegroundColor Gray
}
Write-Host ""

# 5. Adaptive execution (if requested)
if ($IncludeAdaptive) {
    $adaptiveResult = Test-AdaptiveExecution -ItemCount $ItemCount
    $benchmarkResults.Benchmarks += $adaptiveResult

    Write-Host "Adaptive Execution: $([Math]::Round($adaptiveResult.Metrics.ThroughputPerSecond, 2)) items/sec" -ForegroundColor Yellow
    Write-Host ""
}

# 6. Optimal throttle calculation (if requested)
if ($IncludeOptimalCalculation) {
    $optimalResult = Test-OptimalThrottleCalculation
    $benchmarkResults.Benchmarks += $optimalResult

    Write-Host "Optimal Throttle Limits:" -ForegroundColor Yellow
    foreach ($workloadType in $optimalResult.Results.Keys) {
        $limits = $optimalResult.Results[$workloadType]
        Write-Host "  $workloadType`: Standard=$($limits.Standard), MaxLimit=$($limits.WithMaxLimit), LoadFactor=$($limits.WithLoadFactor)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Generate summary
Write-Host "=== Benchmark Summary ===" -ForegroundColor Cyan

$bestCPUResult = $benchmarkResults.Benchmarks | Where-Object { $_.TestType -eq "CPU-Intensive" } | Sort-Object { $_.Metrics.ThroughputPerSecond } -Descending | Select-Object -First 1
if ($bestCPUResult) {
    Write-Host "Best CPU Performance: $([Math]::Round($bestCPUResult.Metrics.ThroughputPerSecond, 2)) items/sec (Throttle: $($bestCPUResult.ThrottleLimit))" -ForegroundColor Green
}

$overallSpeedup = $comparisonResult.SpeedupFactor
Write-Host "Overall Parallel Speedup: $([Math]::Round($overallSpeedup, 2))x" -ForegroundColor Green

$efficiency = $comparisonResult.EfficiencyPercent
Write-Host "Parallel Efficiency: $([Math]::Round($efficiency, 1))%" -ForegroundColor Green

# Save results if path provided
if ($OutputPath) {
    $benchmarkResults | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
    Write-Host "Results saved to: $OutputPath" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Benchmark completed successfully!" -ForegroundColor Green
