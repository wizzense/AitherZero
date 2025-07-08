function Reset-CircuitBreaker {
    <#
    .SYNOPSIS
        Reset circuit breaker state
    .DESCRIPTION
        Resets a circuit breaker to closed state, clearing failure counts
    .PARAMETER OperationName
        Operation to reset circuit breaker for
    .PARAMETER All
        Reset all circuit breakers
    .PARAMETER Force
        Force reset without confirmation
    .EXAMPLE
        Reset-CircuitBreaker -OperationName "LabRunner.ExecuteStep" -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Single')]
        [string]$OperationName,
        
        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        if (-not $script:CircuitBreakers) {
            Write-CustomLog -Level 'WARNING' -Message "No circuit breakers exist"
            return @{
                Success = $false
                Reason = "No circuit breakers exist"
            }
        }
        
        $resetOperations = @()
        
        if ($All) {
            if (-not $Force) {
                $choice = Read-Host "Reset all $($script:CircuitBreakers.Count) circuit breakers? (y/N)"
                if ($choice -ne 'y' -and $choice -ne 'Y') {
                    return @{
                        Success = $false
                        Reason = "Operation cancelled"
                    }
                }
            }
            
            foreach ($opName in $script:CircuitBreakers.Keys) {
                $cb = $script:CircuitBreakers[$opName]
                $originalState = $cb.State
                
                $cb.State = 'Closed'
                $cb.FailureCount = 0
                $cb.LastFailure = $null
                
                $resetOperations += @{
                    Operation = $opName
                    PreviousState = $originalState
                    ResetAt = Get-Date
                }
            }
        } else {
            if (-not $script:CircuitBreakers.ContainsKey($OperationName)) {
                throw "Circuit breaker not found for operation: $OperationName"
            }
            
            $cb = $script:CircuitBreakers[$OperationName]
            $originalState = $cb.State
            
            if (-not $Force -and $cb.State -eq 'Open') {
                $choice = Read-Host "Reset circuit breaker for '$OperationName' (currently $originalState)? (y/N)"
                if ($choice -ne 'y' -and $choice -ne 'Y') {
                    return @{
                        Success = $false
                        Reason = "Operation cancelled"
                    }
                }
            }
            
            $cb.State = 'Closed'
            $cb.FailureCount = 0
            $cb.LastFailure = $null
            
            $resetOperations += @{
                Operation = $OperationName
                PreviousState = $originalState
                ResetAt = Get-Date
            }
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Reset $($resetOperations.Count) circuit breakers"
        
        return @{
            Success = $true
            ResetCount = $resetOperations.Count
            ResetOperations = $resetOperations
            ResetAt = Get-Date
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to reset circuit breaker: $_"
        throw
    }
}