#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    AitherZero - Unified Entry Point for PowerShell Automation Framework
    
.DESCRIPTION
    This is the main entry point for AitherZero, combining bootstrap capabilities
    with application launch. It handles:
    - PowerShell 7 detection and installation
    - Platform detection and prerequisites
    - Application startup with proper delegation
    
.PARAMETER Auto
    Run in automatic mode without user interaction
    
.PARAMETER Scripts
    Comma-separated list of scripts to run
    
.PARAMETER Setup
    Run first-time setup wizard
    
.PARAMETER InstallationProfile
    Installation profile: minimal, developer, full, or interactive
    
.PARAMETER Bootstrap
    Run full bootstrap installation (clone repo, install prerequisites)
    
.PARAMETER WhatIf
    Preview mode - show what would be done without making changes
    
.PARAMETER Help
    Show help information
    
.PARAMETER NonInteractive
    Run in non-interactive mode (no prompts)
    
.PARAMETER Quiet
    Run in quiet mode with minimal output
    
.PARAMETER Force
    Force operations even if validations fail
    
.PARAMETER OfflineMode
    Run in offline mode (no network operations)
    
.EXAMPLE
    ./Start-AitherZero.ps1
    # Run in interactive mode
    
.EXAMPLE
    ./Start-AitherZero.ps1 -Bootstrap
    # Run full bootstrap installation
    
.EXAMPLE
    ./Start-AitherZero.ps1 -Setup -InstallationProfile developer
    # Run setup wizard with developer profile
    
.EXAMPLE
    curl -sL https://raw.githubusercontent.com/wizzense/AitherZero/main/Start-AitherZero.ps1 | pwsh -s - -Bootstrap
    # Remote bootstrap installation
    
.NOTES
    Version: 3.0.0
    This consolidated version eliminates duplication between bootstrap.ps1 and the original Start-AitherZero.ps1
#>

[CmdletBinding()]
param(
    [switch]$Auto,
    [string]$Scripts,
    [switch]$Setup,
    [ValidateSet("minimal", "developer", "full", "interactive")]
    [string]$InstallationProfile = "interactive",
    [switch]$Bootstrap,
    [switch]$WhatIf,
    [switch]$Help,
    [switch]$NonInteractive,
    [switch]$Quiet,
    [switch]$Force,
    [switch]$OfflineMode,
    [string]$ConfigFile,
    [ValidateSet('silent', 'normal', 'detailed')]
    [string]$Verbosity = 'normal',
    [switch]$EnhancedUI,
    [switch]$ClassicUI,
    [ValidateSet('auto', 'enhanced', 'classic')]
    [string]$UIMode = 'auto'
)

# ════════════════════════════════════════════════════════════════════════════════
#                               INITIALIZATION
# ════════════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Determine script location
$script:ScriptRoot = $PSScriptRoot
if (-not $script:ScriptRoot) {
    $script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Global state
$script:State = @{
    StartTime = Get-Date
    Platform = $null
    PowerShell7Path = $null
    IsBootstrap = $Bootstrap.IsPresent
    ProjectRoot = $script:ScriptRoot
}

# ════════════════════════════════════════════════════════════════════════════════
#                            SHARED UTILITIES
# ════════════════════════════════════════════════════════════════════════════════

function Write-AitherLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )
    
    if ($Quiet -and $Level -ne 'Error') { return }
    if ($Verbosity -eq 'silent' -and $Level -ne 'Error') { return }
    if ($Verbosity -eq 'normal' -and $Level -eq 'Debug') { return }
    
    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Debug' = 'Gray'
    }
    
    $symbols = @{
        'Info' = '[i]'
        'Success' = '[✓]'
        'Warning' = '[!]'
        'Error' = '[✗]'
        'Debug' = '[.]'
    }
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Write-Host "$($symbols[$Level]) [$timestamp] $Message" -ForegroundColor $colors[$Level]
}

function Test-Command {
    param([string]$Command)
    
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        if (Get-Command $Command) { return $true }
        return $false
    } finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Get-PlatformInfo {
    $info = @{
        Platform = ''
        Version = ''
        Architecture = ''
        IsWSL = $false
        Distribution = ''
    }
    
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSEdition -eq 'Desktop') {
        $info.Platform = 'Windows'
        $info.Version = [System.Environment]::OSVersion.Version.ToString()
        $info.Architecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
        
        # Check if running in WSL
        if (Test-Path '/proc/version') {
            $procVersion = Get-Content '/proc/version' -Raw -ErrorAction SilentlyContinue
            if ($procVersion -match 'microsoft|wsl') {
                $info.IsWSL = $true
                $info.Platform = 'Linux'
                $info.Distribution = 'WSL'
            }
        }
    } elseif ($IsLinux -or $PSVersionTable.Platform -eq 'Unix') {
        $info.Platform = 'Linux'
        
        if (Test-Path '/etc/os-release') {
            $osRelease = Get-Content '/etc/os-release' | ConvertFrom-StringData
            $info.Distribution = $osRelease.ID
            $info.Version = $osRelease.VERSION_ID
        }
        
        $info.Architecture = & uname -m
    } elseif ($IsMacOS) {
        $info.Platform = 'macOS'
        $info.Version = & sw_vers -productVersion
        $info.Architecture = & uname -m
    } else {
        $info.Platform = 'Unknown'
    }
    
    return $info
}

# ════════════════════════════════════════════════════════════════════════════════
#                         POWERSHELL 7 MANAGEMENT
# ════════════════════════════════════════════════════════════════════════════════

function Find-PowerShell7 {
    Write-AitherLog "Searching for PowerShell 7..." -Level Debug
    
    # Quick check for pwsh in PATH
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        Write-AitherLog "Found PowerShell 7 at: $($pwshCmd.Source)" -Level Debug
        return $pwshCmd.Source
    }
    
    # Platform-specific search paths
    $searchPaths = @()
    
    if ($script:State.Platform.Platform -eq 'Windows') {
        $searchPaths = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe",
            "$env:LocalAppData\Microsoft\PowerShell\pwsh.exe"
        )
    } elseif ($script:State.Platform.Platform -eq 'Linux') {
        $searchPaths = @(
            '/usr/bin/pwsh',
            '/usr/local/bin/pwsh',
            '/opt/microsoft/powershell/7/pwsh',
            "$HOME/.dotnet/tools/pwsh"
        )
    } elseif ($script:State.Platform.Platform -eq 'macOS') {
        $searchPaths = @(
            '/usr/local/bin/pwsh',
            '/opt/homebrew/bin/pwsh',
            '/usr/local/microsoft/powershell/7/pwsh'
        )
    }
    
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            Write-AitherLog "Found PowerShell 7 at: $path" -Level Debug
            return $path
        }
    }
    
    return $null
}

function Install-PowerShell7 {
    Write-AitherLog "Installing PowerShell 7 for $($script:State.Platform.Platform)..." -Level Info
    
    if ($OfflineMode) {
        Write-AitherLog "Cannot install PowerShell 7 in offline mode" -Level Error
        Show-OfflineInstallGuide
        return $false
    }
    
    try {
        switch ($script:State.Platform.Platform) {
            'Windows' {
                if (-not $script:State.Platform.IsWSL) {
                    $url = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
                    $installer = Join-Path $env:TEMP "PowerShell-7.msi"
                    
                    Write-AitherLog "Downloading PowerShell 7 installer..." -Level Info
                    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
                    
                    Write-AitherLog "Running installer..." -Level Info
                    $arguments = @("/i", $installer, "/quiet", "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1", "ENABLE_PSREMOTING=1")
                    Start-Process msiexec.exe -ArgumentList $arguments -Wait
                    
                    Remove-Item $installer -Force
                }
            }
            'Linux' {
                switch ($script:State.Platform.Distribution) {
                    { $_ -in 'ubuntu', 'debian' } {
                        Write-AitherLog "Installing via apt..." -Level Info
                        $commands = @(
                            "wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb",
                            "sudo dpkg -i packages-microsoft-prod.deb",
                            "sudo apt-get update",
                            "sudo apt-get install -y powershell",
                            "rm packages-microsoft-prod.deb"
                        )
                        
                        foreach ($cmd in $commands) {
                            Write-AitherLog "Running: $cmd" -Level Debug
                            Invoke-Expression $cmd
                            if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
                        }
                    }
                    { $_ -in 'rhel', 'centos', 'fedora' } {
                        Write-AitherLog "Installing via yum..." -Level Info
                        $commands = @(
                            "curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo",
                            "sudo yum install -y powershell"
                        )
                        
                        foreach ($cmd in $commands) {
                            Write-AitherLog "Running: $cmd" -Level Debug
                            Invoke-Expression $cmd
                            if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
                        }
                    }
                    default {
                        Write-AitherLog "Automated installation not available for $($script:State.Platform.Distribution)" -Level Error
                        return $false
                    }
                }
            }
            'macOS' {
                if (Test-Command 'brew') {
                    Write-AitherLog "Installing via Homebrew..." -Level Info
                    & brew install --cask powershell
                } else {
                    Write-AitherLog "Installing Homebrew first..." -Level Info
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                    & brew install --cask powershell
                }
            }
        }
        
        Write-AitherLog "PowerShell 7 installation completed" -Level Success
        return $true
        
    } catch {
        Write-AitherLog "PowerShell 7 installation failed: $_" -Level Error
        return $false
    }
}

function Start-WithPowerShell7 {
    param([string]$PowerShell7Path)
    
    Write-AitherLog "Restarting with PowerShell 7..." -Level Info
    
    # Build argument list preserving all parameters
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MyInvocation.MyCommand.Path)
    
    foreach ($key in $PSBoundParameters.Keys) {
        $value = $PSBoundParameters[$key]
        if ($value -is [switch]) {
            if ($value.IsPresent) { $argList += "-$key" }
        } elseif ($null -ne $value) {
            $argList += "-$key", $value
        }
    }
    
    & $PowerShell7Path @argList
    exit $LASTEXITCODE
}

# ════════════════════════════════════════════════════════════════════════════════
#                           BOOTSTRAP FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

function Install-Prerequisites {
    Write-AitherLog "Installing prerequisites for $($script:State.Platform.Platform)..." -Level Info
    
    $prerequisites = @{
        'Windows' = @{
            Commands = @('git', 'code')
            Installer = {
                # Install Chocolatey if not present
                if (-not (Test-Command 'choco')) {
                    Write-AitherLog "Installing Chocolatey..." -Level Info
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                }
                
                # Install prerequisites via Chocolatey
                $packages = @('git', 'vscode', 'nodejs')
                foreach ($package in $packages) {
                    if (-not (Test-Command $package)) {
                        Write-AitherLog "Installing $package..." -Level Info
                        choco install $package -y --no-progress
                    }
                }
            }
        }
        'Linux' = @{
            Commands = @('git', 'curl', 'wget')
            Installer = {
                $packages = @('git', 'curl', 'wget', 'build-essential')
                
                switch ($script:State.Platform.Distribution) {
                    { $_ -in 'ubuntu', 'debian' } {
                        Write-AitherLog "Updating package lists..." -Level Info
                        sudo apt-get update
                        Write-AitherLog "Installing packages..." -Level Info
                        sudo apt-get install -y $packages
                    }
                    { $_ -in 'rhel', 'centos', 'fedora' } {
                        Write-AitherLog "Installing packages..." -Level Info
                        sudo yum install -y $packages
                    }
                }
            }
        }
        'macOS' = @{
            Commands = @('git', 'brew')
            Installer = {
                # Install Homebrew if not present
                if (-not (Test-Command 'brew')) {
                    Write-AitherLog "Installing Homebrew..." -Level Info
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                }
                
                # Install prerequisites
                $packages = @('git', 'node')
                foreach ($package in $packages) {
                    if (-not (Test-Command $package)) {
                        Write-AitherLog "Installing $package..." -Level Info
                        brew install $package
                    }
                }
            }
        }
    }
    
    # Check and install prerequisites
    $prereq = $prerequisites[$script:State.Platform.Platform]
    if ($prereq -and $prereq.Installer) {
        & $prereq.Installer
    }
    
    Write-AitherLog "Prerequisites installation completed" -Level Success
}

function Get-AitherZero {
    param([string]$TargetPath)
    
    if (-not $TargetPath) {
        if ($script:State.Platform.Platform -eq 'Windows' -and -not $script:State.Platform.IsWSL) {
            $TargetPath = Join-Path $env:USERPROFILE 'AitherZero'
        } else {
            $TargetPath = Join-Path $HOME 'AitherZero'
        }
    }
    
    Write-AitherLog "Installing AitherZero to: $TargetPath" -Level Info
    
    # Check if already exists
    if (Test-Path $TargetPath) {
        if ($Force) {
            Write-AitherLog "Removing existing installation..." -Level Warning
            Remove-Item -Path $TargetPath -Recurse -Force
        } else {
            Write-AitherLog "AitherZero already exists at $TargetPath" -Level Warning
            if (-not $NonInteractive) {
                $response = Read-Host "Remove and reinstall? (y/N)"
                if ($response -eq 'y') {
                    Remove-Item -Path $TargetPath -Recurse -Force
                } else {
                    return $TargetPath
                }
            } else {
                return $TargetPath
            }
        }
    }
    
    # Clone repository
    Write-AitherLog "Cloning AitherZero repository..." -Level Info
    $gitUrl = "https://github.com/wizzense/AitherZero.git"
    
    try {
        git clone $gitUrl $TargetPath --depth 1
        Write-AitherLog "Repository cloned successfully" -Level Success
        $script:State.ProjectRoot = $TargetPath
    } catch {
        Write-AitherLog "Failed to clone repository: $_" -Level Error
        throw
    }
    
    return $TargetPath
}

# ════════════════════════════════════════════════════════════════════════════════
#                         APPLICATION FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

function Start-AitherCore {
    Write-AitherLog "Starting AitherZero core application..." -Level Info
    
    # Verify core script exists
    $coreScript = Join-Path $script:State.ProjectRoot "aither-core/aither-core.ps1"
    if (-not (Test-Path $coreScript)) {
        Write-AitherLog "Core script not found at: $coreScript" -Level Error
        Write-AitherLog "Please ensure AitherZero is properly installed" -Level Error
        return $false
    }
    
    # Build parameter hashtable for delegation
    $coreParams = @{}
    if ($Auto) { $coreParams['Auto'] = $true }
    if ($Scripts) { $coreParams['Scripts'] = $Scripts }
    if ($Setup) { $coreParams['Setup'] = $true }
    if ($InstallationProfile) { $coreParams['InstallationProfile'] = $InstallationProfile }
    if ($WhatIf) { $coreParams['WhatIf'] = $true }
    if ($NonInteractive) { $coreParams['NonInteractive'] = $true }
    if ($Quiet) { $coreParams['Quiet'] = $true }
    if ($Verbosity) { $coreParams['Verbosity'] = $Verbosity }
    if ($ConfigFile) { $coreParams['ConfigFile'] = $ConfigFile }
    if ($Force) { $coreParams['Force'] = $true }
    if ($EnhancedUI) { $coreParams['EnhancedUI'] = $true }
    if ($ClassicUI) { $coreParams['ClassicUI'] = $true }
    if ($UIMode) { $coreParams['UIMode'] = $UIMode }
    
    try {
        & $coreScript @coreParams
        return $true
    } catch {
        Write-AitherLog "Failed to start core application: $_" -Level Error
        return $false
    }
}

# ════════════════════════════════════════════════════════════════════════════════
#                              HELP FUNCTIONS
# ════════════════════════════════════════════════════════════════════════════════

function Show-Help {
    Write-Host @"

AitherZero - PowerShell Automation Framework
Version 3.0.0

USAGE:
    ./Start-AitherZero.ps1 [options]

OPTIONS:
    -Auto                Run in automatic mode
    -Scripts <list>      Comma-separated list of scripts to run
    -Setup               Run first-time setup wizard
    -InstallationProfile Profile: minimal, developer, full, interactive
    -Bootstrap           Run full bootstrap installation
    -WhatIf              Preview mode
    -Help                Show this help
    -NonInteractive      No prompts
    -Quiet               Minimal output
    -Force               Force operations
    -OfflineMode         No network operations

EXAMPLES:
    # Standard run
    ./Start-AitherZero.ps1
    
    # Bootstrap from fresh system
    ./Start-AitherZero.ps1 -Bootstrap
    
    # Setup with specific profile
    ./Start-AitherZero.ps1 -Setup -InstallationProfile developer
    
    # Remote bootstrap
    curl -sL https://raw.githubusercontent.com/wizzense/AitherZero/main/Start-AitherZero.ps1 | pwsh -s - -Bootstrap

For more information, visit: https://github.com/wizzense/AitherZero

"@
}

function Show-OfflineInstallGuide {
    Write-Host @"

📡 OFFLINE MODE - Manual Installation Required

PowerShell 7 is required but not found, and offline mode is enabled.

INSTALLATION OPTIONS:

1. Download PowerShell 7 installer on a connected machine:
   https://github.com/PowerShell/PowerShell/releases/latest

2. Transfer the installer to this machine and run it manually

3. After installation:
   - Restart your terminal
   - Run this script again

"@ -ForegroundColor Yellow
}

# ════════════════════════════════════════════════════════════════════════════════
#                              MAIN EXECUTION
# ════════════════════════════════════════════════════════════════════════════════

try {
    # Handle help request
    if ($Help) {
        Show-Help
        exit 0
    }
    
    # Show banner
    if (-not $Quiet) {
        Write-Host @"
════════════════════════════════════════════════════════════════════════════════
                        🚀 AitherZero v3.0.0 🚀
                   PowerShell Automation Framework
════════════════════════════════════════════════════════════════════════════════
"@ -ForegroundColor Cyan
    }
    
    # Detect platform
    Write-AitherLog "Detecting platform..." -Level Info
    $script:State.Platform = Get-PlatformInfo
    Write-AitherLog "Platform: $($script:State.Platform.Platform) $($script:State.Platform.Version)" -Level Success
    
    # Check PowerShell version
    $currentVersion = $PSVersionTable.PSVersion
    Write-AitherLog "PowerShell version: $currentVersion" -Level Info
    
    if ($currentVersion.Major -lt 7) {
        Write-AitherLog "PowerShell 7+ required (current: $currentVersion)" -Level Warning
        
        # Try to find PowerShell 7
        $pwsh7Path = Find-PowerShell7
        
        if ($pwsh7Path) {
            $script:State.PowerShell7Path = $pwsh7Path
            Start-WithPowerShell7 -PowerShell7Path $pwsh7Path
        } else {
            # Ask to install
            if ($NonInteractive -or $Auto) {
                $install = $true
            } else {
                Write-Host "`nPowerShell 7 is required but not found." -ForegroundColor Yellow
                $response = Read-Host "Install PowerShell 7 automatically? (Y/n)"
                $install = ($response -eq '' -or $response -eq 'y' -or $response -eq 'Y')
            }
            
            if ($install) {
                if (Install-PowerShell7) {
                    Write-AitherLog "Please restart the script with PowerShell 7" -Level Warning
                    Write-Host "Run: pwsh $($MyInvocation.MyCommand.Path) $($args -join ' ')" -ForegroundColor Yellow
                } else {
                    Write-AitherLog "PowerShell 7 installation failed" -Level Error
                }
            } else {
                Show-OfflineInstallGuide
            }
            exit 1
        }
    }
    
    # Running on PowerShell 7+
    Write-AitherLog "PowerShell 7+ detected" -Level Success
    
    # Handle bootstrap mode
    if ($Bootstrap) {
        Write-AitherLog "Running bootstrap installation..." -Level Info
        
        # Install prerequisites
        if (-not $OfflineMode) {
            Install-Prerequisites
        }
        
        # Clone/Install AitherZero
        $installPath = Get-AitherZero
        
        Write-AitherLog "Bootstrap completed successfully!" -Level Success
        Write-Host "`nAitherZero installed to: $installPath" -ForegroundColor Green
        Write-Host "To start AitherZero, run:" -ForegroundColor Cyan
        Write-Host "  cd $installPath" -ForegroundColor White
        Write-Host "  ./Start-AitherZero.ps1" -ForegroundColor White
        Write-Host ""
        
        exit 0
    }
    
    # Normal mode - start application
    if (-not (Test-Path (Join-Path $script:State.ProjectRoot "aither-core"))) {
        Write-AitherLog "AitherZero not found in current directory" -Level Error
        Write-AitherLog "Run with -Bootstrap to install, or navigate to AitherZero directory" -Level Info
        exit 1
    }
    
    # Start the core application
    if (Start-AitherCore) {
        exit 0
    } else {
        exit 1
    }
    
} catch {
    Write-AitherLog "Fatal error: $_" -Level Error
    Write-AitherLog $_.ScriptStackTrace -Level Debug
    exit 1
}