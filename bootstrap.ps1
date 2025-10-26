#!/usr/bin/env pwsh
# Supports PowerShell 5.1+ but will install PowerShell 7

<#
.SYNOPSIS
    AitherZero Bootstrap Script - One-liner installation and setup
.DESCRIPTION
    Cross-platform bootstrap script for AitherZero with automatic dependency resolution
.PARAMETER Mode
    Operation mode: Remove (uninstall) - otherwise auto-detects install vs initialize
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
    iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | iex

    # One-liner with options
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1))) -InstallProfile Developer -AutoInstallDeps
#>

[CmdletBinding()]
param(
    [ValidateSet('New', 'Update', 'Clean', 'Remove')]
    [string]$Mode = 'New',

    # NOTE: Removed ValidateSet here to allow graceful handling of blank / malformed values coming
    # from external bootstrap wrappers (an empty string was causing immediate validation failure
    # before we could apply defaults). We perform our own validation immediately after param binding.
    [string]$InstallProfile = 'Standard',  # Default for non-CI; CI logic below may override

    [string]$InstallPath,

    [string]$Branch = 'main',

    [switch]$NonInteractive = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'),

    [switch]$AutoInstallDeps,

    [switch]$SkipAutoStart,

    [switch]$IsRelaunch
)

# Detect CI early so normalization logic has accurate context
$script:IsCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true' -or $env:TF_BUILD -eq 'true')

# Robust profile normalization & validation (must run immediately after param binding & CI detection)
$validProfiles = @('Minimal','Standard','Developer','Full')
if ([string]::IsNullOrWhiteSpace($InstallProfile)) {
    $InstallProfile = if ($script:IsCI) { 'Full' } else { 'Standard' }
} elseif ($validProfiles -notcontains $InstallProfile) {
    Write-Host "[!] Provided InstallProfile '$InstallProfile' is not valid. Falling back to 'Standard'" -ForegroundColor Yellow
    $InstallProfile = 'Standard'
}

# (Already detected above) Auto-adjust if CI and user did not explicitly pass InstallProfile
if ($script:IsCI -and -not $PSBoundParameters.ContainsKey('InstallProfile')) {
    $InstallProfile = 'Full'  # CI always uses Full profile if not explicitly set (even if blank passed we normalized above)
}

# Script configuration
$script:RepoOwner = "wizzense"
$script:RepoName = "AitherZero"
$script:GitHubUrl = "https://github.com/$script:RepoOwner/$script:RepoName"
$script:RawContentUrl = "https://raw.githubusercontent.com/$script:RepoOwner/$script:RepoName"

# Enable TLS 1.2 for older systems
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Set error action preference
$ErrorActionPreference = 'Stop'

# CRITICAL: Clean environment BEFORE anything else
# Remove ALL conflicting modules and systems
$conflictingModules = @(
    'CoreApp', 'AitherRun', 'ConfigurationManager', 'SecurityAutomation',
    'UtilityServices', 'ConfigurationCore', 'ConfigurationCarousel',
    'ModuleCommunication', 'ConfigurationRepository', 'StartupExperience'
)

foreach ($module in $conflictingModules) {
    Remove-Module $module -Force -ErrorAction SilentlyContinue 2>$null
}

# Clean PSModulePath of any conflicting paths
if ($env:PSModulePath) {
    $cleanPaths = $env:PSModulePath -split [IO.Path]::PathSeparator |
        Where-Object {
            $_ -notlike "*aither-core*" -and
            $_ -notlike "*Aitherium*" -and
            $_ -notlike "*AitherRun*"
        }
    $env:PSModulePath = $cleanPaths -join [IO.Path]::PathSeparator
}

# Remove conflicting environment variables
@('AITHERIUM_ROOT', 'AITHERRUN_ROOT', 'COREAPP_ROOT', 'AITHER_CORE_PATH') | ForEach-Object {
    Remove-Item "env:$_" -ErrorAction SilentlyContinue 2>$null
}

# Block any auto-loading scripts
$env:AITHERZERO_BOOTSTRAP_RUNNING = "1"

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
    # PowerShell 5.1 assumes Windows
    return $true
}

function Test-IsLinux {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $IsLinux
    }
    # PowerShell 5.1 only runs on Windows
    return $false
}

function Test-IsMacOS {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $IsMacOS
    }
    # PowerShell 5.1 only runs on Windows
    return $false
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

function Get-TempDirectory {
    if ($env:TEMP) {
        return $env:TEMP
    } elseif ($env:TMPDIR) {
        return $env:TMPDIR
    } else {
        return '/tmp'
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
    Write-BootstrapLog "Checking system dependencies..." -Level Info

    $missing = @()
    $found = @()

    # Check Git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $gitVersion = & git --version 2>$null
            Write-BootstrapLog "Git found: $gitVersion" -Level Success
            $found += 'Git'
        } catch {
            Write-BootstrapLog "Git command exists but failed to get version" -Level Warning
            $missing += 'Git'
        }
    } else {
        Write-BootstrapLog "Git not found in PATH" -Level Warning
        $missing += 'Git'
    }

    # Check PowerShell version - we NEED PowerShell 7
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $missing += 'PowerShell7'
        Write-BootstrapLog "PowerShell 7 is required. Current version: $($PSVersionTable.PSVersion)" -Level Warning
        Write-BootstrapLog "AitherZero requires PowerShell 7+ for cross-platform compatibility and modern features" -Level Info
    } else {
        Write-BootstrapLog "PowerShell 7+ detected: $($PSVersionTable.PSVersion)" -Level Success
        $found += 'PowerShell7'
    }

    # Additional system checks
    if (Test-IsWindows) {
        Write-BootstrapLog "Platform: Windows" -Level Info
    } elseif (Test-IsMacOS) {
        Write-BootstrapLog "Platform: macOS" -Level Info
    } else {
        Write-BootstrapLog "Platform: Linux/Unix" -Level Info
    }

    # Report findings
    if ($found.Count -gt 0) {
        Write-BootstrapLog "Dependencies satisfied: $($found -join ', ')" -Level Success
    }

    if ($missing.Count -gt 0) {
        Write-BootstrapLog "Missing dependencies: $($missing -join ', ')" -Level Warning

        # Determine installation strategy
        $shouldInstall = $false
        $reason = ""

        if ($AutoInstallDeps) {
            $shouldInstall = $true
            $reason = "AutoInstallDeps flag is set"
        } elseif ($missing -contains 'PowerShell7') {
            $shouldInstall = $true
            $reason = "PowerShell 7 is required and will be auto-installed"
        } elseif ($script:IsCI) {
            $shouldInstall = $true
            $reason = "CI environment detected"
        }

        if ($shouldInstall) {
            Write-BootstrapLog "Will attempt to install missing dependencies ($reason)" -Level Info
            Install-Dependencies -Missing $missing
        } else {
            Write-BootstrapLog "Automatic dependency installation not enabled" -Level Warning
            Write-BootstrapLog "To enable automatic installation, use: bootstrap.ps1 -AutoInstallDeps" -Level Info
            Write-BootstrapLog "Manual installation options:" -Level Info

            foreach ($dep in $missing) {
                switch ($dep) {
                    'Git' {
                        Write-BootstrapLog "  Git: https://git-scm.com/downloads" -Level Info
                    }
                    'PowerShell7' {
                        Write-BootstrapLog "  PowerShell 7: https://github.com/PowerShell/PowerShell#get-powershell" -Level Info
                    }
                }
            }

            throw "Missing dependencies: $($missing -join ', '). Use -AutoInstallDeps to install automatically."
        }
    } else {
        Write-BootstrapLog "All required dependencies are available!" -Level Success
    }
}

function Install-Dependencies {
    param([string[]]$Missing)

    Write-BootstrapLog "Installing missing dependencies: $($Missing -join ', ')" -Level Info

    # Install Git if needed
    if ($Missing -contains 'Git') {
        Install-Git
    }

    # Install PowerShell 7 first if needed
    if ($Missing -contains 'PowerShell7') {
        Install-PowerShell7

        # Don't re-launch if we're already in a relaunch to avoid infinite loops
        if ($IsRelaunch) {
            Write-BootstrapLog "PowerShell 7 installed, continuing in current session..." -Level Info
            return
        }

        # Re-launch in PowerShell 7
        Write-BootstrapLog "Re-launching bootstrap in PowerShell 7..." -Level Info

        # Find PowerShell 7 executable
        $pwsh = $null
        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            $pwsh = "pwsh"
        } elseif (Test-IsWindows) {
            # Try common Windows paths
            $pwshPaths = @(
                "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe"
            )
            foreach ($path in $pwshPaths) {
                if (Test-Path $path) {
                    $pwsh = $path
                    break
                }
            }
        }

        if (-not $pwsh) {
            throw "PowerShell 7 was installed but pwsh command not found in PATH"
        }

        # Get the current script path
        $scriptPath = $null
        if ($MyInvocation.PSCommandPath) {
            $scriptPath = $MyInvocation.PSCommandPath
        } elseif ($PSCommandPath) {
            $scriptPath = $PSCommandPath
        } elseif ($MyInvocation.MyCommand.Path) {
            $scriptPath = $MyInvocation.MyCommand.Path
        } else {
            # When executed via iwr | iex, there's no physical file
            # Download the script to temp and execute from there
            Write-BootstrapLog "Script executed via one-liner, downloading to temp file..." -Level Info
            $tempScript = Join-Path (Get-TempDirectory) "aitherzero-bootstrap-$(Get-Random).ps1"
            try {
                Invoke-WebRequest -Uri "$script:RawContentUrl/$Branch/bootstrap.ps1" -OutFile $tempScript -UseBasicParsing
                $scriptPath = $tempScript
            } catch {
                Write-BootstrapLog "Failed to download script: $_" -Level Error
                # Fallback - assume bootstrap.ps1 in current directory
                $scriptPath = Join-Path (Get-Location) "bootstrap.ps1"
            }
        }

        # Build arguments to preserve all parameters
        $argumentList = @()
        $argumentList += "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $scriptPath

        # Preserve all bound parameters and add IsRelaunch flag
        foreach ($param in $PSBoundParameters.GetEnumerator()) {
            if ($param.Value -is [switch]) {
                if ($param.Value) {
                    $argumentList += "-$($param.Key)"
                }
            } elseif ($param.Value -is [array]) {
                # Handle array parameters properly
                $argumentList += "-$($param.Key)"
                $argumentList += ($param.Value -join ',')
            } else {
                $argumentList += "-$($param.Key)", $param.Value
            }
        }
        # Add relaunch flag to prevent infinite loops
        $argumentList += "-IsRelaunch"

        Write-BootstrapLog "Executing: $pwsh $($argumentList -join ' ')" -Level Info

        try {
            & $pwsh @argumentList
            $exitCode = $LASTEXITCODE
        } finally {
            # Clean up temporary script if we created one
            $tempDir = Get-TempDirectory
            if ($scriptPath -and $scriptPath.StartsWith($tempDir, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path $scriptPath)) {
                Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
            }
        }
        exit $exitCode
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
                } elseif (Test-IsMacOS) {
                    if (Get-Command brew -ErrorAction SilentlyContinue) {
                        brew install git
                    } else {
                        throw "Please install Homebrew first: /bin/bash -c `"`$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)`""
                    }
                } else {
                    # Linux
                    if (Get-Command apt -ErrorAction SilentlyContinue) {
                        sudo apt update
                        sudo apt install -y git
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

function Install-Git {
    Write-BootstrapLog "Installing Git..." -Level Info

    # Check if Git is already available
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-BootstrapLog "Git is already installed" -Level Success
        return
    }

    try {
        if (Test-IsWindows) {
            # Windows Git installation
            Write-BootstrapLog "Installing Git for Windows..." -Level Info

            # Try winget first (modern Windows package manager)
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-BootstrapLog "Attempting Git installation via winget..." -Level Info
                & winget install --id Git.Git --source winget --accept-source-agreements --accept-package-agreements --silent
                if ($LASTEXITCODE -eq 0) {
                    Write-BootstrapLog "Git installed successfully via winget" -Level Success

                    # Refresh PATH on Windows
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                    if (Get-Command git -ErrorAction SilentlyContinue) {
                        return
                    }
                } else {
                    Write-BootstrapLog "Winget installation failed, trying alternative method..." -Level Warning
                }
            }

            # Try Chocolatey if available
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-BootstrapLog "Attempting Git installation via Chocolatey..." -Level Info
                & choco install git -y
                if ($LASTEXITCODE -eq 0) {
                    Write-BootstrapLog "Git installed successfully via Chocolatey" -Level Success

                    # Refresh PATH
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

                    if (Get-Command git -ErrorAction SilentlyContinue) {
                        return
                    }
                }
            }

            # Fallback: Download and install Git MSI
            Write-BootstrapLog "Downloading Git for Windows installer..." -Level Info
            $gitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.42.0.2-64-bit.exe"
            $gitInstaller = "$env:TEMP\Git-installer.exe"

            Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller -UseBasicParsing -ErrorAction Stop

            Write-BootstrapLog "Running Git installer..." -Level Info
            if (Test-IsAdmin) {
                Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT" -Wait
            } else {
                Start-Process -FilePath $gitInstaller -ArgumentList "/SILENT" -Verb RunAs -Wait
            }

            Remove-Item $gitInstaller -Force -ErrorAction SilentlyContinue

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        } elseif (Test-IsMacOS) {
            # macOS Git installation
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                Write-BootstrapLog "Installing Git via Homebrew..." -Level Info
                & brew install git
            } elseif (Get-Command port -ErrorAction SilentlyContinue) {
                Write-BootstrapLog "Installing Git via MacPorts..." -Level Info
                & sudo port install git
            } else {
                Write-BootstrapLog "Installing Xcode Command Line Tools (includes Git)..." -Level Info
                & xcode-select --install
                Write-BootstrapLog "Xcode Command Line Tools installation initiated. Please complete it and re-run this script." -Level Warning
                return
            }

        } else {
            # Linux/Unix Git installation
            Write-BootstrapLog "Installing Git for Linux..." -Level Info

            # Detect distribution and use appropriate package manager
            if (Test-Path "/etc/os-release") {
                $osRelease = Get-Content "/etc/os-release" | ConvertFrom-StringData -Delimiter "="
                $distroId = $osRelease.ID.Trim('"')

                switch -Regex ($distroId) {
                    "ubuntu|debian" {
                        & sudo apt-get update
                        & sudo apt-get install -y git
                    }
                    "rhel|centos|rocky|almalinux|fedora" {
                        if (Get-Command dnf -ErrorAction SilentlyContinue) {
                            & sudo dnf install -y git
                        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                            & sudo yum install -y git
                        }
                    }
                    "opensuse|sles" {
                        & sudo zypper install -y git
                    }
                    "arch|manjaro" {
                        & sudo pacman -Sy --noconfirm git
                    }
                    "alpine" {
                        & sudo apk add git
                    }
                    default {
                        Write-BootstrapLog "Unknown Linux distribution: $distroId. Please install Git manually." -Level Warning
                        throw "Unsupported Linux distribution for automatic Git installation"
                    }
                }
            } else {
                Write-BootstrapLog "Cannot determine Linux distribution. Please install Git manually." -Level Warning
                throw "Cannot determine Linux distribution for Git installation"
            }
        }

        # Verify Git installation
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $gitVersion = & git --version
            Write-BootstrapLog "Git installed successfully: $gitVersion" -Level Success
        } else {
            throw "Git installation completed but git command not found in PATH"
        }

    } catch {
        Write-BootstrapLog "Failed to install Git: $_" -Level Error
        Write-BootstrapLog "Please install Git manually from https://git-scm.com/downloads" -Level Info
        throw "Git installation failed"
    }
}

function Install-PowerShell7 {
    Write-BootstrapLog "Installing PowerShell 7..." -Level Info

    # First check if it's already available but not detected
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Write-BootstrapLog "PowerShell 7 already available as 'pwsh'" -Level Success
        return
    }

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

    } elseif (Test-IsMacOS) {
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
        # Linux or other Unix-like systems
        Write-BootstrapLog "Installing PowerShell 7 for Unix..." -Level Info

        try {
            # Download and run Microsoft's install script
            $installScript = if ($env:HOME) { "$env:HOME/install-powershell.sh" } else { "/tmp/install-powershell.sh" }
            Write-BootstrapLog "Downloading PowerShell install script to: $installScript" -Level Info

            Invoke-WebRequest -Uri "https://aka.ms/install-powershell.sh" -OutFile $installScript -UseBasicParsing
            & chmod "+x" $installScript

            Write-BootstrapLog "Running PowerShell install script..." -Level Info
            & sudo $installScript

            Remove-Item $installScript -Force -ErrorAction SilentlyContinue
        } catch {
            Write-BootstrapLog "Microsoft install script failed: $_" -Level Warning
            Write-BootstrapLog "Please install PowerShell 7 manually and re-run bootstrap" -Level Error
            throw
        }
    }

    # Verify installation - refresh PATH first
    if (Test-IsWindows) {
        # Refresh environment variables on Windows
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    # Check common locations and PATH
    $pwshFound = $false
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        $pwshFound = $true
    } elseif (Test-IsWindows) {
        # Check common Windows installation paths
        $commonPaths = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe"
        )
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                $pwshFound = $true
                break
            }
        }
    }

    if (-not $pwshFound) {
        throw "PowerShell 7 installation completed but pwsh not found. Please add PowerShell 7 to PATH and re-run."
    }

    Write-BootstrapLog "PowerShell 7 installed and verified successfully!" -Level Success
}

function Install-AitherZero {
    # Check if we're already in an AitherZero project
    $currentPath = Get-Location
    $isAitherProject = (Test-Path "./Start-AitherZero.ps1") -or
                       (Test-Path "./domains") -or
                       (Test-Path "./automation-scripts")

    # If script resides inside an existing project but user executed from parent directory,
    # prefer the script's directory as the install/initialize target. This prevents creating
    # a sibling empty AitherZero folder that lacks the manifest.
    $scriptRootPath = $null
    try {
        if ($MyInvocation -and $MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
            $scriptRootPath = Split-Path -Parent $MyInvocation.MyCommand.Path
        } elseif ($PSCommandPath) {
            $scriptRootPath = Split-Path -Parent $PSCommandPath
        }
    } catch { $scriptRootPath = $null }
    if (-not $scriptRootPath -or -not (Test-Path $scriptRootPath)) {
        # Fallback: relative path of bootstrap file name within current directory
        $candidate = Join-Path (Get-Location) 'aitherzero/AitherZero'
        if (Test-Path (Join-Path $candidate 'AitherZero.psd1')) { $scriptRootPath = $candidate }
    }
    if ($scriptRootPath -and -not $isAitherProject -and (Test-Path (Join-Path $scriptRootPath 'AitherZero.psd1'))) {
        Write-BootstrapLog "Detected existing project at script location: $scriptRootPath" -Level Info
        Push-Location $scriptRootPath
        try {
            Initialize-Configuration
            Setup-DevelopmentEnvironment
            return $scriptRootPath
        } finally { Pop-Location }
    }

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

    # Clone repository only if target directory itself is not already a git repo
    $targetGitDir = Join-Path $installPath '.git'
    if ($script:GitHubUrl -and -not (Test-Path $targetGitDir)) {
        Write-BootstrapLog "Cloning AitherZero repository..." -Level Info
        Push-Location $installPath
        try {
            if (Test-Path '.git') {
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
        if (-not (Test-Path (Join-Path $installPath 'AitherZero.psd1'))) {
            Write-BootstrapLog "Skipping clone: target path appears inside another git repo (parent .git detected). If you intended a fresh clone, run from a clean directory or specify -InstallPath." -Level Warning
        } else {
            Write-BootstrapLog "Repository already present - skipping clone" -Level Info
        }
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
    $configPath = "config.psd1"
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
    $ProfileNameContent = @'
# AitherZero Auto-Load
if ($PWD.Path -like "*AitherZero*") {
    $azPsd1 = Get-ChildItem -Path $PWD.Path -Filter "AitherZero.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($azPsd1 -and -not $env:AITHERZERO_INITIALIZED) {
        Import-Module $azPsd1.FullName -Force -Global
        Write-Host "✓ AitherZero environment loaded" -ForegroundColor Green
    }
}
'@

    $ProfileNames = @(
        $ProfileName.CurrentUserAllHosts,
        $ProfileName.CurrentUserCurrentHost
    )

    foreach ($ProfileNamePath in $ProfileNames) {
        if ($ProfileNamePath -and $ProfileNamePath -ne '') {
            $ProfileNameDir = Split-Path $ProfileNamePath -Parent -ErrorAction SilentlyContinue
            if ($ProfileNameDir -and -not (Test-Path $ProfileNameDir)) {
                New-Item -ItemType Directory -Path $ProfileNameDir -Force | Out-Null
            }

            if ($ProfileNamePath -and (Test-Path $ProfileNamePath)) {
                $currentContent = Get-Content $ProfileNamePath -Raw
                if ($currentContent -notlike "*AitherZero Auto-Load*") {
                    Add-Content -Path $ProfileNamePath -Value "`n$ProfileNameContent"
                    Write-BootstrapLog "Updated PowerShell profile: $ProfileNamePath" -Level Success
                }
            } elseif ($ProfileNamePath) {
                Set-Content -Path $ProfileNamePath -Value $ProfileNameContent
                Write-BootstrapLog "Created PowerShell profile: $ProfileNamePath" -Level Success
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
& "$root/az.ps1" $arguments
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

function Initialize-CleanEnvironment {
    Write-BootstrapLog "Cleaning PowerShell environment..." -Level Info

    # Extended list of conflicting modules to remove (legacy modules that might interfere)
    $conflictingModules = @(
        'AitherRun', 'CoreApp', 'ConfigurationManager', 'SecurityAutomation',
        'UtilityServices', 'ConfigurationCore', 'ConfigurationCarousel',
        'ModuleCommunication', 'ConfigurationRepository', 'StartupExperience',
        'OpenTofuProvider', 'PSScriptAnalyzerIntegration',
        'SemanticVersioning', 'LicenseManager'
    )

    # Remove conflicting modules
    foreach ($module in $conflictingModules) {
        if (Get-Module -Name $module -ErrorAction SilentlyContinue) {
            Write-BootstrapLog "Removing conflicting module: $module" -Level Info
            Remove-Module -Name $module -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean PSModulePath of any conflicting references
    if ($env:PSModulePath) {
        $cleanPaths = $env:PSModulePath -split [IO.Path]::PathSeparator |
            Where-Object {
                $_ -notlike "*Aitherium*" -and
                $_ -notlike "*AitherRun*" -and
                $_ -notlike "*aither-core*" -and
                $_ -notlike "*CoreApp*"
            }
        $env:PSModulePath = $cleanPaths -join [IO.Path]::PathSeparator
    }

    # Clean PATH variable
    if ($env:PATH) {
        $cleanPaths = $env:PATH -split [IO.Path]::PathSeparator |
            Where-Object {
                $_ -notlike "*aither-core*" -and
                $_ -notlike "*Aitherium*"
            }
        $env:PATH = $cleanPaths -join [IO.Path]::PathSeparator
    }

    # Set AitherZero root - use the directory containing AitherZero.psd1
    $currentPath = Get-Location
    if (Test-Path "./AitherZero.psd1") {
        $script:ProjectRoot = $currentPath.Path
    } elseif ($env:AITHERZERO_ROOT -and (Test-Path "$env:AITHERZERO_ROOT/AitherZero.psd1")) {
        $script:ProjectRoot = $env:AITHERZERO_ROOT
    } else {
        # Try to find AitherZero.psd1 in parent directories
        $testPath = $currentPath
        while ($testPath -and $testPath.Path -ne $testPath.Drive.Root) {
            if (Test-Path (Join-Path $testPath "AitherZero.psd1")) {
                $script:ProjectRoot = $testPath.Path
                break
            }
            $testPath = Split-Path $testPath -Parent
        }
        if (-not $script:ProjectRoot) {
            $script:ProjectRoot = $currentPath.Path
        }
    }
    $env:AITHERZERO_ROOT = $script:ProjectRoot

    # Clean any lingering environment variables
    @('AITHERIUM_ROOT', 'AITHERRUN_ROOT', 'COREAPP_ROOT', 'AITHER_CORE_PATH', 'PWSH_MODULES_PATH') | ForEach-Object {
        Remove-Item "env:$_" -ErrorAction SilentlyContinue
    }

    # Set flags to prevent auto-loading of conflicting systems
    $env:DISABLE_COREAPP = "1"
    $env:SKIP_AUTO_MODULES = "1"
    $env:AITHERZERO_ONLY = "1"

    Write-BootstrapLog "Environment cleaned" -Level Success

    # Now load AitherZero modules
    Write-BootstrapLog "Loading AitherZero modules..." -Level Info

    # Check if already initialized (idempotency)
    if ($env:AITHERZERO_INITIALIZED -eq "1" -and (Get-Module AitherZero -ErrorAction SilentlyContinue)) {
        Write-BootstrapLog "AitherZero already initialized" -Level Info
        return
    }

    try {
        # Import the module manifest - use the resolved project root
        $manifestPath = Join-Path $script:ProjectRoot "AitherZero.psd1"
        if (Test-Path $manifestPath) {
            Write-BootstrapLog "Loading module from: $manifestPath" -Level Info
            Import-Module $manifestPath -Force -Global

            # Verify critical functions
            $criticalFunctions = @(
                'Write-CustomLog',
                'Show-UIMenu',
                'Invoke-OrchestrationSequence'
            )

            $missingFunctions = @()
            foreach ($func in $criticalFunctions) {
                if (-not (Get-Command $func -ErrorAction SilentlyContinue)) {
                    $missingFunctions += $func
                }
            }

            if ($missingFunctions.Count -gt 0) {
                Write-BootstrapLog "Warning: Some functions are missing: $($missingFunctions -join ', ')" -Level Warning
            } else {
                Write-BootstrapLog "All critical functions loaded" -Level Success
            }

            # Set aliases
            Set-Alias -Name 'az' -Value (Join-Path $script:ProjectRoot 'az.ps1') -Scope Global -Force
            Set-Alias -Name 'seq' -Value 'Invoke-OrchestrationSequence' -Scope Global -Force

            # Show loaded modules count
            $loadedModules = Get-Module | Where-Object { $_.Path -like "*$script:ProjectRoot*" }
            Write-BootstrapLog "Environment initialized - $($loadedModules.Count) modules loaded!" -Level Success

        } else {
            Write-BootstrapLog "AitherZero.psd1 not found" -Level Error
            throw "Module manifest not found"
        }
    } catch {
        Write-BootstrapLog "Failed to load AitherZero modules: $_" -Level Error
        throw
    }
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
    # Only clear host in interactive sessions
    if (-not $NonInteractive -and -not $env:CI -and $host.UI.RawUI) {
        try { Clear-Host } catch { }
    }
    Write-BootstrapLog @"
    _    _ _   _               ______
   / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___
  / _ \ | | __| '_ \ / _ \ '__/ // _ \ '__/ _ \
 / ___ \| | |_| | | |  __/ | / /|  __/ | | (_) |
/_/   \_\_|\__|_| |_|\___|_|/____\___|_|  \___/

        Infrastructure Automation Platform
"@ -Level Header

    # Intelligent detection of what needs to be done
    $currentPath = Get-Location
    $isInAitherProject = (Test-Path "./Start-AitherZero.ps1") -and
                         (Test-Path "./domains") -and
                         (Test-Path "./AitherZero.psd1")

    # Check if modules are already loaded
    $modulesLoaded = $env:AITHERZERO_INITIALIZED -eq "1" -or
                     (Get-Module AitherZero -ErrorAction SilentlyContinue)

    # Determine what to do
    if ($Mode -eq 'Remove') {
        Write-BootstrapLog "Mode: Remove" -Level Info
        Remove-AitherZero
    } elseif ($isInAitherProject) {
        # We're already in an AitherZero project
        Write-BootstrapLog "Detected existing AitherZero project" -Level Info

        if ($modulesLoaded) {
            Write-BootstrapLog "Environment already initialized - refreshing..." -Level Info
        }

        # Just initialize/refresh the environment
        Initialize-CleanEnvironment

        $installPath = $currentPath.Path
    } else {
        # Not in a project, need to install/clone
        Write-BootstrapLog "Installing AitherZero..." -Level Info

        # Test dependencies
        Test-Dependencies

        # Install AitherZero
        $installPath = Install-AitherZero

        # Initialize environment in the new installation
        Write-BootstrapLog "Initializing AitherZero environment..." -Level Info
        Push-Location $installPath
        try {
            Initialize-CleanEnvironment
        } catch {
            Write-BootstrapLog "Failed to initialize environment: $_" -Level Warning
        } finally {
            Pop-Location
        }
    }

    # Handle auto-start if requested (for both scenarios)
    if (-not $SkipAutoStart -and $installPath -and $Mode -ne 'Remove') {
        Write-BootstrapLog "Starting AitherZero..." -Level Info

        Push-Location $installPath
        try {
            # Check if launcher exists
            if (Test-Path "./Start-AitherZero.ps1") {
                # Set environment to block conflicting systems
                $env:DISABLE_COREAPP = "1"
                $env:SKIP_AUTO_MODULES = "1"
                $env:AITHERZERO_ONLY = "1"

                if ($NonInteractive) {
                    # Don't pass -NonInteractive explicitly - let Start-AitherZero.ps1 auto-detect CI environment
                    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -Command "& { `$env:DISABLE_COREAPP='1'; `$env:SKIP_AUTO_MODULES='1'; Remove-Module CoreApp,AitherRun,StartupExperience -Force -ErrorAction SilentlyContinue; & ./Start-AitherZero.ps1 }"
                } else {
                    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -Command "& { `$env:DISABLE_COREAPP='1'; `$env:SKIP_AUTO_MODULES='1'; Remove-Module CoreApp,AitherRun,StartupExperience -Force -ErrorAction SilentlyContinue; & ./Start-AitherZero.ps1 }"
                }
            } else {
                Write-BootstrapLog "Launcher not found. Please run manually from: $installPath" -Level Warning
            }
        } finally {
            Pop-Location
        }
    } else {
        if ($Mode -ne 'Remove') {
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

} catch {
    Write-BootstrapLog "Bootstrap failed: $_" -Level Error
    exit 1
}
