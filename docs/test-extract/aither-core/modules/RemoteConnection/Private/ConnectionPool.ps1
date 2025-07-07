# Connection Pool Management for RemoteConnection Module

# Global connection pool variable
if (-not (Get-Variable -Name 'Global:AitherZeroConnectionPool' -ErrorAction SilentlyContinue)) {
    $Global:AitherZeroConnectionPool = @{}
}

function Initialize-ConnectionPool {
    <#
    .SYNOPSIS
        Initializes the connection pool with default settings.
    
    .DESCRIPTION
        Sets up the global connection pool with configuration options
        for maximum connections, timeout settings, and cleanup policies.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MaxConnections = 50,
        
        [Parameter()]
        [int]$ConnectionTimeoutMinutes = 30,
        
        [Parameter()]
        [int]$CleanupIntervalMinutes = 5
    )
    
    try {
        $Global:AitherZeroConnectionPool = @{
            MaxConnections = $MaxConnections
            ConnectionTimeout = [TimeSpan]::FromMinutes($ConnectionTimeoutMinutes)
            CleanupInterval = [TimeSpan]::FromMinutes($CleanupIntervalMinutes)
            Connections = @{}
            LastCleanup = Get-Date
            Statistics = @{
                TotalConnections = 0
                ActiveConnections = 0
                SuccessfulConnections = 0
                FailedConnections = 0
                ReusedConnections = 0
            }
        }
        
        Write-CustomLog -Level 'INFO' -Message "Connection pool initialized with max $MaxConnections connections"
        return $true
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize connection pool: $($_.Exception.Message)"
        return $false
    }
}

function Get-PooledConnection {
    <#
    .SYNOPSIS
        Retrieves a connection from the pool or creates a new one.
    
    .DESCRIPTION
        Checks the connection pool for an existing, valid connection.
        If found, returns it. Otherwise, creates a new connection.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionName,
        
        [Parameter()]
        [switch]$ForceNew
    )
    
    try {
        # Initialize pool if not already done
        if (-not $Global:AitherZeroConnectionPool -or -not $Global:AitherZeroConnectionPool.Connections) {
            Initialize-ConnectionPool
        }
        
        # Clean up expired connections
        Invoke-ConnectionPoolCleanup
        
        $poolKey = "Pool_$ConnectionName"
        
        # Check if we should force a new connection
        if ($ForceNew) {
            Remove-PooledConnection -ConnectionName $ConnectionName
        }
        
        # Check if connection exists in pool
        if ($Global:AitherZeroConnectionPool.Connections.ContainsKey($poolKey)) {
            $pooledConnection = $Global:AitherZeroConnectionPool.Connections[$poolKey]
            
            # Validate connection is still active
            if (Test-PooledConnectionHealth -PooledConnection $pooledConnection) {
                # Update last used time
                $pooledConnection.LastUsed = Get-Date
                $Global:AitherZeroConnectionPool.Statistics.ReusedConnections++
                
                Write-CustomLog -Level 'DEBUG' -Message "Reusing pooled connection: $ConnectionName"
                return @{
                    Success = $true
                    Connection = $pooledConnection.Connection
                    FromPool = $true
                    PoolKey = $poolKey
                }
            } else {
                # Connection is stale, remove it
                Remove-PooledConnection -ConnectionName $ConnectionName
            }
        }
        
        # Create new connection
        $connectionResult = New-PooledConnection -ConnectionName $ConnectionName
        
        if ($connectionResult.Success) {
            return @{
                Success = $true
                Connection = $connectionResult.Connection
                FromPool = $false
                PoolKey = $connectionResult.PoolKey
            }
        } else {
            return @{
                Success = $false
                Error = $connectionResult.Error
                FromPool = $false
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get pooled connection: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
            FromPool = $false
        }
    }
}

function New-PooledConnection {
    <#
    .SYNOPSIS
        Creates a new connection and adds it to the pool.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionName
    )
    
    try {
        # Check pool capacity
        if ($Global:AitherZeroConnectionPool.Connections.Count -ge $Global:AitherZeroConnectionPool.MaxConnections) {
            # Remove oldest connection
            $oldestConnection = $Global:AitherZeroConnectionPool.Connections.GetEnumerator() | 
                Sort-Object { $_.Value.LastUsed } | 
                Select-Object -First 1
            
            if ($oldestConnection) {
                Remove-PooledConnection -PoolKey $oldestConnection.Key
                Write-CustomLog -Level 'INFO' -Message "Removed oldest connection to make room in pool"
            }
        }
        
        # Get connection configuration
        $configResult = Get-ConnectionConfiguration -ConnectionName $ConnectionName
        if (-not $configResult.Success) {
            throw "Connection configuration not found: $ConnectionName"
        }
        
        $config = $configResult.Configuration
        
        # Establish connection based on endpoint type
        $connectionResult = switch ($config.EndpointType) {
            'SSH' { Connect-SSHEndpoint -Config $config -TimeoutSeconds 30 }
            'WinRM' { Connect-WinRMEndpoint -Config $config -TimeoutSeconds 30 }
            'VMware' { Connect-VMwareEndpoint -Config $config -TimeoutSeconds 30 }
            'Hyper-V' { Connect-HyperVEndpoint -Config $config -TimeoutSeconds 30 }
            'Docker' { Connect-DockerEndpoint -Config $config -TimeoutSeconds 30 }
            'Kubernetes' { Connect-KubernetesEndpoint -Config $config -TimeoutSeconds 30 }
            default { @{ Success = $false; Error = "Unsupported endpoint type: $($config.EndpointType)" } }
        }
        
        if ($connectionResult.Success) {
            # Add to pool
            $poolKey = "Pool_$ConnectionName"
            $pooledConnection = @{
                ConnectionName = $ConnectionName
                Connection = $connectionResult.Session
                Config = $config
                Created = Get-Date
                LastUsed = Get-Date
                UsageCount = 1
                EndpointType = $config.EndpointType
            }
            
            $Global:AitherZeroConnectionPool.Connections[$poolKey] = $pooledConnection
            $Global:AitherZeroConnectionPool.Statistics.TotalConnections++
            $Global:AitherZeroConnectionPool.Statistics.ActiveConnections++
            $Global:AitherZeroConnectionPool.Statistics.SuccessfulConnections++
            
            Write-CustomLog -Level 'SUCCESS' -Message "Created new pooled connection: $ConnectionName"
            
            return @{
                Success = $true
                Connection = $connectionResult.Session
                PoolKey = $poolKey
            }
        } else {
            $Global:AitherZeroConnectionPool.Statistics.FailedConnections++
            throw "Failed to establish connection: $($connectionResult.Error)"
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to create pooled connection: $($_.Exception.Message)"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Remove-PooledConnection {
    <#
    .SYNOPSIS
        Removes a connection from the pool and closes it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName = 'ByName')]
        [string]$ConnectionName,
        
        [Parameter(ParameterSetName = 'ByKey')]
        [string]$PoolKey
    )
    
    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $PoolKey = "Pool_$ConnectionName"
        }
        
        if ($Global:AitherZeroConnectionPool.Connections.ContainsKey($PoolKey)) {
            $pooledConnection = $Global:AitherZeroConnectionPool.Connections[$PoolKey]
            
            # Close the connection based on type
            try {
                switch ($pooledConnection.EndpointType) {
                    'VMware' {
                        if ($pooledConnection.Connection.Connection) {
                            Disconnect-VIServer -Server $pooledConnection.Connection.Connection -Confirm:$false -Force
                        }
                    }
                    'WinRM' {
                        # WinRM sessions are handled automatically by PowerShell
                    }
                    default {
                        # Generic cleanup for other connection types
                    }
                }
            }
            catch {
                Write-CustomLog -Level 'WARN' -Message "Error closing connection: $($_.Exception.Message)"
            }
            
            # Remove from pool
            $Global:AitherZeroConnectionPool.Connections.Remove($PoolKey)
            $Global:AitherZeroConnectionPool.Statistics.ActiveConnections--
            
            Write-CustomLog -Level 'DEBUG' -Message "Removed connection from pool: $($pooledConnection.ConnectionName)"
            return $true
        }
        
        return $false
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to remove pooled connection: $($_.Exception.Message)"
        return $false
    }
}

function Test-PooledConnectionHealth {
    <#
    .SYNOPSIS
        Tests if a pooled connection is still healthy and active.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PooledConnection
    )
    
    try {
        # Check if connection has expired
        $age = (Get-Date) - $PooledConnection.LastUsed
        if ($age -gt $Global:AitherZeroConnectionPool.ConnectionTimeout) {
            Write-CustomLog -Level 'DEBUG' -Message "Connection expired: $($PooledConnection.ConnectionName)"
            return $false
        }
        
        # Perform basic connectivity test based on endpoint type
        switch ($PooledConnection.EndpointType) {
            'SSH' {
                # Test SSH connection (simplified)
                return $PooledConnection.Connection.Connected -eq $true
            }
            'WinRM' {
                # Test WinRM connection
                return $PooledConnection.Connection.Connected -eq $true
            }
            'VMware' {
                # Test VMware connection
                if ($PooledConnection.Connection.Connection) {
                    return $PooledConnection.Connection.Connection.IsConnected -eq $true
                }
                return $false
            }
            'Docker' {
                # Test Docker connection by pinging API
                try {
                    $dockerUrl = $PooledConnection.Connection.DockerUrl
                    $response = Invoke-RestMethod -Uri "$dockerUrl/ping" -TimeoutSec 5 -ErrorAction Stop
                    return $response -eq "OK"
                }
                catch {
                    return $false
                }
            }
            default {
                # For other types, assume healthy if not too old
                return $true
            }
        }
    }
    catch {
        Write-CustomLog -Level 'DEBUG' -Message "Connection health check failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-ConnectionPoolCleanup {
    <#
    .SYNOPSIS
        Cleans up expired or unhealthy connections from the pool.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if cleanup is needed
        $timeSinceLastCleanup = (Get-Date) - $Global:AitherZeroConnectionPool.LastCleanup
        if ($timeSinceLastCleanup -lt $Global:AitherZeroConnectionPool.CleanupInterval) {
            return
        }
        
        Write-CustomLog -Level 'DEBUG' -Message "Starting connection pool cleanup"
        
        $connectionsToRemove = @()
        
        # Check each connection
        foreach ($poolEntry in $Global:AitherZeroConnectionPool.Connections.GetEnumerator()) {
            if (-not (Test-PooledConnectionHealth -PooledConnection $poolEntry.Value)) {
                $connectionsToRemove += $poolEntry.Key
            }
        }
        
        # Remove unhealthy connections
        foreach ($key in $connectionsToRemove) {
            Remove-PooledConnection -PoolKey $key
        }
        
        # Update cleanup time
        $Global:AitherZeroConnectionPool.LastCleanup = Get-Date
        
        if ($connectionsToRemove.Count -gt 0) {
            Write-CustomLog -Level 'INFO' -Message "Cleaned up $($connectionsToRemove.Count) stale connections from pool"
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Connection pool cleanup failed: $($_.Exception.Message)"
    }
}

function Get-ConnectionPoolStatistics {
    <#
    .SYNOPSIS
        Returns statistics about the connection pool.
    #>
    [CmdletBinding()]
    param()
    
    if (-not $Global:AitherZeroConnectionPool) {
        return @{
            PoolInitialized = $false
        }
    }
    
    return @{
        PoolInitialized = $true
        MaxConnections = $Global:AitherZeroConnectionPool.MaxConnections
        CurrentConnections = $Global:AitherZeroConnectionPool.Connections.Count
        ConnectionTimeout = $Global:AitherZeroConnectionPool.ConnectionTimeout.TotalMinutes
        LastCleanup = $Global:AitherZeroConnectionPool.LastCleanup
        Statistics = $Global:AitherZeroConnectionPool.Statistics.Clone()
        ConnectionDetails = $Global:AitherZeroConnectionPool.Connections.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{
                PoolKey = $_.Key
                ConnectionName = $_.Value.ConnectionName
                EndpointType = $_.Value.EndpointType
                Created = $_.Value.Created
                LastUsed = $_.Value.LastUsed
                UsageCount = $_.Value.UsageCount
                Age = ((Get-Date) - $_.Value.Created).TotalMinutes
                IdleTime = ((Get-Date) - $_.Value.LastUsed).TotalMinutes
            }
        }
    }
}

function Clear-ConnectionPool {
    <#
    .SYNOPSIS
        Clears all connections from the pool.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )
    
    if ($Force -or $PSCmdlet.ShouldProcess("Connection Pool", "Clear all connections")) {
        try {
            if ($Global:AitherZeroConnectionPool -and $Global:AitherZeroConnectionPool.Connections) {
                $connectionKeys = @($Global:AitherZeroConnectionPool.Connections.Keys)
                
                foreach ($key in $connectionKeys) {
                    Remove-PooledConnection -PoolKey $key
                }
                
                # Reset statistics
                $Global:AitherZeroConnectionPool.Statistics.ActiveConnections = 0
                
                Write-CustomLog -Level 'INFO' -Message "Cleared all connections from pool"
                return $true
            }
            return $true
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to clear connection pool: $($_.Exception.Message)"
            return $false
        }
    }
}

# Initialize the pool when this script is loaded
Initialize-ConnectionPool