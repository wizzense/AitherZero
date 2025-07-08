function Start-DeploymentRollback {
    <#
    .SYNOPSIS
        Rolls back a deployment to a previous state.

    .DESCRIPTION
        Performs a rollback of infrastructure deployment to a previous known good state.
        Supports rolling back to snapshots, previous versions, or specific checkpoints.

    .PARAMETER DeploymentId
        ID of the deployment to rollback.

    .PARAMETER TargetSnapshot
        Name of the snapshot to rollback to.

    .PARAMETER TargetVersion
        Version number to rollback to.

    .PARAMETER TargetCheckpoint
        Checkpoint name to rollback to.

    .PARAMETER RollbackType
        Type of rollback operation (Snapshot, Version, Checkpoint, LastGood).

    .PARAMETER CreateBackup
        Create a backup before performing rollback.

    .PARAMETER Force
        Force rollback without confirmation prompts.

    .PARAMETER DryRun
        Preview rollback actions without executing them.

    .PARAMETER MaxRetries
        Maximum retry attempts for rollback operations.

    .EXAMPLE
        Start-DeploymentRollback -DeploymentId "abc123" -TargetSnapshot "pre-update"

    .EXAMPLE
        Start-DeploymentRollback -DeploymentId "abc123" -RollbackType "LastGood" -CreateBackup

    .EXAMPLE
        Start-DeploymentRollback -DeploymentId "abc123" -TargetVersion "1.2.0" -DryRun

    .OUTPUTS
        Rollback operation result object
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'LastGood')]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,

        [Parameter(ParameterSetName = 'Snapshot')]
        [string]$TargetSnapshot,

        [Parameter(ParameterSetName = 'Version')]
        [string]$TargetVersion,

        [Parameter(ParameterSetName = 'Checkpoint')]
        [string]$TargetCheckpoint,

        [Parameter(ParameterSetName = 'LastGood')]
        [ValidateSet('Snapshot', 'Version', 'Checkpoint', 'LastGood')]
        [string]$RollbackType = 'LastGood',

        [Parameter()]
        [switch]$CreateBackup,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [ValidateRange(0, 5)]
        [int]$MaxRetries = 2
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting deployment rollback for: $DeploymentId"

        # Validate deployment exists
        $deployment = Get-DeploymentStatus -DeploymentId $DeploymentId
        if (-not $deployment) {
            throw "Deployment '$DeploymentId' not found"
        }

        # Initialize rollback tracking
        $script:rollbackId = [Guid]::NewGuid().ToString()
        $script:rollbackStartTime = Get-Date
    }

    process {
        try {
            # Initialize rollback result
            $rollbackResult = @{
                RollbackId = $script:rollbackId
                DeploymentId = $DeploymentId
                StartTime = $script:rollbackStartTime
                EndTime = $null
                Duration = $null
                Success = $false
                RollbackType = $RollbackType
                TargetState = @{}
                Actions = @()
                Errors = @()
                Warnings = @()
                BackupCreated = $false
                BackupPath = $null
            }

            # Determine target state based on rollback type
            Write-CustomLog -Level 'INFO' -Message "Determining rollback target"

            $targetInfo = switch ($PSCmdlet.ParameterSetName) {
                'Snapshot' {
                    Get-SnapshotInfo -DeploymentId $DeploymentId -SnapshotName $TargetSnapshot
                }
                'Version' {
                    Get-VersionInfo -DeploymentId $DeploymentId -Version $TargetVersion
                }
                'Checkpoint' {
                    Get-CheckpointInfo -DeploymentId $DeploymentId -CheckpointName $TargetCheckpoint
                }
                'LastGood' {
                    Get-LastGoodDeployment -DeploymentId $DeploymentId
                }
            }

            if (-not $targetInfo -or -not $targetInfo.IsValid) {
                throw "Cannot determine valid rollback target: $($targetInfo.Error)"
            }

            $rollbackResult.TargetState = $targetInfo

            Write-CustomLog -Level 'INFO' -Message "Rollback target: $($targetInfo.Description)"

            # Create backup if requested
            if ($CreateBackup) {
                Write-CustomLog -Level 'INFO' -Message "Creating deployment backup before rollback"

                $backupResult = New-DeploymentSnapshot -DeploymentId $DeploymentId -Name "pre-rollback-$($script:rollbackId)" -Description "Automatic backup before rollback"

                if ($backupResult.Success) {
                    $rollbackResult.BackupCreated = $true
                    $rollbackResult.BackupPath = $backupResult.SnapshotPath
                    Write-CustomLog -Level 'SUCCESS' -Message "Backup created: $($backupResult.SnapshotPath)"
                } else {
                    if (-not $Force) {
                        throw "Failed to create backup: $($backupResult.Error)"
                    } else {
                        $rollbackResult.Warnings += "Backup creation failed but continuing due to -Force: $($backupResult.Error)"
                    }
                }
            }

            # Generate rollback plan
            Write-CustomLog -Level 'INFO' -Message "Generating rollback execution plan"

            $rollbackPlan = New-RollbackPlan -CurrentDeployment $deployment -TargetState $targetInfo -DeploymentId $DeploymentId

            if (-not $rollbackPlan.IsValid) {
                throw "Failed to generate valid rollback plan: $($rollbackPlan.ValidationErrors -join '; ')"
            }

            $rollbackResult.Actions = $rollbackPlan.Actions

            # Show rollback plan
            Write-RollbackPlan -Plan $rollbackPlan

            # Confirm rollback unless forced or dry run
            if (-not $Force -and -not $DryRun) {
                $confirmation = Read-Host "Proceed with rollback? This will modify $($rollbackPlan.Actions.Count) resource(s) (Y/N)"
                if ($confirmation -notmatch '^[Yy]') {
                    Write-CustomLog -Level 'INFO' -Message "Rollback cancelled by user"
                    return [PSCustomObject]@{
                        Success = $false
                        Cancelled = $true
                        Message = "Rollback cancelled by user"
                    }
                }
            }

            # Execute rollback plan
            if ($DryRun) {
                Write-CustomLog -Level 'INFO' -Message "[DRY-RUN] Rollback plan would execute $($rollbackPlan.Actions.Count) action(s)"
                $rollbackResult.Success = $true
                $rollbackResult.DryRun = $true
            } else {
                Write-CustomLog -Level 'INFO' -Message "Executing rollback plan"

                $executionResult = Invoke-RollbackPlan -Plan $rollbackPlan -DeploymentId $DeploymentId -MaxRetries $MaxRetries

                $rollbackResult.Success = $executionResult.Success
                $rollbackResult.Errors = $executionResult.Errors
                $rollbackResult.Warnings = $executionResult.Warnings

                # Update deployment status
                if ($executionResult.Success) {
                    Update-DeploymentAfterRollback -DeploymentId $DeploymentId -RollbackInfo $rollbackResult
                }
            }

            $rollbackResult.EndTime = Get-Date
            $rollbackResult.Duration = $rollbackResult.EndTime - $rollbackResult.StartTime

            # Log results
            if ($rollbackResult.Success) {
                Write-CustomLog -Level 'SUCCESS' -Message "Deployment rollback completed successfully in $([Math]::Round($rollbackResult.Duration.TotalMinutes, 2)) minutes"
            } else {
                Write-CustomLog -Level 'ERROR' -Message "Deployment rollback failed: $($rollbackResult.Errors -join '; ')"
            }

            return [PSCustomObject]$rollbackResult

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to perform deployment rollback: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-SnapshotInfo {
    param(
        [string]$DeploymentId,
        [string]$SnapshotName
    )

    $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
    $snapshotPath = Join-Path $deploymentPath "snapshots" "$SnapshotName.json"

    if (-not (Test-Path $snapshotPath)) {
        return @{
            IsValid = $false
            Error = "Snapshot '$SnapshotName' not found"
        }
    }

    try {
        $snapshot = Get-Content $snapshotPath | ConvertFrom-Json

        return @{
            IsValid = $true
            Type = 'Snapshot'
            Name = $SnapshotName
            Description = "Snapshot: $SnapshotName ($(Get-Date $snapshot.CreatedAt -Format 'yyyy-MM-dd HH:mm'))"
            StateData = $snapshot
            ConfigurationPath = $snapshot.ConfigurationPath
            CreatedAt = $snapshot.CreatedAt
        }
    } catch {
        return @{
            IsValid = $false
            Error = "Failed to load snapshot: $_"
        }
    }
}

function Get-VersionInfo {
    param(
        [string]$DeploymentId,
        [string]$Version
    )

    # Get deployment history to find version
    $history = Get-DeploymentHistory -DeploymentId $DeploymentId

    $versionEntry = $history | Where-Object { $_.Version -eq $Version }

    if (-not $versionEntry) {
        return @{
            IsValid = $false
            Error = "Version '$Version' not found in deployment history"
        }
    }

    return @{
        IsValid = $true
        Type = 'Version'
        Name = $Version
        Description = "Version: $Version ($(Get-Date $versionEntry.Timestamp -Format 'yyyy-MM-dd HH:mm'))"
        StateData = $versionEntry
        ConfigurationPath = $versionEntry.ConfigurationPath
        CreatedAt = $versionEntry.Timestamp
    }
}

function Get-CheckpointInfo {
    param(
        [string]$DeploymentId,
        [string]$CheckpointName
    )

    $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
    $checkpointPath = Join-Path $deploymentPath "checkpoints" "$CheckpointName.json"

    if (-not (Test-Path $checkpointPath)) {
        return @{
            IsValid = $false
            Error = "Checkpoint '$CheckpointName' not found"
        }
    }

    try {
        $checkpoint = Get-Content $checkpointPath | ConvertFrom-Json

        return @{
            IsValid = $true
            Type = 'Checkpoint'
            Name = $CheckpointName
            Description = "Checkpoint: $CheckpointName ($(Get-Date $checkpoint.Timestamp -Format 'yyyy-MM-dd HH:mm'))"
            StateData = $checkpoint
            ConfigurationPath = $null  # Checkpoints may not have config
            CreatedAt = $checkpoint.Timestamp
        }
    } catch {
        return @{
            IsValid = $false
            Error = "Failed to load checkpoint: $_"
        }
    }
}

function Get-LastGoodDeployment {
    param([string]$DeploymentId)

    # Get deployment history and find last successful deployment
    $history = Get-DeploymentHistory -DeploymentId $DeploymentId

    $lastGood = $history | Where-Object { $_.Status -eq 'Completed' } | Sort-Object Timestamp -Descending | Select-Object -First 1

    if (-not $lastGood) {
        return @{
            IsValid = $false
            Error = "No successful deployment found in history"
        }
    }

    return @{
        IsValid = $true
        Type = 'LastGood'
        Name = "LastGood"
        Description = "Last successful deployment ($(Get-Date $lastGood.Timestamp -Format 'yyyy-MM-dd HH:mm'))"
        StateData = $lastGood
        ConfigurationPath = $lastGood.ConfigurationPath
        CreatedAt = $lastGood.Timestamp
    }
}

function New-RollbackPlan {
    param(
        [PSCustomObject]$CurrentDeployment,
        [hashtable]$TargetState,
        [string]$DeploymentId
    )

    $plan = @{
        IsValid = $true
        ValidationErrors = @()
        Actions = @()
        EstimatedDuration = [TimeSpan]::Zero
    }

    try {
        # Get current infrastructure state
        $currentState = Get-ActualInfrastructureState -DeploymentId $DeploymentId -Provider (Get-DeploymentProvider -DeploymentId $DeploymentId)

        # Get target configuration
        $targetConfig = if ($TargetState.ConfigurationPath -and (Test-Path $TargetState.ConfigurationPath)) {
            Read-DeploymentConfiguration -Path $TargetState.ConfigurationPath
        } elseif ($TargetState.StateData.Configuration) {
            $TargetState.StateData.Configuration
        } else {
            throw "Cannot determine target configuration"
        }

        # Generate rollback actions
        $plan.Actions = Get-RollbackActions -CurrentState $currentState -TargetConfiguration $targetConfig -DeploymentId $DeploymentId

        # Validate plan
        if ($plan.Actions.Count -eq 0) {
            $plan.ValidationErrors += "No rollback actions required - deployment is already at target state"
        }

        # Estimate duration
        $plan.EstimatedDuration = [TimeSpan]::FromMinutes($plan.Actions.Count * 2)  # Rough estimate

        $plan.IsValid = $plan.ValidationErrors.Count -eq 0

    } catch {
        $plan.IsValid = $false
        $plan.ValidationErrors += "Failed to generate rollback plan: $_"
    }

    return $plan
}

function Get-RollbackActions {
    param(
        [hashtable]$CurrentState,
        [PSCustomObject]$TargetConfiguration,
        [string]$DeploymentId
    )

    $actions = @()

    # Get target state from configuration
    $targetResources = @{}

    if ($TargetConfiguration.infrastructure) {
        foreach ($resourceProp in $TargetConfiguration.infrastructure.PSObject.Properties) {
            $resourceType = $resourceProp.Name
            $resourceConfig = $resourceProp.Value

            $resources = if ($resourceConfig -is [array]) { $resourceConfig } else { @($resourceConfig) }

            foreach ($resource in $resources) {
                $targetResources[$resource.name] = @{
                    Name = $resource.name
                    Type = $resourceType
                    Configuration = $resource
                }
            }
        }
    }

    # Compare current state with target and generate actions
    $allResources = @()
    $allResources += $CurrentState.Keys
    $allResources += $targetResources.Keys
    $allResources = $allResources | Sort-Object | Get-Unique

    foreach ($resourceName in $allResources) {
        $current = $CurrentState[$resourceName]
        $target = $targetResources[$resourceName]

        if ($current -and -not $target) {
            # Resource should be removed
            $actions += @{
                Type = 'Remove'
                ResourceName = $resourceName
                ResourceType = $current.Type
                Description = "Remove $($current.Type): $resourceName"
                Priority = 1
            }
        } elseif (-not $current -and $target) {
            # Resource should be created
            $actions += @{
                Type = 'Create'
                ResourceName = $resourceName
                ResourceType = $target.Type
                Configuration = $target.Configuration
                Description = "Create $($target.Type): $resourceName"
                Priority = 3
            }
        } elseif ($current -and $target) {
            # Check if resource needs modification
            $changes = Compare-ResourceConfiguration -Desired $target.Configuration -Actual $current.Configuration

            if ($changes.Count -gt 0) {
                $actions += @{
                    Type = 'Modify'
                    ResourceName = $resourceName
                    ResourceType = $target.Type
                    Configuration = $target.Configuration
                    Changes = $changes
                    Description = "Modify $($target.Type): $resourceName ($($changes.Count) change(s))"
                    Priority = 2
                }
            }
        }
    }

    # Sort by priority (Remove first, then Modify, then Create)
    return $actions | Sort-Object Priority
}

function Write-RollbackPlan {
    param([hashtable]$Plan)

    Write-Host "`n=== ROLLBACK EXECUTION PLAN ===" -ForegroundColor Cyan
    Write-Host "Estimated Duration: $([Math]::Round($Plan.EstimatedDuration.TotalMinutes, 2)) minutes" -ForegroundColor Gray

    if ($Plan.Actions.Count -eq 0) {
        Write-Host "No actions required - deployment is already at target state" -ForegroundColor Green
        return
    }

    Write-Host "`nActions to perform:" -ForegroundColor Yellow

    foreach ($action in $Plan.Actions) {
        $color = switch ($action.Type) {
            'Remove' { 'Red' }
            'Modify' { 'Yellow' }
            'Create' { 'Green' }
            default { 'White' }
        }

        Write-Host "  $($action.Type): $($action.Description)" -ForegroundColor $color
    }

    Write-Host "==============================`n" -ForegroundColor Cyan
}

function Invoke-RollbackPlan {
    param(
        [hashtable]$Plan,
        [string]$DeploymentId,
        [int]$MaxRetries
    )

    $result = @{
        Success = $true
        Errors = @()
        Warnings = @()
        CompletedActions = 0
        FailedActions = 0
    }

    foreach ($action in $Plan.Actions) {
        Write-CustomLog -Level 'INFO' -Message "Executing rollback action: $($action.Description)"

        $actionResult = Invoke-RollbackAction -Action $action -DeploymentId $DeploymentId -MaxRetries $MaxRetries

        if ($actionResult.Success) {
            $result.CompletedActions++
            Write-CustomLog -Level 'SUCCESS' -Message "Completed: $($action.Description)"
        } else {
            $result.FailedActions++
            $result.Success = $false
            $result.Errors += "Failed: $($action.Description) - $($actionResult.Error)"
            Write-CustomLog -Level 'ERROR' -Message "Failed: $($action.Description) - $($actionResult.Error)"
        }

        if ($actionResult.Warnings) {
            $result.Warnings += $actionResult.Warnings
        }
    }

    return $result
}

function Invoke-RollbackAction {
    param(
        [hashtable]$Action,
        [string]$DeploymentId,
        [int]$MaxRetries
    )

    $result = @{
        Success = $false
        Error = $null
        Warnings = @()
    }

    $retryCount = 0

    while ($retryCount -le $MaxRetries) {
        try {
            switch ($Action.Type) {
                'Remove' {
                    $result = Invoke-RemoveResourceAction -Action $Action -DeploymentId $DeploymentId
                }
                'Create' {
                    $result = Invoke-CreateResourceAction -Action $Action -DeploymentId $DeploymentId
                }
                'Modify' {
                    $result = Invoke-ModifyResourceAction -Action $Action -DeploymentId $DeploymentId
                }
            }

            if ($result.Success) {
                break
            }

        } catch {
            $result.Error = $_.Exception.Message
        }

        $retryCount++
        if ($retryCount -le $MaxRetries) {
            Write-CustomLog -Level 'WARN' -Message "Retrying action: $($Action.Description) (attempt $($retryCount + 1))"
            Start-Sleep -Seconds (5 * $retryCount)
        }
    }

    return $result
}

function Invoke-RemoveResourceAction {
    param(
        [hashtable]$Action,
        [string]$DeploymentId
    )

    # Implementation would depend on provider
    # For now, return success for demonstration
    return @{
        Success = $true
        Message = "Resource removal simulated"
    }
}

function Invoke-CreateResourceAction {
    param(
        [hashtable]$Action,
        [string]$DeploymentId
    )

    # Implementation would depend on provider
    # For now, return success for demonstration
    return @{
        Success = $true
        Message = "Resource creation simulated"
    }
}

function Invoke-ModifyResourceAction {
    param(
        [hashtable]$Action,
        [string]$DeploymentId
    )

    # Implementation would depend on provider
    # For now, return success for demonstration
    return @{
        Success = $true
        Message = "Resource modification simulated"
    }
}

function Update-DeploymentAfterRollback {
    param(
        [string]$DeploymentId,
        [hashtable]$RollbackInfo
    )

    # Update deployment status to reflect rollback
    $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
    $statePath = Join-Path $deploymentPath "state.json"

    if (Test-Path $statePath) {
        try {
            $state = Get-Content $statePath | ConvertFrom-Json

            # Add rollback information
            if (-not $state.Rollbacks) {
                $state | Add-Member -NotePropertyName 'Rollbacks' -NotePropertyValue @()
            }

            $state.Rollbacks += @{
                RollbackId = $RollbackInfo.RollbackId
                Timestamp = $RollbackInfo.StartTime
                TargetType = $RollbackInfo.RollbackType
                Success = $RollbackInfo.Success
            }

            $state.Status = "RolledBack"
            $state.LastRollback = $RollbackInfo.StartTime

            # Save updated state
            $state | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath

        } catch {
            Write-CustomLog -Level 'WARN' -Message "Failed to update deployment state after rollback: $_"
        }
    }
}
