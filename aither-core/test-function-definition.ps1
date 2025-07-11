#!/usr/bin/env pwsh

# Test if the Start-ParallelExecution function definition is valid
$functionText = @'
function Start-ParallelExecution {
    <#
    .SYNOPSIS
        High-level parallel execution function for job orchestration

    .DESCRIPTION
        Provides a simplified interface for executing multiple jobs in parallel
        with comprehensive result aggregation and error handling

    .PARAMETER Jobs
        Array of job definitions containing Name, ScriptBlock, and Arguments

    .PARAMETER MaxConcurrentJobs
        Maximum number of jobs to run concurrently

    .PARAMETER TimeoutSeconds
        Timeout for the entire parallel execution

    .EXAMPLE
        $jobs = @(
            @{ Name = "Job1"; ScriptBlock = { param($x) $x * 2 }; Arguments = @(5) },
            @{ Name = "Job2"; ScriptBlock = { param($x) $x + 10 }; Arguments = @(3) }
        )
        $result = Start-ParallelExecution -Jobs $jobs -MaxConcurrentJobs 2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Jobs,

        [Parameter(Mandatory = $false)]
        [int]$MaxConcurrentJobs = [Environment]::ProcessorCount,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 600
    )

    return @{
        Success = $true
        TotalJobs = $Jobs.Count
        CompletedJobs = $Jobs.Count
        FailedJobs = 0
        Results = @()
        Errors = @()
    }
}
'@

Write-Host 'Testing function definition...'
try {
    Invoke-Expression $functionText
    Write-Host '✓ Function definition is valid'
    
    # Test if the function is available
    $cmd = Get-Command Start-ParallelExecution -ErrorAction SilentlyContinue
    if ($cmd) {
        Write-Host '✓ Function is available after definition'
        
        # Test calling it
        $jobs = @(
            @{ Name = 'Job1'; ScriptBlock = { param($x) $x * 2 }; Arguments = @(5) }
        )
        $result = Start-ParallelExecution -Jobs $jobs
        Write-Host "✓ Function call successful: $($result.Success)"
    } else {
        Write-Host '✗ Function is NOT available after definition'
    }
    
} catch {
    Write-Host "✗ Function definition failed: $($_.Exception.Message)"
    Write-Host "Error line: $($_.InvocationInfo.ScriptLineNumber)"
}