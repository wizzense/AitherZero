#Requires -Version 7.0

<#
.SYNOPSIS
    Centralized configuration management for AitherZero
.DESCRIPTION
    Aitherium™ Enterprise Infrastructure Automation Platform
    Configuration Module - Provides a unified configuration store with
    environment support, validation, and hot-reloading
.NOTES
    Copyright © 2025 Aitherium Corporation
#>

# Script variables
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:ConfigPath = $null  # Will be determined dynamically
$script:Config = $null
$script:ConfigCache = @{}
$script:ConfigWatcher = $null
$script:ValidationSchemas = @{}
$script:CurrentEnvironment = "Development"
$script:IsCI = $false
$script:CIDefaults = @{}
$script:CIDefaultsUI = @{}

# Logging helper for Configuration module
function Write-ConfigLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    # Respect quiet mode - only show warnings and errors
    if ($env:AITHERZERO_QUIET_MODE -eq 'true' -and $Level -notin @('Warning', 'Error')) {
        return
    }
    
    # Respect log level override
    $logLevels = @{ 'Debug' = 0; 'Information' = 1; 'Warning' = 2; 'Error' = 3 }
    $minLevel = if ($env:AITHERZERO_LOG_LEVEL) { $env:AITHERZERO_LOG_LEVEL } else { 'Information' }
    if ($logLevels[$Level] -lt $logLevels[$minLevel]) {
        return
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "Configuration" -Data $Data
    } else {
        # Only output to console if not in quiet mode
        if ($env:AITHERZERO_QUIET_MODE -ne 'true') {
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

function Initialize-CIEnvironment {
    <#
    .SYNOPSIS
        Detects if running in CI environment and sets defaults
    #>

    # Detect CI environment from well-known variables
    $script:IsCI = (
        $env:CI -eq 'true' -or
        $env:GITHUB_ACTIONS -eq 'true' -or
        $env:TF_BUILD -eq 'true' -or  # Azure DevOps
        $env:GITLAB_CI -eq 'true' -or
        $env:JENKINS_URL -or
        $env:TEAMCITY_VERSION -or
        $env:TRAVIS -eq 'true' -or
        $env:CIRCLECI -eq 'true' -or
        $env:APPVEYOR -eq 'true' -or
        $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI  # Azure DevOps
    )

    if ($script:IsCI -and -not (Get-Variable -Name "AitherZeroCIDetected" -Scope Global -ErrorAction SilentlyContinue)) {
        Write-ConfigLog -Message "CI environment detected" -Level Information
        $global:AitherZeroCIDetected = $true
        $script:CurrentEnvironment = "CI"

        # Set CI defaults for Core section
        $script:CIDefaults = @{
            Profile = 'Full'
            NonInteractive = $true
            CI = $true
            OutputFormat = 'JSON'
            VerboseOutput = $false
            ShowProgress = $false
            OpenReportAfterRun = $false
            DryRun = $false
            WhatIf = $false
            ContinueOnError = $false
        }

        # Set CI defaults for UI section
        $script:CIDefaultsUI = @{
            ClearScreenOnStart = $false
            EnableAnimations = $false
            EnableColors = $false
        }
    }
}

function Get-ConfigurationPath {
    <#
    .SYNOPSIS
        Determines the configuration file path with fallback logic
    #>

    # Priority order:
    # 1. Environment variable
    if ($env:AITHERZERO_CONFIG_PATH -and (Test-Path $env:AITHERZERO_CONFIG_PATH)) {
        return $env:AITHERZERO_CONFIG_PATH
    }

    # 2. PSD1 file (preferred)
    $psd1Path = Join-Path $script:ProjectRoot "config.psd1"
    if (Test-Path $psd1Path) {
        return $psd1Path
    }

    # 3. JSON file (legacy)
    $jsonPath = Join-Path $script:ProjectRoot "config.json"
    if (Test-Path $jsonPath) {
        Write-ConfigLog -Message "Using legacy config.json. Consider converting to config.psd1" -Level Warning
        return $jsonPath
    }

    # 4. No config file found
    return $null
}

function Get-Configuration {
    [CmdletBinding()]
    param(
        [string]$Section,
        [string]$Key
    )

    # Initialize CI environment on first call
    if ($null -eq $script:ConfigPath) {
        Initialize-CIEnvironment
        $script:ConfigPath = Get-ConfigurationPath
    }

    Write-ConfigLog -Level Debug -Message "Loading configuration" -Data @{
        Section = $Section
        Key = $Key
        ConfigPath = $script:ConfigPath
        IsCI = $script:IsCI
    }

    if (-not $script:Config) {
        if ($script:ConfigPath -and (Test-Path $script:ConfigPath)) {
            Write-ConfigLog -Message "Loading configuration from file" -Data @{ Path = $script:ConfigPath }
            try {
                # Load based on file extension
                if ($script:ConfigPath -like "*.psd1") {
                    $script:Config = Import-PowerShellDataFile $script:ConfigPath

                    # Check for local overrides
                    $localPath = $script:ConfigPath -replace '\.psd1$', '.local.psd1'
                    if (Test-Path $localPath) {
                        Write-ConfigLog -Message "Loading local overrides from $localPath" -Level Information
                        $localConfig = Import-PowerShellDataFile $localPath
                        $script:Config = Merge-Configuration -Current $script:Config -New $localConfig
                    }
                } else {
                    # JSON fallback
                    $script:Config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
                }

                # Apply CI defaults if in CI environment
                if ($script:IsCI -and $script:CIDefaults.Count -gt 0) {
                    Write-ConfigLog -Message "Applying CI defaults" -Level Information
                    # Merge CI defaults into Core section
                    if (-not $script:Config.Core) {
                        $script:Config | Add-Member -MemberType NoteProperty -Name Core -Value ([PSCustomObject]@{})
                    }
                    foreach ($key in $script:CIDefaults.Keys) {
                        if (-not $script:Config.Core.$key) {
                            $script:Config.Core | Add-Member -MemberType NoteProperty -Name $key -Value $script:CIDefaults[$key]
                        }
                    }

                    # Apply UI-specific CI defaults to UI section
                    if ($script:CIDefaultsUI -and $script:CIDefaultsUI.Count -gt 0) {
                        if (-not $script:Config.UI) {
                            $script:Config | Add-Member -MemberType NoteProperty -Name UI -Value ([PSCustomObject]@{})
                        }
                        foreach ($key in $script:CIDefaultsUI.Keys) {
                            if (-not $script:Config.UI.$key) {
                                $script:Config.UI | Add-Member -MemberType NoteProperty -Name $key -Value $script:CIDefaultsUI[$key]
                            }
                        }
                    }
                }
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
            # No config file - create minimal defaults
            Write-ConfigLog -Message "No configuration file found, using defaults" -Level Warning
            $script:Config = @{
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

            # Apply CI defaults if in CI environment
            if ($script:IsCI -and $script:CIDefaults.Count -gt 0) {
                foreach ($key in $script:CIDefaults.Keys) {
                    if (-not $script:Config.Core.$key) {
                        $script:Config.Core | Add-Member -MemberType NoteProperty -Name $key -Value $script:CIDefaults[$key]
                    }
                }

                # Apply UI-specific CI defaults to UI section
                if ($script:CIDefaultsUI -and $script:CIDefaultsUI.Count -gt 0) {
                    if (-not $script:Config.UI) {
                        $script:Config | Add-Member -MemberType NoteProperty -Name UI -Value ([PSCustomObject]@{})
                    }
                    foreach ($key in $script:CIDefaultsUI.Keys) {
                        if (-not $script:Config.UI.$key) {
                            $script:Config.UI | Add-Member -MemberType NoteProperty -Name $key -Value $script:CIDefaultsUI[$key]
                        }
                    }
                }
            }

            Write-ConfigLog -Message "Using default configuration" -Data @{
                Sections = ($script:Config.PSObject.Properties.Name -join ', ')
            }
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
        # Save as PSD1 if the path ends with .psd1
        if ($script:ConfigPath -like '*.psd1') {
            $psd1Content = ConvertTo-Psd1String -InputObject $Configuration
            Set-Content -Path $script:ConfigPath -Value $psd1Content
        } else {
            # Fall back to JSON for compatibility
            $json = $Configuration | ConvertTo-Json -Depth 10
            Set-Content -Path $script:ConfigPath -Value $json
        }
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

function Get-ConfiguredValue {
    <#
    .SYNOPSIS
        Gets a configuration value with fallback chain: EnvVar > Config > CI Default > Default
    .DESCRIPTION
        Smart configuration resolution that checks environment variables first,
        then configuration file, then CI defaults (if in CI), then provided default.
    .PARAMETER Name
        Configuration key name (e.g., "Profile", "OutputFormat")
    .PARAMETER Section
        Configuration section (default: "Core")
    .PARAMETER Default
        Default value if not found elsewhere
    .PARAMETER EnvPrefix
        Environment variable prefix (default: "AITHERZERO_")
    .EXAMPLE
        $ProfileName = Get-ConfiguredValue -Name "Profile" -Default "Standard"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [string]$Section = "Core",

        [object]$Default = $null,

        [string]$EnvPrefix = "AITHERZERO_"
    )

    # 1. Check environment variable (highest priority)
    $envVarName = "${EnvPrefix}${Name}".ToUpper()
    $envValue = [Environment]::GetEnvironmentVariable($envVarName)
    if ($envValue) {
        Write-ConfigLog -Level Debug -Message "Using environment variable $envVarName = $envValue"
        # Convert string booleans if needed
        if ($envValue -eq 'true') { return $true }
        if ($envValue -eq 'false') { return $false }
        return $envValue
    }

    # 2. Check configuration file
    $config = Get-Configuration -Section $Section
    if ($config -and $null -ne $config.$Name) {
        Write-ConfigLog -Level Debug -Message "Using config value $Section.$Name = $($config.$Name)"
        return $config.$Name
    }

    # 3. Check CI defaults (if in CI environment)
    if ($script:IsCI -and $script:CIDefaults.ContainsKey($Name)) {
        Write-ConfigLog -Level Debug -Message "Using CI default for $Name = $($script:CIDefaults[$Name])"
        return $script:CIDefaults[$Name]
    }

    # 4. Return provided default
    Write-ConfigLog -Level Debug -Message "Using default value for $Name = $Default"
    return $Default
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Legacy function - Gets nested configuration value by path
    #>
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
    return $true
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
    $config = Get-Configuration

    # Update the environment in the config
    if ($config) {
        if ($config -is [hashtable]) {
            $config.Core.Environment = $Environment
        } else {
            $config.Core.Environment = $Environment
        }
        $script:Config = $config
    }

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

# Helper function to convert object to PSD1 string using native PowerShell capabilities
function ConvertTo-Psd1String {
    param(
        $InputObject
    )

    if ($null -eq $InputObject) {
        return '@{}'
    }

    # Use PowerShell's native conversion capabilities
    # Convert to JSON first then parse back to create a clean structure
    try {
        # Use depth of 10 to match the original function's MaxDepth parameter and prevent excessive nesting
        $json = $InputObject | ConvertTo-Json -Depth 10 -Compress
        $cleanObject = $json | ConvertFrom-Json -AsHashtable
        
        # Now convert the clean hashtable to PSD1 format
        return ConvertTo-Psd1Format -InputObject $cleanObject -Depth 0
    }
    catch {
        Write-Warning "Failed to convert object to PSD1 format: $($_.Exception.Message)"
        return '@{}'
    }
}

# Helper function for actual PSD1 formatting
function ConvertTo-Psd1Format {
    param(
        $InputObject,
        [int]$Depth = 0
    )
    
    $indent = '    ' * $Depth
    
    if ($null -eq $InputObject) {
        return '$null'
    }
    elseif ($InputObject -is [bool]) {
        return '$' + $InputObject.ToString().ToLower()
    }
    elseif ($InputObject -is [string]) {
        return "'" + ($InputObject -replace "'", "''") + "'"
    }
    elseif ($InputObject -is [int] -or $InputObject -is [long] -or $InputObject -is [double]) {
        return $InputObject.ToString()
    }
    elseif ($InputObject -is [System.Collections.IEnumerable] -and 
            -not ($InputObject -is [string]) -and 
            -not ($InputObject -is [hashtable])) {
        if ($InputObject.Count -eq 0) {
            return '@()'
        }
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-Psd1Format -InputObject $item -Depth ($Depth + 1)
        }
        return "@(`n$indent    " + ($items -join "`n$indent    ") + "`n$indent)"
    }
    elseif ($InputObject -is [hashtable]) {
        if ($InputObject.Count -eq 0) {
            return '@{}'
        }
        $pairs = @()
        foreach ($key in $InputObject.Keys | Sort-Object) {
            $value = ConvertTo-Psd1Format -InputObject $InputObject[$key] -Depth ($Depth + 1)
            $pairs += "$indent    $key = $value"
        }
        return "@{`n" + ($pairs -join "`n") + "`n$indent}"
    }
    else {
        return "'" + $InputObject.ToString() + "'"
    }
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
        
        if ($null -eq $config) {
            Write-ConfigLog -Level Error -Message "No configuration available to export"
            throw "No configuration available to export. Initialize configuration system first."
        }

        # The configuration is already in the correct format (hashtable), no conversion needed

        # Export as PowerShell Data File
        $psd1Content = ConvertTo-Psd1String -InputObject $config
        $psd1Content | Set-Content -Path $Path

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
        # Try to import as PowerShell Data File first
        if ($Path -like '*.psd1') {
            $newConfig = Import-PowerShellDataFile -Path $Path
        } else {
            # Fall back to JSON for compatibility
            $newConfig = Get-Content $Path -Raw | ConvertFrom-Json
        }

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
    # Check for performance optimization settings
    if ($env:AITHERZERO_NO_CONFIG_WATCH -eq 'true' -or
        $env:AITHERZERO_TEST_MODE -eq 'true') {
        Write-ConfigLog -Level Debug -Message "Configuration hot reload disabled (performance optimization)"
        return
    }

    if ($script:ConfigWatcher) {
        Write-Host "Configuration hot reload is already enabled" -ForegroundColor Yellow
        return
    }

    # Check if testing performance optimizations are enabled
    try {
        $config = Get-Configuration -Section 'Testing'
        if ($config -and $config.Performance -and $config.Performance.DisableConfigWatch) {
            Write-ConfigLog -Level Debug -Message "Configuration hot reload disabled (Testing.Performance.DisableConfigWatch = true)"
            return
        }
    } catch {
        # Continue if we can't read config (avoid infinite recursion)
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

    $null = Register-ObjectEvent -InputObject $script:ConfigWatcher -EventName "Changed" -Action $action

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

# ===================================================================
# MANIFEST AND FEATURE MANAGEMENT FUNCTIONS
# ===================================================================

function Get-PlatformManifest {
    <#
    .SYNOPSIS
        Gets the platform manifest information
    .DESCRIPTION
        Returns the manifest section that defines platform capabilities,
        supported platforms, feature dependencies, and execution profiles
    #>
    [CmdletBinding()]
    param()
    
    $config = Get-Configuration
    return $config.Manifest
}

function Get-FeatureConfiguration {
    <#
    .SYNOPSIS
        Gets configuration for a specific feature
    .DESCRIPTION
        Returns the configuration for a feature including its dependencies,
        platform support, installation details, and settings
    .PARAMETER FeatureName
        Name of the feature (e.g., 'Node', 'Docker', 'VSCode')
    .PARAMETER Category
        Feature category (Core, Development, Infrastructure, Cloud, Testing, Utilities)
    .EXAMPLE
        Get-FeatureConfiguration -Category 'Development' -FeatureName 'Node'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName,
        
        [string]$Category = $null
    )
    
    $config = Get-Configuration -Section Features
    
    if ($Category) {
        if ($config.$Category -and $config.$Category.$FeatureName) {
            return $config.$Category.$FeatureName
        }
    } else {
        # Search across all categories
        foreach ($cat in $config.Keys) {
            if ($config.$cat.$FeatureName) {
                return $config.$cat.$FeatureName
            }
        }
    }
    
    return $null
}

function Test-FeatureEnabled {
    <#
    .SYNOPSIS
        Tests if a feature is enabled in the current configuration
    .DESCRIPTION
        Checks if a feature is enabled, taking into account the current profile,
        platform compatibility, and dependency requirements
    .PARAMETER FeatureName
        Name of the feature to check
    .PARAMETER Category
        Feature category (optional - will search all if not specified)
    .PARAMETER Profile
        Profile to check against (defaults to current profile)
    .EXAMPLE
        Test-FeatureEnabled -FeatureName 'Node' -Category 'Development'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName,
        
        [string]$Category = $null,
        
        [string]$Profile = $null
    )
    
    $featureConfig = Get-FeatureConfiguration -FeatureName $FeatureName -Category $Category
    
    if (-not $featureConfig) {
        Write-ConfigLog -Level Debug -Message "Feature not found: $FeatureName"
        return $false
    }
    
    # Check if explicitly enabled
    if (-not $featureConfig.Enabled) {
        Write-ConfigLog -Level Debug -Message "Feature disabled: $FeatureName"
        return $false
    }
    
    # Check platform compatibility
    $currentPlatform = Get-ConfiguredValue -Name 'Platform' -Default 'auto'
    if ($currentPlatform -eq 'auto') {
        $currentPlatform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
    }
    
    if ($featureConfig.Platforms -and $currentPlatform -notin $featureConfig.Platforms) {
        Write-ConfigLog -Level Debug -Message "Feature $FeatureName not supported on platform: $currentPlatform"
        return $false
    }
    
    # Check profile compatibility
    if (-not $Profile) {
        $Profile = Get-ConfiguredValue -Name 'Profile' -Default 'Standard'
    }
    
    $manifest = Get-PlatformManifest
    $profileConfig = $manifest.ExecutionProfiles.$Profile
    
    if ($profileConfig -and $profileConfig.Features) {
        # Check if feature is included in profile
        $profileFeatures = $profileConfig.Features
        if ($profileFeatures -contains '*') {
            # All features enabled
            return $true
        }
        
        # Check specific feature patterns
        $featurePath = if ($Category) { "$Category.$FeatureName" } else { $FeatureName }
        $categoryPath = if ($Category) { $Category } else { '*' }
        
        $isIncluded = $profileFeatures -contains $featurePath -or
                     $profileFeatures -contains $FeatureName -or
                     $profileFeatures -contains $categoryPath
        
        if (-not $isIncluded) {
            Write-ConfigLog -Level Debug -Message "Feature $FeatureName not included in profile: $Profile"
            return $false
        }
    }
    
    return $true
}

function Get-ExecutionProfile {
    <#
    .SYNOPSIS
        Gets execution profile configuration
    .DESCRIPTION
        Returns the configuration for the specified or current execution profile
    .PARAMETER ProfileName
        Name of the profile to get (defaults to current profile)
    .EXAMPLE
        Get-ExecutionProfile -ProfileName 'Developer'
    #>
    [CmdletBinding()]
    param(
        [string]$ProfileName = $null
    )
    
    if (-not $ProfileName) {
        $ProfileName = Get-ConfiguredValue -Name 'Profile' -Default 'Standard'
    }
    
    $manifest = Get-PlatformManifest
    return $manifest.ExecutionProfiles.$ProfileName
}

function Get-FeatureDependencies {
    <#
    .SYNOPSIS
        Gets dependencies for a feature
    .DESCRIPTION
        Returns the dependency chain for a feature from the manifest
    .PARAMETER FeatureName
        Name of the feature
    .PARAMETER Category
        Feature category
    .EXAMPLE
        Get-FeatureDependencies -Category 'Development' -FeatureName 'Node'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName,
        
        [string]$Category = $null
    )
    
    $manifest = Get-PlatformManifest
    $dependencies = $manifest.FeatureDependencies
    
    if ($Category -and $dependencies.$Category -and $dependencies.$Category.$FeatureName) {
        return $dependencies.$Category.$FeatureName
    }
    
    # Search across categories
    foreach ($cat in $dependencies.Keys) {
        if ($dependencies.$cat.$FeatureName) {
            return $dependencies.$cat.$FeatureName
        }
    }
    
    return $null
}

function Resolve-FeatureDependencies {
    <#
    .SYNOPSIS
        Resolves all dependencies for enabled features
    .DESCRIPTION
        Returns a dependency-sorted list of features that need to be installed
        based on the current profile and enabled features
    .PARAMETER Profile
        Profile to resolve dependencies for (defaults to current profile)
    .EXAMPLE
        Resolve-FeatureDependencies -Profile 'Developer'
    #>
    [CmdletBinding()]
    param(
        [string]$Profile = $null
    )
    
    if (-not $Profile) {
        $Profile = Get-ConfiguredValue -Name 'Profile' -Default 'Standard'
    }
    
    Write-ConfigLog -Message "Resolving feature dependencies for profile: $Profile"
    
    $resolved = @()
    $visited = @{}
    $visiting = @{}
    
    # Get all enabled features for the profile
    $profileConfig = Get-ExecutionProfile -ProfileName $Profile
    if (-not $profileConfig -or -not $profileConfig.Features) {
        Write-ConfigLog -Level Warning -Message "No features defined for profile: $Profile"
        return $resolved
    }
    
    # Recursive dependency resolution function
    function Resolve-Feature {
        param($FeaturePath)
        
        if ($visited.ContainsKey($FeaturePath)) {
            return
        }
        
        if ($visiting.ContainsKey($FeaturePath)) {
            Write-ConfigLog -Level Warning -Message "Circular dependency detected: $FeaturePath"
            return
        }
        
        $visiting[$FeaturePath] = $true
        
        # Parse feature path (Category.Feature or just Feature)
        $parts = $FeaturePath -split '\.'
        $category = if ($parts.Count -gt 1) { $parts[0] } else { $null }
        $featureName = if ($parts.Count -gt 1) { $parts[1] } else { $parts[0] }
        
        # Get dependencies for this feature
        $deps = Get-FeatureDependencies -FeatureName $featureName -Category $category
        
        if ($deps -and $deps.DependsOn) {
            foreach ($dep in $deps.DependsOn) {
                Resolve-Feature -FeaturePath $dep
            }
        }
        
        $visiting.Remove($FeaturePath)
        $visited[$FeaturePath] = $true
        
        # Add to resolved list if not already present
        if ($FeaturePath -notin $resolved) {
            $resolved += $FeaturePath
        }
    }
    
    # Process all features in the profile
    foreach ($feature in $profileConfig.Features) {
        if ($feature -eq '*') {
            Write-ConfigLog -Level Warning -Message "Wildcard feature resolution not implemented yet"
            continue
        }
        Resolve-Feature -FeaturePath $feature
    }
    
    Write-ConfigLog -Message "Resolved $($resolved.Count) features: $($resolved -join ', ')"
    return $resolved
}

Export-ModuleMember -Function @(
    'Get-Configuration',
    'Set-Configuration',
    'Get-ConfigValue',
    'Get-ConfiguredValue',
    'Merge-Configuration',
    'Initialize-ConfigurationSystem',
    'Switch-ConfigurationEnvironment',
    'Test-Configuration',
    'Export-Configuration',
    'Import-Configuration',
    'Enable-ConfigurationHotReload',
    'Disable-ConfigurationHotReload',
    'Get-PlatformManifest',
    'Get-FeatureConfiguration',
    'Test-FeatureEnabled',
    'Get-ExecutionProfile',
    'Get-FeatureDependencies',
    'Resolve-FeatureDependencies'
)