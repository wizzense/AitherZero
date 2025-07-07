function Disconnect-RemoteEndpoint {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Disconnect-RemoteEndpoint for: $ConnectionName"
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($ConnectionName, "Disconnect from remote endpoint")) {
                $result = Disconnect-EndpointSession -ConnectionName $ConnectionName

                if ($result.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully disconnected from: $ConnectionName"
                    return @{
                        Success = $true
                        ConnectionName = $ConnectionName
                        Message = "Disconnected successfully"
                    }
                } else {
                    throw "Failed to disconnect: $($result.Error)"
                }
            } else {
                Write-CustomLog -Level 'INFO' -Message "WhatIf: Would disconnect from $ConnectionName"
                return @{
                    Success = $true
                    ConnectionName = $ConnectionName
                    Message = "WhatIf: Would disconnect successfully"
                }
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to disconnect from $ConnectionName : $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed Disconnect-RemoteEndpoint for: $ConnectionName"
    }
}
