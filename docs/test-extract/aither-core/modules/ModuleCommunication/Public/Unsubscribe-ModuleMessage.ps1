function Unsubscribe-ModuleMessage {
    <#
    .SYNOPSIS
        Unsubscribe from module messages
    .DESCRIPTION
        Removes a message handler subscription
    .PARAMETER SubscriptionId
        The subscription ID to remove
    .PARAMETER Channel
        Channel to unsubscribe from (removes all subscriptions for the channel)
    .PARAMETER SubscriberModule
        Module to unsubscribe (removes all subscriptions for the module)
    .EXAMPLE
        Unsubscribe-ModuleMessage -SubscriptionId "12345678-1234-1234-1234-123456789012"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory, ParameterSetName = 'ByChannel')]
        [string]$Channel,
        
        [Parameter(Mandatory, ParameterSetName = 'ByModule')]
        [string]$SubscriberModule
    )
    
    try {
        $removedCount = 0
        
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                # Find and remove specific subscription
                $keysToRemove = @()
                foreach ($key in $script:MessageBus.Subscriptions.Keys) {
                    if ($key.EndsWith("|$SubscriptionId")) {
                        $keysToRemove += $key
                    }
                }
                
                foreach ($key in $keysToRemove) {
                    $subscription = $script:MessageBus.Subscriptions[$key]
                    if ($script:MessageBus.Subscriptions.TryRemove($key, [ref]$subscription)) {
                        $removedCount++
                        
                        # Update channel subscription count
                        if ($script:MessageBus.Channels.ContainsKey($subscription.Channel)) {
                            $script:MessageBus.Channels[$subscription.Channel].SubscriptionCount--
                        }
                        
                        Write-CustomLog -Level 'INFO' -Message "Subscription removed: $SubscriptionId"
                    }
                }
            }
            
            'ByChannel' {
                # Remove all subscriptions for channel
                $keysToRemove = @()
                foreach ($key in $script:MessageBus.Subscriptions.Keys) {
                    if ($key.StartsWith("$Channel|")) {
                        $keysToRemove += $key
                    }
                }
                
                foreach ($key in $keysToRemove) {
                    $subscription = $script:MessageBus.Subscriptions[$key]
                    if ($script:MessageBus.Subscriptions.TryRemove($key, [ref]$subscription)) {
                        $removedCount++
                    }
                }
                
                # Reset channel subscription count
                if ($script:MessageBus.Channels.ContainsKey($Channel)) {
                    $script:MessageBus.Channels[$Channel].SubscriptionCount = 0
                }
                
                Write-CustomLog -Level 'INFO' -Message "All subscriptions removed for channel: $Channel"
            }
            
            'ByModule' {
                # Remove all subscriptions for module
                $keysToRemove = @()
                foreach ($key in $script:MessageBus.Subscriptions.Keys) {
                    $subscription = $script:MessageBus.Subscriptions[$key]
                    if ($subscription.SubscriberModule -eq $SubscriberModule) {
                        $keysToRemove += $key
                    }
                }
                
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
                
                Write-CustomLog -Level 'INFO' -Message "All subscriptions removed for module: $SubscriberModule"
            }
        }
        
        return @{
            RemovedCount = $removedCount
            Success = $removedCount -gt 0
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to unsubscribe: $_"
        throw
    }
}