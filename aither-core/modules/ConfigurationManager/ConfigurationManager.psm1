#Requires -Version 7.0

<#
.SYNOPSIS
    Unified Configuration Management Module for AitherZero Infrastructure Automation

.DESCRIPTION
    This module consolidates all configuration management functionality across the
    AitherZero platform, including configuration stores, environment management,
    carousel operations, and repository integration. It provides a single unified
    interface for all configuration-related operations.

.FEATURES
    - Unified configuration store management
    - Multi-environment configuration support
    - Configuration carousel operations
    - Repository-based configuration management
    - Event-driven configuration updates
    - Comprehensive testing and validation
    - Cross-platform compatibility

.NOTES
    This module integrates with:
    - ConfigurationCore (unified store)
    - ConfigurationCarousel (multi-environment)
    - ConfigurationRepository (Git-based configurations)
    - Logging (centralized logging)
    - ModuleCommunication (event system)
#>

# Error handling
$ErrorActionPreference = 'Stop'

# Module-level variables
$script:MODULE_VERSION = "1.0.0"
$script:ModuleInitialized = $false
$script:UnifiedConfigurationStore = @{}

# Get module root path
$moduleRoot = $PSScriptRoot
if (-not $moduleRoot) {
    $moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Try to import Logging module
try {
    $loggingModule = Join-Path (Split-Path $moduleRoot -Parent) "Logging"
    if (Test-Path $loggingModule) {
        Import-Module $loggingModule -Force -ErrorAction Stop
        Write-Verbose "Logging module imported successfully"
    }
} catch {
    Write-Warning "Could not import Logging module: $_"
    # Provide fallback logging function
    function Write-ConfigurationLog {
        param($Level, $Message)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'ERROR' { 'Red' }
            'WARNING' { 'Yellow' }
            default { 'White' }
        }
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# Ensure logging function is available
if (-not (Get-Command Write-ConfigurationLog -ErrorAction SilentlyContinue)) {
    function Write-ConfigurationLog {
        param($Level, $Message)
        Write-CustomLog -Level $Level -Message $Message
    }
}

# Import Private functions
$privateFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load private function $($function.BaseName): $_"
    }
}

# Import Public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded public function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load public function $($function.BaseName): $_"
    }
}

# Initialize the unified configuration store
try {
    $script:UnifiedConfigurationStore = @{
        Metadata = @{
            Version = $script:MODULE_VERSION
            LastModified = Get-Date
            Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        }
        Modules = @{}
        Environments = @{
            default = @{
                Name = 'default'
                Description = 'Default configuration environment'
                Settings = @{}
                Created = Get-Date
                CreatedBy = $env:USERNAME
            }
        }
        CurrentEnvironment = 'default'
        Carousel = @{
            Configurations = @{}
            CurrentConfiguration = 'default'
            Registry = @{}
        }
        Repository = @{
            Templates = @{}
            DefaultProvider = 'filesystem'
            Settings = @{}
        }
        Events = @{
            Subscriptions = @()
            History = @()
        }
        Security = @{
            HashValidation = $true
            EncryptionEnabled = $false
        }
        StorePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'unified-config.json'
    }
    
    # Create storage directory if it doesn't exist
    $storeDir = Split-Path $script:UnifiedConfigurationStore.StorePath -Parent
    if (-not (Test-Path $storeDir)) {
        New-Item -Path $storeDir -ItemType Directory -Force | Out-Null
    }
    
    # Try to load existing configuration
    if (Test-Path $script:UnifiedConfigurationStore.StorePath) {
        try {
            $existingConfig = Get-Content $script:UnifiedConfigurationStore.StorePath -Raw | ConvertFrom-Json -AsHashtable
            if ($existingConfig -and $existingConfig.Metadata) {
                # Merge with existing configuration
                foreach ($key in $existingConfig.Keys) {
                    if ($key -ne 'Metadata') {
                        $script:UnifiedConfigurationStore[$key] = $existingConfig[$key]
                    }
                }
                Write-Verbose "Loaded existing configuration from $($script:UnifiedConfigurationStore.StorePath)"
            }
        } catch {
            Write-Warning "Failed to load existing configuration: $_"
        }
    }
    
    $script:ModuleInitialized = $true
    Write-Verbose "ConfigurationManager module initialized successfully"
    
} catch {
    Write-Warning "Failed to initialize ConfigurationManager: $_"
    $script:ModuleInitialized = $false
}

# Helper function to save configuration
function Save-UnifiedConfiguration {
    try {
        $script:UnifiedConfigurationStore.Metadata.LastModified = Get-Date
        $script:UnifiedConfigurationStore | ConvertTo-Json -Depth 20 | Set-Content $script:UnifiedConfigurationStore.StorePath -Encoding UTF8
        Write-Verbose "Configuration saved to $($script:UnifiedConfigurationStore.StorePath)"
    } catch {
        Write-Warning "Failed to save configuration: $_"
    }
}

# Export only the main public functions
Export-ModuleMember -Function @(
    'Test-ConfigurationManager'
)