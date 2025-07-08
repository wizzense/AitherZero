function Submit-ModuleEvent {
    <#
    .SYNOPSIS
        Submits an event to the module communication system
    .DESCRIPTION
        Publishes an event that can be consumed by registered event handlers
    .PARAMETER EventName
        The name of the event to publish
    .PARAMETER EventData
        The data payload of the event
    .PARAMETER Source
        The source module or component publishing the event
    .PARAMETER Priority
        The priority level of the event (Low, Normal, High, Critical)
    .PARAMETER Persistent
        Whether the event should be stored in history
    .EXAMPLE
        Submit-ModuleEvent -EventName "UserLoggedIn" -EventData @{UserId=123; Timestamp=Get-Date}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,

        [Parameter()]
        [hashtable]$EventData = @{},

        [Parameter()]
        [string]$Source,

        [Parameter()]
        [ValidateSet('Low', 'Normal', 'High', 'Critical')]
        [string]$Priority = 'Normal',

        [Parameter()]
        [switch]$Persistent
    )

    try {
        # Determine source if not provided
        if (-not $Source) {
            $Source = if ($PSCmdlet.MyInvocation.ScriptName) { 
                Split-Path $PSCmdlet.MyInvocation.ScriptName -Leaf 
            } else { 
                'Interactive' 
            }
        }

        # Create event object
        $event = @{
            Id = [Guid]::NewGuid().ToString()
            Name = $EventName
            Data = $EventData
            Source = $Source
            Priority = $Priority
            Timestamp = Get-Date
            Persistent = $Persistent.IsPresent
        }

        # Add to event history if persistent or if history is enabled
        if ($Persistent.IsPresent -or $script:Configuration.MaxEventHistory -gt 0) {
            $script:MessageBus.EventHistory.Enqueue($event)
            
            # Trim history if it exceeds max size
            while ($script:MessageBus.EventHistory.Count -gt $script:Configuration.MaxEventHistory) {
                $script:MessageBus.EventHistory.TryDequeue([ref]$null) | Out-Null
            }
        }

        # Find and notify registered event handlers
        $handlerCount = 0
        $subscriptionKeys = $script:MessageBus.Subscriptions.Keys | Where-Object { $_ -like "*:$EventName" }
        
        foreach ($key in $subscriptionKeys) {
            if ($script:MessageBus.Subscriptions.TryGetValue($key, [ref]$subscription)) {
                try {
                    # Execute handler in background to avoid blocking
                    $handler = $subscription.Handler
                    Start-Job -ScriptBlock {
                        param($Handler, $Event)
                        try {
                            & $Handler $Event
                        } catch {
                            Write-Error "Event handler error: $_"
                        }
                    } -ArgumentList $handler, $event | Out-Null
                    
                    $handlerCount++
                } catch {
                    Write-CustomLog -Level 'ERROR' -Message "Failed to execute event handler for '$EventName': $_"
                }
            }
        }

        Write-CustomLog -Level 'INFO' -Message "Event '$EventName' published with ID '$($event.Id)' to $handlerCount handlers"

        return $event.Id
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to submit event '$EventName': $_"
        throw
    }
}