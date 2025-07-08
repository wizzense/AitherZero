# ParallelExecution Module

## Test Status
- **Last Run**: 2025-07-08 18:34:12 UTC
- **Status**: ✅ PASSING (11/11 tests)
- **Coverage**: 0%
- **Platform**: ✅ Windows ✅ Linux ✅ macOS
- **Dependencies**: ✅ All resolved

## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.4s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ❌ FAIL | 43/49 | 0% | 3.6s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 10/10 | 0% | 1s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 0.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Test Results
| Test Suite | Status | Tests | Coverage | Duration |
|------------|--------|-------|----------|----------|
| Unit Tests | ✅ PASS | 11/11 | 0% | 1.5s |

---
*Test status updated automatically by AitherZero Testing Framework*
## Module Overview

The ParallelExecution module provides cross-platform parallel processing capabilities for PowerShell scripts within the AitherZero framework. It leverages PowerShell 7.0+ native parallel features to accelerate CPU-intensive and I/O-intensive workloads while maintaining compatibility across Windows, Linux, and macOS.

### Primary Purpose and Architecture

- **Native parallel processing** using PowerShell 7.0+ ForEach-Object -Parallel
- **Background job management** with monitoring and result aggregation
- **Pester test parallelization** for faster test execution
- **Cross-platform compatibility** with consistent behavior
- **Thread-safe operations** with proper synchronization
- **Resource throttling** to prevent system overload
- **Result aggregation** from parallel operations

### Key Capabilities and Features

- **Parallel ForEach execution** with configurable throttle limits
- **Background job orchestration** with timeout management
- **Progress monitoring** for long-running parallel operations
- **Automatic result collection** and error aggregation
- **Pester integration** for parallel test execution
- **Dynamic throttling** based on system resources
- **Timeout protection** to prevent runaway operations
- **Comprehensive error handling** with detailed reporting
- **Adaptive parallel execution** with real-time performance optimization
- **System resource analysis** for optimal throttle limit calculation
- **Performance metrics collection** and analysis
- **Thread-safe operations** with proper resource cleanup
- **Cross-platform compatibility** (Windows, Linux, macOS)

### Integration Patterns

```powershell
# Import the module
Import-Module ./aither-core/modules/ParallelExecution -Force

# Parallel foreach with script block
$files = Get-ChildItem -Path "./scripts" -Filter "*.ps1"
$results = Invoke-ParallelForEach -InputObject $files -ScriptBlock {
    param($file)
    Test-ScriptAnalyzer -Path $file.FullName
} -ThrottleLimit 4

# Background jobs with monitoring
$jobs = @()
$jobs += Start-ParallelJob -Name "DatabaseBackup" -ScriptBlock {
    Backup-Database -Server "DB01"
}
$jobs += Start-ParallelJob -Name "FileBackup" -ScriptBlock {
    Backup-FileShare -Path "\\server\share"
}
$results = Wait-ParallelJobs -Jobs $jobs -ShowProgress

# Parallel Pester tests
$testResults = Invoke-ParallelPesterTests -TestPaths @(
    "./tests/Unit.Tests.ps1",
    "./tests/Integration.Tests.ps1"
) -ThrottleLimit 2
```

## Directory Structure

```
ParallelExecution/
├── ParallelExecution.psd1    # Module manifest
├── ParallelExecution.psm1    # Core parallel execution logic
└── README.md                 # This documentation
```

### Module Organization

- **ParallelExecution.psd1**: Module manifest defining PowerShell 7.0+ requirement
- **ParallelExecution.psm1**: Implementation of parallel execution functions
- **tests/ParallelExecution.Tests.ps1**: Comprehensive test suite with 37 test cases
- **Project root detection**: Automatic discovery of AitherZero project structure
- **Logging integration**: Optional integration with AitherZero Logging module
- **Performance optimization**: Advanced throttling and adaptive execution capabilities

## API Reference

### Main Functions

#### Invoke-ParallelForEach
Executes a script block in parallel across multiple items.

```powershell
Invoke-ParallelForEach [-InputObject <object[]>] -ScriptBlock <scriptblock>
                      [-ThrottleLimit <int>] [-TimeoutSeconds <int>]
```

**Parameters:**
- `InputObject` (object[]): Collection of items to process in parallel
- `ScriptBlock` (scriptblock, required): Script to execute for each item
- `ThrottleLimit` (int): Maximum parallel threads. Default: CPU count
- `TimeoutSeconds` (int): Operation timeout. Default: 300

**Returns:** Array of results from parallel execution

**Example:**
```powershell
# Process multiple files in parallel
$logFiles = Get-ChildItem -Path "C:\Logs" -Filter "*.log"
$analysis = Invoke-ParallelForEach -InputObject $logFiles -ScriptBlock {
    param($file)
    $errors = Select-String -Path $file.FullName -Pattern "ERROR"
    return @{
        File = $file.Name
        ErrorCount = $errors.Count
        Size = $file.Length
    }
} -ThrottleLimit 8

# Using $_ syntax
$numbers = 1..100
$results = Invoke-ParallelForEach -InputObject $numbers -ScriptBlock {
    $_ * $_ # Square each number
}
```

#### Start-ParallelJob
Starts a background job for parallel execution.

```powershell
Start-ParallelJob -Name <string> -ScriptBlock <scriptblock>
                 [-ArgumentList <object[]>]
```

**Parameters:**
- `Name` (string, required): Job identifier name
- `ScriptBlock` (scriptblock, required): Script to execute in background
- `ArgumentList` (object[]): Arguments to pass to script block

**Returns:** PowerShell Job object

**Example:**
```powershell
# Start multiple background operations
$backupJob = Start-ParallelJob -Name "BackupDatabase" -ScriptBlock {
    param($server, $database)
    Backup-SqlDatabase -ServerInstance $server -Database $database
} -ArgumentList @("SQL01", "ProductionDB")

$compressionJob = Start-ParallelJob -Name "CompressLogs" -ScriptBlock {
    Compress-Archive -Path "C:\Logs\*.log" -DestinationPath "C:\Archive\logs.zip"
}
```

#### Wait-ParallelJobs
Waits for multiple parallel jobs to complete with monitoring.

```powershell
Wait-ParallelJobs -Jobs <Job[]> [-TimeoutSeconds <int>] [-ShowProgress]
```

**Parameters:**
- `Jobs` (Job[], required): Array of PowerShell job objects
- `TimeoutSeconds` (int): Maximum wait time. Default: 600
- `ShowProgress` (switch): Display progress bar

**Returns:** Array of job result objects with status and output

**Example:**
```powershell
# Create and wait for multiple jobs
$jobs = @()
$servers = @("WEB01", "WEB02", "WEB03")
foreach ($server in $servers) {
    $jobs += Start-ParallelJob -Name "Deploy-$server" -ScriptBlock {
        param($srv)
        Update-WebApplication -ComputerName $srv
    } -ArgumentList $server
}

# Wait with progress display
$results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 1200 -ShowProgress

# Check results
foreach ($result in $results) {
    if ($result.State -eq "Completed") {
        Write-Host "$($result.Name) succeeded"
    } else {
        Write-Host "$($result.Name) failed: $($result.Errors -join '; ')"
    }
}
```

#### Invoke-ParallelPesterTests
Runs Pester tests in parallel for improved performance.

```powershell
Invoke-ParallelPesterTests -TestPaths <string[]> [-ThrottleLimit <int>]
                          [-OutputFormat <string>]
```

**Parameters:**
- `TestPaths` (string[], required): Array of test file paths or directories
- `ThrottleLimit` (int): Maximum parallel test jobs. Default: CPU count
- `OutputFormat` (string): Pester output format - Detailed, Normal, Minimal. Default: Normal

**Returns:** Array of test execution results

**Example:**
```powershell
# Run all module tests in parallel
$testPaths = Get-ChildItem -Path "./tests" -Filter "*.Tests.ps1" | 
             Select-Object -ExpandProperty FullName

$testResults = Invoke-ParallelPesterTests -TestPaths $testPaths -ThrottleLimit 4

# Aggregate results
$summary = Merge-ParallelTestResults -TestResults $testResults
Write-Host "Total: $($summary.TotalTests), Passed: $($summary.Passed), Failed: $($summary.Failed)"
```

#### Merge-ParallelTestResults
Merges results from parallel Pester test execution.

```powershell
Merge-ParallelTestResults [-TestResults <object[]>]
```

**Parameters:**
- `TestResults` (object[]): Array of test result objects from parallel execution

**Returns:** Aggregated test summary object

#### Get-OptimalThrottleLimit
Calculates the optimal throttle limit based on system resources and workload type.

```powershell
Get-OptimalThrottleLimit [-WorkloadType <string>] [-MaxLimit <int>] [-SystemLoadFactor <double>]
```

**Parameters:**
- `WorkloadType` (string): Type of workload - CPU, IO, Network, or Mixed. Default: Mixed
- `MaxLimit` (int): Maximum throttle limit to consider. Default: 32
- `SystemLoadFactor` (double): Factor to reduce parallelism based on system load (0.1-1.0). Default: 1.0

**Returns:** Optimal throttle limit for the specified workload

#### Measure-ParallelPerformance
Measures and analyzes performance of parallel operations.

```powershell
Measure-ParallelPerformance -OperationName <string> -StartTime <DateTime> -EndTime <DateTime> -ItemCount <int> -ThrottleLimit <int>
```

**Parameters:**
- `OperationName` (string, required): Name of the operation being measured
- `StartTime` (DateTime, required): Start time of the operation
- `EndTime` (DateTime, required): End time of the operation
- `ItemCount` (int, required): Number of items processed
- `ThrottleLimit` (int, required): Throttle limit used for the operation

**Returns:** Performance metrics object with throughput, efficiency, and timing data

#### Start-AdaptiveParallelExecution
Executes operations with adaptive throttling based on real-time performance.

```powershell
Start-AdaptiveParallelExecution -InputObject <object[]> -ScriptBlock <scriptblock> [-InitialThrottle <int>] [-MaxThrottle <int>] [-AdaptationInterval <int>]
```

**Parameters:**
- `InputObject` (object[], required): Collection of items to process
- `ScriptBlock` (scriptblock, required): Script block to execute for each item
- `InitialThrottle` (int): Initial throttle limit. Default: CPU count
- `MaxThrottle` (int): Maximum throttle limit. Default: CPU count * 2
- `AdaptationInterval` (int): Interval in seconds for throttle adaptation. Default: 5

**Returns:** Array of results from adaptive parallel execution

**Example:**
```powershell
# Run tests and merge results
$results = Invoke-ParallelPesterTests -TestPaths @(
    "./tests/Core.Tests.ps1",
    "./tests/Modules.Tests.ps1",
    "./tests/Integration.Tests.ps1"
)

$summary = Merge-ParallelTestResults -TestResults $results

# Display summary
Write-Host "Test Execution Summary:"
Write-Host "  Total Tests: $($summary.TotalTests)"
Write-Host "  Passed: $($summary.Passed)"
Write-Host "  Failed: $($summary.Failed)"
Write-Host "  Skipped: $($summary.Skipped)"
Write-Host "  Duration: $($summary.TotalTime)"

if ($summary.Failed -gt 0) {
    Write-Host "`nFailures:"
    $summary.Failures | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.ErrorRecord.Exception.Message)"
    }
}
```

## Core Concepts

### Parallel Execution Models

#### ForEach-Object -Parallel
The module uses PowerShell 7.0+'s native parallel foreach:
- **Thread-based parallelism** for efficient resource usage
- **Automatic work distribution** across available threads
- **Shared variable access** with proper synchronization
- **Streaming results** as operations complete

#### PowerShell Jobs
Background job execution for long-running operations:
- **Process isolation** for stability
- **Independent execution** contexts
- **Resource monitoring** and control
- **Result persistence** across sessions

### Throttling and Resource Management

The module implements intelligent throttling:
- **CPU-based defaults**: Uses processor count for optimal parallelism
- **Configurable limits**: Override based on workload characteristics
- **Dynamic adjustment**: Responds to system load
- **Memory protection**: Prevents resource exhaustion

### Error Handling and Recovery

Comprehensive error handling strategies:
- **Individual operation isolation**: Failures don't affect other operations
- **Error aggregation**: Collect all errors for reporting
- **Timeout protection**: Prevent indefinite execution
- **Graceful degradation**: Continue processing on partial failures

## Usage Patterns

### Common Usage Scenarios

#### File Processing
```powershell
# Process large file sets in parallel
$csvFiles = Get-ChildItem -Path "C:\Data" -Filter "*.csv" -Recurse

$processedData = Invoke-ParallelForEach -InputObject $csvFiles -ScriptBlock {
    param($file)
    $data = Import-Csv -Path $file.FullName
    $processed = $data | Where-Object { $_.Status -eq "Active" } |
                        Select-Object Name, Date, Amount
    return @{
        FileName = $file.Name
        RecordCount = $data.Count
        ProcessedCount = $processed.Count
        Data = $processed
    }
} -ThrottleLimit 10

# Aggregate results
$totalRecords = ($processedData.RecordCount | Measure-Object -Sum).Sum
$totalProcessed = ($processedData.ProcessedCount | Measure-Object -Sum).Sum
```

#### Multi-Server Operations
```powershell
# Execute commands on multiple servers
$servers = Get-Content ".\servers.txt"
$jobs = @()

foreach ($server in $servers) {
    $jobs += Start-ParallelJob -Name "HealthCheck-$server" -ScriptBlock {
        param($computerName)
        $result = Test-Connection -ComputerName $computerName -Count 1 -Quiet
        $services = Get-Service -ComputerName $computerName -Name "W3SVC", "MSSQLSERVER" -ErrorAction SilentlyContinue
        
        return @{
            Server = $computerName
            Online = $result
            Services = $services | Select-Object Name, Status
            Timestamp = Get-Date
        }
    } -ArgumentList $server
}

$healthResults = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 300 -ShowProgress

# Generate report
$healthResults | ForEach-Object {
    if ($_.State -eq "Completed") {
        $data = $_.Result
        Write-Host "$($data.Server): $(if ($data.Online) { 'Online' } else { 'Offline' })"
    }
}
```

#### Parallel Testing Strategy
```powershell
# Organize tests by execution time for optimal parallelization
$unitTests = Get-ChildItem "./tests/Unit/*.Tests.ps1"
$integrationTests = Get-ChildItem "./tests/Integration/*.Tests.ps1"
$e2eTests = Get-ChildItem "./tests/E2E/*.Tests.ps1"

# Run fast unit tests with high parallelism
$unitResults = Invoke-ParallelPesterTests -TestPaths $unitTests -ThrottleLimit 8

# Run integration tests with moderate parallelism
$integResults = Invoke-ParallelPesterTests -TestPaths $integrationTests -ThrottleLimit 4

# Run E2E tests with low parallelism to avoid conflicts
$e2eResults = Invoke-ParallelPesterTests -TestPaths $e2eTests -ThrottleLimit 2

# Merge all results
$allResults = Merge-ParallelTestResults -TestResults ($unitResults + $integResults + $e2eResults)
```

### Integration Examples

#### With Logging Module
```powershell
# Parallel operations with centralized logging
Import-Module ./aither-core/modules/Logging -Force
Import-Module ./aither-core/modules/ParallelExecution -Force

$items = 1..20
$results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
    param($item)
    
    # Each parallel thread can log independently
    Write-CustomLog -Message "Processing item $item" -Level "INFO"
    
    try {
        # Simulate work
        Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)
        
        if ($item % 5 -eq 0) {
            throw "Simulated error for item $item"
        }
        
        Write-CustomLog -Message "Completed item $item" -Level "SUCCESS"
        return "Processed: $item"
    } catch {
        Write-CustomLog -Message "Error processing item $item" -Level "ERROR" -Exception $_.Exception
        throw
    }
} -ThrottleLimit 5
```

#### With OrchestrationEngine
```powershell
# Parallel step in orchestration playbook
$parallelStep = @{
    name = "Deploy to All Regions"
    type = "parallel"
    parallel = @(
        @{ name = "Deploy US-East"; type = "script"; command = "Deploy-Region -Region us-east-1" }
        @{ name = "Deploy US-West"; type = "script"; command = "Deploy-Region -Region us-west-2" }
        @{ name = "Deploy EU"; type = "script"; command = "Deploy-Region -Region eu-west-1" }
        @{ name = "Deploy APAC"; type = "script"; command = "Deploy-Region -Region ap-southeast-1" }
    )
}

# The OrchestrationEngine will use ParallelExecution module automatically
```

### Best Practices

1. **Choose appropriate throttle limits** based on operation type:
   - CPU-intensive: Use CPU count
   - I/O-intensive: Can use higher limits (2-3x CPU count)
   - Network operations: Limit to avoid overwhelming targets

2. **Handle errors gracefully** in parallel operations:
   ```powershell
   $results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
       try {
           # Operation
       } catch {
           return @{ Success = $false; Error = $_.Exception.Message }
       }
       return @{ Success = $true; Data = $result }
   }
   ```

3. **Monitor resource usage** during parallel execution:
   ```powershell
   $jobs = Start-ParallelJob -Name "HeavyOperation" -ScriptBlock { ... }
   while ($jobs.State -eq "Running") {
       $cpu = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
       Write-Host "CPU Usage: $([math]::Round($cpu, 2))%"
       Start-Sleep -Seconds 1
   }
   ```

4. **Use timeout protection** for unreliable operations:
   ```powershell
   $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 120
   $timedOut = $results | Where-Object { $_.State -eq "Timeout" }
   if ($timedOut) {
       Write-Warning "Operations timed out: $($timedOut.Name -join ', ')"
   }
   ```

5. **Aggregate results properly** for reporting:
   ```powershell
   $results = Invoke-ParallelForEach -InputObject $servers -ScriptBlock { ... }
   $summary = $results | Group-Object Status | ForEach-Object {
       @{ Status = $_.Name; Count = $_.Count }
   }
   ```

## Performance Optimization Guide

### Workload-Specific Throttle Limits

Choose the appropriate workload type for optimal performance:

```powershell
# CPU-intensive operations (mathematical calculations, data processing)
$cpuOptimal = Get-OptimalThrottleLimit -WorkloadType "CPU"
# Result: Typically equals CPU core count

# I/O-intensive operations (file operations, database queries)
$ioOptimal = Get-OptimalThrottleLimit -WorkloadType "IO"
# Result: Typically 2x CPU core count

# Network-intensive operations (web requests, API calls)
$networkOptimal = Get-OptimalThrottleLimit -WorkloadType "Network"
# Result: Typically 3x CPU core count (up to MaxLimit)

# Mixed workloads (combination of CPU, I/O, and network)
$mixedOptimal = Get-OptimalThrottleLimit -WorkloadType "Mixed"
# Result: Typically 1.5x CPU core count
```

### Performance Measurement and Analysis

```powershell
# Measure performance of parallel operations
$startTime = Get-Date
$results = Invoke-ParallelForEach -InputObject $largeDataset -ScriptBlock {
    param($item)
    Process-DataItem $item
} -ThrottleLimit $optimalThrottle
$endTime = Get-Date

# Analyze performance metrics
$metrics = Measure-ParallelPerformance -OperationName "DataProcessing" -StartTime $startTime -EndTime $endTime -ItemCount $largeDataset.Count -ThrottleLimit $optimalThrottle

Write-Host "Throughput: $($metrics.ThroughputPerSecond) items/sec"
Write-Host "Efficiency Ratio: $($metrics.EfficiencyRatio)"
Write-Host "Parallel Speedup: $($metrics.ParallelSpeedup)x"
```

### Adaptive Execution for Dynamic Workloads

```powershell
# For workloads with varying complexity, use adaptive execution
$results = Start-AdaptiveParallelExecution -InputObject $variableComplexityItems -ScriptBlock {
    param($item)
    if ($item.Complexity -eq "High") {
        # CPU-intensive processing
        Invoke-ComplexCalculation $item
    } else {
        # Simple processing
        Invoke-SimpleTransformation $item
    }
} -InitialThrottle 4 -MaxThrottle 16

# The system will automatically adjust throttle limits based on performance
```

### System Load Considerations

```powershell
# Adjust throttle limits based on current system load
function Get-SystemLoadFactor {
    $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
    
    if ($cpuUsage -gt 80) {
        return 0.5  # Reduce parallelism on high load
    } elseif ($cpuUsage -gt 60) {
        return 0.75  # Moderate reduction
    } else {
        return 1.0   # Full parallelism
    }
}

$loadFactor = Get-SystemLoadFactor
$throttle = Get-OptimalThrottleLimit -WorkloadType "Mixed" -SystemLoadFactor $loadFactor
```

## Advanced Features

### Dynamic Script Block Handling

The module intelligently handles different script block patterns:

```powershell
# Parameter-based script block
$paramScript = {
    param($item)
    "Processing: $item"
}

# Pipeline-based script block
$pipelineScript = {
    "Processing: $_"
}

# Both work with Invoke-ParallelForEach
$results1 = Invoke-ParallelForEach -InputObject $items -ScriptBlock $paramScript
$results2 = Invoke-ParallelForEach -InputObject $items -ScriptBlock $pipelineScript
```

### Job State Management

Comprehensive job state tracking:
- **Running**: Currently executing
- **Completed**: Successfully finished
- **Failed**: Execution error occurred
- **Stopped**: Manually terminated
- **Timeout**: Exceeded time limit

```powershell
$results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 300

$summary = $results | Group-Object State | ForEach-Object {
    Write-Host "$($_.Name): $($_.Count) jobs"
}

# Detailed error analysis
$failed = $results | Where-Object { $_.HasErrors }
$failed | ForEach-Object {
    Write-Host "Job $($_.Name) errors:"
    $_.Errors | ForEach-Object { Write-Host "  - $_" }
}
```

### Progress Monitoring

Real-time progress tracking for long operations:

```powershell
# With progress bar
$results = Wait-ParallelJobs -Jobs $jobs -ShowProgress

# Custom progress monitoring
$jobs = Start-ParallelJob -Name "LongOperation" -ScriptBlock { ... }
while ($jobs | Where-Object { $_.State -eq "Running" }) {
    $completed = ($jobs | Where-Object { $_.State -ne "Running" }).Count
    $percent = ($completed / $jobs.Count) * 100
    Write-Progress -Activity "Processing" -PercentComplete $percent
    Start-Sleep -Seconds 1
}
```

## Real-World Use Cases

### Large-Scale File Processing

```powershell
# Process thousands of log files efficiently
$logFiles = Get-ChildItem -Path "C:\Logs" -Filter "*.log" -Recurse
$throttle = Get-OptimalThrottleLimit -WorkloadType "IO" -MaxLimit 20

$results = Invoke-ParallelForEach -InputObject $logFiles -ScriptBlock {
    param($file)
    $errors = Select-String -Path $file.FullName -Pattern "ERROR|CRITICAL"
    return @{
        File = $file.Name
        Size = $file.Length
        ErrorCount = $errors.Count
        LastModified = $file.LastWriteTime
    }
} -ThrottleLimit $throttle

# Aggregate results
$totalErrors = ($results.ErrorCount | Measure-Object -Sum).Sum
$totalSize = ($results.Size | Measure-Object -Sum).Sum
Write-Host "Processed $($results.Count) files, found $totalErrors errors in $([Math]::Round($totalSize/1MB, 2)) MB"
```

### Distributed Web Scraping

```powershell
# Scrape multiple websites with rate limiting
$urls = Get-Content "urls.txt"
$throttle = Get-OptimalThrottleLimit -WorkloadType "Network" -MaxLimit 10

$scrapingResults = Invoke-ParallelForEach -InputObject $urls -ScriptBlock {
    param($url)
    try {
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 30
        $title = ($response.Content | Select-String '<title>(.*?)</title>').Matches[0].Groups[1].Value
        
        return @{
            Url = $url
            Title = $title
            StatusCode = $response.StatusCode
            ContentLength = $response.Content.Length
            Success = $true
        }
    } catch {
        return @{
            Url = $url
            Error = $_.Exception.Message
            Success = $false
        }
    }
} -ThrottleLimit $throttle

# Report results
$successful = $scrapingResults | Where-Object { $_.Success }
Write-Host "Successfully scraped $($successful.Count) of $($urls.Count) URLs"
```

### Parallel Database Operations

```powershell
# Process database records in parallel batches
$recordIds = 1..10000
$batchSize = 100
$batches = for ($i = 0; $i -lt $recordIds.Count; $i += $batchSize) {
    $recordIds[$i..([Math]::Min($i + $batchSize - 1, $recordIds.Count - 1))]
}

$results = Invoke-ParallelForEach -InputObject $batches -ScriptBlock {
    param($batch)
    $connection = New-SqlConnection -Server "DBServer" -Database "AppDB"
    $processedCount = 0
    
    foreach ($id in $batch) {
        try {
            Invoke-SqlUpdate -Connection $connection -Query "UPDATE Records SET Status = 'Processed' WHERE Id = $id"
            $processedCount++
        } catch {
            Write-Warning "Failed to process record $id : $($_.Exception.Message)"
        }
    }
    
    $connection.Close()
    return @{
        BatchSize = $batch.Count
        ProcessedCount = $processedCount
        FailedCount = $batch.Count - $processedCount
    }
} -ThrottleLimit 5  # Limited to avoid overwhelming database

# Aggregate batch results
$totalProcessed = ($results.ProcessedCount | Measure-Object -Sum).Sum
$totalFailed = ($results.FailedCount | Measure-Object -Sum).Sum
Write-Host "Database update complete: $totalProcessed successful, $totalFailed failed"
```

## Configuration

### Module-Specific Settings

Control parallel execution behavior:

```powershell
# Set default throttle limit based on workload
$cpuCount = [Environment]::ProcessorCount
$defaultThrottle = if ($isIOBound) { $cpuCount * 2 } else { $cpuCount }

# Configure timeouts based on operation type
$timeout = switch ($operationType) {
    "Quick"    { 60 }
    "Normal"   { 300 }
    "Extended" { 1800 }
    default    { 300 }
}
```

### Customization Options

1. **Throttle limit strategies**:
   - Fixed: Specific number of threads
   - Dynamic: Based on system load
   - Adaptive: Adjust during execution

2. **Timeout policies**:
   - Per-operation timeouts
   - Global execution limits
   - No timeout for trusted operations

3. **Result handling**:
   - Stream results as available
   - Batch collection
   - Custom aggregation

### Performance Tuning Parameters

#### CPU-Bound Operations
```powershell
# Optimal for computation
$results = Invoke-ParallelForEach -InputObject $data -ScriptBlock {
    # Heavy computation
} -ThrottleLimit ([Environment]::ProcessorCount)
```

#### I/O-Bound Operations
```powershell
# Higher parallelism for I/O waits
$results = Invoke-ParallelForEach -InputObject $files -ScriptBlock {
    # File/Network operations
} -ThrottleLimit ([Environment]::ProcessorCount * 3)
```

#### Memory-Intensive Operations
```powershell
# Lower parallelism to avoid memory pressure
$results = Invoke-ParallelForEach -InputObject $largeDatesets -ScriptBlock {
    # Memory-intensive processing
} -ThrottleLimit ([Math]::Max(2, [Environment]::ProcessorCount / 2))
```

## Error Handling and Recovery

### Error Isolation

Each parallel operation is isolated:

```powershell
$results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
    param($item)
    try {
        # Operation that might fail
        if ($item.IsValid) {
            Process-Item $item
        } else {
            throw "Invalid item: $($item.Name)"
        }
    } catch {
        # Return error info instead of throwing
        return @{
            Item = $item
            Success = $false
            Error = $_.Exception.Message
        }
    }
    return @{
        Item = $item
        Success = $true
        Result = $processedData
    }
}

# Separate successes and failures
$successes = $results | Where-Object { $_.Success }
$failures = $results | Where-Object { -not $_.Success }
```

### Timeout Recovery

Handle operations that exceed time limits:

```powershell
$jobs = @()
$servers | ForEach-Object {
    $jobs += Start-ParallelJob -Name "Backup-$_" -ScriptBlock {
        param($server)
        Backup-Server -ComputerName $server -Timeout 600
    } -ArgumentList $_
}

$results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 900

# Handle timeouts
$timedOut = $results | Where-Object { $_.State -eq "Timeout" }
if ($timedOut) {
    Write-Warning "Servers timed out: $($timedOut.Name -join ', ')"
    
    # Attempt recovery
    $timedOut | ForEach-Object {
        $server = $_.Name -replace "Backup-", ""
        Write-Host "Attempting quick backup for $server"
        Backup-Server -ComputerName $server -Quick
    }
}
```

### Resource Cleanup

Ensure proper cleanup after parallel operations:

```powershell
$jobs = @()
try {
    # Start jobs
    $items | ForEach-Object {
        $jobs += Start-ParallelJob -Name "Process-$_" -ScriptBlock { ... }
    }
    
    # Wait for completion
    $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 600
    
} finally {
    # Ensure all jobs are cleaned up
    $jobs | Where-Object { $_.State -eq "Running" } | Stop-Job
    $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
}
```

## Troubleshooting Guide

### Common Issues and Solutions

#### High Memory Usage

**Problem:** Parallel execution consumes too much memory

**Solutions:**
```powershell
# Reduce throttle limit for memory-intensive operations
$memoryOptimal = Get-OptimalThrottleLimit -WorkloadType "CPU" -SystemLoadFactor 0.5

# Use smaller batch sizes for large datasets
$results = Start-AdaptiveParallelExecution -InputObject $largeDataset -ScriptBlock {
    param($item)
    # Process item and immediately release memory
    $result = Process-Item $item
    [System.GC]::Collect()  # Force garbage collection if needed
    return $result
} -InitialThrottle 2 -MaxThrottle 4
```

#### Poor Performance on I/O Operations

**Problem:** Parallel I/O operations are slower than expected

**Solutions:**
```powershell
# Increase throttle limit for I/O-bound operations
$ioThrottle = Get-OptimalThrottleLimit -WorkloadType "IO"

# Consider using adaptive execution for mixed workloads
$results = Start-AdaptiveParallelExecution -InputObject $files -ScriptBlock {
    param($file)
    # I/O operation will benefit from higher parallelism
    Copy-Item -Path $file.SourcePath -Destination $file.DestinationPath
} -InitialThrottle $ioThrottle -MaxThrottle ($ioThrottle * 2)
```

#### Timeout Issues

**Problem:** Operations timeout prematurely

**Solutions:**
```powershell
# Increase timeout for long-running operations
$results = Invoke-ParallelForEach -InputObject $items -ScriptBlock {
    param($item)
    # Long-running operation
    Invoke-ComplexProcessing $item
} -TimeoutSeconds 1800  # 30 minutes

# Or use background jobs for extremely long operations
$jobs = $items | ForEach-Object {
    Start-ParallelJob -Name "Process_$($_.Id)" -ScriptBlock {
        param($item)
        Invoke-VeryLongProcess $item
    } -ArgumentList $_
}
$results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 7200  # 2 hours
```

### Performance Monitoring

```powershell
# Monitor system resources during parallel execution
function Monitor-ParallelExecution {
    param($ScriptBlock, $InputObject, $ThrottleLimit)
    
    $startTime = Get-Date
    $initialMemory = [System.GC]::GetTotalMemory($false)
    
    # Execute parallel operation
    $results = Invoke-ParallelForEach -InputObject $InputObject -ScriptBlock $ScriptBlock -ThrottleLimit $ThrottleLimit
    
    $endTime = Get-Date
    $finalMemory = [System.GC]::GetTotalMemory($true)
    
    # Calculate metrics
    $metrics = Measure-ParallelPerformance -OperationName "MonitoredExecution" -StartTime $startTime -EndTime $endTime -ItemCount $InputObject.Count -ThrottleLimit $ThrottleLimit
    
    # Add memory metrics
    $metrics | Add-Member -NotePropertyName "MemoryUsed" -NotePropertyValue ($finalMemory - $initialMemory)
    $metrics | Add-Member -NotePropertyName "MemoryPerItem" -NotePropertyValue (($finalMemory - $initialMemory) / $InputObject.Count)
    
    return @{
        Results = $results
        Metrics = $metrics
    }
}

# Usage
$execution = Monitor-ParallelExecution -ScriptBlock { param($item) Process-Item $item } -InputObject $items -ThrottleLimit 8
Write-Host "Memory used: $([Math]::Round($execution.Metrics.MemoryUsed / 1MB, 2)) MB"
Write-Host "Memory per item: $([Math]::Round($execution.Metrics.MemoryPerItem / 1KB, 2)) KB"
```

## Testing with ParallelExecution

### Comprehensive Test Suite

The module includes 37 comprehensive test cases covering:

- **Basic functionality**: Module import, function export, parameter validation
- **Parallel execution**: ForEach-Object operations, throttle limits, timeout handling
- **Job management**: Background job creation, monitoring, cleanup
- **Error handling**: Timeout recovery, error isolation, resource cleanup
- **Performance testing**: Large workloads, memory management, throughput analysis
- **Advanced features**: Adaptive execution, optimal throttle calculation, performance metrics

```powershell
# Run the complete test suite
Invoke-Pester -Path "./aither-core/modules/ParallelExecution/tests/ParallelExecution.Tests.ps1" -Output Detailed
```

### Parallel Test Execution

Optimize test runtime with parallel execution:

```powershell
# Group tests by type for optimal parallelization
$testGroups = @{
    Unit = Get-ChildItem "./tests/Unit/*.Tests.ps1"
    Integration = Get-ChildItem "./tests/Integration/*.Tests.ps1"
    Performance = Get-ChildItem "./tests/Performance/*.Tests.ps1"
}

$allResults = @()
foreach ($group in $testGroups.GetEnumerator()) {
    Write-Host "Running $($group.Key) tests in parallel..."
    
    # Adjust throttle based on test type
    $throttle = switch ($group.Key) {
        "Unit" { 8 }         # High parallelism for isolated tests
        "Integration" { 4 }  # Moderate for shared resources
        "Performance" { 2 }  # Low to avoid interference
    }
    
    $results = Invoke-ParallelPesterTests `
        -TestPaths $group.Value `
        -ThrottleLimit $throttle `
        -OutputFormat "Minimal"
    
    $allResults += $results
}

# Generate comprehensive report
$summary = Merge-ParallelTestResults -TestResults $allResults
```

### Test Result Analysis

Analyze parallel test execution results:

```powershell
# Identify slow tests
$results | ForEach-Object {
    if ($_.Result.TotalTime -gt [TimeSpan]::FromSeconds(10)) {
        Write-Warning "Slow test file: $($_.Name) took $($_.Result.TotalTime)"
    }
}

# Find flaky tests
$failurePatterns = $results | 
    Where-Object { $_.Result.Failed.Count -gt 0 } |
    ForEach-Object {
        $_.Result.Failed | Select-Object @{
            Name = "Test"
            Expression = { $_.Name }
        }, @{
            Name = "File"
            Expression = { $_.Result.File }
        }
    } |
    Group-Object Test |
    Where-Object { $_.Count -gt 1 }

if ($failurePatterns) {
    Write-Warning "Potentially flaky tests detected:"
    $failurePatterns | ForEach-Object {
        Write-Warning "  - $($_.Name): Failed $($_.Count) times"
    }
}
```