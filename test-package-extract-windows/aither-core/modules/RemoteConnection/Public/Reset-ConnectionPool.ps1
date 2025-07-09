function Reset-ConnectionPool {
    <#
    .SYNOPSIS
        Resets the connection pool by clearing all connections.

    .DESCRIPTION
        Closes all active connections in the pool and resets pool statistics.
        This is useful for troubleshooting connection issues or cleaning up
        after bulk operations.

    .PARAMETER Force
        Force reset without confirmation.

    .PARAMETER ReinitializePool
        Reinitialize the pool with default settings after clearing.

    .EXAMPLE
        Reset-ConnectionPool
        Clears all connections from the pool with confirmation.

    .EXAMPLE
        Reset-ConnectionPool -Force
        Clears all connections without confirmation.

    .EXAMPLE
        Reset-ConnectionPool -Force -ReinitializePool
        Clears all connections and reinitializes the pool.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$ReinitializePool
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting connection pool reset"
    }

    process {
        try {
            if ($Force -or $PSCmdlet.ShouldProcess("Connection Pool", "Reset all connections")) {
                # Get current status
                $poolStats = Get-ConnectionPoolStatistics
                $currentConnections = $poolStats.CurrentConnections

                # Clear the pool
                $clearResult = Clear-ConnectionPool -Force

                if ($clearResult) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Connection pool cleared successfully. Removed $currentConnections connections."

                    # Reinitialize if requested
                    if ($ReinitializePool) {
                        $initResult = Initialize-ConnectionPool
                        if ($initResult) {
                            Write-CustomLog -Level 'SUCCESS' -Message "Connection pool reinitialized successfully"
                        } else {
                            Write-CustomLog -Level 'WARN' -Message "Failed to reinitialize connection pool"
                        }
                    }

                    return @{
                        Success = $true
                        Message = "Connection pool reset successfully"
                        ConnectionsCleared = $currentConnections
                        Reinitialized = $ReinitializePool.IsPresent
                    }
                } else {
                    throw "Failed to clear connection pool"
                }
            } else {
                Write-CustomLog -Level 'INFO' -Message "WhatIf: Would reset connection pool"
                return @{
                    Success = $true
                    Message = "WhatIf: Would reset connection pool"
                    WhatIf = $true
                }
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to reset connection pool: $($_.Exception.Message)"
            throw
        }
    }
}
