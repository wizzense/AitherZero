function Initialize-ConfigurationCore {
    <#
    .SYNOPSIS
        Initialize the ConfigurationCore system (Legacy Compatibility Function)
    .DESCRIPTION
        Initializes the ConfigurationCore subsystem within the unified Configuration Manager.
        This function maintains compatibility with the original ConfigurationCore module.
    .PARAMETER ConfigPath
        Path to the main configuration file
    .PARAMETER Environment
        Initial environment to load (default: 'default')
    .PARAMETER Force
        Force reinitialization even if already initialized
    .EXAMPLE
        Initialize-ConfigurationCore
        
        Initialize with default settings
    .EXAMPLE
        Initialize-ConfigurationCore -ConfigPath "C:\Config\app.json" -Environment "prod"
        
        Initialize with custom configuration file and production environment
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigPath,
        
        [Parameter()]
        [string]$Environment = 'default',
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        Write-ConfigurationLog -Level 'INFO' -Message "Initializing ConfigurationCore subsystem"
        
        # Ensure Configuration Manager is initialized
        if (-not $script:ModuleInitialized) {
            Write-ConfigurationLog -Level 'INFO' -Message "Configuration Manager not initialized, initializing now"
            $initResult = Initialize-ConfigurationManager -Force:$Force
            if (-not $initResult.Success) {
                throw "Failed to initialize Configuration Manager: $($initResult.Error)"
            }
        }
        
        # Load configuration from file if provided
        if ($ConfigPath -and (Test-Path $ConfigPath)) {
            try {
                Write-ConfigurationLog -Level 'INFO' -Message "Loading configuration from: $ConfigPath"
                $configContent = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
                
                # Merge loaded configuration into unified store
                if ($configContent.Modules) {
                    foreach ($moduleName in $configContent.Modules.Keys) {
                        $script:UnifiedConfigurationStore.Modules[$moduleName] = $configContent.Modules[$moduleName]
                    }
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Loaded $($configContent.Modules.Count) module configurations"
                }
                
                if ($configContent.Environments) {
                    foreach ($envName in $configContent.Environments.Keys) {
                        $script:UnifiedConfigurationStore.Environments[$envName] = $configContent.Environments[$envName]
                    }
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Loaded $($configContent.Environments.Count) environment configurations"
                }
                
                if ($configContent.Schemas) {
                    foreach ($schemaName in $configContent.Schemas.Keys) {
                        $script:UnifiedConfigurationStore.Schemas[$schemaName] = $configContent.Schemas[$schemaName]
                    }
                    Write-ConfigurationLog -Level 'SUCCESS' -Message "Loaded $($configContent.Schemas.Count) configuration schemas"
                }
                
            } catch {
                Write-ConfigurationLog -Level 'ERROR' -Message "Failed to load configuration from file: $_"
                if (-not $Force) {
                    throw "Configuration file loading failed: $_"
                }
            }
        }
        
        # Set active environment
        if ($script:UnifiedConfigurationStore.Environments.ContainsKey($Environment)) {
            $script:UnifiedConfigurationStore.CurrentEnvironment = $Environment
            Write-ConfigurationLog -Level 'INFO' -Message "Set active environment: $Environment"
        } else {
            if ($Environment -ne 'default') {
                Write-ConfigurationLog -Level 'WARNING' -Message "Environment '$Environment' not found, creating default environment"
                
                # Create the requested environment
                $script:UnifiedConfigurationStore.Environments[$Environment] = @{
                    Name = $Environment
                    Description = "Environment created by Initialize-ConfigurationCore"
                    Settings = @{}
                    Created = Get-Date
                    CreatedBy = $env:USERNAME
                }
                $script:UnifiedConfigurationStore.CurrentEnvironment = $Environment
            }
        }
        
        # Initialize default schemas for known modules
        Initialize-DefaultSchemas
        
        # Save initial state
        try {
            Save-UnifiedConfiguration
            Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration saved successfully"
        } catch {
            Write-ConfigurationLog -Level 'WARNING' -Message "Failed to save configuration: $_"
        }
        
        # Publish initialization event
        Publish-ConfigurationEvent -EventName 'ConfigurationCoreInitialized' -EventData @{
            Environment = $Environment
            ConfigPath = $ConfigPath
            InitializedAt = Get-Date
        } -Priority 'Normal'
        
        Write-ConfigurationLog -Level 'SUCCESS' -Message "ConfigurationCore subsystem initialized successfully"
        
        return @{
            Success = $true
            Environment = $script:UnifiedConfigurationStore.CurrentEnvironment
            ModulesLoaded = $script:UnifiedConfigurationStore.Modules.Count
            EnvironmentsAvailable = $script:UnifiedConfigurationStore.Environments.Count
            SchemasLoaded = $script:UnifiedConfigurationStore.Schemas.Count
            ConfigPath = $ConfigPath
        }
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to initialize ConfigurationCore: $_"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Environment = $Environment
            ConfigPath = $ConfigPath
        }
    }
}

# Helper function for initializing default schemas
function Initialize-DefaultSchemas {
    try {
        # Define default schemas for common AitherZero modules
        $defaultSchemas = @{
            'LabRunner' = @{
                type = 'object'
                properties = @{
                    MaxConcurrency = @{ type = 'integer'; minimum = 1; maximum = 10 }
                    TimeoutMinutes = @{ type = 'integer'; minimum = 1; maximum = 120 }
                    LogLevel = @{ type = 'string'; enum = @('Debug', 'Info', 'Warning', 'Error') }
                    RetryAttempts = @{ type = 'integer'; minimum = 0; maximum = 5 }
                }
                required = @('MaxConcurrency', 'TimeoutMinutes')
            }
            
            'PatchManager' = @{
                type = 'object'
                properties = @{
                    AutoMerge = @{ type = 'boolean' }
                    DefaultBranch = @{ type = 'string'; default = 'main' }
                    CreatePR = @{ type = 'boolean'; default = $true }
                    RequireApproval = @{ type = 'boolean'; default = $false }
                }
                required = @('DefaultBranch')
            }
            
            'BackupManager' = @{
                type = 'object'
                properties = @{
                    BackupPath = @{ type = 'string' }
                    RetentionDays = @{ type = 'integer'; minimum = 1; maximum = 365 }
                    CompressionEnabled = @{ type = 'boolean'; default = $true }
                    ScheduleEnabled = @{ type = 'boolean'; default = $false }
                }
                required = @('BackupPath', 'RetentionDays')
            }
            
            'OpenTofuProvider' = @{
                type = 'object'
                properties = @{
                    Provider = @{ type = 'string'; enum = @('aws', 'azure', 'gcp', 'vmware', 'hyperv') }
                    Region = @{ type = 'string' }
                    EnableLogging = @{ type = 'boolean'; default = $true }
                    StateBackend = @{ type = 'string'; enum = @('local', 's3', 'azurerm', 'gcs') }
                }
                required = @('Provider')
            }
            
            'SecureCredentials' = @{
                type = 'object'
                properties = @{
                    EncryptionEnabled = @{ type = 'boolean'; default = $true }
                    KeyRotationDays = @{ type = 'integer'; minimum = 30; maximum = 365 }
                    BackupEnabled = @{ type = 'boolean'; default = $true }
                    AuditLogging = @{ type = 'boolean'; default = $true }
                }
                required = @('EncryptionEnabled')
            }
        }
        
        # Register schemas that don't already exist
        $schemasRegistered = 0
        foreach ($moduleName in $defaultSchemas.Keys) {
            if (-not $script:UnifiedConfigurationStore.Schemas.ContainsKey($moduleName)) {
                $script:UnifiedConfigurationStore.Schemas[$moduleName] = $defaultSchemas[$moduleName]
                $schemasRegistered++
            }
        }
        
        if ($schemasRegistered -gt 0) {
            Write-ConfigurationLog -Level 'INFO' -Message "Registered $schemasRegistered default configuration schemas"
        }
        
    } catch {
        Write-ConfigurationLog -Level 'WARNING' -Message "Failed to initialize default schemas: $_"
    }
}