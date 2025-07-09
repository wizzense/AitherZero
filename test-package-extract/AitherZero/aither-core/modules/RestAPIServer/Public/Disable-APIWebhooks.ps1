<#
.SYNOPSIS
    Disables webhook functionality in the API server.

.DESCRIPTION
    Disable-APIWebhooks stops all webhook delivery and optionally removes
    all webhook subscriptions and clears delivery history.

.PARAMETER RemoveSubscriptions
    Remove all existing webhook subscriptions.

.PARAMETER ClearHistory
    Clear all webhook delivery history.

.PARAMETER Force
    Force disable without confirmation prompts.

.PARAMETER Reason
    Reason for disabling webhooks (for logging).

.EXAMPLE
    Disable-APIWebhooks
    Disables webhooks while preserving subscriptions and history.

.EXAMPLE
    Disable-APIWebhooks -RemoveSubscriptions -ClearHistory -Force -Reason "Maintenance"
    Completely disables webhooks and cleans up all data.

.EXAMPLE
    Disable-APIWebhooks -RemoveSubscriptions -Reason "Security concern"
    Disables webhooks and removes subscriptions with logging.
#>
function Disable-APIWebhooks {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$RemoveSubscriptions,

        [Parameter()]
        [switch]$ClearHistory,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [string]$Reason = "Manual disable request"
    )

    begin {
        Write-CustomLog -Message "Disabling API webhooks: $Reason" -Level "INFO"
    }

    process {
        try {
            # Check current webhook status
            if (-not $script:APIConfiguration.WebhookConfig.Enabled) {
                Write-CustomLog -Message "Webhooks are already disabled" -Level "INFO"
                return @{
                    Success = $true
                    Message = "Webhooks were already disabled"
                    AlreadyDisabled = $true
                }
            }

            $stats = @{
                SubscriptionCount = $script:WebhookSubscriptions.Count
                HistoryCount = $script:APIConfiguration.WebhookConfig.DeliveryHistory.Count
                DisabledAt = Get-Date
                DisabledBy = $env:USERNAME
                Reason = $Reason
            }

            # Confirm destructive operations if not forced
            if (($RemoveSubscriptions -or $ClearHistory) -and -not $Force) {
                $actions = @()
                if ($RemoveSubscriptions) { $actions += "remove $($stats.SubscriptionCount) subscriptions" }
                if ($ClearHistory) { $actions += "clear $($stats.HistoryCount) history entries" }

                $actionText = $actions -join " and "
                $confirmation = Read-Host "This will disable webhooks and $actionText. Continue? (y/N)"
                if ($confirmation -notmatch '^[Yy]') {
                    return @{
                        Success = $false
                        Message = "Operation cancelled by user"
                    }
                }
            }

            # Send final notification before disabling
            try {
                Send-WebhookNotification -Event "webhook.system.disabled" -Data @{
                    reason = $Reason
                    disabledBy = $env:USERNAME
                    disabledAt = Get-Date
                    willRemoveSubscriptions = $RemoveSubscriptions.IsPresent
                    willClearHistory = $ClearHistory.IsPresent
                    subscriptionCount = $stats.SubscriptionCount
                    historyCount = $stats.HistoryCount
                } -Priority High -Force
            } catch {
                Write-CustomLog -Message "Failed to send disable notification: $($_.Exception.Message)" -Level "WARNING"
            }

            # Disable webhooks
            $script:APIConfiguration.WebhookConfig.Enabled = $false
            $script:APIConfiguration.WebhookConfig.DisabledAt = Get-Date
            $script:APIConfiguration.WebhookConfig.DisabledBy = $env:USERNAME
            $script:APIConfiguration.WebhookConfig.DisableReason = $Reason

            $actions = @("Webhooks disabled")

            # Remove subscriptions if requested
            if ($RemoveSubscriptions) {
                $removedSubscriptions = @()
                foreach ($subscriptionId in $script:WebhookSubscriptions.Keys) {
                    $subscription = $script:WebhookSubscriptions[$subscriptionId]
                    $removedSubscriptions += @{
                        SubscriptionId = $subscriptionId
                        Url = $subscription.Url
                        Events = $subscription.Events
                        Description = $subscription.Description
                        DeliveryStats = $subscription.DeliveryStats.Clone()
                    }
                }

                $script:WebhookSubscriptions.Clear()
                $actions += "Removed $($removedSubscriptions.Count) subscriptions"
                $stats.RemovedSubscriptions = $removedSubscriptions

                Write-CustomLog -Message "Removed all $($removedSubscriptions.Count) webhook subscriptions" -Level "INFO"
            }

            # Clear history if requested
            if ($ClearHistory) {
                $clearedCount = $script:APIConfiguration.WebhookConfig.DeliveryHistory.Count
                $script:APIConfiguration.WebhookConfig.DeliveryHistory = @()
                $actions += "Cleared $clearedCount history entries"
                $stats.ClearedHistoryCount = $clearedCount

                Write-CustomLog -Message "Cleared $clearedCount webhook delivery history entries" -Level "INFO"
            }

            # Log the disable action
            $script:APIConfiguration.WebhookConfig.DisableHistory = $script:APIConfiguration.WebhookConfig.DisableHistory + @($stats)

            # Maintain disable history size limit
            if ($script:APIConfiguration.WebhookConfig.DisableHistory.Count -gt 50) {
                $script:APIConfiguration.WebhookConfig.DisableHistory = $script:APIConfiguration.WebhookConfig.DisableHistory | Select-Object -Last 50
            }

            $resultMessage = $actions -join "; "
            Write-CustomLog -Message "Webhook disable completed: $resultMessage" -Level "SUCCESS"

            return @{
                Success = $true
                Message = $resultMessage
                DisabledAt = $stats.DisabledAt
                DisabledBy = $stats.DisabledBy
                Reason = $Reason
                SubscriptionsRemoved = $RemoveSubscriptions.IsPresent
                HistoryCleared = $ClearHistory.IsPresent
                Stats = $stats
                RemainingSubscriptions = $script:WebhookSubscriptions.Count
                RemainingHistory = $script:APIConfiguration.WebhookConfig.DeliveryHistory.Count
            }

        } catch {
            $errorMessage = "Failed to disable webhooks: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                Reason = $Reason
            }
        }
    }
}

Export-ModuleMember -Function Disable-APIWebhooks
