function Register-ModuleEventHandler {
    <#
    .SYNOPSIS
        Register a handler for module events
    .DESCRIPTION
        Simplified event handler registration wrapper around message subscription
    .PARAMETER EventName
        Event name to register handler for (supports wildcards)
    .PARAMETER Handler
        ScriptBlock to execute when event occurs
    .PARAMETER Channel
        Channel to listen on (default: 'Events')
    .EXAMPLE
        Register-ModuleEventHandler -EventName "Configuration*" -Handler {
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
    
    # Register handler for messages with event type
    $subscription = Register-ModuleMessageHandler `
        -Channel $Channel `
        -MessageType "Event:$EventName" `
        -Handler $messageHandler `
        -SubscriberModule $MyInvocation.MyCommand.Module.Name
    
    return $subscription
}