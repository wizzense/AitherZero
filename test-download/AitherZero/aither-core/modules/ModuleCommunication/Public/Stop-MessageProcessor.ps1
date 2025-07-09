function Stop-MessageProcessor {
    <#
    .SYNOPSIS
        Stop the message processor
    .DESCRIPTION
        Gracefully stops the background message processor
    .PARAMETER Timeout
        Timeout in seconds to wait for graceful shutdown
    .PARAMETER Force
        Force stop without waiting
    .EXAMPLE
        Stop-MessageProcessor -Timeout 10
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Timeout = 30,

        [Parameter()]
        [switch]$Force
    )

    try {
        if (-not $script:MessageBus.Processor.Running) {
            Write-CustomLog -Level 'WARNING' -Message "Message processor is not running"
            return @{
                Success = $true
                Reason = "Not running"
            }
        }

        $stopStart = Get-Date
        $processor = $script:MessageBus.Processor.Thread
        $processorId = if ($processor) { $processor.InstanceId } else { "Unknown" }

        Write-CustomLog -Level 'INFO' -Message "Stopping message processor (ID: $processorId)..."

        # Signal cancellation
        if ($script:MessageBus.Processor.CancellationToken) {
            $script:MessageBus.Processor.CancellationToken.Cancel()
        }

        if ($Force) {
            # Force stop immediately
            if ($processor) {
                $processor.Stop()
                $processor.Dispose()
            }
            $script:MessageBus.Processor.Running = $false
            $script:MessageBus.Processor.Thread = $null

            Write-CustomLog -Level 'WARNING' -Message "Message processor force stopped"

            return @{
                Success = $true
                Method = "Force"
                Duration = ((Get-Date) - $stopStart).TotalMilliseconds
                ProcessorId = $processorId
            }
        } else {
            # Graceful shutdown
            $maxWait = $stopStart.AddSeconds($Timeout)

            while ((Get-Date) -lt $maxWait -and $script:MessageBus.Processor.Running) {
                Start-Sleep -Milliseconds 500

                # Check if processor has stopped
                if ($processor -and ($processor.InvocationStateInfo.State -eq 'Stopped' -or
                                   $processor.InvocationStateInfo.State -eq 'Completed' -or
                                   $processor.InvocationStateInfo.State -eq 'Failed')) {
                    break
                }
            }

            # Clean up
            if ($processor) {
                if ($processor.InvocationStateInfo.State -eq 'Running') {
                    Write-CustomLog -Level 'WARNING' -Message "Processor did not stop gracefully, forcing stop"
                    $processor.Stop()
                }
                $processor.Dispose()
            }

            $script:MessageBus.Processor.Running = $false
            $script:MessageBus.Processor.Thread = $null
            $script:MessageBus.Processor.CancellationToken = $null

            $stopDuration = ((Get-Date) - $stopStart).TotalMilliseconds
            $graceful = $stopDuration -lt ($Timeout * 1000)

            Write-CustomLog -Level 'SUCCESS' -Message "Message processor stopped $(if ($graceful) { 'gracefully' } else { 'forcefully' }) in ${stopDuration}ms"

            return @{
                Success = $true
                Method = if ($graceful) { "Graceful" } else { "Timeout" }
                Duration = $stopDuration
                ProcessorId = $processorId
                RemainingMessages = $script:MessageBus.MessageQueue.Count
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to stop message processor: $_"

        # Emergency cleanup
        $script:MessageBus.Processor.Running = $false
        $script:MessageBus.Processor.Thread = $null
        $script:MessageBus.Processor.CancellationToken = $null

        throw
    }
}
