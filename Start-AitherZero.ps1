#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Infrastructure Automation Framework Launcher

.DESCRIPTION
    This is the main entry point for AitherZero infrastructure automation framework.
    It delegates to the core application while providing a consistent interface.

.PARAMETER Auto
    Run in automatic mode without user interaction

.PARAMETER Scripts
    Comma-separated list of scripts to run

.PARAMETER Setup
    Run first-time setup wizard

.PARAMETER InstallationProfile
    Installation profile: minimal, developer, full, or interactive

.PARAMETER WhatIf
    Preview mode - show what would be done without making changes

.PARAMETER Help
    Show help information

.PARAMETER NonInteractive
    Run in non-interactive mode (no prompts)

.EXAMPLE
    ./Start-AitherZero.ps1
    # Run in interactive mode

.EXAMPLE
    ./Start-AitherZero.ps1 -Setup -InstallationProfile developer
    # Run setup wizard with developer profile

.EXAMPLE
    ./Start-AitherZero.ps1 -Auto -Scripts "LabRunner,BackupManager"
    # Run specific scripts in automatic mode
#>

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