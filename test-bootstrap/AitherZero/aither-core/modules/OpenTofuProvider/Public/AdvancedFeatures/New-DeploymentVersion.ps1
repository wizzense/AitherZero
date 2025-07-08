function New-DeploymentVersion {
    <#
    .SYNOPSIS
        Creates a new versioned deployment from current state
    .DESCRIPTION
        Tags current deployment state with a version number and creates an immutable
        record for rollback and history tracking
    .PARAMETER DeploymentId
        Deployment to version
    .PARAMETER Version
        Semantic version number (e.g., 1.2.0)
    .PARAMETER Description
        Version description or release notes
    .PARAMETER Tags
        Additional tags for the version
    .PARAMETER AutoIncrement
        Automatically increment version based on change type
    .EXAMPLE
        New-DeploymentVersion -DeploymentId "lab-prod-001" -Version "1.2.0" -Description "Added monitoring dashboard"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,
        
        [Parameter(Mandatory, ParameterSetName = 'Manual')]
        [ValidatePattern('^\d+\.\d+\.\d+(-\w+)?$')]
        [string]$Version,
        
        [Parameter(ParameterSetName = 'Auto')]
        [ValidateSet('Major', 'Minor', 'Patch')]
        [string]$AutoIncrement = 'Patch',
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [string[]]$Tags,
        
        [Parameter()]
        [switch]$CreateSnapshot
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Creating new deployment version for: $DeploymentId"
        
        # Get deployment state
        $deploymentState = Get-DeploymentState -DeploymentId $DeploymentId
        if (-not $deploymentState) {
            throw "Deployment not found: $DeploymentId"
        }
        
        # Get version history
        $versionPath = Join-Path $deploymentState.WorkingDirectory ".versions"
        if (-not (Test-Path $versionPath)) {
            New-Item -ItemType Directory -Path $versionPath -Force | Out-Null
        }
        
        $versionFile = Join-Path $versionPath "versions.json"
        $versions = if (Test-Path $versionFile) {
            Get-Content $versionFile -Raw | ConvertFrom-Json
        }
        else {
            @{
                DeploymentId = $DeploymentId
                CurrentVersion = "0.0.0"
                Versions = @()
            }
        }
        
        # Determine version number
        if ($PSCmdlet.ParameterSetName -eq 'Auto') {
            $currentVersion = [version]($versions.CurrentVersion -replace '-.*$', '')
            
            switch ($AutoIncrement) {
                'Major' {
                    $Version = "$($currentVersion.Major + 1).0.0"
                }
                'Minor' {
                    $Version = "$($currentVersion.Major).$($currentVersion.Minor + 1).0"
                }
                'Patch' {
                    $Version = "$($currentVersion.Major).$($currentVersion.Minor).$($currentVersion.Build + 1)"
                }
            }
        }
        
        # Validate version is newer
        $newVersion = [version]($Version -replace '-.*$', '')
        $currentVersion = [version]($versions.CurrentVersion -replace '-.*$', '')
        
        if ($newVersion -le $currentVersion) {
            throw "Version must be greater than current version: $($versions.CurrentVersion)"
        }
        
        # Create version record
        $versionRecord = @{
            Version = $Version
            Timestamp = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
            Description = $Description
            Tags = $Tags
            CreatedBy = $env:USERNAME
            Changes = @()
            State = @{
                ResourceCount = 0
                Checksum = ""
            }
        }
        
        # Get current state info
        $stateFile = Join-Path $deploymentState.WorkingDirectory "terraform.tfstate"
        if (Test-Path $stateFile) {
            $tfState = Get-Content $stateFile -Raw | ConvertFrom-Json
            $versionRecord.State.ResourceCount = $tfState.resources.Count
            $versionRecord.State.Serial = $tfState.serial
            
            # Calculate state checksum
            $stateContent = Get-Content $stateFile -Raw
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stateContent))
            $versionRecord.State.Checksum = [BitConverter]::ToString($hash) -replace '-', ''
        }
        
        # Detect changes from previous version
        if ($versions.Versions.Count -gt 0) {
            $previousVersion = $versions.Versions[-1]
            
            if ($previousVersion.State.ResourceCount -ne $versionRecord.State.ResourceCount) {
                $diff = $versionRecord.State.ResourceCount - $previousVersion.State.ResourceCount
                $versionRecord.Changes += "Resource count changed by $diff"
            }
            
            if ($previousVersion.State.Checksum -ne $versionRecord.State.Checksum) {
                $versionRecord.Changes += "Infrastructure state modified"
            }
        }
        
        # Create snapshot if requested
        if ($CreateSnapshot) {
            $snapshot = Get-DeploymentSnapshot -DeploymentId $DeploymentId
            $versionRecord.SnapshotId = $snapshot.SnapshotId
            $versionRecord.SnapshotPath = $snapshot.FilePath
        }
        
        # Save state file copy
        $versionStatePath = Join-Path $versionPath "state-v$Version.tfstate"
        if (Test-Path $stateFile) {
            Copy-Item -Path $stateFile -Destination $versionStatePath -Force
            $versionRecord.StatePath = $versionStatePath
        }
        
        # Update versions
        $versions.CurrentVersion = $Version
        $versions.Versions += $versionRecord
        
        # Save version history
        if ($PSCmdlet.ShouldProcess("Create version $Version for deployment $DeploymentId")) {
            $versions | ConvertTo-Json -Depth 10 | Set-Content -Path $versionFile -Encoding UTF8
            
            # Create version tag file
            $tagFile = Join-Path $versionPath "v$Version.tag"
            $versionRecord | ConvertTo-Json -Depth 5 | Set-Content -Path $tagFile -Encoding UTF8
            
            Write-CustomLog -Level 'SUCCESS' -Message "Created deployment version: $Version"
            
            return [PSCustomObject]@{
                Version = $Version
                DeploymentId = $DeploymentId
                Timestamp = $versionRecord.Timestamp
                Description = $Description
                ResourceCount = $versionRecord.State.ResourceCount
                SnapshotId = $versionRecord.SnapshotId
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment version: $_"
        throw
    }
}