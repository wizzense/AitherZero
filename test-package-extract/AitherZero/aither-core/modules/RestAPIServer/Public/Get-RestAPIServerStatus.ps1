function Get-RestAPIServerStatus {
    <#
    .SYNOPSIS
        Gets the current status of the REST API server
    
    .DESCRIPTION
        Retrieves comprehensive status information about the REST API server
        including state, configuration, and metrics
    
    .EXAMPLE
        Get-RestAPIServerStatus
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-CustomLog -Message "Retrieving REST API server status..." -Level "DEBUG"
        
        # Get current state
        $status = @{
            State = if ($script:ManagementState) { $script:ManagementState.State } else { 'Uninitialized' }
            ServerRunning = $script:APIServer -ne $null
            Configuration = $script:APIConfiguration
            Metrics = $script:APIMetrics
            Endpoints = $script:RegisteredEndpoints.Count
            WebhookSubscriptions = $script:WebhookSubscriptions.Count
            LastUpdated = Get-Date
        }
        
        # Add uptime calculation if server is running
        if ($script:ManagementState -and $script:ManagementState.StartTime) {
            $status.UpTime = (Get-Date) - $script:ManagementState.StartTime
        }
        
        Write-CustomLog -Message "REST API server status retrieved successfully" -Level "DEBUG"
        return $status
        
    } catch {
        Write-CustomLog -Message "Failed to get REST API server status: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}