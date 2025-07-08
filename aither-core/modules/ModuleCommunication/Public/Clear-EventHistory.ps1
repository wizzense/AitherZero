function Clear-EventHistory {
    <#
    .SYNOPSIS
        Clear module event history
    .DESCRIPTION
        Removes events from the event history with optional filtering
    .PARAMETER EventName
        Clear only events with this name (supports wildcards)
    .PARAMETER Channel
        Clear only events from this channel
    .PARAMETER OlderThan
        Clear events older than this datetime
    .PARAMETER Force
        Force clear without confirmation
    .EXAMPLE
        Clear-EventHistory -OlderThan (Get-Date).AddDays(-7) -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$EventName,

        [Parameter()]
        [string]$Channel,

        [Parameter()]
        [datetime]$OlderThan,

        [Parameter()]
        [switch]$Force
    )

    try {
        $originalCount = $script:MessageBus.EventHistory.Count

        if ($originalCount -eq 0) {
            Write-CustomLog -Level 'INFO' -Message "Event history is already empty"
            return @{
                ClearedCount = 0
                Success = $true
            }
        }

        # Confirmation
        if (-not $Force -and -not $WhatIfPreference) {
            $message = "Clear event history?"
            if ($EventName) { $message += " (EventName: $EventName)" }
            if ($Channel) { $message += " (Channel: $Channel)" }
            if ($OlderThan) { $message += " (OlderThan: $OlderThan)" }
            $message += " ($originalCount events)"

            $choice = Read-Host "$message (y/N)"
            if ($choice -ne 'y' -and $choice -ne 'Y') {
                Write-CustomLog -Level 'INFO' -Message "Operation cancelled"
                return @{
                    ClearedCount = 0
                    Success = $false
                }
            }
        }

        if ($PSCmdlet.ShouldProcess("Event History", "Clear Events")) {
            $clearedCount = 0

            if (-not $EventName -and -not $Channel -and -not $OlderThan) {
                # Clear all events
                while ($script:MessageBus.EventHistory.Count -gt 0) {
                    $event = $null
                    if ($script:MessageBus.EventHistory.TryDequeue([ref]$event)) {
                        $clearedCount++
                    }
                }
            } else {
                # Selective clearing - need to rebuild queue
                $tempQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()

                while ($script:MessageBus.EventHistory.Count -gt 0) {
                    $event = $null
                    if ($script:MessageBus.EventHistory.TryDequeue([ref]$event)) {
                        $shouldClear = $false

                        # Apply filters
                        if ($EventName -and $event.Name -like $EventName) {
                            $shouldClear = $true
                        }
                        if ($Channel -and $event.Channel -eq $Channel) {
                            $shouldClear = $true
                        }
                        if ($OlderThan -and $event.Timestamp -lt $OlderThan) {
                            $shouldClear = $true
                        }

                        # If multiple filters, all must match
                        if (($EventName -or $Channel -or $OlderThan) -and -not $shouldClear) {
                            # Check if all specified filters match
                            $matches = 0
                            $totalFilters = 0

                            if ($EventName) {
                                $totalFilters++
                                if ($event.Name -like $EventName) { $matches++ }
                            }
                            if ($Channel) {
                                $totalFilters++
                                if ($event.Channel -eq $Channel) { $matches++ }
                            }
                            if ($OlderThan) {
                                $totalFilters++
                                if ($event.Timestamp -lt $OlderThan) { $matches++ }
                            }

                            $shouldClear = ($matches -eq $totalFilters)
                        }

                        if ($shouldClear) {
                            $clearedCount++
                        } else {
                            $tempQueue.Enqueue($event)
                        }
                    }
                }

                # Restore non-cleared events
                while ($tempQueue.Count -gt 0) {
                    $event = $null
                    if ($tempQueue.TryDequeue([ref]$event)) {
                        $script:MessageBus.EventHistory.Enqueue($event)
                    }
                }
            }

            Write-CustomLog -Level 'SUCCESS' -Message "Cleared $clearedCount events from history (was $originalCount, now $($script:MessageBus.EventHistory.Count))"

            return @{
                ClearedCount = $clearedCount
                OriginalCount = $originalCount
                RemainingCount = $script:MessageBus.EventHistory.Count
                Success = $true
            }
        }

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to clear event history: $_"
        throw
    }
}
