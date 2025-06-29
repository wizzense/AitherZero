function Subscribe-ModuleEvent {
    <#
    .SYNOPSIS
        Subscribe to module events
    .DESCRIPTION
        Simplified event subscription wrapper around message subscription
    .PARAMETER EventName
        Event name to subscribe to (supports wildcards)
    .PARAMETER Handler
        ScriptBlock to execute when event occurs
    .PARAMETER Channel
        Channel to listen on (default: 'Events')
    .EXAMPLE
        Subscribe-ModuleEvent -EventName "Configuration*" -Handler {
            param($Event)
            Write-Host "Configuration event: $($Event.Name)"
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [scriptblock]$Handler,
        
        [Parameter()]
        [string]$Channel = 'Events'
    )
    
    # Convert event handler to message handler
    $messageHandler = {
        param($Message)
        # Extract event from message data
        $event = $Message.Data
        & $Handler $event
    }.GetNewClosure()
    
    # Subscribe to messages with event type
    $subscription = Subscribe-ModuleMessage `
        -Channel $Channel `
        -MessageType "Event:$EventName" `
        -Handler $messageHandler `
        -SubscriberModule $MyInvocation.MyCommand.Module.Name
    
    return $subscription
}