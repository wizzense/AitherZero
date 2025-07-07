function Get-CommunicationStatus {
    <#
    .SYNOPSIS
        Get overall communication system status
    .DESCRIPTION
        Returns a comprehensive status report of the communication system
    .PARAMETER IncludeDetails
        Include detailed component information
    .PARAMETER CheckHealth
        Perform health checks on components
    .EXAMPLE
        Get-CommunicationStatus -IncludeDetails -CheckHealth
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeDetails,
        
        [Parameter()]
        [switch]$CheckHealth
    )
    
    try {
        $status = @{
            Timestamp = Get-Date
            OverallHealth = 'Unknown'
            Components = @{
                MessageBus = @{
                    Status = 'Unknown'
                    ProcessorRunning = $script:MessageBus.Processor.Running
                    Channels = $script:MessageBus.Channels.Count
                    Subscriptions = $script:MessageBus.Subscriptions.Count
                    QueuedMessages = $script:MessageBus.MessageQueue.Count
                }
                APIRegistry = @{
                    Status = 'Unknown'
                    RegisteredAPIs = $script:APIRegistry.APIs.Count
                    ActiveMiddleware = $script:APIRegistry.Middleware.Count
                    TotalCalls = $script:APIRegistry.Metrics.TotalCalls
                    SuccessRate = if ($script:APIRegistry.Metrics.TotalCalls -gt 0) {
                        [math]::Round(($script:APIRegistry.Metrics.SuccessfulCalls / $script:APIRegistry.Metrics.TotalCalls) * 100, 2)
                    } else { 0 }
                }
                Configuration = @{
                    Status = 'Unknown'
                    TracingEnabled = $script:Configuration.EnableTracing
                    MaxEventHistory = $script:Configuration.MaxEventHistory
                    MaxMessageQueue = $script:Configuration.MaxMessageQueueSize
                }
            }
            Issues = @()
            Recommendations = @()
        }
        
        # Determine component health
        $healthyComponents = 0
        $totalComponents = 3
        
        # MessageBus Health
        if ($script:MessageBus.Processor.Running) {
            $status.Components.MessageBus.Status = 'Healthy'
            $healthyComponents++
        } else {
            $status.Components.MessageBus.Status = 'Unhealthy'
            $status.Issues += "Message processor is not running"
            $status.Recommendations += "Restart message processor with Start-MessageProcessor"
        }
        
        # Check queue size
        if ($script:MessageBus.MessageQueue.Count -gt ($script:Configuration.MaxMessageQueueSize * 0.8)) {
            $status.Issues += "Message queue is nearly full ($($script:MessageBus.MessageQueue.Count)/$($script:Configuration.MaxMessageQueueSize))"
            $status.Recommendations += "Consider increasing queue size or clearing old messages"
        }
        
        # APIRegistry Health
        if ($script:APIRegistry.APIs.Count -gt 0) {
            if ($script:APIRegistry.Metrics.TotalCalls -gt 0) {
                $successRate = ($script:APIRegistry.Metrics.SuccessfulCalls / $script:APIRegistry.Metrics.TotalCalls) * 100
                if ($successRate -ge 95) {
                    $status.Components.APIRegistry.Status = 'Healthy'
                    $healthyComponents++
                } elseif ($successRate -ge 80) {
                    $status.Components.APIRegistry.Status = 'Warning'
                    $status.Issues += "API success rate is low: $([math]::Round($successRate, 2))%"
                    $status.Recommendations += "Review failed API calls and error patterns"
                } else {
                    $status.Components.APIRegistry.Status = 'Unhealthy'
                    $status.Issues += "API success rate is very low: $([math]::Round($successRate, 2))%"
                    $status.Recommendations += "Investigate API failures urgently"
                }
            } else {
                $status.Components.APIRegistry.Status = 'Healthy'
                $healthyComponents++
            }
        } else {
            $status.Components.APIRegistry.Status = 'Warning'
            $status.Issues += "No APIs are registered"
            $status.Recommendations += "Register module APIs for inter-module communication"
        }
        
        # Configuration Health
        $status.Components.Configuration.Status = 'Healthy'
        $healthyComponents++
        
        # Check event history size
        if ($script:MessageBus.EventHistory.Count -gt ($script:Configuration.MaxEventHistory * 0.9)) {
            $status.Issues += "Event history is nearly full ($($script:MessageBus.EventHistory.Count)/$($script:Configuration.MaxEventHistory))"
            $status.Recommendations += "Consider clearing old events or increasing history size"
        }
        
        # Overall health
        $healthPercentage = ($healthyComponents / $totalComponents) * 100
        if ($healthPercentage -eq 100) {
            $status.OverallHealth = 'Healthy'
        } elseif ($healthPercentage -ge 66) {
            $status.OverallHealth = 'Warning'
        } else {
            $status.OverallHealth = 'Unhealthy'
        }
        
        # Perform health checks if requested
        if ($CheckHealth) {
            $status.HealthChecks = @{}
            
            # Test basic messaging
            try {
                $testResult = Test-MessageChannel -Name "Events" -Timeout 5
                $status.HealthChecks.MessagingTest = @{
                    Success = $testResult.Success
                    Duration = $testResult.Duration
                    Details = if (-not $testResult.Success) { $testResult.Errors -join '; ' } else { 'OK' }
                }
            } catch {
                $status.HealthChecks.MessagingTest = @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
            
            # Test metrics collection
            try {
                $metrics = Get-CommunicationMetrics
                $status.HealthChecks.MetricsTest = @{
                    Success = $metrics -ne $null
                    Details = 'Metrics collection working'
                }
            } catch {
                $status.HealthChecks.MetricsTest = @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Add detailed information if requested
        if ($IncludeDetails) {
            $status.Details = @{
                Channels = Get-MessageChannels
                APIs = Get-ModuleAPIs
                Middleware = Get-APIMiddleware
                Subscriptions = Get-MessageSubscriptions
                RecentEvents = Get-ModuleEvents -Last 10
            }
        }
        
        return $status
        
    } catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to get communication status: $_"
        throw
    }
}