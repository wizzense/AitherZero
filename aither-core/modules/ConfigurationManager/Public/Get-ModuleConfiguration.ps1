function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Gets configuration for a specific module (Legacy Compatibility Function)
    .DESCRIPTION
        Retrieves configuration data for a specified module from the unified configuration store.
        This function maintains compatibility with the original ConfigurationCore module.
    .PARAMETER ModuleName
        Name of the module to get configuration for
    .PARAMETER Environment
        Environment-specific configuration to retrieve
    .PARAMETER IncludeDefaults
        Include default values from the module schema
    .EXAMPLE
        Get-ModuleConfiguration -ModuleName "LabRunner"
        
        Gets LabRunner module configuration
    .EXAMPLE
        Get-ModuleConfiguration -ModuleName "PatchManager" -Environment "prod" -IncludeDefaults
        
        Gets PatchManager configuration for production with defaults
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        
        [Parameter()]
        [string]$Environment,
        
        [Parameter()]
        [switch]$IncludeDefaults
    )
    
    try {
        Write-ConfigurationLog -Level 'DEBUG' -Message "Getting configuration for module: $ModuleName"
        
        if (-not $script:ModuleInitialized) {
            throw "Configuration Manager not initialized. Run Initialize-ConfigurationManager first."
        }
        
        $result = @{
            ModuleName = $ModuleName
            Environment = $Environment ?? $script:UnifiedConfigurationStore.CurrentEnvironment
            Configuration = @{}
            HasConfiguration = $false
            Source = 'ConfigurationManager'
            Timestamp = Get-Date
        }
        
        # Get base module configuration
        if ($script:UnifiedConfigurationStore.Modules.ContainsKey($ModuleName)) {
            $result.Configuration = $script:UnifiedConfigurationStore.Modules[$ModuleName].Clone()
            $result.HasConfiguration = $true
            $result.Source = 'ModuleStore'
        } else {
            Write-ConfigurationLog -Level 'WARNING' -Message "Module '$ModuleName' not found in configuration store"
        }
        
        # Apply environment-specific overrides
        $envName = $Environment ?? $script:UnifiedConfigurationStore.CurrentEnvironment
        if ($script:UnifiedConfigurationStore.Environments.ContainsKey($envName)) {
            $envConfig = $script:UnifiedConfigurationStore.Environments[$envName]
            if ($envConfig.Settings -and $envConfig.Settings.ContainsKey($ModuleName)) {
                $envOverrides = $envConfig.Settings[$ModuleName]
                
                # Merge environment overrides
                $mergeResult = Merge-ConfigurationData -SourceConfiguration $envOverrides -TargetConfiguration $result.Configuration -ConflictStrategy 'Overwrite' -SourceName "Environment-$envName"
                
                if ($mergeResult.Success) {
                    $result.Configuration = $result.Configuration
                    $result.EnvironmentOverrides = $envOverrides
                    $result.HasConfiguration = $true
                    $result.Source = 'ModuleStore+Environment'
                    Write-ConfigurationLog -Level 'DEBUG' -Message "Applied environment overrides for $ModuleName from $envName"
                }
            }
        }
        
        # Include defaults from schema if requested
        if ($IncludeDefaults -and $script:UnifiedConfigurationStore.Schemas.ContainsKey($ModuleName)) {
            $schema = $script:UnifiedConfigurationStore.Schemas[$ModuleName]
            
            if ($schema.properties) {
                foreach ($propertyName in $schema.properties.Keys) {
                    $propertySchema = $schema.properties[$propertyName]
                    
                    # Add default value if not already set
                    if (-not $result.Configuration.ContainsKey($propertyName) -and $propertySchema.ContainsKey('default')) {
                        $result.Configuration[$propertyName] = $propertySchema.default
                        if (-not $result.DefaultsApplied) {
                            $result.DefaultsApplied = @()
                        }
                        $result.DefaultsApplied += $propertyName
                    }
                }
                
                if ($result.DefaultsApplied) {
                    Write-ConfigurationLog -Level 'DEBUG' -Message "Applied defaults for $ModuleName`: $($result.DefaultsApplied -join ', ')"
                    $result.Source += '+Defaults'
                }
            }
        }
        
        # Add metadata
        $result.Schema = if ($script:UnifiedConfigurationStore.Schemas.ContainsKey($ModuleName)) { 
            $script:UnifiedConfigurationStore.Schemas[$ModuleName] 
        } else { 
            $null 
        }
        
        Write-ConfigurationLog -Level 'SUCCESS' -Message "Retrieved configuration for module '$ModuleName' from $($result.Source)"
        
        return $result
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to get module configuration for '$ModuleName': $_"
        
        return @{
            ModuleName = $ModuleName
            Environment = $Environment
            Configuration = @{}
            HasConfiguration = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}