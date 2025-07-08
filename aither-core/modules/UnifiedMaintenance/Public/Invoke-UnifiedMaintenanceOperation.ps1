function Invoke-UnifiedMaintenanceOperation {
    <#
    .SYNOPSIS
        Executes a unified maintenance operation
    
    .DESCRIPTION
        Performs operations on the unified maintenance system with proper validation
        and error handling
    
    .PARAMETER Operation
        The operation to perform
    
    .PARAMETER WhatIf
        Show what would happen without executing
    
    .EXAMPLE
        Invoke-UnifiedMaintenanceOperation -Operation "HealthCheck" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )
    
    try {
        Write-MaintenanceLog "Executing unified maintenance operation: $Operation" 'MAINTENANCE'
        
        $result = @{
            Operation = $Operation
            Status = 'Success'
            ExecutedAt = Get-Date
            WhatIf = $WhatIf.IsPresent
        }
        
        if ($WhatIf) {
            $result.Message = "Would execute operation: $Operation"
            Write-MaintenanceLog "WhatIf: Would execute operation: $Operation" 'INFO'
        } else {
            switch ($Operation) {
                'HealthCheck' {
                    $healthResult = Invoke-InfrastructureHealth
                    $result.Data = $healthResult
                    $result.Message = "Health check completed - Status: $($healthResult.OverallHealth)"
                    if ($script:ManagementState) {
                        $script:ManagementState.LastHealthCheck = Get-Date
                    }
                    Write-MaintenanceLog "Health check operation completed" 'SUCCESS'
                }
                'TestRun' {
                    $testResult = Invoke-AutomatedTestWorkflow -TestCategory 'Unit'
                    $result.Data = $testResult
                    $result.Message = "Test run completed"
                    if ($script:ManagementState) {
                        $script:ManagementState.LastTestRun = Get-Date
                    }
                    Write-MaintenanceLog "Test run operation completed" 'SUCCESS'
                }
                'QuickMaintenance' {
                    $maintenanceResult = Invoke-UnifiedMaintenance -Mode 'Quick'
                    $result.Data = $maintenanceResult
                    $result.Message = "Quick maintenance completed"
                    Write-MaintenanceLog "Quick maintenance operation completed" 'SUCCESS'
                }
                'FullMaintenance' {
                    $maintenanceResult = Invoke-UnifiedMaintenance -Mode 'Full'
                    $result.Data = $maintenanceResult
                    $result.Message = "Full maintenance completed"
                    Write-MaintenanceLog "Full maintenance operation completed" 'SUCCESS'
                }
                default {
                    $result.Status = 'Warning'
                    $result.Message = "Unknown operation: $Operation"
                    Write-MaintenanceLog "Unknown operation: $Operation" 'WARNING'
                }
            }
        }
        
        return $result
        
    } catch {
        Write-MaintenanceLog "Failed to execute unified maintenance operation: $($_.Exception.Message)" 'ERROR'
        throw
    }
}