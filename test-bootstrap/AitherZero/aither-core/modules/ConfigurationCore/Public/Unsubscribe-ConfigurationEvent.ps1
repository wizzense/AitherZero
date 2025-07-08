function Unsubscribe-ConfigurationEvent {
    <#
    .SYNOPSIS
        Unsubscribe from configuration events
    .DESCRIPTION
        Removes a configuration event subscription
    .PARAMETER SubscriptionId
        ID of the subscription to remove
    .PARAMETER EventName
        Name of the event to unsubscribe from (if SubscriptionId not provided)
    .PARAMETER ModuleName
        Name of the module to unsubscribe (if SubscriptionId not provided)
    .EXAMPLE
        Unsubscribe-ConfigurationEvent -SubscriptionId "12345678-1234-1234-1234-123456789012"
    .EXAMPLE
        Unsubscribe-ConfigurationEvent -EventName "ModuleConfigurationChanged" -ModuleName "LabRunner"
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory, ParameterSetName = 'ByEventAndModule')]
        [string]$EventName,
        
        [Parameter(Mandatory, ParameterSetName = 'ByEventAndModule')]
        [string]$ModuleName
    )
    
    try {
        if (-not $script:ConfigurationStore.EventSystem -or 
            -not $script:ConfigurationStore.EventSystem.Subscriptions) {
            Write-CustomLog -Level 'WARNING' -Message "No event subscriptions found"
            return $false
        }
        
        $removed = $false
        $removedSubscriptions = @()
        
        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            # Remove by subscription ID
            foreach ($eventName in $script:ConfigurationStore.EventSystem.Subscriptions.Keys) {
                $subscriptions = $script:ConfigurationStore.EventSystem.Subscriptions[$eventName]
                $newSubscriptions = @()
                
                foreach ($subscription in $subscriptions) {
                    if ($subscription.Id -eq $SubscriptionId) {
                        $removedSubscriptions += @{
                            EventName = $eventName
                            ModuleName = $subscription.ModuleName
                            SubscriptionId = $subscription.Id
                        }
                        $removed = $true
                    } else {
                        $newSubscriptions += $subscription
                    }
                }
                
                $script:ConfigurationStore.EventSystem.Subscriptions[$eventName] = $newSubscriptions
            }
        } else {
            # Remove by event name and module name
            if ($script:ConfigurationStore.EventSystem.Subscriptions.ContainsKey($EventName)) {
                $subscriptions = $script:ConfigurationStore.EventSystem.Subscriptions[$EventName]
                $newSubscriptions = @()
                
                foreach ($subscription in $subscriptions) {
                    if ($subscription.ModuleName -eq $ModuleName) {
                        $removedSubscriptions += @{
                            EventName = $EventName
                            ModuleName = $subscription.ModuleName
                            SubscriptionId = $subscription.Id
                        }
                        $removed = $true
                    } else {
                        $newSubscriptions += $subscription
                    }
                }
                
                $script:ConfigurationStore.EventSystem.Subscriptions[$EventName] = $newSubscriptions
            }
        }
        
        if ($removed) {
            foreach ($removedSub in $removedSubscriptions) {
                Write-CustomLog -Level 'INFO' -Message "Unsubscribed module '$($removedSub.ModuleName)' from event '$($removedSub.EventName)'"
                
                # Publish unsubscription event
                if (Get-Command 'Publish-TestEvent' -ErrorAction SilentlyContinue) {
                    Publish-TestEvent -EventName 'ConfigurationEventUnsubscribed' -EventData @{
                        EventName = $removedSub.EventName
                        ModuleName = $removedSub.ModuleName
                        SubscriptionId = $removedSub.SubscriptionId
                        Timestamp = Get-Date
                    }
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "Successfully removed $($removedSubscriptions.Count) subscription(s)"
        } else {
            Write-CustomLog -Level 'WARNING' -Message "No matching subscriptions found to remove"
        }
        
        return $removed
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to unsubscribe from configuration event: $_"
        throw
    }
}