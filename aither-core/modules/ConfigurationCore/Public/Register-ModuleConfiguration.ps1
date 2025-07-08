function Register-ModuleConfiguration {
    <#
    .SYNOPSIS
        Register a module's configuration schema
    .DESCRIPTION
        Allows modules to register their configuration schema for validation and management
    .PARAMETER ModuleName
        Name of the module registering configuration
    .PARAMETER Schema
        Configuration schema definition (hashtable or JSON schema)
    .PARAMETER DefaultConfiguration
        Default configuration values for the module
    .EXAMPLE
        Register-ModuleConfiguration -ModuleName "LabRunner" -Schema @{
            Properties = @{
                MaxConcurrentJobs = @{ Type = "int"; Default = 5; Min = 1; Max = 20 }
                LogLevel = @{ Type = "string"; Default = "INFO"; ValidValues = @("DEBUG", "INFO", "WARN", "ERROR") }
            }
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [hashtable]$Schema,

        [Parameter()]
        [hashtable]$DefaultConfiguration = @{}
    )

    try {
        Write-CustomLog -Level 'INFO' -Message "Registering configuration for module: $ModuleName"

        # Store schema
        $script:ConfigurationStore.Schemas[$ModuleName] = $Schema

        # Initialize module configuration if not exists
        if (-not $script:ConfigurationStore.Modules.ContainsKey($ModuleName)) {
            $script:ConfigurationStore.Modules[$ModuleName] = @{}
        }

        # Extract default values from schema if no explicit defaults provided
        $effectiveDefaults = $DefaultConfiguration.Clone()
        if ($Schema.Properties) {
            foreach ($propName in $Schema.Properties.Keys) {
                $propSchema = $Schema.Properties[$propName]
                if ($propSchema.ContainsKey('Default') -and -not $effectiveDefaults.ContainsKey($propName)) {
                    $effectiveDefaults[$propName] = $propSchema.Default
                }
            }
        }

        # Apply defaults to all environments
        foreach ($env in $script:ConfigurationStore.Environments.Keys) {
            if (-not $script:ConfigurationStore.Environments[$env].Settings.ContainsKey($ModuleName)) {
                $script:ConfigurationStore.Environments[$env].Settings[$ModuleName] = @{}
            }

            # Merge defaults with existing settings
            $currentSettings = $script:ConfigurationStore.Environments[$env].Settings[$ModuleName]
            $mergedSettings = Merge-Configuration -Base $effectiveDefaults -Override $currentSettings
            $script:ConfigurationStore.Environments[$env].Settings[$ModuleName] = $mergedSettings
        }

        # Validate the effective default configuration
        $validationResult = Validate-Configuration -ModuleName $ModuleName -Configuration $effectiveDefaults
        if (-not $validationResult.IsValid) {
            Write-CustomLog -Level 'WARNING' -Message "Default configuration has validation warnings: $($validationResult.Errors -join ', ')"
        }

        # Save updated store
        Save-ConfigurationStore

        Write-CustomLog -Level 'SUCCESS' -Message "Module configuration registered: $ModuleName"
        return $true

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to register module configuration: $_"
        throw
    }
}
