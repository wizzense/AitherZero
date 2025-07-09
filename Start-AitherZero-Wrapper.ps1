# PowerShell Version Check Wrapper for AitherZero
# This script checks for PowerShell 7 and automatically relaunches if available

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
    [switch]$NonInteractive,

    [Parameter(HelpMessage = "Run in quiet mode with minimal output")]
    [switch]$Quiet,

    [Parameter(HelpMessage = "Set verbosity level: silent, normal, detailed")]
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',

    [Parameter(HelpMessage = "Path to configuration file")]
    [string]$ConfigFile,

    [Parameter(HelpMessage = "Force operations even if validations fail")]
    [switch]$Force,

    [Parameter(HelpMessage = "Force enhanced UI experience")]
    [switch]$EnhancedUI,

    [Parameter(HelpMessage = "Force classic menu experience")]
    [switch]$ClassicUI,

    [Parameter(HelpMessage = "UI preference mode: auto, enhanced, classic")]
    [ValidateSet('auto', 'enhanced', 'classic')]
    [string]$UIMode = 'auto'
)

$ErrorActionPreference = 'Stop'

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host @"
════════════════════════════════════════════════════════════════════════
                    AitherZero Requires PowerShell 7
════════════════════════════════════════════════════════════════════════

You are currently running PowerShell $($PSVersionTable.PSVersion)

AitherZero requires PowerShell 7.0 or later for cross-platform compatibility
and enhanced features.
"@ -ForegroundColor Yellow

    # Check if pwsh is available
    $pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshPath) {
        Write-Host "`n✅ PowerShell 7 is installed at: $($pwshPath.Source)" -ForegroundColor Green
        Write-Host "🔄 Automatically relaunching with PowerShell 7..." -ForegroundColor Cyan
        
        # Prepare arguments for pwsh
        $argList = @('-NoProfile', '-File', $MyInvocation.MyCommand.Path)
        
        # Add all bound parameters
        foreach ($key in $PSBoundParameters.Keys) {
            $value = $PSBoundParameters[$key]
            
            if ($value -is [switch]) {
                if ($value.IsPresent) {
                    $argList += "-$key"
                }
            } elseif ($null -ne $value) {
                $argList += "-$key"
                $argList += $value
            }
        }
        
        # Launch with PowerShell 7
        & $pwshPath.Source @argList
        
        # Exit with the same exit code
        exit $LASTEXITCODE
    } else {
        # PowerShell 7 not found - show installation instructions
        Write-Host @"

📥 INSTALLATION OPTIONS:
════════════════════════

🪟 WINDOWS:
  Option 1 - Windows Package Manager (Recommended):
    winget install Microsoft.PowerShell

  Option 2 - Direct Download:
    https://github.com/PowerShell/PowerShell/releases/latest

  Option 3 - Chocolatey:
    choco install powershell-core

🐧 LINUX:
  Ubuntu/Debian:
    wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    sudo apt-get update
    sudo apt-get install -y powershell

  RHEL/CentOS:
    curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
    sudo yum install -y powershell

🍎 MACOS:
  Option 1 - Homebrew:
    brew install --cask powershell

  Option 2 - Direct Download:
    https://github.com/PowerShell/PowerShell/releases/latest

📘 After Installation:
════════════════════════
1. Close this window
2. Open PowerShell 7 (search for 'pwsh' or 'PowerShell 7')
3. Navigate to the AitherZero directory
4. Run: ./Start-AitherZero.ps1

💡 TIP: You can check if PowerShell 7 is installed by running:
   pwsh --version

For more information, visit:
https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell

════════════════════════════════════════════════════════════════════════
"@ -ForegroundColor Yellow
        
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
}

# If we're running PowerShell 7, proceed with the actual script
Write-Host "✅ PowerShell $($PSVersionTable.PSVersion) detected - proceeding with AitherZero" -ForegroundColor Green

# Pass all parameters to the actual script
$scriptPath = Join-Path $PSScriptRoot "Start-AitherZero.ps1"
if (Test-Path $scriptPath) {
    & $scriptPath @PSBoundParameters
} else {
    Write-Error "Could not find Start-AitherZero.ps1 at: $scriptPath"
}