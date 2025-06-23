#Requires -Version 7.0
<#
.SYNOPSIS
    Updates PROJECT-MANIFEST.json with the latest module information
    
.DESCRIPTION
    This function automatically updates the project manifest file with the latest
    version information, modified dates, and module details. It ensures that the
    manifest stays in sync with actual code changes.
    
.PARAMETER ModuleName
    Name of the module being updated
    
.PARAMETER PatchDescription
    Description of the changes being made
    
.PARAMETER VersionBump
    Type of version bump to apply: None, Patch, Minor, Major
    
.PARAMETER AffectedFiles
    List of files affected by the changes
    
.EXAMPLE
    Update-ProjectManifest -ModuleName "PatchManager" -PatchDescription "fix: Corrected path handling" -VersionBump "Patch"
    
.NOTES
    - Should be called as part of GitControlledPatch workflow
    - Automatically detects the module version from module manifest
    - Creates backup of manifest before modifications
    - Updates project's last updated timestamp
#>

function Update-ProjectManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ModuleName = "",
        
        [Parameter(Mandatory = $false)]
        [string]$PatchDescription = "",
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("None", "Patch", "Minor", "Major")]
        [string]$VersionBump = "None",
        
        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @()
    )
      begin {
        Write-Verbose "Starting PROJECT-MANIFEST.json update process..."
        
        # Set paths
        $manifestPath = Join-Path $env:PROJECT_ROOT "PROJECT-MANIFEST.json"
        
        if (-not (Test-Path $manifestPath)) {
            Write-Error "PROJECT-MANIFEST.json not found at $manifestPath"
            return $false
        }
        
        # Create backup
        $backupDir = Join-Path $env:PROJECT_ROOT "backups/manifest"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        
        $backupPath = Join-Path $backupDir "PROJECT-MANIFEST-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        Copy-Item -Path $manifestPath -Destination $backupPath -Force
        Write-Verbose "Created manifest backup at $backupPath"
    }
    
    process {
        try {
            # Read current manifest
            $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json-Depth 20
            
            # Always update the last updated timestamp
            $manifest.project.lastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # If a specific module is being updated
            if (-not [string]::IsNullOrEmpty($ModuleName)) {
                # Check if module exists in manifest
                if ($manifest.core.modules.PSObject.Properties.Name -contains $ModuleName) {
                    # Update module's last updated date
                    $manifest.core.modules.$ModuleName.lastUpdated = Get-Date -Format "yyyy-MM-dd"
                      # Get current module version from manifest (for reference)
                    $moduleVersion = $manifest.core.modules.$ModuleName.version
                    Write-Verbose "Current module version: $moduleVersion"
                    
                    # Try to get module version from module manifest
                    $modulePath = Join-Path $env:PROJECT_ROOT "pwsh/modules/$ModuleName"
                    $moduleManifestPath = Join-Path $modulePath "$ModuleName.psd1"
                    
                    if (Test-Path $moduleManifestPath) {
                        try {
                            $moduleInfo = Import-PowerShellDataFile -Path $moduleManifestPath
                            if ($moduleInfo.ModuleVersion) {
                                $manifest.core.modules.$ModuleName.version = $moduleInfo.ModuleVersion
                                Write-Verbose "Updated $ModuleName version to $($moduleInfo.ModuleVersion) from module manifest"
                            }
                        }
                        catch {
                            Write-Warning "Could not read module manifest for $ModuleName`: $($_.Exception.Message)"
                        }
                    }
                    
                    # Process version bump if requested
                    if ($VersionBump -ne "None") {
                        $versionParts = $manifest.core.modules.$ModuleName.version -split '\.'
                        $major = [int]$versionParts[0]
                        $minor = [int]$versionParts[1]
                        $patch = [int]$versionParts[2]
                        
                        switch ($VersionBump) {
                            "Major" {
                                $major++
                                $minor = 0
                                $patch = 0
                            }
                            "Minor" {
                                $minor++
                                $patch = 0
                            }
                            "Patch" {
                                $patch++
                            }
                        }
                        
                        $newVersion = "$major.$minor.$patch"
                        $manifest.core.modules.$ModuleName.version = $newVersion
                        Write-Verbose "Bumped $ModuleName version to $newVersion ($VersionBump)"
                    }
                    
                    # Add to history if not already tracking
                    if (-not $manifest.core.modules.$ModuleName.PSObject.Properties.Name -contains "changeHistory") {
                        $manifest.core.modules.$ModuleName | Add-Member -NotePropertyName "changeHistory" -NotePropertyValue @()
                    }
                    
                    # Add change to history
                    if (-not [string]::IsNullOrEmpty($PatchDescription)) {
                        $change = @{
                            date = Get-Date -Format "yyyy-MM-dd"
                            description = $PatchDescription
                            version = $manifest.core.modules.$ModuleName.version
                            files = $AffectedFiles
                        }
                        
                        # Convert to PSObject for proper serialization
                        $changeObj = [PSCustomObject]$change
                        
                        # Add to history
                        $currentHistory = $manifest.core.modules.$ModuleName.changeHistory
                        if ($null -eq $currentHistory) {
                            $manifest.core.modules.$ModuleName.changeHistory = @($changeObj)
                        }
                        else {
                            $currentHistory += $changeObj
                            $manifest.core.modules.$ModuleName.changeHistory = $currentHistory
                        }
                        
                        Write-Verbose "Added change to history: $PatchDescription"
                    }
                }
                else {
                    Write-Warning "Module $ModuleName not found in PROJECT-MANIFEST.json"
                }
            }
            
            # Update project metrics
            if ($manifest.metrics) {
                $manifest.metrics.lastCalculated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                
                # Count active modules
                $activeModules = ($manifest.core.modules | Get-Member -MemberType NoteProperty).Name
                $manifest.metrics.codebase.activeModules = $activeModules.Count
            }
              # Write updated manifest
            $manifest | ConvertTo-Json-Depth 20 | Set-Content -Path $manifestPath
            Write-Verbose "Successfully updated PROJECT-MANIFEST.json"
            
            return $true
        }
        catch {
            Write-Error "Failed to update PROJECT-MANIFEST.json: $($_.Exception.Message)"
            # Restore from backup if update fails
            Copy-Item -Path $backupPath -Destination $manifestPath -Force
            Write-Warning "Restored PROJECT-MANIFEST.json from backup"
            return $false
        }
    }
}