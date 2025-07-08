function Get-ConfigurationEnvironment {
    <#
    .SYNOPSIS
        Get information about configuration environments
    .DESCRIPTION
        Returns information about the current environment or all environments
    .PARAMETER Name
        Specific environment name to get (default: current environment)
    .PARAMETER All
        Return all environments
    .PARAMETER IncludeSettings
        Include environment-specific settings in the output
    .EXAMPLE
        $currentEnv = Get-ConfigurationEnvironment
    .EXAMPLE
        $allEnvs = Get-ConfigurationEnvironment -All
    .EXAMPLE
        $prodEnv = Get-ConfigurationEnvironment -Name "production" -IncludeSettings
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$All,

        [Parameter()]
        [switch]$IncludeSettings
    )

    try {
        if ($All) {
            $environments = @{}
            foreach ($envName in $script:ConfigurationStore.Environments.Keys) {
                $env = $script:ConfigurationStore.Environments[$envName].Clone()
                if (-not $IncludeSettings) {
                    $env.Remove('Settings')
                }
                $environments[$envName] = $env
            }
            return $environments
        }

        # Get specific environment or current
        if (-not $Name) {
            $Name = $script:ConfigurationStore.CurrentEnvironment
        }

        if (-not $script:ConfigurationStore.Environments.ContainsKey($Name)) {
            throw "Environment '$Name' not found"
        }

        $environment = $script:ConfigurationStore.Environments[$Name].Clone()

        # Add current environment indicator
        $environment.IsCurrent = ($Name -eq $script:ConfigurationStore.CurrentEnvironment)

        if (-not $IncludeSettings) {
            $environment.Remove('Settings')
        }

        return $environment

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration environment: $_"
        throw
    }
}
