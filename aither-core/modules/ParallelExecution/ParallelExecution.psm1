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
            
            $results = $items | ForEach-Object -Parallel $parallelScript -ThrottleLimit $ThrottleLimit -TimeoutSeconds $TimeoutSeconds

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
                    $results[$job.Id] = @{
                        Name = $job.Name
                        State = $job.State
                        Result = $jobResult
                        HasErrors = $job.ChildJobs[0].Error.Count -gt 0
                        Errors = $job.ChildJobs[0].Error
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
            if ($result.Result -and $result.Result.PSObject.Properties['Passed']) {
                $totalPassed += $result.Result.Passed.Count
                $totalFailed += $result.Result.Failed.Count
                $totalSkipped += $result.Result.Skipped.Count

                if ($result.Result.PSObject.Properties['TotalTime']) {
                    $totalTime += $result.Result.TotalTime
                }

                if ($result.Result.Failed.Count -gt 0) {
                    $allFailures += $result.Result.Failed
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

function Get-IntelligentParallelSettings {
    <#
    .SYNOPSIS
    Get intelligent parallel execution settings using SystemMonitoring integration
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$CI,
        
        [Parameter()]
        [ValidateSet('Test', 'Build', 'Deploy', 'Analysis', 'General')]
        [string]$WorkloadType = 'General',
        
        [Parameter()]
        [switch]$UseBaseline
    )
    
    try {
        # Import SystemMonitoring module for intelligent resource detection
        $systemMonitoringPath = Join-Path (Split-Path $PSScriptRoot -Parent) "SystemMonitoring"
        if (Test-Path $systemMonitoringPath) {
            Import-Module $systemMonitoringPath -Force -ErrorAction SilentlyContinue
            
            if (Get-Command Get-IntelligentResourceMetrics -ErrorAction SilentlyContinue) {
                Write-CustomLog "Using intelligent resource detection for parallel settings" -Level "INFO"
                
                $resourceMetrics = Get-IntelligentResourceMetrics -IncludeRecommendations -OutputFormat Performance
                
                return @{
                    OptimalThreads = $resourceMetrics.OptimalParallelThreads
                    MaxSafeThreads = $resourceMetrics.MaxSafeThreads
                    RecommendParallel = $resourceMetrics.RecommendParallel
                    IntelligentDetection = $true
                    MemoryConstraintFactor = $resourceMetrics.MemoryConstraintFactor
                    IOConstraintFactor = $resourceMetrics.IOConstraintFactor
                    Source = "IntelligentResourceDetection"
                }
            }
        }
    } catch {
        Write-CustomLog "Intelligent resource detection failed, using fallback: $_" -Level "WARN"
    }
    
    # Fallback to basic detection
    return Get-BasicParallelSettings -CI:$CI
}

function Get-BasicParallelSettings {
    <#
    .SYNOPSIS
    Basic parallel execution settings fallback
    #>
    param([switch]$CI)
    
    $processorCount = [Environment]::ProcessorCount
    
    $optimalThreads = if ($CI) {
        [math]::Min($processorCount, 4)
    } else {
        [math]::Min($processorCount, 8)
    }
    
    return @{
        OptimalThreads = [int]$optimalThreads
        MaxSafeThreads = [int]([math]::Min($processorCount * 2, 16))
        RecommendParallel = $processorCount -ge 2
        IntelligentDetection = $false
        MemoryConstraintFactor = 1.0
        IOConstraintFactor = 1.0
        Source = "BasicDetection"
    }
}

function Start-AdaptiveParallelExecution {
    <#
    .SYNOPSIS
    Start parallel execution with adaptive throttling based on real-time system pressure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory)]
        [object[]]$InputObject,
        
        [Parameter()]
        [ValidateSet('Test', 'Build', 'Deploy', 'Analysis', 'General')]
        [string]$WorkloadType = 'General',
        
        [Parameter()]
        [int]$InitialThrottleLimit,
        
        [Parameter()]
        [switch]$EnableAdaptiveThrottling,
        
        [Parameter()]
        [int]$MonitoringInterval = 10,
        
        [Parameter()]
        [int]$TimeoutSeconds = 300
    )
    
    Write-CustomLog "Starting adaptive parallel execution for $($InputObject.Count) items" -Level "INFO"
    
    # Get intelligent initial settings
    $parallelSettings = Get-IntelligentParallelSettings -WorkloadType $WorkloadType
    $currentThrottleLimit = if ($InitialThrottleLimit) { $InitialThrottleLimit } else { $parallelSettings.OptimalThreads }
    
    Write-CustomLog "Initial throttle limit: $currentThrottleLimit (Source: $($parallelSettings.Source))" -Level "INFO"
    
    if (-not $parallelSettings.RecommendParallel) {
        Write-CustomLog "Parallel execution not recommended, falling back to sequential" -Level "WARN"
        return Invoke-SequentialExecution -ScriptBlock $ScriptBlock -InputObject $InputObject
    }
    
    # Start resource pressure monitoring if adaptive throttling is enabled
    $resourceMonitoring = $null
    if ($EnableAdaptiveThrottling) {
        try {
            $systemMonitoringPath = Join-Path (Split-Path $PSScriptRoot -Parent) "SystemMonitoring"
            if (Test-Path $systemMonitoringPath) {
                Import-Module $systemMonitoringPath -Force -ErrorAction SilentlyContinue
                
                if (Get-Command Watch-SystemResourcePressure -ErrorAction SilentlyContinue) {
                    Write-CustomLog "Starting adaptive resource pressure monitoring" -Level "INFO"
                    
                    $resourceMonitoring = Watch-SystemResourcePressure -MonitoringInterval $MonitoringInterval -ReturnImmediately -ThrottleCallback {
                        param($NewRecommendation)
                        $script:AdaptiveThrottleLimit = $NewRecommendation.OptimalParallelThreads
                        Write-CustomLog "Adaptive throttling adjusted to $script:AdaptiveThrottleLimit threads" -Level "INFO"
                    }
                    
                    $script:AdaptiveThrottleLimit = $currentThrottleLimit
                }
            }
        } catch {
            Write-CustomLog "Failed to start adaptive monitoring: $_" -Level "WARN"
        }
    }
    
    try {
        # Execute with adaptive throttling
        if ($EnableAdaptiveThrottling -and $resourceMonitoring) {
            Write-CustomLog "Executing with adaptive throttling enabled" -Level "INFO"
            $results = Invoke-AdaptiveParallelForEach -ScriptBlock $ScriptBlock -InputObject $InputObject -InitialThrottleLimit $currentThrottleLimit -TimeoutSeconds $TimeoutSeconds
        } else {
            Write-CustomLog "Executing with fixed throttling: $currentThrottleLimit threads" -Level "INFO"
            $results = Invoke-ParallelForEach -ScriptBlock $ScriptBlock -InputObject $InputObject -ThrottleLimit $currentThrottleLimit -TimeoutSeconds $TimeoutSeconds
        }
        
        Write-CustomLog "Adaptive parallel execution completed successfully" -Level "SUCCESS"
        return $results
        
    } finally {
        # Clean up resource monitoring
        if ($resourceMonitoring) {
            try {
                Stop-ResourcePressureMonitoring -MonitoringData $resourceMonitoring
            } catch {
                Write-CustomLog "Failed to stop resource monitoring: $_" -Level "WARN"
            }
        }
    }
}

function Invoke-AdaptiveParallelForEach {
    <#
    .SYNOPSIS
    Execute parallel foreach with adaptive throttling during execution
    #>
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$InputObject,
        [int]$InitialThrottleLimit,
        [int]$TimeoutSeconds
    )
    
    $script:AdaptiveThrottleLimit = $InitialThrottleLimit
    $results = @()
    $jobs = @()
    $processedItems = 0
    
    try {
        foreach ($item in $InputObject) {
            # Check if we need to wait for running jobs to complete due to throttle adjustment
            while ($jobs.Count -ge $script:AdaptiveThrottleLimit) {
                $completedJobs = $jobs | Where-Object { $_.State -ne 'Running' }
                
                foreach ($completedJob in $completedJobs) {
                    $jobResult = Receive-Job -Job $completedJob -Keep
                    $results += $jobResult
                    $jobs = $jobs | Where-Object { $_.Id -ne $completedJob.Id }
                    Remove-Job -Job $completedJob -Force
                    $processedItems++
                }
                
                if ($completedJobs.Count -eq 0) {
                    Start-Sleep -Milliseconds 100
                }
            }
            
            # Start new job for current item
            $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $item
            $jobs += $job
        }
        
        # Wait for remaining jobs
        if ($jobs.Count -gt 0) {
            Write-CustomLog "Waiting for remaining $($jobs.Count) jobs to complete" -Level "INFO"
            $jobResults = Wait-ParallelJobs -Jobs $jobs -TimeoutSeconds $TimeoutSeconds
            
            foreach ($jobResult in $jobResults) {
                if ($jobResult.Result) {
                    $results += $jobResult.Result
                }
            }
        }
        
        Write-CustomLog "Adaptive parallel execution processed $($InputObject.Count) items with dynamic throttling" -Level "SUCCESS"
        return $results
        
    } catch {
        Write-CustomLog "Adaptive parallel execution failed: $_" -Level "ERROR"
        
        # Clean up any remaining jobs
        $jobs | Stop-Job -Force -ErrorAction SilentlyContinue
        $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        
        throw
    }
}

function Invoke-SequentialExecution {
    <#
    .SYNOPSIS
    Fallback sequential execution when parallel is not recommended
    #>
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$InputObject
    )
    
    $results = @()
    
    foreach ($item in $InputObject) {
        try {
            $result = & $ScriptBlock $item
            $results += $result
        } catch {
            Write-CustomLog "Sequential execution item failed: $_" -Level "ERROR"
            throw
        }
    }
    
    return $results
}

function Get-ParallelExecutionAnalytics {
    <#
    .SYNOPSIS
    Get analytics and performance data for parallel execution optimization
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeBaselines,
        
        [Parameter()]
        [switch]$IncludeRecommendations
    )
    
    $analytics = @{
        SystemCapabilities = Get-IntelligentParallelSettings
        CurrentPerformance = $null
        Baselines = $null
        Recommendations = @()
        AnalyticsTimestamp = Get-Date
    }
    
    # Get current system performance
    try {
        $systemMonitoringPath = Join-Path (Split-Path $PSScriptRoot -Parent) "SystemMonitoring"
        if (Test-Path $systemMonitoringPath) {
            Import-Module $systemMonitoringPath -Force -ErrorAction SilentlyContinue
            
            if (Get-Command Get-IntelligentResourceMetrics -ErrorAction SilentlyContinue) {
                $analytics.CurrentPerformance = Get-IntelligentResourceMetrics -DetailedAnalysis
            }
        }
    } catch {
        Write-CustomLog "Failed to get current performance metrics: $_" -Level "WARN"
    }
    
    # Include baselines if requested
    if ($IncludeBaselines) {
        try {
            # Check for existing baseline files
            $baselineFiles = Get-ChildItem -Path "./baselines" -Filter "baseline-*.json" -ErrorAction SilentlyContinue
            if ($baselineFiles) {
                $analytics.Baselines = @()
                foreach ($baselineFile in $baselineFiles) {
                    $baseline = Get-Content $baselineFile.FullName | ConvertFrom-Json
                    $analytics.Baselines += $baseline
                }
            }
        } catch {
            Write-CustomLog "Failed to load baseline data: $_" -Level "WARN"
        }
    }
    
    # Generate recommendations
    if ($IncludeRecommendations) {
        $analytics.Recommendations = Get-ParallelExecutionRecommendations -Analytics $analytics
    }
    
    return $analytics
}

function Get-ParallelExecutionRecommendations {
    <#
    .SYNOPSIS
    Generate intelligent recommendations for parallel execution optimization
    #>
    param($Analytics)
    
    $recommendations = @()
    
    $capabilities = $Analytics.SystemCapabilities
    $performance = $Analytics.CurrentPerformance
    
    # Basic capability recommendations
    if (-not $capabilities.RecommendParallel) {
        $recommendations += "System not suitable for parallel execution - limited CPU cores or resources"
    } else {
        $recommendations += "System supports parallel execution with up to $($capabilities.OptimalThreads) optimal threads"
    }
    
    # Performance-based recommendations
    if ($performance) {
        if ($performance.Performance.CPULoad -gt 80) {
            $recommendations += "High CPU load detected - consider reducing parallel thread count"
        }
        
        if ($performance.Performance.MemoryPressure -gt 85) {
            $recommendations += "High memory pressure - parallel execution may be constrained"
        }
        
        if ($performance.Hardware.Storage.IOLoad -gt 50) {
            $recommendations += "High I/O load - consider I/O-optimized parallel strategies"
        }
        
        if ($performance.Capacity.OverallCapacity -gt 80) {
            $recommendations += "System has good capacity for parallel workloads"
        }
    }
    
    # Baseline-based recommendations
    if ($Analytics.Baselines) {
        $testBaseline = $Analytics.Baselines | Where-Object { $_.WorkloadType -eq 'Test' } | Select-Object -First 1
        if ($testBaseline) {
            if ($testBaseline.OptimalConfiguration.PerformanceImprovement -gt 20) {
                $recommendations += "Test workloads show significant parallel benefits ($($testBaseline.OptimalConfiguration.PerformanceImprovement)% improvement)"
            }
        }
    }
    
    # Intelligent detection recommendations
    if ($capabilities.IntelligentDetection) {
        $recommendations += "Using intelligent resource detection for optimal parallel configuration"
    } else {
        $recommendations += "Consider enabling intelligent resource detection for better parallel optimization"
    }
    
    return $recommendations
}

# Export module functions
Export-ModuleMember -Function @(
    'Invoke-ParallelForEach',
    'Start-ParallelJob',
    'Wait-ParallelJobs',
    'Invoke-ParallelPesterTests',
    'Merge-ParallelTestResults',
    'Get-IntelligentParallelSettings',
    'Start-AdaptiveParallelExecution',
    'Get-ParallelExecutionAnalytics'
)