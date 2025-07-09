#Requires -Version 7.0

<#
.SYNOPSIS
    Enhanced startup experience module for AitherZero
.DESCRIPTION
    Provides interactive configuration management, module discovery, and rich terminal UI
#>

# Import required modules
$ErrorActionPreference = 'Stop'

# Get the path to the project root
$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $moduleRoot) {
    $moduleRoot = $PSScriptRoot
}

# Import shared functions
. "$PSScriptRoot/../../shared/Find-ProjectRoot.ps1"

# Now get the project root
$projectRoot = Find-ProjectRoot -StartPath $moduleRoot

# Module-level variables
$script:ConfigProfilePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'profiles'
$script:CurrentProfile = $null
$script:TerminalUIEnabled = $false
$script:ManagementState = $null

# Create profile directory if it doesn't exist
if (-not (Test-Path $script:ConfigProfilePath)) {
    New-Item -Path $script:ConfigProfilePath -ItemType Directory -Force | Out-Null
}

# Import all public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    . $function.FullName
}

# Import all private functions with error handling
$privateFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    try {
        . $function.FullName
        Write-Verbose "Loaded private function: $($function.BaseName)"
    } catch {
        Write-Warning "Failed to load private function $($function.BaseName): $_"
    }
}

# Try to import LicenseManager module if available BEFORE exporting functions
try {
    $licenseManagerPath = Join-Path (Split-Path $moduleRoot -Parent) "LicenseManager"
    if (Test-Path $licenseManagerPath) {
        Import-Module $licenseManagerPath -Force -ErrorAction Stop
        Write-Verbose "LicenseManager module loaded successfully"
    }
} catch {
    Write-Verbose "LicenseManager module not available: $_"
}

# Provide fallback Test-FeatureAccess function if LicenseManager is not loaded
if (-not (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue)) {
    function Test-FeatureAccess {
        <#
        .SYNOPSIS
            Fallback function when LicenseManager is not available
        .DESCRIPTION
            Always returns true to allow all features when license management is not loaded
        #>
        param(
            [string]$FeatureName,
            [string]$ModuleName,
            [switch]$ThrowOnDenied
        )

        # Without license management, all features are accessible
        return $true
    }

    Write-Verbose "Using fallback Test-FeatureAccess function"
}

# Export public functions (commenting out to avoid interference with imported functions)
# The module manifest (.psd1) will handle function exports instead
# if ($publicFunctions.Count -gt 0) {
#     Export-ModuleMember -Function $publicFunctions.BaseName
# }

# Module initialization
Write-Verbose "StartupExperience module loaded from $moduleRoot"
