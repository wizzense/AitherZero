function Set-ModuleConfiguration {
    <#
    .SYNOPSIS
        Set configuration for a specific module
    .DESCRIPTION
        Updates the configuration for a module in the specified environment
    .PARAMETER ModuleName
        Name of the module to configure
    .PARAMETER Configuration
        Configuration settings to apply
    .PARAMETER Environment
        Environment to update (default: current environment)
    .PARAMETER Merge
        Merge with existing configuration instead of replacing
    .EXAMPLE
        Set-ModuleConfiguration -ModuleName "LabRunner" -Configuration @{
            MaxConcurrentJobs = 10
            LogLevel = "DEBUG"
        }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [hashtable]$Configuration,

        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [switch]$Merge
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

        # Validate configuration against schema if available
        if ($script:ConfigurationStore.Schemas.ContainsKey($ModuleName)) {
            $validationResult = Validate-Configuration -ModuleName $ModuleName -Configuration $Configuration
            if (-not $validationResult.IsValid) {
                throw "Configuration validation failed: $($validationResult.Errors -join ', ')"
            }
        }

        if ($PSCmdlet.ShouldProcess("$ModuleName in $Environment", "Update configuration")) {
            # Initialize module settings if not exists
            if (-not $script:ConfigurationStore.Environments[$Environment].Settings.ContainsKey($ModuleName)) {
                $script:ConfigurationStore.Environments[$Environment].Settings[$ModuleName] = @{}
            }

            if ($Merge) {
                # Merge with existing configuration
                $currentConfig = $script:ConfigurationStore.Environments[$Environment].Settings[$ModuleName]
                $mergedConfig = Merge-Configuration -Base $currentConfig -Override $Configuration
                $script:ConfigurationStore.Environments[$Environment].Settings[$ModuleName] = $mergedConfig
            } else {
                # Replace configuration
                $script:ConfigurationStore.Environments[$Environment].Settings[$ModuleName] = $Configuration
            }

            # Trigger hot reload if enabled
            if ($script:ConfigurationStore.HotReload.Enabled) {
                Invoke-ConfigurationReload -ModuleName $ModuleName -Environment $Environment
            }

            # Save updated configuration
            Save-ConfigurationStore

            # Publish configuration change event
            $eventData = @{
                ModuleName = $ModuleName
                Environment = $Environment
                ConfigurationChanged = $true
                ChangeType = if ($Merge) { "Merged" } else { "Replaced" }
                Timestamp = Get-Date
            }

            Publish-ConfigurationEvent -EventName "ModuleConfigurationChanged" -EventData $eventData -SourceModule "ConfigurationCore"

            Write-CustomLog -Level 'SUCCESS' -Message "Configuration updated for $ModuleName in $Environment"
            return $true
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set module configuration: $_"
        throw
    }
}
