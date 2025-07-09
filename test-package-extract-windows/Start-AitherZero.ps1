<#
.SYNOPSIS
    AitherZero Infrastructure Automation Framework - Universal Launcher

.DESCRIPTION
    This is the ONLY entry point for AitherZero infrastructure automation framework.
    It automatically detects PowerShell version requirements and handles cross-platform compatibility.
    
    ✅ SIMPLE USAGE:
    - First time: ./Start-AitherZero.ps1 -Setup
    - Regular use: ./Start-AitherZero.ps1
    - Quick deployment: ./Start-AitherZero.ps1 -Scripts "LabRunner"

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

# Import PowerShell version checking utility
$versionCheckPath = Join-Path $PSScriptRoot "aither-core/shared/Test-PowerShellVersion.ps1"
if (Test-Path $versionCheckPath) {
    . $versionCheckPath
} else {
    Write-Error "PowerShell version check utility not found. Please ensure AitherZero is properly installed."
    exit 1
}

# ══════════════════════════════════════════════════════════════════════════════
#                          POWERSHELL VERSION CHECK
# ══════════════════════════════════════════════════════════════════════════════

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host @"
════════════════════════════════════════════════════════════════════════
                     ⚡ AitherZero Requires PowerShell 7 ⚡
════════════════════════════════════════════════════════════════════════

You are currently running PowerShell $($PSVersionTable.PSVersion)

AitherZero requires PowerShell 7.0+ for:
  ✅ Cross-platform compatibility (Windows/Linux/macOS)
  ✅ Enhanced performance and security features
  ✅ Modern automation capabilities

"@ -ForegroundColor Yellow

    # Check if PowerShell 7 is already installed
    $pwsh7Path = $null
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $pwsh7Path = $pwshCmd.Source
        Write-Host "✅ Great! PowerShell 7 is already installed at: $pwsh7Path" -ForegroundColor Green
        Write-Host "🔄 Automatically switching to PowerShell 7..." -ForegroundColor Cyan
        
        # Prepare arguments for pwsh
        $argList = @('-NoProfile', '-File', $MyInvocation.MyCommand.Path)
        
        # Add all bound parameters
        foreach ($key in $PSBoundParameters.Keys) {
            $value = $PSBoundParameters[$key]
            if ($value -is [switch]) {
                if ($value.IsPresent) { $argList += "-$key" }
            } elseif ($null -ne $value) {
                $argList += "-$key", $value
            }
        }
        
        # Launch with PowerShell 7
        & $pwsh7Path @argList
        exit $LASTEXITCODE
    }
    
    # PowerShell 7 not found - show installation instructions
    Write-Host @"

📥 QUICK INSTALLATION:
══════════════════════

🪟 WINDOWS (choose one):
  • Windows Package Manager: winget install Microsoft.PowerShell
  • Chocolatey:              choco install powershell-core
  • Direct download:          https://aka.ms/powershell-release

🐧 LINUX:
  • Ubuntu/Debian:  sudo snap install powershell --classic
  • RHEL/CentOS:     sudo yum install powershell
  • More options:    https://aka.ms/powershell-linux

🍎 MACOS:
  • Homebrew:       brew install --cask powershell
  • Direct download: https://aka.ms/powershell-release

💡 AFTER INSTALLATION:
════════════════════════
1. Close this window
2. Open PowerShell 7 (search for 'pwsh' or 'PowerShell 7')
3. Navigate to: $PSScriptRoot
4. Run: ./Start-AitherZero.ps1

🔍 Verify installation: pwsh --version

════════════════════════════════════════════════════════════════════════
"@ -ForegroundColor Yellow
    
    Write-Host "`n👆 Press any key to open PowerShell installation page..." -ForegroundColor Cyan
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
            Start-Process "https://aka.ms/powershell-release"
        }
    } catch {
        # Graceful fallback if ReadKey is not supported
    }
    
    exit 1
}

Write-Host "✅ PowerShell $($PSVersionTable.PSVersion) - Ready to launch AitherZero!" -ForegroundColor Green

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
if ($Quiet) { $coreparams['Quiet'] = $true }
if ($Verbosity) { $coreparams['Verbosity'] = $Verbosity }
if ($ConfigFile) { $coreparams['ConfigFile'] = $ConfigFile }
if ($Force) { $coreparams['Force'] = $true }
if ($EnhancedUI) { $coreparams['EnhancedUI'] = $true }
if ($ClassicUI) { $coreparams['ClassicUI'] = $true }
if ($UIMode) { $coreparams['UIMode'] = $UIMode }

try {
    & $coreScript @coreparams
} catch {
    # Load user-friendly error system
    $errorHelperPath = Join-Path (Join-Path $scriptPath "aither-core/shared") "Show-UserFriendlyError.ps1"
    if (Test-Path $errorHelperPath) {
        . $errorHelperPath
        Show-UserFriendlyError -ErrorRecord $_ -Context "Starting AitherZero" -Module "Core"
    } else {
        # Fallback to basic user-friendly error
        Write-Host "" -ForegroundColor Yellow
        Write-Host "❌ AitherZero failed to start" -ForegroundColor Red
        Write-Host "" -ForegroundColor Yellow
        Write-Host "What happened:" -ForegroundColor Cyan
        Write-Host "  $($_.Exception.Message)" -ForegroundColor White
        Write-Host "" -ForegroundColor Yellow
        Write-Host "How to fix it:" -ForegroundColor Green
        Write-Host "  1. Try running setup: ./Start-AitherZero.ps1 -Setup" -ForegroundColor Green
        Write-Host "  2. Check if all files were extracted properly" -ForegroundColor Green
        Write-Host "  3. Make sure you have PowerShell 7.0 or newer" -ForegroundColor Green
        Write-Host "" -ForegroundColor Yellow
        Write-Host "For more help: https://github.com/wizzense/AitherZero/blob/main/README.md" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Yellow
    }
    exit 1
}
