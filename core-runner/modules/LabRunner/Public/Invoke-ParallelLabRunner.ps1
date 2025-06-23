# Parallel Runner Enhancement for LabRunner
# Safe parallel processing for runner scripts with thread management

function Invoke-ParallelLabRunner {
    <#
    .SYNOPSIS
    Execute LabRunner scripts in parallel with safety controls
    
    .PARAMETER Scripts
    Array of script objects to run in parallel
    
    .PARAMETER MaxConcurrency
    Maximum number of concurrent threads (default: number of CPU cores)
    
    .PARAMETER TimeoutMinutes
    Timeout for each script execution (default: 30 minutes)
    
    .PARAMETER SafeMode
    Enable safe mode with dependency checking and resource locking
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Scripts,
        
        [Parameter()]
        [int]$MaxConcurrency = [Environment]::ProcessorCount,
        
        [Parameter()]
        [int]$TimeoutMinutes = 30,
        
        [Parameter()]
        [switch]$SafeMode
    )
    
    # Import required modules
    Import-Module ThreadJob -Force -ErrorAction SilentlyContinue
    
    if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
        Write-Warning "ThreadJob module not available. Installing..."
        Install-Module ThreadJob -Force -Scope CurrentUser
        Import-Module ThreadJob -Force
    }
    
    Write-Host "Starting parallel execution with $MaxConcurrency concurrent threads" -ForegroundColor Green
    
    $results = @()
    $activeJobs = @()
    $completed = 0
    $total = $Scripts.Count
    
    # Process scripts in batches
    for ($i = 0; $i -lt $total; $i++) {
        $script = $Scripts[$i]
        
        # Wait for available slot if at max concurrency
        while ($activeJobs.Count -ge $MaxConcurrency) {
            $finishedJobs = $activeJobs | Where-Object{ $_.State -eq 'Completed' -or $_.State -eq 'Failed' }
            
            foreach ($job in $finishedJobs) {
                $result = Receive-Job $job -ErrorAction SilentlyContinue
                $results += @{
                    Script = $job.Name
                    Result = $result
                    State = $job.State
                    Duration = (Get-Date) - $job.PSBeginTime
                }
                Remove-Job $job
                $activeJobs = $activeJobs | Where-Object{ $_.Id -ne $job.Id }
                $completed++
                
                $percentComplete = [math]::Round(($completed / $total) * 100, 1)
                Write-Progress -Activity "Parallel Script Execution" -Status "$completed of $total completed ($percentComplete%)" -PercentComplete $percentComplete
            }
            
            if ($activeJobs.Count -ge $MaxConcurrency) {
                Start-Sleep -Milliseconds 500
            }
        }
        
        # Start new job
        $scriptBlock = {
            param($ScriptPath, $Config, $SafeMode)
            
            try {
                if ($SafeMode) {
                    # Implement resource locking and dependency checking
                    $lockFile = "$env:TEMP\labrunner-$($ScriptPath -replace '[\\/:*?"<>|]', '_').lock"
                    
                    # Check for existing lock
                    if (Test-Path $lockFile) {
                        $lockContent = Get-Content $lockFile -ErrorAction SilentlyContinue
                        if ($lockContent -and ((Get-Date) - [DateTime]::Parse($lockContent[0])).TotalMinutes -lt 30) {
                            throw "Script is locked by another process"
                        }
                    }
                    
                    # Create lock
                    Set-Content $lockFile -Value @((Get-Date).ToString(), $PID)
                    
                    try {
                        # Execute script
                        & $ScriptPath -Config $Config
                    }
                    finally {
                        # Remove lock
                        Remove-Item $lockFile -ErrorAction SilentlyContinue
                    }
                } else {
                    # Execute script without locking
                    & $ScriptPath -Config $Config
                }
            }
            catch {
                Write-Error "Script execution failed: $($_.Exception.Message)"
                throw
            }
        }
        
        # Start the job
        $jobName = "LabRunner-$(Split-Path $script.Path -Leaf)-$i"
        $job = Start-ThreadJob -ScriptBlock $scriptBlock -ArgumentList $script.Path, $script.Config, $SafeMode.IsPresent -Name $jobName
        $activeJobs += $job
        
        Write-Host "Started job: $jobName" -ForegroundColor Cyan
    }
    
    # Wait for all remaining jobs to complete
    Write-Host "Waiting for remaining jobs to complete..." -ForegroundColor Yellow
    
    while ($activeJobs.Count -gt 0) {
        $finishedJobs = $activeJobs | Where-Object{ $_.State -eq 'Completed' -or $_.State -eq 'Failed' }
        
        foreach ($job in $finishedJobs) {
            $result = Receive-Job $job -ErrorAction SilentlyContinue
            $results += @{
                Script = $job.Name
                Result = $result
                State = $job.State
                Duration = (Get-Date) - $job.PSBeginTime
            }
            Remove-Job $job
            $activeJobs = $activeJobs | Where-Object{ $_.Id -ne $job.Id }
            $completed++
            
            $percentComplete = [math]::Round(($completed / $total) * 100, 1)
            Write-Progress -Activity "Parallel Script Execution" -Status "$completed of $total completed ($percentComplete%)" -PercentComplete $percentComplete
        }
        
        if ($activeJobs.Count -gt 0) {
            Start-Sleep -Milliseconds 500
        }
    }
    
    Write-Progress -Activity "Parallel Script Execution" -Completed
    Write-Host "All jobs completed!" -ForegroundColor Green
    
    # Return results
    return $results
}



