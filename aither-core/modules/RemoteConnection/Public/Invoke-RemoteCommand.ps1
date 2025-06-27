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
                # Execute command based on endpoint type
                $result = switch ($config.EndpointType) {
                    'SSH' { Invoke-SSHCommand -Config $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob }
                    'WinRM' { Invoke-WinRMCommand -Config $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob }
                    'VMware' { Invoke-VMwareCommand -Config $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob }
                    'Hyper-V' { Invoke-HyperVCommand -Config $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob }
                    'Docker' { Invoke-DockerCommand -Config $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob }
                    'Kubernetes' { Invoke-KubernetesCommand -Config $config -Command $Command -Parameters $Parameters -TimeoutSeconds $TimeoutSeconds -AsJob:$AsJob }
                    default { throw "Unsupported endpoint type: $($config.EndpointType)" }
                }

                if ($result.Success) {
                    Write-CustomLog -Level 'SUCCESS' -Message "Successfully executed command on: $ConnectionName"
                    return @{
                        Success = $true
                        ConnectionName = $ConnectionName
                        Output = $result.Output
                        ExitCode = $result.ExitCode
                        Job = $result.Job
                        Message = "Command executed successfully"
                    }
                } else {
                    throw "Failed to execute command: $($result.Error)"
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
