#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Connects to a remote endpoint using a stored connection configuration.

.DESCRIPTION
    Establishes a connection to a remote endpoint using the configuration
    stored by New-RemoteConnection. Supports multiple connection types
    including SSH, WinRM, VMware, Hyper-V, Docker, and Kubernetes.

.PARAMETER ConnectionName
    The name of the connection configuration to use.

.PARAMETER Timeout
    Connection timeout in seconds. Default is 30 seconds.

.EXAMPLE
    Connect-RemoteEndpoint -ConnectionName "MyServer"
    Connects to the endpoint configured as "MyServer".

.EXAMPLE
    Connect-RemoteEndpoint -ConnectionName "MyServer" -Timeout 60
    Connects with a 60-second timeout.
#>
function Connect-RemoteEndpoint {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$Timeout = 30
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Connect-RemoteEndpoint for: $ConnectionName"
    }

    process {
        try {
            Write-CustomLog -Level 'INFO' -Message "Connecting to remote endpoint: $ConnectionName"

            # Get connection configuration
            $connectionConfig = Get-ConnectionConfiguration -ConnectionName $ConnectionName
            if (-not $connectionConfig.Success) {
                Write-CustomLog -Level 'ERROR' -Message "Connection configuration not found: $ConnectionName"
                return @{
                    Success = $false
                    Error = "Connection configuration not found"
                    ConnectionName = $ConnectionName
                }
            }

            if ($PSCmdlet.ShouldProcess($ConnectionName, "Connect to remote endpoint")) {
                $config = $connectionConfig.Configuration

                # Try to get connection from pool first
                $poolResult = Get-PooledConnection -ConnectionName $ConnectionName
                
                if ($poolResult.Success -and $poolResult.FromPool) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully connected to: $ConnectionName (from pool)"
                    return @{
                        Success = $true
                        ConnectionName = $ConnectionName
                        SessionInfo = $poolResult.Connection
                        Message = "Connection established successfully from pool"
                        FromPool = $true
                    }
                } elseif ($poolResult.Success -and -not $poolResult.FromPool) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully connected to: $ConnectionName (new connection)"
                    return @{
                        Success = $true
                        ConnectionName = $ConnectionName
                        SessionInfo = $poolResult.Connection
                        Message = "New connection established successfully"
                        FromPool = $false
                    }
                } else {
                    # Pool connection failed, try with retry logic
                    Write-CustomLog -Level 'WARN' -Message "Pool connection failed, attempting with retry logic"
                    
                    $retryResult = New-ConnectionWithRetry -ConnectionConfig $config -TimeoutSeconds $Timeout
                    
                    if ($retryResult.Success) {
                        Write-CustomLog -Level 'SUCCESS' -Message "Successfully connected to: $ConnectionName (with retry)"
                        return @{
                            Success = $true
                            ConnectionName = $ConnectionName
                            SessionInfo = $retryResult.Result.Session
                            Message = "Connection established successfully with retry"
                            Attempts = $retryResult.Attempts
                        }
                    } else {
                        # Generate diagnostics for failed connection
                        $diagnostics = Get-ConnectionDiagnostics -ConnectionConfig $config -LastError $retryResult.Error
                        $formattedError = Format-ConnectionError -Error $retryResult.Error -ConnectionConfig $config -Diagnostics $diagnostics
                        
                        Write-CustomLog -Level 'ERROR' -Message "Failed to connect to $ConnectionName after $($retryResult.Attempts) attempts: $($retryResult.Error.Exception.Message)"
                        
                        return @{
                            Success = $false
                            Error = $retryResult.Error.Exception.Message
                            ConnectionName = $ConnectionName
                            Attempts = $retryResult.Attempts
                            Diagnostics = $diagnostics
                            ErrorDetails = $formattedError
                        }
                    }
                }
            } else {
                Write-CustomLog -Level 'INFO' -Message "WhatIf: Would connect to $ConnectionName"
                return @{
                    Success = $true
                    ConnectionName = $ConnectionName
                    Message = "WhatIf: Would connect to endpoint"
                    WhatIf = $true
                }
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to connect to remote endpoint '$ConnectionName': $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed Connect-RemoteEndpoint for: $ConnectionName"
    }
}
