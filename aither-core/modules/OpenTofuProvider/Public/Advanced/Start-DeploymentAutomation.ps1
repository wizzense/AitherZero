function Start-DeploymentAutomation {
    <#
    .SYNOPSIS
        Configures and starts automated deployment workflows.

    .DESCRIPTION
        Sets up automated deployment processes including scheduled deployments,
        automated backups, drift detection, and maintenance workflows.

    .PARAMETER DeploymentId
        ID of the deployment to automate.

    .PARAMETER AutomationType
        Type of automation (Scheduled, ContinuousDeployment, Maintenance, Monitoring).

    .PARAMETER Schedule
        Schedule for automated tasks (cron-like format or predefined).

    .PARAMETER EnableDriftDetection
        Enable automatic drift detection.

    .PARAMETER DriftCheckInterval
        Interval for drift checks (in hours).

    .PARAMETER EnableAutoBackup
        Enable automatic backups before deployments.

    .PARAMETER BackupRetention
        Number of backups to retain.

    .PARAMETER EnableAutoRollback
        Enable automatic rollback on deployment failures.

    .PARAMETER NotificationEndpoint
        Endpoint for deployment notifications.

    .PARAMETER ConfigurationPath
        Path to automation configuration file.

    .EXAMPLE
        Start-DeploymentAutomation -DeploymentId "abc123" -AutomationType "Maintenance" -Schedule "Daily" -EnableDriftDetection

    .EXAMPLE
        Start-DeploymentAutomation -DeploymentId "abc123" -AutomationType "Monitoring" -DriftCheckInterval 6 -EnableAutoBackup

    .OUTPUTS
        Automation configuration result
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,

        [Parameter(Mandatory)]
        [ValidateSet('Scheduled', 'ContinuousDeployment', 'Maintenance', 'Monitoring')]
        [string]$AutomationType,

        [Parameter()]
        [ValidateSet('Hourly', 'Daily', 'Weekly', 'Monthly', 'Custom')]
        [string]$Schedule = 'Daily',

        [Parameter()]
        [switch]$EnableDriftDetection,

        [Parameter()]
        [ValidateRange(1, 168)]
        [int]$DriftCheckInterval = 24,

        [Parameter()]
        [switch]$EnableAutoBackup,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$BackupRetention = 10,

        [Parameter()]
        [switch]$EnableAutoRollback,

        [Parameter()]
        [string]$NotificationEndpoint,

        [Parameter()]
        [string]$ConfigurationPath
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting deployment automation setup for: $DeploymentId"

        # Validate deployment exists
        $deployment = Get-DeploymentStatus -DeploymentId $DeploymentId
        if (-not $deployment) {
            throw "Deployment '$DeploymentId' not found"
        }

        $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
        $automationDir = Join-Path $deploymentPath "automation"

        if (-not (Test-Path $automationDir)) {
            New-Item -Path $automationDir -ItemType Directory -Force | Out-Null
        }
    }

    process {
        try {
            # Initialize automation configuration
            $automationConfig = @{
                DeploymentId = $DeploymentId
                AutomationType = $AutomationType
                Enabled = $true
                CreatedAt = Get-Date
                LastModified = Get-Date
                Schedule = @{
                    Type = $Schedule
                    Interval = $DriftCheckInterval
                    NextRun = $null
                }
                Features = @{
                    DriftDetection = @{
                        Enabled = $EnableDriftDetection
                        Interval = $DriftCheckInterval
                        LastCheck = $null
                        AutoFix = $false
                    }
                    AutoBackup = @{
                        Enabled = $EnableAutoBackup
                        Retention = $BackupRetention
                        LastBackup = $null
                    }
                    AutoRollback = @{
                        Enabled = $EnableAutoRollback
                        Conditions = @('DeploymentFailure', 'CriticalDrift')
                    }
                    Notifications = @{
                        Enabled = -not [string]::IsNullOrEmpty($NotificationEndpoint)
                        Endpoint = $NotificationEndpoint
                        Events = @('DeploymentComplete', 'DeploymentFailure', 'DriftDetected', 'RollbackTriggered')
                    }
                }
                History = @()
                Status = 'Active'
            }

            # Configure schedule
            $automationConfig.Schedule.NextRun = Get-NextScheduledRun -Schedule $Schedule

            # Setup automation workflows based on type
            switch ($AutomationType) {
                'Scheduled' {
                    $automationConfig = Setup-ScheduledDeployment -Config $automationConfig -DeploymentId $DeploymentId
                }
                'ContinuousDeployment' {
                    $automationConfig = Setup-ContinuousDeployment -Config $automationConfig -DeploymentId $DeploymentId
                }
                'Maintenance' {
                    $automationConfig = Setup-MaintenanceWorkflow -Config $automationConfig -DeploymentId $DeploymentId
                }
                'Monitoring' {
                    $automationConfig = Setup-MonitoringWorkflow -Config $automationConfig -DeploymentId $DeploymentId
                }
            }

            if ($PSCmdlet.ShouldProcess($DeploymentId, "Configure deployment automation")) {
                # Save automation configuration
                $configPath = Join-Path $automationDir "automation-config.json"
                $automationConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath

                # Create automation scripts/tasks
                New-AutomationTasks -Config $automationConfig -AutomationDir $automationDir

                # Register automation with task scheduler (if on Windows)
                if ($IsWindows) {
                    Register-AutomationTasks -Config $automationConfig -DeploymentId $DeploymentId
                }

                # Update deployment state
                Update-DeploymentForAutomation -DeploymentId $DeploymentId -AutomationConfig $automationConfig

                Write-CustomLog -Level 'SUCCESS' -Message "Deployment automation configured successfully"

                return [PSCustomObject]@{
                    Success = $true
                    DeploymentId = $DeploymentId
                    AutomationType = $AutomationType
                    ConfigurationPath = $configPath
                    NextScheduledRun = $automationConfig.Schedule.NextRun
                    EnabledFeatures = @(
                        if ($EnableDriftDetection) { 'DriftDetection' }
                        if ($EnableAutoBackup) { 'AutoBackup' }
                        if ($EnableAutoRollback) { 'AutoRollback' }
                        if ($NotificationEndpoint) { 'Notifications' }
                    )
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to configure deployment automation: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-NextScheduledRun {
    param([string]$Schedule)

    $now = Get-Date

    switch ($Schedule) {
        'Hourly' { return $now.AddHours(1) }
        'Daily' { return $now.AddDays(1).Date.AddHours(2) }  # 2 AM
        'Weekly' {
            $daysUntilSunday = 7 - [int]$now.DayOfWeek
            return $now.AddDays($daysUntilSunday).Date.AddHours(2)
        }
        'Monthly' {
            $firstOfNextMonth = (Get-Date -Day 1).AddMonths(1)
            return $firstOfNextMonth.AddHours(2)
        }
        default { return $now.AddDays(1) }
    }
}

function Setup-ScheduledDeployment {
    param(
        [hashtable]$Config,
        [string]$DeploymentId
    )

    Write-CustomLog -Level 'INFO' -Message "Configuring scheduled deployment automation"

    $Config.Tasks = @(
        @{
            Name = 'PreDeploymentBackup'
            Enabled = $Config.Features.AutoBackup.Enabled
            Script = 'New-DeploymentSnapshot -DeploymentId $DeploymentId -Name "scheduled-backup-$(Get-Date -Format "yyyyMMdd-HHmm")"'
        },
        @{
            Name = 'DeploymentExecution'
            Enabled = $true
            Script = 'Start-InfrastructureDeployment -ConfigurationPath $ConfigurationPath'
        },
        @{
            Name = 'PostDeploymentValidation'
            Enabled = $true
            Script = 'Test-InfrastructureDrift -DeploymentId $DeploymentId'
        }
    )

    return $Config
}

function Setup-ContinuousDeployment {
    param(
        [hashtable]$Config,
        [string]$DeploymentId
    )

    Write-CustomLog -Level 'INFO' -Message "Configuring continuous deployment automation"

    $Config.Features.RepositoryWatching = @{
        Enabled = $true
        CheckInterval = 15  # minutes
        AutoDeploy = $true
    }

    $Config.Tasks = @(
        @{
            Name = 'RepositorySync'
            Enabled = $true
            Script = 'Sync-InfrastructureRepository -Name $RepositoryName'
        },
        @{
            Name = 'ConfigurationValidation'
            Enabled = $true
            Script = 'Test-ProviderConfiguration -Configuration $Configuration -ProviderName $ProviderName'
        },
        @{
            Name = 'AutomaticDeployment'
            Enabled = $true
            Script = 'Start-InfrastructureDeployment -ConfigurationPath $ConfigurationPath -AutoApprove'
        }
    )

    return $Config
}

function Setup-MaintenanceWorkflow {
    param(
        [hashtable]$Config,
        [string]$DeploymentId
    )

    Write-CustomLog -Level 'INFO' -Message "Configuring maintenance workflow automation"

    $Config.Tasks = @(
        @{
            Name = 'DriftDetection'
            Enabled = $Config.Features.DriftDetection.Enabled
            Script = 'Test-InfrastructureDrift -DeploymentId $DeploymentId -SaveReport'
        },
        @{
            Name = 'BackupRotation'
            Enabled = $Config.Features.AutoBackup.Enabled
            Script = 'Remove-OldDeploymentSnapshots -DeploymentId $DeploymentId -RetainCount $RetainCount'
        },
        @{
            Name = 'HealthCheck'
            Enabled = $true
            Script = 'Test-DeploymentHealth -DeploymentId $DeploymentId'
        },
        @{
            Name = 'UpdateCheck'
            Enabled = $true
            Script = 'Test-DeploymentUpdates -DeploymentId $DeploymentId'
        }
    )

    return $Config
}

function Setup-MonitoringWorkflow {
    param(
        [hashtable]$Config,
        [string]$DeploymentId
    )

    Write-CustomLog -Level 'INFO' -Message "Configuring monitoring workflow automation"

    $Config.Features.Monitoring = @{
        Enabled = $true
        MetricsCollection = $true
        AlertThresholds = @{
            DriftPercentage = 10
            FailureRate = 5
            ResponseTime = 30
        }
    }

    $Config.Tasks = @(
        @{
            Name = 'ContinuousDriftMonitoring'
            Enabled = $Config.Features.DriftDetection.Enabled
            Script = 'Start-ContinuousDriftMonitoring -DeploymentId $DeploymentId'
        },
        @{
            Name = 'PerformanceMonitoring'
            Enabled = $true
            Script = 'Test-DeploymentPerformance -DeploymentId $DeploymentId'
        },
        @{
            Name = 'AlertProcessing'
            Enabled = $Config.Features.Notifications.Enabled
            Script = 'Process-DeploymentAlerts -DeploymentId $DeploymentId'
        }
    )

    return $Config
}

function New-AutomationTasks {
    param(
        [hashtable]$Config,
        [string]$AutomationDir
    )

    # Create PowerShell scripts for each task
    foreach ($task in $Config.Tasks) {
        if ($task.Enabled) {
            $scriptPath = Join-Path $AutomationDir "$($task.Name).ps1"

            $scriptContent = @"
# Automated task: $($task.Name)
# Generated: $(Get-Date)
# Deployment: $($Config.DeploymentId)

param(
    [string]`$DeploymentId = '$($Config.DeploymentId)',
    [string]`$ConfigurationPath,
    [string]`$RepositoryName,
    [string]`$ProviderName,
    [int]`$RetainCount = $($Config.Features.AutoBackup.Retention)
)

try {
    Write-Host "Starting automated task: $($task.Name)"

    # Import required modules
    Import-Module (Join-Path `$env:PROJECT_ROOT "aither-core/modules/OpenTofuProvider") -Force

    # Execute task script
    $($task.Script)

    Write-Host "Completed automated task: $($task.Name)"

} catch {
    Write-Error "Automated task failed: `$(`$_.Exception.Message)"
    exit 1
}
"@

            $scriptContent | Set-Content -Path $scriptPath
            Write-CustomLog -Level 'INFO' -Message "Created automation script: $($task.Name).ps1"
        }
    }
}

function Register-AutomationTasks {
    param(
        [hashtable]$Config,
        [string]$DeploymentId
    )

    if (-not $IsWindows) {
        Write-CustomLog -Level 'INFO' -Message "Task scheduling not implemented for this platform"
        return
    }

    try {
        # Register scheduled tasks with Windows Task Scheduler
        $taskName = "AitherZero-Deployment-$DeploymentId"

        # Create task action
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File `"$AutomationDir\MaintenanceTask.ps1`""

        # Create task trigger based on schedule
        $trigger = switch ($Config.Schedule.Type) {
            'Hourly' { New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) }
            'Daily' { New-ScheduledTaskTrigger -Daily -At "02:00" }
            'Weekly' { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "02:00" }
            'Monthly' { New-ScheduledTaskTrigger -Once -At (Get-Date).AddMonths(1) -RepetitionInterval (New-TimeSpan -Days 30) }
            default { New-ScheduledTaskTrigger -Daily -At "02:00" }
        }

        # Register the task
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Description "AitherZero automated deployment task for $DeploymentId"

        Write-CustomLog -Level 'SUCCESS' -Message "Registered scheduled task: $taskName"

    } catch {
        Write-CustomLog -Level 'WARN' -Message "Failed to register scheduled task: $_"
    }
}

function Update-DeploymentForAutomation {
    param(
        [string]$DeploymentId,
        [hashtable]$AutomationConfig
    )

    $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
    $statePath = Join-Path $deploymentPath "state.json"

    if (Test-Path $statePath) {
        try {
            $state = Get-Content $statePath | ConvertFrom-Json

            $state | Add-Member -NotePropertyName 'Automation' -NotePropertyValue @{
                Enabled = $true
                Type = $AutomationConfig.AutomationType
                ConfiguredAt = $AutomationConfig.CreatedAt
                NextRun = $AutomationConfig.Schedule.NextRun
            } -Force

            $state | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath

        } catch {
            Write-CustomLog -Level 'WARN' -Message "Failed to update deployment state with automation info: $_"
        }
    }
}

function Stop-DeploymentAutomation {
    <#
    .SYNOPSIS
        Stops automated deployment workflows.

    .DESCRIPTION
        Disables and removes automated deployment processes for a specific deployment.

    .PARAMETER DeploymentId
        ID of the deployment to stop automation for.

    .PARAMETER RemoveConfiguration
        Remove automation configuration files.

    .PARAMETER UnregisterTasks
        Unregister scheduled tasks.

    .EXAMPLE
        Stop-DeploymentAutomation -DeploymentId "abc123" -RemoveConfiguration

    .OUTPUTS
        Operation result
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,

        [Parameter()]
        [switch]$RemoveConfiguration,

        [Parameter()]
        [switch]$UnregisterTasks
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Stopping deployment automation for: $DeploymentId"
    }

    process {
        try {
            $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
            $automationDir = Join-Path $deploymentPath "automation"

            if ($PSCmdlet.ShouldProcess($DeploymentId, "Stop deployment automation")) {
                # Unregister scheduled tasks
                if ($UnregisterTasks -and $IsWindows) {
                    try {
                        $taskName = "AitherZero-Deployment-$DeploymentId"
                        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                        Write-CustomLog -Level 'SUCCESS' -Message "Unregistered scheduled task: $taskName"
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to unregister scheduled task: $_"
                    }
                }

                # Remove configuration files
                if ($RemoveConfiguration -and (Test-Path $automationDir)) {
                    Remove-Item -Path $automationDir -Recurse -Force
                    Write-CustomLog -Level 'SUCCESS' -Message "Removed automation configuration"
                } else {
                    # Just disable automation
                    $configPath = Join-Path $automationDir "automation-config.json"
                    if (Test-Path $configPath) {
                        $config = Get-Content $configPath | ConvertFrom-Json
                        $config.Enabled = $false
                        $config.Status = 'Disabled'
                        $config.LastModified = Get-Date

                        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
                        Write-CustomLog -Level 'SUCCESS' -Message "Disabled deployment automation"
                    }
                }

                # Update deployment state
                $statePath = Join-Path $deploymentPath "state.json"
                if (Test-Path $statePath) {
                    $state = Get-Content $statePath | ConvertFrom-Json
                    if ($state.Automation) {
                        $state.Automation.Enabled = $false
                    }
                    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath
                }

                return [PSCustomObject]@{
                    Success = $true
                    DeploymentId = $DeploymentId
                    Message = "Deployment automation stopped successfully"
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to stop deployment automation: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-DeploymentAutomation {
    <#
    .SYNOPSIS
        Gets automation configuration for deployments.

    .DESCRIPTION
        Retrieves automation configuration and status for one or more deployments.

    .PARAMETER DeploymentId
        ID of the deployment to get automation info for.

    .PARAMETER IncludeHistory
        Include automation execution history.

    .EXAMPLE
        Get-DeploymentAutomation -DeploymentId "abc123" -IncludeHistory

    .OUTPUTS
        Automation configuration and status
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeploymentId,

        [Parameter()]
        [switch]$IncludeHistory
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting deployment automation information"
    }

    process {
        try {
            $automationInfo = @()

            if ($DeploymentId) {
                $deploymentDirs = @(Get-Item (Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId) -ErrorAction SilentlyContinue)
            } else {
                $deploymentsDir = Join-Path $env:PROJECT_ROOT "deployments"
                $deploymentDirs = Get-ChildItem -Path $deploymentsDir -Directory -ErrorAction SilentlyContinue
            }

            foreach ($dir in $deploymentDirs) {
                $automationDir = Join-Path $dir.FullName "automation"
                $configPath = Join-Path $automationDir "automation-config.json"

                if (Test-Path $configPath) {
                    try {
                        $config = Get-Content $configPath | ConvertFrom-Json

                        if (-not $IncludeHistory) {
                            $config.PSObject.Properties.Remove('History')
                        }

                        $automationInfo += $config
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to load automation config for $($dir.Name): $_"
                    }
                }
            }

            return $automationInfo

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get deployment automation: $($_.Exception.Message)"
            throw
        }
    }
}
