# AitherZero Configuration Manager Module
# Unified configuration management system consolidating ConfigurationCore, ConfigurationCarousel, and ConfigurationRepository

#Requires -Version 7.0

using namespace System.IO
using namespace System.Security
using namespace System.Text.Json
using namespace System.Collections.Generic

# Module-level constants
$script:MODULE_VERSION = '1.0.0'
$script:CONFIG_FILE_VERSION = '1.0'
$script:MAX_BACKUP_COUNT = 10
$script:CONFIG_FILE_PERMISSIONS = if ($IsWindows) { 'Owner' } else { '600' }

# Initialize project root
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"
$script:ProjectRoot = Find-ProjectRoot

# Module state
$script:ModuleInitialized = $false
$script:LegacyModulesLoaded = @{}

# Unified configuration store combining all three modules
$script:UnifiedConfigurationStore = @{
    # Core configuration (from ConfigurationCore)
    Metadata = @{
        Version = $script:CONFIG_FILE_VERSION
        LastModified = Get-Date
        CreatedBy = $env:USERNAME
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } else { 'macOS' }
        PSVersion = $PSVersionTable.PSVersion.ToString()
        ModuleVersion = $script:MODULE_VERSION
        ConsolidatedModules = @('ConfigurationCore', 'ConfigurationCarousel', 'ConfigurationRepository')
    }
    Modules = @{}
    Environments = @{
        'default' = @{
            Name = 'default'
            Description = 'Default configuration environment'
            Settings = @{}
            Created = Get-Date
            CreatedBy = $env:USERNAME
        }
    }
    CurrentEnvironment = 'default'
    Schemas = @{}
    HotReload = @{
        Enabled = $false
        Watchers = @{}
        LastReload = $null
    }
    Security = @{
        EncryptionEnabled = $false
        HashValidation = $true
        LastSecurityCheck = Get-Date
    }
    StorePath = $null
    
    # Carousel configuration (from ConfigurationCarousel)
    Carousel = @{
        Version = "1.0"
        CurrentConfiguration = "default"
        CurrentEnvironment = "dev"
        Configurations = @{
            default = @{
                name = "default"
                description = "Default AitherZero configuration"
                path = "../../configs"
                type = "builtin"
                environments = @("dev", "staging", "prod")
            }
        }
        CarouselPath = $null
        BackupPath = $null
        EnvironmentsPath = $null
        LastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    
    # Repository configuration (from ConfigurationRepository)
    Repository = @{
        ActiveRepositories = @{}
        Templates = @{
            'default' = @{ Description = 'Standard AitherZero configuration template' }
            'minimal' = @{ Description = 'Minimal configuration template' }
            'enterprise' = @{ Description = 'Enterprise-grade configuration template' }
            'custom' = @{ Description = 'Custom configuration template' }
        }
        DefaultProvider = 'github'
        SyncSettings = @{
            AutoSync = $false
            BackupBeforeSync = $true
            ConflictResolution = 'prompt'
        }
    }
    
    # Event system
    Events = @{
        Subscriptions = @{}
        History = @()
        MaxHistorySize = 1000
    }
}

# Enhanced logging function with fallback
function Write-ConfigurationLog {
    param(
        [string]$Level = 'INFO',
        [string]$Message,
        [string]$Component = 'ConfigurationManager'
    )
    
    # Normalize level names for compatibility
    $normalizedLevel = switch ($Level.ToUpper()) {
        'WARNING' { 'WARN' }
        'SUCCESS' { 'SUCCESS' }
        'DEBUG' { 'DEBUG' }
        'ERROR' { 'ERROR' }
        'INFORMATION' { 'INFO' }
        default { 'INFO' }
    }
    
    if (Get-Command 'Write-CustomLog' -ErrorAction SilentlyContinue) {
        try {
            Write-CustomLog -Level $normalizedLevel -Message "[$Component] $Message"
        } catch {
            # Fallback to simple output if Write-CustomLog fails
            Write-Host "[$normalizedLevel] [$Component] $Message"
        }
    } else {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $color = switch ($normalizedLevel) {
            'ERROR' { 'Red' }
            'WARN' { 'Yellow' }
            'SUCCESS' { 'Green' }
            'DEBUG' { 'Gray' }
            default { 'White' }
        }
        Write-Host "[$timestamp] [$normalizedLevel] [$Component] $Message" -ForegroundColor $color
    }
}

# Initialize unified configuration paths
function Initialize-ConfigurationPaths {
    try {
        # Platform-specific configuration paths
        if ($IsWindows) {
            $configDir = Join-Path $env:APPDATA 'AitherZero'
        } elseif ($IsLinux -or $IsMacOS) {
            $configDir = Join-Path $env:HOME '.aitherzero'
        } else {
            throw "Unsupported platform for configuration storage"
        }
        
        # Set core paths
        $script:UnifiedConfigurationStore.StorePath = Join-Path $configDir 'unified-configuration.json'
        
        # Set carousel paths
        $script:UnifiedConfigurationStore.Carousel.CarouselPath = Join-Path $script:ProjectRoot "configs/carousel"
        $script:UnifiedConfigurationStore.Carousel.BackupPath = Join-Path $script:ProjectRoot "configs/backups"
        $script:UnifiedConfigurationStore.Carousel.EnvironmentsPath = Join-Path $script:ProjectRoot "configs/environments"
        
        # Create directories with appropriate permissions
        $directories = @(
            $configDir,
            (Join-Path $configDir 'backups'),
            $script:UnifiedConfigurationStore.Carousel.CarouselPath,
            $script:UnifiedConfigurationStore.Carousel.BackupPath,
            $script:UnifiedConfigurationStore.Carousel.EnvironmentsPath
        )
        
        foreach ($dir in $directories) {
            if (-not (Test-Path $dir)) {
                $directory = New-Item -ItemType Directory -Path $dir -Force
                
                # Set directory permissions (Unix-like systems)
                if ($IsLinux -or $IsMacOS) {
                    chmod 700 $dir 2>/dev/null
                }
            }
        }
        
        Write-ConfigurationLog -Level 'DEBUG' -Message "Configuration paths initialized successfully"
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to initialize configuration paths: $_"
        throw
    }
}

# Load legacy modules for compatibility
function Import-LegacyModules {
    [CmdletBinding()]
    param(
        [switch]$Force
    )
    
    try {
        $legacyModules = @(
            @{ Name = 'ConfigurationCore'; Path = Join-Path $script:ProjectRoot "aither-core/modules/ConfigurationCore" }
            @{ Name = 'ConfigurationCarousel'; Path = Join-Path $script:ProjectRoot "aither-core/modules/ConfigurationCarousel" }
            @{ Name = 'ConfigurationRepository'; Path = Join-Path $script:ProjectRoot "aither-core/modules/ConfigurationRepository" }
        )
        
        foreach ($moduleInfo in $legacyModules) {
            if (Test-Path $moduleInfo.Path) {
                try {
                    if ($Force -or -not $script:LegacyModulesLoaded[$moduleInfo.Name]) {
                        Import-Module $moduleInfo.Path -Force:$Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
                        $script:LegacyModulesLoaded[$moduleInfo.Name] = $true
                        Write-ConfigurationLog -Level 'DEBUG' -Message "Imported legacy module: $($moduleInfo.Name)"
                    }
                } catch {
                    Write-ConfigurationLog -Level 'WARNING' -Message "Failed to import legacy module $($moduleInfo.Name): $_"
                }
            } else {
                Write-ConfigurationLog -Level 'WARNING' -Message "Legacy module path not found: $($moduleInfo.Path)"
            }
        }
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to import legacy modules: $_"
    }
}

# Import and load all function files
function Import-ConfigurationFunctions {
    try {
        # Get function files
        $publicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
        $privateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue)
        
        Write-ConfigurationLog -Level 'INFO' -Message "Loading $($privateFunctions.Count) private and $($publicFunctions.Count) public functions"
        
        # Import private functions first
        foreach ($functionFile in $privateFunctions) {
            try {
                . $functionFile.FullName
                Write-ConfigurationLog -Level 'DEBUG' -Message "Loaded private function: $($functionFile.BaseName)"
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to load private function $($functionFile.Name): $_"
            }
        }
        
        # Import public functions and collect for export
        $functionsToExport = @()
        foreach ($functionFile in $publicFunctions) {
            try {
                . $functionFile.FullName
                $functionName = [System.IO.Path]::GetFileNameWithoutExtension($functionFile.Name)
                if (Get-Command $functionName -ErrorAction SilentlyContinue) {
                    $functionsToExport += $functionName
                    Write-ConfigurationLog -Level 'DEBUG' -Message "Loaded public function: $functionName"
                }
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to load public function $($functionFile.Name): $_"
            }
        }
        
        # Export successfully loaded functions
        if ($functionsToExport.Count -gt 0) {
            Export-ModuleMember -Function $functionsToExport
            Write-ConfigurationLog -Level 'SUCCESS' -Message "Successfully exported $($functionsToExport.Count) functions"
        } else {
            Write-ConfigurationLog -Level 'WARNING' -Message "No functions available for export"
        }
        
        # Export aliases for backward compatibility
        $aliases = @(
            @{ Name = 'Get-ConfigCarouselRegistry'; Value = 'Get-AvailableConfigurations' }
            @{ Name = 'Set-ConfigCarouselRegistry'; Value = 'Switch-ConfigurationSet' }
            @{ Name = 'Initialize-ConfigCarousel'; Value = 'Initialize-ConfigurationManager' }
        )
        
        foreach ($alias in $aliases) {
            try {
                New-Alias -Name $alias.Name -Value $alias.Value -Force -ErrorAction SilentlyContinue
                Write-ConfigurationLog -Level 'DEBUG' -Message "Created alias: $($alias.Name) -> $($alias.Value)"
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to create alias $($alias.Name): $_"
            }
        }
        
        Export-ModuleMember -Alias $aliases.Name
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Critical error during function import: $_"
        throw
    }
}

# Module initialization function
function Initialize-ConfigurationManagerModule {
    [CmdletBinding()]
    param()
    
    try {
        if ($script:ModuleInitialized) {
            Write-ConfigurationLog -Level 'DEBUG' -Message "Module already initialized"
            return
        }
        
        Write-ConfigurationLog -Level 'INFO' -Message "Initializing Configuration Manager v$($script:MODULE_VERSION)"
        
        # Initialize paths
        Initialize-ConfigurationPaths
        
        # Import legacy modules for compatibility
        Import-LegacyModules
        
        # Load existing configuration if available
        $configPath = $script:UnifiedConfigurationStore.StorePath
        if (Test-Path $configPath) {
            try {
                $existingConfig = Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable -Depth 20
                
                # Merge existing configuration with defaults
                foreach ($key in $existingConfig.Keys) {
                    if ($script:UnifiedConfigurationStore.ContainsKey($key)) {
                        $script:UnifiedConfigurationStore[$key] = $existingConfig[$key]
                    }
                }
                
                Write-ConfigurationLog -Level 'SUCCESS' -Message "Loaded existing configuration from $configPath"
                
            } catch {
                Write-ConfigurationLog -Level 'WARNING' -Message "Failed to load existing configuration: $_"
                # Continue with defaults
            }
        }
        
        # Initialize carousel registry if needed
        $registryPath = Join-Path $script:UnifiedConfigurationStore.Carousel.CarouselPath "carousel-registry.json"
        if (-not (Test-Path $registryPath)) {
            $defaultRegistry = $script:UnifiedConfigurationStore.Carousel
            $defaultRegistry | ConvertTo-Json -Depth 10 | Set-Content -Path $registryPath
            Write-ConfigurationLog -Level 'INFO' -Message "Created default carousel registry"
        }
        
        $script:ModuleInitialized = $true
        Write-ConfigurationLog -Level 'SUCCESS' -Message "Configuration Manager initialization completed"
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to initialize Configuration Manager: $_"
        throw
    }
}

# Save unified configuration to disk
function Save-UnifiedConfiguration {
    [CmdletBinding()]
    param()
    
    try {
        $configPath = $script:UnifiedConfigurationStore.StorePath
        
        # Update metadata
        $script:UnifiedConfigurationStore.Metadata.LastModified = Get-Date
        
        # Create backup if existing config exists
        if (Test-Path $configPath) {
            $backupPath = "$configPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $configPath $backupPath -ErrorAction SilentlyContinue
        }
        
        # Save configuration
        $script:UnifiedConfigurationStore | ConvertTo-Json -Depth 20 | Set-Content -Path $configPath -Encoding UTF8
        
        # Set file permissions
        if ($IsLinux -or $IsMacOS) {
            chmod 600 $configPath 2>/dev/null
        }
        
        Write-ConfigurationLog -Level 'DEBUG' -Message "Unified configuration saved to $configPath"
        
    } catch {
        Write-ConfigurationLog -Level 'ERROR' -Message "Failed to save unified configuration: $_"
        throw
    }
}

# Import logging module if available
$loggingModule = Join-Path $script:ProjectRoot "aither-core/modules/Logging"
if (Test-Path $loggingModule) {
    try {
        Import-Module $loggingModule -Force -ErrorAction SilentlyContinue
        Write-ConfigurationLog -Level 'DEBUG' -Message "Imported Logging module"
    } catch {
        Write-ConfigurationLog -Level 'WARNING' -Message "Failed to import Logging module: $_"
    }
}

# Initialize the module
try {
    Initialize-ConfigurationManagerModule
    
    # Import all functions
    Import-ConfigurationFunctions
    
} catch {
    Write-ConfigurationLog -Level 'ERROR' -Message "Failed to initialize Configuration Manager module: $_"
    throw
}

# Module cleanup
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    try {
        Save-UnifiedConfiguration
        Write-ConfigurationLog -Level 'INFO' -Message "Configuration Manager module cleanup completed"
    } catch {
        Write-ConfigurationLog -Level 'WARNING' -Message "Module cleanup failed: $_"
    }
}