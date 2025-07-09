function Start-MessageProcessor {
    <#
    .SYNOPSIS
        Start the message processor
    .DESCRIPTION
        Starts the background message processor if it's not already running
    .PARAMETER Force
        Force restart if already running
    .EXAMPLE
        Start-MessageProcessor -Force
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    try {
        if ($script:MessageBus.Processor.Running -and -not $Force) {
            Write-CustomLog -Level 'WARNING' -Message "Message processor is already running"
            return @{
                Success = $false
                Reason = "Already running"
                ProcessorId = $script:MessageBus.Processor.Thread.Id
            }
        }

        # Stop existing processor if force restart
        if ($script:MessageBus.Processor.Running -and $Force) {
            Write-CustomLog -Level 'INFO' -Message "Force restarting message processor"
            Stop-MessageProcessor
            Start-Sleep -Milliseconds 500  # Give time for cleanup
        }

        # Initialize the processor
        Initialize-MessageProcessor

        # Verify it started
        $timeout = (Get-Date).AddSeconds(5)
        while ((Get-Date) -lt $timeout -and -not $script:MessageBus.Processor.Running) {
            Start-Sleep -Milliseconds 100
        }

        if ($script:MessageBus.Processor.Running) {
            Write-CustomLog -Level 'SUCCESS' -Message "Message processor started successfully"

            return @{
                Success = $true
                ProcessorId = $script:MessageBus.Processor.Thread.InstanceId
                StartTime = Get-Date
                QueueSize = $script:MessageBus.MessageQueue.Count
                Configuration = @{
                    ProcessorInterval = $script:Configuration.ProcessorInterval
                    MaxQueueSize = $script:Configuration.MaxMessageQueueSize
                    TracingEnabled = $script:Configuration.EnableTracing
                }
            }
        } else {
            throw "Message processor failed to start"
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to start message processor: $_"
        throw
    }
}
