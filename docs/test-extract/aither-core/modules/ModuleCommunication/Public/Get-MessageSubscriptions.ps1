function Get-MessageSubscriptions {
    <#
    .SYNOPSIS
        Get current message subscriptions
    .DESCRIPTION
        Returns information about active message subscriptions
    .PARAMETER Channel
        Filter by channel
    .PARAMETER SubscriberModule
        Filter by subscriber module
    .PARAMETER IncludeStatistics
        Include subscription statistics
    .EXAMPLE
        Get-MessageSubscriptions -Channel "Configuration" -IncludeStatistics
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Channel,
        
        [Parameter()]
        [string]$SubscriberModule,
        
        [Parameter()]
        [switch]$IncludeStatistics
    )
    
    try {
        $subscriptions = @()
        
        foreach ($key in $script:MessageBus.Subscriptions.Keys) {
            $subscription = $script:MessageBus.Subscriptions[$key]
            
            # Apply filters
            if ($Channel -and $subscription.Channel -ne $Channel) {
                continue
            }
            if ($SubscriberModule -and $subscription.SubscriberModule -ne $SubscriberModule) {
                continue
            }
            
            $subscriptionInfo = @{
                Id = $subscription.Id
                Channel = $subscription.Channel
                MessageType = $subscription.MessageType
                SubscriberModule = $subscription.SubscriberModule
                CreatedAt = $subscription.CreatedAt
                RunAsync = $subscription.RunAsync
                HasFilter = $null -ne $subscription.Filter
            }
            
            if ($IncludeStatistics) {
                $subscriptionInfo.Statistics = @{
                    MessageCount = $subscription.MessageCount
                    LastMessage = $subscription.LastMessage
                    ErrorCount = $subscription.Errors.Count
                    LastError = if ($subscription.Errors.Count -gt 0) { 
                        $subscription.Errors[-1].Timestamp 
                    } else { 
                        $null 
                    }
                }
            }
            
            $subscriptions += $subscriptionInfo
        }
        
        return $subscriptions
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get subscriptions: $_"
        throw
    }
}