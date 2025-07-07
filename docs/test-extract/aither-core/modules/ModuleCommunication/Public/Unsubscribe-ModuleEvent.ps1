function Unsubscribe-ModuleEvent {
    <#
    .SYNOPSIS
        Unsubscribe from module events
    .DESCRIPTION
        Removes an event handler subscription (wrapper around message unsubscription)
    .PARAMETER SubscriptionId
        The subscription ID to remove
    .PARAMETER EventName
        Event name to unsubscribe from (removes all subscriptions for the event)
    .PARAMETER Channel
        Channel to unsubscribe from (default: 'Events')
    .EXAMPLE
        Unsubscribe-ModuleEvent -SubscriptionId "12345678-1234-1234-1234-123456789012"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory, ParameterSetName = 'ByEvent')]
        [string]$EventName,
        
        [Parameter()]
        [string]$Channel = 'Events'
    )
    
    try {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                # Remove by subscription ID
                $result = Unsubscribe-ModuleMessage -SubscriptionId $SubscriptionId
                return $result
            }
            
            'ByEvent' {
                # Remove all subscriptions for this event
                $removedCount = 0
                $keysToRemove = @()
                
                # Find all subscriptions for this event
                foreach ($key in $script:MessageBus.Subscriptions.Keys) {
                    if ($key.StartsWith("$Channel|")) {
                        $subscription = $script:MessageBus.Subscriptions[$key]
                        if ($subscription.MessageType -eq "Event:$EventName" -or 
                            ($EventName.Contains('*') -and $subscription.MessageType -like "Event:$EventName")) {
                            $keysToRemove += $key
                        }
                    }
                }
                
                # Remove subscriptions
                foreach ($key in $keysToRemove) {
                    $subscription = $script:MessageBus.Subscriptions[$key]
                    if ($script:MessageBus.Subscriptions.TryRemove($key, [ref]$subscription)) {
                        $removedCount++
                        
                        # Update channel subscription count
                        if ($script:MessageBus.Channels.ContainsKey($subscription.Channel)) {
                            $script:MessageBus.Channels[$subscription.Channel].SubscriptionCount--
                        }
                    }
                }
                
                Write-CustomLog -Level 'INFO' -Message "Removed $removedCount event subscriptions for: $EventName"
                
                return @{
                    RemovedCount = $removedCount
                    Success = $removedCount -gt 0
                }
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to unsubscribe from event: $_"
        throw
    }
}