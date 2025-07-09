function Set-UnifiedMaintenanceConfiguration {
    <#
    .SYNOPSIS
        Sets unified maintenance configuration
    
    .DESCRIPTION
        Updates the unified maintenance configuration with new settings
        and validates the configuration before applying
    
    .PARAMETER Configuration
        Hashtable containing configuration settings
    
    .EXAMPLE
        Set-UnifiedMaintenanceConfiguration -Configuration @{ MaintenanceMode = 'Full'; AutoFix = $true }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-MaintenanceLog "Setting unified maintenance configuration..." 'INFO'
        
        # Validate configuration
        if ($Configuration.ContainsKey('MaintenanceMode') -and 
            $Configuration.MaintenanceMode -notin @('Quick', 'Full', 'Test', 'TestOnly', 'Continuous', 'Track', 'Report', 'All')) {
            throw "Invalid maintenance mode: $($Configuration.MaintenanceMode)"
        }
        
        # Initialize management state if not exists
        if (-not $script:ManagementState) {
            $script:ManagementState = @{
                State = 'Configured'
                StartTime = Get-Date
                TestMode = $false
            }
        }
        
        # Apply configuration changes
        foreach ($key in $Configuration.Keys) {
            $script:ManagementState[$key] = $Configuration[$key]
            Write-MaintenanceLog "Updated configuration: $key = $($Configuration[$key])" 'INFO'
        }
        
        $script:ManagementState.LastConfigUpdate = Get-Date
        
        Write-MaintenanceLog "Unified maintenance configuration updated successfully" 'SUCCESS'
        return $script:ManagementState
        
    } catch {
        Write-MaintenanceLog "Failed to set unified maintenance configuration: $($_.Exception.Message)" 'ERROR'
        throw
    }
}