function Set-StartupExperienceConfiguration {
    <#
    .SYNOPSIS
        Sets configuration for the StartupExperience management system
    .DESCRIPTION
        Updates the configuration settings for the StartupExperience
        management system with validation and error handling
    .PARAMETER Configuration
        Hashtable containing configuration settings
    .EXAMPLE
        Set-StartupExperienceConfiguration -Configuration @{Setting1 = 'Value1'}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    try {
        # Initialize management state if not already done
        if (-not $script:ManagementState) {
            Start-StartupExperienceManagement
        }

        # Validate configuration
        if ($null -eq $Configuration -or $Configuration.Count -eq 0) {
            throw "Configuration cannot be null or empty"
        }

        # Update configuration
        foreach ($key in $Configuration.Keys) {
            $script:ManagementState.Configuration[$key] = $Configuration[$key]
        }

        $script:ManagementState.LastOperation = "SetConfiguration"
        $script:ManagementState.Operations += @{
            Operation = "SetConfiguration"
            Timestamp = Get-Date
            Parameters = $Configuration
        }

        Write-Verbose "Configuration updated with $($Configuration.Count) settings"
        
        return $true
    } catch {
        Write-Error "Failed to set StartupExperience configuration: $($_.Exception.Message)"
        throw
    }
}