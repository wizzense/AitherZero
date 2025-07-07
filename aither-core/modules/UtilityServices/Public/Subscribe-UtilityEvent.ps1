function Subscribe-UtilityEvent {
    <#
    .SYNOPSIS
        Subscribes to utility service events
    
    .DESCRIPTION
        Registers a handler to be called when specific events are published
    
    .PARAMETER EventType
        Type of event to subscribe to
    
    .PARAMETER Handler
        Script block to execute when the event occurs
    
    .EXAMPLE
        Subscribe-UtilityEvent -EventType "TestCompleted" -Handler { param($event) Write-Host "Test completed: $($event.Data.TestName)" }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventType,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )
    
    if (-not $script:ServiceEventSystem.Subscribers.ContainsKey($EventType)) {
        $script:ServiceEventSystem.Subscribers[$EventType] = @()
    }
    
    $script:ServiceEventSystem.Subscribers[$EventType] += $Handler
    Write-UtilityLog "📬 Subscribed to event: $EventType" -Level "INFO"
}