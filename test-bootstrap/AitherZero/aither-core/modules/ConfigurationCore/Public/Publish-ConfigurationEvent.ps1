function Publish-ConfigurationEvent {
    <#
    .SYNOPSIS
        Publish a configuration event to all subscribers
    .DESCRIPTION
        Publishes configuration events to notify subscribed modules of changes
    .PARAMETER EventName
        Name of the configuration event to publish
    .PARAMETER EventData
        Data associated with the event
    .PARAMETER SourceModule
        Module that is publishing the event
    .EXAMPLE
        Publish-ConfigurationEvent -EventName "ModuleConfigurationChanged" -EventData @{
            ModuleName = "LabRunner"
            Changes = @("MaxConcurrentJobs")
            OldValues = @{ MaxConcurrentJobs = 5 }
            NewValues = @{ MaxConcurrentJobs = 10 }
        } -SourceModule "ConfigurationCore"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EventName,
        
        [Parameter(Mandatory)]
        [hashtable]$EventData,
        
        [Parameter()]
        [string]$SourceModule = "ConfigurationCore"
    )
    
    try {
        # Initialize event system if not already done
        if (-not $script:ConfigurationStore.EventSystem) {
            $script:ConfigurationStore.EventSystem = @{
                Subscriptions = @{}
                EventHistory = @()
                MaxHistorySize = 1000
            }
        }
        
        # Create event record
        $eventRecord = @{
            EventName = $EventName
            EventData = $EventData
            SourceModule = $SourceModule
            PublishedAt = Get-Date
            Id = [System.Guid]::NewGuid().ToString()
            DeliveryResults = @()
        }
        
        Write-CustomLog -Level 'INFO' -Message "Publishing configuration event '$EventName' from module '$SourceModule'"
        
        # Get subscribers for this event
        $subscribers = $script:ConfigurationStore.EventSystem.Subscriptions[$EventName]
        
        if ($subscribers -and $subscribers.Count -gt 0) {
            Write-CustomLog -Level 'INFO' -Message "Delivering event to $($subscribers.Count) subscribers"
            
            foreach ($subscription in $subscribers) {
                try {
                    # Check if event matches filter
                    $shouldDeliver = $true
                    if ($subscription.Filter.Count -gt 0) {
                        foreach ($filterKey in $subscription.Filter.Keys) {
                            if ($EventData[$filterKey] -ne $subscription.Filter[$filterKey]) {
                                $shouldDeliver = $false
                                break
                            }
                        }
                    }
                    
                    if ($shouldDeliver) {
                        # Execute subscription action
                        $deliveryStart = Get-Date
                        & $subscription.Action $EventData
                        $deliveryEnd = Get-Date
                        $duration = ($deliveryEnd - $deliveryStart).TotalMilliseconds
                        
                        $eventRecord.DeliveryResults += @{
                            SubscriptionId = $subscription.Id
                            ModuleName = $subscription.ModuleName
                            Success = $true
                            Duration = $duration
                            DeliveredAt = $deliveryEnd
                        }
                        
                        Write-CustomLog -Level 'DEBUG' -Message "Event delivered to module '$($subscription.ModuleName)' in ${duration}ms"
                    } else {
                        $eventRecord.DeliveryResults += @{
                            SubscriptionId = $subscription.Id
                            ModuleName = $subscription.ModuleName
                            Success = $false
                            Reason = "Filtered out"
                            DeliveredAt = Get-Date
                        }
                        
                        Write-CustomLog -Level 'DEBUG' -Message "Event filtered out for module '$($subscription.ModuleName)'"
                    }
                    
                } catch {
                    $eventRecord.DeliveryResults += @{
                        SubscriptionId = $subscription.Id
                        ModuleName = $subscription.ModuleName
                        Success = $false
                        Error = $_.Exception.Message
                        DeliveredAt = Get-Date
                    }
                    
                    Write-CustomLog -Level 'WARNING' -Message "Failed to deliver event to module '$($subscription.ModuleName)': $_"
                }
            }
        } else {
            Write-CustomLog -Level 'DEBUG' -Message "No subscribers found for event '$EventName'"
        }
        
        # Add to event history
        $script:ConfigurationStore.EventSystem.EventHistory += $eventRecord
        
        # Trim history if too large
        if ($script:ConfigurationStore.EventSystem.EventHistory.Count -gt $script:ConfigurationStore.EventSystem.MaxHistorySize) {
            $script:ConfigurationStore.EventSystem.EventHistory = $script:ConfigurationStore.EventSystem.EventHistory | 
                Select-Object -Last $script:ConfigurationStore.EventSystem.MaxHistorySize
        }
        
        Write-CustomLog -Level 'SUCCESS' -Message "Configuration event '$EventName' published successfully"
        
        return $eventRecord.Id
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to publish configuration event: $_"
        throw
    }
}