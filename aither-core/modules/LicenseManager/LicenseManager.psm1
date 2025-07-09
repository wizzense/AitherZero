#Requires -Version 7.0

<#
.SYNOPSIS
    License and feature management module for AitherZero
.DESCRIPTION
    Provides tier-based feature access control and license validation
#>

# Write-CustomLog fallback for test isolation scenarios
if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
    function Global:Write-CustomLog {
        param(
            [string]$Message,
            [string]$Level = 'INFO'
        )
        Write-Host "[$Level] $Message"
    }
}

# Import required modules
$ErrorActionPreference = 'Stop'

# Get the path to the project root
$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $moduleRoot))

# Import shared functions
. (Join-Path $projectRoot "aither-core" "shared" "Find-ProjectRoot.ps1")

# Module-level variables
$script:LicensePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.aitherzero' 'license.json'
$script:FeatureRegistryPath = Join-Path $projectRoot 'configs' 'feature-registry.json'
$script:CurrentLicense = $null
$script:FeatureRegistry = $null

# Create license directory if it doesn't exist
$licenseDir = Split-Path -Parent $script:LicensePath
if (-not (Test-Path $licenseDir)) {
    New-Item -Path $licenseDir -ItemType Directory -Force | Out-Null
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

# Module initialization
Write-Verbose "LicenseManager module loaded from $moduleRoot"

# Load feature registry if it exists
if (Test-Path $script:FeatureRegistryPath) {
    try {
        $script:FeatureRegistry = Get-Content $script:FeatureRegistryPath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to load feature registry: $_"
    }
}
