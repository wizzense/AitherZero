function Get-ConfigurationEventHistory {
    <#
    .SYNOPSIS
        Get configuration event history
    .DESCRIPTION
        Retrieves the history of published configuration events
    .PARAMETER EventName
        Filter by specific event name
    .PARAMETER ModuleName
        Filter by source module name
    .PARAMETER Since
        Get events since a specific date/time
    .PARAMETER Last
        Get the last N events
    .EXAMPLE
        Get-ConfigurationEventHistory -Last 10
    .EXAMPLE
        Get-ConfigurationEventHistory -EventName "ModuleConfigurationChanged" -Since (Get-Date).AddHours(-1)
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$EventName,

        [Parameter()]
        [string]$ModuleName,

        [Parameter()]
        [datetime]$Since,

        [Parameter()]
        [int]$Last
    )

    try {
        if (-not $script:ConfigurationStore.EventSystem -or
            -not $script:ConfigurationStore.EventSystem.EventHistory) {
            Write-CustomLog -Level 'INFO' -Message "No event history found"
            return @()
        }

        $events = $script:ConfigurationStore.EventSystem.EventHistory

        # Apply filters
        if ($EventName) {
            $events = $events | Where-Object { $_.EventName -eq $EventName }
        }

        if ($ModuleName) {
            $events = $events | Where-Object { $_.SourceModule -eq $ModuleName }
        }

        if ($Since) {
            $events = $events | Where-Object { $_.PublishedAt -ge $Since }
        }

        # Sort by published date (newest first)
        $events = $events | Sort-Object PublishedAt -Descending

        # Apply Last filter
        if ($Last) {
            $events = $events | Select-Object -First $Last
        }

        # Enhance events with summary information
        $enhancedEvents = @()
        foreach ($event in $events) {
            $successfulDeliveries = ($event.DeliveryResults | Where-Object { $_.Success }).Count
            $totalDeliveries = $event.DeliveryResults.Count
            $failedDeliveries = $totalDeliveries - $successfulDeliveries

            $enhancedEvent = $event.Clone()
            $enhancedEvent.DeliverySummary = @{
                Total = $totalDeliveries
                Successful = $successfulDeliveries
                Failed = $failedDeliveries
                SuccessRate = if ($totalDeliveries -gt 0) {
                    [math]::Round(($successfulDeliveries / $totalDeliveries) * 100, 2)
                } else {
                    0
                }
            }

            $enhancedEvents += $enhancedEvent
        }

        Write-CustomLog -Level 'INFO' -Message "Retrieved $($enhancedEvents.Count) event(s) from history"

        return $enhancedEvents

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get configuration event history: $_"
        throw
    }
}
