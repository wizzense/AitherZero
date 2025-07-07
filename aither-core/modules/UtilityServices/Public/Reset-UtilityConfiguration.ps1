function Reset-UtilityConfiguration {
    <#
    .SYNOPSIS
        Resets utility service configuration to defaults
    
    .DESCRIPTION
        Resets all configuration settings to their default values
    
    .EXAMPLE
        Reset-UtilityConfiguration
        
        Reset configuration to defaults
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