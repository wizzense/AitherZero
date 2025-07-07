function Get-UtilityConfiguration {
    <#
    .SYNOPSIS
        Gets current utility service configuration
    
    .DESCRIPTION
        Retrieves the current configuration settings for all utility services
    
    .EXAMPLE
        Get-UtilityConfiguration
        
        Get the current configuration
    #>
    [CmdletBinding()]
    param()
    
    return $script:SharedConfiguration.Clone()
}