function Clear-UtilityEvents {
    <#
    .SYNOPSIS
        Clears utility service event history
    
    .DESCRIPTION
        Removes events from the event history, optionally filtered by type
    
    .PARAMETER EventType
        Clear only events of this type
    
    .PARAMETER Force
        Force clearing all events without confirmation
    
    .EXAMPLE
        Clear-UtilityEvents -EventType "TestEvent"
        
        Clear only TestEvent events
    #>
    [CmdletBinding()]
    param(
        [string]$EventType,
        [switch]$Force
    )
    
    if ($EventType) {
        $script:ServiceEventSystem.EventHistory = $script:ServiceEventSystem.EventHistory | Where-Object { 
            $_.EventType -ne $EventType 
        }
        Write-UtilityLog "Cleared events of type: $EventType" -Level "INFO"
    } else {
        if ($Force) {
            $script:ServiceEventSystem.EventHistory = @()
            Write-UtilityLog "Cleared all event history" -Level "INFO"
        } else {
            throw "Use -Force to clear all events"
        }
    }
}