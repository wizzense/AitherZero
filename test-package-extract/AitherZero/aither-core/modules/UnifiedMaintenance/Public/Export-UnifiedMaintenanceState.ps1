function Export-UnifiedMaintenanceState {
    <#
    .SYNOPSIS
        Exports unified maintenance state to file
    
    .DESCRIPTION
        Exports the current state of the unified maintenance system to a file
        for backup or persistence purposes
    
    .PARAMETER Path
        Path where to export the state file
    
    .EXAMPLE
        Export-UnifiedMaintenanceState -Path "C:\temp\maintenance-state.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        Write-MaintenanceLog "Exporting unified maintenance state to: $Path" 'INFO'
        
        # Collect state information
        $stateData = @{
            ManagementState = $script:ManagementState
            ProjectRoot = Get-ProjectRoot
            ExportedAt = Get-Date
            Version = "1.0.0"
        }
        
        # Add current status
        try {
            $stateData.CurrentStatus = Get-UnifiedMaintenanceStatus
        } catch {
            $stateData.CurrentStatus = @{ Error = "Failed to get current status: $($_.Exception.Message)" }
        }
        
        # Add recent health check if available
        try {
            $stateData.RecentHealthCheck = Invoke-InfrastructureHealth
        } catch {
            $stateData.RecentHealthCheck = @{ Error = "Failed to get health check: $($_.Exception.Message)" }
        }
        
        # Convert to JSON and save
        $stateJson = $stateData | ConvertTo-Json -Depth 10
        $stateJson | Out-File -FilePath $Path -Encoding UTF8
        
        Write-MaintenanceLog "Unified maintenance state exported successfully to: $Path" 'SUCCESS'
        return @{
            Path = $Path
            Size = (Get-Item $Path).Length
            ExportedAt = Get-Date
        }
        
    } catch {
        Write-MaintenanceLog "Failed to export unified maintenance state: $($_.Exception.Message)" 'ERROR'
        throw
    }
}