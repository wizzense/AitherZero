<#
.SYNOPSIS
    Sends a webhook notification to all subscribed endpoints.

.DESCRIPTION
    Send-WebhookNotification delivers event notifications to all webhook
    subscriptions that match the specified event type. Supports retry logic,
    signature validation, and delivery tracking.

.PARAMETER Event
    The event type to notify about.

.PARAMETER Data
    The event data to include in the notification payload.

.PARAMETER Source
    The source system/module generating the event.

.PARAMETER Priority
    The priority level of the notification (Low, Normal, High).

.PARAMETER CustomHeaders
    Additional headers to include in the webhook request.

.PARAMETER RetryAttempts
    Number of retry attempts for failed deliveries.

.PARAMETER Force
    Force delivery even if webhooks are disabled.

.EXAMPLE
    Send-WebhookNotification -Event "test.completed" -Data @{
        TestName = "Integration Test"
        Result = "Success"
        Duration = 150
    }
    Sends a test completion notification.

.EXAMPLE
    Send-WebhookNotification -Event "deployment.finished" -Data @{
        Environment = "Production"
        Version = "1.2.3"
        Status = "Success"
    } -Priority High
    Sends a high-priority deployment notification.

.EXAMPLE
    Send-WebhookNotification -Event "error.occurred" -Data @{
        Module = "LabRunner"
        Error = "Connection timeout"
        Timestamp = Get-Date
    } -CustomHeaders @{"X-Alert-Level" = "Critical"}
    Sends an error notification with custom headers.
#>
function Send-WebhookNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Event,

        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter()]
        [string]$Source = 'AitherZero-RestAPI',

        [Parameter()]
        [ValidateSet('Low', 'Normal', 'High')]
        [string]$Priority = 'Normal',

        [Parameter()]
        [hashtable]$CustomHeaders = @{},

        [Parameter()]
        [ValidateRange(0, 10)]
        [int]$RetryAttempts = 3,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-CustomLog -Message "Sending webhook notification for event: $Event" -Level "INFO"
    }

    process {
        try {
            # Check if webhooks are enabled
            if (-not $script:APIConfiguration.WebhookConfig.Enabled -and -not $Force) {
                Write-CustomLog -Message "Webhooks not enabled, skipping notification for event: $Event" -Level "DEBUG"
                return @{
                    Success = $true
                    Message = "Webhooks disabled, notification skipped"
                    Event = $Event
                    DeliveryCount = 0
                }
            }

            # Get matching subscriptions
            $matchingSubscriptions = @()
            foreach ($subscriptionId in $script:WebhookSubscriptions.Keys) {
                $subscription = $script:WebhookSubscriptions[$subscriptionId]

                # Check if subscription is active
                if (-not $subscription.IsActive) {
                    continue
                }

                # Check if event matches
                if ($subscription.Events -contains "*" -or $subscription.Events -contains $Event) {
                    $matchingSubscriptions += @{
                        Id = $subscriptionId
                        Subscription = $subscription
                    }
                }
            }

            if ($matchingSubscriptions.Count -eq 0) {
                Write-CustomLog -Message "No webhook subscriptions for event: $Event" -Level "DEBUG"
                return @{
                    Success = $true
                    Message = "No matching subscriptions"
                    Event = $Event
                    DeliveryCount = 0
                }
            }

            # Create notification payload
            $payload = @{
                event = $Event
                timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                data = $Data
                source = $Source
                priority = $Priority
                version = "1.0.0"
                delivery_id = [System.Guid]::NewGuid().ToString()
            }

            $payloadJson = $payload | ConvertTo-Json -Depth 10
            $deliveryResults = @()

            # Deliver to each subscription
            foreach ($sub in $matchingSubscriptions) {
                $subscription = $sub.Subscription
                $subscriptionId = $sub.Id

                # Track delivery attempt
                $subscription.DeliveryStats.Attempted++
                $subscription.DeliveryStats.LastAttempt = Get-Date

                $deliverySuccess = $false
                $lastError = $null

                # Retry logic
                for ($attempt = 1; $attempt -le ($RetryAttempts + 1); $attempt++) {
                    try {
                        $request = [System.Net.WebRequest]::Create($subscription.Url)
                        $request.Method = "POST"
                        $request.ContentType = "application/json"
                        $request.Timeout = $subscription.Configuration.Timeout * 1000
                        $request.UserAgent = "AitherZero-Webhook/1.0"

                        # Add custom headers
                        foreach ($header in $CustomHeaders.Keys) {
                            $request.Headers.Add($header, $CustomHeaders[$header])
                        }

                        # Add standard webhook headers
                        $request.Headers.Add("X-Event-Type", $Event)
                        $request.Headers.Add("X-Delivery-Id", $payload.delivery_id)
                        $request.Headers.Add("X-Webhook-Id", $subscriptionId)
                        $request.Headers.Add("X-Priority", $Priority)

                        # Add signature if secret is configured
                        if ($subscription.Secret) {
                            $hmac = New-Object System.Security.Cryptography.HMACSHA256
                            $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($subscription.Secret)
                            $signature = [System.Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payloadJson)))
                            $request.Headers.Add("X-Webhook-Signature", "sha256=$signature")
                        }

                        # Write request body
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
                        $request.ContentLength = $bytes.Length

                        $requestStream = $request.GetRequestStream()
                        $requestStream.Write($bytes, 0, $bytes.Length)
                        $requestStream.Close()

                        # Send request
                        $response = $request.GetResponse()
                        $statusCode = $response.StatusCode
                        $response.Close()

                        # Success
                        $deliverySuccess = $true
                        $subscription.DeliveryStats.Delivered++
                        $subscription.DeliveryStats.LastSuccess = Get-Date

                        Write-CustomLog -Message "Webhook delivered successfully: $Event to $($subscription.Url)" -Level "DEBUG"
                        break

                    } catch {
                        $lastError = $_.Exception.Message
                        Write-CustomLog -Message "Webhook delivery attempt $attempt failed: $lastError" -Level "WARNING"

                        # Exponential backoff before retry
                        if ($attempt -lt ($RetryAttempts + 1)) {
                            $backoffMs = [math]::Min(1000 * [math]::Pow(2, $attempt - 1), 30000)
                            Start-Sleep -Milliseconds $backoffMs
                        }
                    }
                }

                # Record delivery result
                $deliveryResult = @{
                    SubscriptionId = $subscriptionId
                    Url = $subscription.Url
                    Success = $deliverySuccess
                    Attempts = $attempt
                    Error = $lastError
                    DeliveredAt = if ($deliverySuccess) { Get-Date } else { $null }
                }

                $deliveryResults += $deliveryResult

                # Update subscription stats
                if (-not $deliverySuccess) {
                    $subscription.DeliveryStats.Failed++
                    $subscription.DeliveryStats.LastError = $lastError
                }
            }

            # Add to delivery history
            $historyEntry = @{
                Event = $Event
                Timestamp = Get-Date
                SubscriptionCount = $matchingSubscriptions.Count
                SuccessfulDeliveries = ($deliveryResults | Where-Object { $_.Success }).Count
                FailedDeliveries = ($deliveryResults | Where-Object { -not $_.Success }).Count
                DeliveryResults = $deliveryResults
                Payload = $payload
            }

            $script:APIConfiguration.WebhookConfig.DeliveryHistory += $historyEntry

            # Maintain history size limit
            if ($script:APIConfiguration.WebhookConfig.DeliveryHistory.Count -gt 100) {
                $script:APIConfiguration.WebhookConfig.DeliveryHistory = $script:APIConfiguration.WebhookConfig.DeliveryHistory | Select-Object -Last 100
            }

            $successCount = $historyEntry.SuccessfulDeliveries
            $totalCount = $historyEntry.SubscriptionCount

            $resultMessage = if ($successCount -eq $totalCount) {
                "Successfully delivered to all $totalCount subscriptions"
            } else {
                "Delivered to $successCount out of $totalCount subscriptions"
            }

            Write-CustomLog -Message "Webhook notification completed: $resultMessage" -Level $(if ($successCount -eq $totalCount) { "SUCCESS" } else { "WARNING" })

            return @{
                Success = $successCount -gt 0
                Message = $resultMessage
                Event = $Event
                DeliveryCount = $totalCount
                SuccessfulDeliveries = $successCount
                FailedDeliveries = $historyEntry.FailedDeliveries
                DeliveryResults = $deliveryResults
                DeliveryId = $payload.delivery_id
            }

        } catch {
            $errorMessage = "Failed to send webhook notification: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                Event = $Event
            }
        }
    }
}

Export-ModuleMember -Function Send-WebhookNotification
