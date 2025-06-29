function Get-DeploymentStatus {
    <#
    .SYNOPSIS
        Gets the status of a deployment.

    .DESCRIPTION
        Retrieves detailed status information for an active or completed deployment,
        including stage progress, resource status, and any errors or warnings.

    .PARAMETER DeploymentId
        The deployment ID to query.

    .PARAMETER Latest
        Get status of the latest deployment.

    .PARAMETER IncludeHistory
        Include historical deployments in the results.

    .PARAMETER Format
        Output format (Object, Table, Json).

    .PARAMETER Watch
        Continuously monitor deployment status.

    .PARAMETER RefreshInterval
        Refresh interval for watch mode (seconds).

    .EXAMPLE
        Get-DeploymentStatus -DeploymentId "abc123"

    .EXAMPLE
        Get-DeploymentStatus -Latest -Watch

    .EXAMPLE
        Get-DeploymentStatus -IncludeHistory | Format-Table

    .OUTPUTS
        Deployment status object or formatted output
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$DeploymentId,
        
        [Parameter(Mandatory, ParameterSetName = 'Latest')]
        [switch]$Latest,
        
        [Parameter(ParameterSetName = 'History')]
        [switch]$IncludeHistory,
        
        [Parameter()]
        [ValidateSet('Object', 'Table', 'Json', 'Summary')]
        [string]$Format = 'Object',
        
        [Parameter()]
        [switch]$Watch,
        
        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$RefreshInterval = 5
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting deployment status"
        
        # Get deployments directory
        $deploymentsDir = Join-Path $env:PROJECT_ROOT "deployments"
        
        if (-not (Test-Path $deploymentsDir)) {
            Write-CustomLog -Level 'WARN' -Message "No deployments found"
            return
        }
    }
    
    process {
        try {
            # Determine which deployments to query
            $deploymentDirs = @()
            
            switch ($PSCmdlet.ParameterSetName) {
                'ById' {
                    $deploymentDir = Join-Path $deploymentsDir $DeploymentId
                    if (Test-Path $deploymentDir) {
                        $deploymentDirs += Get-Item $deploymentDir
                    } else {
                        throw "Deployment not found: $DeploymentId"
                    }
                }
                
                'Latest' {
                    $latestDeployment = Get-ChildItem -Path $deploymentsDir -Directory | 
                        Sort-Object CreationTime -Descending | 
                        Select-Object -First 1
                    
                    if ($latestDeployment) {
                        $deploymentDirs += $latestDeployment
                    } else {
                        Write-CustomLog -Level 'WARN' -Message "No deployments found"
                        return
                    }
                }
                
                'History' {
                    $deploymentDirs = Get-ChildItem -Path $deploymentsDir -Directory | 
                        Sort-Object CreationTime -Descending
                }
            }
            
            # Get status for each deployment
            $statuses = @()
            
            foreach ($dir in $deploymentDirs) {
                $status = Get-SingleDeploymentStatus -DeploymentPath $dir.FullName
                if ($status) {
                    $statuses += $status
                }
            }
            
            # Handle watch mode
            if ($Watch -and $statuses.Count -eq 1) {
                Watch-DeploymentStatus -DeploymentPath $deploymentDirs[0].FullName -RefreshInterval $RefreshInterval
                return
            }
            
            # Format output
            switch ($Format) {
                'Table' {
                    $statuses | Format-Table -Property DeploymentId, Status, StartTime, Duration, 
                        @{Name='Progress'; Expression={
                            "$($_.CompletedStages.Count)/$($_.TotalStages) stages"
                        }},
                        @{Name='Errors'; Expression={$_.Errors.Count}}
                }
                
                'Json' {
                    $statuses | ConvertTo-Json -Depth 10
                }
                
                'Summary' {
                    foreach ($status in $statuses) {
                        Write-DeploymentStatusSummary -Status $status
                    }
                }
                
                default {
                    # Return objects
                    if ($statuses.Count -eq 1 -and -not $IncludeHistory) {
                        return $statuses[0]
                    } else {
                        return $statuses
                    }
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get deployment status: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-SingleDeploymentStatus {
    param([string]$DeploymentPath)
    
    try {
        # Load deployment state
        $statePath = Join-Path $DeploymentPath "state.json"
        if (-not (Test-Path $statePath)) {
            Write-CustomLog -Level 'WARN' -Message "State file not found for deployment"
            return $null
        }
        
        $state = Get-Content $statePath | ConvertFrom-Json
        
        # Load deployment plan if available
        $planPath = Join-Path $DeploymentPath "deployment-plan.json"
        $plan = $null
        if (Test-Path $planPath) {
            $plan = Get-Content $planPath | ConvertFrom-Json
        }
        
        # Build status object
        $status = [PSCustomObject]@{
            DeploymentId = $state.Id
            Status = $state.Status
            StartTime = [DateTime]$state.StartTime
            EndTime = if ($state.EndTime) { [DateTime]$state.EndTime } else { $null }
            Duration = if ($state.EndTime) { 
                [DateTime]$state.EndTime - [DateTime]$state.StartTime 
            } else { 
                (Get-Date) - [DateTime]$state.StartTime 
            }
            CurrentStage = $state.CurrentStage
            CompletedStages = @($state.CompletedStages)
            TotalStages = if ($plan) { $plan.Stages.Count } else { 5 }
            ConfigurationPath = $state.ConfigurationPath
            Errors = @($state.Errors)
            Warnings = @($state.Warnings)
            IsRunning = $state.Status -in @('Initializing', 'Running:Prepare', 'Running:Validate', 
                                           'Running:Plan', 'Running:Apply', 'Running:Verify')
            Progress = @{
                Percentage = 0
                StagesCompleted = $state.CompletedStages.Count
                CurrentAction = $null
            }
            Resources = @{}
            Outputs = @{}
        }
        
        # Calculate progress
        if ($status.TotalStages -gt 0) {
            $status.Progress.Percentage = [Math]::Round(($status.CompletedStages.Count / $status.TotalStages) * 100, 0)
        }
        
        # Get current action if running
        if ($status.IsRunning -and $status.CurrentStage) {
            $status.Progress.CurrentAction = "Executing stage: $($status.CurrentStage)"
        }
        
        # Load stage results if available
        $stageResults = @{}
        $stageFiles = Get-ChildItem -Path $DeploymentPath -Filter "stage-*.json" -File
        foreach ($stageFile in $stageFiles) {
            try {
                $stageData = Get-Content $stageFile.FullName | ConvertFrom-Json
                $stageName = $stageFile.BaseName -replace '^stage-', ''
                $stageResults[$stageName] = $stageData
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not load stage result: $($stageFile.Name)"
            }
        }
        
        # Extract resource information from Apply stage
        if ($stageResults.ContainsKey('Apply') -and $stageResults['Apply'].Outputs.DeployedResources) {
            $status.Resources = $stageResults['Apply'].Outputs.DeployedResources
        }
        
        # Collect all outputs
        foreach ($stageName in $stageResults.Keys) {
            if ($stageResults[$stageName].Outputs) {
                foreach ($outputKey in $stageResults[$stageName].Outputs.PSObject.Properties.Name) {
                    if ($outputKey -ne 'DeployedResources') {
                        $status.Outputs[$outputKey] = $stageResults[$stageName].Outputs.$outputKey
                    }
                }
            }
        }
        
        # Load artifacts
        $status | Add-Member -NotePropertyName Artifacts -NotePropertyValue @{}
        $artifactsPath = Join-Path $DeploymentPath "artifacts.json"
        if (Test-Path $artifactsPath) {
            try {
                $artifacts = Get-Content $artifactsPath | ConvertFrom-Json
                $status.Artifacts = $artifacts
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not load artifacts"
            }
        }
        
        # Add deployment path for reference
        $status | Add-Member -NotePropertyName DeploymentPath -NotePropertyValue $DeploymentPath
        
        return $status
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Error loading deployment status from $DeploymentPath`: $($_.Exception.Message)"
        return $null
    }
}

function Watch-DeploymentStatus {
    param(
        [string]$DeploymentPath,
        [int]$RefreshInterval
    )
    
    Write-Host "`nWatching deployment status (Press Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host "Refresh interval: $RefreshInterval seconds`n" -ForegroundColor Gray
    
    $previousStatus = $null
    $spinnerChars = @('|', '/', '-', '\')
    $spinnerIndex = 0
    
    try {
        while ($true) {
            # Clear previous output
            if ($null -ne $previousStatus) {
                $linesToClear = 15  # Approximate number of lines in summary
                for ($i = 0; $i -lt $linesToClear; $i++) {
                    Write-Host "`r$(' ' * 80)" -NoNewline
                    if ($i -lt ($linesToClear - 1)) {
                        Write-Host "`n" -NoNewline
                        [Console]::SetCursorPosition(0, [Console]::CursorTop - 1)
                    }
                }
                [Console]::SetCursorPosition(0, [Console]::CursorTop - $linesToClear + 1)
            }
            
            # Get current status
            $status = Get-SingleDeploymentStatus -DeploymentPath $DeploymentPath
            
            if ($status) {
                # Show spinner for running deployments
                if ($status.IsRunning) {
                    $spinner = $spinnerChars[$spinnerIndex % $spinnerChars.Count]
                    $spinnerIndex++
                    Write-Host "$spinner " -NoNewline -ForegroundColor Cyan
                } else {
                    Write-Host "  " -NoNewline
                }
                
                # Display status summary
                Write-DeploymentStatusSummary -Status $status -Compact
                
                # Check if deployment completed
                if ($previousStatus -and $previousStatus.IsRunning -and -not $status.IsRunning) {
                    Write-Host "`nDeployment completed!" -ForegroundColor Green
                    
                    # Show final summary
                    Write-Host "`n$('='*60)" -ForegroundColor Cyan
                    Write-DeploymentStatusSummary -Status $status
                    break
                }
                
                $previousStatus = $status
            }
            
            Start-Sleep -Seconds $RefreshInterval
        }
    } catch {
        Write-Host "`nWatch mode interrupted" -ForegroundColor Yellow
    }
}

function Write-DeploymentStatusSummary {
    param(
        [PSCustomObject]$Status,
        [switch]$Compact
    )
    
    if (-not $Compact) {
        Write-Host "`nDEPLOYMENT STATUS" -ForegroundColor Cyan
        Write-Host "=================" -ForegroundColor Cyan
    }
    
    # Basic info
    Write-Host "ID: $($Status.DeploymentId)"
    Write-Host "Status: " -NoNewline
    
    $statusColor = switch ($Status.Status) {
        'Completed' { 'Green' }
        'CompletedWithWarnings' { 'Yellow' }
        'Failed' { 'Red' }
        'DryRunCompleted' { 'Cyan' }
        default { 'White' }
    }
    Write-Host $Status.Status -ForegroundColor $statusColor
    
    # Timing
    Write-Host "Started: $($Status.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    if ($Status.EndTime) {
        Write-Host "Ended: $($Status.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Host "Duration: $([Math]::Round($Status.Duration.TotalMinutes, 2)) minutes"
    } else {
        Write-Host "Running for: $([Math]::Round($Status.Duration.TotalMinutes, 2)) minutes"
    }
    
    # Progress
    Write-Host "`nProgress: " -NoNewline
    $progressBar = Create-ProgressBar -Percentage $Status.Progress.Percentage -Width 30
    Write-Host $progressBar -NoNewline
    Write-Host " $($Status.Progress.Percentage)% ($($Status.CompletedStages.Count)/$($Status.TotalStages) stages)"
    
    if ($Status.Progress.CurrentAction) {
        Write-Host "Current: $($Status.Progress.CurrentAction)" -ForegroundColor Yellow
    }
    
    # Stages
    if (-not $Compact -and $Status.CompletedStages.Count -gt 0) {
        Write-Host "`nCompleted Stages:" -ForegroundColor Green
        foreach ($stage in $Status.CompletedStages) {
            Write-Host "  ✓ $stage" -ForegroundColor Green
        }
    }
    
    # Resources
    if ($Status.Resources.Count -gt 0) {
        Write-Host "`nDeployed Resources:" -ForegroundColor Cyan
        foreach ($resource in $Status.Resources.GetEnumerator()) {
            Write-Host "  - $($resource.Key): $($resource.Value.Count) instance(s)"
        }
    }
    
    # Errors and Warnings
    if ($Status.Errors.Count -gt 0) {
        Write-Host "`nErrors:" -ForegroundColor Red
        foreach ($error in $Status.Errors | Select-Object -First 3) {
            Write-Host "  - $error" -ForegroundColor Red
        }
        if ($Status.Errors.Count -gt 3) {
            Write-Host "  ... and $($Status.Errors.Count - 3) more" -ForegroundColor Red
        }
    }
    
    if ($Status.Warnings.Count -gt 0) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        foreach ($warning in $Status.Warnings | Select-Object -First 3) {
            Write-Host "  - $warning" -ForegroundColor Yellow
        }
        if ($Status.Warnings.Count -gt 3) {
            Write-Host "  ... and $($Status.Warnings.Count - 3) more" -ForegroundColor Yellow
        }
    }
    
    # Outputs
    if ($Status.Outputs.Count -gt 0 -and -not $Compact) {
        Write-Host "`nOutputs:" -ForegroundColor Green
        foreach ($output in $Status.Outputs.GetEnumerator() | Select-Object -First 5) {
            $value = if ($output.Value -is [string] -and $output.Value.Length -gt 50) {
                $output.Value.Substring(0, 47) + "..."
            } else {
                $output.Value
            }
            Write-Host "  $($output.Key): $value"
        }
        if ($Status.Outputs.Count -gt 5) {
            Write-Host "  ... and $($Status.Outputs.Count - 5) more" -ForegroundColor Gray
        }
    }
    
    if (-not $Compact) {
        Write-Host ""
    }
}

function Create-ProgressBar {
    param(
        [int]$Percentage,
        [int]$Width = 30
    )
    
    $filled = [Math]::Round(($Percentage / 100) * $Width)
    $empty = $Width - $filled
    
    $bar = "[" + ("█" * $filled) + ("░" * $empty) + "]"
    
    return $bar
}

# Export deployment status for other modules
Export-ModuleMember -Function Get-DeploymentStatus