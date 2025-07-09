function Set-RestAPIServerConfiguration {
    <#
    .SYNOPSIS
        Sets REST API server configuration
    
    .DESCRIPTION
        Updates the REST API server configuration with new settings
        and validates the configuration before applying
    
    .PARAMETER Configuration
        Hashtable containing configuration settings
    
    .EXAMPLE
        Set-RestAPIServerConfiguration -Configuration @{ Port = 8081; Protocol = 'HTTPS' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    try {
        Write-CustomLog -Message "Setting REST API server configuration..." -Level "INFO"
        
        # Validate configuration
        if ($Configuration.ContainsKey('Port') -and ($Configuration.Port -lt 1 -or $Configuration.Port -gt 65535)) {
            throw "Invalid port number: $($Configuration.Port)"
        }
        
        if ($Configuration.ContainsKey('Protocol') -and $Configuration.Protocol -notin @('HTTP', 'HTTPS')) {
            throw "Invalid protocol: $($Configuration.Protocol)"
        }
        
        # Apply configuration changes
        foreach ($key in $Configuration.Keys) {
            $script:APIConfiguration[$key] = $Configuration[$key]
            Write-CustomLog -Message "Updated configuration: $key = $($Configuration[$key])" -Level "DEBUG"
        }
        
        # Update management state if initialized
        if ($script:ManagementState) {
            $script:ManagementState.Configuration = $script:APIConfiguration.Clone()
            $script:ManagementState.LastConfigUpdate = Get-Date
        }
        
        Write-CustomLog -Message "REST API server configuration updated successfully" -Level "SUCCESS"
        return $script:APIConfiguration
        
    } catch {
        Write-CustomLog -Message "Failed to set REST API server configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}