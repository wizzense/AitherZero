#!/usr/bin/env pwsh
# Supports PowerShell 5.1+ but will install PowerShell 7

<#
.SYNOPSIS
    AitherZero Bootstrap Script - One-liner installation and setup
.DESCRIPTION
    Cross-platform bootstrap script for AitherZero with automatic dependency resolution
.PARAMETER Mode
    Installation mode: New, Update, Clean, Remove
.PARAMETER InstallProfile
    Installation profile: Minimal, Standard, Developer, Full
.PARAMETER InstallPath
    Custom installation path (default: ./AitherZero)
.PARAMETER Branch
    Git branch to use (default: main)
.PARAMETER NonInteractive
    Run without prompts
.PARAMETER AutoInstallDeps
    Automatically install missing dependencies
.PARAMETER SkipAutoStart
    Don't auto-start AitherZero after installation
.EXAMPLE
    # One-liner installation (PowerShell 5.1+)
    iwr -useb https://raw.githubusercontent.com/yourusername/AitherZero/main/bootstrap.ps1 | iex

    # One-liner with options
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/yourusername/AitherZero/main/bootstrap.ps1))) -InstallProfile Developer -AutoInstallDeps
#>

[CmdletBinding()]
param(
    [ValidateSet('New', 'Update', 'Clean', 'Remove')]
    [string]$Mode = 'New',
    
    [ValidateSet('Minimal', 'Standard', 'Developer', 'Full')]
    [string]$InstallProfile = 'Standard',
    
    [string]$InstallPath,
    
    [string]$Branch = 'main',
    
    [switch]$NonInteractive,
    
    [switch]$AutoInstallDeps,
    
    [switch]$SkipAutoStart
)

# Script configuration
$script:RepoOwner = "yourusername"
$script:RepoName = "AitherZero"
$script:GitHubUrl = "https://github.com/$script:RepoOwner/$script:RepoName"
$script:RawContentUrl = "https://raw.githubusercontent.com/$script:RepoOwner/$script:RepoName"

# Enable TLS 1.2 for older systems
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set error action preference
$ErrorActionPreference = 'Stop'

# Helper functions
function Write-BootstrapLog {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )

    $colors = @{
        'Header' = 'Cyan'
        'Info' = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    $prefix = @{
        'Header' = ''
        'Info' = '[*]'
        'Success' = '[+]'
        'Warning' = '[!]'
        'Error' = '[-]'
    }

    if ($Level -eq 'Header') {
        Write-Host "`n$Message" -ForegroundColor $colors[$Level]
        Write-Host ('=' * $Message.Length) -ForegroundColor $colors[$Level]
    } else {
        Write-Host "$($prefix[$Level]) $Message" -ForegroundColor $colors[$Level]
    }
}

function Test-IsWindows {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $IsWindows
    }
    return $true
}

function Test-IsAdmin {
    if (Test-IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]$identity
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } else {
        return (id -u) -eq 0
    }
}

function Get-DefaultInstallPath {
    if (-not $InstallPath) {
        $currentPath = Get-Location
        
        # Check if in system directory on Windows
        if (Test-IsWindows) {
            $systemPaths = @('C:\Windows', 'C:\Program Files', 'C:\Program Files (x86)')
            foreach ($sysPath in $systemPaths) {
                if ($currentPath.Path.StartsWith($sysPath)) {
                    return Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AitherZero'
                }
            }
        }
        
        return Join-Path $currentPath 'AitherZero'
    }
    return $InstallPath
}

function Test-Dependencies {
    Write-BootstrapLog "Checking dependencies..." -Level Info
    
    $missing = @()

    # Check Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += 'Git'
    }

    # Check PowerShell version - we NEED PowerShell 7
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $missing += 'PowerShell7'
        Write-BootstrapLog "PowerShell 7 is required. Current version: $($PSVersionTable.PSVersion)" -Level Warning
    }

    if ($missing.Count -gt 0) {
        if ($AutoInstallDeps -or $missing -contains 'PowerShell7') {
            Install-Dependencies -Missing $missing
        } else {
            throw "Missing dependencies: $($missing -join ', '). Use -AutoInstallDeps to install automatically."
        }
    }
}

function Install-Dependencies {
    param([string[]]$Missing)

    # Install PowerShell 7 first if needed
    if ($Missing -contains 'PowerShell7') {
        Install-PowerShell7
        
        # Re-launch in PowerShell 7
        Write-BootstrapLog "Re-launching bootstrap in PowerShell 7..." -Level Info
        
        $pwsh = if (Test-IsWindows) { "pwsh.exe" } else { "pwsh" }
        $scriptPath = $MyInvocation.PSCommandPath
        
        # Build arguments to preserve
        $args = @()
        if ($Mode) { $args += "-Mode", $Mode }
        if ($InstallProfile) { $args += "-InstallProfile", $InstallProfile }
        if ($InstallPath) { $args += "-InstallPath", $InstallPath }
        if ($Branch) { $args += "-Branch", $Branch }
        if ($NonInteractive) { $args += "-NonInteractive" }
        if ($AutoInstallDeps) { $args += "-AutoInstallDeps" }
        if ($SkipAutoStart) { $args += "-SkipAutoStart" }
        
        & $pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath @args
        exit $LASTEXITCODE
    }
    
    foreach ($dep in $Missing) {
        Write-BootstrapLog "Installing $dep..." -Level Info
        
        switch ($dep) {
            'Git' {
                if (Test-IsWindows) {
                    # Try winget first
                    if (Get-Command winget -ErrorAction SilentlyContinue) {
                        winget install --id Git.Git -e --source winget --accept-source-agreements --accept-package-agreements
                    } else {
                        # Download and install Git
                        $gitInstaller = "$env:TEMP\git-installer.exe"
                        Write-BootstrapLog "Downloading Git installer..." -Level Info
                        Invoke-WebRequest -Uri "https://github.com/git-for-windows/git/releases/latest/download/Git-64-bit.exe" -OutFile $gitInstaller
                        Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
                        Remove-Item $gitInstaller -Force
                    }
                } elseif ($IsMacOS) {
                    if (Get-Command brew -ErrorAction SilentlyContinue) {
                        brew install git
                    } else {
                        throw "Please install Homebrew first: /bin/bash -c `"`$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)`""
                    }
                } else {
                    # Linux
                    if (Get-Command apt -ErrorAction SilentlyContinue) {
                        sudo apt update && sudo apt install -y git
                    } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                        sudo yum install -y git
                    } else {
                        throw "Please install Git manually for your distribution"
                    }
                }
                
                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            }
        }
    }
}

function Install-PowerShell7 {
    Write-BootstrapLog "Installing PowerShell 7..." -Level Info

    if (Test-IsWindows) {
        # Windows installation
        $installUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
        $msiPath = "$env:TEMP\PowerShell-7-win-x64.msi"
        
        try {
            # Try winget first
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-BootstrapLog "Installing via winget..." -Level Info
                winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-BootstrapLog "PowerShell 7 installed successfully via winget" -Level Success
                    return
                }
            }

            # Fallback to MSI
            Write-BootstrapLog "Downloading PowerShell 7 MSI..." -Level Info
            Invoke-WebRequest -Uri $installUrl -OutFile $msiPath -UseBasicParsing
            
            Write-BootstrapLog "Installing PowerShell 7 MSI..." -Level Info
            $arguments = "/i `"$msiPath`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1"

            if (Test-IsAdmin) {
                Start-Process msiexec.exe -ArgumentList $arguments -Wait
            } else {
                # Try to elevate
                Start-Process msiexec.exe -ArgumentList $arguments -Verb RunAs -Wait
            }
            
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            Write-BootstrapLog "PowerShell 7 installed successfully" -Level Success
            
        } catch {
            Write-BootstrapLog "Failed to install PowerShell 7: $_" -Level Error
            throw
        }
        
    } elseif ($IsMacOS) {
        # macOS installation
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-BootstrapLog "Installing via Homebrew..." -Level Info
            brew install --cask powershell
        } else {
            Write-BootstrapLog "Installing Homebrew first..." -Level Info
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install --cask powershell
        }
        
    } else {
        # Linux installation
        Write-BootstrapLog "Installing PowerShell 7 for Linux..." -Level Info
        
        # Download and run Microsoft's install script
        $installScript = "$env:HOME/install-powershell.sh"
        Invoke-WebRequest -Uri https://aka.ms/install-powershell.sh -OutFile $installScript
        chmod +x $installScript
        sudo $installScript
        Remove-Item $installScript -Force
    }

    # Verify installation
    $pwshPath = if (Test-IsWindows) { 
        "$env:ProgramFiles\PowerShell\7\pwsh.exe" 
    } else { 
        "/usr/bin/pwsh" 
    }

    if (-not (Test-Path $pwshPath)) {
        # Check in PATH
        if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            throw "PowerShell 7 installation completed but pwsh not found"
        }
    }
    
    Write-BootstrapLog "PowerShell 7 installed successfully!" -Level Success
}

function Install-AitherZero {
    # Check if we're already in an AitherZero project
    $currentPath = Get-Location
    $isAitherProject = (Test-Path "./Start-AitherZero.ps1") -or 
                       (Test-Path "./domains") -or 
                       (Test-Path "./automation-scripts")

    if ($isAitherProject) {
        Write-BootstrapLog "Detected existing AitherZero project at: $currentPath" -Level Info
        $installPath = $currentPath.Path
        
        # Just set up the environment, don't clone anything
        Write-BootstrapLog "Setting up development environment..." -Level Info
        
        # Initialize configuration
        Initialize-Configuration
        
        # Set up development environment  
        Setup-DevelopmentEnvironment
        
        return $installPath
    }

    # If not in a project, then do the normal install
    $installPath = Get-DefaultInstallPath
    
    Write-BootstrapLog "Installing AitherZero to: $installPath" -Level Info

    # Check if exists
    if ((Test-Path $installPath) -and $Mode -eq 'New') {
        # Check if it's already an AitherZero project
        Push-Location $installPath
        $existingProject = (Test-Path "./Start-AitherZero.ps1") -or 
                          (Test-Path "./domains") -or 
                          (Test-Path "./automation-scripts")
        Pop-Location
        
        if ($existingProject) {
            Write-BootstrapLog "Found existing AitherZero project" -Level Info
            Push-Location $installPath
            try {
                # Just set up environment
                Initialize-Configuration
                Setup-DevelopmentEnvironment
            } finally {
                Pop-Location
            }
            return $installPath
        }
        
        if (-not $NonInteractive) {
            $response = Read-Host "Directory exists at $installPath. Overwrite? (y/N)"
            if ($response -ne 'y') {
                Write-BootstrapLog "Installation cancelled" -Level Warning
                return
            }
        } else {
            throw "Directory already exists. Use -Mode Update or Clean"
        }
    }

    # Clean if requested
    if ($Mode -eq 'Clean' -and (Test-Path $installPath)) {
        Write-BootstrapLog "Cleaning existing installation..." -Level Info
        Remove-Item $installPath -Recurse -Force
    }

    # Create directory
    if (-not (Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    }

    # Clone repository only if we have a valid GitHub URL
    if ($script:GitHubUrl -ne "https://github.com/yourusername/AitherZero") {
        Write-BootstrapLog "Cloning AitherZero repository..." -Level Info
        
        Push-Location $installPath
        try {
            if (Test-Path ".git") {
                # Update existing
                git pull origin $Branch
            } else {
                # Fresh clone
                git clone --branch $Branch $script:GitHubUrl .
            }
            
            Write-BootstrapLog "Repository cloned successfully" -Level Success
        } catch {
            Write-BootstrapLog "Clone failed - assuming local development" -Level Warning
        } finally {
            Pop-Location
        }
    } else {
        Write-BootstrapLog "No repository URL configured - setting up for local development" -Level Info
    }
    
    Push-Location $installPath
    try {
        # Initialize configuration
        Initialize-Configuration
        
        # Set up development environment
        Setup-DevelopmentEnvironment
    } finally {
        Pop-Location
    }
    
    return $installPath
}

function Initialize-Configuration {
    Write-BootstrapLog "Initializing configuration..." -Level Info

    # Create default config if doesn't exist
    $configPath = "config.json"
    if (-not (Test-Path $configPath)) {
        $config = @{
            Core = @{
                Name = "AitherZero"
                Version = "1.0.0"
                Profile = $InstallProfile
                Environment = "Development"
            }
            Infrastructure = @{
                Provider = "opentofu"
                WorkingDirectory = "./infrastructure"
            }
            Logging = @{
                Level = "Information"
                Path = "./logs"
                Targets = @("Console", "File")
            }
            Automation = @{
                ScriptsPath = "./automation-scripts"
                MaxConcurrency = [Environment]::ProcessorCount
                DefaultTimeout = 30
            }
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
        Write-BootstrapLog "Created default configuration" -Level Success
    }

    # Create necessary directories
    $directories = @("logs", "tests/results", "tests/reports", "tests/analysis")
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-BootstrapLog "Created directory: $dir" -Level Info
        }
    }
}

function Setup-DevelopmentEnvironment {
    Write-BootstrapLog "Setting up development environment..." -Level Info

    # 1. Add to PowerShell profile for automatic loading
    $profileContent = @'
# AitherZero Auto-Load
if ($PWD.Path -like "*AitherZero*") {
    $azPsd1 = Get-ChildItem -Path $PWD.Path -Filter "AitherZero.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($azPsd1 -and -not $env:AITHERZERO_INITIALIZED) {
        Import-Module $azPsd1.FullName -Force -Global
        Write-Host "✓ AitherZero environment loaded" -ForegroundColor Green
    }
}
'@
    
    $profiles = @(
        $PROFILE.CurrentUserAllHosts,
        $PROFILE.CurrentUserCurrentHost
    )

    foreach ($profilePath in $profiles) {
        if ($profilePath -and $profilePath -ne '') {
            $profileDir = Split-Path $profilePath -Parent -ErrorAction SilentlyContinue
            if ($profileDir -and -not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }

            if ($profilePath -and (Test-Path $profilePath)) {
                $currentContent = Get-Content $profilePath -Raw
                if ($currentContent -notlike "*AitherZero Auto-Load*") {
                    Add-Content -Path $profilePath -Value "`n$profileContent"
                    Write-BootstrapLog "Updated PowerShell profile: $profilePath" -Level Success
                }
            } elseif ($profilePath) {
                Set-Content -Path $profilePath -Value $profileContent
                Write-BootstrapLog "Created PowerShell profile: $profilePath" -Level Success
            }
        }
    }

    # 2. Create convenient shell scripts
    # For Unix-like systems
    if (-not (Test-IsWindows)) {
        # Create az command
        $azScript = @'
#!/usr/bin/env pwsh
$root = $PSScriptRoot
if (-not $env:AITHERZERO_INITIALIZED) {
    Import-Module "$root/AitherZero.psd1" -Force -Global
}
& "$root/az.ps1" $args
'@
        $azScript | Set-Content "./az" -Force
        chmod +x ./az 2>$null
        
        # Create shell activation script
        $activateScript = @'
#!/bin/bash
# AitherZero environment activation
export AITHERZERO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$AITHERZERO_ROOT/automation-scripts:$PATH"
alias az="pwsh $AITHERZERO_ROOT/az.ps1"
alias aither="pwsh $AITHERZERO_ROOT/Start-AitherZero.ps1"
echo "✓ AitherZero environment activated"
echo "  Commands: az <num>, aither"
'@
        $activateScript | Set-Content "./activate.sh" -Force
        chmod +x ./activate.sh 2>$null
        
        Write-BootstrapLog "Created Unix shell helpers (./az, ./activate.sh)" -Level Success
    }

    # 3. Create Windows batch files
    if (Test-IsWindows) {
        # az.cmd
        @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0az.ps1" %*
'@ | Set-Content "./az.cmd" -Force
        
        # aither.cmd  
        @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-AitherZero.ps1" %*
'@ | Set-Content "./aither.cmd" -Force
        
        Write-BootstrapLog "Created Windows command helpers (az.cmd, aither.cmd)" -Level Success
    }

    # 4. Set up VS Code integration
    $vscodeDir = ".vscode"
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    }
    
    $vscodeSettings = @{
        "terminal.integrated.env.windows" = @{
            "AITHERZERO_ROOT" = "`${workspaceFolder}"
        }
        "terminal.integrated.env.linux" = @{
            "AITHERZERO_ROOT" = "`${workspaceFolder}"
        }
        "terminal.integrated.env.osx" = @{
            "AITHERZERO_ROOT" = "`${workspaceFolder}"
        }
        "powershell.startAutomatically" = $false
        "terminal.integrated.defaultProfile.windows" = "PowerShell"
        "terminal.integrated.profiles.windows" = @{
            "PowerShell" = @{
                "source" = "PowerShell"
                "args" = @("-NoExit", "-Command", "& { if (Test-Path ./AitherZero.psd1) { Import-Module ./AitherZero.psd1 -Force } }")
            }
        }
        "terminal.integrated.profiles.linux" = @{
            "PowerShell" = @{
                "path" = "pwsh"
                "args" = @("-NoExit", "-Command", "& { if (Test-Path ./AitherZero.psd1) { Import-Module ./AitherZero.psd1 -Force } }")
            }
        }
    }
    
    $settingsPath = Join-Path $vscodeDir "settings.json"
    $vscodeSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Force
    Write-BootstrapLog "Created VS Code integration settings" -Level Success
}

function Remove-AitherZero {
    $installPath = Get-DefaultInstallPath

    if (-not (Test-Path $installPath)) {
        Write-BootstrapLog "AitherZero not found at: $installPath" -Level Warning
        return
    }

    if (-not $NonInteractive) {
        $response = Read-Host "Remove AitherZero from $installPath? (y/N)"
        if ($response -ne 'y') {
            Write-BootstrapLog "Removal cancelled" -Level Warning
            return
        }
    }
    
    Write-BootstrapLog "Removing AitherZero..." -Level Info
    Remove-Item $installPath -Recurse -Force
    Write-BootstrapLog "AitherZero removed successfully" -Level Success
}

# Main execution
try {
    Clear-Host
    Write-BootstrapLog @"
    _    _ _   _               ______               
   / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___  
  / _ \ | | __| '_ \ / _ \ '__/ // _ \ '__/ _ \ 
 / ___ \| | |_| | | |  __/ | / /|  __/ | | (_) |
/_/   \_\_|\__|_| |_|\___|_|/____\___|_|  \___/ 
                                                 
        Infrastructure Automation Platform
"@ -Level Header

    Write-BootstrapLog "Bootstrap Mode: $Mode | Profile: $InstallProfile" -Level Info

    # Test dependencies
    Test-Dependencies

    # Execute based on mode
    switch ($Mode) {
        'Remove' {
            Remove-AitherZero
        }
        default {
            $installPath = Install-AitherZero

            # Initialize environment
            Write-BootstrapLog "Initializing AitherZero environment..." -Level Info
            Push-Location $installPath
            try {
                if (Test-Path "./AitherZero.psd1") {
                    Import-Module ./AitherZero.psd1 -Force -Global
                    $modules = Get-Module | Where-Object { $_.Path -like "*AitherZero*" }
                    if ($modules) {
                        Write-BootstrapLog "Environment initialized - $($modules.Count) modules loaded!" -Level Success
                    } else {
                        Write-BootstrapLog "Environment initialization completed with errors" -Level Warning
                    }
                } elseif (Test-Path "./Initialize-AitherEnvironment.ps1") {
                    # Fallback for backward compatibility
                    & ./Initialize-AitherEnvironment.ps1 -Force
                    Write-BootstrapLog "Environment initialized using legacy script" -Level Success
                }
            } catch {
                Write-BootstrapLog "Failed to initialize environment: $_" -Level Warning
            } finally {
                Pop-Location
            }

            if (-not $SkipAutoStart -and $installPath) {
                Write-BootstrapLog "Starting AitherZero..." -Level Info
                
                Push-Location $installPath
                try {
                    # Check if launcher exists
                    if (Test-Path "./Start-AitherZero.ps1") {
                        if ($NonInteractive) {
                            & ./Start-AitherZero.ps1 -NonInteractive
                        } else {
                            & ./Start-AitherZero.ps1 -Setup
                        }
                    } else {
                        Write-BootstrapLog "Launcher not found. Please run manually from: $installPath" -Level Warning
                    }
                } finally {
                    Pop-Location
                }
            } else {
                Write-Host "`n" -NoNewline
                Write-Host "=" * 60 -ForegroundColor Green
                Write-Host " Installation Complete! " -ForegroundColor Green
                Write-Host "=" * 60 -ForegroundColor Green
                
                Write-Host "`nAitherZero is ready to use!" -ForegroundColor Cyan
                Write-Host "The environment will auto-load when you:" -ForegroundColor Gray
                Write-Host "  • Open a new PowerShell terminal in this directory" -ForegroundColor White
                Write-Host "  • Use VS Code with the integrated terminal" -ForegroundColor White
                Write-Host "  • Run any az command" -ForegroundColor White
                
                Write-Host "`nAvailable commands:" -ForegroundColor Yellow
                Write-Host "  az <number>    " -NoNewline -ForegroundColor Cyan
                Write-Host "- Run automation script (e.g., az 0511)"
                Write-Host "  aither         " -NoNewline -ForegroundColor Cyan
                Write-Host "- Launch interactive UI"
                Write-Host "  seq <pattern>  " -NoNewline -ForegroundColor Cyan
                Write-Host "- Run orchestration sequence"
                
                if (-not (Test-IsWindows)) {
                    Write-Host "`nFor bash/zsh users:" -ForegroundColor Yellow
                    Write-Host "  source ./activate.sh  " -NoNewline -ForegroundColor Cyan
                    Write-Host "- Activate in current shell"
                }
                
                Write-Host "`nNext steps:" -ForegroundColor Magenta
                Write-Host "  cd $installPath" -ForegroundColor White
                Write-Host "  ./az 0511 -ShowAll    # View project dashboard" -ForegroundColor White
            }
        }
    }
    
} catch {
    Write-BootstrapLog "Bootstrap failed: $_" -Level Error
    exit 1
}