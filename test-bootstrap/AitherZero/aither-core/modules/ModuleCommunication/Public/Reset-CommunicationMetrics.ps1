function Reset-CommunicationMetrics {
    <#
    .SYNOPSIS
        Reset communication metrics
    .DESCRIPTION
        Resets performance metrics and counters for message bus and APIs
    .PARAMETER MetricType
        Type of metrics to reset (All, MessageBus, API, Performance)
    .PARAMETER Force
        Force reset without confirmation
    .EXAMPLE
        Reset-CommunicationMetrics -MetricType API -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [ValidateSet('All', 'MessageBus', 'API', 'Performance')]
        [string]$MetricType = 'All',
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        # Confirmation
        if (-not $Force -and -not $WhatIfPreference) {
            $message = "Reset $MetricType metrics? This will clear all performance counters."
            
            $choice = Read-Host "$message (y/N)"
            if ($choice -ne 'y' -and $choice -ne 'Y') {
                Write-CustomLog -Level 'INFO' -Message "Operation cancelled"
                return @{
                    Success = $false
                    Reason = "Operation cancelled"
                }
            }
        }
        
        if ($PSCmdlet.ShouldProcess("Communication Metrics", "Reset $MetricType Metrics")) {
            $resetDetails = @{}
            
            switch ($MetricType) {
                'All' {
                    # Reset all metrics
                    $resetDetails.MessageBus = Reset-MessageBusMetrics
                    $resetDetails.API = Reset-APIMetrics
                    $resetDetails.Performance = Reset-PerformanceMetrics
                }
                'MessageBus' {
                    $resetDetails.MessageBus = Reset-MessageBusMetrics
                }
                'API' {
                    $resetDetails.API = Reset-APIMetrics
                }
                'Performance' {
                    $resetDetails.Performance = Reset-PerformanceMetrics
                }
            }
            
            Write-CustomLog -Level 'SUCCESS' -Message "$MetricType metrics reset successfully"
            
            return @{
                Success = $true
                MetricType = $MetricType
                ResetTime = Get-Date
                Details = $resetDetails
            }
        }
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to reset metrics: $_"
        throw
    }
}

function Reset-MessageBusMetrics {
    # Reset channel statistics
    foreach ($channelName in $script:MessageBus.Channels.Keys) {
        $channel = $script:MessageBus.Channels[$channelName]
        $channel.Statistics = @{
            TotalMessages = 0
            DeliveredMessages = 0
            FailedDeliveries = 0
            ExpiredMessages = 0
        }
        $channel.MessageCount = 0
    }
    
    # Reset subscription error counts
    foreach ($key in $script:MessageBus.Subscriptions.Keys) {
        $subscription = $script:MessageBus.Subscriptions[$key]
        $subscription.MessageCount = 0
        $subscription.Errors = @()
    }
    
    return @{
        ChannelsReset = $script:MessageBus.Channels.Count
        SubscriptionsReset = $script:MessageBus.Subscriptions.Count
    }
}

function Reset-APIMetrics {
    # Reset global API metrics
    $script:APIRegistry.Metrics.TotalCalls = 0
    $script:APIRegistry.Metrics.SuccessfulCalls = 0
    $script:APIRegistry.Metrics.FailedCalls = 0
    
    # Clear call history
    while ($script:APIRegistry.Metrics.CallHistory.Count -gt 0) {
        $discard = $null
        $script:APIRegistry.Metrics.CallHistory.TryDequeue([ref]$discard) | Out-Null
    }
    
    # Reset individual API metrics
    $apisReset = 0
    foreach ($apiKey in $script:APIRegistry.APIs.Keys) {
        $api = $script:APIRegistry.APIs[$apiKey]
        $api.CallCount = 0
        $api.LastCalled = $null
        $api.AverageExecutionTime = 0
        $apisReset++
    }
    
    return @{
        APIsReset = $apisReset
        CallHistoryCleared = $true
    }
}

function Reset-PerformanceMetrics {
    # Performance metrics are calculated on-demand, so just return status
    return @{
        MetricsRecalculated = $true
        ProcessorStatus = $script:MessageBus.Processor.Running
    }
}