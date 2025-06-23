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
                
                # Attempt connection based on endpoint type
                $result = switch ($config.EndpointType) {
                    'SSH' { Start-SSHSession -Config $config -Timeout $Timeout }
                    'WinRM' { Start-WinRMSession -Config $config -Timeout $Timeout }
                    'VMware' { Start-VMwareSession -Config $config -Timeout $Timeout }
                    'Hyper-V' { Start-HyperVSession -Config $config -Timeout $Timeout }
                    'Docker' { Start-DockerSession -Config $config -Timeout $Timeout }
                    'Kubernetes' { Start-KubernetesSession -Config $config -Timeout $Timeout }
                    default { 
                        @{ Success = $false; Error = "Unsupported endpoint type: $($config.EndpointType)" }
                    }
                }

                if ($result.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully connected to: $ConnectionName"
                    return @{
                        Success = $true
                        ConnectionName = $ConnectionName
                        SessionInfo = $result.SessionInfo
                        Message = "Connection established successfully"
                    }
                } else {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to connect to $ConnectionName`: $($result.Error)"
                    return @{
                        Success = $false
                        Error = $result.Error
                        ConnectionName = $ConnectionName
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