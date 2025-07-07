function Get-UtilityEvents {
    <#
    .SYNOPSIS
        Retrieves utility service events
    
    .DESCRIPTION
        Gets event history from the utility services event system
    
    .PARAMETER EventType
        Filter by specific event type
    
    .PARAMETER Source
        Filter by event source
    
    .PARAMETER Count
        Maximum number of events to return
    
    .EXAMPLE
        Get-UtilityEvents -Count 20
        
        Get the last 20 events
    #>
    [CmdletBinding()]
    param(
        [string]$EventType,
        [string]$Source,
        [int]$Count = 100
    )
    
    $events = $script:ServiceEventSystem.EventHistory
    
    if ($EventType) {
        $events = $events | Where-Object { $_.EventType -eq $EventType }
    }
    
    if ($Source) {
        $events = $events | Where-Object { $_.Source -eq $Source }
    }
    
    return $events | Select-Object -Last $Count | Sort-Object Timestamp -Descending
}