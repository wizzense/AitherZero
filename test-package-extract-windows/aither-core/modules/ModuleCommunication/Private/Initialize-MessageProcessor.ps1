function Initialize-MessageProcessor {
    <#
    .SYNOPSIS
        Initialize the background message processor
    .DESCRIPTION
        Sets up the message processing thread that handles async message delivery
    #>
    [CmdletBinding()]
    param()

    try {
        # Create processor runspace
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()

        # Share required variables
        $runspace.SessionStateProxy.SetVariable('MessageBus', $script:MessageBus)
        $runspace.SessionStateProxy.SetVariable('Configuration', $script:Configuration)

        # Create processor script
        $processorScript = {
            while ($true) {
                try {
                    # Check for cancellation
                    if ($MessageBus.Processor.CancellationToken -and $MessageBus.Processor.CancellationToken.IsCancellationRequested) {
                        break
                    }

                    # Process messages
                    $message = $null
                    if ($MessageBus.MessageQueue.TryDequeue([ref]$message)) {
                        # Check if message expired
                        if ($message.ExpiresAt -lt (Get-Date)) {
                            $channel = $MessageBus.Channels[$message.Channel]
                            if ($channel) {
                                $channel.Statistics.ExpiredMessages++
                            }
                            continue
                        }

                        # Get relevant subscriptions
                        $subscriptions = @()
                        foreach ($key in $MessageBus.Subscriptions.Keys) {
                            if ($key.StartsWith("$($message.Channel)|")) {
                                $sub = $MessageBus.Subscriptions[$key]

                                # Check message type filter
                                if ($sub.MessageType -eq '*' -or $sub.MessageType -eq $message.MessageType) {
                                    # Check custom filter
                                    if (-not $sub.Filter -or (& $sub.Filter $message)) {
                                        $subscriptions += $sub
                                    }
                                }
                            }
                        }

                        # Deliver to subscribers
                        foreach ($subscription in $subscriptions) {
                            try {
                                $subscription.MessageCount++
                                $subscription.LastMessage = Get-Date

                                if ($subscription.RunAsync) {
                                    # Async execution
                                    Start-Job -ScriptBlock $subscription.Handler -ArgumentList $message | Out-Null
                                } else {
                                    # Sync execution
                                    & $subscription.Handler $message
                                }

                                # Update channel stats
                                $channel = $MessageBus.Channels[$message.Channel]
                                if ($channel) {
                                    $channel.Statistics.DeliveredMessages++
                                }
                            } catch {
                                $subscription.Errors += @{
                                    Timestamp = Get-Date
                                    Error = $_.Exception.Message
                                    MessageId = $message.Id
                                }

                                # Update channel stats
                                $channel = $MessageBus.Channels[$message.Channel]
                                if ($channel) {
                                    $channel.Statistics.FailedDeliveries++
                                }
                            }
                        }

                        $message.ProcessedCount = $subscriptions.Count
                    } else {
                        # No messages, sleep briefly
                        Start-Sleep -Milliseconds $Configuration.ProcessorInterval
                    }

                } catch {
                    # Log error but continue processing
                    # In real implementation, would use Write-CustomLog
                }
            }
        }

        # Start processor
        $powershell = [powershell]::Create()
        $powershell.Runspace = $runspace
        $powershell.AddScript($processorScript)

        $script:MessageBus.Processor.Thread = $powershell
        $script:MessageBus.Processor.Running = $true
        $script:MessageBus.Processor.CancellationToken = [System.Threading.CancellationTokenSource]::new()

        $handle = $powershell.BeginInvoke()

        Write-CustomLog -Level 'INFO' -Message "Message processor initialized"

    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to initialize message processor: $_"
        throw
    }
}
