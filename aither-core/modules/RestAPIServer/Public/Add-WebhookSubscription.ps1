<#
.SYNOPSIS
    Adds a new webhook subscription to the API server.

.DESCRIPTION
    Add-WebhookSubscription creates a new webhook subscription that will
    receive HTTP notifications when specified events occur within AitherZero.
    Supports event filtering, secret authentication, and delivery validation.

.PARAMETER Url
    The webhook URL to send notifications to.

.PARAMETER Events
    Array of event types to subscribe to. Use "*" for all events.

.PARAMETER Secret
    Optional secret for webhook payload signing.

.PARAMETER Description
    Description of the webhook subscription.

.PARAMETER Active
    Whether the subscription is active. Default is true.

.PARAMETER TestDelivery
    Send a test webhook after creating the subscription.

.EXAMPLE
    Add-WebhookSubscription -Url "https://api.example.com/webhooks" -Events @("test.completed", "deployment.finished")
    Creates a webhook subscription for specific events.

.EXAMPLE
    Add-WebhookSubscription -Url "https://hooks.slack.com/services/..." -Events @("*") -Secret "webhook-secret"
    Creates a webhook subscription for all events with secret authentication.

.EXAMPLE
    Add-WebhookSubscription -Url "https://internal.company.com/aither-hooks" -Events @("error.occurred") -Description "Internal error monitoring"
    Creates a webhook for error monitoring with description.
#>
function Add-WebhookSubscription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if ($_ -match '^https?://') { $true }
            else { throw "URL must start with http:// or https://" }
        })]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [ValidateScript({
            if ($_.Count -eq 0) { throw "At least one event must be specified" }
            $true
        })]
        [string[]]$Events,
        
        [Parameter()]
        [string]$Secret,
        
        [Parameter()]
        [string]$Description = "",
        
        [Parameter()]
        [switch]$Active = $true,
        
        [Parameter()]
        [switch]$TestDelivery
    )

    begin {
        Write-CustomLog -Message "Adding webhook subscription: $Url" -Level "INFO"
    }

    process {
        try {
            # Check if webhooks are enabled
            if (-not $script:APIConfiguration.WebhookConfig.Enabled) {
                throw "Webhooks are not enabled. Run Enable-APIWebhooks first."
            }
            
            # Validate events against supported events
            $supportedEvents = $script:APIConfiguration.WebhookConfig.Events + @("*")
            foreach ($event in $Events) {
                if ($event -ne "*" -and $event -notin $supportedEvents) {
                    Write-CustomLog -Message "Warning: Event '$event' is not in supported events list" -Level "WARNING"
                }
            }
            
            # Check for duplicate subscription (same URL and events)
            $duplicateFound = $false
            foreach ($existingId in $script:WebhookSubscriptions.Keys) {
                $existing = $script:WebhookSubscriptions[$existingId]
                if ($existing.Url -eq $Url -and $existing.IsActive) {
                    # Check if events overlap significantly
                    $overlap = ($existing.Events | Where-Object { $_ -in $Events }).Count
                    if ($overlap -gt 0 -or $Events -contains "*" -or $existing.Events -contains "*") {
                        Write-CustomLog -Message "Warning: Similar subscription already exists for $Url" -Level "WARNING"
                        $duplicateFound = $true
                        break
                    }
                }
            }
            
            # Generate unique subscription ID
            $subscriptionId = [System.Guid]::NewGuid().ToString()
            
            # Create subscription object
            $subscription = @{
                Url = $Url
                Events = $Events
                Secret = $Secret
                Description = $Description
                IsActive = $Active.IsPresent
                CreatedAt = Get-Date
                CreatedBy = $env:USERNAME
                LastModified = Get-Date
                DeliveryStats = @{
                    Attempted = 0
                    Delivered = 0
                    Failed = 0
                    LastAttempt = $null
                    LastSuccess = $null
                    LastError = $null
                }
                Configuration = @{
                    RetryAttempts = $script:APIConfiguration.WebhookConfig.RetryAttempts
                    Timeout = $script:APIConfiguration.WebhookConfig.Timeout
                }
            }
            
            # Validate URL accessibility if requested or if it's the first subscription
            if ($TestDelivery -or $script:WebhookSubscriptions.Count -eq 0) {
                Write-CustomLog -Message "Testing webhook URL accessibility" -Level "DEBUG"
                
                try {
                    $testPayload = @{
                        event = "webhook.test"
                        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                        data = @{
                            message = "Test webhook from AitherZero API server"
                            subscriptionId = $subscriptionId
                        }
                        source = "AitherZero-RestAPI"
                        version = "1.0.0"
                    } | ConvertTo-Json -Depth 3
                    
                    $testRequest = [System.Net.WebRequest]::Create($Url)
                    $testRequest.Method = "POST"
                    $testRequest.ContentType = "application/json"
                    $testRequest.Timeout = 10000  # 10 second timeout for test
                    $testRequest.UserAgent = "AitherZero-Webhook-Test/1.0"
                    
                    # Add signature if secret provided
                    if ($Secret) {
                        $hmac = New-Object System.Security.Cryptography.HMACSHA256
                        $hmac.Key = [System.Text.Encoding]::UTF8.GetBytes($Secret)
                        $signature = [System.Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($testPayload)))
                        $testRequest.Headers.Add("X-Webhook-Signature", "sha256=$signature")
                    }
                    
                    $testRequest.Headers.Add("X-Event-Type", "webhook.test")
                    $testRequest.Headers.Add("X-Webhook-Id", $subscriptionId)
                    
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($testPayload)
                    $testRequest.ContentLength = $bytes.Length
                    
                    $requestStream = $testRequest.GetRequestStream()
                    $requestStream.Write($bytes, 0, $bytes.Length)
                    $requestStream.Close()
                    
                    $testResponse = $testRequest.GetResponse()
                    $testStatusCode = $testResponse.StatusCode
                    $testResponse.Close()
                    
                    Write-CustomLog -Message "Webhook test successful: $testStatusCode" -Level "SUCCESS"
                    
                } catch {
                    Write-CustomLog -Message "Webhook test failed: $($_.Exception.Message)" -Level "WARNING"
                    if (-not $TestDelivery) {
                        # Don't fail subscription creation if this was just an automatic test
                        Write-CustomLog -Message "Continuing with subscription creation despite test failure" -Level "INFO"
                    }
                }
            }
            
            # Add subscription to registry
            $script:WebhookSubscriptions[$subscriptionId] = $subscription
            
            # Log successful creation
            $eventText = if ($Events -contains "*") { "all events" } else { $Events -join ", " }
            $secretText = if ($Secret) { " (with secret)" } else { " (no secret)" }
            
            Write-CustomLog -Message "Webhook subscription created: $subscriptionId for $eventText$secretText" -Level "SUCCESS"
            
            # Send subscription created event
            if ($Active) {
                Send-WebhookNotification -Event "webhook.subscription.created" -Data @{
                    subscriptionId = $subscriptionId
                    url = $Url
                    events = $Events
                    hasSecret = -not [string]::IsNullOrEmpty($Secret)
                    description = $Description
                }
            }
            
            return @{
                Success = $true
                SubscriptionId = $subscriptionId
                Url = $Url
                Events = $Events
                Description = $Description
                IsActive = $Active.IsPresent
                HasSecret = -not [string]::IsNullOrEmpty($Secret)
                CreatedAt = $subscription.CreatedAt
                TotalSubscriptions = $script:WebhookSubscriptions.Count
                DuplicateWarning = $duplicateFound
            }

        } catch {
            $errorMessage = "Failed to add webhook subscription: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                Message = $errorMessage
                Url = $Url
                Events = $Events
            }
        }
    }
}

Export-ModuleMember -Function Add-WebhookSubscription