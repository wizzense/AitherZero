# AitherZero ConfigurationCore Module
# Unified configuration management for the entire platform

#Requires -Version 7.0

# Script-level variables
$script:ConfigurationStore = @{
    Modules = @{}
    Environments = @{
        'default' = @{
            Name = 'default'
            Description = 'Default configuration environment'
            Settings = @{}
        }
    }
    CurrentEnvironment = 'default'
    Schemas = @{}
    HotReload = @{
        Enabled = $false
        Watchers = @{}
    }
    StorePath = $null
}

# Import functions
$Public = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue)

foreach ($import in @($Private + $Public)) {
    try {
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Initialize configuration store path
$script:ConfigurationStore.StorePath = Join-Path $env:APPDATA 'AitherZero' 'configuration.json'
if ($IsLinux -or $IsMacOS) {
    $script:ConfigurationStore.StorePath = Join-Path $env:HOME '.aitherzero' 'configuration.json'
}

# Create directory if it doesn't exist
$configDir = Split-Path $script:ConfigurationStore.StorePath -Parent
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

# Load existing configuration if available
if (Test-Path $script:ConfigurationStore.StorePath) {
    try {
        $storedConfig = Get-Content $script:ConfigurationStore.StorePath -Raw | ConvertFrom-Json -AsHashtable
        if ($storedConfig) {
            $script:ConfigurationStore = $storedConfig
        }
    } catch {
        Write-Warning "Failed to load existing configuration: $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName