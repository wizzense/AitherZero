function Initialize-ConfigurationManager {
    <#
    .SYNOPSIS
        Initializes the unified Configuration Manager system
    .DESCRIPTION
        Consolidates initialization of ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository
        into a single unified configuration management system
    .PARAMETER Force
        Force re-initialization even if already initialized
    .PARAMETER SkipLegacyImport
        Skip importing legacy modules for backward compatibility
    .PARAMETER ConfigurationPath
        Custom path for configuration storage
    .EXAMPLE
        Initialize-ConfigurationManager
        
        Initializes the configuration manager with default settings
    .EXAMPLE
        Initialize-ConfigurationManager -Force -ConfigurationPath "C:\CustomConfig"
        
        Forces re-initialization with a custom configuration path
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$SkipLegacyImport,
        [string]$ConfigurationPath
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Initializing Configuration Manager v$($script:MODULE_VERSION)"
        
        # Check if already initialized
        if ($script:ModuleInitialized -and -not $Force) {
            Write-ConfigurationLog -Level 'INFO' -Message "Configuration Manager already initialized. Use -Force to re-initialize."
            return @{
                Success = $true
                AlreadyInitialized = $true
                Version = $script:MODULE_VERSION
            }
        }
        
        # Initialize paths with custom path if provided
        if ($ConfigurationPath) {
            if (-not (Test-Path $ConfigurationPath)) {
                New-Item -ItemType Directory -Path $ConfigurationPath -Force | Out-Null
            }
            $script:UnifiedConfigurationStore.StorePath = Join-Path $ConfigurationPath 'unified-configuration.json'
        } else {
            Initialize-ConfigurationPaths
        }
        
        # Import legacy modules unless skipped
        if (-not $SkipLegacyImport) {
            Import-LegacyModules -Force:$Force
        }
        
        # Initialize legacy modules for backward compatibility
        $initResults = @{}
        
        # Initialize ConfigurationCore
        if (Get-Command 'Initialize-ConfigurationCore' -ErrorAction SilentlyContinue) {
            try {
                $coreResult = Initialize-ConfigurationCore
                $initResults.ConfigurationCore = @{ Success = $true; Result = $coreResult }
                Write-ConfigurationLog -Level 'SUCCESS' -Message "ConfigurationCore initialized successfully"
            } catch {
                $initResults.ConfigurationCore = @{ Success = $false; Error = $_.Exception.Message }
                Write-ConfigurationLog -Level 'WARNING' -Message "ConfigurationCore initialization failed: $_"
            }
        }
        
        # Initialize carousel registry
        $registryPath = Join-Path $script:UnifiedConfigurationStore.Carousel.CarouselPath "carousel-registry.json"
        if (-not (Test-Path $registryPath) -or $Force) {
            try {
                $carouselRegistry = $script:UnifiedConfigurationStore.Carousel
                $carouselRegistry | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath
                $initResults.ConfigurationCarousel = @{ Success = $true; RegistryPath = $registryPath }
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration Carousel initialized successfully"
            } catch {
                $initResults.ConfigurationCarousel = @{ Success = $false; Error = $_.Exception.Message }
                Write-ConfigurationLog -Level 'WARNING' -Message "Configuration Carousel initialization failed: $_"
            }
        } else {
            $initResults.ConfigurationCarousel = @{ Success = $true; AlreadyExists = $true }
        }
        
        # Initialize repository settings
        try {
            $repositoryDefaults = $script:UnifiedConfigurationStore.Repository
            $initResults.ConfigurationRepository = @{ Success = $true; Templates = $repositoryDefaults.Templates.Keys }
            Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration Repository initialized successfully"
        } catch {
            $initResults.ConfigurationRepository = @{ Success = $false; Error = $_.Exception.Message }
            Write-ConfigurationLog -Level 'WARNING' -Message "Configuration Repository initialization failed: $_"
        }
        
        # Load existing unified configuration
        $configPath = $script:UnifiedConfigurationStore.StorePath
        if (Test-Path $configPath) {
            try {
                $existingConfig = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable -Depth 20
                
                # Merge with current configuration
                foreach ($key in $existingConfig.Keys) {
                    if ($script:UnifiedConfigurationStore.ContainsKey($key)) {
                        $script:UnifiedConfigurationStore[$key] = $existingConfig[$key]
                    }
                }
                
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Loaded existing unified configuration"
                $initResults.ConfigurationLoad = @{ Success = $true; Source = $configPath }
                
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to load existing configuration: $_"
                $initResults.ConfigurationLoad = @{ Success = $false; Error = $_.Exception.Message }
            }
        } else {
            # Save initial configuration
            Save-UnifiedConfiguration
            $initResults.ConfigurationLoad = @{ Success = $true; Created = $true }
        }
        
        # Validate configuration integrity
        $validationResult = Test-ConfigurationIntegrity
        $initResults.Validation = $validationResult
        
        # Mark as initialized
        $script:ModuleInitialized = $true
        
        # Publish initialization event
        try {
            Publish-ConfigurationEvent -EventName 'ConfigurationManagerInitialized' -EventData @{
                Version = $script:MODULE_VERSION
                InitializationTime = Get-Date
                InitResults = $initResults
            }
        } catch {
            Write-ConfigurationLog -Level 'WARNING' -Message "Failed to publish initialization event: $_"
        }
        
        Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration Manager initialization completed successfully"
        
        return @{
            Success = $true
            Version = $script:MODULE_VERSION
            ConfigurationPath = $script:UnifiedConfigurationStore.StorePath
            InitializationResults = $initResults
            ValidationResult = $validationResult
            InitializedComponents = @(
                'ConfigurationCore',
                'ConfigurationCarousel', 
                'ConfigurationRepository'
            )
        }
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Configuration Manager initialization failed: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Version = $script:MODULE_VERSION
        }
    }
}