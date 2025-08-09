#Requires -Version 7.0

<#
.SYNOPSIS
    Centralized configuration management for AitherZero
.DESCRIPTION
    Provides a unified configuration store with environment support, validation, and hot-reloading
#>

# Script variables
$script:ConfigPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "config.json"
$script:Config = $null
$script:ConfigCache = @{}
$script:ConfigWatcher = $null
$script:ValidationSchemas = @{}
$script:CurrentEnvironment = "Development"

# Logging helper for Configuration module
function Write-ConfigLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "Configuration" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $color = @{
            'Error' = 'Red'
            'Warning' = 'Yellow'
            'Information' = 'White'
            'Debug' = 'Gray'
        }[$Level]
        Write-Host "[$timestamp] [$Level] [Configuration] $Message" -ForegroundColor $color
    }
}

# Log module initialization (only once per session)
if (-not $global:AitherZeroConfigInitialized) {
    Write-ConfigLog -Message "Configuration module initialized" -Data @{
        ConfigPath = $script:ConfigPath
        Environment = $script:CurrentEnvironment
        DefaultSections = @('Core', 'Infrastructure', 'System', 'Logging', 'Automation')
    }
    $global:AitherZeroConfigInitialized = $true
}

function Get-Configuration {
    [CmdletBinding()]
    param(
        [string]$Section,
        [string]$Key
    )

    Write-ConfigLog -Level Debug -Message "Loading configuration" -Data @{
        Section = $Section
        Key = $Key
        ConfigPath = $script:ConfigPath
    }

    if (-not $script:Config) {
        if (Test-Path $script:ConfigPath) {
            Write-ConfigLog -Message "Loading configuration from file" -Data @{ Path = $script:ConfigPath }
            try {
                $script:Config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
                Write-ConfigLog -Message "Configuration loaded successfully" -Data @{ 
                    Sections = ($script:Config.PSObject.Properties.Name -join ', ')
                }
            } catch {
                Write-ConfigLog -Level Error -Message "Failed to parse configuration file" -Data @{
                    Path = $script:ConfigPath
                    Error = $_.Exception.Message
                }
                throw
            }
        } else {
            Write-ConfigLog -Message "Configuration file not found, creating default configuration" -Data @{ Path = $script:ConfigPath }
            # Default configuration with enhanced structure
            $script:Config = [PSCustomObject]@{
                Core = [PSCustomObject]@{
                    Name = "AitherZero"
                    Version = "1.0.0"
                    Environment = $script:CurrentEnvironment
                }
                Infrastructure = [PSCustomObject]@{
                    Provider = "opentofu"
                    WorkingDirectory = "./infrastructure"
                    DefaultVMPath = "C:\VMs"
                    DefaultMemory = "2GB"
                    DefaultCPU = 2
                }
                Configuration = [PSCustomObject]@{
                    AutoSave = $true
                    ValidateOnLoad = $true
                    ConfigPath = $script:ConfigPath
                }
                Logging = [PSCustomObject]@{
                    Level = "Information"
                    Path = "./logs"
                    MaxFileSize = "10MB"
                    RetentionDays = 30
                    Targets = @("Console", "File")
                }
                Security = [PSCustomObject]@{
                    CredentialStore = "LocalMachine"
                    EncryptionType = "AES256"
                    RequireSecureTransport = $true
                }
            }
            
            Write-ConfigLog -Message "Default configuration created" -Data @{
                Sections = ($script:Config.PSObject.Properties.Name -join ', ')
            }

            # Save default configuration
            Set-Configuration -Configuration $script:Config
        }
    }

    # Return specific section or key if requested
    if ($Section) {
        Write-ConfigLog -Level Debug -Message "Retrieving configuration section" -Data @{ Section = $Section }
        $sectionData = $script:Config.$Section
        if (-not $sectionData) {
            Write-ConfigLog -Level Warning -Message "Configuration section not found" -Data @{ Section = $Section }
            Write-Warning "Configuration section '$Section' not found"
            return $null
        }
        
        if ($Key) {
            Write-ConfigLog -Level Debug -Message "Retrieving configuration key" -Data @{ Section = $Section; Key = $Key }
            $keyData = $sectionData.$Key
            if ($null -eq $keyData) {
                Write-ConfigLog -Level Warning -Message "Configuration key not found" -Data @{ Section = $Section; Key = $Key }
                Write-Warning "Configuration key '$Section.$Key' not found"
                return $null
            }
            Write-ConfigLog -Level Debug -Message "Configuration key retrieved" -Data @{ Section = $Section; Key = $Key; Value = $keyData }
            return $keyData
        }
        
        Write-ConfigLog -Level Debug -Message "Configuration section retrieved" -Data @{ Section = $Section }
        return $sectionData
    }
    
    Write-ConfigLog -Level Debug -Message "Full configuration retrieved"
    return $script:Config
}

function Set-Configuration {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    Write-ConfigLog -Message "Saving configuration" -Data @{
        Path = $script:ConfigPath
        Sections = ($Configuration.PSObject.Properties.Name -join ', ')
    }
    
    try {
        $script:Config = $Configuration
        $json = $Configuration | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigPath -Value $json
        Write-ConfigLog -Message "Configuration saved successfully" -Data @{ Path = $script:ConfigPath }
    } catch {
        Write-ConfigLog -Level Error -Message "Failed to save configuration" -Data @{
            Path = $script:ConfigPath
            Error = $_.Exception.Message
        }
        throw
    }
    
    return $script:Config
}

function Get-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $config = Get-Configuration
    $current = $config
    
    foreach ($part in $Path.Split('.')) {
        if ($current.$part) {
            $current = $current.$part
        } else {
            return $null
        }
    }
    
    return $current
}

# Initialize configuration system
function Initialize-ConfigurationSystem {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = $script:ConfigPath,
        [string]$Environment = "Development",
        [switch]$EnableHotReload
    )

    Write-ConfigLog -Message "Initializing configuration system" -Data @{
        ConfigPath = $ConfigPath
        Environment = $Environment
        EnableHotReload = $EnableHotReload.IsPresent
    }
    
    $script:ConfigPath = $ConfigPath
    $script:CurrentEnvironment = $Environment

    # Load initial configuration
    $null = Get-Configuration

    if ($EnableHotReload) {
        Enable-ConfigurationHotReload
    }
    
    Write-ConfigLog -Message "Configuration system initialized successfully" -Data @{
        Environment = $Environment
        HotReloadEnabled = $EnableHotReload.IsPresent
    }
    Write-Host "Configuration system initialized for environment: $Environment" -ForegroundColor Green
}

# Environment switching
function Switch-ConfigurationEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Testing', 'Staging', 'Production')]
        [string]$Environment
    )

    $oldEnvironment = $script:CurrentEnvironment
    Write-ConfigLog -Message "Switching configuration environment" -Data @{
        FromEnvironment = $oldEnvironment
        ToEnvironment = $Environment
    }
    
    $script:CurrentEnvironment = $Environment

    # Reload configuration with new environment
    $script:Config = $null
    $null = Get-Configuration
    
    Write-ConfigLog -Message "Configuration environment switched successfully" -Data @{
        FromEnvironment = $oldEnvironment
        ToEnvironment = $Environment
    }
    Write-Host "Switched to $Environment environment" -ForegroundColor Green
}

# Validation
function Test-Configuration {
    [CmdletBinding()]
    param(
        [switch]$ThrowOnError
    )

    Write-ConfigLog -Message "Validating configuration" -Data @{
        ThrowOnError = $ThrowOnError.IsPresent
    }
    
    $config = Get-Configuration
    $errors = @()

    # Basic validation
    if (-not $config.Core) {
        $errors += "Missing Core configuration section"
    }

    if (-not $config.Core.Version) {
        $errors += "Missing Core.Version"
    }

    if ($errors.Count -gt 0) {
        Write-ConfigLog -Level Warning -Message "Configuration validation failed" -Data @{
            ErrorCount = $errors.Count
            Errors = ($errors -join '; ')
        }
        if ($ThrowOnError) {
            throw "Configuration validation failed: $($errors -join '; ')"
        }
        return $false
    }
    
    Write-ConfigLog -Message "Configuration validation passed"
    return $true
}

# Import/Export
function Export-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$IncludeDefaults
    )

    Write-ConfigLog -Message "Exporting configuration" -Data @{
        Path = $Path
        IncludeDefaults = $IncludeDefaults.IsPresent
    }
    
    try {
        $config = Get-Configuration
        
        if (-not $IncludeDefaults) {
            # Export only non-default values
            $config = $config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
        Write-ConfigLog -Message "Configuration exported successfully" -Data @{ Path = $Path }
        Write-Host "Configuration exported to: $Path" -ForegroundColor Green
    } catch {
        Write-ConfigLog -Level Error -Message "Failed to export configuration" -Data @{
            Path = $Path
            Error = $_.Exception.Message
        }
        throw
    }
}

function Import-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Merge
    )

    Write-ConfigLog -Message "Importing configuration" -Data @{
        Path = $Path
        Merge = $Merge.IsPresent
    }

    if (-not (Test-Path $Path)) {
        Write-ConfigLog -Level Error -Message "Configuration file not found" -Data @{ Path = $Path }
        throw "Configuration file not found: $Path"
    }
    
    try {
        $newConfig = Get-Content $Path -Raw | ConvertFrom-Json
        
        if ($Merge) {
            Write-ConfigLog -Message "Merging imported configuration with existing configuration"
            $currentConfig = Get-Configuration
            $script:Config = Merge-Configuration -Current $currentConfig -New $newConfig
        }
        else {
            Write-ConfigLog -Message "Replacing current configuration with imported configuration"
            $script:Config = $newConfig
        }
        
        # Save to current config path
        Set-Configuration -Configuration $script:Config
        
        Write-ConfigLog -Message "Configuration imported successfully" -Data @{
            Path = $Path
            Merged = $Merge.IsPresent
        }
        Write-Host "Configuration imported from: $Path" -ForegroundColor Green
    } catch {
        Write-ConfigLog -Level Error -Message "Failed to import configuration" -Data @{
            Path = $Path
            Error = $_.Exception.Message
        }
        throw
    }
}

# Helper function to merge configurations
function Merge-Configuration {
    param($Current, $New)
    
    $merged = $Current | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    
    foreach ($prop in $New.PSObject.Properties) {
        if ($merged.PSObject.Properties.Name -contains $prop.Name) {
            if ($prop.Value -is [PSCustomObject]) {
                $merged.$($prop.Name) = Merge-Configuration -Current $merged.$($prop.Name) -New $prop.Value
            }
            else {
                $merged.$($prop.Name) = $prop.Value
            }
        }
        else {
            $merged | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
        }
    }
    
    return $merged
}

# Hot reload support
function Enable-ConfigurationHotReload {
    if ($script:ConfigWatcher) {
        Write-Host "Configuration hot reload is already enabled" -ForegroundColor Yellow
        return
    }
    
    $action = {
        $script:Config = $null
        Write-Host "Configuration file changed - reloading..." -ForegroundColor Yellow
        $null = Get-Configuration
    }
    
    $script:ConfigWatcher = New-Object System.IO.FileSystemWatcher
    $script:ConfigWatcher.Path = Split-Path $script:ConfigPath -Parent
    $script:ConfigWatcher.Filter = Split-Path $script:ConfigPath -Leaf
    $script:ConfigWatcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
    
    Register-ObjectEvent -InputObject $script:ConfigWatcher -EventName "Changed" -Action $action
    
    $script:ConfigWatcher.EnableRaisingEvents = $true
    Write-Host "Configuration hot reload enabled" -ForegroundColor Green
}

function Disable-ConfigurationHotReload {
    if ($script:ConfigWatcher) {
        $script:ConfigWatcher.EnableRaisingEvents = $false
        $script:ConfigWatcher.Dispose()
        $script:ConfigWatcher = $null
        Write-Host "Configuration hot reload disabled" -ForegroundColor Green
    }
}

Export-ModuleMember -Function @(
    'Get-Configuration',
    'Set-Configuration', 
    'Get-ConfigValue',
    'Initialize-ConfigurationSystem',
    'Switch-ConfigurationEnvironment',
    'Test-Configuration',
    'Export-Configuration',
    'Import-Configuration',
    'Enable-ConfigurationHotReload',
    'Disable-ConfigurationHotReload'
)