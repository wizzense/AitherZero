function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Get configuration for a specific module
    .DESCRIPTION
        Retrieves the configuration for a module in the current environment with all overlays applied
    .PARAMETER ModuleName
        Name of the module to get configuration for
    .PARAMETER Environment
        Specific environment to get configuration from (default: current environment)
    .PARAMETER Raw
        Return raw configuration without environment overlays
    .EXAMPLE
        $config = Get-ModuleConfiguration -ModuleName "LabRunner"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [switch]$Raw
    )

    try {
        # Use current environment if not specified
        if (-not $Environment) {
            $Environment = $script:ConfigurationStore.CurrentEnvironment
        }

        # Validate environment exists
        if (-not $script:ConfigurationStore.Environments.ContainsKey($Environment)) {
            throw "Environment '$Environment' not found"
        }

        # Get base configuration
        $baseConfig = @{}
        if ($script:ConfigurationStore.Modules.ContainsKey($ModuleName)) {
            $baseConfig = $script:ConfigurationStore.Modules[$ModuleName].Clone()
        }

        if ($Raw) {
            return $baseConfig
        }

        # Apply environment overlay
        $envSettings = @{}
        if ($script:ConfigurationStore.Environments[$Environment].Settings.ContainsKey($ModuleName)) {
            $envSettings = $script:ConfigurationStore.Environments[$Environment].Settings[$ModuleName]
        }

        # Merge configurations (environment overrides base)
        $finalConfig = Merge-Configuration -Base $baseConfig -Override $envSettings

        # Apply variable substitution
        $finalConfig = Expand-ConfigurationVariables -Configuration $finalConfig -Environment $Environment

        return $finalConfig

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get module configuration: $_"
        throw
    }
}
