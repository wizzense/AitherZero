function Get-UnifiedMaintenanceStatus {
    <#
    .SYNOPSIS
        Gets the current status of unified maintenance
    
    .DESCRIPTION
        Retrieves comprehensive status information about the unified maintenance system
        including state, configuration, and recent operations
    
    .EXAMPLE
        Get-UnifiedMaintenanceStatus
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-MaintenanceLog "Retrieving unified maintenance status..." 'INFO'
        
        # Get current state
        $status = @{
            State = if ($script:ManagementState) { $script:ManagementState.State } else { 'Uninitialized' }
            ManagementRunning = $script:ManagementState -ne $null
            ProjectRoot = Get-ProjectRoot
            LastUpdated = Get-Date
        }
        
        # Add uptime calculation if management is running
        if ($script:ManagementState -and $script:ManagementState.StartTime) {
            $status.UpTime = (Get-Date) - $script:ManagementState.StartTime
            $status.MaintenanceMode = $script:ManagementState.MaintenanceMode
            $status.LastHealthCheck = $script:ManagementState.LastHealthCheck
            $status.LastTestRun = $script:ManagementState.LastTestRun
        }
        
        # Check health of key components
        $status.ComponentHealth = @{
            Prerequisites = Test-Prerequisites -ProjectRoot $status.ProjectRoot
            Modules = @{
                LabRunner = Test-Path (Join-Path $status.ProjectRoot "aither-core/modules/LabRunner")
                PatchManager = Test-Path (Join-Path $status.ProjectRoot "aither-core/modules/PatchManager")
            }
            TestFramework = @{
                Pester = $null -ne (Get-Module -ListAvailable Pester)
                Python = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
            }
        }
        
        Write-MaintenanceLog "Unified maintenance status retrieved successfully" 'INFO'
        return $status
        
    } catch {
        Write-MaintenanceLog "Failed to get unified maintenance status: $($_.Exception.Message)" 'ERROR'
        throw
    }
}