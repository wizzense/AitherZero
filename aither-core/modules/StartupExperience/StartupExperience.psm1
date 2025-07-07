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

# Import shared functions - try multiple locations
$sharedPaths = @(
    (Join-Path (Split-Path (Split-Path $moduleRoot -Parent) -Parent) "shared" "Find-ProjectRoot.ps1"),
    (Join-Path (Split-Path $moduleRoot -Parent) "shared" "Find-ProjectRoot.ps1"),
    (Join-Path $moduleRoot ".." ".." "shared" "Find-ProjectRoot.ps1")
)

$foundSharedUtil = $false
foreach ($sharedPath in $sharedPaths) {
    if (Test-Path $sharedPath) {
        . $sharedPath
        Write-Verbose "Loaded Find-ProjectRoot from: $sharedPath"
        $foundSharedUtil = $true
        break
    }
}

if (-not $foundSharedUtil) {
    # Define Find-ProjectRoot locally if shared utility is not found
    function Find-ProjectRoot {
        param([string]$StartPath = $PWD.Path)
        
        $currentPath = $StartPath
        while ($currentPath -and $currentPath -ne (Split-Path $currentPath -Parent)) {
            if (Test-Path (Join-Path $currentPath "Start-AitherZero.ps1")) {
                return $currentPath
            }
            $currentPath = Split-Path $currentPath -Parent
        }
        
        # Fallback to module root's parent parent
        return Split-Path (Split-Path $moduleRoot -Parent) -Parent
    }
    Write-Verbose "Using fallback Find-ProjectRoot function"
}

# Now get the project root
$projectRoot = Find-ProjectRoot -StartPath $moduleRoot

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
# Force creation of fallback function if LicenseManager isn't properly loaded
if (-not (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue) -or 
    (Get-Command Test-FeatureAccess -ErrorAction SilentlyContinue).Source -eq '') {
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