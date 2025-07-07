<#
.SYNOPSIS
    Gets the current status and metrics of the AitherZero REST API server.

.DESCRIPTION
    Get-APIStatus returns comprehensive information about the API server
    including operational status, performance metrics, configuration details,
    and health indicators.

.PARAMETER IncludeMetrics
    Include detailed performance metrics in the response.

.PARAMETER IncludeEndpoints
    Include information about registered endpoints.

.PARAMETER IncludeConfiguration
    Include current server configuration details.

.EXAMPLE
    Get-APIStatus
    Gets basic API server status information.

.EXAMPLE
    Get-APIStatus -IncludeMetrics -IncludeEndpoints
    Gets comprehensive status with metrics and endpoint information.

.EXAMPLE
    Get-APIStatus -IncludeConfiguration
    Gets status information including server configuration.
#>
function Get-APIStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeMetrics,
        
        [Parameter()]
        [switch]$IncludeEndpoints,
        
        [Parameter()]
        [switch]$IncludeConfiguration
    )

    begin {
        Write-CustomLog -Message "Retrieving API server status" -Level "DEBUG"
    }

    process {
        try {
            # Base status information
            $status = @{
                Success = $true
                IsRunning = $false
                Status = "Stopped"
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                Version = "1.0.0"
            }
            
            # Check if server is running
            if ($script:APIServer -and $script:APIServerJob) {
                $jobState = $script:APIServerJob.State
                
                if ($jobState -eq 'Running') {
                    $status.IsRunning = $true
                    $status.Status = "Running"
                    
                    # Calculate uptime
                    if ($script:APIStartTime) {
                        $uptime = (Get-Date) - $script:APIStartTime
                        $status.UpTime = @{
                            TotalSeconds = [math]::Round($uptime.TotalSeconds, 2)
                            TotalMinutes = [math]::Round($uptime.TotalMinutes, 2)
                            TotalHours = [math]::Round($uptime.TotalHours, 2)
                            Display = "{0:dd\.hh\:mm\:ss}" -f $uptime
                        }
                    }
                    
                    # Add server information
                    $status.Server = @{
                        JobId = $script:APIServerJob.Id
                        Port = $script:APIServer.Port
                        Protocol = $script:APIServer.Protocol
                        StartTime = $script:APIServer.StartTime
                        URL = "$($script:APIServer.Protocol.ToLower())://localhost:$($script:APIServer.Port)"
                    }
                    
                } else {
                    $status.Status = "Job $jobState"
                    $status.JobState = $jobState
                }
            }
            
            # Include performance metrics if requested
            if ($IncludeMetrics -and $status.IsRunning) {
                # Update metrics
                if ($script:APIStartTime) {
                    $script:APIMetrics.UpTime = ((Get-Date) - $script:APIStartTime).TotalSeconds
                }
                
                $status.Metrics = @{
                    RequestCount = $script:APIMetrics.RequestCount
                    ErrorCount = $script:APIMetrics.ErrorCount
                    LastRequest = $script:APIMetrics.LastRequest
                    UpTimeSeconds = $script:APIMetrics.UpTime
                    ErrorRate = if ($script:APIMetrics.RequestCount -gt 0) {
                        [math]::Round(($script:APIMetrics.ErrorCount / $script:APIMetrics.RequestCount) * 100, 2)
                    } else { 0 }
                }
                
                # Add performance indicators
                $status.Health = @{
                    Status = if ($status.Metrics.ErrorRate -lt 5) { "Healthy" } 
                            elseif ($status.Metrics.ErrorRate -lt 15) { "Warning" } 
                            else { "Critical" }
                    RequestsPerMinute = if ($status.UpTime.TotalMinutes -gt 0) {
                        [math]::Round($script:APIMetrics.RequestCount / $status.UpTime.TotalMinutes, 2)
                    } else { 0 }
                }
            }
            
            # Include endpoint information if requested
            if ($IncludeEndpoints) {
                $status.Endpoints = @{
                    Count = $script:RegisteredEndpoints.Count
                    Registered = $script:RegisteredEndpoints.Keys | Sort-Object
                }
                
                if ($script:RegisteredEndpoints.Count -gt 0) {
                    $status.EndpointDetails = @{}
                    foreach ($path in $script:RegisteredEndpoints.Keys) {
                        $endpoint = $script:RegisteredEndpoints[$path]
                        $status.EndpointDetails[$path] = @{
                            Method = $endpoint.Method
                            Handler = $endpoint.Handler
                            Description = $endpoint.Description
                            RequiresAuth = $endpoint.Authentication
                        }
                    }
                }
            }
            
            # Include configuration if requested
            if ($IncludeConfiguration) {
                $status.Configuration = @{
                    Port = $script:APIConfiguration.Port
                    Protocol = $script:APIConfiguration.Protocol
                    SSLEnabled = $script:APIConfiguration.SSLEnabled
                    Authentication = $script:APIConfiguration.Authentication
                    CorsEnabled = $script:APIConfiguration.CorsEnabled
                    RateLimiting = $script:APIConfiguration.RateLimiting
                    LoggingEnabled = $script:APIConfiguration.LoggingEnabled
                }
                
                # Add webhook information
                $status.Webhooks = @{
                    Enabled = $script:WebhookSubscriptions.Count -gt 0
                    SubscriptionCount = $script:WebhookSubscriptions.Count
                    Subscriptions = $script:WebhookSubscriptions.Keys | Sort-Object
                }
            }
            
            return $status

        } catch {
            $errorMessage = "Failed to get API status: $($_.Exception.Message)"
            Write-CustomLog -Message $errorMessage -Level "ERROR"
            
            return @{
                Success = $false
                Status = "Error"
                Error = $_.Exception.Message
                Message = $errorMessage
                Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            }
        }
    }
}

Export-ModuleMember -Function Get-APIStatus