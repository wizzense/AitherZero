<#
.SYNOPSIS
    Stops the AitherZero REST API server gracefully.

.DESCRIPTION
    Stop-AitherZeroAPI gracefully shuts down the REST API server, closing
    active connections and cleaning up resources. Supports both background
    and synchronous server modes.

.PARAMETER Force
    Force immediate shutdown without waiting for active connections to complete.

.PARAMETER Timeout
    Maximum time to wait for graceful shutdown before forcing stop (seconds).

.EXAMPLE
    Stop-AitherZeroAPI
    Gracefully stops the API server with default timeout.

.EXAMPLE
    Stop-AitherZeroAPI -Force
    Immediately stops the API server without waiting for connections.

.EXAMPLE
    Stop-AitherZeroAPI -Timeout 30
    Stops the API server with 30-second timeout for graceful shutdown.
#>
function Stop-AitherZeroAPI {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$Timeout = 15
    )

    begin {
        Write-CustomLog -Message "Stopping AitherZero REST API server" -Level "INFO"

        # Check if API server is running
        if (-not $script:APIServer -or -not $script:APIServerJob) {
            Write-CustomLog -Message "API server is not currently running" -Level "WARNING"
            return @{
                Success = $true
                Message = "API server was not running"
                Status = "Stopped"
            }
        }
    }

    process {
        try {
            $stopResult = @{
                Success = $false
                Message = ""
                Status = "Unknown"
                StopTime = Get-Date
                UpTime = $null
            }

            # Calculate uptime
            if ($script:APIStartTime) {
                $stopResult.UpTime = (Get-Date) - $script:APIStartTime
            }

            if ($Force) {
                # Force immediate stop
                Write-CustomLog -Message "Force stopping API server job" -Level "WARNING"

                if ($script:APIServerJob.State -eq 'Running') {
                    Stop-Job -Job $script:APIServerJob -PassThru | Remove-Job
                }

                $stopResult.Success = $true
                $stopResult.Message = "API server force stopped"
                $stopResult.Status = "Force Stopped"

            } else {
                # Graceful shutdown
                Write-CustomLog -Message "Initiating graceful shutdown (timeout: ${Timeout}s)" -Level "INFO"

                # Send stop signal to server job
                if ($script:APIServerJob.State -eq 'Running') {
                    # Signal graceful shutdown by stopping the job
                    Stop-Job -Job $script:APIServerJob

                    # Wait for graceful shutdown
                    $waitTime = 0
                    while ($script:APIServerJob.State -eq 'Running' -and $waitTime -lt $Timeout) {
                        Start-Sleep -Seconds 1
                        $waitTime++

                        if ($waitTime % 5 -eq 0) {
                            Write-CustomLog -Message "Waiting for graceful shutdown... (${waitTime}/${Timeout}s)" -Level "DEBUG"
                        }
                    }

                    # Check if graceful shutdown completed
                    if ($script:APIServerJob.State -eq 'Running') {
                        Write-CustomLog -Message "Graceful shutdown timeout, forcing stop" -Level "WARNING"
                        Stop-Job -Job $script:APIServerJob -PassThru | Remove-Job
                        $stopResult.Status = "Timeout Force Stopped"
                    } else {
                        $stopResult.Status = "Gracefully Stopped"
                    }

                    # Remove the job
                    Remove-Job -Job $script:APIServerJob -Force -ErrorAction SilentlyContinue
                }

                $stopResult.Success = $true
                $stopResult.Message = "API server stopped successfully"
            }

            # Clean up server state
            $script:APIServer = $null
            $script:APIServerJob = $null
            $script:APIStartTime = $null

            # Reset metrics
            $script:APIMetrics.RequestCount = 0
            $script:APIMetrics.ErrorCount = 0
            $script:APIMetrics.LastRequest = $null
            $script:APIMetrics.UpTime = 0

            Write-CustomLog -Message $stopResult.Message -Level "SUCCESS"
            return $stopResult

        } catch {
            $errorMessage = "Failed to stop API server: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Message = $errorMessage
                Status = "Error"
                Error = $_.Exception.Message
            }
        }
    }
}

Export-ModuleMember -Function Stop-AitherZeroAPI
