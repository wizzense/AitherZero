function Get-UnifiedConfiguration {
    <#
    .SYNOPSIS
        Gets unified configuration from all subsystems
    .DESCRIPTION
        Retrieves configuration data from ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository
        in a unified format, providing a single point of access to all configuration data
    .PARAMETER Module
        Specific module configuration to retrieve
    .PARAMETER Environment
        Environment-specific configuration to retrieve
    .PARAMETER ConfigurationSet
        Specific configuration set from the carousel
    .PARAMETER IncludeMetadata
        Include metadata information in the response
    .PARAMETER Format
        Output format (Object, JSON, YAML)
    .EXAMPLE
        Get-UnifiedConfiguration
        
        Gets all configuration data in unified format
    .EXAMPLE
        Get-UnifiedConfiguration -Module "LabRunner" -Environment "prod"
        
        Gets configuration for LabRunner module in production environment
    .EXAMPLE
        Get-UnifiedConfiguration -ConfigurationSet "enterprise" -Format JSON
        
        Gets enterprise configuration set as JSON
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'Module')]
        [string]$Module,
        
        [Parameter(ParameterSetName = 'Module')]
        [Parameter(ParameterSetName = 'Environment')]
        [string]$Environment,
        
        [Parameter(ParameterSetName = 'ConfigurationSet')]
        [string]$ConfigurationSet,
        
        [switch]$IncludeMetadata,
        
        [ValidateSet('Object', 'JSON', 'YAML')]
        [string]$Format = 'Object'
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Getting unified configuration (ParameterSet: $($PSCmdlet.ParameterSetName))"
        
        if (-not $script:ModuleInitialized) {
            throw "Configuration Manager not initialized. Run Initialize-ConfigurationManager first."
        }
        
        $result = @{
            Success = $true
            Timestamp = Get-Date
            Source = 'ConfigurationManager'
            ParameterSet = $PSCmdlet.ParameterSetName
            Configuration = @{}
        }
        
        switch ($PSCmdlet.ParameterSetName) {
            'Module' {
                if ($Module) {
                    # Get module-specific configuration
                    if ($script:UnifiedConfigurationStore.Modules.ContainsKey($Module)) {
                        $moduleConfig = $script:UnifiedConfigurationStore.Modules[$Module]
                        
                        # Apply environment-specific overrides if specified
                        if ($Environment -and $script:UnifiedConfigurationStore.Environments.ContainsKey($Environment)) {
                            $envConfig = $script:UnifiedConfigurationStore.Environments[$Environment]
                            if ($envConfig.Settings -and $envConfig.Settings.ContainsKey($Module)) {
                                $envOverrides = $envConfig.Settings[$Module]
                                $moduleConfig = Merge-ConfigurationData -SourceConfiguration $envOverrides -TargetConfiguration $moduleConfig -ConflictStrategy 'Overwrite' -SourceName "Environment-$Environment"
                            }
                        }
                        
                        $result.Configuration = @{
                            Module = $Module
                            Environment = $Environment ?? $script:UnifiedConfigurationStore.CurrentEnvironment
                            Data = $moduleConfig
                        }
                    } else {
                        throw "Module '$Module' not found in configuration store"
                    }
                } else {
                    throw "Module parameter is required for Module parameter set"
                }
            }
            
            'Environment' {
                if ($Environment) {
                    # Get environment-specific configuration
                    if ($script:UnifiedConfigurationStore.Environments.ContainsKey($Environment)) {
                        $envConfig = $script:UnifiedConfigurationStore.Environments[$Environment]
                        
                        $result.Configuration = @{
                            Environment = $Environment
                            Data = $envConfig
                            ModuleOverrides = $envConfig.Settings ?? @{}
                        }
                    } else {
                        throw "Environment '$Environment' not found in configuration store"
                    }
                } else {
                    throw "Environment parameter is required for Environment parameter set"
                }
            }
            
            'ConfigurationSet' {
                if ($ConfigurationSet) {
                    # Get configuration set from carousel
                    if ($script:UnifiedConfigurationStore.Carousel.Configurations.ContainsKey($ConfigurationSet)) {
                        $carouselConfig = $script:UnifiedConfigurationStore.Carousel.Configurations[$ConfigurationSet]
                        
                        $result.Configuration = @{
                            ConfigurationSet = $ConfigurationSet
                            Data = $carouselConfig
                            IsActive = ($ConfigurationSet -eq $script:UnifiedConfigurationStore.Carousel.CurrentConfiguration)
                        }
                        
                        # If the configuration has a path, try to load additional data
                        if ($carouselConfig.path -and (Test-Path $carouselConfig.path)) {
                            try {
                                $additionalConfig = @{}
                                
                                # Look for common configuration files
                                $configFiles = @('app-config.json', 'module-config.json', 'settings.json')
                                foreach ($configFile in $configFiles) {
                                    $filePath = Join-Path $carouselConfig.path $configFile
                                    if (Test-Path $filePath) {
                                        $fileConfig = Get-Content $filePath -Raw | ConvertFrom-Json -AsHashtable
                                        $additionalConfig[$configFile] = $fileConfig
                                    }
                                }
                                
                                if ($additionalConfig.Count -gt 0) {
                                    $result.Configuration.AdditionalData = $additionalConfig
                                }
                                
                            } catch {
                                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to load additional configuration data from $($carouselConfig.path): $_"
                            }
                        }
                    } else {
                        throw "Configuration set '$ConfigurationSet' not found in carousel"
                    }
                } else {
                    throw "ConfigurationSet parameter is required for ConfigurationSet parameter set"
                }
            }
            
            'All' {
                # Get all configuration data
                $result.Configuration = @{
                    Core = @{
                        Modules = $script:UnifiedConfigurationStore.Modules
                        Environments = $script:UnifiedConfigurationStore.Environments
                        CurrentEnvironment = $script:UnifiedConfigurationStore.CurrentEnvironment
                        Schemas = $script:UnifiedConfigurationStore.Schemas
                        HotReload = $script:UnifiedConfigurationStore.HotReload
                        Security = $script:UnifiedConfigurationStore.Security
                    }
                    
                    Carousel = @{
                        CurrentConfiguration = $script:UnifiedConfigurationStore.Carousel.CurrentConfiguration
                        CurrentEnvironment = $script:UnifiedConfigurationStore.Carousel.CurrentEnvironment
                        Configurations = $script:UnifiedConfigurationStore.Carousel.Configurations
                        LastUpdated = $script:UnifiedConfigurationStore.Carousel.LastUpdated
                    }
                    
                    Repository = @{
                        ActiveRepositories = $script:UnifiedConfigurationStore.Repository.ActiveRepositories
                        Templates = $script:UnifiedConfigurationStore.Repository.Templates
                        DefaultProvider = $script:UnifiedConfigurationStore.Repository.DefaultProvider
                        SyncSettings = $script:UnifiedConfigurationStore.Repository.SyncSettings
                    }
                    
                    Events = @{
                        Subscriptions = $script:UnifiedConfigurationStore.Events.Subscriptions.Count
                        HistoryCount = $script:UnifiedConfigurationStore.Events.History.Count
                        RecentEvents = $script:UnifiedConfigurationStore.Events.History | Select-Object -Last 5
                    }
                }
            }
        }
        
        # Include metadata if requested
        if ($IncludeMetadata) {
            $result.Metadata = $script:UnifiedConfigurationStore.Metadata
            $result.StorePath = $script:UnifiedConfigurationStore.StorePath
            $result.ModuleVersion = $script:MODULE_VERSION
            $result.Initialized = $script:ModuleInitialized
        }
        
        # Format output as requested
        switch ($Format) {
            'JSON' {
                $jsonResult = $result | ConvertTo-Json -Depth 20
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration retrieved in JSON format"
                return $jsonResult
            }
            
            'YAML' {
                # Basic YAML conversion (would need a proper YAML module for full support)
                try {
                    if (Get-Module 'powershell-yaml' -ErrorAction SilentlyContinue) {
                        $yamlResult = $result | ConvertTo-Yaml
                        Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration retrieved in YAML format"
                        return $yamlResult
                    } else {
                        Write-ConfigurationLog -Level 'WARNING' -Message "YAML module not available, returning JSON"
                        $jsonResult = $result | ConvertTo-Json -Depth 20
                        return $jsonResult
                    }
                } catch {
                    Write-ConfigurationLog -Level 'WARNING' -Message "YAML conversion failed, returning JSON: $_"
                    $jsonResult = $result | ConvertTo-Json -Depth 20
                    return $jsonResult
                }
            }
            
            'Object' {
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration retrieved as PowerShell object"
                return $result
            }
        }
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to get unified configuration: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date
            Source = 'ConfigurationManager'
            ParameterSet = $PSCmdlet.ParameterSetName
        }
    }
}