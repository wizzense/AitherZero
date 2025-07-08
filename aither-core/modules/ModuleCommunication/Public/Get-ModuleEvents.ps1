function Get-ModuleEvents {
    <#
    .SYNOPSIS
        Get module event history
    .DESCRIPTION
        Returns stored event history with optional filtering
    .PARAMETER EventName
        Filter by event name (supports wildcards)
    .PARAMETER Channel
        Filter by channel
    .PARAMETER Since
        Get events since this datetime
    .PARAMETER Last
        Get last N events
    .PARAMETER IncludeSource
        Include source information
    .EXAMPLE
        Get-ModuleEvents -EventName "Configuration*" -Since (Get-Date).AddHours(-1) -IncludeSource
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$EventName,

        [Parameter()]
        [string]$Channel,

        [Parameter()]
        [datetime]$Since,

        [Parameter()]
        [int]$Last = 0,

        [Parameter()]
        [switch]$IncludeSource
    )

    try {
        $events = @()

        # Get events from history
        $eventHistory = @($script:MessageBus.EventHistory.ToArray())

        # Apply filters
        foreach ($event in $eventHistory) {
            # Event name filter
            if ($EventName -and $event.Name -notlike $EventName) {
                continue
            }

            # Channel filter
            if ($Channel -and $event.Channel -ne $Channel) {
                continue
            }

            # Time filter
            if ($Since -and $event.Timestamp -lt $Since) {
                continue
            }

            # Build event info
            $eventInfo = @{
                Id = $event.Id
                Name = $event.Name
                Channel = $event.Channel
                Timestamp = $event.Timestamp
                Data = $event.Data
            }

            if ($IncludeSource) {
                $eventInfo.Source = $event.Source
            }

            $events += $eventInfo
        }

        # Sort by timestamp (newest first)
        $events = $events | Sort-Object -Property Timestamp -Descending

        # Apply Last filter
        if ($Last -gt 0) {
            $events = $events | Select-Object -First $Last
        }

        return $events

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get events: $_"
        throw
    }
}
