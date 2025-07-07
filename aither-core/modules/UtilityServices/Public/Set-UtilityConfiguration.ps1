function Set-UtilityConfiguration {
    <#
    .SYNOPSIS
        Sets utility service configuration
    
    .DESCRIPTION
        Updates configuration settings for utility services
    
    .PARAMETER Configuration
        Hashtable of configuration settings to update
    
    .EXAMPLE
        Set-UtilityConfiguration -Configuration @{LogLevel = 'DEBUG'; MaxConcurrency = 8}
        
        Update specific configuration settings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )
    
    foreach ($key in $Configuration.Keys) {
        $script:SharedConfiguration[$key] = $Configuration[$key]
        Write-UtilityLog "Configuration updated: $key = $($Configuration[$key])" -Level "DEBUG"
    }
}