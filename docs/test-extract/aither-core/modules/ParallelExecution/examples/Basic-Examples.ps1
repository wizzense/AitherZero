#Requires -Version 7.0

<#
.SYNOPSIS
    Basic examples demonstrating ParallelExecution module capabilities
    
.DESCRIPTION
    This script provides practical examples of using the ParallelExecution module
    for common scenarios including file processing, data transformation, and
    performance optimization.
    
.EXAMPLE
    .\Basic-Examples.ps1
#>

# Import the ParallelExecution module
$ModulePath = Join-Path $PSScriptRoot ".."
Import-Module $ModulePath -Force

Write-Host "=== ParallelExecution Module Examples ===" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic Parallel ForEach
Write-Host "Example 1: Basic Parallel Processing" -ForegroundColor Green
Write-Host "Processing numbers 1-10 in parallel..." -ForegroundColor Gray

$numbers = 1..10
$results = Invoke-ParallelForEach -InputObject $numbers -ScriptBlock {
    param($number)
    # Simulate some work
    Start-Sleep -Milliseconds 100
    return $number * $number
} -ThrottleLimit 4

Write-Host "Results: $($results -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Example 2: Optimal Throttle Calculation
Write-Host "Example 2: Optimal Throttle Calculation" -ForegroundColor Green

$cpuOptimal = Get-OptimalThrottleLimit -WorkloadType "CPU"
$ioOptimal = Get-OptimalThrottleLimit -WorkloadType "IO"
$networkOptimal = Get-OptimalThrottleLimit -WorkloadType "Network" -MaxLimit 10

Write-Host "CPU-optimal throttle: $cpuOptimal" -ForegroundColor Yellow
Write-Host "I/O-optimal throttle: $ioOptimal" -ForegroundColor Yellow
Write-Host "Network-optimal throttle: $networkOptimal" -ForegroundColor Yellow
Write-Host ""

# Example 3: File Processing Simulation
Write-Host "Example 3: File Processing Simulation" -ForegroundColor Green
Write-Host "Simulating processing of multiple files..." -ForegroundColor Gray

# Create mock file objects
$mockFiles = 1..20 | ForEach-Object {
    [PSCustomObject]@{
        Name = "file$_.txt"
        Size = Get-Random -Minimum 1000 -Maximum 10000
        Path = "/temp/file$_.txt"
    }
}

$fileResults = Invoke-ParallelForEach -InputObject $mockFiles -ScriptBlock {
    param($file)
    
    # Simulate file processing
    Start-Sleep -Milliseconds (Get-Random -Minimum 50 -Maximum 200)
    
    return [PSCustomObject]@{
        FileName = $file.Name
        OriginalSize = $file.Size
        ProcessedSize = $file.Size * 1.1
        ProcessingTime = (Get-Random -Minimum 50 -Maximum 200)
        Success = $true
    }
} -ThrottleLimit $ioOptimal

$totalProcessed = $fileResults.Count
$avgProcessingTime = ($fileResults.ProcessingTime | Measure-Object -Average).Average
Write-Host "Processed $totalProcessed files with average processing time of $([Math]::Round($avgProcessingTime, 1))ms" -ForegroundColor Yellow
Write-Host ""

# Example 4: Performance Measurement
Write-Host "Example 4: Performance Measurement" -ForegroundColor Green
Write-Host "Measuring performance of parallel operation..." -ForegroundColor Gray

$items = 1..50
$startTime = Get-Date

$perfResults = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
    param($item)
    # CPU-intensive operation
    $sum = 0
    for ($i = 1; $i -le 1000; $i++) {
        $sum += [Math]::Sqrt($i * $item)
    }
    return @{ Item = $item; Result = $sum }
} -ThrottleLimit $cpuOptimal

$endTime = Get-Date
$metrics = Measure-ParallelPerformance -OperationName "CPUIntensive" -StartTime $startTime -EndTime $endTime -ItemCount $items.Count -ThrottleLimit $cpuOptimal

Write-Host "Performance Metrics:" -ForegroundColor Yellow
Write-Host "  Duration: $($metrics.Duration)" -ForegroundColor Gray
Write-Host "  Throughput: $($metrics.ThroughputPerSecond) items/sec" -ForegroundColor Gray
Write-Host "  Efficiency Ratio: $($metrics.EfficiencyRatio)" -ForegroundColor Gray
Write-Host "  Average Time per Item: $($metrics.AverageTimePerItem)ms" -ForegroundColor Gray
Write-Host ""

# Example 5: Background Jobs
Write-Host "Example 5: Background Job Management" -ForegroundColor Green
Write-Host "Starting multiple background jobs..." -ForegroundColor Gray

$jobs = @()
$jobs += Start-ParallelJob -Name "DataBackup" -ScriptBlock {
    # Simulate backup operation
    Start-Sleep -Seconds 2
    return "Backup completed at $(Get-Date)"
}

$jobs += Start-ParallelJob -Name "LogAnalysis" -ScriptBlock {
    # Simulate log analysis
    Start-Sleep -Seconds 1
    return "Found 42 errors in logs"
}

$jobs += Start-ParallelJob -Name "DatabaseCleanup" -ScriptBlock {
    # Simulate database cleanup
    Start-Sleep -Seconds 3
    return "Cleaned up 1,337 old records"
}

Write-Host "Waiting for jobs to complete..." -ForegroundColor Gray
$jobResults = Wait-ParallelJobs -Jobs $jobs -ShowProgress

foreach ($result in $jobResults) {
    Write-Host "Job '$($result.Name)': $($result.Result)" -ForegroundColor Yellow
}
Write-Host ""

# Example 6: Error Handling
Write-Host "Example 6: Error Handling in Parallel Operations" -ForegroundColor Green
Write-Host "Processing items with some failures..." -ForegroundColor Gray

$items = 1..15
$errorResults = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
    param($item)
    
    try {
        # Simulate random failures
        if ($item % 5 -eq 0) {
            throw "Simulated error for item $item"
        }
        
        # Successful processing
        return @{
            Item = $item
            Result = $item * 2
            Success = $true
            Error = $null
        }
    } catch {
        return @{
            Item = $item
            Result = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
} -ThrottleLimit 4 -ErrorAction SilentlyContinue

$successful = $errorResults | Where-Object { $_.Success }
$failed = $errorResults | Where-Object { -not $_.Success }

Write-Host "Successful items: $($successful.Count)" -ForegroundColor Green
Write-Host "Failed items: $($failed.Count)" -ForegroundColor Red
if ($failed.Count -gt 0) {
    Write-Host "Errors:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  Item $($_.Item): $($_.Error)" -ForegroundColor Gray }
}
Write-Host ""

# Example 7: Adaptive Execution
Write-Host "Example 7: Adaptive Parallel Execution" -ForegroundColor Green
Write-Host "Processing items with varying complexity..." -ForegroundColor Gray

$variableItems = 1..30
$adaptiveResults = Start-AdaptiveParallelExecution -InputObject $variableItems -ScriptBlock {
    param($item)
    
    # Variable complexity based on item
    if ($item % 10 -eq 0) {
        # High complexity (10% of items)
        Start-Sleep -Milliseconds 200
        $complexity = "High"
    } elseif ($item % 5 -eq 0) {
        # Medium complexity (20% of items)
        Start-Sleep -Milliseconds 100
        $complexity = "Medium"
    } else {
        # Low complexity (70% of items)
        Start-Sleep -Milliseconds 50
        $complexity = "Low"
    }
    
    return @{
        Item = $item
        Complexity = $complexity
        Result = $item * 3
    }
} -InitialThrottle 2 -MaxThrottle 6

$complexityDistribution = $adaptiveResults | Group-Object Complexity
Write-Host "Complexity Distribution:" -ForegroundColor Yellow
foreach ($group in $complexityDistribution) {
    Write-Host "  $($group.Name): $($group.Count) items" -ForegroundColor Gray
}
Write-Host ""

# Example 8: System Resource Considerations
Write-Host "Example 8: System Resource Considerations" -ForegroundColor Green

# Demonstrate different throttle strategies
$strategies = @{
    "Conservative" = Get-OptimalThrottleLimit -WorkloadType "Mixed" -SystemLoadFactor 0.5
    "Balanced" = Get-OptimalThrottleLimit -WorkloadType "Mixed" -SystemLoadFactor 0.75
    "Aggressive" = Get-OptimalThrottleLimit -WorkloadType "Mixed" -SystemLoadFactor 1.0
}

Write-Host "Throttle strategies for current system:" -ForegroundColor Yellow
foreach ($strategy in $strategies.GetEnumerator()) {
    Write-Host "  $($strategy.Key): $($strategy.Value) threads" -ForegroundColor Gray
}
Write-Host ""

Write-Host "=== Examples Complete ===" -ForegroundColor Cyan
Write-Host "The ParallelExecution module provides powerful parallel processing capabilities" -ForegroundColor Green
Write-Host "for improving performance across CPU, I/O, and mixed workloads." -ForegroundColor Green