function Export-RestAPIServerState {
    <#
    .SYNOPSIS
        Exports REST API server state to file
    
    .DESCRIPTION
        Exports the current state of the REST API server to a file
        for backup or persistence purposes
    
    .PARAMETER Path
        Path where to export the state file
    
    .EXAMPLE
        Export-RestAPIServerState -Path "C:\temp\api-state.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        Write-CustomLog -Message "Exporting REST API server state to: $Path" -Level "INFO"
        
        # Collect state information
        $stateData = @{
            ManagementState = $script:ManagementState
            Configuration = $script:APIConfiguration
            Metrics = $script:APIMetrics
            RegisteredEndpoints = $script:RegisteredEndpoints
            WebhookSubscriptions = $script:WebhookSubscriptions
            ExportedAt = Get-Date
            Version = "1.0.0"
        }
        
        # Convert to JSON and save
        $stateJson = $stateData | ConvertTo-Json -Depth 10
        $stateJson | Out-File -FilePath $Path -Encoding UTF8
        
        Write-CustomLog -Message "REST API server state exported successfully to: $Path" -Level "SUCCESS"
        return @{
            Path = $Path
            Size = (Get-Item $Path).Length
            ExportedAt = Get-Date
        }
        
    } catch {
        Write-CustomLog -Message "Failed to export REST API server state: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}