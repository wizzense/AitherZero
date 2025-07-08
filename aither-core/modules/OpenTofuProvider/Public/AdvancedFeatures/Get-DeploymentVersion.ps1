function Get-DeploymentVersion {
    <#
    .SYNOPSIS
        Retrieves deployment version information
    .DESCRIPTION
        Gets version history, specific version details, or current version
        of a deployment with full metadata
    .PARAMETER DeploymentId
        Deployment identifier
    .PARAMETER Version
        Specific version to retrieve
    .PARAMETER Latest
        Get only the latest version
    .PARAMETER Count
        Number of recent versions to retrieve
    .EXAMPLE
        Get-DeploymentVersion -DeploymentId "lab-prod-001" -Latest
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,

        [Parameter(ParameterSetName = 'Specific')]
        [ValidatePattern('^\d+\.\d+\.\d+(-\w+)?$')]
        [string]$Version,

        [Parameter(ParameterSetName = 'Latest')]
        [switch]$Latest,

        [Parameter(ParameterSetName = 'Recent')]
        [ValidateRange(1, 100)]
        [int]$Count = 10
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Retrieving deployment version information for: $DeploymentId"

        # Get deployment state
        $deploymentState = Get-DeploymentState -DeploymentId $DeploymentId
        if (-not $deploymentState) {
            throw "Deployment not found: $DeploymentId"
        }

        # Get version history
        $versionPath = Join-Path $deploymentState.WorkingDirectory ".versions"
        $versionFile = Join-Path $versionPath "versions.json"

        if (-not (Test-Path $versionFile)) {
            Write-CustomLog -Level 'WARNING' -Message "No version history found for deployment: $DeploymentId"
            return $null
        }

        $versions = Get-Content $versionFile -Raw | ConvertFrom-Json

        switch ($PSCmdlet.ParameterSetName) {
            'Specific' {
                # Find specific version
                $versionRecord = $versions.Versions | Where-Object { $_.Version -eq $Version }

                if (-not $versionRecord) {
                    throw "Version not found: $Version"
                }

                # Enrich with additional details
                $result = [PSCustomObject]@{
                    DeploymentId = $DeploymentId
                    Version = $versionRecord.Version
                    Timestamp = $versionRecord.Timestamp
                    Description = $versionRecord.Description
                    Tags = $versionRecord.Tags
                    CreatedBy = $versionRecord.CreatedBy
                    Changes = $versionRecord.Changes
                    ResourceCount = $versionRecord.State.ResourceCount
                    StateChecksum = $versionRecord.State.Checksum
                    IsCurrent = $versionRecord.Version -eq $versions.CurrentVersion
                }

                # Check if state file exists
                if ($versionRecord.StatePath -and (Test-Path $versionRecord.StatePath)) {
                    $result | Add-Member -NotePropertyName StateFileExists -NotePropertyValue $true
                    $result | Add-Member -NotePropertyName StateFileSize -NotePropertyValue (Get-Item $versionRecord.StatePath).Length
                }
                else {
                    $result | Add-Member -NotePropertyName StateFileExists -NotePropertyValue $false
                }

                # Check if snapshot exists
                if ($versionRecord.SnapshotPath -and (Test-Path $versionRecord.SnapshotPath)) {
                    $result | Add-Member -NotePropertyName SnapshotExists -NotePropertyValue $true
                    $result | Add-Member -NotePropertyName SnapshotId -NotePropertyValue $versionRecord.SnapshotId
                }
                else {
                    $result | Add-Member -NotePropertyName SnapshotExists -NotePropertyValue $false
                }

                return $result
            }

            'Latest' {
                # Return current version details
                $currentVersion = $versions.Versions | Where-Object { $_.Version -eq $versions.CurrentVersion }

                if ($currentVersion) {
                    return [PSCustomObject]@{
                        DeploymentId = $DeploymentId
                        Version = $currentVersion.Version
                        Timestamp = $currentVersion.Timestamp
                        Description = $currentVersion.Description
                        Tags = $currentVersion.Tags
                        CreatedBy = $currentVersion.CreatedBy
                        Changes = $currentVersion.Changes
                        ResourceCount = $currentVersion.State.ResourceCount
                        IsCurrent = $true
                    }
                }
                else {
                    Write-CustomLog -Level 'WARNING' -Message "Current version record not found"
                    return $null
                }
            }

            'Recent' {
                # Return recent versions
                $recentVersions = $versions.Versions | Select-Object -Last $Count

                $results = @()
                foreach ($ver in $recentVersions) {
                    $results += [PSCustomObject]@{
                        Version = $ver.Version
                        Timestamp = $ver.Timestamp
                        Description = $ver.Description
                        CreatedBy = $ver.CreatedBy
                        ResourceCount = $ver.State.ResourceCount
                        IsCurrent = $ver.Version -eq $versions.CurrentVersion
                    }
                }

                return $results | Sort-Object { [version]($_.Version -replace '-.*$', '') } -Descending
            }

            'All' {
                # Return version summary
                $versionList = $versions.Versions | ForEach-Object {
                    [PSCustomObject]@{
                        Version = $_.Version
                        Timestamp = $_.Timestamp
                        Description = $_.Description
                        IsCurrent = $_.Version -eq $versions.CurrentVersion
                    }
                }

                $summary = [PSCustomObject]@{
                    DeploymentId = $DeploymentId
                    CurrentVersion = $versions.CurrentVersion
                    TotalVersions = $versions.Versions.Count
                    OldestVersion = $versions.Versions[0].Version
                    NewestVersion = $versions.CurrentVersion
                    Versions = $versionList | Sort-Object { [version]($_.Version -replace '-.*$', '') } -Descending
                }

                return $summary
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve deployment version: $_"
        throw
    }
}
