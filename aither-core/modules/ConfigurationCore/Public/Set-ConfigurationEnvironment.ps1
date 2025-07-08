function Set-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Set the active configuration environment
    .DESCRIPTION
        Changes the active configuration environment and optionally triggers module updates
    .PARAMETER Name
        Name of the environment to activate
    .PARAMETER Force
        Force environment switch even if validation fails
    .PARAMETER NotifyModules
        Notify modules about the environment change (triggers hot reload)
    .EXAMPLE
        Set-ConfigurationEnvironment -Name "production"
    .EXAMPLE
        Set-ConfigurationEnvironment -Name "staging" -NotifyModules
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$NotifyModules
    )

    try {
        # Validate environment exists
        if (-not $script:ConfigurationStore.Environments.ContainsKey($Name)) {
            throw "Environment '$Name' not found. Available environments: $($script:ConfigurationStore.Environments.Keys -join ', ')"
        }

        # Check if already current
        if ($script:ConfigurationStore.CurrentEnvironment -eq $Name) {
            Write-CustomLog -Level 'INFO' -Message "Environment '$Name' is already active"
            return $true
        }

        # Validate environment configuration if not forcing
        if (-not $Force) {
            $env = $script:ConfigurationStore.Environments[$Name]
            if (-not $env.Settings) {
                Write-CustomLog -Level 'WARN' -Message "Environment '$Name' has no settings configured"
            }
        }

        if ($PSCmdlet.ShouldProcess($Name, "Set active environment")) {
            $previousEnvironment = $script:ConfigurationStore.CurrentEnvironment
            $script:ConfigurationStore.CurrentEnvironment = $Name

            # Save updated configuration
            Save-ConfigurationStore

            Write-CustomLog -Level 'SUCCESS' -Message "Active environment changed from '$previousEnvironment' to '$Name'"

            # Notify modules if requested
            if ($NotifyModules) {
                Write-CustomLog -Level 'INFO' -Message "Notifying modules about environment change"

                # Get all modules that have configurations
                $moduleNames = @()
                foreach ($envName in $script:ConfigurationStore.Environments.Keys) {
                    $moduleNames += $script:ConfigurationStore.Environments[$envName].Settings.Keys
                }
                $moduleNames = $moduleNames | Select-Object -Unique

                # Trigger reload for each module
                foreach ($moduleName in $moduleNames) {
                    try {
                        Invoke-ConfigurationReload -ModuleName $moduleName -Environment $Name
                    } catch {
                        Write-CustomLog -Level 'WARN' -Message "Failed to notify module '$moduleName': $_"
                    }
                }

                # Publish environment change event
                if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
                    Publish-TestEvent -EventName 'EnvironmentChanged' -EventData @{
                        PreviousEnvironment = $previousEnvironment
                        NewEnvironment = $Name
                        Timestamp = Get-Date
                    }
                }
            }

            return $true
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to set configuration environment: $_"
        throw
    }
}
