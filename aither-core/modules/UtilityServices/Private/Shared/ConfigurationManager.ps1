function Set-UtilityConfiguration {
    <#
    .SYNOPSIS
        Sets utility service configuration
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Configuration
    )
    
    foreach ($key in $Configuration.Keys) {
        $script:SharedConfiguration[$key] = $Configuration[$key]
        Write-UtilityLog "Configuration updated: $key = $($Configuration[$key])" -Level "DEBUG"
    }
}

function Get-UtilityConfiguration {
    <#
    .SYNOPSIS
        Gets current utility service configuration
    #>
    [CmdletBinding()]
    param()
    
    return $script:SharedConfiguration.Clone()
}

function Reset-UtilityConfiguration {
    <#
    .SYNOPSIS
        Resets utility service configuration to defaults
    #>
    [CmdletBinding()]
    param()
    
    $script:SharedConfiguration = @{
        LogLevel = 'INFO'
        EnableProgressTracking = $true
        EnableVersioning = $true
        EnableMetrics = $true
        DefaultTimeout = 300
        MaxConcurrency = 4
    }
    
    Write-UtilityLog "Configuration reset to defaults" -Level "INFO"
}