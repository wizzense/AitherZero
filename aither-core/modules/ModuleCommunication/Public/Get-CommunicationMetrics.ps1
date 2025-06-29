function Get-CommunicationMetrics {
    <#
    .SYNOPSIS
        Get module communication performance metrics
    .DESCRIPTION
        Returns detailed metrics about message bus and API performance
    .PARAMETER IncludeHistory
        Include call history details
    .PARAMETER Channel
        Get metrics for specific channel
    .EXAMPLE
        $metrics = Get-CommunicationMetrics
        Write-Host "Total API Calls: $($metrics.API.TotalCalls)"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeHistory,
        
        [Parameter()]
        [string]$Channel
    )
    
    try {
        $metrics = @{
            Timestamp = Get-Date
            MessageBus = @{
                Channels = @{}
                TotalChannels = $script:MessageBus.Channels.Count
                TotalSubscriptions = $script:MessageBus.Subscriptions.Count
                QueuedMessages = $script:MessageBus.MessageQueue.Count
                EventHistorySize = $script:MessageBus.EventHistory.Count
            }
            API = @{
                TotalAPIs = $script:APIRegistry.APIs.Count
                TotalCalls = $script:APIRegistry.Metrics.TotalCalls
                SuccessfulCalls = $script:APIRegistry.Metrics.SuccessfulCalls
                FailedCalls = $script:APIRegistry.Metrics.FailedCalls
                SuccessRate = if ($script:APIRegistry.Metrics.TotalCalls -gt 0) {
                    [math]::Round(($script:APIRegistry.Metrics.SuccessfulCalls / $script:APIRegistry.Metrics.TotalCalls) * 100, 2)
                } else { 0 }
                TopAPIs = @()
            }
            Performance = @{
                ProcessorRunning = $script:MessageBus.Processor.Running
                AverageAPIExecutionTime = 0
                MessageDeliveryRate = 0
            }
        }
        
        # Channel metrics
        if ($Channel) {
            if ($script:MessageBus.Channels.ContainsKey($Channel)) {
                $channelInfo = $script:MessageBus.Channels[$Channel]
                $metrics.MessageBus.Channels[$Channel] = @{
                    MessageCount = $channelInfo.MessageCount
                    SubscriptionCount = $channelInfo.SubscriptionCount
                    Statistics = $channelInfo.Statistics
                    LastActivity = $channelInfo.LastActivity
                }
            }
        } else {
            # All channels
            foreach ($channelName in $script:MessageBus.Channels.Keys) {
                $channelInfo = $script:MessageBus.Channels[$channelName]
                $metrics.MessageBus.Channels[$channelName] = @{
                    MessageCount = $channelInfo.MessageCount
                    SubscriptionCount = $channelInfo.SubscriptionCount
                    TotalMessages = $channelInfo.Statistics.TotalMessages
                    DeliveryRate = if ($channelInfo.Statistics.TotalMessages -gt 0) {
                        [math]::Round(($channelInfo.Statistics.DeliveredMessages / $channelInfo.Statistics.TotalMessages) * 100, 2)
                    } else { 0 }
                }
            }
        }
        
        # Top APIs by call count
        $topAPIs = $script:APIRegistry.APIs.Values | 
            Sort-Object -Property CallCount -Descending |
            Select-Object -First 10
        
        foreach ($api in $topAPIs) {
            $metrics.API.TopAPIs += @{
                Name = $api.FullName
                CallCount = $api.CallCount
                AverageExecutionTime = [math]::Round($api.AverageExecutionTime, 2)
                LastCalled = $api.LastCalled
            }
        }
        
        # Calculate average API execution time
        $totalTime = 0
        $totalAPIs = 0
        foreach ($api in $script:APIRegistry.APIs.Values) {
            if ($api.CallCount -gt 0) {
                $totalTime += $api.AverageExecutionTime
                $totalAPIs++
            }
        }
        if ($totalAPIs -gt 0) {
            $metrics.Performance.AverageAPIExecutionTime = [math]::Round($totalTime / $totalAPIs, 2)
        }
        
        # Include history if requested
        if ($IncludeHistory) {
            $metrics.API.RecentCalls = @()
            $recentCalls = @($script:APIRegistry.Metrics.CallHistory.ToArray()) | 
                Sort-Object -Property StartTime -Descending |
                Select-Object -First 50
                
            foreach ($call in $recentCalls) {
                $metrics.API.RecentCalls += @{
                    RequestId = $call.RequestId
                    API = $call.APIKey
                    StartTime = $call.StartTime
                    Duration = $call.Duration
                    Success = -not $call.Error
                    Error = $call.Error
                }
            }
        }
        
        return $metrics
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get communication metrics: $_"
        throw
    }
}