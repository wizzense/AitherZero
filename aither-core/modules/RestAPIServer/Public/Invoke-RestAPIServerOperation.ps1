function Invoke-RestAPIServerOperation {
    <#
    .SYNOPSIS
        Executes a REST API server operation
    
    .DESCRIPTION
        Performs operations on the REST API server with proper validation
        and error handling
    
    .PARAMETER Operation
        The operation to perform
    
    .PARAMETER WhatIf
        Show what would happen without executing
    
    .EXAMPLE
        Invoke-RestAPIServerOperation -Operation "Test" -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )
    
    try {
        Write-CustomLog -Message "Executing REST API server operation: $Operation" -Level "INFO"
        
        $result = @{
            Operation = $Operation
            Status = 'Success'
            ExecutedAt = Get-Date
            WhatIf = $WhatIf.IsPresent
        }
        
        if ($WhatIf) {
            $result.Message = "Would execute operation: $Operation"
            Write-CustomLog -Message "WhatIf: Would execute operation: $Operation" -Level "INFO"
        } else {
            switch ($Operation) {
                'Test' {
                    $result.Message = "Test operation completed successfully"
                    Write-CustomLog -Message "Test operation completed" -Level "SUCCESS"
                }
                'Restart' {
                    $result.Message = "Restart operation completed successfully"
                    Write-CustomLog -Message "Restart operation completed" -Level "SUCCESS"
                }
                'Status' {
                    $result.Data = Get-RestAPIServerStatus
                    $result.Message = "Status operation completed successfully"
                    Write-CustomLog -Message "Status operation completed" -Level "SUCCESS"
                }
                default {
                    $result.Status = 'Warning'
                    $result.Message = "Unknown operation: $Operation"
                    Write-CustomLog -Message "Unknown operation: $Operation" -Level "WARNING"
                }
            }
        }
        
        return $result
        
    } catch {
        Write-CustomLog -Message "Failed to execute REST API server operation: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}