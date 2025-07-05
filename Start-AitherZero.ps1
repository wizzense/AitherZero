# AitherZero Launcher Script
#
# This is the main entry point for AitherZero infrastructure automation framework.
# It delegates to the core application while providing a consistent interface.

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Run in automatic mode without user interaction")]
    [switch]$Auto,
    
    [Parameter(HelpMessage = "Scripts to run (comma-separated)")]
    [string]$Scripts,
    
    [Parameter(HelpMessage = "Run first-time setup wizard")]
    [switch]$Setup,
    
    [Parameter(HelpMessage = "Installation profile: minimal, developer, full, or interactive")]
    [ValidateSet("minimal", "developer", "full", "interactive")]
    [string]$InstallationProfile = "interactive",
    
    [Parameter(HelpMessage = "Preview mode - show what would be done")]
    [switch]$WhatIf,
    
    [Parameter(HelpMessage = "Show help information")]
    [switch]$Help
)

# Find the aither-core.ps1 script
# Handle case where $PSScriptRoot is null (e.g., when run from certain contexts)
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    if (-not $PSScriptRoot) {
        $PSScriptRoot = $PWD.Path
    }
}

$coreScript = Join-Path $PSScriptRoot "aither-core" "aither-core.ps1"

if (-not (Test-Path $coreScript)) {
    Write-Error "Core script not found at: $coreScript"
    Write-Error "Please ensure AitherZero is properly installed."
    exit 1
}

# Pass all parameters to the core script
$coreparams = @{}

if ($Auto) { $coreparams['Auto'] = $true }
if ($Scripts) { $coreparams['Scripts'] = $Scripts }
if ($Setup) { $coreparams['Setup'] = $true }
if ($InstallationProfile) { $coreparams['InstallationProfile'] = $InstallationProfile }
if ($WhatIf) { $coreparams['WhatIf'] = $true }
if ($Help) { $coreparams['Help'] = $true }

try {
    & $coreScript @coreparams
} catch {
    Write-Error "Failed to execute AitherZero: $_"
    exit 1
}