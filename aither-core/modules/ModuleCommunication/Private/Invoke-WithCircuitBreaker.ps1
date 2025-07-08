function Invoke-WithCircuitBreaker {
    <#
    .SYNOPSIS
        Execute operation with circuit breaker pattern
    .DESCRIPTION
        Implements circuit breaker pattern for fault tolerance
    .PARAMETER Operation
        ScriptBlock to execute
    .PARAMETER OperationName
        Name of the operation for tracking
    .PARAMETER FailureThreshold
        Number of failures before opening circuit
    .PARAMETER RecoveryTimeout
        Time in seconds before attempting recovery
    .PARAMETER Timeout
        Operation timeout in seconds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Operation,

        [Parameter(Mandatory)]
        [string]$OperationName,

        [Parameter()]
        [int]$FailureThreshold = 5,

        [Parameter()]
        [int]$RecoveryTimeout = 60,

        [Parameter()]
        [int]$Timeout = 30
    )

    # Initialize circuit breaker state if not exists
    if (-not $script:CircuitBreakers) {
        $script:CircuitBreakers = @{}
    }

    if (-not $script:CircuitBreakers.ContainsKey($OperationName)) {
        $script:CircuitBreakers[$OperationName] = @{
            State = 'Closed'  # Closed, Open, HalfOpen
            FailureCount = 0
            LastFailure = $null
            LastSuccess = $null
            TotalCalls = 0
            SuccessfulCalls = 0
        }
    }

    $circuitBreaker = $script:CircuitBreakers[$OperationName]
    $circuitBreaker.TotalCalls++

    try {
        # Check circuit state
        switch ($circuitBreaker.State) {
            'Open' {
                # Check if recovery timeout has passed
                if ($circuitBreaker.LastFailure -and
                    ((Get-Date) - $circuitBreaker.LastFailure).TotalSeconds -ge $RecoveryTimeout) {
                    $circuitBreaker.State = 'HalfOpen'
                    Write-CustomLog -Level 'INFO' -Message "Circuit breaker for '$OperationName' moved to HalfOpen state"
                } else {
                    throw "Circuit breaker is OPEN for operation '$OperationName'. Last failure: $($circuitBreaker.LastFailure)"
                }
            }
            'HalfOpen' {
                Write-CustomLog -Level 'DEBUG' -Message "Circuit breaker for '$OperationName' is in HalfOpen state - testing recovery"
            }
            'Closed' {
                # Normal operation
            }
        }

        # Execute operation with timeout
        $result = $null
        $completed = $false

        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()

        $powershell = [powershell]::Create()
        $powershell.Runspace = $runspace
        $powershell.AddScript($Operation)

        $handle = $powershell.BeginInvoke()
        $completed = $handle.AsyncWaitHandle.WaitOne($Timeout * 1000)

        if ($completed) {
            $result = $powershell.EndInvoke($handle)

            # Success - reset circuit breaker
            $circuitBreaker.FailureCount = 0
            $circuitBreaker.LastSuccess = Get-Date
            $circuitBreaker.SuccessfulCalls++

            if ($circuitBreaker.State -eq 'HalfOpen') {
                $circuitBreaker.State = 'Closed'
                Write-CustomLog -Level 'SUCCESS' -Message "Circuit breaker for '$OperationName' recovered - moved to Closed state"
            }

            return $result

        } else {
            $powershell.Stop()
            throw "Operation '$OperationName' timed out after $Timeout seconds"
        }

    } catch {
        # Handle failure
        $circuitBreaker.FailureCount++
        $circuitBreaker.LastFailure = Get-Date

        # Check if threshold reached
        if ($circuitBreaker.FailureCount -ge $FailureThreshold -and $circuitBreaker.State -ne 'Open') {
            $circuitBreaker.State = 'Open'
            Write-CustomLog -Level 'ERROR' -Message "Circuit breaker for '$OperationName' OPENED due to $($circuitBreaker.FailureCount) failures"
        }

        Write-CustomLog -Level 'ERROR' -Message "Circuit breaker operation '$OperationName' failed: $_"
        throw

    } finally {
        if ($powershell) {
            $powershell.Dispose()
        }
        if ($runspace) {
            $runspace.Close()
        }
    }
}
