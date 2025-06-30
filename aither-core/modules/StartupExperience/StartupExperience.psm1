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

# Import shared functions
. (Join-Path $projectRoot "aither-core" "shared" "Find-ProjectRoot.ps1")

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

# Module initialization
Write-Verbose "StartupExperience module loaded from $moduleRoot"