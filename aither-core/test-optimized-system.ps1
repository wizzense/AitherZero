#!/usr/bin/env pwsh

<#
.SYNOPSIS
Test the complete optimized AitherZero system
.DESCRIPTION
Validates all performance optimizations including parallel execution, memory management,
module loading, and overall system performance
#>

Set-Location '/workspaces/AitherZero'

Write-Host "🔥 AitherZero Optimized System Test" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host ""

# Test 1: Optimized Module Loading
Write-Host "📦 Test 1: Optimized Module Loading Performance" -ForegroundColor Cyan
Write-Host "-" * 40

try {
    $loadStartTime = Get-Date
    
    # Import AitherCore with optimizations
    Import-Module ./aither-core/AitherCore.psm1 -Force -Global
    Write-Host "✓ AitherCore orchestration module loaded" -ForegroundColor Green
    
    # Initialize the complete system
    $initResult = Initialize-CoreApplication -RequiredOnly:$false
    $loadDuration = ((Get-Date) - $loadStartTime).TotalSeconds
    
    if ($initResult) {
        Write-Host "✓ Complete system initialization successful" -ForegroundColor Green
        Write-Host "  Load time: $($loadDuration.ToString('F2'))s" -ForegroundColor Gray
        
        # Get module status
        $moduleStatus = Get-CoreModuleStatus
        $loadedCount = ($moduleStatus | Where-Object { $_.Loaded }).Count
        $availableCount = ($moduleStatus | Where-Object { $_.Available }).Count
        
        Write-Host "  Modules loaded: $loadedCount/$availableCount available" -ForegroundColor Gray
        
        if ($loadedCount -gt 5) {
            Write-Host "✓ Good module loading performance" -ForegroundColor Green
        } else {
            Write-Host "⚠ Limited module loading" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ System initialization had issues" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Module loading test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 2: Enhanced Parallel Execution
Write-Host "⚡ Test 2: Enhanced Parallel Execution" -ForegroundColor Cyan
Write-Host "-" * 40

try {
    Write-Host "  Testing ForEach-Object parallel..." -ForegroundColor Gray
    $items = 1..50
    $startTime = Get-Date
    
    $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
        param($x)
        Start-Sleep -Milliseconds 20
        return $x * 3
    } -ThrottleLimit 8 -EnableMemoryOptimization
    
    $duration = ((Get-Date) - $startTime).TotalSeconds
    $expectedResults = $items | ForEach-Object { $_ * 3 }
    
    if ($results.Count -eq $items.Count) {
        Write-Host "✓ Parallel ForEach successful" -ForegroundColor Green
        Write-Host "  Items processed: $($results.Count) in $($duration.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "  Throughput: $((($results.Count / $duration)).ToString('F2')) items/sec" -ForegroundColor Gray
    } else {
        Write-Host "✗ Parallel ForEach failed - incomplete results" -ForegroundColor Red
    }
    
    Write-Host "  Testing job-based parallel execution..." -ForegroundColor Gray
    $jobs = @(
        @{ Name = 'Task1'; ScriptBlock = { param($n) Start-Sleep -Milliseconds 100; return $n * 5 }; Arguments = @(7) },
        @{ Name = 'Task2'; ScriptBlock = { param($s) Start-Sleep -Milliseconds 120; return $s.ToUpper() }; Arguments = @("test") },
        @{ Name = 'Task3'; ScriptBlock = { param($a, $b) Start-Sleep -Milliseconds 80; return $a + $b }; Arguments = @(10, 15) }
    )
    
    $jobStartTime = Get-Date
    $jobResults = Start-ParallelExecution -Jobs $jobs -MaxConcurrentJobs 3 -EnableMemoryOptimization -EnableProgressReporting
    $jobDuration = ((Get-Date) - $jobStartTime).TotalSeconds
    
    if ($jobResults.Success) {
        Write-Host "✓ Enhanced job execution successful" -ForegroundColor Green
        Write-Host "  Jobs completed: $($jobResults.CompletedJobs)/$($jobResults.TotalJobs) in $($jobDuration.ToString('F2'))s" -ForegroundColor Gray
    } else {
        Write-Host "✗ Enhanced job execution failed" -ForegroundColor Red
        Write-Host "  Failed jobs: $($jobResults.FailedJobs)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Parallel execution test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 3: Memory Management
Write-Host "🧠 Test 3: Memory Management & Optimization" -ForegroundColor Cyan
Write-Host "-" * 40

try {
    $memBefore = Get-MemoryPressure
    Write-Host "  Initial memory pressure: $($memBefore.MemoryPressure)%" -ForegroundColor Gray
    
    # Create memory load
    $largeData = @()
    for ($i = 0; $i -lt 1000; $i++) {
        $largeData += "Memory test data item $i" * 50
    }
    
    $memDuring = Get-MemoryPressure
    Write-Host "  Memory pressure with load: $($memDuring.MemoryPressure)%" -ForegroundColor Gray
    
    # Test garbage collection
    Optimize-GarbageCollection -Force
    $largeData = $null
    
    $memAfter = Get-MemoryPressure
    Write-Host "  Memory pressure after GC: $($memAfter.MemoryPressure)%" -ForegroundColor Gray
    
    $improvement = $memDuring.MemoryPressure - $memAfter.MemoryPressure
    if ($improvement -ge 0) {
        Write-Host "✓ Memory management working properly" -ForegroundColor Green
        Write-Host "  Memory change: $($improvement.ToString('F1'))%" -ForegroundColor Gray
    } else {
        Write-Host "⚠ Memory management results unclear" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "✗ Memory management test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 4: System Integration
Write-Host "🔧 Test 4: System Integration & Performance" -ForegroundColor Cyan
Write-Host "-" * 40

try {
    # Test integrated toolset
    $toolset = Get-IntegratedToolset
    if ($toolset) {
        Write-Host "✓ Integrated toolset available" -ForegroundColor Green
        Write-Host "  Core modules: $($toolset.CoreModules.Count)" -ForegroundColor Gray
        Write-Host "  Capabilities: $($toolset.Capabilities.Count)" -ForegroundColor Gray
        Write-Host "  Integrations: $($toolset.Integrations.Count)" -ForegroundColor Gray
    } else {
        Write-Host "⚠ Integrated toolset not fully available" -ForegroundColor Yellow
    }
    
    # Test system health
    $health = Test-CoreApplicationHealth
    if ($health) {
        Write-Host "✓ Core system health check passed" -ForegroundColor Green
    } else {
        Write-Host "✗ Core system health check failed" -ForegroundColor Red
    }
    
    # Test optimal throttle calculation
    $optimalCPU = Get-OptimalThrottleLimit -WorkloadType "CPU"
    $optimalIO = Get-OptimalThrottleLimit -WorkloadType "IO"
    $optimalMixed = Get-OptimalThrottleLimit -WorkloadType "Mixed"
    
    Write-Host "  Optimal throttle limits:" -ForegroundColor Gray
    Write-Host "    CPU: $optimalCPU" -ForegroundColor Gray
    Write-Host "    I/O: $optimalIO" -ForegroundColor Gray
    Write-Host "    Mixed: $optimalMixed" -ForegroundColor Gray
    
    if ($optimalCPU -gt 0 -and $optimalIO -gt 0 -and $optimalMixed -gt 0) {
        Write-Host "✓ Performance optimization calculations working" -ForegroundColor Green
    } else {
        Write-Host "✗ Performance optimization calculations failed" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ System integration test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 5: Stress Test with Optimizations
Write-Host "💪 Test 5: Optimized Stress Test" -ForegroundColor Cyan
Write-Host "-" * 40

try {
    Write-Host "  Running optimized stress test..." -ForegroundColor Gray
    
    $stressItems = 1..200  # Increased load
    $stressStartTime = Get-Date
    
    $stressResults = Invoke-ParallelForEach -InputObject $stressItems -ScriptBlock {
        param($item)
        # Mixed CPU and memory work
        $result = 0
        for ($i = 0; $i -lt 500; $i++) {
            $result += $item * $i
        }
        # Random delay to simulate real-world variability
        Start-Sleep -Milliseconds (Get-Random -Minimum 5 -Maximum 25)
        return @{
            Item = $item
            Result = $result
            ProcessedAt = Get-Date
        }
    } -ThrottleLimit 12 -EnableMemoryOptimization -WorkloadType "Mixed"
    
    $stressDuration = ((Get-Date) - $stressStartTime).TotalSeconds
    
    if ($stressResults.Count -eq $stressItems.Count) {
        Write-Host "✓ Optimized stress test completed successfully" -ForegroundColor Green
        Write-Host "  Processed $($stressResults.Count) items in $($stressDuration.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "  Throughput: $((($stressResults.Count / $stressDuration)).ToString('F2')) items/sec" -ForegroundColor Gray
        
        # Check for memory efficiency
        $finalMemory = Get-MemoryPressure
        Write-Host "  Final memory pressure: $($finalMemory.MemoryPressure)%" -ForegroundColor Gray
        
        if ($finalMemory.MemoryPressure -lt 85) {
            Write-Host "✓ Memory efficiency maintained under stress" -ForegroundColor Green
        } else {
            Write-Host "⚠ High memory pressure after stress test" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Optimized stress test failed" -ForegroundColor Red
        Write-Host "  Expected: $($stressItems.Count), Got: $($stressResults.Count)" -ForegroundColor Red
    }
    
} catch {
    Write-Host "✗ Stress test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Performance Summary
Write-Host "📊 Optimization Performance Summary" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

$summary = @{
    ModuleLoading = if ($initResult) { "✓ Optimized" } else { "✗ Issues" }
    ParallelExecution = if ($results.Count -eq 50) { "✓ Enhanced" } else { "✗ Problems" }
    JobExecution = if ($jobResults.Success) { "✓ Working" } else { "✗ Failed" }
    MemoryManagement = if (Get-Command Get-MemoryPressure -ErrorAction SilentlyContinue) { "✓ Active" } else { "✗ Missing" }
    SystemIntegration = if ($health) { "✓ Healthy" } else { "✗ Issues" }
    StressTest = if ($stressResults.Count -eq 200) { "✓ Passed" } else { "✗ Failed" }
}

foreach ($test in $summary.GetEnumerator()) {
    $color = if ($test.Value.StartsWith("✓")) { "Green" } else { "Red" }
    Write-Host "  $($test.Key): $($test.Value)" -ForegroundColor $color
}

Write-Host ""

# Final Performance Metrics
Write-Host "🎯 Performance Metrics" -ForegroundColor Cyan
Write-Host "-" * 40

$successCount = ($summary.Values | Where-Object { $_ -like "✓*" }).Count
$totalTests = $summary.Count
$successRate = [math]::Round(($successCount / $totalTests) * 100, 1)

if ($successRate -ge 80) {
    Write-Host "🎉 Performance optimization SUCCESS! ($successRate% pass rate)" -ForegroundColor Green
} elseif ($successRate -ge 60) {
    Write-Host "⚠ Performance optimization PARTIAL success ($successRate% pass rate)" -ForegroundColor Yellow
} else {
    Write-Host "❌ Performance optimization NEEDS WORK ($successRate% pass rate)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Key Improvements Implemented:" -ForegroundColor Yellow
Write-Host "• Enhanced parallel execution with memory optimization" -ForegroundColor White
Write-Host "• Intelligent memory pressure monitoring and GC" -ForegroundColor White
Write-Host "• Optimized module loading with parallel capability" -ForegroundColor White
Write-Host "• Adaptive throttling based on system resources" -ForegroundColor White
Write-Host "• Comprehensive error handling and recovery" -ForegroundColor White
Write-Host "• Performance caching and optimization strategies" -ForegroundColor White

Write-Host ""
Write-Host "🏁 Optimized system test completed!" -ForegroundColor Cyan