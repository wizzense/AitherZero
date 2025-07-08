#Requires -Version 7.0

<#
.SYNOPSIS
    Gets comprehensive status information about the AitherZero platform.

.DESCRIPTION
    Provides detailed status information including module load status,
    health checks, and platform readiness indicators.

.PARAMETER Detailed
    Include detailed information about each module.

.EXAMPLE
    Get-PlatformStatus
    
.EXAMPLE
    Get-PlatformStatus -Detailed

.NOTES
    Part of the unified platform API system.
#>

function Get-PlatformStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Detailed
    )
    
    process {
        try {
            $moduleStatus = Get-CoreModuleStatus
            $loadedCount = ($moduleStatus | Where-Object { $_.Loaded }).Count
            $availableCount = ($moduleStatus | Where-Object { $_.Available }).Count
            $requiredModules = $script:CoreModules | Where-Object { $_.Required }
            $requiredLoaded = 0
            
            foreach ($required in $requiredModules) {
                if ($script:LoadedModules.ContainsKey($required.Name)) {
                    $requiredLoaded++
                }
            }
            
            $status = @{
                Platform = @{
                    Version = "2.0.0"
                    Status = if ($requiredLoaded -eq $requiredModules.Count) { "Ready" } else { "Degraded" }
                    InitializedAt = $script:LoadedModules.Values | ForEach-Object { $_.ImportTime } | Sort-Object | Select-Object -First 1
                    Profile = "Unknown" # Will be set by platform initialization
                }
                Modules = @{
                    Total = $script:CoreModules.Count
                    Available = $availableCount
                    Loaded = $loadedCount
                    Required = $requiredModules.Count
                    RequiredLoaded = $requiredLoaded
                    LoadedModules = @($script:LoadedModules.Keys)
                }
                Health = @{
                    CoreHealth = Test-CoreApplicationHealth
                    ConfigurationSystem = if (Get-Module ConfigurationCore -ErrorAction SilentlyContinue) { "Available" } else { "Not Loaded" }
                    CommunicationSystem = if (Get-Module ModuleCommunication -ErrorAction SilentlyContinue) { "Available" } else { "Not Loaded" }
                    APIGateway = "Active"
                }
                Capabilities = @{
                    LabAutomation = $script:LoadedModules.ContainsKey('LabRunner')
                    InfrastructureDeployment = $script:LoadedModules.ContainsKey('OpenTofuProvider')
                    PatchManagement = $script:LoadedModules.ContainsKey('PatchManager')
                    ISOManagement = $script:LoadedModules.ContainsKey('ISOManager')
                    TestingFramework = $script:LoadedModules.ContainsKey('TestingFramework')
                    BackupManagement = $script:LoadedModules.ContainsKey('BackupManager')
                    ConfigurationManagement = $script:LoadedModules.ContainsKey('ConfigurationCore')
                    Orchestration = $script:LoadedModules.ContainsKey('OrchestrationEngine')
                    ProgressTracking = $script:LoadedModules.ContainsKey('ProgressTracking')
                    RemoteConnections = $script:LoadedModules.ContainsKey('RemoteConnection')
                }
                Performance = @{
                    ModuleLoadTime = if ($script:LoadedModules.Count -gt 0) {
                        $times = $script:LoadedModules.Values | ForEach-Object { $_.ImportTime }
                        $span = (($times | Sort-Object)[-1]) - (($times | Sort-Object)[0])
                        $span.TotalSeconds
                    } else { 0 }
                    MemoryUsage = [System.GC]::GetTotalMemory($false) / 1MB
                    LoadedAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies().Count
                }
                LastCheck = Get-Date
            }
            
            if ($Detailed) {
                $status.DetailedModules = $moduleStatus
                $status.LoadOrder = $script:CoreModules | ForEach-Object {
                    @{
                        Name = $_.Name
                        Required = $_.Required
                        Loaded = $script:LoadedModules.ContainsKey($_.Name)
                        LoadTime = if ($script:LoadedModules.ContainsKey($_.Name)) { 
                            $script:LoadedModules[$_.Name].ImportTime 
                        } else { 
                            $null 
                        }
                        Description = $_.Description
                    }
                } | Sort-Object { if ($_.LoadTime) { $_.LoadTime } else { [DateTime]::MaxValue } }
                
                # Add integration analysis
                $status.Integrations = @{
                    ConfigurationIntegration = ($script:LoadedModules.ContainsKey('ConfigurationCore') -and 
                                              $script:LoadedModules.ContainsKey('ConfigurationCarousel'))
                    OrchestrationIntegration = ($script:LoadedModules.ContainsKey('OrchestrationEngine') -and 
                                              $script:LoadedModules.ContainsKey('LabRunner'))
                    DevelopmentIntegration = ($script:LoadedModules.ContainsKey('PatchManager') -and 
                                            $script:LoadedModules.ContainsKey('TestingFramework'))
                    ISOWorkflowIntegration = $script:LoadedModules.ContainsKey('ISOManager')
                    CommunicationIntegration = $script:LoadedModules.ContainsKey('ModuleCommunication')
                }
            }
            
            return $status
            
        } catch {
            Write-CustomLog -Message "Failed to get platform status: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}