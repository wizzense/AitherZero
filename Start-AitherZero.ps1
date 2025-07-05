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
    [switch]$Help,
    
    [Parameter(HelpMessage = "Run in non-interactive mode (no prompts)")]
    [switch]$NonInteractive
)

# Find the aither-core.ps1 script
# Robust path resolution for various execution contexts
$scriptPath = $null

# Method 1: $PSScriptRoot (works in most cases)
if ($PSScriptRoot) {
    $scriptPath = $PSScriptRoot
}
# Method 2: $MyInvocation (works when called as script)
elseif ($MyInvocation.MyCommand.Path) {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
}
# Method 3: Get script path from stack frame (works in more contexts)
elseif ($MyInvocation.ScriptName) {
    $scriptPath = Split-Path -Parent $MyInvocation.ScriptName
}
# Method 4: Use current directory as fallback
else {
    $scriptPath = (Get-Location).Path
    # Double-check if we're in the right directory
    if (-not (Test-Path (Join-Path $scriptPath "aither-core"))) {
        # Try to find Start-AitherZero.ps1 in current directory
        $thisScript = Get-ChildItem -Path . -Filter "Start-AitherZero.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($thisScript) {
            $scriptPath = $thisScript.DirectoryName
        }
    }
}

$coreScript = Join-Path (Join-Path $scriptPath "aither-core") "aither-core.ps1"

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
if ($NonInteractive) { $coreparams['NonInteractive'] = $true }

try {
    & $coreScript @coreparams
} catch {
    Write-Error "Failed to execute AitherZero: $_"
    exit 1
}