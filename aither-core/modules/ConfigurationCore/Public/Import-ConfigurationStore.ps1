function Import-ConfigurationStore {
    <#
    .SYNOPSIS
        Import a configuration store from a file
    .DESCRIPTION
        Imports a configuration store from a JSON file, replacing or merging with current store
    .PARAMETER Path
        Path to the configuration file to import
    .PARAMETER Merge
        Merge with existing configuration instead of replacing
    .PARAMETER Backup
        Create a backup before importing
    .PARAMETER Validate
        Validate the imported configuration
    .EXAMPLE
        Import-ConfigurationStore -Path "C:\backup\config.json" -Backup
    .EXAMPLE
        Import-ConfigurationStore -Path "config.json" -Merge
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter()]
        [switch]$Merge,
        
        [Parameter()]
        [switch]$Backup,
        
        [Parameter()]
        [switch]$Validate
    )
    
    try {
        if (-not (Test-Path $Path)) {
            throw "Configuration file not found: $Path"
        }
        
        # Read and parse configuration file
        $content = Get-Content $Path -Raw -Encoding UTF8
        $importedStore = $content | ConvertFrom-Json -AsHashtable
        
        if (-not $importedStore) {
            throw "Failed to parse configuration file or file is empty"
        }
        
        # Validate structure if requested
        if ($Validate) {
            $requiredKeys = @('Modules', 'Environments', 'CurrentEnvironment')
            foreach ($key in $requiredKeys) {
                if (-not $importedStore.ContainsKey($key)) {
                    throw "Invalid configuration structure: missing required key '$key'"
                }
            }
        }
        
        if ($PSCmdlet.ShouldProcess($Path, "Import configuration store")) {
            # Create backup if requested
            if ($Backup) {
                Backup-Configuration -Reason "Before import from $Path"
            }
            
            if ($Merge) {
                # Merge imported configuration with existing
                Write-CustomLog -Level 'INFO' -Message "Merging imported configuration with existing store"
                
                # Merge modules
                if ($importedStore.Modules) {
                    foreach ($moduleName in $importedStore.Modules.Keys) {
                        $script:ConfigurationStore.Modules[$moduleName] = $importedStore.Modules[$moduleName]
                    }
                }
                
                # Merge environments
                if ($importedStore.Environments) {
                    foreach ($envName in $importedStore.Environments.Keys) {
                        if ($script:ConfigurationStore.Environments.ContainsKey($envName)) {
                            # Merge environment settings
                            $currentEnv = $script:ConfigurationStore.Environments[$envName]
                            $importedEnv = $importedStore.Environments[$envName]
                            
                            foreach ($key in $importedEnv.Keys) {
                                $currentEnv[$key] = $importedEnv[$key]
                            }
                        } else {
                            $script:ConfigurationStore.Environments[$envName] = $importedStore.Environments[$envName]
                        }
                    }
                }
                
                # Merge schemas
                if ($importedStore.Schemas) {
                    foreach ($schemaName in $importedStore.Schemas.Keys) {
                        $script:ConfigurationStore.Schemas[$schemaName] = $importedStore.Schemas[$schemaName]
                    }
                }
                
                # Update current environment if specified
                if ($importedStore.CurrentEnvironment -and 
                    $script:ConfigurationStore.Environments.ContainsKey($importedStore.CurrentEnvironment)) {
                    $script:ConfigurationStore.CurrentEnvironment = $importedStore.CurrentEnvironment
                }
                
            } else {
                # Replace entire store
                Write-CustomLog -Level 'INFO' -Message "Replacing configuration store with imported data"
                
                # Preserve StorePath
                $currentStorePath = $script:ConfigurationStore.StorePath
                $script:ConfigurationStore = $importedStore
                $script:ConfigurationStore.StorePath = $currentStorePath
                
                # Ensure required keys exist
                if (-not $script:ConfigurationStore.HotReload) {
                    $script:ConfigurationStore.HotReload = @{
                        Enabled = $false
                        Watchers = @{}
                    }
                }
            }
            
            # Save updated configuration
            Save-ConfigurationStore
            
            Write-CustomLog -Level 'SUCCESS' -Message "Configuration store imported successfully from: $Path"
            return $true
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to import configuration store: $_"
        throw
    }
}