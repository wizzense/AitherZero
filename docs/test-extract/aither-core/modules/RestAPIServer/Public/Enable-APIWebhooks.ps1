<#
.SYNOPSIS
    Enables webhook functionality for the AitherZero REST API server.

.DESCRIPTION
    Enable-APIWebhooks activates webhook support, allowing external systems
    to subscribe to events and receive HTTP notifications when specific
    actions occur within AitherZero.

.PARAMETER WebhookURL
    Base URL for webhook notifications (used for testing).

.PARAMETER Events
    Array of event types to enable for webhook notifications.

.PARAMETER SecretKey
    Secret key for webhook payload signing (optional).

.PARAMETER RetryAttempts
    Number of retry attempts for failed webhook deliveries. Default is 3.

.PARAMETER Timeout
    Timeout for webhook HTTP requests in seconds. Default is 30.

.EXAMPLE
    Enable-APIWebhooks
    Enables webhook functionality with default settings.

.EXAMPLE
    Enable-APIWebhooks -Events @("module.loaded", "test.completed", "deployment.finished")
    Enables webhooks for specific event types.

.EXAMPLE
    Enable-APIWebhooks -SecretKey "webhook-secret-123" -RetryAttempts 5
    Enables webhooks with custom secret and retry configuration.
#>
function Enable-APIWebhooks {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$WebhookURL,
        
        [Parameter()]
        [string[]]$Events = @(
            "api.started",
            "api.stopped", 
            "module.loaded",
            "module.error",
            "test.started",
            "test.completed",
            "deployment.started",
            "deployment.completed",
            "backup.started",
            "backup.completed",
            "error.occurred"
        ),
        
        [Parameter()]
        [string]$SecretKey,
        
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$RetryAttempts = 3,
        
        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$Timeout = 30
    )

    begin {
        Write-CustomLog -Message "Enabling API webhook functionality" -Level "INFO"
    }

    process {
        try {
            # Initialize webhook configuration
            $webhookConfig = @{
                Enabled = $true
                Events = $Events
                SecretKey = $SecretKey
                RetryAttempts = $RetryAttempts
                Timeout = $Timeout
                EnabledAt = Get-Date
                DeliveryStats = @{
                    TotalSent = 0
                    TotalDelivered = 0
                    TotalFailed = 0
                    LastDelivery = $null
                }
            }
            
            # Store webhook configuration
            $script:APIConfiguration.WebhookConfig = $webhookConfig
            
            # Initialize webhook subscriptions if not already done
            if (-not $script:WebhookSubscriptions) {
                $script:WebhookSubscriptions = @{}
            }
            
            # Add test subscription if WebhookURL provided
            if ($WebhookURL) {
                $testSubscription = @{
                    Url = $WebhookURL
                    Events = $Events
                    Secret = $SecretKey
                    CreatedAt = Get-Date
                    IsActive = $true
                    DeliveryStats = @{
                        Attempted = 0
                        Delivered = 0
                        Failed = 0
                        LastAttempt = $null
                        LastSuccess = $null
                    }
                }
                
                $subscriptionId = [System.Guid]::NewGuid().ToString()
                $script:WebhookSubscriptions[$subscriptionId] = $testSubscription
                
                Write-CustomLog -Message "Added test webhook subscription: $WebhookURL" -Level "INFO"
            }
            
            # Register webhook endpoints if API server is running
            if ($script:APIServer) {
                # Webhook management endpoints are already registered in Initialize-DefaultEndpoints
                Write-CustomLog -Message "Webhook endpoints already available" -Level "DEBUG"
            }
            
            # Send webhook enabled event
            Send-WebhookNotification -Event "webhook.enabled" -Data @{
                EnabledAt = $webhookConfig.EnabledAt
                Events = $Events
                SubscriptionCount = $script:WebhookSubscriptions.Count
            }
            
            Write-CustomLog -Message "Webhook functionality enabled successfully" -Level "SUCCESS"
            
            return @{
                Success = $true
                Enabled = $true
                Events = $Events
                RetryAttempts = $RetryAttempts
                Timeout = $Timeout
                SubscriptionCount = $script:WebhookSubscriptions.Count
                EnabledAt = $webhookConfig.EnabledAt
                SupportedEvents = $Events
            }

        } catch {
            $errorMessage = "Failed to enable webhooks: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Enabled = $false
                Error = $_.Exception.Message
                Message = $errorMessage
            }
        }
    }
}

# Helper function to send webhook notifications
function Send-WebhookNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Event,
        
        [Parameter()]
        [hashtable]$Data = @{},
        
        [Parameter()]
        [string]$SubscriptionId
    )
    
    try {
        # Check if webhooks are enabled
        if (-not $script:APIConfiguration.WebhookConfig.Enabled) {
            Write-CustomLog -Message "Webhooks not enabled, skipping notification" -Level "DEBUG"
            return
        }
        
        # Get subscriptions to notify
        $subscriptionsToNotify = @()
        
        if ($SubscriptionId) {
            # Specific subscription
            if ($script:WebhookSubscriptions.ContainsKey($SubscriptionId)) {
                $subscriptionsToNotify += @{ Id = $SubscriptionId; Config = $script:WebhookSubscriptions[$SubscriptionId] }
            }
        } else {
            # All subscriptions that match this event
            foreach ($subId in $script:WebhookSubscriptions.Keys) {
                $subscription = $script:WebhookSubscriptions[$subId]
                if ($subscription.IsActive -and ($subscription.Events -contains $Event -or $subscription.Events -contains "*")) {
                    $subscriptionsToNotify += @{ Id = $subId; Config = $subscription }
                }
            }
        }
        
        if ($subscriptionsToNotify.Count -eq 0) {
            Write-CustomLog -Message "No webhook subscriptions for event: $Event" -Level "DEBUG"
            return
        }
        
        # Create webhook payload
        $payload = @{
            event = $Event
            timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            data = $Data
            source = "AitherZero-RestAPI"
            version = "1.0.0"
        }
        
        $payloadJson = $payload | ConvertTo-Json -Depth 5 -Compress
        
        # Send to all matching subscriptions (async)
        foreach ($sub in $subscriptionsToNotify) {
            try {
                $subscription = $sub.Config
                $subId = $sub.Id
                
                # Update attempt statistics
                $subscription.DeliveryStats.Attempted++
                $subscription.DeliveryStats.LastAttempt = Get-Date
                
                # Create HTTP request
                $request = [System.Net.WebRequest]::Create($subscription.Url)
                $request.Method = "POST"
                $request.ContentType = "application/json"
                $request.Timeout = $script:APIConfiguration.WebhookConfig.Timeout * 1000
                $request.UserAgent = "AitherZero-Webhook/1.0"
                
                # Add signature if secret provided
                if ($subscription.Secret) {
                    $hmac = New-Object System.Security.Cryptography.HMACSHA256
                    $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($subscription.Secret)
                    $signature = [System.Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payloadJson)))
                    $request.Headers.Add("X-Webhook-Signature", "sha256=$signature")
                }
                
                # Add custom headers
                $request.Headers.Add("X-Event-Type", $Event)
                $request.Headers.Add("X-Webhook-Id", $subId)
                
                # Write payload
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($payloadJson)
                $request.ContentLength = $bytes.Length
                
                $requestStream = $request.GetRequestStream()
                $requestStream.Write($bytes, 0, $bytes.Length)
                $requestStream.Close()
                
                # Get response (with timeout)
                $response = $request.GetResponse()
                
                if ($response.StatusCode -eq [System.Net.HttpStatusCode]::OK) {
                    $subscription.DeliveryStats.Delivered++
                    $subscription.DeliveryStats.LastSuccess = Get-Date
                    Write-CustomLog -Message "Webhook delivered successfully: $Event to $($subscription.Url)" -Level "DEBUG"
                } else {
                    $subscription.DeliveryStats.Failed++
                    Write-CustomLog -Message "Webhook delivery failed with status $($response.StatusCode): $Event" -Level "WARNING"
                }
                
                $response.Close()
                
            } catch {
                $subscription.DeliveryStats.Failed++
                Write-CustomLog -Message "Webhook delivery error for $Event : $($_.Exception.Message)" -Level "ERROR"
            }
        }
        
        # Update global webhook statistics
        $script:APIConfiguration.WebhookConfig.DeliveryStats.TotalSent++
        $script:APIConfiguration.WebhookConfig.DeliveryStats.LastDelivery = Get-Date
        
    } catch {
        Write-CustomLog -Message "Webhook notification failed: $($_.Exception.Message)" -Level "ERROR"
    }
}

Export-ModuleMember -Function Enable-APIWebhooks, Send-WebhookNotification