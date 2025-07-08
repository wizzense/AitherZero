#Requires -Version 7.0

<#
.SYNOPSIS
    Starts platform services and background processes.

.DESCRIPTION
    Initializes and starts background services, monitoring processes,
    and other platform services based on loaded modules.

.PARAMETER Platform
    The platform API object to configure services for.

.PARAMETER Services
    Specific services to start. If not specified, starts all available services.

.EXAMPLE
    Start-PlatformServices -Platform $aither

.EXAMPLE
    Start-PlatformServices -Platform $aither -Services @('Monitoring', 'Communication')

.NOTES
    Part of the unified platform API system. Typically called during platform initialization.
#>

function Start-PlatformServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Platform,

        [Parameter()]
        [string[]]$Services = @('All')
    )

    process {
        try {
            Write-CustomLog -Message "Starting platform services..." -Level "INFO"

            $serviceResults = @{
                Started = @()
                Failed = @()
                Skipped = @()
                StartTime = Get-Date
            }

            # Define available services based on loaded modules
            $availableServices = @{
                'Communication' = @{
                    Required = 'ModuleCommunication'
                    Description = 'Inter-module communication bus'
                    StartFunction = { Start-CommunicationService }
                }
                'Monitoring' = @{
                    Required = 'SystemMonitoring'
                    Description = 'System performance monitoring'
                    StartFunction = { Start-SystemMonitoring }
                }
                'RestAPI' = @{
                    Required = 'RestAPIServer'
                    Description = 'REST API server'
                    StartFunction = { Start-RestAPIServer }
                }
                'EventSystem' = @{
                    Required = $null  # Always available
                    Description = 'Platform event system'
                    StartFunction = { Initialize-EventSystem }
                }
                'ConfigurationWatcher' = @{
                    Required = 'ConfigurationCore'
                    Description = 'Configuration file watcher'
                    StartFunction = { Start-ConfigurationWatcher }
                }
                'BackgroundJobs' = @{
                    Required = 'ParallelExecution'
                    Description = 'Background job processor'
                    StartFunction = { Start-BackgroundJobProcessor }
                }
                'HealthMonitor' = @{
                    Required = $null  # Always available
                    Description = 'Platform health monitor'
                    StartFunction = { Start-HealthMonitor }
                }
            }

            # Determine which services to start
            $servicesToStart = if ($Services -contains 'All') {
                $availableServices.Keys
            } else {
                $Services | Where-Object { $availableServices.ContainsKey($_) }
            }

            foreach ($serviceName in $servicesToStart) {
                $serviceConfig = $availableServices[$serviceName]

                try {
                    # Check if required module is loaded
                    if ($serviceConfig.Required -and -not (Get-Module $serviceConfig.Required -ErrorAction SilentlyContinue)) {
                        Write-CustomLog -Message "⏭️ Skipping $serviceName - required module '$($serviceConfig.Required)' not loaded" -Level "DEBUG"
                        $serviceResults.Skipped += @{
                            Name = $serviceName
                            Reason = "Required module not loaded: $($serviceConfig.Required)"
                        }
                        continue
                    }

                    Write-CustomLog -Message "🚀 Starting $serviceName service..." -Level "INFO"

                    # Start the service
                    switch ($serviceName) {
                        'Communication' {
                            if (Get-Command Start-CommunicationService -ErrorAction SilentlyContinue) {
                                Start-CommunicationService
                            } else {
                                # Fallback - ensure communication is initialized
                                Write-CustomLog -Message "Communication service already initialized" -Level "DEBUG"
                            }
                        }

                        'Monitoring' {
                            if (Get-Command Start-SystemMonitoring -ErrorAction SilentlyContinue) {
                                Start-SystemMonitoring -Background
                            } else {
                                Write-CustomLog -Message "SystemMonitoring commands not available" -Level "WARN"
                            }
                        }

                        'RestAPI' {
                            if (Get-Command Start-RestAPIServer -ErrorAction SilentlyContinue) {
                                Start-RestAPIServer -Background
                            } else {
                                Write-CustomLog -Message "RestAPIServer commands not available" -Level "WARN"
                            }
                        }

                        'EventSystem' {
                            # Initialize basic event system if not already done
                            if (-not (Get-Variable -Name "PlatformEventSystem" -Scope Script -ErrorAction SilentlyContinue)) {
                                $script:PlatformEventSystem = @{
                                    Initialized = $true
                                    StartTime = Get-Date
                                    EventCount = 0
                                }
                                Write-CustomLog -Message "Platform event system initialized" -Level "DEBUG"
                            }
                        }

                        'ConfigurationWatcher' {
                            if (Get-Command Start-ConfigurationWatcher -ErrorAction SilentlyContinue) {
                                Start-ConfigurationWatcher
                            } else {
                                Write-CustomLog -Message "Configuration watcher not available" -Level "DEBUG"
                            }
                        }

                        'BackgroundJobs' {
                            if (Get-Command Start-BackgroundJobProcessor -ErrorAction SilentlyContinue) {
                                Start-BackgroundJobProcessor
                            } else {
                                # Basic background job initialization
                                if (-not (Get-Variable -Name "PlatformJobProcessor" -Scope Script -ErrorAction SilentlyContinue)) {
                                    $script:PlatformJobProcessor = @{
                                        Initialized = $true
                                        StartTime = Get-Date
                                        Jobs = @()
                                    }
                                    Write-CustomLog -Message "Basic job processor initialized" -Level "DEBUG"
                                }
                            }
                        }

                        'HealthMonitor' {
                            # Start background health monitoring
                            Start-PlatformHealthMonitor
                        }
                    }

                    Write-CustomLog -Message "✅ $serviceName service started successfully" -Level "SUCCESS"
                    $serviceResults.Started += @{
                        Name = $serviceName
                        Description = $serviceConfig.Description
                        StartTime = Get-Date
                    }

                } catch {
                    Write-CustomLog -Message "❌ Failed to start $serviceName service: $($_.Exception.Message)" -Level "ERROR"
                    $serviceResults.Failed += @{
                        Name = $serviceName
                        Error = $_.Exception.Message
                        Description = $serviceConfig.Description
                    }
                }
            }

            $serviceResults.EndTime = Get-Date
            $serviceResults.Duration = $serviceResults.EndTime - $serviceResults.StartTime

            # Summary
            Write-CustomLog -Message "Platform services startup complete:" -Level "INFO"
            Write-CustomLog -Message "  ✅ Started: $($serviceResults.Started.Count)" -Level "SUCCESS"
            Write-CustomLog -Message "  ❌ Failed: $($serviceResults.Failed.Count)" -Level "$(if ($serviceResults.Failed.Count -gt 0) { 'WARN' } else { 'INFO' })"
            Write-CustomLog -Message "  ⏭️ Skipped: $($serviceResults.Skipped.Count)" -Level "DEBUG"
            Write-CustomLog -Message "  ⏱️ Duration: $($serviceResults.Duration.TotalSeconds) seconds" -Level "INFO"

            return $serviceResults

        } catch {
            Write-CustomLog -Message "❌ Failed to start platform services: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

# Helper function for health monitoring
function Start-PlatformHealthMonitor {
    [CmdletBinding()]
    param()

    process {
        try {
            if (-not (Get-Variable -Name "PlatformHealthMonitor" -Scope Script -ErrorAction SilentlyContinue)) {
                $script:PlatformHealthMonitor = @{
                    Initialized = $true
                    StartTime = Get-Date
                    LastCheck = $null
                    CheckInterval = 300  # 5 minutes
                    AlertThreshold = 60  # Alert if health score below 60
                    Enabled = $true
                }

                # Start background monitoring job if ParallelExecution is available
                if (Get-Module ParallelExecution -ErrorAction SilentlyContinue) {
                    $monitoringJob = Start-Job -ScriptBlock {
                        param($CheckInterval, $AlertThreshold)

                        while ($true) {
                            Start-Sleep -Seconds $CheckInterval

                            try {
                                $health = Get-PlatformHealth -Quick

                                if ($health.Score -lt $AlertThreshold) {
                                    Write-Warning "Platform health degraded: Score $($health.Score), Issues: $($health.Issues -join '; ')"
                                }

                            } catch {
                                Write-Warning "Health monitoring check failed: $_"
                            }
                        }
                    } -ArgumentList $script:PlatformHealthMonitor.CheckInterval, $script:PlatformHealthMonitor.AlertThreshold

                    $script:PlatformHealthMonitor.JobId = $monitoringJob.Id
                    Write-CustomLog -Message "Background health monitoring started (Job ID: $($monitoringJob.Id))" -Level "DEBUG"
                } else {
                    Write-CustomLog -Message "Health monitor initialized (no background job - ParallelExecution not available)" -Level "DEBUG"
                }
            }

        } catch {
            Write-CustomLog -Message "Failed to start health monitor: $($_.Exception.Message)" -Level "WARN"
        }
    }
}
