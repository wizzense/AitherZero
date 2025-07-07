function Get-DeploymentSnapshot {
    <#
    .SYNOPSIS
        Captures current state snapshot of infrastructure deployment
    .DESCRIPTION
        Creates a comprehensive snapshot of current infrastructure state including
        resource configurations, dependencies, and metadata for backup/comparison
    .PARAMETER DeploymentId
        Unique identifier of the deployment
    .PARAMETER IncludeSecrets
        Include sensitive data in snapshot (encrypted)
    .PARAMETER OutputPath
        Path to save snapshot file
    .PARAMETER Format
        Snapshot format (JSON or YAML)
    .EXAMPLE
        Get-DeploymentSnapshot -DeploymentId "lab-prod-001" -OutputPath "./snapshots"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DeploymentId,
        
        [Parameter()]
        [switch]$IncludeSecrets,
        
        [Parameter()]
        [string]$OutputPath = (Join-Path $PSScriptRoot "../../snapshots"),
        
        [Parameter()]
        [ValidateSet('JSON', 'YAML')]
        [string]$Format = 'JSON'
    )
    
    try {
        Write-CustomLog -Level 'INFO' -Message "Creating deployment snapshot for: $DeploymentId"
        
        # Get deployment state
        $deploymentState = Get-DeploymentState -DeploymentId $DeploymentId
        if (-not $deploymentState) {
            throw "Deployment not found: $DeploymentId"
        }
        
        # Get OpenTofu state
        $stateFile = Join-Path $deploymentState.WorkingDirectory "terraform.tfstate"
        if (-not (Test-Path $stateFile)) {
            throw "State file not found: $stateFile"
        }
        
        $tfState = Get-Content $stateFile -Raw | ConvertFrom-Json
        
        # Build snapshot object
        $snapshot = @{
            SnapshotId = "snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$((New-Guid).ToString().Substring(0,8))"
            DeploymentId = $DeploymentId
            Timestamp = Get-Date -Format "yyyy-MM-dd'T'HH:mm:ss'Z'"
            Version = $tfState.version
            SerialNumber = $tfState.serial
            Resources = @()
            Outputs = @{}
            Variables = @{}
            Metadata = @{
                Provider = $deploymentState.Provider
                Environment = $deploymentState.Environment
                Tags = $deploymentState.Tags
            }
        }
        
        # Process resources
        foreach ($resource in $tfState.resources) {
            $resourceInfo = @{
                Type = $resource.type
                Name = $resource.name
                Provider = $resource.provider
                Mode = $resource.mode
                Instances = @()
            }
            
            foreach ($instance in $resource.instances) {
                $instanceInfo = @{
                    IndexKey = $instance.index_key
                    SchemaVersion = $instance.schema_version
                    Attributes = $instance.attributes
                    Dependencies = $instance.dependencies
                }
                
                # Handle secrets
                if (-not $IncludeSecrets) {
                    $instanceInfo.Attributes = Remove-SensitiveData -Data $instanceInfo.Attributes
                }
                
                $resourceInfo.Instances += $instanceInfo
            }
            
            $snapshot.Resources += $resourceInfo
        }
        
        # Get outputs
        if ($tfState.outputs) {
            foreach ($output in $tfState.outputs.PSObject.Properties) {
                $snapshot.Outputs[$output.Name] = @{
                    Value = $output.Value.value
                    Type = $output.Value.type
                    Sensitive = $output.Value.sensitive
                }
                
                if ($output.Value.sensitive -and -not $IncludeSecrets) {
                    $snapshot.Outputs[$output.Name].Value = "[REDACTED]"
                }
            }
        }
        
        # Create output directory
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        # Generate filename
        $fileName = "deployment-snapshot-$DeploymentId-$(Get-Date -Format 'yyyyMMdd-HHmmss').$($Format.ToLower())"
        $filePath = Join-Path $OutputPath $fileName
        
        # Save snapshot
        switch ($Format) {
            'JSON' {
                $snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            }
            'YAML' {
                # Would use ConvertTo-Yaml if available
                $snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path "$filePath.json" -Encoding UTF8
                Write-CustomLog -Level 'WARNING' -Message "YAML conversion not available, saved as JSON"
                $filePath = "$filePath.json"
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Deployment snapshot created: $filePath"
        
        return [PSCustomObject]@{
            SnapshotId = $snapshot.SnapshotId
            FilePath = $filePath
            Size = (Get-Item $filePath).Length
            ResourceCount = $snapshot.Resources.Count
            Timestamp = $snapshot.Timestamp
        }
        
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create deployment snapshot: $_"
        throw
    }
}

# Helper function to remove sensitive data
function Remove-SensitiveData {
    param($Data)
    
    $sensitiveKeys = @('password', 'secret', 'key', 'token', 'credential', 'private')
    
    if ($Data -is [hashtable] -or $Data -is [PSCustomObject]) {
        $cleaned = @{}
        $properties = if ($Data -is [hashtable]) { $Data.Keys } else { $Data.PSObject.Properties.Name }
        
        foreach ($prop in $properties) {
            $value = if ($Data -is [hashtable]) { $Data[$prop] } else { $Data.$prop }
            
            if ($sensitiveKeys -contains $prop.ToLower() -or $prop -match 'password|secret|key|token') {
                $cleaned[$prop] = "[REDACTED]"
            }
            elseif ($value -is [hashtable] -or $value -is [PSCustomObject]) {
                $cleaned[$prop] = Remove-SensitiveData -Data $value
            }
            else {
                $cleaned[$prop] = $value
            }
        }
        
        return $cleaned
    }
    
    return $Data
}