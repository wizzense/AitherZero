function Start-InfrastructureDeployment {
    <#
    .SYNOPSIS
        Starts an infrastructure deployment using the abstraction layer.

    .DESCRIPTION
        Main entry point for infrastructure deployment. Orchestrates repository sync,
        template resolution, ISO preparation, and OpenTofu execution with comprehensive
        error handling and progress tracking.

    .PARAMETER ConfigurationPath
        Path to deployment configuration file.

    .PARAMETER Repository
        Override repository from configuration.

    .PARAMETER DryRun
        Perform planning only without applying changes.

    .PARAMETER Stage
        Run specific deployment stage only.

    .PARAMETER Checkpoint
        Resume from specific checkpoint.

    .PARAMETER MaxRetries
        Maximum retry attempts for failed operations.

    .PARAMETER Force
        Force deployment even with warnings.

    .PARAMETER SkipPreChecks
        Skip pre-deployment validation checks.

    .EXAMPLE
        Start-InfrastructureDeployment -ConfigurationPath ".\lab-deployment.yaml" -DryRun

    .EXAMPLE
        Start-InfrastructureDeployment -ConfigurationPath ".\prod.yaml" -Stage "Apply" -Checkpoint "after-plan"

    .OUTPUTS
        Deployment result object with detailed status
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [string]$ConfigurationPath,
        
        [Parameter()]
        [string]$Repository,
        
        [Parameter()]
        [switch]$DryRun,
        
        [Parameter()]
        [ValidateSet('Prepare', 'Validate', 'Plan', 'Apply', 'Verify')]
        [string]$Stage,
        
        [Parameter()]
        [string]$Checkpoint,
        
        [Parameter()]
        [ValidateRange(0, 5)]
        [int]$MaxRetries = 2,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$SkipPreChecks
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting infrastructure deployment from: $ConfigurationPath"
        
        # Initialize deployment tracking
        $script:deploymentId = [Guid]::NewGuid().ToString()
        $script:deploymentStartTime = Get-Date
        
        # Initialize progress tracking if ProgressTracking module is available
        $script:progressOperationId = $null
        $script:useProgressTracking = (Get-Module -Name 'ProgressTracking' -ListAvailable -ErrorAction SilentlyContinue) -ne $null
        
        if ($script:useProgressTracking) {
            try {
                # Import ProgressTracking module if not already loaded
                if (-not (Get-Module -Name 'ProgressTracking')) {
                    Import-Module 'ProgressTracking' -Force -ErrorAction Stop
                }
                
                $totalSteps = if ($Stage) { 1 } else { 5 }  # Prepare, Validate, Plan, Apply, Verify
                $script:progressOperationId = Start-ProgressOperation -OperationName "Infrastructure Deployment" -TotalSteps $totalSteps -ShowTime -ShowETA -Style 'Detailed'
                Write-ProgressLog -Message "Infrastructure deployment started with progress tracking" -Level 'Info'
            } catch {
                Write-CustomLog -Level 'WARN' -Message "Could not initialize progress tracking: $($_.Exception.Message)"
                $script:useProgressTracking = $false
            }
        }
        
        # Create deployment directory
        $script:deploymentDir = Join-Path $env:PROJECT_ROOT "deployments" $script:deploymentId
        New-Item -Path $script:deploymentDir -ItemType Directory -Force | Out-Null
        
        # Initialize deployment state
        $script:deploymentState = @{
            Id = $script:deploymentId
            StartTime = $script:deploymentStartTime
            ConfigurationPath = $ConfigurationPath
            Status = 'Initializing'
            CurrentStage = $null
            CompletedStages = @()
            Checkpoints = @{}
            Errors = @()
            Warnings = @()
            Outputs = @{}
        }
        
        # Save initial state
        Save-DeploymentState -State $script:deploymentState
    }
    
    process {
        try {
            # Initialize result object
            $deploymentResult = @{
                Success = $false
                DeploymentId = $script:deploymentId
                StartTime = $script:deploymentStartTime
                EndTime = $null
                Duration = $null
                Configuration = $null
                Stages = @{}
                Resources = @{}
                Errors = @()
                Warnings = @()
                Outputs = @{}
                LogPath = Join-Path $script:deploymentDir "deployment.log"
            }
            
            # Start logging
            Start-Transcript -Path $deploymentResult.LogPath -Append
            
            try {
                # Step 1: Load and validate configuration
                if ($script:useProgressTracking -and $script:progressOperationId) {
                    Update-ProgressOperation -OperationId $script:progressOperationId -CurrentStep 1 -StepName "Loading deployment configuration"
                }
                
                Write-CustomLog -Level 'INFO' -Message "Loading deployment configuration"
                $config = Read-DeploymentConfiguration -Path $ConfigurationPath -ExpandVariables
                $deploymentResult.Configuration = $config
                
                if ($script:useProgressTracking -and $script:progressOperationId) {
                    Write-ProgressLog -Message "Configuration loaded successfully" -Level 'Success'
                }
                
                # Override repository if specified
                if ($Repository) {
                    $config.repository.name = $Repository
                    Write-CustomLog -Level 'INFO' -Message "Using repository override: $Repository"
                }
                
                # Step 2: Create deployment plan
                if ($script:useProgressTracking -and $script:progressOperationId) {
                    Update-ProgressOperation -OperationId $script:progressOperationId -CurrentStep 2 -StepName "Creating deployment plan"
                }
                
                Write-CustomLog -Level 'INFO' -Message "Creating deployment plan"
                $plan = New-DeploymentPlan -Configuration $config -DryRun:$DryRun -SkipPreChecks:$SkipPreChecks
                
                if ($script:useProgressTracking -and $script:progressOperationId) {
                    Write-ProgressLog -Message "Deployment plan created" -Level 'Success'
                }
                
                if (-not $plan.IsValid) {
                    throw "Deployment plan validation failed: $($plan.ValidationErrors -join '; ')"
                }
                
                # Step 3: Determine stages to run
                $stagesToRun = if ($Stage) {
                    # Single stage mode
                    @($Stage)
                } else {
                    # All stages
                    $plan.Stages.Keys | Sort-Object { $plan.Stages[$_].Order }
                }
                
                # Check for checkpoint resume
                if ($Checkpoint) {
                    Write-CustomLog -Level 'INFO' -Message "Resuming from checkpoint: $Checkpoint"
                    $checkpointData = Load-DeploymentCheckpoint -DeploymentId $script:deploymentId -CheckpointName $Checkpoint
                    
                    if ($checkpointData) {
                        # Skip stages before checkpoint
                        $stagesToRun = $stagesToRun | Where-Object { 
                            $plan.Stages[$_].Order -gt $checkpointData.StageOrder 
                        }
                        
                        # Restore state
                        $script:deploymentState = $checkpointData.State
                    } else {
                        Write-CustomLog -Level 'WARN' -Message "Checkpoint not found, starting from beginning"
                    }
                }
                
                # Step 4: Execute deployment stages
                $currentStageIndex = 0
                foreach ($stageName in $stagesToRun) {
                    if (-not $PSCmdlet.ShouldProcess("Stage: $stageName", "Execute deployment stage")) {
                        continue
                    }
                    
                    $currentStageIndex++
                    
                    if ($script:useProgressTracking -and $script:progressOperationId) {
                        $stageStep = if ($Stage) { 1 } else { $currentStageIndex + 2 }  # Offset by config loading and planning steps
                        Update-ProgressOperation -OperationId $script:progressOperationId -CurrentStep $stageStep -StepName "Executing stage: $stageName"
                    }
                    
                    Write-CustomLog -Level 'INFO' -Message "Executing stage: $stageName"
                    $script:deploymentState.CurrentStage = $stageName
                    $script:deploymentState.Status = "Running:$stageName"
                    Save-DeploymentState -State $script:deploymentState
                    
                    $stageResult = Invoke-DeploymentStage -Plan $plan -StageName $stageName -DryRun:$DryRun -MaxRetries $MaxRetries
                    
                    $deploymentResult.Stages[$stageName] = $stageResult
                    
                    if ($stageResult.Success) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Stage '$stageName' completed successfully"
                        $script:deploymentState.CompletedStages += $stageName
                        
                        if ($script:useProgressTracking -and $script:progressOperationId) {
                            Write-ProgressLog -Message "Stage '$stageName' completed successfully ($([Math]::Round($stageResult.Duration.TotalSeconds, 1))s)" -Level 'Success'
                        }
                        
                        # Create checkpoint after successful stage
                        if ($plan.Stages[$stageName].CreateCheckpoint) {
                            Save-DeploymentCheckpoint -DeploymentId $script:deploymentId -CheckpointName "after-$stageName" -State $script:deploymentState -StageOrder $plan.Stages[$stageName].Order
                        }
                    } else {
                        Write-CustomLog -Level 'ERROR' -Message "Stage '$stageName' failed: $($stageResult.Error)"
                        $deploymentResult.Errors += "Stage '$stageName' failed: $($stageResult.Error)"
                        
                        if ($script:useProgressTracking -and $script:progressOperationId) {
                            Add-ProgressError -OperationId $script:progressOperationId -Error "Stage '$stageName' failed: $($stageResult.Error)"
                            Write-ProgressLog -Message "Stage '$stageName' failed: $($stageResult.Error)" -Level 'Error'
                        }
                        
                        if (-not $Force) {
                            throw "Deployment failed at stage: $stageName"
                        } else {
                            Write-CustomLog -Level 'WARN' -Message "Continuing despite failure due to -Force flag"
                            $deploymentResult.Warnings += "Stage '$stageName' failed but continuing due to -Force"
                            
                            if ($script:useProgressTracking -and $script:progressOperationId) {
                                Add-ProgressWarning -OperationId $script:progressOperationId -Warning "Stage '$stageName' failed but continuing due to -Force"
                            }
                        }
                    }
                    
                    # Collect outputs
                    if ($stageResult.Outputs) {
                        foreach ($key in $stageResult.Outputs.Keys) {
                            $deploymentResult.Outputs[$key] = $stageResult.Outputs[$key]
                        }
                    }
                }
                
                # Step 5: Final verification
                if ($stagesToRun -contains 'Verify' -or (-not $Stage -and -not $DryRun)) {
                    if ($script:useProgressTracking -and $script:progressOperationId) {
                        $finalStep = if ($Stage) { 1 } else { 5 }
                        Update-ProgressOperation -OperationId $script:progressOperationId -CurrentStep $finalStep -StepName "Performing final deployment verification"
                    }
                    
                    Write-CustomLog -Level 'INFO' -Message "Performing final deployment verification"
                    $verifyResult = Test-DeploymentSuccess -Plan $plan -DeploymentResult $deploymentResult
                    
                    if ($verifyResult.Success) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Deployment verification passed"
                        $deploymentResult.Success = $true
                        $script:deploymentState.Status = 'Completed'
                        
                        if ($script:useProgressTracking -and $script:progressOperationId) {
                            Write-ProgressLog -Message "Deployment verification passed" -Level 'Success'
                        }
                    } else {
                        Write-CustomLog -Level 'WARN' -Message "Deployment verification failed: $($verifyResult.Reason)"
                        $deploymentResult.Warnings += "Verification failed: $($verifyResult.Reason)"
                        $script:deploymentState.Status = 'CompletedWithWarnings'
                        
                        if ($script:useProgressTracking -and $script:progressOperationId) {
                            Add-ProgressWarning -OperationId $script:progressOperationId -Warning "Deployment verification failed: $($verifyResult.Reason)"
                            Write-ProgressLog -Message "Deployment verification failed: $($verifyResult.Reason)" -Level 'Warning'
                        }
                    }
                } else {
                    # Partial deployment
                    $deploymentResult.Success = $deploymentResult.Errors.Count -eq 0
                    $script:deploymentState.Status = if ($DryRun) { 'DryRunCompleted' } else { 'PartiallyCompleted' }
                    
                    if ($script:useProgressTracking -and $script:progressOperationId) {
                        $status = if ($DryRun) { "Dry run completed" } else { "Partial deployment completed" }
                        Write-ProgressLog -Message $status -Level 'Info'
                    }
                }
                
            } catch {
                Write-CustomLog -Level 'ERROR' -Message "Deployment failed: $($_.Exception.Message)"
                $deploymentResult.Errors += $_.Exception.Message
                $script:deploymentState.Status = 'Failed'
                $script:deploymentState.Errors += $_.Exception.Message
                
                if ($script:useProgressTracking -and $script:progressOperationId) {
                    Add-ProgressError -OperationId $script:progressOperationId -Error $_.Exception.Message
                    Write-ProgressLog -Message "Deployment failed: $($_.Exception.Message)" -Level 'Error'
                }
                
                if (-not $Force) {
                    throw
                }
            } finally {
                # Save final state
                $deploymentResult.EndTime = Get-Date
                $deploymentResult.Duration = $deploymentResult.EndTime - $deploymentResult.StartTime
                $script:deploymentState.EndTime = $deploymentResult.EndTime
                Save-DeploymentState -State $script:deploymentState
                
                # Complete progress tracking
                if ($script:useProgressTracking -and $script:progressOperationId) {
                    Complete-ProgressOperation -OperationId $script:progressOperationId -ShowSummary
                }
                
                # Stop logging
                Stop-Transcript
                
                # Generate summary
                Write-DeploymentSummary -Result $deploymentResult
            }
            
            return [PSCustomObject]$deploymentResult
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Infrastructure deployment failed: $($_.Exception.Message)"
            throw
        }
    }
}

function Save-DeploymentState {
    param([hashtable]$State)
    
    $statePath = Join-Path $script:deploymentDir "state.json"
    $State | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath
}

function Save-DeploymentCheckpoint {
    param(
        [string]$DeploymentId,
        [string]$CheckpointName,
        [hashtable]$State,
        [int]$StageOrder
    )
    
    $checkpointDir = Join-Path $script:deploymentDir "checkpoints"
    if (-not (Test-Path $checkpointDir)) {
        New-Item -Path $checkpointDir -ItemType Directory -Force | Out-Null
    }
    
    $checkpoint = @{
        Name = $CheckpointName
        Timestamp = Get-Date
        StageOrder = $StageOrder
        State = $State
    }
    
    $checkpointPath = Join-Path $checkpointDir "$CheckpointName.json"
    $checkpoint | ConvertTo-Json -Depth 10 | Set-Content -Path $checkpointPath
    
    Write-CustomLog -Level 'INFO' -Message "Checkpoint saved: $CheckpointName"
}

function Load-DeploymentCheckpoint {
    param(
        [string]$DeploymentId,
        [string]$CheckpointName
    )
    
    $deploymentDir = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
    $checkpointPath = Join-Path $deploymentDir "checkpoints" "$CheckpointName.json"
    
    if (Test-Path $checkpointPath) {
        return Get-Content $checkpointPath | ConvertFrom-Json
    }
    
    return $null
}

function Test-DeploymentSuccess {
    param(
        [object]$Plan,
        [hashtable]$DeploymentResult
    )
    
    $result = @{
        Success = $true
        Reason = ""
    }
    
    # Check if all required stages completed
    $requiredStages = $Plan.Stages.Keys | Where-Object { $Plan.Stages[$_].Required }
    foreach ($stage in $requiredStages) {
        if (-not $DeploymentResult.Stages.ContainsKey($stage) -or -not $DeploymentResult.Stages[$stage].Success) {
            $result.Success = $false
            $result.Reason = "Required stage '$stage' did not complete successfully"
            return $result
        }
    }
    
    # Check for critical errors
    if ($DeploymentResult.Errors.Count -gt 0) {
        $result.Success = $false
        $result.Reason = "Deployment completed with errors"
    }
    
    return $result
}

function Write-DeploymentSummary {
    param([hashtable]$Result)
    
    Write-Host "`n$('='*60)" -ForegroundColor Cyan
    Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "$('='*60)" -ForegroundColor Cyan
    
    Write-Host "Deployment ID: $($Result.DeploymentId)"
    Write-Host "Duration: $([Math]::Round($Result.Duration.TotalMinutes, 2)) minutes"
    Write-Host "Status: $(if ($Result.Success) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($Result.Success) { 'Green' } else { 'Red' })
    
    if ($Result.Stages.Count -gt 0) {
        Write-Host "`nStages:" -ForegroundColor Yellow
        foreach ($stage in $Result.Stages.Keys) {
            $stageResult = $Result.Stages[$stage]
            $status = if ($stageResult.Success) { "✓" } else { "✗" }
            $color = if ($stageResult.Success) { "Green" } else { "Red" }
            Write-Host "  $status $stage" -ForegroundColor $color
        }
    }
    
    if ($Result.Warnings.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        foreach ($warning in $Result.Warnings) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
    }
    
    if ($Result.Errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($error in $Result.Errors) {
            Write-Host "  - $error" -ForegroundColor Red
        }
    }
    
    if ($Result.Outputs.Count -gt 0) {
        Write-Host "`nOutputs:" -ForegroundColor Green
        foreach ($key in $Result.Outputs.Keys) {
            Write-Host "  $key`: $($Result.Outputs[$key])"
        }
    }
    
    Write-Host "`nLog file: $($Result.LogPath)" -ForegroundColor Gray
    Write-Host "$('='*60)`n" -ForegroundColor Cyan
}