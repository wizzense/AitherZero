#Requires -Version 7.0

<#
.SYNOPSIS
    Gets platform lifecycle information including initialization order and dependencies.

.DESCRIPTION
    Provides detailed information about module initialization order, dependencies,
    lifecycle hooks, and platform state management.

.PARAMETER IncludeDependencies
    Include detailed dependency analysis.

.EXAMPLE
    Get-PlatformLifecycle
    
.EXAMPLE
    Get-PlatformLifecycle -IncludeDependencies

.NOTES
    Part of the unified platform API system.
#>

function Get-PlatformLifecycle {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeDependencies
    )
    
    process {
        try {
            $lifecycle = @{
                InitializationOrder = @(
                    # Foundation Layer
                    @{ Name = "Logging"; Layer = "Foundation"; Priority = 1; Description = "Core logging system" }
                    @{ Name = "ConfigurationCore"; Layer = "Foundation"; Priority = 2; Description = "Unified configuration management" }
                    @{ Name = "ModuleCommunication"; Layer = "Foundation"; Priority = 3; Description = "Inter-module communication" }
                    
                    # Security Layer
                    @{ Name = "SecureCredentials"; Layer = "Security"; Priority = 4; Description = "Credential management" }
                    @{ Name = "SecurityAutomation"; Layer = "Security"; Priority = 5; Description = "Security automation" }
                    
                    # Core Services Layer
                    @{ Name = "ParallelExecution"; Layer = "Core"; Priority = 6; Description = "Parallel processing" }
                    @{ Name = "ProgressTracking"; Layer = "Core"; Priority = 7; Description = "Progress tracking" }
                    @{ Name = "LabRunner"; Layer = "Core"; Priority = 8; Description = "Lab automation" }
                    
                    # Platform Services Layer
                    @{ Name = "ConfigurationCarousel"; Layer = "Platform"; Priority = 9; Description = "Multi-environment config" }
                    @{ Name = "ConfigurationRepository"; Layer = "Platform"; Priority = 10; Description = "Git-based config" }
                    @{ Name = "OrchestrationEngine"; Layer = "Platform"; Priority = 11; Description = "Workflow orchestration" }
                    
                    # Infrastructure Layer
                    @{ Name = "OpenTofuProvider"; Layer = "Infrastructure"; Priority = 12; Description = "Infrastructure deployment" }
                    @{ Name = "RemoteConnection"; Layer = "Infrastructure"; Priority = 13; Description = "Remote connections" }
                    @{ Name = "SystemMonitoring"; Layer = "Infrastructure"; Priority = 14; Description = "System monitoring" }
                    
                    # Feature Layer
                    @{ Name = "ISOManager"; Layer = "Features"; Priority = 15; Description = "ISO management" }
                    @{ Name = "ISOCustomizer"; Layer = "Features"; Priority = 16; Description = "ISO customization" }
                    @{ Name = "BackupManager"; Layer = "Features"; Priority = 17; Description = "Backup operations" }
                    @{ Name = "UnifiedMaintenance"; Layer = "Features"; Priority = 18; Description = "Maintenance operations" }
                    @{ Name = "ScriptManager"; Layer = "Features"; Priority = 19; Description = "Script management" }
                    @{ Name = "RepoSync"; Layer = "Features"; Priority = 20; Description = "Repository sync" }
                    
                    # Development Layer
                    @{ Name = "DevEnvironment"; Layer = "Development"; Priority = 21; Description = "Dev environment" }
                    @{ Name = "PatchManager"; Layer = "Development"; Priority = 22; Description = "Patch management" }
                    @{ Name = "TestingFramework"; Layer = "Development"; Priority = 23; Description = "Testing framework" }
                    @{ Name = "AIToolsIntegration"; Layer = "Development"; Priority = 24; Description = "AI tools integration" }
                    @{ Name = "SetupWizard"; Layer = "Development"; Priority = 25; Description = "Setup wizard" }
                    
                    # API Layer
                    @{ Name = "RestAPIServer"; Layer = "API"; Priority = 26; Description = "REST API server" }
                )
                
                CurrentState = @{
                    LoadedModules = @($script:LoadedModules.Keys)
                    LoadOrder = @()
                    InitializationTime = $null
                    PlatformReady = $false
                }
                
                LifecycleHooks = @{
                    PreInitialization = @()
                    PostInitialization = @()
                    PreShutdown = @()
                    PostShutdown = @()
                    ConfigurationChange = @()
                    ModuleLoad = @()
                    ModuleUnload = @()
                }
                
                Dependencies = @{}
                
                Layers = @{
                    Foundation = @{ Modules = @(); Status = "Unknown"; Critical = $true }
                    Security = @{ Modules = @(); Status = "Unknown"; Critical = $true }
                    Core = @{ Modules = @(); Status = "Unknown"; Critical = $true }
                    Platform = @{ Modules = @(); Status = "Unknown"; Critical = $false }
                    Infrastructure = @{ Modules = @(); Status = "Unknown"; Critical = $false }
                    Features = @{ Modules = @(); Status = "Unknown"; Critical = $false }
                    Development = @{ Modules = @(); Status = "Unknown"; Critical = $false }
                    API = @{ Modules = @(); Status = "Unknown"; Critical = $false }
                }
            }
            
            # Analyze current state
            if ($script:LoadedModules.Count -gt 0) {
                $loadTimes = $script:LoadedModules.Values | ForEach-Object { $_.ImportTime } | Sort-Object
                $lifecycle.CurrentState.InitializationTime = $loadTimes[-1] - $loadTimes[0]
                
                # Determine actual load order
                foreach ($moduleName in $script:LoadedModules.Keys) {
                    $moduleInfo = $script:LoadedModules[$moduleName]
                    $lifecycle.CurrentState.LoadOrder += @{
                        Name = $moduleName
                        LoadTime = $moduleInfo.ImportTime
                        Description = $moduleInfo.Description
                    }
                }
                
                $lifecycle.CurrentState.LoadOrder = $lifecycle.CurrentState.LoadOrder | Sort-Object LoadTime
                
                # Check if platform is ready (required modules loaded)
                $requiredModules = $script:CoreModules | Where-Object { $_.Required } | ForEach-Object { $_.Name }
                $requiredLoaded = $requiredModules | Where-Object { $script:LoadedModules.ContainsKey($_) }
                $lifecycle.CurrentState.PlatformReady = $requiredLoaded.Count -eq $requiredModules.Count
            }
            
            # Analyze layers
            foreach ($module in $lifecycle.InitializationOrder) {
                $layer = $module.Layer
                $lifecycle.Layers[$layer].Modules += $module.Name
                
                # Check if module is loaded
                $isLoaded = $script:LoadedModules.ContainsKey($module.Name)
                if (-not $isLoaded -and $lifecycle.Layers[$layer].Status -ne "Degraded") {
                    if ($lifecycle.Layers[$layer].Critical) {
                        $lifecycle.Layers[$layer].Status = "Degraded"
                    } else {
                        $lifecycle.Layers[$layer].Status = "Partial"
                    }
                }
            }
            
            # Set layer status for loaded layers
            foreach ($layerName in $lifecycle.Layers.Keys) {
                if ($lifecycle.Layers[$layerName].Status -eq "Unknown") {
                    $layerModules = $lifecycle.Layers[$layerName].Modules
                    $loadedInLayer = $layerModules | Where-Object { $script:LoadedModules.ContainsKey($_) }
                    
                    if ($loadedInLayer.Count -eq $layerModules.Count) {
                        $lifecycle.Layers[$layerName].Status = "Complete"
                    } elseif ($loadedInLayer.Count -gt 0) {
                        $lifecycle.Layers[$layerName].Status = "Partial"
                    } else {
                        $lifecycle.Layers[$layerName].Status = "Not Loaded"
                    }
                }
            }
            
            # Add dependency information if requested
            if ($IncludeDependencies) {
                $lifecycle.Dependencies = @{
                    # Foundation dependencies
                    "ConfigurationCore" = @("Logging")
                    "ModuleCommunication" = @("Logging", "ConfigurationCore")
                    
                    # Security dependencies
                    "SecurityAutomation" = @("Logging", "SecureCredentials")
                    
                    # Core service dependencies
                    "ProgressTracking" = @("Logging")
                    "LabRunner" = @("Logging", "ConfigurationCore", "ProgressTracking")
                    "ParallelExecution" = @("Logging")
                    
                    # Platform service dependencies
                    "ConfigurationCarousel" = @("ConfigurationCore")
                    "ConfigurationRepository" = @("ConfigurationCore")
                    "OrchestrationEngine" = @("Logging", "ConfigurationCore", "ModuleCommunication", "ProgressTracking")
                    
                    # Infrastructure dependencies
                    "OpenTofuProvider" = @("Logging", "ConfigurationCore", "ProgressTracking")
                    "RemoteConnection" = @("Logging", "SecureCredentials")
                    "SystemMonitoring" = @("Logging", "ConfigurationCore")
                    
                    # Feature dependencies
                    "ISOManager" = @("Logging", "ConfigurationCore", "ProgressTracking")
                    "ISOCustomizer" = @("Logging", "ISOManager")
                    "BackupManager" = @("Logging", "ConfigurationCore")
                    "UnifiedMaintenance" = @("Logging", "BackupManager")
                    
                    # Development dependencies
                    "PatchManager" = @("Logging", "ConfigurationCore", "TestingFramework")
                    "TestingFramework" = @("Logging", "ConfigurationCore")
                    "DevEnvironment" = @("Logging", "ConfigurationCore")
                    "AIToolsIntegration" = @("Logging", "DevEnvironment")
                    "SetupWizard" = @("Logging", "ConfigurationCore", "ProgressTracking")
                    
                    # API dependencies
                    "RestAPIServer" = @("Logging", "ConfigurationCore", "ModuleCommunication", "SecureCredentials")
                }
                
                # Add circular dependency check
                $lifecycle.DependencyAnalysis = @{
                    CircularDependencies = @()
                    MissingDependencies = @()
                    OptionalDependencies = @()
                }
                
                foreach ($module in $lifecycle.Dependencies.Keys) {
                    $deps = $lifecycle.Dependencies[$module]
                    foreach ($dep in $deps) {
                        # Check if dependency is loaded when module is loaded
                        if ($script:LoadedModules.ContainsKey($module) -and -not $script:LoadedModules.ContainsKey($dep)) {
                            $lifecycle.DependencyAnalysis.MissingDependencies += @{
                                Module = $module
                                MissingDependency = $dep
                            }
                        }
                    }
                }
            }
            
            return $lifecycle
            
        } catch {
            Write-CustomLog -Message "Failed to get platform lifecycle: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}