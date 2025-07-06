#Requires -Version 7.0

<#
.SYNOPSIS
Parallel execution utilities for OpenTofu Lab Automation

.DESCRIPTION
This module provides cross-platform parallel processing capabilities for PowerShell scripts,
including parallel test execution, job management, and result aggregation.

.NOTES
- Compatible with PowerShell 7.0+ on Windows, Linux, and macOS
- Optimized for CPU-intensive and I/O-intensive workloads
- Integrated with Pester for parallel test execution
- Follows PowerShell 7.0+ cross-platform standards
#>

# Robust project root detection using shared utility
$findProjectRootPath = Join-Path $PSScriptRoot "../../shared/Find-ProjectRoot.ps1"
if (Test-Path $findProjectRootPath) {
    . $findProjectRootPath
    $script:ProjectRoot = Find-ProjectRoot
} else {
    # Fallback: basic upward traversal
    $script:ProjectRoot = $PSScriptRoot
    while ($script:ProjectRoot -and -not (Test-Path (Join-Path $script:ProjectRoot "aither-core"))) {
        $parent = Split-Path $script:ProjectRoot -Parent
        if ($parent -eq $script:ProjectRoot) { break }
        $script:ProjectRoot = $parent
    }
}

# Import the centralized Logging module
$loggingImported = $false

# Check if Logging module is already available
if (Get-Module -Name 'Logging' -ErrorAction SilentlyContinue) {
    $loggingImported = $true
    Write-Verbose "Logging module already available"
} else {
    # Robust path resolution using project root
    $loggingPaths = @(
        'Logging',  # Try module name first (if in PSModulePath)
        (Join-Path (Split-Path $PSScriptRoot -Parent) "Logging"),  # Relative to modules directory
        (Join-Path $script:ProjectRoot "aither-core/modules/Logging")  # Project root based path
    )

    # Add environment-based paths if available
    if ($env:PWSH_MODULES_PATH) {
        $loggingPaths += (Join-Path $env:PWSH_MODULES_PATH "Logging")
    }
    if ($env:PROJECT_ROOT) {
        $loggingPaths += (Join-Path $env:PROJECT_ROOT "aither-core/modules/Logging")
    }

    foreach ($loggingPath in $loggingPaths) {
        if ($loggingImported) { break }

        try {
            if ($loggingPath -eq 'Logging') {
                Import-Module 'Logging' -Global -ErrorAction Stop
            } elseif (Test-Path $loggingPath) {
                Import-Module $loggingPath -Global -ErrorAction Stop
            } else {
                continue
            }
            Write-Verbose "Successfully imported Logging module from: $loggingPath"
            $loggingImported = $true
        } catch {
            Write-Verbose "Failed to import Logging from $loggingPath : $_"
        }
    }
}

if (-not $loggingImported) {
    Write-Warning "Could not import Logging module from any of the attempted paths"
    # Fallback logging function
    function Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
}

function Invoke-ParallelForEach {
    <#
    .SYNOPSIS
    Executes a script block in parallel across multiple items

    .DESCRIPTION
    Provides a cross-platform parallel foreach implementation using PowerShell 7.0+ ForEach-Object -Parallel

    .PARAMETER InputObject
    The collection of items to process in parallel

    .PARAMETER ScriptBlock
    The script block to execute for each item

    .PARAMETER ThrottleLimit
    Maximum number of parallel threads (default: processor count)

    .PARAMETER TimeoutSeconds
    Timeout for the entire operation in seconds (default: 300)

    .EXAMPLE
    $files = Get-ChildItem *.ps1
    $results = Invoke-ParallelForEach -InputObject $files -ScriptBlock {
        param($file)
        Invoke-ScriptAnalyzer -Path $file.FullName
    }

    .NOTES
    Uses PowerShell 7.0+ native parallel processing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [object[]]$InputObject = @(),

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = [Environment]::ProcessorCount,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300
    )

    begin {
        Write-CustomLog "Starting parallel execution with throttle limit: $ThrottleLimit" -Level "INFO"
        $items = @()
    }

    process {
        if ($InputObject) {
            $items += $InputObject
        }
    }

    end {
        if ($items.Count -eq 0) {
            Write-CustomLog "No items to process" -Level "INFO"
            return @()
        }

        try {
            $startTime = Get-Date
            
            # Convert the scriptblock to handle both parameter-based and $_ based invocations
            $scriptText = $ScriptBlock.ToString()
            
            # Check if the scriptblock expects a parameter
            if ($scriptText -match 'param\s*\(') {
                # Wrap to pass $_ as the first parameter
                $parallelScript = [scriptblock]::Create(@"
                    `$___item = `$_
                    & { $scriptText } `$___item
"@)
            } else {
                # Use the original scriptblock as-is (it will use $_)
                $parallelScript = $ScriptBlock
            }
            
            # Use timeout with a try-catch to handle timeout properly
            try {
                $results = $items | ForEach-Object -Parallel $parallelScript -ThrottleLimit $ThrottleLimit -TimeoutSeconds $TimeoutSeconds
            } catch [System.Management.Automation.RuntimeException] {
                if ($_.Exception.Message -match "timeout") {
                    Write-CustomLog "Parallel execution timed out after $TimeoutSeconds seconds" -Level "ERROR"
                    throw "Parallel execution timeout: Operation exceeded $TimeoutSeconds seconds"
                } else {
                    throw
                }
            }

            $duration = (Get-Date) - $startTime
            Write-CustomLog "Parallel execution completed in $($duration.TotalSeconds) seconds" -Level "SUCCESS"

            return $results
        }
        catch {
            Write-CustomLog "Parallel execution failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Start-ParallelJob {
    <#
    .SYNOPSIS
    Starts a background job for parallel execution

    .DESCRIPTION
    Creates and starts a PowerShell background job with proper error handling and logging

    .PARAMETER Name
    Name of the job for identification

    .PARAMETER ScriptBlock
    Script block to execute in the background job

    .PARAMETER ArgumentList
    Arguments to pass to the script block

    .EXAMPLE
    $job = Start-ParallelJob -Name "TestValidation" -ScriptBlock {
        param($path)
        Invoke-Pester -Path $path
    } -ArgumentList @("./tests")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [object[]]$ArgumentList = @()
    )

    try {
        Write-CustomLog "Starting background job: $Name" -Level "INFO"

        $job = Start-Job -Name $Name -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList

        Write-CustomLog "Job started successfully: $Name (ID: $($job.Id))" -Level "SUCCESS"
        return $job
    }
    catch {
        Write-CustomLog "Failed to start job $Name : $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Wait-ParallelJobs {
    <#
    .SYNOPSIS
    Waits for multiple parallel jobs to complete

    .DESCRIPTION
    Monitors and waits for background jobs with timeout and progress reporting

    .PARAMETER Jobs
    Array of job objects to wait for

    .PARAMETER TimeoutSeconds
    Maximum time to wait for all jobs to complete

    .PARAMETER ShowProgress
    Whether to show progress while waiting

    .EXAMPLE
    $jobs = @($job1, $job2, $job3)
    $results = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds 600 -ShowProgress
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Job[]]$Jobs,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600,

        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress
    )

    try {
        $startTime = Get-Date
        $results = @{}

        Write-CustomLog "Waiting for $($Jobs.Count) jobs to complete (timeout: $TimeoutSeconds seconds)" -Level "INFO"
          do {
            $runningJobs = $Jobs | Where-Object { $_.State -eq 'Running' }
            $completedJobs = $Jobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }

            if ($ShowProgress) {
                $percentComplete = [math]::Round(($completedJobs.Count / $Jobs.Count) * 100, 1)
                Write-Progress -Activity "Waiting for parallel jobs" -Status "$($completedJobs.Count)/$($Jobs.Count) completed" -PercentComplete $percentComplete
            }

            # Check for completed jobs and collect results
            foreach ($job in ($Jobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') })) {
                if (-not $results.ContainsKey($job.Id)) {
                    $jobResult = Receive-Job -Job $job -Keep
                    $hasErrors = $false
                    $jobErrors = @()
                    
                    # Check for errors in different ways depending on job structure
                    if ($job.ChildJobs -and $job.ChildJobs.Count -gt 0) {
                        $hasErrors = $job.ChildJobs[0].Error.Count -gt 0
                        $jobErrors = $job.ChildJobs[0].Error
                    } elseif ($job.State -eq 'Failed') {
                        $hasErrors = $true
                        $jobErrors = @("Job failed with state: $($job.State)")
                    }
                    
                    $results[$job.Id] = @{
                        Name = $job.Name
                        State = $job.State
                        Result = $jobResult
                        HasErrors = $hasErrors
                        Errors = $jobErrors
                    }

                    if ($job.State -eq 'Failed') {
                        Write-CustomLog "Job failed: $($job.Name)" -Level "ERROR"
                    } else {
                        Write-CustomLog "Job completed: $($job.Name)" -Level "SUCCESS"
                    }
                }
            }

            # Check timeout
            $elapsed = (Get-Date) - $startTime
            if ($elapsed.TotalSeconds -gt $TimeoutSeconds) {
                Write-CustomLog "Timeout reached after $($elapsed.TotalSeconds) seconds" -Level "WARN"
                # For timeout, still add running jobs to results
                foreach ($job in $runningJobs) {
                    if (-not $results.ContainsKey($job.Id)) {
                        $results[$job.Id] = @{
                            Name = $job.Name
                            State = 'Timeout'
                            Result = $null
                            HasErrors = $false
                            Errors = @()
                        }
                    }
                }
                break
            }

            if ($runningJobs.Count -gt 0) {
                Start-Sleep -Seconds 1
            }

        } while ($runningJobs.Count -gt 0)

        if ($ShowProgress) {
            Write-Progress -Activity "Waiting for parallel jobs" -Completed
        }

        # Clean up jobs
        $Jobs | Remove-Job -Force -ErrorAction SilentlyContinue

        $duration = (Get-Date) - $startTime
        Write-CustomLog "All jobs completed in $($duration.TotalSeconds) seconds" -Level "SUCCESS"

        return $results.Values
    }
    catch {
        Write-CustomLog "Error waiting for parallel jobs: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Invoke-ParallelPesterTests {
    <#
    .SYNOPSIS
    Runs Pester tests in parallel for improved performance

    .DESCRIPTION
    Executes Pester tests across multiple test files in parallel, aggregating results

    .PARAMETER TestPaths
    Array of test file paths or directories to test

    .PARAMETER ThrottleLimit
    Maximum number of parallel test jobs

    .PARAMETER OutputFormat
    Pester output format (Detailed, Normal, Minimal)

    .EXAMPLE
    $results = Invoke-ParallelPesterTests -TestPaths @("./tests/Module1.Tests.ps1", "./tests/Module2.Tests.ps1")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TestPaths,

        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit = [Environment]::ProcessorCount,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Detailed', 'Normal', 'Minimal')]
        [string]$OutputFormat = 'Normal'
    )

    try {
        Write-CustomLog "Starting parallel Pester tests for $($TestPaths.Count) paths" -Level "INFO"

        $jobs = @()
        foreach ($testPath in $TestPaths) {
            $jobName = "PesterTest_$(Split-Path $testPath -Leaf)"
            $job = Start-ParallelJob -Name $jobName -ScriptBlock {
                param($path, $output)
                Import-Module Pester -Force
                Invoke-Pester -Path $path -Output $output -PassThru
            } -ArgumentList @($testPath, $OutputFormat)

            $jobs += $job

            # Throttle job creation
            if ($jobs.Count -ge $ThrottleLimit) {
                $completedJobs = $jobs | Where-Object { $_.State -ne 'Running' }
                if ($completedJobs.Count -eq 0) {
                    # Wait for at least one job to complete
                    Wait-Job -Job $jobs[0] | Out-Null
                }
            }
        }

        Write-CustomLog "All test jobs started, waiting for completion..." -Level "INFO"
        $results = Wait-ParallelJobs -Jobs $jobs -ShowProgress

        return $results
    }
    catch {
        Write-CustomLog "Parallel Pester execution failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Get-OptimalThrottleLimit {
    <#
    .SYNOPSIS
    Calculates the optimal throttle limit based on system resources and workload type
    
    .DESCRIPTION
    Analyzes system CPU, memory, and workload characteristics to determine the optimal
    number of parallel threads for maximum performance without resource exhaustion
    
    .PARAMETER WorkloadType
    Type of workload: CPU, IO, Network, or Mixed
    
    .PARAMETER MaxLimit
    Maximum throttle limit to consider
    
    .PARAMETER SystemLoadFactor
    Factor to reduce parallelism based on current system load (0.1 to 1.0)
    
    .EXAMPLE
    $optimal = Get-OptimalThrottleLimit -WorkloadType "IO" -MaxLimit 20
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('CPU', 'IO', 'Network', 'Mixed')]
        [string]$WorkloadType = 'Mixed',
        
        [Parameter(Mandatory = $false)]
        [int]$MaxLimit = 32,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(0.1, 1.0)]
        [double]$SystemLoadFactor = 1.0
    )
    
    try {
        $cpuCount = [Environment]::ProcessorCount
        
        # Base calculation by workload type
        $baseThrottle = switch ($WorkloadType) {
            'CPU' { $cpuCount }
            'IO' { $cpuCount * 2 }
            'Network' { $cpuCount * 3 }
            'Mixed' { [Math]::Ceiling($cpuCount * 1.5) }
        }
        
        # Apply system load factor
        $adjustedThrottle = [Math]::Ceiling($baseThrottle * $SystemLoadFactor)
        
        # Apply maximum limit
        $optimalThrottle = [Math]::Min($adjustedThrottle, $MaxLimit)
        
        # Ensure minimum of 1
        $optimalThrottle = [Math]::Max(1, $optimalThrottle)
        
        Write-CustomLog "Optimal throttle limit calculated: $optimalThrottle (Type: $WorkloadType, CPUs: $cpuCount)" -Level "INFO"
        
        return $optimalThrottle
    }
    catch {
        Write-CustomLog "Error calculating optimal throttle limit: $($_.Exception.Message)" -Level "ERROR"
        return $cpuCount  # Safe fallback
    }
}

function Measure-ParallelPerformance {
    <#
    .SYNOPSIS
    Measures and analyzes performance of parallel operations
    
    .DESCRIPTION
    Collects performance metrics during parallel execution including timing,
    resource usage, and efficiency metrics
    
    .PARAMETER OperationName
    Name of the operation being measured
    
    .PARAMETER StartTime
    Start time of the operation
    
    .PARAMETER EndTime
    End time of the operation
    
    .PARAMETER ItemCount
    Number of items processed
    
    .PARAMETER ThrottleLimit
    Throttle limit used for the operation
    
    .EXAMPLE
    $metrics = Measure-ParallelPerformance -OperationName "FileProcessing" -StartTime $start -EndTime $end -ItemCount 100 -ThrottleLimit 8
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$StartTime,
        
        [Parameter(Mandatory = $true)]
        [DateTime]$EndTime,
        
        [Parameter(Mandatory = $true)]
        [int]$ItemCount,
        
        [Parameter(Mandatory = $true)]
        [int]$ThrottleLimit
    )
    
    try {
        $duration = $EndTime - $StartTime
        $throughput = if ($duration.TotalSeconds -gt 0) { $ItemCount / $duration.TotalSeconds } else { 0 }
        $efficiency = if ($ThrottleLimit -gt 0) { $throughput / $ThrottleLimit } else { 0 }
        
        $metrics = [PSCustomObject]@{
            OperationName = $OperationName
            StartTime = $StartTime
            EndTime = $EndTime
            Duration = $duration
            ItemCount = $ItemCount
            ThrottleLimit = $ThrottleLimit
            ThroughputPerSecond = [Math]::Round($throughput, 2)
            EfficiencyRatio = [Math]::Round($efficiency, 2)
            AverageTimePerItem = [Math]::Round($duration.TotalMilliseconds / $ItemCount, 2)
            ParallelSpeedup = [Math]::Round($ThrottleLimit * $efficiency, 2)
        }
        
        Write-CustomLog "Performance metrics - Operation: $OperationName, Duration: $($duration.TotalSeconds)s, Throughput: $($metrics.ThroughputPerSecond) items/sec" -Level "INFO"
        
        return $metrics
    }
    catch {
        Write-CustomLog "Error measuring parallel performance: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Start-AdaptiveParallelExecution {
    <#
    .SYNOPSIS
    Executes operations with adaptive throttling based on real-time performance
    
    .DESCRIPTION
    Dynamically adjusts parallelism during execution based on system performance
    and resource availability
    
    .PARAMETER InputObject
    Collection of items to process
    
    .PARAMETER ScriptBlock
    Script block to execute for each item
    
    .PARAMETER InitialThrottle
    Initial throttle limit
    
    .PARAMETER MaxThrottle
    Maximum throttle limit
    
    .PARAMETER AdaptationInterval
    Interval in seconds for throttle adaptation
    
    .EXAMPLE
    $results = Start-AdaptiveParallelExecution -InputObject $files -ScriptBlock { param($file) Process-File $file } -InitialThrottle 4 -MaxThrottle 16
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $false)]
        [int]$InitialThrottle = [Environment]::ProcessorCount,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxThrottle = [Environment]::ProcessorCount * 2,
        
        [Parameter(Mandatory = $false)]
        [int]$AdaptationInterval = 5
    )
    
    begin {
        Write-CustomLog "Starting adaptive parallel execution with initial throttle: $InitialThrottle" -Level "INFO"
        $allItems = @()
    }
    
    process {
        $allItems += $InputObject
    }
    
    end {
        if ($allItems.Count -eq 0) {
            Write-CustomLog "No items to process" -Level "INFO"
            return @()
        }
        
        try {
            $currentThrottle = $InitialThrottle
            $batchSize = [Math]::Max(10, $allItems.Count / 10)
            $results = @()
            $startTime = Get-Date
            
            for ($i = 0; $i -lt $allItems.Count; $i += $batchSize) {
                $batchItems = $allItems[$i..([Math]::Min($i + $batchSize - 1, $allItems.Count - 1))]
                
                Write-CustomLog "Processing batch $([Math]::Floor($i / $batchSize) + 1) with throttle limit: $currentThrottle" -Level "INFO"
                
                $batchStartTime = Get-Date
                $batchResults = Invoke-ParallelForEach -InputObject $batchItems -ScriptBlock $ScriptBlock -ThrottleLimit $currentThrottle
                $batchEndTime = Get-Date
                
                $results += $batchResults
                
                # Analyze performance and adapt throttle
                $batchDuration = ($batchEndTime - $batchStartTime).TotalSeconds
                $batchThroughput = $batchItems.Count / $batchDuration
                
                # Simple adaptation logic
                if ($batchThroughput -gt ($batchItems.Count * 0.8)) {
                    # Good performance, consider increasing throttle
                    $currentThrottle = [Math]::Min($MaxThrottle, $currentThrottle + 1)
                } elseif ($batchThroughput -lt ($batchItems.Count * 0.3)) {
                    # Poor performance, reduce throttle
                    $currentThrottle = [Math]::Max(1, $currentThrottle - 1)
                }
                
                Write-CustomLog "Batch completed in $([Math]::Round($batchDuration, 2))s, throughput: $([Math]::Round($batchThroughput, 2)) items/sec, next throttle: $currentThrottle" -Level "INFO"
            }
            
            $endTime = Get-Date
            $totalDuration = ($endTime - $startTime).TotalSeconds
            Write-CustomLog "Adaptive parallel execution completed in $([Math]::Round($totalDuration, 2))s, processed $($allItems.Count) items" -Level "SUCCESS"
            
            return $results
        }
        catch {
            Write-CustomLog "Adaptive parallel execution failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Merge-ParallelTestResults {
    <#
    .SYNOPSIS
    Merges results from parallel Pester test execution

    .DESCRIPTION
    Aggregates test results from multiple parallel test runs into a single summary

    .PARAMETER TestResults
    Array of test result objects from parallel execution

    .EXAMPLE
    $mergedResults = Merge-ParallelTestResults -TestResults $parallelResults
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [object[]]$TestResults = @()
    )

    try {
        Write-CustomLog "Merging results from $($TestResults.Count) parallel test runs" -Level "INFO"

        if ($TestResults.Count -eq 0) {
            return [PSCustomObject]@{
                TotalTests = 0
                Passed = 0
                Failed = 0
                Skipped = 0
                TotalTime = [timespan]::Zero
                Failures = @()
                Success = $true
            }
        }

        $totalPassed = 0
        $totalFailed = 0
        $totalSkipped = 0
        $totalTime = [timespan]::Zero
        $allFailures = @()

        foreach ($result in $TestResults) {
            if ($result.Result) {
                # Handle different possible Pester result structures
                $pesterResult = $result.Result
                
                # Check if this is a Pester result object
                if ($pesterResult.PSObject.Properties['Tests']) {
                    # Pester 5.x structure
                    $passedTests = @($pesterResult.Tests | Where-Object { $_.Result -eq 'Passed' })
                    $failedTests = @($pesterResult.Tests | Where-Object { $_.Result -eq 'Failed' })
                    $skippedTests = @($pesterResult.Tests | Where-Object { $_.Result -eq 'Skipped' })
                    
                    $totalPassed += $passedTests.Count
                    $totalFailed += $failedTests.Count
                    $totalSkipped += $skippedTests.Count
                    
                    if ($failedTests.Count -gt 0) {
                        $allFailures += $failedTests
                    }
                    
                    if ($pesterResult.PSObject.Properties['Duration']) {
                        $totalTime += $pesterResult.Duration
                    }
                } elseif ($pesterResult.PSObject.Properties['Passed']) {
                    # Legacy structure or different format
                    $totalPassed += $pesterResult.Passed.Count
                    $totalFailed += $pesterResult.Failed.Count
                    $totalSkipped += $pesterResult.Skipped.Count

                    if ($pesterResult.PSObject.Properties['TotalTime']) {
                        $totalTime += $pesterResult.TotalTime
                    }

                    if ($pesterResult.Failed.Count -gt 0) {
                        $allFailures += $pesterResult.Failed
                    }
                } else {
                    # Try to parse as simple counts if it's a different structure
                    if ($pesterResult.PSObject.Properties['PassedCount']) {
                        $totalPassed += $pesterResult.PassedCount
                    }
                    if ($pesterResult.PSObject.Properties['FailedCount']) {
                        $totalFailed += $pesterResult.FailedCount
                    }
                    if ($pesterResult.PSObject.Properties['SkippedCount']) {
                        $totalSkipped += $pesterResult.SkippedCount
                    }
                }
            }

            if ($result.HasErrors) {
                Write-CustomLog "Test job $($result.Name) had errors: $($result.Errors -join '; ')" -Level "WARN"
            }
        }

        $summary = [PSCustomObject]@{
            TotalTests = $totalPassed + $totalFailed + $totalSkipped
            Passed = $totalPassed
            Failed = $totalFailed
            Skipped = $totalSkipped
            TotalTime = $totalTime
            Failures = $allFailures
            Success = $totalFailed -eq 0
        }

        Write-CustomLog "Test summary: $($summary.Passed) passed, $($summary.Failed) failed, $($summary.Skipped) skipped in $($summary.TotalTime)" -Level "INFO"

        return $summary
    }
    catch {
        Write-CustomLog "Error merging test results: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Invoke-ParallelForEach',
    'Start-ParallelJob',
    'Wait-ParallelJobs',
    'Invoke-ParallelPesterTests',
    'Merge-ParallelTestResults',
    'Get-OptimalThrottleLimit',
    'Measure-ParallelPerformance',
    'Start-AdaptiveParallelExecution'
)