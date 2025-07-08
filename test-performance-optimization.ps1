#!/usr/bin/env pwsh
#Requires -Version 7.0

# Test script for module loading performance and optimization validation

param(
    [switch]$Detailed,
    [int]$Iterations = 3
)

$ErrorActionPreference = 'Stop'

function Test-ModuleLoadingPerformance {
    Write-Host "=== Testing Module Loading Performance ===" -ForegroundColor Cyan
    
    $performanceTests = @()
    
    try {
        # Performance Test 1: Cold start performance
        Write-Host "`n1. Testing cold start performance..." -ForegroundColor Yellow
        
        $coldStartResults = @()
        
        for ($i = 1; $i -le $Iterations; $i++) {
            Write-Host "  Cold start iteration $i..." -ForegroundColor Gray
            
            # Remove all modules for clean start
            Get-Module | Where-Object { $_.Name -like 'AitherCore' -or $_.Name -like 'Logging' -or $_.Name -like 'LabRunner' } | Remove-Module -Force -ErrorAction SilentlyContinue
            
            # Measure cold start
            $startTime = Get-Date
            Import-Module ./aither-core/AitherCore.psd1 -Force
            $initResult = Initialize-CoreApplication -RequiredOnly
            $endTime = Get-Date
            
            $duration = ($endTime - $startTime).TotalMilliseconds
            $moduleCount = (Get-Module).Count
            
            $coldStartResults += @{
                Iteration = $i
                Duration = $duration
                ModuleCount = $moduleCount
                Success = $initResult
            }
        }
        
        $avgColdStart = ($coldStartResults | Measure-Object -Property Duration -Average).Average
        $minColdStart = ($coldStartResults | Measure-Object -Property Duration -Minimum).Minimum
        $maxColdStart = ($coldStartResults | Measure-Object -Property Duration -Maximum).Maximum
        
        $performanceTests += @{
            Test = "Cold start performance"
            Success = $true
            AvgDuration = $avgColdStart
            MinDuration = $minColdStart
            MaxDuration = $maxColdStart
            Details = "$Iterations iterations, avg: $([math]::Round($avgColdStart, 1))ms"
        }
        
        Write-Host "✓ Cold start performance: avg $([math]::Round($avgColdStart, 1))ms, min $([math]::Round($minColdStart, 1))ms, max $([math]::Round($maxColdStart, 1))ms" -ForegroundColor Green
        
        # Performance Test 2: Warm start performance
        Write-Host "`n2. Testing warm start performance..." -ForegroundColor Yellow
        
        $warmStartResults = @()
        
        # Ensure we have a baseline loaded
        Import-Module ./aither-core/AitherCore.psd1 -Force
        Initialize-CoreApplication -RequiredOnly
        
        for ($i = 1; $i -le $Iterations; $i++) {
            Write-Host "  Warm start iteration $i..." -ForegroundColor Gray
            
            # Measure warm re-initialization
            $startTime = Get-Date
            $initResult = Initialize-CoreApplication -Force
            $endTime = Get-Date
            
            $duration = ($endTime - $startTime).TotalMilliseconds
            
            $warmStartResults += @{
                Iteration = $i
                Duration = $duration
                Success = $initResult
            }
        }
        
        $avgWarmStart = ($warmStartResults | Measure-Object -Property Duration -Average).Average
        $minWarmStart = ($warmStartResults | Measure-Object -Property Duration -Minimum).Minimum
        $maxWarmStart = ($warmStartResults | Measure-Object -Property Duration -Maximum).Maximum
        
        $performanceTests += @{
            Test = "Warm start performance"
            Success = $true
            AvgDuration = $avgWarmStart
            MinDuration = $minWarmStart
            MaxDuration = $maxWarmStart
            Details = "$Iterations iterations, avg: $([math]::Round($avgWarmStart, 1))ms"
        }
        
        Write-Host "✓ Warm start performance: avg $([math]::Round($avgWarmStart, 1))ms, min $([math]::Round($minWarmStart, 1))ms, max $([math]::Round($maxWarmStart, 1))ms" -ForegroundColor Green
        
        # Performance Test 3: Individual module loading
        Write-Host "`n3. Testing individual module loading performance..." -ForegroundColor Yellow
        
        $modulePerformance = @()
        $testModules = @('Logging', 'ConfigurationCore', 'LabRunner')
        
        foreach ($moduleName in $testModules) {
            $modulePath = "./aither-core/modules/$moduleName"
            if (Test-Path $modulePath) {
                # Remove module if loaded
                if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
                    Remove-Module -Name $moduleName -Force
                }
                
                # Measure individual module load time
                $startTime = Get-Date
                Import-Module $modulePath -Force
                $endTime = Get-Date
                
                $duration = ($endTime - $startTime).TotalMilliseconds
                $commands = (Get-Command -Module $moduleName -ErrorAction SilentlyContinue).Count
                
                $modulePerformance += @{
                    Module = $moduleName
                    Duration = $duration
                    Commands = $commands
                    CommandsPerMs = if ($duration -gt 0) { [math]::Round($commands / $duration, 2) } else { 0 }
                }
                
                Write-Host "  ✓ ${moduleName}: $([math]::Round($duration, 1))ms ($commands commands)" -ForegroundColor Green
            }
        }
        
        $performanceTests += @{
            Test = "Individual module loading"
            Success = $true
            ModulePerformance = $modulePerformance
            Details = "Tested $($testModules.Count) modules individually"
        }
        
        return @{
            Success = $true
            PerformanceTests = $performanceTests
            ColdStartResults = $coldStartResults
            WarmStartResults = $warmStartResults
            ModulePerformance = $modulePerformance
        }
        
    } catch {
        Write-Host "✗ Module loading performance test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            PerformanceTests = $performanceTests
        }
    }
}

function Test-MemoryUsage {
    Write-Host "`n=== Testing Memory Usage ===" -ForegroundColor Cyan
    
    $memoryTests = @()
    
    try {
        # Memory Test 1: Baseline memory usage
        Write-Host "`n1. Testing baseline memory usage..." -ForegroundColor Yellow
        
        # Clean environment
        Get-Module | Where-Object { $_.Name -notlike 'Microsoft.PowerShell.*' -and $_.Name -ne 'PSReadLine' } | Remove-Module -Force -ErrorAction SilentlyContinue
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 500
        
        $baselineMemory = [System.GC]::GetTotalMemory($false)
        
        Write-Host "✓ Baseline memory usage: $([math]::Round($baselineMemory / 1MB, 2)) MB" -ForegroundColor Green
        
        # Memory Test 2: Memory usage after AitherCore loading
        Write-Host "`n2. Testing memory usage after AitherCore loading..." -ForegroundColor Yellow
        
        Import-Module ./aither-core/AitherCore.psd1 -Force
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 500
        
        $afterAitherCoreMemory = [System.GC]::GetTotalMemory($false)
        $aitherCoreMemoryUsage = $afterAitherCoreMemory - $baselineMemory
        
        Write-Host "✓ Memory after AitherCore: $([math]::Round($afterAitherCoreMemory / 1MB, 2)) MB (delta: $([math]::Round($aitherCoreMemoryUsage / 1MB, 2)) MB)" -ForegroundColor Green
        
        # Memory Test 3: Memory usage after full initialization
        Write-Host "`n3. Testing memory usage after full initialization..." -ForegroundColor Yellow
        
        Initialize-CoreApplication -RequiredOnly
        [System.GC]::Collect()
        Start-Sleep -Milliseconds 500
        
        $afterInitMemory = [System.GC]::GetTotalMemory($false)
        $initMemoryUsage = $afterInitMemory - $afterAitherCoreMemory
        $totalMemoryUsage = $afterInitMemory - $baselineMemory
        
        Write-Host "✓ Memory after initialization: $([math]::Round($afterInitMemory / 1MB, 2)) MB (delta: $([math]::Round($initMemoryUsage / 1MB, 2)) MB)" -ForegroundColor Green
        Write-Host "✓ Total memory increase: $([math]::Round($totalMemoryUsage / 1MB, 2)) MB" -ForegroundColor Green
        
        $memoryTests += @{
            Test = "Memory usage tracking"
            Success = $true
            BaselineMemory = $baselineMemory
            AitherCoreMemory = $afterAitherCoreMemory
            InitializedMemory = $afterInitMemory
            AitherCoreIncrease = $aitherCoreMemoryUsage
            InitializationIncrease = $initMemoryUsage
            TotalIncrease = $totalMemoryUsage
            Details = "Total increase: $([math]::Round($totalMemoryUsage / 1MB, 2)) MB"
        }
        
        # Memory Test 4: Memory efficiency check
        Write-Host "`n4. Testing memory efficiency..." -ForegroundColor Yellow
        
        $moduleCount = (Get-Module).Count
        $functionCount = (Get-Command -CommandType Function).Count
        
        $memoryPerModule = if ($moduleCount -gt 0) { $totalMemoryUsage / $moduleCount } else { 0 }
        $memoryPerFunction = if ($functionCount -gt 0) { $totalMemoryUsage / $functionCount } else { 0 }
        
        # Define reasonable thresholds (these are rough estimates)
        $maxMemoryPerModule = 5MB  # 5MB per module seems reasonable
        $maxMemoryPerFunction = 500KB  # 500KB per function seems reasonable
        
        $memoryEfficient = ($memoryPerModule -le $maxMemoryPerModule) -and ($memoryPerFunction -le $maxMemoryPerFunction)
        
        $memoryTests += @{
            Test = "Memory efficiency"
            Success = $memoryEfficient
            ModuleCount = $moduleCount
            FunctionCount = $functionCount
            MemoryPerModule = $memoryPerModule
            MemoryPerFunction = $memoryPerFunction
            Details = "Memory per module: $([math]::Round($memoryPerModule / 1KB, 1)) KB, per function: $([math]::Round($memoryPerFunction / 1KB, 1)) KB"
        }
        
        if ($memoryEfficient) {
            Write-Host "✓ Memory efficiency acceptable" -ForegroundColor Green
        } else {
            Write-Host "⚠ Memory efficiency could be improved" -ForegroundColor Yellow
        }
        
        Write-Host "  - Memory per module: $([math]::Round($memoryPerModule / 1KB, 1)) KB" -ForegroundColor White
        Write-Host "  - Memory per function: $([math]::Round($memoryPerFunction / 1KB, 1)) KB" -ForegroundColor White
        
        return @{
            Success = $true
            MemoryTests = $memoryTests
        }
        
    } catch {
        Write-Host "✗ Memory usage test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            MemoryTests = $memoryTests
        }
    }
}

function Test-FunctionLoadingOptimization {
    Write-Host "`n=== Testing Function Loading Optimization ===" -ForegroundColor Cyan
    
    $optimizationTests = @()
    
    try {
        # Optimization Test 1: Function availability timing
        Write-Host "`n1. Testing function availability timing..." -ForegroundColor Yellow
        
        # Clean start
        Get-Module | Where-Object { $_.Name -like 'AitherCore' } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        # Import and time function availability
        $startTime = Get-Date
        Import-Module ./aither-core/AitherCore.psd1 -Force
        
        $coreImportTime = Get-Date
        $coreImportDuration = ($coreImportTime - $startTime).TotalMilliseconds
        
        # Test core functions availability
        $coreFunctions = @('Initialize-CoreApplication', 'Get-CoreConfiguration', 'Test-CoreApplicationHealth', 'Write-CustomLog')
        $availableFunctions = 0
        foreach ($func in $coreFunctions) {
            if (Get-Command $func -ErrorAction SilentlyContinue) {
                $availableFunctions++
            }
        }
        
        $functionAvailabilityTime = Get-Date
        $functionCheckDuration = ($functionAvailabilityTime - $coreImportTime).TotalMilliseconds
        
        $optimizationTests += @{
            Test = "Function availability timing"
            Success = $true
            CoreImportDuration = $coreImportDuration
            FunctionCheckDuration = $functionCheckDuration
            AvailableFunctions = $availableFunctions
            TotalFunctions = $coreFunctions.Count
            Details = "Core import: $([math]::Round($coreImportDuration, 1))ms, function check: $([math]::Round($functionCheckDuration, 1))ms"
        }
        
        Write-Host "✓ Function availability: $availableFunctions/$($coreFunctions.Count) functions available immediately" -ForegroundColor Green
        Write-Host "  - Core import time: $([math]::Round($coreImportDuration, 1))ms" -ForegroundColor White
        Write-Host "  - Function check time: $([math]::Round($functionCheckDuration, 1))ms" -ForegroundColor White
        
        # Optimization Test 2: Lazy loading effectiveness
        Write-Host "`n2. Testing lazy loading effectiveness..." -ForegroundColor Yellow
        
        # Test if modules are loaded on demand
        $initialModuleCount = (Get-Module).Count
        
        # Initialize with required only
        $initStartTime = Get-Date
        Initialize-CoreApplication -RequiredOnly
        $initEndTime = Get-Date
        $initDuration = ($initEndTime - $initStartTime).TotalMilliseconds
        
        $requiredModuleCount = (Get-Module).Count
        $requiredModulesLoaded = $requiredModuleCount - $initialModuleCount
        
        # Test full initialization
        $fullInitStartTime = Get-Date
        Import-CoreModules
        $fullInitEndTime = Get-Date
        $fullInitDuration = ($fullInitEndTime - $fullInitStartTime).TotalMilliseconds
        
        $finalModuleCount = (Get-Module).Count
        $optionalModulesLoaded = $finalModuleCount - $requiredModuleCount
        
        $lazyLoadingEffective = ($requiredModulesLoaded -le 10) -and ($initDuration -le 5000)  # Should load ≤10 modules in ≤5 seconds
        
        $optimizationTests += @{
            Test = "Lazy loading effectiveness"
            Success = $lazyLoadingEffective
            RequiredModulesLoaded = $requiredModulesLoaded
            OptionalModulesLoaded = $optionalModulesLoaded
            RequiredInitDuration = $initDuration
            FullInitDuration = $fullInitDuration
            Details = "Required: $requiredModulesLoaded modules in $([math]::Round($initDuration, 1))ms, Full: $optionalModulesLoaded additional modules in $([math]::Round($fullInitDuration, 1))ms"
        }
        
        if ($lazyLoadingEffective) {
            Write-Host "✓ Lazy loading effective: $requiredModulesLoaded required modules in $([math]::Round($initDuration, 1))ms" -ForegroundColor Green
        } else {
            Write-Host "⚠ Lazy loading could be optimized: $requiredModulesLoaded modules in $([math]::Round($initDuration, 1))ms" -ForegroundColor Yellow
        }
        
        # Optimization Test 3: Function call overhead
        Write-Host "`n3. Testing function call overhead..." -ForegroundColor Yellow
        
        $overheadTests = @()
        
        # Test Write-CustomLog overhead
        if (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) {
            $logCallStart = Get-Date
            for ($i = 1; $i -le 100; $i++) {
                Write-CustomLog -Message "Performance test $i" -Level 'DEBUG' -ErrorAction SilentlyContinue
            }
            $logCallEnd = Get-Date
            $logCallDuration = ($logCallEnd - $logCallStart).TotalMilliseconds
            $avgLogCallTime = $logCallDuration / 100
            
            $overheadTests += @{
                Function = "Write-CustomLog"
                TotalDuration = $logCallDuration
                AverageCallTime = $avgLogCallTime
                CallsPerSecond = if ($avgLogCallTime -gt 0) { 1000 / $avgLogCallTime } else { 0 }
            }
        }
        
        # Test Get-CoreModuleStatus overhead
        if (Get-Command 'Get-CoreModuleStatus' -ErrorAction SilentlyContinue) {
            $statusCallStart = Get-Date
            for ($i = 1; $i -le 10; $i++) {
                Get-CoreModuleStatus | Out-Null
            }
            $statusCallEnd = Get-Date
            $statusCallDuration = ($statusCallEnd - $statusCallStart).TotalMilliseconds
            $avgStatusCallTime = $statusCallDuration / 10
            
            $overheadTests += @{
                Function = "Get-CoreModuleStatus"
                TotalDuration = $statusCallDuration
                AverageCallTime = $avgStatusCallTime
                CallsPerSecond = if ($avgStatusCallTime -gt 0) { 1000 / $avgStatusCallTime } else { 0 }
            }
        }
        
        $optimizationTests += @{
            Test = "Function call overhead"
            Success = $true
            OverheadTests = $overheadTests
            Details = "Tested function call performance"
        }
        
        foreach ($test in $overheadTests) {
            Write-Host "✓ $($test.Function): $([math]::Round($test.AverageCallTime, 2))ms avg ($([math]::Round($test.CallsPerSecond, 0)) calls/sec)" -ForegroundColor Green
        }
        
        return @{
            Success = $true
            OptimizationTests = $optimizationTests
        }
        
    } catch {
        Write-Host "✗ Function loading optimization test failed: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            Error = $_.Exception.Message
            OptimizationTests = $optimizationTests
        }
    }
}

try {
    Write-Host "=== Module Performance and Optimization Testing ===" -ForegroundColor Cyan
    
    $testResults = @{}
    
    # Test 1: Module Loading Performance
    $testResults.LoadingPerformance = Test-ModuleLoadingPerformance
    
    # Test 2: Memory Usage
    $testResults.MemoryUsage = Test-MemoryUsage
    
    # Test 3: Function Loading Optimization
    $testResults.FunctionOptimization = Test-FunctionLoadingOptimization
    
    # Final Assessment
    Write-Host "`n=== Final Assessment ===" -ForegroundColor Cyan
    
    $failedTests = $testResults.Values | Where-Object { -not $_.Success }
    $allTestsPassed = ($failedTests.Count -eq 0)
    
    if ($allTestsPassed) {
        Write-Host "🎉 All performance and optimization tests PASSED" -ForegroundColor Green
    } else {
        Write-Host "❌ Some performance and optimization tests had issues:" -ForegroundColor Red
        foreach ($failedTest in $failedTests) {
            Write-Host "  - $($failedTest.Error)" -ForegroundColor Red
        }
    }
    
    # Performance Summary
    Write-Host "`n📊 Performance Summary:" -ForegroundColor Cyan
    
    if ($testResults.LoadingPerformance.Success) {
        $loadingResult = $testResults.LoadingPerformance
        $coldStartAvg = ($loadingResult.PerformanceTests | Where-Object { $_.Test -eq "Cold start performance" }).AvgDuration
        $warmStartAvg = ($loadingResult.PerformanceTests | Where-Object { $_.Test -eq "Warm start performance" }).AvgDuration
        
        Write-Host "  - Cold start average: $([math]::Round($coldStartAvg, 1))ms" -ForegroundColor White
        Write-Host "  - Warm start average: $([math]::Round($warmStartAvg, 1))ms" -ForegroundColor White
        Write-Host "  - Warm start improvement: $([math]::Round((1 - $warmStartAvg / $coldStartAvg) * 100, 1))%" -ForegroundColor White
    }
    
    if ($testResults.MemoryUsage.Success) {
        $memoryResult = $testResults.MemoryUsage
        $memoryTest = $memoryResult.MemoryTests | Where-Object { $_.Test -eq "Memory usage tracking" }
        if ($memoryTest) {
            Write-Host "  - Total memory increase: $([math]::Round($memoryTest.TotalIncrease / 1MB, 2)) MB" -ForegroundColor White
        }
    }
    
    # Detailed breakdown if requested
    if ($Detailed) {
        Write-Host "`nDetailed Performance Results:" -ForegroundColor Cyan
        
        if ($testResults.LoadingPerformance.Success -and $testResults.LoadingPerformance.ColdStartResults) {
            Write-Host "`nCold Start Results:" -ForegroundColor Yellow
            $testResults.LoadingPerformance.ColdStartResults | Format-Table Iteration, @{Name="Duration(ms)"; Expression={[math]::Round($_.Duration, 1)}}, ModuleCount, Success -AutoSize
        }
        
        if ($testResults.LoadingPerformance.Success -and $testResults.LoadingPerformance.ModulePerformance) {
            Write-Host "`nIndividual Module Performance:" -ForegroundColor Yellow
            $testResults.LoadingPerformance.ModulePerformance | Format-Table Module, @{Name="Duration(ms)"; Expression={[math]::Round($_.Duration, 1)}}, Commands, CommandsPerMs -AutoSize
        }
        
        if ($testResults.FunctionOptimization.Success) {
            Write-Host "`nFunction Optimization Results:" -ForegroundColor Yellow
            foreach ($test in $testResults.FunctionOptimization.OptimizationTests) {
                Write-Host "$($test.Test): $($test.Details)" -ForegroundColor White
            }
        }
    }
    
    return @{
        Success = $allTestsPassed
        TestResults = $testResults
        Summary = @{
            LoadingPerformancePassed = $testResults.LoadingPerformance.Success
            MemoryUsagePassed = $testResults.MemoryUsage.Success
            FunctionOptimizationPassed = $testResults.FunctionOptimization.Success
        }
    }
    
} catch {
    Write-Host "`n=== Performance and Optimization Testing FAILED ===" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
}