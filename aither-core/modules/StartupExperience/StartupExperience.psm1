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
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $moduleRoot))

# Import shared functions - use absolute path construction
$sharedPath = Join-Path $projectRoot "aither-core" "shared" "Find-ProjectRoot.ps1"
if (Test-Path $sharedPath) {
    . $sharedPath
} else {
    Write-Warning "Find-ProjectRoot.ps1 not found at: $sharedPath"
}

# Module-level variables
$script:ConfigProfilePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'profiles'
$script:CurrentProfile = $null
$script:TerminalUIEnabled = $false

# Create profile directory if it doesn't exist
if (-not (Test-Path $script:ConfigProfilePath)) {
    New-Item -Path $script:ConfigProfilePath -ItemType Directory -Force | Out-Null
}

# Import all public functions
$publicFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $publicFunctions) {
    . $function.FullName
}

# Import all private functions
$privateFunctions = Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
foreach ($function in $privateFunctions) {
    . $function.FullName
}

# Export public functions
Export-ModuleMember -Function $publicFunctions.BaseName

# Try to import LicenseManager module if available
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
            [string]$Feature,
            [string]$Module,
            [string]$CurrentTier
        )
        
        # Without license management, all features are accessible
        return $true
    }
    
    Write-Verbose "Using fallback Test-FeatureAccess function"
}

# Module initialization
Write-Verbose "StartupExperience module loaded from $moduleRoot"