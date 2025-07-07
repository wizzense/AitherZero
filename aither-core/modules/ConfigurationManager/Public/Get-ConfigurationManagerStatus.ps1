function Get-ConfigurationManagerStatus {
    <#
    .SYNOPSIS
        Gets the current status of the Configuration Manager system
    .DESCRIPTION
        Provides comprehensive status information about all configuration subsystems
        including ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository
    .PARAMETER IncludeDetails
        Include detailed information about each subsystem
    .PARAMETER CheckHealth
        Perform health checks on all subsystems
    .EXAMPLE
        Get-ConfigurationManagerStatus
        
        Gets basic status information
    .EXAMPLE
        Get-ConfigurationManagerStatus -IncludeDetails -CheckHealth
        
        Gets detailed status with health checks
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeDetails,
        [switch]$CheckHealth
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Getting Configuration Manager status"
        
        $status = @{
            Success = $true
            ModuleVersion = $script:MODULE_VERSION
            IsInitialized = $script:ModuleInitialized
            ConfigurationPath = $script:UnifiedConfigurationStore.StorePath
            LastModified = $script:UnifiedConfigurationStore.Metadata.LastModified
            Platform = $script:UnifiedConfigurationStore.Metadata.Platform
            CurrentEnvironment = $script:UnifiedConfigurationStore.CurrentEnvironment
            ConsolidatedModules = $script:UnifiedConfigurationStore.Metadata.ConsolidatedModules
        }
        
        # Basic subsystem status
        $status.Subsystems = @{
            ConfigurationCore = @{
                Enabled = $true
                ModulesRegistered = $script:UnifiedConfigurationStore.Modules.Count
                EnvironmentsConfigured = $script:UnifiedConfigurationStore.Environments.Count
                HotReloadEnabled = $script:UnifiedConfigurationStore.HotReload.Enabled
                SchemasRegistered = $script:UnifiedConfigurationStore.Schemas.Count
            }
            ConfigurationCarousel = @{
                Enabled = $true
                CurrentConfiguration = $script:UnifiedConfigurationStore.Carousel.CurrentConfiguration
                CurrentEnvironment = $script:UnifiedConfigurationStore.Carousel.CurrentEnvironment
                AvailableConfigurations = $script:UnifiedConfigurationStore.Carousel.Configurations.Count
                LastUpdated = $script:UnifiedConfigurationStore.Carousel.LastUpdated
            }
            ConfigurationRepository = @{
                Enabled = $true
                ActiveRepositories = $script:UnifiedConfigurationStore.Repository.ActiveRepositories.Count
                AvailableTemplates = $script:UnifiedConfigurationStore.Repository.Templates.Count
                DefaultProvider = $script:UnifiedConfigurationStore.Repository.DefaultProvider
                AutoSync = $script:UnifiedConfigurationStore.Repository.SyncSettings.AutoSync
            }
        }
        
        # Event system status
        $status.EventSystem = @{
            Enabled = $true
            ActiveSubscriptions = $script:UnifiedConfigurationStore.Events.Subscriptions.Count
            EventHistory = $script:UnifiedConfigurationStore.Events.History.Count
            MaxHistorySize = $script:UnifiedConfigurationStore.Events.MaxHistorySize
        }
        
        # Legacy module compatibility
        $status.LegacyModules = @{}
        foreach ($moduleName in $script:LegacyModulesLoaded.Keys) {
            $status.LegacyModules[$moduleName] = @{
                Loaded = $script:LegacyModulesLoaded[$moduleName]
                Available = (Get-Module $moduleName -ErrorAction SilentlyContinue) -ne $null
            }
        }
        
        # Include detailed information if requested
        if ($IncludeDetails) {
            $status.Details = @{
                ConfigurationStore = @{
                    StorePath = $script:UnifiedConfigurationStore.StorePath
                    FileExists = Test-Path $script:UnifiedConfigurationStore.StorePath
                    SecuritySettings = $script:UnifiedConfigurationStore.Security
                    Metadata = $script:UnifiedConfigurationStore.Metadata
                }
                
                Carousel = @{
                    Paths = @{
                        CarouselPath = $script:UnifiedConfigurationStore.Carousel.CarouselPath
                        BackupPath = $script:UnifiedConfigurationStore.Carousel.BackupPath
                        EnvironmentsPath = $script:UnifiedConfigurationStore.Carousel.EnvironmentsPath
                    }
                    Configurations = $script:UnifiedConfigurationStore.Carousel.Configurations
                }
                
                Repository = @{
                    Templates = $script:UnifiedConfigurationStore.Repository.Templates
                    SyncSettings = $script:UnifiedConfigurationStore.Repository.SyncSettings
                    ActiveRepositories = $script:UnifiedConfigurationStore.Repository.ActiveRepositories
                }
                
                Environments = $script:UnifiedConfigurationStore.Environments
                RegisteredModules = $script:UnifiedConfigurationStore.Modules.Keys
            }
        }
        
        # Perform health checks if requested
        if ($CheckHealth) {
            $healthChecks = @{
                OverallHealth = 'Healthy'
                Issues = @()
                Warnings = @()
                Checks = @{}
            }
            
            # Check configuration file integrity
            $configPath = $script:UnifiedConfigurationStore.StorePath
            if (Test-Path $configPath) {
                try {
                    Get-Content $configPath -Raw | ConvertFrom-Json | Out-Null
                    $healthChecks.Checks.ConfigurationFile = @{ Status = 'Healthy'; Message = 'Configuration file is valid JSON' }
                } catch {
                    $healthChecks.Checks.ConfigurationFile = @{ Status = 'Error'; Message = "Configuration file is corrupted: $_" }
                    $healthChecks.Issues += "Configuration file corruption detected"
                    $healthChecks.OverallHealth = 'Unhealthy'
                }
            } else {
                $healthChecks.Checks.ConfigurationFile = @{ Status = 'Warning'; Message = 'Configuration file does not exist' }
                $healthChecks.Warnings += "Configuration file missing"
                if ($healthChecks.OverallHealth -eq 'Healthy') {
                    $healthChecks.OverallHealth = 'Warning'
                }
            }
            
            # Check directory permissions
            $configDir = Split-Path $configPath -Parent
            if (Test-Path $configDir) {
                $healthChecks.Checks.DirectoryPermissions = @{ Status = 'Healthy'; Message = 'Configuration directory accessible' }
            } else {
                $healthChecks.Checks.DirectoryPermissions = @{ Status = 'Error'; Message = 'Configuration directory not accessible' }
                $healthChecks.Issues += "Configuration directory access issues"
                $healthChecks.OverallHealth = 'Unhealthy'
            }
            
            # Check carousel registry
            $registryPath = Join-Path $script:UnifiedConfigurationStore.Carousel.CarouselPath "carousel-registry.json"
            if (Test-Path $registryPath) {
                try {
                    Get-Content $registryPath -Raw | ConvertFrom-Json | Out-Null
                    $healthChecks.Checks.CarouselRegistry = @{ Status = 'Healthy'; Message = 'Carousel registry is valid' }
                } catch {
                    $healthChecks.Checks.CarouselRegistry = @{ Status = 'Warning'; Message = "Carousel registry issues: $_" }
                    $healthChecks.Warnings += "Carousel registry validation failed"
                    if ($healthChecks.OverallHealth -eq 'Healthy') {
                        $healthChecks.OverallHealth = 'Warning'
                    }
                }
            } else {
                $healthChecks.Checks.CarouselRegistry = @{ Status = 'Warning'; Message = 'Carousel registry not found' }
                $healthChecks.Warnings += "Carousel registry missing"
                if ($healthChecks.OverallHealth -eq 'Healthy') {
                    $healthChecks.OverallHealth = 'Warning'
                }
            }
            
            # Check legacy module compatibility
            foreach ($moduleName in @('ConfigurationCore', 'ConfigurationCarousel', 'ConfigurationRepository')) {
                if (Get-Module $moduleName -ErrorAction SilentlyContinue) {
                    $healthChecks.Checks."Legacy$moduleName" = @{ Status = 'Healthy'; Message = "Legacy module $moduleName is available" }
                } else {
                    $healthChecks.Checks."Legacy$moduleName" = @{ Status = 'Warning'; Message = "Legacy module $moduleName not loaded" }
                    $healthChecks.Warnings += "Legacy module $moduleName unavailable"
                    if ($healthChecks.OverallHealth -eq 'Healthy') {
                        $healthChecks.OverallHealth = 'Warning'
                    }
                }
            }
            
            # Check for Git availability (needed for repository features)
            if (Get-Command git -ErrorAction SilentlyContinue) {
                $healthChecks.Checks.GitAvailability = @{ Status = 'Healthy'; Message = 'Git is available for repository operations' }
            } else {
                $healthChecks.Checks.GitAvailability = @{ Status = 'Warning'; Message = 'Git not available - repository features limited' }
                $healthChecks.Warnings += "Git not available for repository operations"
                if ($healthChecks.OverallHealth -eq 'Healthy') {
                    $healthChecks.OverallHealth = 'Warning'
                }
            }
            
            $status.HealthCheck = $healthChecks
        }
        
        # Calculate summary statistics
        $status.Summary = @{
            TotalConfigurations = $script:UnifiedConfigurationStore.Carousel.Configurations.Count
            TotalEnvironments = $script:UnifiedConfigurationStore.Environments.Count
            TotalModulesRegistered = $script:UnifiedConfigurationStore.Modules.Count
            TotalActiveRepositories = $script:UnifiedConfigurationStore.Repository.ActiveRepositories.Count
            TotalEventSubscriptions = $script:UnifiedConfigurationStore.Events.Subscriptions.Count
            ConfigurationFileSize = if (Test-Path $script:UnifiedConfigurationStore.StorePath) { 
                (Get-Item $script:UnifiedConfigurationStore.StorePath).Length 
            } else { 0 }
        }
        
        Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration Manager status retrieved successfully"
        
        return $status
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to get Configuration Manager status: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            ModuleVersion = $script:MODULE_VERSION
            IsInitialized = $script:ModuleInitialized
        }
    }
}