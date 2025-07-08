function New-DeploymentSnapshot {
    <#
    .SYNOPSIS
        Creates a snapshot of the current deployment state.

    .DESCRIPTION
        Captures the current state of a deployment including configuration,
        infrastructure state, and metadata. Snapshots can be used for rollback
        operations and state comparison.

    .PARAMETER DeploymentId
        ID of the deployment to snapshot.

    .PARAMETER Name
        Name for the snapshot.

    .PARAMETER Description
        Optional description for the snapshot.

    .PARAMETER IncludeState
        Include infrastructure state in the snapshot.

    .PARAMETER IncludeConfiguration
        Include deployment configuration in the snapshot.

    .PARAMETER IncludeArtifacts
        Include deployment artifacts in the snapshot.

    .PARAMETER CompressionLevel
        Compression level for snapshot data (None, Optimal, Fastest).

    .PARAMETER PassThru
        Return the created snapshot object.

    .EXAMPLE
        New-DeploymentSnapshot -DeploymentId "abc123" -Name "pre-update"

    .EXAMPLE
        New-DeploymentSnapshot -DeploymentId "abc123" -Name "backup" -Description "Backup before major changes" -IncludeArtifacts

    .OUTPUTS
        Snapshot creation result object
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,
        
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9\-_]+$')]
        [string]$Name,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [switch]$IncludeState = $true,
        
        [Parameter()]
        [switch]$IncludeConfiguration = $true,
        
        [Parameter()]
        [switch]$IncludeArtifacts,
        
        [Parameter()]
        [ValidateSet('None', 'Optimal', 'Fastest')]
        [string]$CompressionLevel = 'Optimal',
        
        [Parameter()]
        [switch]$PassThru
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Creating deployment snapshot: $Name for deployment $DeploymentId"
        
        # Validate deployment exists
        $deployment = Get-DeploymentStatus -DeploymentId $DeploymentId
        if (-not $deployment) {
            throw "Deployment '$DeploymentId' not found"
        }
        
        # Prepare snapshot directory
        $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
        $snapshotsDir = Join-Path $deploymentPath "snapshots"
        
        if (-not (Test-Path $snapshotsDir)) {
            New-Item -Path $snapshotsDir -ItemType Directory -Force | Out-Null
        }
        
        $snapshotPath = Join-Path $snapshotsDir "$Name.json"
        
        # Check if snapshot already exists
        if ((Test-Path $snapshotPath) -and -not $PSCmdlet.ShouldProcess($Name, "Overwrite existing snapshot")) {
            throw "Snapshot '$Name' already exists"
        }
    }
    
    process {
        try {
            # Initialize snapshot object
            $snapshot = @{
                Name = $Name
                Description = $Description
                DeploymentId = $DeploymentId
                CreatedAt = Get-Date
                CreatedBy = $env:USERNAME
                Version = "1.0"
                Configuration = @{}
                State = @{}
                Artifacts = @{}
                Metadata = @{
                    CompressionLevel = $CompressionLevel
                    Size = 0
                    Checksum = $null
                }
            }
            
            if ($PSCmdlet.ShouldProcess($Name, "Create deployment snapshot")) {
                # Capture configuration
                if ($IncludeConfiguration) {
                    Write-CustomLog -Level 'INFO' -Message "Capturing deployment configuration"
                    
                    $configPath = Join-Path $deploymentPath "deployment-config.json"
                    if (Test-Path $configPath) {
                        $snapshot.Configuration = Get-Content $configPath | ConvertFrom-Json
                    }
                    
                    # Also capture original configuration file if available
                    $statePath = Join-Path $deploymentPath "state.json"
                    if (Test-Path $statePath) {
                        $state = Get-Content $statePath | ConvertFrom-Json
                        if ($state.ConfigurationPath -and (Test-Path $state.ConfigurationPath)) {
                            $snapshot.Configuration.OriginalPath = $state.ConfigurationPath
                            $snapshot.Configuration.OriginalContent = Get-Content $state.ConfigurationPath -Raw
                        }
                    }
                }
                
                # Capture infrastructure state
                if ($IncludeState) {
                    Write-CustomLog -Level 'INFO' -Message "Capturing infrastructure state"
                    
                    # Get provider for the deployment
                    $provider = Get-DeploymentProvider -DeploymentId $DeploymentId
                    
                    # Capture current infrastructure state
                    $snapshot.State.Infrastructure = Get-ActualInfrastructureState -DeploymentId $DeploymentId -Provider $provider
                    
                    # Capture OpenTofu state if available
                    $tfStatePath = Join-Path $deploymentPath "terraform.tfstate"
                    if (Test-Path $tfStatePath) {
                        $snapshot.State.TerraformState = Get-Content $tfStatePath | ConvertFrom-Json
                    }
                    
                    # Capture deployment state
                    $deploymentStatePath = Join-Path $deploymentPath "state.json"
                    if (Test-Path $deploymentStatePath) {
                        $snapshot.State.DeploymentState = Get-Content $deploymentStatePath | ConvertFrom-Json
                    }
                }
                
                # Capture artifacts
                if ($IncludeArtifacts) {
                    Write-CustomLog -Level 'INFO' -Message "Capturing deployment artifacts"
                    
                    $artifactsPath = Join-Path $deploymentPath "artifacts"
                    if (Test-Path $artifactsPath) {
                        $artifacts = Get-ChildItem -Path $artifactsPath -Recurse -File
                        
                        foreach ($artifact in $artifacts) {
                            $relativePath = $artifact.FullName.Substring($artifactsPath.Length + 1)
                            $snapshot.Artifacts[$relativePath] = @{
                                Path = $relativePath
                                Content = Get-Content $artifact.FullName -Raw
                                Size = $artifact.Length
                                LastModified = $artifact.LastWriteTime
                            }
                        }
                    }
                    
                    # Capture important files
                    $importantFiles = @(
                        "deployment-plan.json",
                        "deployment.log"
                    )
                    
                    foreach ($file in $importantFiles) {
                        $filePath = Join-Path $deploymentPath $file
                        if (Test-Path $filePath) {
                            $snapshot.Artifacts[$file] = @{
                                Path = $file
                                Content = Get-Content $filePath -Raw
                                Size = (Get-Item $filePath).Length
                                LastModified = (Get-Item $filePath).LastWriteTime
                            }
                        }
                    }
                }
                
                # Add metadata
                $snapshot.Metadata.DeploymentStatus = $deployment.Status
                $snapshot.Metadata.DeploymentStartTime = $deployment.StartTime
                $snapshot.Metadata.Provider = $provider.Name
                
                # Compress snapshot if requested
                if ($CompressionLevel -ne 'None') {
                    $snapshot = Compress-SnapshotData -Snapshot $snapshot -CompressionLevel $CompressionLevel
                }
                
                # Calculate checksum
                $snapshotJson = $snapshot | ConvertTo-Json -Depth 10
                $snapshot.Metadata.Checksum = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($snapshotJson))) -Algorithm SHA256).Hash
                $snapshot.Metadata.Size = [System.Text.Encoding]::UTF8.GetByteCount($snapshotJson)
                
                # Save snapshot
                $snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $snapshotPath -Encoding UTF8
                
                Write-CustomLog -Level 'SUCCESS' -Message "Snapshot '$Name' created successfully"
                Write-CustomLog -Level 'INFO' -Message "Snapshot size: $([Math]::Round($snapshot.Metadata.Size / 1KB, 2)) KB"
                
                # Create result object
                $result = @{
                    Success = $true
                    SnapshotName = $Name
                    SnapshotPath = $snapshotPath
                    Size = $snapshot.Metadata.Size
                    Checksum = $snapshot.Metadata.Checksum
                    CreatedAt = $snapshot.CreatedAt
                }
                
                if ($PassThru) {
                    $result.Snapshot = $snapshot
                }
                
                return [PSCustomObject]$result
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment snapshot: $($_.Exception.Message)"
            throw
        }
    }
}

function Compress-SnapshotData {
    param(
        [hashtable]$Snapshot,
        [string]$CompressionLevel
    )
    
    # Simplified compression - in practice, you might use .NET compression classes
    Write-CustomLog -Level 'DEBUG' -Message "Applying $CompressionLevel compression to snapshot data"
    
    # For demonstration, we'll just mark that compression was applied
    $Snapshot.Metadata.Compressed = $true
    $Snapshot.Metadata.OriginalSize = $Snapshot.Metadata.Size
    
    return $Snapshot
}

function Get-DeploymentSnapshot {
    <#
    .SYNOPSIS
        Retrieves information about deployment snapshots.

    .DESCRIPTION
        Gets information about snapshots for a specific deployment or
        retrieves the content of a specific snapshot.

    .PARAMETER DeploymentId
        ID of the deployment to get snapshots for.

    .PARAMETER Name
        Name of a specific snapshot to retrieve.

    .PARAMETER IncludeContent
        Include the full snapshot content in the result.

    .PARAMETER ListOnly
        Only return snapshot metadata, not content.

    .EXAMPLE
        Get-DeploymentSnapshot -DeploymentId "abc123"

    .EXAMPLE
        Get-DeploymentSnapshot -DeploymentId "abc123" -Name "pre-update" -IncludeContent

    .OUTPUTS
        Snapshot information objects
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,
        
        [Parameter()]
        [string]$Name,
        
        [Parameter()]
        [switch]$IncludeContent,
        
        [Parameter()]
        [switch]$ListOnly
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Getting deployment snapshots for: $DeploymentId"
        
        $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
        $snapshotsDir = Join-Path $deploymentPath "snapshots"
        
        if (-not (Test-Path $snapshotsDir)) {
            Write-CustomLog -Level 'INFO' -Message "No snapshots directory found"
            return
        }
    }
    
    process {
        try {
            $snapshots = @()
            
            if ($Name) {
                # Get specific snapshot
                $snapshotPath = Join-Path $snapshotsDir "$Name.json"
                if (-not (Test-Path $snapshotPath)) {
                    throw "Snapshot '$Name' not found"
                }
                
                $snapshotFiles = @(Get-Item $snapshotPath)
            } else {
                # Get all snapshots
                $snapshotFiles = Get-ChildItem -Path $snapshotsDir -Filter "*.json" -File
            }
            
            foreach ($file in $snapshotFiles) {
                try {
                    if ($ListOnly) {
                        # Only return basic metadata
                        $snapshots += [PSCustomObject]@{
                            Name = $file.BaseName
                            Path = $file.FullName
                            Size = $file.Length
                            Created = $file.CreationTime
                            Modified = $file.LastWriteTime
                        }
                    } else {
                        # Load snapshot content
                        $snapshot = Get-Content $file.FullName | ConvertFrom-Json
                        
                        if (-not $IncludeContent) {
                            # Remove large content sections
                            $snapshot.PSObject.Properties.Remove('Configuration')
                            $snapshot.PSObject.Properties.Remove('State')
                            $snapshot.PSObject.Properties.Remove('Artifacts')
                        }
                        
                        $snapshots += $snapshot
                    }
                } catch {
                    Write-CustomLog -Level 'WARN' -Message "Failed to load snapshot $($file.Name): $_"
                }
            }
            
            # Sort by creation date (newest first)
            $snapshots = $snapshots | Sort-Object CreatedAt -Descending
            
            return $snapshots
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get deployment snapshots: $($_.Exception.Message)"
            throw
        }
    }
}

function Remove-DeploymentSnapshot {
    <#
    .SYNOPSIS
        Removes a deployment snapshot.

    .DESCRIPTION
        Deletes a specific deployment snapshot from storage.

    .PARAMETER DeploymentId
        ID of the deployment.

    .PARAMETER Name
        Name of the snapshot to remove.

    .PARAMETER Force
        Force removal without confirmation.

    .EXAMPLE
        Remove-DeploymentSnapshot -DeploymentId "abc123" -Name "old-snapshot"

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Removing deployment snapshot: $Name"
        
        $deploymentPath = Join-Path $env:PROJECT_ROOT "deployments" $DeploymentId
        $snapshotPath = Join-Path $deploymentPath "snapshots" "$Name.json"
        
        if (-not (Test-Path $snapshotPath)) {
            throw "Snapshot '$Name' not found"
        }
    }
    
    process {
        try {
            if ($Force -or $PSCmdlet.ShouldProcess($Name, "Remove deployment snapshot")) {
                Remove-Item -Path $snapshotPath -Force
                Write-CustomLog -Level 'SUCCESS' -Message "Snapshot '$Name' removed successfully"
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to remove deployment snapshot: $($_.Exception.Message)"
            throw
        }
    }
}

function Compare-DeploymentSnapshots {
    <#
    .SYNOPSIS
        Compares two deployment snapshots.

    .DESCRIPTION
        Compares the state and configuration between two snapshots to identify
        differences and changes.

    .PARAMETER DeploymentId
        ID of the deployment.

    .PARAMETER SourceSnapshot
        Name of the source snapshot.

    .PARAMETER TargetSnapshot
        Name of the target snapshot.

    .PARAMETER CompareConfiguration
        Include configuration comparison.

    .PARAMETER CompareState
        Include state comparison.

    .PARAMETER OutputFormat
        Format for comparison output (Object, Table, HTML).

    .EXAMPLE
        Compare-DeploymentSnapshots -DeploymentId "abc123" -SourceSnapshot "v1.0" -TargetSnapshot "v1.1"

    .OUTPUTS
        Snapshot comparison result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DeploymentId,
        
        [Parameter(Mandatory)]
        [string]$SourceSnapshot,
        
        [Parameter(Mandatory)]
        [string]$TargetSnapshot,
        
        [Parameter()]
        [switch]$CompareConfiguration = $true,
        
        [Parameter()]
        [switch]$CompareState = $true,
        
        [Parameter()]
        [ValidateSet('Object', 'Table', 'HTML')]
        [string]$OutputFormat = 'Object'
    )
    
    begin {
        Write-CustomLog -Level 'INFO' -Message "Comparing snapshots: $SourceSnapshot vs $TargetSnapshot"
    }
    
    process {
        try {
            # Load snapshots
            $source = Get-DeploymentSnapshot -DeploymentId $DeploymentId -Name $SourceSnapshot -IncludeContent
            $target = Get-DeploymentSnapshot -DeploymentId $DeploymentId -Name $TargetSnapshot -IncludeContent
            
            if (-not $source) {
                throw "Source snapshot '$SourceSnapshot' not found"
            }
            if (-not $target) {
                throw "Target snapshot '$TargetSnapshot' not found"
            }
            
            # Initialize comparison result
            $comparison = @{
                SourceSnapshot = $SourceSnapshot
                TargetSnapshot = $TargetSnapshot
                ComparisonTime = Get-Date
                HasDifferences = $false
                ConfigurationDifferences = @()
                StateDifferences = @()
                Summary = @{
                    ConfigurationChanges = 0
                    StateChanges = 0
                    TotalChanges = 0
                }
            }
            
            # Compare configurations
            if ($CompareConfiguration -and $source.Configuration -and $target.Configuration) {
                $configDiff = Compare-SnapshotConfigurations -Source $source.Configuration -Target $target.Configuration
                $comparison.ConfigurationDifferences = $configDiff
                $comparison.Summary.ConfigurationChanges = $configDiff.Count
                
                if ($configDiff.Count -gt 0) {
                    $comparison.HasDifferences = $true
                }
            }
            
            # Compare states
            if ($CompareState -and $source.State -and $target.State) {
                $stateDiff = Compare-SnapshotStates -Source $source.State -Target $target.State
                $comparison.StateDifferences = $stateDiff
                $comparison.Summary.StateChanges = $stateDiff.Count
                
                if ($stateDiff.Count -gt 0) {
                    $comparison.HasDifferences = $true
                }
            }
            
            $comparison.Summary.TotalChanges = $comparison.Summary.ConfigurationChanges + $comparison.Summary.StateChanges
            
            # Format output
            switch ($OutputFormat) {
                'Table' {
                    return Format-SnapshotComparisonTable -Comparison $comparison
                }
                'HTML' {
                    return Format-SnapshotComparisonHTML -Comparison $comparison
                }
                default {
                    return [PSCustomObject]$comparison
                }
            }
            
        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to compare snapshots: $($_.Exception.Message)"
            throw
        }
    }
}

function Compare-SnapshotConfigurations {
    param($Source, $Target)
    
    $differences = @()
    
    # Convert to JSON for comparison
    $sourceJson = $Source | ConvertTo-Json -Depth 10
    $targetJson = $Target | ConvertTo-Json -Depth 10
    
    if ($sourceJson -ne $targetJson) {
        $differences += @{
            Type = 'Configuration'
            Change = 'Modified'
            Description = 'Configuration has changed between snapshots'
        }
    }
    
    return $differences
}

function Compare-SnapshotStates {
    param($Source, $Target)
    
    $differences = @()
    
    # Compare infrastructure states
    if ($Source.Infrastructure -and $Target.Infrastructure) {
        $sourceInfra = $Source.Infrastructure
        $targetInfra = $Target.Infrastructure
        
        # Get all resource names
        $allResources = @()
        $allResources += $sourceInfra.PSObject.Properties.Name
        $allResources += $targetInfra.PSObject.Properties.Name
        $allResources = $allResources | Sort-Object | Get-Unique
        
        foreach ($resourceName in $allResources) {
            $sourceResource = $sourceInfra.$resourceName
            $targetResource = $targetInfra.$resourceName
            
            if ($sourceResource -and -not $targetResource) {
                $differences += @{
                    Type = 'Resource'
                    Change = 'Removed'
                    ResourceName = $resourceName
                    Description = "Resource '$resourceName' was removed"
                }
            } elseif (-not $sourceResource -and $targetResource) {
                $differences += @{
                    Type = 'Resource'
                    Change = 'Added'
                    ResourceName = $resourceName
                    Description = "Resource '$resourceName' was added"
                }
            } elseif ($sourceResource -and $targetResource) {
                $sourceJson = $sourceResource | ConvertTo-Json -Depth 5
                $targetJson = $targetResource | ConvertTo-Json -Depth 5
                
                if ($sourceJson -ne $targetJson) {
                    $differences += @{
                        Type = 'Resource'
                        Change = 'Modified'
                        ResourceName = $resourceName
                        Description = "Resource '$resourceName' was modified"
                    }
                }
            }
        }
    }
    
    return $differences
}

function Format-SnapshotComparisonTable {
    param($Comparison)
    
    $allDifferences = @()
    $allDifferences += $Comparison.ConfigurationDifferences
    $allDifferences += $Comparison.StateDifferences
    
    return $allDifferences | Format-Table -Property Type, Change, ResourceName, Description -AutoSize
}

function Format-SnapshotComparisonHTML {
    param($Comparison)
    
    # Generate HTML comparison report (simplified)
    return @"
<html>
<head><title>Snapshot Comparison</title></head>
<body>
<h1>Snapshot Comparison</h1>
<p>Source: $($Comparison.SourceSnapshot)</p>
<p>Target: $($Comparison.TargetSnapshot)</p>
<p>Total Changes: $($Comparison.Summary.TotalChanges)</p>
</body>
</html>
"@
}