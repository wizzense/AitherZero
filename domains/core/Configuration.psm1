#Requires -Version 7.0

<#
.SYNOPSIS
    Centralized configuration management for AitherZero
.DESCRIPTION
    Consolidated configuration management providing unified configuration store with 
    environment support, validation, and hot-reloading capabilities.
    Combines core configuration, environment detection, and basic utilities.
.NOTES
    Consolidated from domains/configuration/Configuration.psm1
    Part of AitherZero domain flattening initiative
#>

# Script variables
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:ConfigPath = $null
$script:Config = $null
$script:ConfigCache = @{}
$script:CurrentEnvironment = "Development"
$script:IsCI = $false
$script:CIDefaults = @{}

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

function Initialize-CIEnvironment {
    <#
    .SYNOPSIS
        Detects if running in CI environment and sets defaults
    #>
    
    $script:IsCI = (
        $env:CI -eq 'true' -or
        $env:GITHUB_ACTIONS -eq 'true' -or
        $env:TF_BUILD -eq 'true' -or
        $env:GITLAB_CI -eq 'true' -or
        $env:JENKINS_URL -or
        $env:TEAMCITY_VERSION -or
        $env:TRAVIS -eq 'true' -or
        $env:CIRCLECI -eq 'true' -or
        $env:APPVEYOR -eq 'true' -or
        $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    )
    
    if ($script:IsCI -and -not (Get-Variable -Name "AitherZeroCIDetected" -Scope Global -ErrorAction SilentlyContinue)) {
        Write-ConfigLog -Message "CI environment detected" -Level Information
        $global:AitherZeroCIDetected = $true
        $script:CurrentEnvironment = "CI"
        
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
            ClearScreenOnStart = $false
            EnableAnimations = $false
            ShowWelcomeMessage = $false
            EnableEmoji = $false
            ShowHints = $false
        }
    }
}

function Get-Configuration {
    <#
    .SYNOPSIS
        Get configuration value or section
    .PARAMETER Section
        Configuration section to retrieve
    .PARAMETER Key
        Specific key within section
    .PARAMETER DefaultValue
        Default value if key not found
    #>
    [CmdletBinding()]
    param(
        [string]$Section,
        [string]$Key,
        [object]$DefaultValue = $null
    )

    Initialize-CIEnvironment
    
    if (-not $script:Config) {
        Write-ConfigLog -Level Debug -Message "Loading configuration"
        $loadResult = Load-ConfigurationFromFile
        if (-not $loadResult) {
            Write-ConfigLog -Level Warning -Message "Failed to load configuration, using defaults"
            return $DefaultValue
        }
    }

    if ($Section -and $Key) {
        Write-ConfigLog -Level Debug -Message "Retrieving configuration key" -Data @{
            Section = $Section
            Key = $Key
        }
        
        if ($script:Config.ContainsKey($Section) -and $script:Config[$Section].ContainsKey($Key)) {
            return $script:Config[$Section][$Key]
        } elseif ($script:IsCI -and $script:CIDefaults.ContainsKey($Key)) {
            Write-ConfigLog -Level Debug -Message "Using CI default for $Key = $($script:CIDefaults[$Key])"
            return $script:CIDefaults[$Key]
        } else {
            Write-ConfigLog -Level Warning -Message "Configuration key not found" -Data @{
                Section = $Section
                Key = $Key
            }
            return $DefaultValue
        }
    } elseif ($Section) {
        Write-ConfigLog -Level Debug -Message "Retrieving configuration section" -Data @{ Section = $Section }
        
        if ($script:Config.ContainsKey($Section)) {
            Write-ConfigLog -Level Debug -Message "Configuration section retrieved"
            return $script:Config[$Section]
        } else {
            Write-ConfigLog -Level Warning -Message "Configuration section not found" -Data @{ Section = $Section }
            return @{}
        }
    } else {
        return $script:Config
    }
}

function Set-Configuration {
    <#
    .SYNOPSIS
        Set configuration value
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Section,
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [object]$Value
    )

    if (-not $script:Config) {
        $script:Config = @{}
    }

    if (-not $script:Config.ContainsKey($Section)) {
        $script:Config[$Section] = @{}
    }

    $script:Config[$Section][$Key] = $Value
    Write-ConfigLog -Level Debug -Message "Configuration updated" -Data @{
        Section = $Section
        Key = $Key
        Value = $Value
    }
}

function Load-ConfigurationFromFile {
    <#
    .SYNOPSIS
        Load configuration from file with fallback logic
    #>
    [CmdletBinding()]
    param()

    $possiblePaths = @(
        $script:ConfigPath,
        (Join-Path $script:ProjectRoot "config.psd1"),
        (Join-Path $script:ProjectRoot "config.json"),
        (Join-Path $script:ProjectRoot "config.example.psd1")
    ) | Where-Object { $_ -and (Test-Path $_) }

    if (-not $possiblePaths) {
        Write-ConfigLog -Level Warning -Message "No configuration file found"
        return $false
    }

    $configFile = $possiblePaths[0]
    Write-ConfigLog -Message "Loading configuration from file" -Data @{ Path = $configFile }

    try {
        if ($configFile -like "*.json") {
            $script:Config = Get-Content $configFile -Raw | ConvertFrom-Json -AsHashtable
        } else {
            $script:Config = Import-PowerShellDataFile -Path $configFile
        }

        if ($script:IsCI) {
            Write-ConfigLog -Message "Applying CI defaults" -Level Information
        }

        Write-ConfigLog -Message "Configuration loaded successfully" -Data @{
            Sections = ($script:Config.Keys -join ', ')
        }
        return $true
    }
    catch {
        Write-ConfigLog -Level Error -Message "Failed to load configuration" -Data @{
            Path = $configFile
            Error = $_.Exception.Message
        }
        return $false
    }
}

function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Get configuration specific to a module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,
        [hashtable]$DefaultConfig = @{}
    )

    $moduleConfig = Get-Configuration -Section $ModuleName -DefaultValue $DefaultConfig
    return $moduleConfig
}

function Test-ConfigurationKey {
    <#
    .SYNOPSIS
        Test if a configuration key exists
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Section,
        [Parameter(Mandatory)]
        [string]$Key
    )

    return ($script:Config.ContainsKey($Section) -and $script:Config[$Section].ContainsKey($Key))
}

function Get-EnvironmentInfo {
    <#
    .SYNOPSIS
        Get current environment information
    #>
    [CmdletBinding()]
    param()

    return @{
        Environment = $script:CurrentEnvironment
        IsCI = $script:IsCI
        Platform = $PSVersionTable.Platform
        PSVersion = $PSVersionTable.PSVersion.ToString()
        ProjectRoot = $script:ProjectRoot
        ConfigLoaded = ($null -ne $script:Config)
    }
}

# Initialize CI environment detection on module load
Initialize-CIEnvironment

# Log module initialization
if (-not $global:AitherZeroConfigInitialized) {
    Write-ConfigLog -Message "Configuration module initialized" -Data @{
        Environment = $script:CurrentEnvironment
        IsCI = $script:IsCI
        DefaultSections = @('Core', 'Infrastructure', 'System', 'Logging', 'Automation')
        ConfigPath = $script:ConfigPath
    }
    $global:AitherZeroConfigInitialized = $true
}

# Export functions
Export-ModuleMember -Function @(
    'Get-Configuration',
    'Set-Configuration',
    'Get-ModuleConfiguration',
    'Test-ConfigurationKey',
    'Get-EnvironmentInfo',
    'Load-ConfigurationFromFile'
)