function Get-RemoteConnection {
    <#
    .SYNOPSIS
        Retrieves remote connection configurations.

    .DESCRIPTION
        Gets stored remote connection configurations by name or lists all
        available connections. Supports filtering and detailed information.

    .PARAMETER ConnectionName
        Name of the specific connection to retrieve. If not specified, returns all connections.

    .PARAMETER EndpointType
        Filter connections by endpoint type.

    .PARAMETER IncludeCredentials
        Include credential information in the output (credential names only, not actual secrets).

    .EXAMPLE
        Get-RemoteConnection
        Gets all stored remote connections.

    .EXAMPLE
        Get-RemoteConnection -ConnectionName "HyperV-Lab-01"
        Gets a specific remote connection configuration.

    .EXAMPLE
        Get-RemoteConnection -EndpointType SSH
        Gets all SSH remote connections.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConnectionName,

        [Parameter()]
        [ValidateSet('SSH', 'WinRM', 'VMware', 'Hyper-V', 'Docker', 'Kubernetes')]
        [string]$EndpointType,

        [Parameter()]
        [switch]$IncludeCredentials
    )

    begin {
        Write-CustomLog -Level 'DEBUG' -Message "Retrieving remote connection(s)"
    }

    process {
        try {
            if ($ConnectionName) {
                # Get specific connection
                $config = Get-ConnectionConfig -ConnectionName $ConnectionName
                if (-not $config) {
                    Write-CustomLog -Level 'WARN' -Message "Connection '$ConnectionName' not found"
                    return $null
                }

                $connections = @($config)
            } else {
                # Get all connections
                $connections = Get-AllConnectionConfigs
            }

            # Apply endpoint type filter if specified
            if ($EndpointType) {
                $connections = $connections | Where-Object { $_.EndpointType -eq $EndpointType }
            }

            # Format output objects
            $results = @()
            foreach ($conn in $connections) {
                $result = [PSCustomObject]@{
                    ConnectionName = $conn.Name
                    EndpointType = $conn.EndpointType
                    HostName = $conn.HostName
                    Port = $conn.Port
                    Status = $conn.Status
                    CreatedDate = $conn.CreatedDate
                    LastModified = $conn.LastModified
                    LastUsed = $conn.LastUsed
                    EnableSSL = $conn.EnableSSL
                    ConnectionTimeout = $conn.ConnectionTimeout
                }

                # Add credential information if requested
                if ($IncludeCredentials) {
                    $result | Add-Member -NotePropertyName 'CredentialName' -NotePropertyValue $conn.CredentialName
                    $result | Add-Member -NotePropertyName 'CredentialExists' -NotePropertyValue $(
                        if ($conn.CredentialName) {
                            Test-SecureCredential -CredentialName $conn.CredentialName
                        } else {
                            $false
                        }
                    )
                }

                $results += $result
            }

            if ($ConnectionName) {
                # Return single object if specific connection requested
                return $results[0]
            } else {
                # Return array for all connections
                return $results
            }

        } catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to retrieve remote connection(s): $($_.Exception.Message)"
            throw
        }
    }
}
