#Requires -Version 7.0

<#
.SYNOPSIS
    Async orchestration API for non-blocking execution

.DESCRIPTION
    Provides async orchestration capabilities enabling CLI, GUI, and programmatic
    access to orchestration with progress tracking, job management, and real-time events.
    
    This module makes orchestration the backbone for all AitherZero operations by
    supporting async execution patterns needed for interactive UIs and long-running workflows.

.NOTES
    Part of Orchestration Engine v3.0 enhancements
#>

# Module-level variables
$script:JobsDirectory = Join-Path $env:AITHERZERO_ROOT '.orchestration-jobs'
$script:ActiveJobs = @{}

function Initialize-AsyncOrchestration {
    <#
    .SYNOPSIS
    Initialize async orchestration system
    #>
    
    # Create jobs directory
    if (-not (Test-Path $script:JobsDirectory)) {
        New-Item -ItemType Directory -Path $script:JobsDirectory -Force | Out-Null
    }
    
    # Load active jobs from disk
    $jobDirs = Get-ChildItem -Path $script:JobsDirectory -Directory -ErrorAction SilentlyContinue
    foreach ($jobDir in $jobDirs) {
        $metadataPath = Join-Path $jobDir.FullName 'metadata.json'
        if (Test-Path $metadataPath) {
            $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
            $script:ActiveJobs[$metadata.JobId] = $metadata
        }
    }
}

function Start-OrchestrationAsync {
    <#
    .SYNOPSIS
    Start orchestration execution asynchronously
    
    .DESCRIPTION
    Starts an orchestration playbook in a background job, returning immediately
    with a job ID for tracking. Enables non-blocking execution for CLI, GUI, and scripts.
    
    .PARAMETER LoadPlaybook
    Name of playbook to execute
    
    .PARAMETER Sequence
    Script sequence(s) to execute
    
    .PARAMETER Variables
    Variables to pass to orchestration
    
    .PARAMETER Matrix
    Matrix build parameters
    
    .PARAMETER UseCache
    Enable caching
    
    .PARAMETER GenerateSummary
    Generate execution summary
    
    .PARAMETER MaxConcurrency
    Maximum concurrent executions
    
    .EXAMPLE
    $job = Start-OrchestrationAsync -LoadPlaybook "test-full" -UseCache
    Write-Host "Job ID: $($job.JobId)"
    
    .EXAMPLE
    $job = Start-OrchestrationAsync -Sequence "0402,0404" -GenerateSummary
    Wait-Orchestration -JobId $job.JobId
    #>
    [CmdletBinding(DefaultParameterSetName = 'Playbook')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Playbook')]
        [string]$LoadPlaybook,
        
        [Parameter(Mandatory, ParameterSetName = 'Sequence')]
        [string[]]$Sequence,
        
        [Parameter()]
        [hashtable]$Variables = @{},
        
        [Parameter()]
        [hashtable]$Matrix,
        
        [Parameter()]
        [switch]$UseCache,
        
        [Parameter()]
        [switch]$GenerateSummary,
        
        [Parameter()]
        [int]$MaxConcurrency
    )
    
    # Initialize if needed
    if (-not (Test-Path $script:JobsDirectory)) {
        Initialize-AsyncOrchestration
    }
    
    # Generate job ID
    $jobId = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $jobDir = Join-Path $script:JobsDirectory $jobId
    New-Item -ItemType Directory -Path $jobDir -Force | Out-Null
    
    # Prepare arguments for job
    $jobArgs = @{
        LoadPlaybook = $LoadPlaybook
        Sequence = $Sequence
        Variables = $Variables
        Matrix = $Matrix
        UseCache = $UseCache.IsPresent
        GenerateSummary = $GenerateSummary.IsPresent
        MaxConcurrency = $MaxConcurrency
        JobId = $jobId
        JobDir = $jobDir
        ProjectRoot = $env:AITHERZERO_ROOT
    }
    
    # Start background job
    $job = Start-ThreadJob -Name "Orchestration-$jobId" -ScriptBlock {
        param($Args)
        
        # Set project root
        $env:AITHERZERO_ROOT = $Args.ProjectRoot
        Set-Location $Args.ProjectRoot
        
        # Import orchestration module
        Import-Module (Join-Path $Args.ProjectRoot "AitherZero.psd1") -Force
        
        try {
            # Write start marker
            "Started: $(Get-Date -Format 'o')" | Set-Content "$($Args.JobDir)/start.txt"
            
            # Build orchestration parameters
            $orchParams = @{}
            
            if ($Args.LoadPlaybook) {
                $orchParams['LoadPlaybook'] = $Args.LoadPlaybook
            }
            if ($Args.Sequence) {
                $orchParams['Sequence'] = $Args.Sequence
            }
            if ($Args.Variables) {
                $orchParams['Variables'] = $Args.Variables
            }
            if ($Args.Matrix) {
                $orchParams['Matrix'] = $Args.Matrix
            }
            if ($Args.UseCache) {
                $orchParams['UseCache'] = $true
            }
            if ($Args.GenerateSummary) {
                $orchParams['GenerateSummary'] = $true
            }
            if ($Args.MaxConcurrency) {
                $orchParams['MaxConcurrency'] = $Args.MaxConcurrency
            }
            
            # Execute orchestration
            $result = Invoke-OrchestrationSequence @orchParams
            
            # Save result
            @{
                Status = 'Completed'
                Result = $result
                EndTime = Get-Date -Format 'o'
            } | ConvertTo-Json -Depth 10 | Set-Content "$($Args.JobDir)/result.json"
            
            return @{ Success = $true; Result = $result }
            
        } catch {
            # Save error
            @{
                Status = 'Failed'
                Error = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
                EndTime = Get-Date -Format 'o'
            } | ConvertTo-Json -Depth 10 | Set-Content "$($Args.JobDir)/result.json"
            
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    } -ArgumentList $jobArgs
    
    # Save job metadata
    $metadata = @{
        JobId = $jobId
        Playbook = $LoadPlaybook
        Sequence = $Sequence
        StartTime = Get-Date -Format 'o'
        Status = 'Running'
        ThreadJobId = $job.Id
        Parameters = $jobArgs
    }
    
    $metadata | ConvertTo-Json -Depth 10 | Set-Content "$jobDir/metadata.json"
    $script:ActiveJobs[$jobId] = $metadata
    
    # Return job info
    return [PSCustomObject]@{
        JobId = $jobId
        Status = 'Running'
        StartTime = $metadata.StartTime
    }
}

function Get-OrchestrationStatus {
    <#
    .SYNOPSIS
    Get status of orchestration job
    
    .PARAMETER JobId
    Job ID to query
    
    .EXAMPLE
    $status = Get-OrchestrationStatus -JobId "abc123"
    Write-Host "Status: $($status.Status)"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$JobId
    )
    
    $jobDir = Join-Path $script:JobsDirectory $JobId
    
    if (-not (Test-Path $jobDir)) {
        throw "Job not found: $JobId"
    }
    
    # Load metadata
    $metadataPath = Join-Path $jobDir 'metadata.json'
    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    
    # Check if completed
    $resultPath = Join-Path $jobDir 'result.json'
    if (Test-Path $resultPath) {
        $result = Get-Content $resultPath -Raw | ConvertFrom-Json
        return [PSCustomObject]@{
            JobId = $JobId
            Status = $result.Status
            StartTime = $metadata.StartTime
            EndTime = $result.EndTime
            Duration = if ($result.EndTime) { 
                (Get-Date $result.EndTime) - (Get-Date $metadata.StartTime) 
            } else { $null }
            Result = $result.Result
            Error = $result.Error
        }
    }
    
    # Check ThreadJob status
    $threadJob = Get-Job -Id $metadata.ThreadJobId -ErrorAction SilentlyContinue
    $jobStatus = if ($threadJob) { $threadJob.State } else { 'Unknown' }
    
    return [PSCustomObject]@{
        JobId = $JobId
        Status = $jobStatus
        StartTime = $metadata.StartTime
        Duration = (Get-Date) - (Get-Date $metadata.StartTime)
    }
}

function Wait-Orchestration {
    <#
    .SYNOPSIS
    Wait for orchestration job to complete
    
    .PARAMETER JobId
    Job ID to wait for
    
    .PARAMETER Timeout
    Timeout in seconds (default: no timeout)
    
    .EXAMPLE
    Wait-Orchestration -JobId "abc123"
    
    .EXAMPLE
    Wait-Orchestration -JobId "abc123" -Timeout 300
    #>
    param(
        [Parameter(Mandatory)]
        [string]$JobId,
        
        [Parameter()]
        [int]$Timeout = 0
    )
    
    $startTime = Get-Date
    
    while ($true) {
        $status = Get-OrchestrationStatus -JobId $JobId
        
        if ($status.Status -in @('Completed', 'Failed')) {
            return $status
        }
        
        if ($Timeout -gt 0) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            if ($elapsed -ge $Timeout) {
                throw "Timeout waiting for job $JobId after $Timeout seconds"
            }
        }
        
        Start-Sleep -Seconds 2
    }
}

function Stop-Orchestration {
    <#
    .SYNOPSIS
    Cancel orchestration job
    
    .PARAMETER JobId
    Job ID to cancel
    
    .EXAMPLE
    Stop-Orchestration -JobId "abc123"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$JobId
    )
    
    $jobDir = Join-Path $script:JobsDirectory $JobId
    
    if (-not (Test-Path $jobDir)) {
        throw "Job not found: $JobId"
    }
    
    # Load metadata
    $metadataPath = Join-Path $jobDir 'metadata.json'
    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    
    # Stop thread job
    $threadJob = Get-Job -Id $metadata.ThreadJobId -ErrorAction SilentlyContinue
    if ($threadJob) {
        Stop-Job -Job $threadJob
        Remove-Job -Job $threadJob -Force
    }
    
    # Mark as cancelled
    @{
        Status = 'Cancelled'
        EndTime = Get-Date -Format 'o'
    } | ConvertTo-Json | Set-Content "$jobDir/result.json"
    
    Write-Verbose "Orchestration job $JobId cancelled"
}

function Get-OrchestrationJobs {
    <#
    .SYNOPSIS
    List all orchestration jobs
    
    .PARAMETER Status
    Filter by status (Running, Completed, Failed, Cancelled)
    
    .EXAMPLE
    Get-OrchestrationJobs
    
    .EXAMPLE
    Get-OrchestrationJobs -Status Running
    #>
    param(
        [Parameter()]
        [ValidateSet('Running', 'Completed', 'Failed', 'Cancelled', 'All')]
        [string]$Status = 'All'
    )
    
    if (-not (Test-Path $script:JobsDirectory)) {
        return @()
    }
    
    $jobs = Get-ChildItem -Path $script:JobsDirectory -Directory | ForEach-Object {
        try {
            $jobStatus = Get-OrchestrationStatus -JobId $_.Name
            
            if ($Status -eq 'All' -or $jobStatus.Status -eq $Status) {
                $jobStatus
            }
        } catch {
            # Skip invalid jobs
        }
    }
    
    return $jobs | Sort-Object StartTime -Descending
}

function Get-OrchestrationLogs {
    <#
    .SYNOPSIS
    Get logs for orchestration job
    
    .PARAMETER JobId
    Job ID to get logs for
    
    .PARAMETER Follow
    Follow logs in real-time
    
    .EXAMPLE
    Get-OrchestrationLogs -JobId "abc123"
    
    .EXAMPLE
    Get-OrchestrationLogs -JobId "abc123" -Follow
    #>
    param(
        [Parameter(Mandatory)]
        [string]$JobId,
        
        [Parameter()]
        [switch]$Follow
    )
    
    $jobDir = Join-Path $script:JobsDirectory $JobId
    
    if (-not (Test-Path $jobDir)) {
        throw "Job not found: $JobId"
    }
    
    # Get transcript log if available
    $logPattern = Join-Path $env:AITHERZERO_ROOT "logs/transcript-*.log"
    $logs = Get-ChildItem $logPattern -ErrorAction SilentlyContinue | 
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-1) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    
    if ($logs) {
        if ($Follow) {
            Get-Content $logs.FullName -Wait
        } else {
            Get-Content $logs.FullName
        }
    } else {
        Write-Warning "No logs found for job $JobId"
    }
}

# Initialize on module load
Initialize-AsyncOrchestration

# Export functions
Export-ModuleMember -Function @(
    'Start-OrchestrationAsync'
    'Get-OrchestrationStatus'
    'Wait-Orchestration'
    'Stop-Orchestration'
    'Get-OrchestrationJobs'
    'Get-OrchestrationLogs'
)
