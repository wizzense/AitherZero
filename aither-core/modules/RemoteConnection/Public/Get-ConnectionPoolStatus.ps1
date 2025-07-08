function Get-ConnectionPoolStatus {
    <#
    .SYNOPSIS
        Retrieves status and statistics of the connection pool.

    .DESCRIPTION
        Returns detailed information about the current state of the connection pool,
        including active connections, statistics, and performance metrics.

    .PARAMETER Detailed
        Include detailed information about each connection in the pool.

    .EXAMPLE
        Get-ConnectionPoolStatus
        Gets basic pool status information.

    .EXAMPLE
        Get-ConnectionPoolStatus -Detailed
        Gets detailed status including information about each pooled connection.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Detailed
    )

    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Retrieving connection pool status"
    }

    process {
        try {
            $poolStats = Get-ConnectionPoolStatistics

            if (-not $poolStats.PoolInitialized) {
                Write-CustomLog -Level 'WARN' -Message "Connection pool not initialized"
                return [PSCustomObject]@{
                    PoolInitialized = $false
                    Message = "Connection pool not initialized"
                }
            }

            $statusObject = [PSCustomObject]@{
                PoolInitialized = $poolStats.PoolInitialized
                MaxConnections = $poolStats.MaxConnections
                CurrentConnections = $poolStats.CurrentConnections
                ConnectionTimeoutMinutes = $poolStats.ConnectionTimeout
                LastCleanup = $poolStats.LastCleanup
                Statistics = [PSCustomObject]$poolStats.Statistics
                PoolUtilization = [math]::Round(($poolStats.CurrentConnections / $poolStats.MaxConnections) * 100, 2)
                Health = if ($poolStats.CurrentConnections -eq 0) {
                    "Empty"
                } elseif ($poolStats.CurrentConnections -lt ($poolStats.MaxConnections * 0.8)) {
                    "Healthy"
                } else {
                    "Near Capacity"
                }
            }

            if ($Detailed -and $poolStats.ConnectionDetails) {
                $statusObject | Add-Member -NotePropertyName 'Connections' -NotePropertyValue $poolStats.ConnectionDetails
            }

            Write-CustomLog -Level 'INFO' -Message "Connection pool status: $($statusObject.CurrentConnections)/$($statusObject.MaxConnections) connections ($($statusObject.PoolUtilization)% utilization)"

            return $statusObject

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to get connection pool status: $($_.Exception.Message)"
            throw
        }
    }
}
