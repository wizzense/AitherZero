function Get-DeploymentHistory {
    <#
    .SYNOPSIS
        Gets the deployment history for infrastructure deployments.

    .DESCRIPTION
        Retrieves deployment history information including versions, changes,
        timestamps, and deployment outcomes. Supports filtering and formatting
        options for analysis and reporting.

    .PARAMETER DeploymentId
        ID of the specific deployment to get history for.

    .PARAMETER Repository
        Repository name to filter history by.

    .PARAMETER TimeRange
        Time range for filtering history (Last24Hours, LastWeek, LastMonth, All).

    .PARAMETER Status
        Filter by deployment status.

    .PARAMETER IncludeDetails
        Include detailed information about each deployment.

    .PARAMETER OutputFormat
        Output format (Object, Table, JSON, CSV, Timeline).

    .PARAMETER ExportPath
        Path to export history data.

    .EXAMPLE
        Get-DeploymentHistory -DeploymentId "abc123"

    .EXAMPLE
        Get-DeploymentHistory -Repository "lab-infrastructure" -TimeRange "LastWeek" -OutputFormat "Timeline"

    .EXAMPLE
        Get-DeploymentHistory -Status "Completed" -IncludeDetails -ExportPath ".\deployment-history.csv"

    .OUTPUTS
        Deployment history information
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DeploymentId,

        [Parameter()]
        [string]$Repository,

        [Parameter()]
        [ValidateSet('Last24Hours', 'LastWeek', 'LastMonth', 'All')]
        [string]$TimeRange = 'All',

        [Parameter()]
        [ValidateSet('Completed', 'Failed', 'Running', 'RolledBack', 'CompletedWithWarnings')]
        [string]$Status,

        [Parameter()]
        [switch]$IncludeDetails,

        [Parameter()]
        [ValidateSet('Object', 'Table', 'JSON', 'CSV', 'Timeline')]
        [string]$OutputFormat = 'Object',

        [Parameter()]
        [string]$ExportPath
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting deployment history"

        $deploymentsDir = Join-Path $env:PROJECT_ROOT "deployments"

        if (-not (Test-Path $deploymentsDir)) {
            Write-CustomLog -Level 'WARN' -Message "No deployments directory found"
            return @()
        }
    }

    process {
        try {
            $historyEntries = @()

            # Determine which deployments to examine
            if ($DeploymentId) {
                $deploymentDirs = @(Get-Item (Join-Path $deploymentsDir $DeploymentId) -ErrorAction SilentlyContinue)
            } else {
                $deploymentDirs = Get-ChildItem -Path $deploymentsDir -Directory
            }

            foreach ($dir in $deploymentDirs) {
                try {
                    $history = Get-SingleDeploymentHistory -DeploymentPath $dir.FullName -IncludeDetails:$IncludeDetails

                    if ($history) {
                        # Apply filters
                        if ($Repository -and $history.Repository -ne $Repository) {
                            continue
                        }

                        if ($Status -and $history.Status -ne $Status) {
                            continue
                        }

                        # Apply time range filter
                        if ($TimeRange -ne 'All') {
                            $cutoffDate = switch ($TimeRange) {
                                'Last24Hours' { (Get-Date).AddDays(-1) }
                                'LastWeek' { (Get-Date).AddDays(-7) }
                                'LastMonth' { (Get-Date).AddDays(-30) }
                            }

                            if ($history.StartTime -lt $cutoffDate) {
                                continue
                            }
                        }

                        $historyEntries += $history
                    }
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to load deployment history for $($dir.Name): $_"
                }
            }

            # Sort by start time (newest first)
            $historyEntries = $historyEntries | Sort-Object StartTime -Descending

            # Format output
            $result = Format-DeploymentHistory -History $historyEntries -OutputFormat $OutputFormat -IncludeDetails:$IncludeDetails

            # Export if requested
            if ($ExportPath) {
                Export-DeploymentHistory -History $historyEntries -ExportPath $ExportPath -OutputFormat $OutputFormat
                Write-CustomLog -Level 'INFO' -Message "Deployment history exported to: $ExportPath"
            }

            return $result

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get deployment history: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-SingleDeploymentHistory {
    param(
        [string]$DeploymentPath,
        [switch]$IncludeDetails
    )

    try {
        # Load deployment state
        $statePath = Join-Path $DeploymentPath "state.json"
        if (-not (Test-Path $statePath)) {
            return $null
        }

        $state = Get-Content $statePath | ConvertFrom-Json

        # Create history entry
        $historyEntry = @{
            DeploymentId = $state.Id
            StartTime = [DateTime]$state.StartTime
            EndTime = if ($state.EndTime) { [DateTime]$state.EndTime } else { $null }
            Duration = if ($state.EndTime) {
                [DateTime]$state.EndTime - [DateTime]$state.StartTime
            } else {
                (Get-Date) - [DateTime]$state.StartTime
            }
            Status = $state.Status
            ConfigurationPath = $state.ConfigurationPath
            CompletedStages = @($state.CompletedStages)
            Errors = @($state.Errors)
            Warnings = @($state.Warnings)
            Repository = $null
            Template = $null
            Version = $null
            User = $env:USERNAME
            Changes = @()
        }

        # Extract additional information from configuration if available
        $configPath = Join-Path $DeploymentPath "deployment-config.json"
        if (Test-Path $configPath) {
            try {
                $config = Get-Content $configPath | ConvertFrom-Json

                if ($config.repository) {
                    $historyEntry.Repository = $config.repository.name
                    $historyEntry.Version = $config.repository.version
                }

                if ($config.template) {
                    $historyEntry.Template = $config.template.name
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not parse deployment configuration"
            }
        }

        # Get deployment plan information if available
        $planPath = Join-Path $DeploymentPath "deployment-plan.json"
        if (Test-Path $planPath -and $IncludeDetails) {
            try {
                $plan = Get-Content $planPath | ConvertFrom-Json

                $historyEntry.Plan = @{
                    TotalStages = $plan.Stages.Count
                    EstimatedDuration = $plan.EstimatedDuration
                    ParallelExecution = $plan.ParallelExecution
                    RequiredISOs = $plan.RequiredISOs.Count
                    Resources = $plan.Resources.Count
                }
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not parse deployment plan"
            }
        }

        # Get rollback information if available
        if ($state.Rollbacks) {
            $historyEntry.Rollbacks = @($state.Rollbacks)
            $historyEntry.LastRollback = $state.LastRollback
        }

        # Load change history if available
        $changesPath = Join-Path $DeploymentPath "changes.json"
        if (Test-Path $changesPath -and $IncludeDetails) {
            try {
                $changes = Get-Content $changesPath | ConvertFrom-Json
                $historyEntry.Changes = @($changes)
            } catch {
                Write-CustomLog -Level 'DEBUG' -Message "Could not parse deployment changes"
            }
        }

        return [PSCustomObject]$historyEntry

    } catch {
        Write-CustomLog -Level 'WARN' -Message "Error loading deployment history from $DeploymentPath`: $_"
        return $null
    }
}

function Format-DeploymentHistory {
    param(
        [array]$History,
        [string]$OutputFormat,
        [switch]$IncludeDetails
    )

    switch ($OutputFormat) {
        'Table' {
            if ($IncludeDetails) {
                return $History | Format-Table -Property DeploymentId, StartTime, Duration, Status, Repository, Template,
                    @{Name='Stages'; Expression={$_.CompletedStages.Count}},
                    @{Name='Errors'; Expression={$_.Errors.Count}} -AutoSize
            } else {
                return $History | Format-Table -Property DeploymentId, StartTime, Status, Repository, Duration -AutoSize
            }
        }

        'JSON' {
            return $History | ConvertTo-Json -Depth 10
        }

        'CSV' {
            return $History | ConvertTo-Csv -NoTypeInformation
        }

        'Timeline' {
            return Format-DeploymentTimeline -History $History
        }

        default {
            return $History
        }
    }
}

function Format-DeploymentTimeline {
    param([array]$History)

    Write-Host "`n=== DEPLOYMENT TIMELINE ===" -ForegroundColor Cyan

    if ($History.Count -eq 0) {
        Write-Host "No deployments found" -ForegroundColor Gray
        return
    }

    # Group by date
    $groupedHistory = $History | Group-Object { $_.StartTime.Date } | Sort-Object Name -Descending

    foreach ($dateGroup in $groupedHistory) {
        $date = [DateTime]$dateGroup.Name
        Write-Host "`n$($date.ToString('yyyy-MM-dd')):" -ForegroundColor Yellow

        $dayDeployments = $dateGroup.Group | Sort-Object StartTime -Descending

        foreach ($deployment in $dayDeployments) {
            $time = $deployment.StartTime.ToString('HH:mm')
            $status = $deployment.Status
            $duration = if ($deployment.Duration) {
                "$([Math]::Round($deployment.Duration.TotalMinutes, 1))m"
            } else {
                "Running..."
            }

            $statusColor = switch ($status) {
                'Completed' { 'Green' }
                'Failed' { 'Red' }
                'Running' { 'Yellow' }
                'RolledBack' { 'Magenta' }
                default { 'White' }
            }

            $repo = if ($deployment.Repository) { "[$($deployment.Repository)]" } else { "" }

            Write-Host "  $time " -NoNewline -ForegroundColor Gray
            Write-Host "$($deployment.DeploymentId.Substring(0,8))... " -NoNewline
            Write-Host "$status " -ForegroundColor $statusColor -NoNewline
            Write-Host "$repo ($duration)" -ForegroundColor Gray
        }
    }

    Write-Host "`nTotal deployments: $($History.Count)" -ForegroundColor Cyan
    Write-Host "============================`n" -ForegroundColor Cyan
}

function Export-DeploymentHistory {
    param(
        [array]$History,
        [string]$ExportPath,
        [string]$OutputFormat
    )

    try {
        # Ensure directory exists
        $exportDir = Split-Path $ExportPath -Parent
        if ($exportDir -and -not (Test-Path $exportDir)) {
            New-Item -Path $exportDir -ItemType Directory -Force | Out-Null
        }

        switch ($OutputFormat) {
            'CSV' {
                $History | Export-Csv -Path $ExportPath -NoTypeInformation
            }

            'JSON' {
                $History | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportPath
            }

            default {
                # Export as formatted text
                $History | Format-Table | Out-String | Set-Content -Path $ExportPath
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to export deployment history: $_"
        throw
    }
}

function New-DeploymentVersion {
    <#
    .SYNOPSIS
        Creates a new version entry for a deployment.

    .DESCRIPTION
        Records a new version in the deployment history with changes,
        configuration updates, and metadata.

    .PARAMETER DeploymentId
        ID of the deployment to version.

    .PARAMETER Version
        Version number (auto-incremented if not specified).

    .PARAMETER Description
        Description of changes in this version.

    .PARAMETER Changes
        List of changes made in this version.

    .PARAMETER ConfigurationPath
        Path to configuration file for this version.

    .PARAMETER Tags
        Tags to associate with this version.

    .EXAMPLE
        New-DeploymentVersion -DeploymentId "abc123" -Description "Updated VM specifications"

    .EXAMPLE
        New-DeploymentVersion -DeploymentId "abc123" -Version "1.2.0" -Changes @("Added load balancer", "Updated security groups")

    .OUTPUTS
        Version creation result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string[]]$Changes = @(),

        [Parameter()]
        [string]$ConfigurationPath,

        [Parameter()]
        [string[]]$Tags = @()
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating new deployment version for: $DeploymentId"

        $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId

        if (-not (Test-Path $deploymentPath)) {
            throw "Deployment '$DeploymentId' not found"
        }

        $versionsPath = Join-Path $deploymentPath "versions.json"
    }

    process {
        try {
            # Load existing versions
            $versions = if (Test-Path $versionsPath) {
                Get-Content $versionsPath | ConvertFrom-Json
            } else {
                @()
            }

            # Determine next version number if not specified
            if (-not $Version) {
                if ($versions.Count -eq 0) {
                    $Version = "1.0.0"
                } else {
                    $lastVersion = $versions | Sort-Object { [Version]$_.Version } | Select-Object -Last 1
                    $lastVersionObj = [Version]$lastVersion.Version
                    $Version = "$($lastVersionObj.Major).$($lastVersionObj.Minor).$($lastVersionObj.Build + 1)"
                }
            }

            # Create new version entry
            $newVersion = @{
                Version = $Version
                Timestamp = Get-Date
                Description = $Description
                Changes = @($Changes)
                ConfigurationPath = $ConfigurationPath
                Tags = @($Tags)
                CreatedBy = $env:USERNAME
                DeploymentId = $DeploymentId
                VersionId = [Guid]::NewGuid().ToString()
            }

            # Add to versions array
            $versions = @($versions) + $newVersion

            # Save versions
            $versions | ConvertTo-Json -Depth 10 | Set-Content -Path $versionsPath

            # Update deployment state with latest version
            $statePath = Join-Path $deploymentPath "state.json"
            if (Test-Path $statePath) {
                $state = Get-Content $statePath | ConvertFrom-Json
                $state | Add-Member -NotePropertyName 'CurrentVersion' -NotePropertyValue $Version -Force
                $state | Add-Member -NotePropertyName 'LastVersionUpdate' -NotePropertyValue (Get-Date) -Force

                $state | ConvertTo-Json -Depth 10 | Set-Content -Path $statePath
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Created version $Version for deployment $DeploymentId"

            return [PSCustomObject]@{
                Success = $true
                Version = $Version
                VersionId = $newVersion.VersionId
                Timestamp = $newVersion.Timestamp
                DeploymentId = $DeploymentId
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment version: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-DeploymentVersion {
    <#
    .SYNOPSIS
        Gets version information for a deployment.

    .DESCRIPTION
        Retrieves version history and information for a specific deployment.

    .PARAMETER DeploymentId
        ID of the deployment.

    .PARAMETER Version
        Specific version to retrieve.

    .PARAMETER Latest
        Get the latest version only.

    .PARAMETER IncludeChanges
        Include change details in the output.

    .EXAMPLE
        Get-DeploymentVersion -DeploymentId "abc123"

    .EXAMPLE
        Get-DeploymentVersion -DeploymentId "abc123" -Version "1.2.0" -IncludeChanges

    .OUTPUTS
        Version information objects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [switch]$Latest,

        [Parameter()]
        [switch]$IncludeChanges
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting deployment version information"

        $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
        $versionsPath = Join-Path $deploymentPath "versions.json"

        if (-not (Test-Path $versionsPath)) {
            Write-CustomLog -Level 'INFO' -Message "No version history found for deployment"
            return @()
        }
    }

    process {
        try {
            $versions = Get-Content $versionsPath | ConvertFrom-Json

            if ($Version) {
                # Get specific version
                $result = $versions | Where-Object { $_.Version -eq $Version }
                if (-not $result) {
                    Write-CustomLog -Level 'WARN' -Message "Version '$Version' not found"
                    return $null
                }
                return $result
            } elseif ($Latest) {
                # Get latest version
                $result = $versions | Sort-Object { [Version]$_.Version } | Select-Object -Last 1
                return $result
            } else {
                # Get all versions
                $result = $versions | Sort-Object { [Version]$_.Version } -Descending
                return $result
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get deployment version: $($_.Exception.Message)"
            throw
        }
    }
}
