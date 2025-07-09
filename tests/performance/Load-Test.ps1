#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Load testing for AitherZero concurrent operations and parallel execution
.DESCRIPTION
    This script tests AitherZero's ability to handle concurrent operations and parallel execution,
    specifically testing the new ParallelExecution module and domain loading under load.
.NOTES
    Performance Test Agent 7 - Load Testing and Parallel Execution Validation
#>

param(
    [int]$ConcurrentUsers = 10,
    [int]$DurationSeconds = 60,
    [int]$ParallelTasks = 5,
    [switch]$TestParallelExecution,
    [switch]$DetailedOutput
)

$ErrorActionPreference = 'Stop'

# Find project root
$ProjectRoot = $PSScriptRoot
while ($ProjectRoot -and -not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    $ProjectRoot = Split-Path $ProjectRoot -Parent
}

if (-not $ProjectRoot) {
    throw "Could not find project root"
}

Write-Host "🚀 AitherZero Load Testing Suite" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Concurrent Users: $ConcurrentUsers" -ForegroundColor Yellow
Write-Host "Duration: $DurationSeconds seconds" -ForegroundColor Yellow
Write-Host "Parallel Tasks: $ParallelTasks" -ForegroundColor Yellow
Write-Host "Test Parallel Execution: $TestParallelExecution" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor DarkGray

# Load testing function
function Start-LoadTest {
    param(
        [scriptblock]$Operation,
        [int]$ConcurrentUsers = 10,
        [int]$DurationSeconds = 60,
        [string]$TestName = "LoadTest"
    )
    
    Write-Host "`n🔄 Starting load test: $TestName" -ForegroundColor Cyan
    
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($DurationSeconds)
    $results = @()
    
    # Create jobs for concurrent users
    $jobs = @()
    for ($i = 1; $i -le $ConcurrentUsers; $i++) {
        $job = Start-Job -ScriptBlock {
            param($Operation, $EndTime, $UserId, $ProjectRoot)
            
            $userResults = @()
            $operationCount = 0
            
            # Change to project directory
            Set-Location $ProjectRoot
            
            while ((Get-Date) -lt $EndTime) {
                $operationStart = Get-Date
                try {
                    $result = & $Operation
                    $success = $true
                    $errorMsg = $null
                } catch {
                    $result = $null
                    $success = $false
                    $errorMsg = $_.Exception.Message
                }
                $operationEnd = Get-Date
                
                $userResults += @{
                    UserId = $UserId
                    OperationNumber = ++$operationCount
                    StartTime = $operationStart
                    EndTime = $operationEnd
                    Duration = ($operationEnd - $operationStart).TotalMilliseconds
                    Success = $success
                    Error = $errorMsg
                    Result = $result
                }
                
                # Small delay to prevent overwhelming the system
                Start-Sleep -Milliseconds 50
            }
            
            return @{
                UserId = $UserId
                OperationCount = $operationCount
                Results = $userResults
            }
        } -ArgumentList $Operation, $endTime, $i, $ProjectRoot
        
        $jobs += $job
    }
    
    # Monitor progress
    $progressInterval = 5
    $lastProgressUpdate = Get-Date
    
    while ((Get-Date) -lt $endTime) {
        $now = Get-Date
        if (($now - $lastProgressUpdate).TotalSeconds -ge $progressInterval) {
            $elapsed = ($now - $startTime).TotalSeconds
            $remaining = ($endTime - $now).TotalSeconds
            Write-Progress -Activity "Load Test: $TestName" -Status "$ConcurrentUsers users running, $([math]::Round($elapsed, 1))s elapsed, $([math]::Round($remaining, 1))s remaining" -PercentComplete (($elapsed / $DurationSeconds) * 100)
            $lastProgressUpdate = $now
        }
        Start-Sleep -Milliseconds 1000
    }
    
    Write-Progress -Activity "Load Test: $TestName" -Status "Collecting results..." -PercentComplete 100
    
    # Wait for all jobs to complete
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    
    Write-Progress -Activity "Load Test: $TestName" -Completed
    
    $actualEndTime = Get-Date
    $actualDuration = ($actualEndTime - $startTime).TotalSeconds
    
    # Analyze results
    $allOperations = $results | ForEach-Object { $_.Results }
    $totalOperations = ($results | Measure-Object -Property OperationCount -Sum).Sum
    $successfulOperations = ($allOperations | Where-Object { $_.Success }).Count
    $failedOperations = $totalOperations - $successfulOperations
    
    $durations = $allOperations | ForEach-Object { $_.Duration }
    $averageResponseTime = if ($durations.Count -gt 0) { ($durations | Measure-Object -Average).Average } else { 0 }
    $p95ResponseTime = if ($durations.Count -gt 0) { ($durations | Sort-Object)[[math]::Floor($durations.Count * 0.95)] } else { 0 }
    $throughput = if ($actualDuration -gt 0) { $totalOperations / $actualDuration } else { 0 }
    
    $loadTestResult = @{
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
        Results = $results
        AllOperations = $allOperations
    }
    
    Write-Host "✅ Load Test Completed: $TestName" -ForegroundColor Green
    Write-Host "  Total Operations: $totalOperations" -ForegroundColor Cyan
    Write-Host "  Success Rate: $([math]::Round($loadTestResult.SuccessRate * 100, 2))%" -ForegroundColor Cyan
    Write-Host "  Throughput: $([math]::Round($throughput, 2)) ops/sec" -ForegroundColor Cyan
    Write-Host "  Average Response Time: $([math]::Round($averageResponseTime, 2))ms" -ForegroundColor Cyan
    Write-Host "  P95 Response Time: $([math]::Round($p95ResponseTime, 2))ms" -ForegroundColor Cyan
    
    return $loadTestResult
}

# Test 1: Concurrent Domain Loading
Write-Host "`n📦 Load Test 1: Concurrent Domain Loading" -ForegroundColor Yellow
$concurrentDomainLoadTest = Start-LoadTest -TestName "ConcurrentDomainLoading" -ConcurrentUsers $ConcurrentUsers -DurationSeconds $DurationSeconds -Operation {
    # Import AitherCore
    $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
    Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
    
    # Initialize with minimal loading for speed
    $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
    
    # Get status
    $status = Get-CoreModuleStatus
    $loadedCount = ($status | Where-Object { $_.Loaded }).Count
    
    # Clean up
    Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'ModuleCommunication') } | Remove-Module -Force -ErrorAction SilentlyContinue
    
    return @{
        Success = $result
        LoadedCount = $loadedCount
        Operations = @("Initialize", "GetStatus", "Cleanup")
    }
}

# Test 2: Concurrent Core Function Operations
Write-Host "`n🎯 Load Test 2: Concurrent Core Function Operations" -ForegroundColor Yellow
$concurrentCoreFunctionTest = Start-LoadTest -TestName "ConcurrentCoreFunctions" -ConcurrentUsers ($ConcurrentUsers / 2) -DurationSeconds ($DurationSeconds / 2) -Operation {
    # Import AitherCore
    $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
    Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
    
    # Initialize
    $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
    
    # Test various operations
    $operations = @()
    
    # Random operation selection
    $operationType = Get-Random -Maximum 4
    switch ($operationType) {
        0 {
            # Get module status
            if (Get-Command Get-CoreModuleStatus -ErrorAction SilentlyContinue) {
                $status = Get-CoreModuleStatus
                $operations += "GetStatus"
            }
        }
        1 {
            # Test health
            if (Get-Command Test-CoreApplicationHealth -ErrorAction SilentlyContinue) {
                $health = Test-CoreApplicationHealth
                $operations += "TestHealth"
            }
        }
        2 {
            # Get platform info
            if (Get-Command Get-PlatformInfo -ErrorAction SilentlyContinue) {
                $platform = Get-PlatformInfo
                $operations += "GetPlatform"
            }
        }
        3 {
            # Get configuration
            if (Get-Command Get-CoreConfiguration -ErrorAction SilentlyContinue) {
                try {
                    $config = Get-CoreConfiguration
                    $operations += "GetConfig"
                } catch {
                    $operations += "GetConfigFailed"
                }
            }
        }
    }
    
    # Clean up
    Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'ModuleCommunication') } | Remove-Module -Force -ErrorAction SilentlyContinue
    
    return @{
        Success = $result
        Operations = $operations
        OperationType = $operationType
    }
}

# Test 3: Parallel Execution Module Test (if enabled)
if ($TestParallelExecution) {
    Write-Host "`n⚡ Load Test 3: Parallel Execution Module Test" -ForegroundColor Yellow
    
    # Test parallel execution capabilities
    $parallelExecutionTest = Start-LoadTest -TestName "ParallelExecutionTest" -ConcurrentUsers ($ConcurrentUsers / 3) -DurationSeconds ($DurationSeconds / 3) -Operation {
        # Import AitherCore and ParallelExecution
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
        
        # Try to load ParallelExecution module
        $parallelExecutionPath = Join-Path $ProjectRoot "aither-core/modules/ParallelExecution"
        if (Test-Path $parallelExecutionPath) {
            try {
                Import-Module $parallelExecutionPath -Force -Global -ErrorAction Stop
                $parallelAvailable = $true
            } catch {
                $parallelAvailable = $false
            }
        } else {
            $parallelAvailable = $false
        }
        
        if ($parallelAvailable -and (Get-Command Invoke-ParallelForEach -ErrorAction SilentlyContinue)) {
            # Test parallel operations
            $testItems = 1..($ParallelTasks)
            $parallelResults = Invoke-ParallelForEach -InputObject $testItems -ThrottleLimit 3 -ScriptBlock {
                param($item)
                
                # Simulate some work
                Start-Sleep -Milliseconds (Get-Random -Minimum 10 -Maximum 100)
                
                return @{
                    Item = $item
                    ProcessedBy = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                    ProcessTime = Get-Date
                }
            }
            
            $parallelSuccess = $parallelResults.Count -eq $testItems.Count
        } else {
            $parallelSuccess = $false
            $parallelResults = @()
        }
        
        # Clean up
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'ModuleCommunication', 'ParallelExecution') } | Remove-Module -Force -ErrorAction SilentlyContinue
        
        return @{
            Success = $parallelSuccess
            ParallelAvailable = $parallelAvailable
            ParallelResults = $parallelResults.Count
            TasksCompleted = $parallelResults.Count
        }
    }
}

# Test 4: Memory Stress Test Under Load
Write-Host "`n🧠 Load Test 4: Memory Stress Test Under Load" -ForegroundColor Yellow
$memoryStressTest = Start-LoadTest -TestName "MemoryStressTest" -ConcurrentUsers ($ConcurrentUsers / 4) -DurationSeconds ($DurationSeconds / 4) -Operation {
    $startMemory = [System.GC]::GetTotalMemory($false)
    
    # Import AitherCore multiple times to stress memory
    for ($i = 1; $i -le 3; $i++) {
        $aitherCorePath = Join-Path $ProjectRoot "aither-core/AitherCore.psm1"
        Import-Module $aitherCorePath -Force -Global -ErrorAction Stop
        
        # Initialize
        $result = Initialize-CoreApplication -RequiredOnly:$true -Force:$true
        
        # Create some objects
        $tempObjects = @()
        for ($j = 1; $j -le 10; $j++) {
            $tempObjects += @{
                Id = $j
                Data = "Test data $j" * 10
                Timestamp = Get-Date
            }
        }
        
        # Clean up modules
        Get-Module | Where-Object { $_.Name -like "*Aither*" -or $_.Name -in @('Logging', 'BackupManager', 'ConfigurationCore', 'ModuleCommunication') } | Remove-Module -Force -ErrorAction SilentlyContinue
    }
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    $endMemory = [System.GC]::GetTotalMemory($false)
    $memoryUsed = ($endMemory - $startMemory) / 1MB
    
    return @{
        Success = $result
        MemoryUsed = $memoryUsed
        Cycles = 3
        ObjectsCreated = 30
    }
}

# Performance Analysis
Write-Host "`n📊 Load Test Performance Analysis:" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray

# Analyze concurrent domain loading
Write-Host "🔄 Concurrent Domain Loading Analysis:" -ForegroundColor White
if ($concurrentDomainLoadTest.SuccessRate -ge 0.8) {
    Write-Host "  ✅ Good success rate: $([math]::Round($concurrentDomainLoadTest.SuccessRate * 100, 2))%" -ForegroundColor Green
} else {
    Write-Host "  ❌ Poor success rate: $([math]::Round($concurrentDomainLoadTest.SuccessRate * 100, 2))%" -ForegroundColor Red
}

if ($concurrentDomainLoadTest.Throughput -ge 1.0) {
    Write-Host "  ✅ Good throughput: $([math]::Round($concurrentDomainLoadTest.Throughput, 2)) ops/sec" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Low throughput: $([math]::Round($concurrentDomainLoadTest.Throughput, 2)) ops/sec" -ForegroundColor Yellow
}

if ($concurrentDomainLoadTest.AverageResponseTime -le 2000) {
    Write-Host "  ✅ Good response time: $([math]::Round($concurrentDomainLoadTest.AverageResponseTime, 2))ms" -ForegroundColor Green
} else {
    Write-Host "  ❌ Slow response time: $([math]::Round($concurrentDomainLoadTest.AverageResponseTime, 2))ms" -ForegroundColor Red
}

# Analyze concurrent core functions
Write-Host "`n🎯 Concurrent Core Functions Analysis:" -ForegroundColor White
if ($concurrentCoreFunctionTest.SuccessRate -ge 0.9) {
    Write-Host "  ✅ Good success rate: $([math]::Round($concurrentCoreFunctionTest.SuccessRate * 100, 2))%" -ForegroundColor Green
} else {
    Write-Host "  ❌ Poor success rate: $([math]::Round($concurrentCoreFunctionTest.SuccessRate * 100, 2))%" -ForegroundColor Red
}

if ($concurrentCoreFunctionTest.Throughput -ge 2.0) {
    Write-Host "  ✅ Good throughput: $([math]::Round($concurrentCoreFunctionTest.Throughput, 2)) ops/sec" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Low throughput: $([math]::Round($concurrentCoreFunctionTest.Throughput, 2)) ops/sec" -ForegroundColor Yellow
}

# Analyze parallel execution (if tested)
if ($TestParallelExecution -and $parallelExecutionTest) {
    Write-Host "`n⚡ Parallel Execution Analysis:" -ForegroundColor White
    if ($parallelExecutionTest.SuccessRate -ge 0.7) {
        Write-Host "  ✅ Good success rate: $([math]::Round($parallelExecutionTest.SuccessRate * 100, 2))%" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Poor success rate: $([math]::Round($parallelExecutionTest.SuccessRate * 100, 2))%" -ForegroundColor Red
    }
    
    # Analyze parallel execution results
    $parallelOperations = $parallelExecutionTest.AllOperations | Where-Object { $_.Success -and $_.Result.ParallelAvailable }
    if ($parallelOperations.Count -gt 0) {
        Write-Host "  ✅ Parallel execution is available and working" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Parallel execution may not be available" -ForegroundColor Yellow
    }
}

# Analyze memory stress test
Write-Host "`n🧠 Memory Stress Test Analysis:" -ForegroundColor White
if ($memoryStressTest.SuccessRate -ge 0.8) {
    Write-Host "  ✅ Good success rate under memory stress: $([math]::Round($memoryStressTest.SuccessRate * 100, 2))%" -ForegroundColor Green
} else {
    Write-Host "  ❌ Poor success rate under memory stress: $([math]::Round($memoryStressTest.SuccessRate * 100, 2))%" -ForegroundColor Red
}

$avgMemoryUsage = ($memoryStressTest.AllOperations | Where-Object { $_.Success } | ForEach-Object { $_.Result.MemoryUsed } | Measure-Object -Average).Average
if ($avgMemoryUsage -and $avgMemoryUsage -le 50) {
    Write-Host "  ✅ Good memory usage: $([math]::Round($avgMemoryUsage, 2))MB average" -ForegroundColor Green
} elseif ($avgMemoryUsage) {
    Write-Host "  ⚠️  High memory usage: $([math]::Round($avgMemoryUsage, 2))MB average" -ForegroundColor Yellow
} else {
    Write-Host "  ❓ Could not determine memory usage" -ForegroundColor Gray
}

# Overall Load Test Verdict
Write-Host "`n🎯 Overall Load Test Verdict:" -ForegroundColor White
Write-Host "=" * 60 -ForegroundColor DarkGray

$overallGood = $true
$issues = @()

# Check each test
if ($concurrentDomainLoadTest.SuccessRate -lt 0.8) {
    $overallGood = $false
    $issues += "Concurrent domain loading reliability"
}

if ($concurrentDomainLoadTest.Throughput -lt 1.0) {
    $overallGood = $false
    $issues += "Low domain loading throughput"
}

if ($concurrentCoreFunctionTest.SuccessRate -lt 0.9) {
    $overallGood = $false
    $issues += "Core function reliability under load"
}

if ($memoryStressTest.SuccessRate -lt 0.8) {
    $overallGood = $false
    $issues += "Memory stress handling"
}

if ($overallGood) {
    Write-Host "✅ LOAD TEST PASSED" -ForegroundColor Green
    Write-Host "Domain architecture handles concurrent operations well" -ForegroundColor Green
} else {
    Write-Host "❌ LOAD TEST ISSUES DETECTED" -ForegroundColor Red
    Write-Host "Issues: $($issues -join ', ')" -ForegroundColor Red
    Write-Host "Domain architecture needs load optimization" -ForegroundColor Red
}

# Summary table
Write-Host "`n📋 Load Test Summary:" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor DarkGray
Write-Host "Test                     | Success Rate | Throughput | Avg Response" -ForegroundColor Gray
Write-Host "-" * 60 -ForegroundColor DarkGray

$tests = @(
    @{Name = "Concurrent Domain Loading"; Test = $concurrentDomainLoadTest},
    @{Name = "Concurrent Core Functions"; Test = $concurrentCoreFunctionTest},
    @{Name = "Memory Stress Test"; Test = $memoryStressTest}
)

if ($TestParallelExecution -and $parallelExecutionTest) {
    $tests += @{Name = "Parallel Execution Test"; Test = $parallelExecutionTest}
}

foreach ($testInfo in $tests) {
    $test = $testInfo.Test
    $name = $testInfo.Name.PadRight(25)
    $successRate = "$([math]::Round($test.SuccessRate * 100, 1))%".PadLeft(10)
    $throughput = "$([math]::Round($test.Throughput, 2))".PadLeft(10)
    $avgResponse = "$([math]::Round($test.AverageResponseTime, 2))ms".PadLeft(12)
    
    Write-Host "$name|$successRate |$throughput |$avgResponse" -ForegroundColor Gray
}

Write-Host "`n🏁 Load testing completed!" -ForegroundColor Green