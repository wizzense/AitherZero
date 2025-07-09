# Parallel Runner Enhancement for LabRunner
# Safe parallel processing for runner scripts with thread management

function Invoke-ParallelLabRunner {
    <#
    .SYNOPSIS
    Execute LabRunner scripts in parallel with safety controls

    .PARAMETER Scripts
    Array of script objects to run in parallel

    .PARAMETER Config
    Configuration object for lab automation

    .PARAMETER MaxConcurrency
    Maximum number of concurrent threads (default: number of CPU cores)

    .PARAMETER TimeoutMinutes
    Timeout for each script execution (default: 30 minutes)

    .PARAMETER SafeMode
    Enable safe mode with dependency checking and resource locking

    .PARAMETER ShowProgress
    Show progress during execution

    .PARAMETER ProgressStyle
    Style of progress display
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [array]$Scripts = @(),

        [Parameter(Mandatory=$false)]
        [object]$Config = @{},

        [Parameter()]
        [int]$MaxConcurrency = [Environment]::ProcessorCount,

        [Parameter()]
        [int]$TimeoutMinutes = 30,

        [Parameter()]
        [switch]$SafeMode,

        [Parameter()]
        [switch]$ShowProgress,

        [Parameter()]
        [ValidateSet('Bar', 'Spinner', 'Percentage', 'Detailed')]
        [string]$ProgressStyle = 'Bar'
    )

    # Import required modules
    Import-Module ThreadJob -Force -ErrorAction SilentlyContinue

    if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
        Write-Warning "ThreadJob module not available. Installing..."
        Install-Module ThreadJob -Force -Scope CurrentUser
        Import-Module ThreadJob -Force
    }

    # Generate deployment scripts from configuration if no scripts provided
    if ($Scripts.Count -eq 0 -and $Config) {
        $Scripts = Generate-DeploymentScripts -Config $Config
    }

    Write-Host "Starting parallel execution with $MaxConcurrency concurrent threads" -ForegroundColor Green

    $results = @()
    $activeJobs = @()
    $completed = 0
    $total = $Scripts.Count

    if ($total -eq 0) {
        Write-Host "No scripts to execute" -ForegroundColor Yellow
        return @{
            TotalScripts = 0
            CompletedScripts = 0
            FailedScripts = 0
            Results = @()
        }
    }

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

    # Calculate summary statistics
    $completedCount = ($results | Where-Object { $_.State -eq 'Completed' }).Count
    $failedCount = ($results | Where-Object { $_.State -eq 'Failed' }).Count

    # Return results in expected format
    return @{
        TotalScripts = $total
        CompletedScripts = $completedCount
        FailedScripts = $failedCount
        Results = $results
        Success = ($failedCount -eq 0)
    }
}

# Helper function to generate deployment scripts from configuration
function Generate-DeploymentScripts {
    param([object]$Config)
    
    $scripts = @()
    
    try {
        # Generate scripts based on configuration sections
        if ($Config.infrastructure) {
            $scripts += @{
                Name = "Infrastructure-Setup"
                Path = "Deploy-Infrastructure"
                Config = $Config.infrastructure
            }
        }
        
        if ($Config.vms) {
            foreach ($vm in $Config.vms) {
                $scripts += @{
                    Name = "VM-$($vm.name)"
                    Path = "Deploy-VM"
                    Config = $vm
                }
            }
        }
        
        if ($Config.applications) {
            foreach ($app in $Config.applications) {
                $scripts += @{
                    Name = "App-$($app.name)"
                    Path = "Deploy-Application"
                    Config = $app
                }
            }
        }
        
        if ($Config.network) {
            $scripts += @{
                Name = "Network-Setup"
                Path = "Deploy-Network"
                Config = $Config.network
            }
        }
        
        # If no specific deployment scripts found, create a default one
        if ($scripts.Count -eq 0) {
            $scripts += @{
                Name = "Default-Lab-Deployment"
                Path = "Deploy-Lab"
                Config = $Config
            }
        }
        
        Write-Host "Generated $($scripts.Count) deployment scripts from configuration" -ForegroundColor Green
        return $scripts
        
    } catch {
        Write-Warning "Failed to generate deployment scripts: $($_.Exception.Message)"
        return @()
    }
}
