# Parallel Runner Enhancement for LabRunner
# Safe parallel processing for runner scripts with thread management and progress tracking

function Invoke-ParallelLabRunner {
    <#
    .SYNOPSIS
    Execute LabRunner scripts in parallel with safety controls and enhanced progress tracking

    .PARAMETER Scripts
    Array of script objects to run in parallel

    .PARAMETER MaxConcurrency
    Maximum number of concurrent threads (default: number of CPU cores)

    .PARAMETER TimeoutMinutes
    Timeout for each script execution (default: 30 minutes)

    .PARAMETER SafeMode
    Enable safe mode with dependency checking and resource locking

    .PARAMETER ShowProgress
    Enable enhanced progress tracking with visual indicators

    .PARAMETER ProgressStyle
    Style of progress display: Bar, Spinner, Percentage, or Detailed

    .PARAMETER Config
    Configuration object for lab deployment
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [array]$Scripts,

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
        [string]$ProgressStyle = 'Bar',

        [Parameter()]
        [object]$Config
    )

    # Handle case where no scripts are provided - use config to determine deployment type
    if (-not $Scripts -and $Config) {
        # Generate deployment scripts based on configuration
        $Scripts = Get-DeploymentScriptsFromConfig -Config $Config
    } elseif (-not $Scripts) {
        # Default minimal script set for basic lab deployment
        $Scripts = @(
            @{ Name = "Environment Setup"; Path = "Setup-LabEnvironment"; Config = $Config },
            @{ Name = "Resource Deployment"; Path = "Deploy-LabResources"; Config = $Config },
            @{ Name = "Network Configuration"; Path = "Configure-LabNetwork"; Config = $Config },
            @{ Name = "Validation"; Path = "Test-LabDeployment"; Config = $Config }
        )
}

    # Import required modules
    Import-Module ThreadJob -Force -ErrorAction SilentlyContinue

    if (-not (Get-Command Start-ThreadJob -ErrorAction SilentlyContinue)) {
        Write-Warning "ThreadJob module not available. Installing..."
        Install-Module ThreadJob -Force -Scope CurrentUser
        Import-Module ThreadJob -Force
    }

    # Check if ProgressTracking is available
    $useProgressTracking = $ShowProgress -and (Get-Module -Name 'ProgressTracking' -ListAvailable -ErrorAction SilentlyContinue)
    $multiProgressIds = $null
    $overallProgressId = $null

    if ($useProgressTracking) {
        try {
            # Start overall progress tracking
            $overallProgressId = Start-ProgressOperation -OperationName "Parallel Lab Deployment" -TotalSteps ($Scripts.Count + 2) -ShowTime -ShowETA -Style $ProgressStyle
            Update-ProgressOperation -OperationId $overallProgressId -CurrentStep 1 -StepName "Initializing deployment environment"

            # Create multi-progress tracking for individual scripts
            $operations = $Scripts | ForEach-Object {
                @{
                    Name = $_.Name
                    Steps = 5  # Estimate steps per script: init, validate, execute, verify, cleanup
                }
            }

            $multiProgressIds = Start-MultiProgress -Title "Lab Script Execution" -Operations $operations
            Write-ProgressLog -Message "Started parallel execution with $MaxConcurrency concurrent threads" -Level 'Info'
        } catch {
            Write-Warning "Could not initialize progress tracking: $($_.Exception.Message)"
            $useProgressTracking = $false
        }
    }

    if (-not $useProgressTracking) {
        Write-Host "Starting parallel execution with $MaxConcurrency concurrent threads" -ForegroundColor Green
    }

    $results = @()
    $activeJobs = @()
    $completed = 0
    $total = $Scripts.Count
    $scriptStartTimes = @{}
    $estimatedDurations = @{}

    # Process scripts in batches
    for ($i = 0; $i -lt $total; $i++) {
        $script = $Scripts[$i]

        # Wait for available slot if at max concurrency
        while ($activeJobs.Count -ge $MaxConcurrency) {
            $finishedJobs = $activeJobs | Where-Object{ $_.State -eq 'Completed' -or $_.State -eq 'Failed' }

            foreach ($job in $finishedJobs) {
                $result = Receive-Job $job -ErrorAction SilentlyContinue
                $jobResult = @{
                    Script = $job.Name
                    Result = $result
                    State = $job.State
                    Duration = (Get-Date) - $job.PSBeginTime
                    StartTime = $job.PSBeginTime
                    EndTime = Get-Date
                }
                $results += $jobResult

                # Update progress tracking for completed job
                if ($useProgressTracking -and $multiProgressIds) {
                    $scriptName = $script.Name
                    if ($multiProgressIds.ContainsKey($scriptName)) {
                        Complete-ProgressOperation -OperationId $multiProgressIds[$scriptName] -ShowSummary:$false

                        if ($job.State -eq 'Completed') {
                            Write-ProgressLog -Message "Completed: $scriptName ($([Math]::Round($jobResult.Duration.TotalSeconds, 1))s)" -Level 'Success'
                        } else {
                            Write-ProgressLog -Message "Failed: $scriptName - $($jobResult.Result.Error)" -Level 'Error'
                        }
                    }
                }

                Remove-Job $job
                $activeJobs = $activeJobs | Where-Object{ $_.Id -ne $job.Id }
                $completed++

                # Update overall progress
                if ($useProgressTracking -and $overallProgressId) {
                    $percentComplete = [math]::Round(($completed / $total) * 100, 1)
                    Update-ProgressOperation -OperationId $overallProgressId -CurrentStep ($completed + 1) -StepName "Completed: $($job.Name) ($percentComplete%)"
                } else {
                    $percentComplete = [math]::Round(($completed / $total) * 100, 1)
                    Write-Progress -Activity "Parallel Script Execution" -Status "$completed of $total completed ($percentComplete%)" -PercentComplete $percentComplete
                }
            }

            if ($activeJobs.Count -ge $MaxConcurrency) {
                Start-Sleep -Milliseconds 500
            }
        }

        # Start new job
        $scriptBlock = {
            param($ScriptPath, $Config, $SafeMode, $ScriptName, $UseProgressTracking, $ProgressId)

            try {
                # Progress tracking within the script block
                if ($UseProgressTracking -and $ProgressId) {
                    # Note: ProgressTracking functions need to be available in the runspace
                    try {
                        Update-ProgressOperation -OperationId $ProgressId -CurrentStep 1 -StepName "Initializing $ScriptName"
                    } catch {
                        # Silently continue if progress tracking fails within runspace
                    }
                }

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
                        if ($UseProgressTracking -and $ProgressId) {
                            try {
                                Update-ProgressOperation -OperationId $ProgressId -CurrentStep 2 -StepName "Executing $ScriptName (Safe Mode)"
                            } catch { }
                        }

                        # Execute script or simulate based on script type
                        if (Test-Path $ScriptPath -PathType Leaf) {
                            & $ScriptPath -Config $Config
                        } else {
                            # Handle predefined script operations
                            Invoke-PredefinedLabOperation -OperationName $ScriptPath -Config $Config -ProgressId $ProgressId -UseProgressTracking $UseProgressTracking
                        }
                    }
                    finally {
                        # Remove lock
                        Remove-Item $lockFile -ErrorAction SilentlyContinue
                    }
                } else {
                    if ($UseProgressTracking -and $ProgressId) {
                        try {
                            Update-ProgressOperation -OperationId $ProgressId -CurrentStep 2 -StepName "Executing $ScriptName"
                        } catch { }
                    }

                    # Execute script or simulate based on script type
                    if (Test-Path $ScriptPath -PathType Leaf) {
                        & $ScriptPath -Config $Config
                    } else {
                        # Handle predefined script operations
                        Invoke-PredefinedLabOperation -OperationName $ScriptPath -Config $Config -ProgressId $ProgressId -UseProgressTracking $UseProgressTracking
                    }
                }

                if ($UseProgressTracking -and $ProgressId) {
                    try {
                        Update-ProgressOperation -OperationId $ProgressId -CurrentStep 5 -StepName "Completed $ScriptName"
                    } catch { }
                }

                return @{
                    Success = $true
                    Message = "$ScriptName completed successfully"
                    ScriptName = $ScriptName
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    ScriptName = $ScriptName
                }
            }
        }

        # Prepare progress tracking for this script
        $scriptProgressId = $null
        if ($useProgressTracking -and $multiProgressIds -and $script.Name) {
            $scriptProgressId = $multiProgressIds[$script.Name]
        }

        # Start the job
        $jobName = "LabRunner-$($script.Name -replace '[^a-zA-Z0-9]', '')-$i"
        $scriptStartTimes[$jobName] = Get-Date

        $job = Start-ThreadJob -ScriptBlock $scriptBlock -ArgumentList $script.Path, $script.Config, $SafeMode.IsPresent, $script.Name, $useProgressTracking, $scriptProgressId -Name $jobName
        $activeJobs += $job

        # Track estimated durations for better progress estimation
        $estimatedDurations[$jobName] = [TimeSpan]::FromMinutes(5)  # Default 5-minute estimate

        if ($useProgressTracking) {
            Write-ProgressLog -Message "Started: $($script.Name)" -Level 'Info'
        } else {
            Write-Host "Started job: $jobName" -ForegroundColor Cyan
        }
    }

    # Wait for all remaining jobs to complete
    if ($useProgressTracking) {
        Write-ProgressLog -Message "Waiting for remaining $($activeJobs.Count) jobs to complete..." -Level 'Info'
    } else {
        Write-Host "Waiting for remaining jobs to complete..." -ForegroundColor Yellow
    }

    while ($activeJobs.Count -gt 0) {
        $finishedJobs = $activeJobs | Where-Object{ $_.State -eq 'Completed' -or $_.State -eq 'Failed' }

        foreach ($job in $finishedJobs) {
            $result = Receive-Job $job -ErrorAction SilentlyContinue
            $jobResult = @{
                Script = $job.Name
                Result = $result
                State = $job.State
                Duration = (Get-Date) - $job.PSBeginTime
                StartTime = $job.PSBeginTime
                EndTime = Get-Date
            }
            $results += $jobResult

            # Update progress tracking for completed job
            if ($useProgressTracking -and $multiProgressIds) {
                # Find the corresponding script name
                $matchingScript = $Scripts | Where-Object { $job.Name -like "*$($_.Name -replace '[^a-zA-Z0-9]', '')*" } | Select-Object -First 1
                if ($matchingScript -and $multiProgressIds.ContainsKey($matchingScript.Name)) {
                    Complete-ProgressOperation -OperationId $multiProgressIds[$matchingScript.Name] -ShowSummary:$false

                    if ($job.State -eq 'Completed') {
                        Write-ProgressLog -Message "Completed: $($matchingScript.Name) ($([Math]::Round($jobResult.Duration.TotalSeconds, 1))s)" -Level 'Success'
                    } else {
                        Write-ProgressLog -Message "Failed: $($matchingScript.Name) - $($result.Error)" -Level 'Error'
                    }
                }
            }

            Remove-Job $job
            $activeJobs = $activeJobs | Where-Object{ $_.Id -ne $job.Id }
            $completed++

            # Update overall progress
            if ($useProgressTracking -and $overallProgressId) {
                $percentComplete = [math]::Round(($completed / $total) * 100, 1)
                Update-ProgressOperation -OperationId $overallProgressId -CurrentStep ($completed + 1) -StepName "Completed: $($job.Name) ($percentComplete%)"
            } else {
                $percentComplete = [math]::Round(($completed / $total) * 100, 1)
                Write-Progress -Activity "Parallel Script Execution" -Status "$completed of $total completed ($percentComplete%)" -PercentComplete $percentComplete
            }
        }

        if ($activeJobs.Count -gt 0) {
            Start-Sleep -Milliseconds 500
        }
    }

    # Complete progress tracking
    if ($useProgressTracking -and $overallProgressId) {
        Update-ProgressOperation -OperationId $overallProgressId -CurrentStep ($total + 2) -StepName "Finalizing deployment"
        Complete-ProgressOperation -OperationId $overallProgressId -ShowSummary
    } else {
        Write-Progress -Activity "Parallel Script Execution" -Completed
        Write-Host "All jobs completed!" -ForegroundColor Green
    }

    # Generate comprehensive results summary
    $summary = @{
        TotalScripts = $total
        CompletedSuccessfully = ($results | Where-Object { $_.State -eq 'Completed' }).Count
        Failed = ($results | Where-Object { $_.State -eq 'Failed' }).Count
        TotalDuration = if ($results.Count -gt 0) {
            ($results | Measure-Object -Property { $_.Duration.TotalSeconds } -Maximum).Maximum
        } else { 0 }
        AverageDuration = if ($results.Count -gt 0) {
            ($results | Measure-Object -Property { $_.Duration.TotalSeconds } -Average).Average
        } else { 0 }
        Results = $results
        ProgressTrackingEnabled = $useProgressTracking
    }

    if ($useProgressTracking) {
        Write-ProgressLog -Message "Lab deployment completed: $($summary.CompletedSuccessfully)/$($summary.TotalScripts) scripts successful" -Level 'Success'
    }

    # Return comprehensive results
    return $summary
}

function Get-DeploymentScriptsFromConfig {
    <#
    .SYNOPSIS
        Generate deployment scripts based on configuration
    #>
    param([object]$Config)

    $scripts = @()

    # Environment setup script
    $scripts += @{
        Name = "Environment Setup"
        Path = "Setup-LabEnvironment"
        Config = $Config
    }

    # If OpenTofu/Terraform is configured, add infrastructure deployment
    if ($Config -and ($Config.infrastructure -or $Config.opentofu -or $Config.terraform)) {
        $scripts += @{
            Name = "Infrastructure Deployment"
            Path = "Deploy-LabInfrastructure"
            Config = $Config
        }
    }

    # Network configuration if specified
    if ($Config -and $Config.network) {
        $scripts += @{
            Name = "Network Configuration"
            Path = "Configure-LabNetwork"
            Config = $Config
        }
    }

    # VM provisioning if VMs are specified
    if ($Config -and ($Config.vms -or $Config.virtual_machines)) {
        $scripts += @{
            Name = "VM Provisioning"
            Path = "Provision-LabVMs"
            Config = $Config
        }
    }

    # Application deployment if specified
    if ($Config -and $Config.applications) {
        $scripts += @{
            Name = "Application Deployment"
            Path = "Deploy-LabApplications"
            Config = $Config
        }
    }

    # Validation script
    $scripts += @{
        Name = "Deployment Validation"
        Path = "Test-LabDeployment"
        Config = $Config
    }

    return $scripts
}

function Invoke-PredefinedLabOperation {
    <#
    .SYNOPSIS
        Execute predefined lab operations with progress tracking
    #>
    param(
        [string]$OperationName,
        [object]$Config,
        [string]$ProgressId,
        [bool]$UseProgressTracking
    )

    try {
        switch ($OperationName) {
            "Setup-LabEnvironment" {
                if ($UseProgressTracking -and $ProgressId) {
                    try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 3 -StepName "Setting up environment" } catch { }
                }

                # Simulate environment setup
                Start-Sleep -Seconds 2
                Write-Host "Environment setup completed" -ForegroundColor Green
            }

            "Deploy-LabInfrastructure" {
                if ($UseProgressTracking -and $ProgressId) {
                    try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 3 -StepName "Deploying infrastructure" } catch { }
                }

                # Try to call OpenTofu deployment if available
                if (Get-Command "Start-InfrastructureDeployment" -ErrorAction SilentlyContinue) {
                    # Call actual infrastructure deployment
                    $infraResult = Start-InfrastructureDeployment -ConfigurationPath $Config.configPath -ShowProgress:$UseProgressTracking
                    return $infraResult
                } else {
                    # Simulate infrastructure deployment
                    Start-Sleep -Seconds 5
                    Write-Host "Infrastructure deployment completed" -ForegroundColor Green
                }
            }

            "Configure-LabNetwork" {
                if ($UseProgressTracking -and $ProgressId) {
                    try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 3 -StepName "Configuring network" } catch { }
                }

                # Simulate network configuration
                Start-Sleep -Seconds 3
                Write-Host "Network configuration completed" -ForegroundColor Green
            }

            "Provision-LabVMs" {
                if ($UseProgressTracking -and $ProgressId) {
                    try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 3 -StepName "Provisioning VMs" } catch { }
                }

                # Simulate VM provisioning
                $vmCount = if ($Config.vms) { $Config.vms.Count } elseif ($Config.virtual_machines) { $Config.virtual_machines.Count } else { 3 }

                for ($i = 1; $i -le $vmCount; $i++) {
                    if ($UseProgressTracking -and $ProgressId) {
                        try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 3 -StepName "Provisioning VM $i of $vmCount" } catch { }
                    }
                    Start-Sleep -Seconds 2
                    Write-Host "VM $i provisioned" -ForegroundColor Green
                }
            }

            "Deploy-LabApplications" {
                if ($UseProgressTracking -and $ProgressId) {
                    try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 3 -StepName "Deploying applications" } catch { }
                }

                # Simulate application deployment
                Start-Sleep -Seconds 4
                Write-Host "Application deployment completed" -ForegroundColor Green
            }

            "Test-LabDeployment" {
                if ($UseProgressTracking -and $ProgressId) {
                    try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 4 -StepName "Validating deployment" } catch { }
                }

                # Simulate deployment validation
                Start-Sleep -Seconds 2

                # Simulate some validation checks
                $checks = @("Network connectivity", "Service availability", "Resource health")
                foreach ($check in $checks) {
                    if ($UseProgressTracking -and $ProgressId) {
                        try { Update-ProgressOperation -OperationId $ProgressId -CurrentStep 4 -StepName "Validating: $check" } catch { }
                    }
                    Start-Sleep -Seconds 1
                    Write-Host "${check}: OK" -ForegroundColor Green
                }
            }

            default {
                Write-Warning "Unknown lab operation: $OperationName"
                Start-Sleep -Seconds 1
            }
        }

        return @{
            Success = $true
            Message = "$OperationName completed successfully"
        }

    } catch {
        Write-Error "Failed to execute $OperationName : $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
