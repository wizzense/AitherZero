function Get-CircuitBreakerStatus {
    <#
    .SYNOPSIS
        Get circuit breaker status
    .DESCRIPTION
        Returns the status of all circuit breakers or a specific one
    .PARAMETER OperationName
        Get status for specific operation
    .PARAMETER IncludeHistory
        Include failure history
    .EXAMPLE
        Get-CircuitBreakerStatus -IncludeHistory
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$OperationName,
        
        [Parameter()]
        [switch]$IncludeHistory
    )
    
    try {
        if (-not $script:CircuitBreakers) {
            return @{
                CircuitBreakers = @{}
                Summary = @{
                    TotalOperations = 0
                    OpenCircuits = 0
                    ClosedCircuits = 0
                    HalfOpenCircuits = 0
                }
            }
        }
        
        $result = @{
            Timestamp = Get-Date
            CircuitBreakers = @{}
            Summary = @{
                TotalOperations = 0
                OpenCircuits = 0
                ClosedCircuits = 0
                HalfOpenCircuits = 0
            }
        }
        
        if ($OperationName) {
            # Get specific circuit breaker
            if ($script:CircuitBreakers.ContainsKey($OperationName)) {
                $cb = $script:CircuitBreakers[$OperationName]
                
                $cbInfo = @{
                    OperationName = $OperationName
                    State = $cb.State
                    FailureCount = $cb.FailureCount
                    TotalCalls = $cb.TotalCalls
                    SuccessfulCalls = $cb.SuccessfulCalls
                    SuccessRate = if ($cb.TotalCalls -gt 0) {
                        [math]::Round(($cb.SuccessfulCalls / $cb.TotalCalls) * 100, 2)
                    } else { 0 }
                    LastFailure = $cb.LastFailure
                    LastSuccess = $cb.LastSuccess
                    TimeSinceLastFailure = if ($cb.LastFailure) {
                        [math]::Round(((Get-Date) - $cb.LastFailure).TotalSeconds, 2)
                    } else { $null }
                }
                
                return $cbInfo
            } else {
                throw "Circuit breaker not found for operation: $OperationName"
            }
        } else {
            # Get all circuit breakers
            foreach ($opName in $script:CircuitBreakers.Keys) {
                $cb = $script:CircuitBreakers[$opName]
                
                $cbInfo = @{
                    OperationName = $opName
                    State = $cb.State
                    FailureCount = $cb.FailureCount
                    TotalCalls = $cb.TotalCalls
                    SuccessfulCalls = $cb.SuccessfulCalls
                    SuccessRate = if ($cb.TotalCalls -gt 0) {
                        [math]::Round(($cb.SuccessfulCalls / $cb.TotalCalls) * 100, 2)
                    } else { 0 }
                    LastFailure = $cb.LastFailure
                    LastSuccess = $cb.LastSuccess
                    TimeSinceLastFailure = if ($cb.LastFailure) {
                        [math]::Round(((Get-Date) - $cb.LastFailure).TotalSeconds, 2)
                    } else { $null }
                }
                
                $result.CircuitBreakers[$opName] = $cbInfo
                
                # Update summary
                $result.Summary.TotalOperations++
                switch ($cb.State) {
                    'Open' { $result.Summary.OpenCircuits++ }
                    'Closed' { $result.Summary.ClosedCircuits++ }
                    'HalfOpen' { $result.Summary.HalfOpenCircuits++ }
                }
            }
            
            return $result
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get circuit breaker status: $_"
        throw
    }
}