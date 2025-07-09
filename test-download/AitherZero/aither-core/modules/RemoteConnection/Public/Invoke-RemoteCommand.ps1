function Invoke-RemoteCommand {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 300,

        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    begin {
        Write-CustomLog -Level 'INFO' -Message "Starting Invoke-RemoteCommand for: $ConnectionName"
    }

    process {
        try {
            # Get connection configuration
            $connectionConfig = Get-ConnectionConfiguration -ConnectionName $ConnectionName
            if (-not $connectionConfig.Success) {
                throw "Connection configuration not found: $ConnectionName"
            }

            $config = $connectionConfig.Configuration

            if ($PSCmdlet.ShouldProcess($ConnectionName, "Execute command: $Command")) {
                # Execute command with retry logic
                $retryResult = Invoke-CommandWithRetry -ConnectionConfig $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob

                if ($retryResult.Success) {
                    $result = $retryResult.Result
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully executed command on: $ConnectionName"

                    if ($retryResult.Attempts -gt 1) {
                        Write-CustomLog -Level 'INFO' -Message "Command succeeded after $($retryResult.Attempts) attempts"
                    }

                    return @{
                        Success = $true
                        ConnectionName = $ConnectionName
                        Output = $result.Output
                        ExitCode = $result.ExitCode
                        Job = $result.Job
                        Message = "Command executed successfully"
                        Attempts = $retryResult.Attempts
                    }
                } else {
                    # Generate diagnostics for failed command
                    $diagnostics = Get-ConnectionDiagnostics -ConnectionConfig $config -LastError $retryResult.Error
                    $formattedError = Format-ConnectionError -Error $retryResult.Error -ConnectionConfig $config -Diagnostics $diagnostics

                    Write-CustomLog -Level 'ERROR' -Message "Failed to execute command on $ConnectionName after $($retryResult.Attempts) attempts: $($retryResult.Error.Exception.Message)"

                    throw @{
                        Error = $retryResult.Error.Exception.Message
                        Attempts = $retryResult.Attempts
                        Diagnostics = $diagnostics
                        ErrorDetails = $formattedError
                    }
                }
            } else {
                Write-CustomLog -Level 'INFO' -Message "WhatIf: Would execute command '$Command' on $ConnectionName"
                return @{
                    Success = $true
                    ConnectionName = $ConnectionName
                    Message = "WhatIf: Command would be executed successfully"
                }
            }
        }
        catch {
            Write-CustomLog -Level 'ERROR' -Message "Failed to execute command on $ConnectionName : $($_.Exception.Message)"
            throw
        }
    }

    end {
        Write-CustomLog -Level 'INFO' -Message "Completed Invoke-RemoteCommand for: $ConnectionName"
    }
}
