<#
.SYNOPSIS
    Gets all webhook subscriptions registered with the API server.

.DESCRIPTION
    Get-WebhookSubscriptions returns information about all webhook
    subscriptions including URLs, events, delivery statistics, and
    subscription status.

.PARAMETER SubscriptionId
    Get details for a specific subscription ID.

.PARAMETER IncludeStatistics
    Include delivery statistics in the response.

.PARAMETER IncludeInactive
    Include inactive subscriptions in the results.

.EXAMPLE
    Get-WebhookSubscriptions
    Gets all active webhook subscriptions.

.EXAMPLE
    Get-WebhookSubscriptions -IncludeStatistics -IncludeInactive
    Gets all subscriptions with detailed statistics.

.EXAMPLE
    Get-WebhookSubscriptions -SubscriptionId "12345678-1234-1234-1234-123456789012"
    Gets details for a specific subscription.
#>
function Get-WebhookSubscriptions {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$SubscriptionId,
        
        [Parameter()]
        [switch]$IncludeStatistics,
        
        [Parameter()]
        [switch]$IncludeInactive
    )

    begin {
        Write-CustomLog -Message "Retrieving webhook subscriptions" -Level "DEBUG"
    }

    process {
        try {
            # Check if webhooks are enabled
            $webhooksEnabled = $script:APIConfiguration.WebhookConfig.Enabled -eq $true
            
            $result = @{
                Success = $true
                WebhooksEnabled = $webhooksEnabled
                TotalSubscriptions = $script:WebhookSubscriptions.Count
                Subscriptions = @()
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
            
            # Return empty result if webhooks not enabled
            if (-not $webhooksEnabled) {
                $result.Message = "Webhooks are not currently enabled"
                return $result
            }
            
            # Get specific subscription
            if ($SubscriptionId) {
                if ($script:WebhookSubscriptions.ContainsKey($SubscriptionId)) {
                    $subscription = $script:WebhookSubscriptions[$SubscriptionId]
                    
                    $subDetails = @{
                        Id = $SubscriptionId
                        Url = $subscription.Url
                        Events = $subscription.Events
                        IsActive = $subscription.IsActive
                        CreatedAt = $subscription.CreatedAt
                        HasSecret = -not [string]::IsNullOrEmpty($subscription.Secret)
                    }
                    
                    if ($IncludeStatistics) {
                        $subDetails.DeliveryStats = $subscription.DeliveryStats
                        $subDetails.SuccessRate = if ($subscription.DeliveryStats.Attempted -gt 0) {
                            [math]::Round(($subscription.DeliveryStats.Delivered / $subscription.DeliveryStats.Attempted) * 100, 2)
                        } else { 0 }
                    }
                    
                    $result.Subscriptions += $subDetails
                } else {
                    $result.Success = $false
                    $result.Error = "Subscription not found: $SubscriptionId"
                    return $result
                }
            } else {
                # Get all subscriptions
                foreach ($subId in $script:WebhookSubscriptions.Keys) {
                    $subscription = $script:WebhookSubscriptions[$subId]
                    
                    # Filter inactive if not requested
                    if (-not $IncludeInactive -and -not $subscription.IsActive) {
                        continue
                    }
                    
                    $subDetails = @{
                        Id = $subId
                        Url = $subscription.Url
                        Events = $subscription.Events
                        IsActive = $subscription.IsActive
                        CreatedAt = $subscription.CreatedAt
                        HasSecret = -not [string]::IsNullOrEmpty($subscription.Secret)
                    }
                    
                    if ($IncludeStatistics) {
                        $subDetails.DeliveryStats = $subscription.DeliveryStats
                        $subDetails.SuccessRate = if ($subscription.DeliveryStats.Attempted -gt 0) {
                            [math]::Round(($subscription.DeliveryStats.Delivered / $subscription.DeliveryStats.Attempted) * 100, 2)
                        } else { 0 }
                    }
                    
                    $result.Subscriptions += $subDetails
                }
            }
            
            # Add webhook configuration if statistics requested
            if ($IncludeStatistics) {
                $result.WebhookConfiguration = @{
                    Events = $script:APIConfiguration.WebhookConfig.Events
                    RetryAttempts = $script:APIConfiguration.WebhookConfig.RetryAttempts
                    Timeout = $script:APIConfiguration.WebhookConfig.Timeout
                    EnabledAt = $script:APIConfiguration.WebhookConfig.EnabledAt
                }
                
                $result.GlobalStatistics = $script:APIConfiguration.WebhookConfig.DeliveryStats
            }
            
            # Update counts
            $result.ActiveSubscriptions = ($result.Subscriptions | Where-Object { $_.IsActive }).Count
            $result.InactiveSubscriptions = ($result.Subscriptions | Where-Object { -not $_.IsActive }).Count
            
            return $result

        } catch {
            $errorMessage = "Failed to get webhook subscriptions: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
        }
    }
}

Export-ModuleMember -Function Get-WebhookSubscriptions