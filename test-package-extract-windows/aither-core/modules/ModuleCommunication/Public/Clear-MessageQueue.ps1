function Clear-MessageQueue {
    <#
    .SYNOPSIS
        Clear the message queue
    .DESCRIPTION
        Removes all pending messages from the message queue
    .PARAMETER Channel
        Clear only messages for specific channel
    .PARAMETER MessageType
        Clear only messages of specific type
    .PARAMETER Force
        Force clear without confirmation
    .EXAMPLE
        Clear-MessageQueue -Channel "Configuration" -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$Channel,

        [Parameter()]
        [string]$MessageType,

        [Parameter()]
        [switch]$Force
    )

    try {
        $queueCount = $script:MessageBus.MessageQueue.Count

        if ($queueCount -eq 0) {
            Write-CustomLog -Level 'INFO' -Message "Message queue is already empty"
            return @{
                ClearedCount = 0
                Success = $true
            }
        }

        # Confirmation
        if (-not $Force -and -not $WhatIfPreference) {
            $message = "Clear $queueCount messages from queue?"
            if ($Channel) { $message += " (Channel: $Channel)" }
            if ($MessageType) { $message += " (Type: $MessageType)" }

            $choice = Read-Host "$message (y/N)"
            if ($choice -ne 'y' -and $choice -ne 'Y') {
                Write-CustomLog -Level 'INFO' -Message "Operation cancelled"
                return @{
                    ClearedCount = 0
                    Success = $false
                }
            }
        }

        if ($PSCmdlet.ShouldProcess("Message Queue", "Clear Messages")) {
            $clearedCount = 0

            if (-not $Channel -and -not $MessageType) {
                # Clear all messages
                while ($script:MessageBus.MessageQueue.Count -gt 0) {
                    $message = $null
                    if ($script:MessageBus.MessageQueue.TryDequeue([ref]$message)) {
                        $clearedCount++
                    }
                }
            } else {
                # Selective clearing - need to rebuild queue
                $tempQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()

                while ($script:MessageBus.MessageQueue.Count -gt 0) {
                    $message = $null
                    if ($script:MessageBus.MessageQueue.TryDequeue([ref]$message)) {
                        $shouldClear = $false

                        if ($Channel -and $message.Channel -eq $Channel) {
                            $shouldClear = $true
                        }
                        if ($MessageType -and $message.MessageType -eq $MessageType) {
                            $shouldClear = $true
                        }
                        if ($Channel -and $MessageType -and
                            $message.Channel -eq $Channel -and
                            $message.MessageType -eq $MessageType) {
                            $shouldClear = $true
                        }

                        if ($shouldClear) {
                            $clearedCount++
                        } else {
                            $tempQueue.Enqueue($message)
                        }
                    }
                }

                # Restore non-cleared messages
                while ($tempQueue.Count -gt 0) {
                    $message = $null
                    if ($tempQueue.TryDequeue([ref]$message)) {
                        $script:MessageBus.MessageQueue.Enqueue($message)
                    }
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Cleared $clearedCount messages from queue"

            return @{
                ClearedCount = $clearedCount
                Success = $true
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to clear message queue: $_"
        throw
    }
}
