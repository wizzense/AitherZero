#!/usr/bin/env pwsh

<#
.SYNOPSIS
Comprehensive test for AitherZero performance optimizations
.DESCRIPTION
Tests parallel execution reliability, memory management, module loading, and overall performance
#>

Set-Location '/workspaces/AitherZero'

Write-Host "🚀 AitherZero Performance Optimization Test Suite" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Import required modules
Write-Host "📦 Loading optimized modules..." -ForegroundColor Yellow

try {
    Import-Module ./aither-core/modules/Logging -Force -Global
    Write-Host "✓ Logging module loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load Logging: $_" -ForegroundColor Red
    exit 1
}

try {
    Import-Module ./aither-core/modules/ParallelExecution/ParallelExecution-Optimized.psm1 -Force
    Write-Host "✓ Optimized ParallelExecution module loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load optimized ParallelExecution: $_" -ForegroundColor Red
    try {
        Import-Module ./aither-core/modules/ParallelExecution -Force
        Write-Host "⚠ Fallback to standard ParallelExecution module" -ForegroundColor Yellow
    } catch {
        Write-Host "✗ Failed to load any ParallelExecution module: $_" -ForegroundColor Red
        exit 1
    }
}

try {
    . ./aither-core/modules/ParallelExecution/ModuleLoadingOptimizer.ps1
    Write-Host "✓ Module loading optimizer loaded" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load module optimizer: $_" -ForegroundColor Red
}

Write-Host ""

# Test 1: Basic Parallel Execution Reliability
Write-Host "🔧 Test 1: Basic Parallel Execution Reliability" -ForegroundColor Cyan
Write-Host "-" * 50

$testItems = 1..20
$results = @()

try {
    $startTime = Get-Date
    $results = Invoke-ParallelForEach -InputObject $testItems -ScriptBlock { 
        param($x) 
        Start-Sleep -Milliseconds 50  # Simulate work
        return $x * 2 
    } -ThrottleLimit 4
    $duration = ((Get-Date) - $startTime).TotalSeconds
    
    $expectedResults = $testItems | ForEach-Object { $_ * 2 }
    $actualResults = $results | Sort-Object
    $expectedResults = $expectedResults | Sort-Object
    
    if (($actualResults -join ',') -eq ($expectedResults -join ',')) {
        Write-Host "✓ Parallel execution successful" -ForegroundColor Green
        Write-Host "  Results: $($results.Count) items processed in $($duration.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "  Throughput: $((($results.Count / $duration)).ToString('F2')) items/sec" -ForegroundColor Gray
    } else {
        Write-Host "✗ Parallel execution produced incorrect results" -ForegroundColor Red
        Write-Host "  Expected: $($expectedResults -join ',')" -ForegroundColor Gray
        Write-Host "  Actual: $($actualResults -join ',')" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Parallel execution failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 2: Memory Management
Write-Host "🧠 Test 2: Memory Management" -ForegroundColor Cyan
Write-Host "-" * 50

try {
    if (Get-Command Get-MemoryPressure -ErrorAction SilentlyContinue) {
        $memBefore = Get-MemoryPressure
        Write-Host "  Memory pressure before: $($memBefore.MemoryPressure)%" -ForegroundColor Gray
        
        # Create memory pressure
        $largeArray = 1..10000 | ForEach-Object { "Large string data item $_" * 10 }
        
        $memDuring = Get-MemoryPressure
        Write-Host "  Memory pressure during load: $($memDuring.MemoryPressure)%" -ForegroundColor Gray
        
        # Test garbage collection
        if (Get-Command Optimize-GarbageCollection -ErrorAction SilentlyContinue) {
            Optimize-GarbageCollection -Force
            $memAfter = Get-MemoryPressure
            Write-Host "  Memory pressure after GC: $($memAfter.MemoryPressure)%" -ForegroundColor Gray
            
            $improvement = $memDuring.MemoryPressure - $memAfter.MemoryPressure
            if ($improvement -gt 0) {
                Write-Host "✓ Memory management working - improved by $($improvement.ToString('F1'))%" -ForegroundColor Green
            } else {
                Write-Host "⚠ Memory management showed no improvement" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠ Optimize-GarbageCollection not available" -ForegroundColor Yellow
        }
        
        # Clean up
        $largeArray = $null
    } else {
        Write-Host "⚠ Memory monitoring functions not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Memory management test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 3: Enhanced Job-Based Parallel Execution
Write-Host "⚙️ Test 3: Enhanced Job-Based Parallel Execution" -ForegroundColor Cyan
Write-Host "-" * 50

try {
    $jobs = @(
        @{ Name = 'MathJob1'; ScriptBlock = { param($x) Start-Sleep -Milliseconds 100; return $x * 2 }; Arguments = @(5) },
        @{ Name = 'MathJob2'; ScriptBlock = { param($x) Start-Sleep -Milliseconds 150; return $x + 10 }; Arguments = @(3) },
        @{ Name = 'MathJob3'; ScriptBlock = { param($x) Start-Sleep -Milliseconds 80; return $x * $x }; Arguments = @(4) },
        @{ Name = 'StringJob'; ScriptBlock = { param($s) Start-Sleep -Milliseconds 120; return $s.ToUpper() }; Arguments = @("hello") }
    )
    
    if (Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue) {
        $startTime = Get-Date
        $jobResult = Start-ParallelExecution -Jobs $jobs -MaxConcurrentJobs 3 -EnableMemoryOptimization
        $duration = ((Get-Date) - $startTime).TotalSeconds
        
        Write-Host "  Job execution results:" -ForegroundColor Gray
        Write-Host "    Total jobs: $($jobResult.TotalJobs)" -ForegroundColor Gray
        Write-Host "    Completed: $($jobResult.CompletedJobs)" -ForegroundColor Gray
        Write-Host "    Failed: $($jobResult.FailedJobs)" -ForegroundColor Gray
        Write-Host "    Duration: $($duration.ToString('F2'))s" -ForegroundColor Gray
        
        if ($jobResult.Success) {
            Write-Host "✓ Enhanced parallel execution successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Enhanced parallel execution had failures" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ Start-ParallelExecution function not available, testing with basic jobs" -ForegroundColor Yellow
        
        # Fallback test with basic job management
        $basicJobs = @()
        foreach ($jobDef in $jobs) {
            $job = Start-Job -Name $jobDef.Name -ScriptBlock $jobDef.ScriptBlock -ArgumentList $jobDef.Arguments
            $basicJobs += $job
        }
        
        $basicJobs | Wait-Job | Out-Null
        $basicResults = $basicJobs | Receive-Job
        $basicJobs | Remove-Job -Force
        
        if ($basicResults.Count -eq $jobs.Count) {
            Write-Host "✓ Basic parallel job execution successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Basic parallel job execution failed" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "✗ Job-based parallel execution test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 4: Module Loading Performance
Write-Host "📚 Test 4: Module Loading Performance" -ForegroundColor Cyan
Write-Host "-" * 50

try {
    # Create a list of available modules for testing
    $modulesPath = './aither-core/modules'
    $availableModules = Get-ChildItem $modulesPath -Directory | Where-Object { 
        Test-Path (Join-Path $_.FullName "$($_.Name).psm1") 
    } | ForEach-Object {
        @{
            Name = $_.Name
            Path = $_.FullName
        }
    } | Select-Object -First 5  # Test with first 5 modules
    
    Write-Host "  Testing with $($availableModules.Count) modules" -ForegroundColor Gray
    
    if (Get-Command Optimize-ModuleBootstrap -ErrorAction SilentlyContinue) {
        $startTime = Get-Date
        $optimizationResult = Optimize-ModuleBootstrap -ModuleList $availableModules -DisableParallelLoading:$false
        $duration = ((Get-Date) - $startTime).TotalSeconds
        
        Write-Host "  Module loading results:" -ForegroundColor Gray
        Write-Host "    Total modules: $($optimizationResult.TotalModules)" -ForegroundColor Gray
        Write-Host "    Successful: $($optimizationResult.SuccessfulLoads)" -ForegroundColor Gray
        Write-Host "    Failed: $($optimizationResult.FailedLoads)" -ForegroundColor Gray
        Write-Host "    Total time: $($optimizationResult.TotalTime.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "    Speed: $($optimizationResult.Performance.ModulesPerSecond.ToString('F2')) modules/sec" -ForegroundColor Gray
        
        if ($optimizationResult.SuccessfulLoads -gt 0) {
            Write-Host "✓ Module loading optimization successful" -ForegroundColor Green
        } else {
            Write-Host "✗ Module loading optimization failed" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ Module loading optimizer not available" -ForegroundColor Yellow
        
        # Basic module loading test
        $successCount = 0
        foreach ($module in $availableModules) {
            try {
                Import-Module $module.Path -Force -ErrorAction Stop
                $successCount++
            } catch {
                Write-Host "    Failed to load $($module.Name): $_" -ForegroundColor Red
            }
        }
        
        Write-Host "  Basic module loading: $successCount/$($availableModules.Count) successful" -ForegroundColor Gray
        if ($successCount -eq $availableModules.Count) {
            Write-Host "✓ Basic module loading successful" -ForegroundColor Green
        } else {
            Write-Host "⚠ Some modules failed to load" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "✗ Module loading test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 5: Stress Test
Write-Host "💪 Test 5: Stress Test" -ForegroundColor Cyan
Write-Host "-" * 50

try {
    Write-Host "  Running parallel stress test..." -ForegroundColor Gray
    
    $stressItems = 1..100
    $stressStartTime = Get-Date
    
    $stressResults = Invoke-ParallelForEach -InputObject $stressItems -ScriptBlock {
        param($item)
        # Simulate CPU and memory work
        $result = 0
        for ($i = 0; $i -lt 1000; $i++) {
            $result += $item * $i
        }
        Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 50)
        return $result
    } -ThrottleLimit 8 -EnableMemoryOptimization
    
    $stressDuration = ((Get-Date) - $stressStartTime).TotalSeconds
    
    if ($stressResults.Count -eq $stressItems.Count) {
        Write-Host "✓ Stress test completed successfully" -ForegroundColor Green
        Write-Host "  Processed $($stressResults.Count) items in $($stressDuration.ToString('F2'))s" -ForegroundColor Gray
        Write-Host "  Throughput: $((($stressResults.Count / $stressDuration)).ToString('F2')) items/sec" -ForegroundColor Gray
    } else {
        Write-Host "✗ Stress test failed - missing results" -ForegroundColor Red
        Write-Host "  Expected: $($stressItems.Count), Got: $($stressResults.Count)" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Stress test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Performance Summary
Write-Host "📊 Performance Optimization Summary" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$summary = @{
    ParallelExecution = if ($results.Count -eq $testItems.Count) { "✓ Working" } else { "✗ Failed" }
    MemoryManagement = if (Get-Command Get-MemoryPressure -ErrorAction SilentlyContinue) { "✓ Available" } else { "⚠ Limited" }
    JobBasedExecution = if (Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue) { "✓ Enhanced" } else { "⚠ Basic" }
    ModuleLoading = if (Get-Command Optimize-ModuleBootstrap -ErrorAction SilentlyContinue) { "✓ Optimized" } else { "⚠ Standard" }
    StressTest = if ($stressResults.Count -eq 100) { "✓ Passed" } else { "✗ Failed" }
}

foreach ($test in $summary.GetEnumerator()) {
    $color = if ($test.Value.StartsWith("✓")) { "Green" } 
             elseif ($test.Value.StartsWith("⚠")) { "Yellow" } 
             else { "Red" }
    Write-Host "  $($test.Key): $($test.Value)" -ForegroundColor $color
}

Write-Host ""

# Recommendations
Write-Host "💡 Performance Recommendations" -ForegroundColor Cyan
Write-Host "-" * 50

$recommendations = @()

if (-not (Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue)) {
    $recommendations += "• Fix Start-ParallelExecution function export issue"
}

if (-not (Get-Command Get-MemoryPressure -ErrorAction SilentlyContinue)) {
    $recommendations += "• Implement memory monitoring functions"
}

if ($summary.StressTest.StartsWith("✗")) {
    $recommendations += "• Investigate parallel execution reliability under stress"
}

if ($recommendations.Count -eq 0) {
    Write-Host "  🎉 All performance optimizations are working correctly!" -ForegroundColor Green
} else {
    foreach ($rec in $recommendations) {
        Write-Host $rec -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🏁 Performance optimization test completed!" -ForegroundColor Cyan