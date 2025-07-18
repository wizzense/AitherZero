#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Universal bootstrap script for AitherZero - Installs from bare OS to fully functional system
    
.DESCRIPTION
    This script handles the complete installation of AitherZero on any supported platform
    (Windows, Linux, macOS) from a fresh OS installation. It detects the platform,
    installs prerequisites, and sets up the complete development environment.
    
.PARAMETER Profile
    Installation profile: Minimal, Developer, or Full (default: Developer)
    
.PARAMETER SkipPrerequisites
    Skip prerequisite installation (assumes they're already installed)
    
.PARAMETER Offline
    Use offline installation mode (requires offline package)
    
.PARAMETER Verbose
    Enable verbose output
    
.EXAMPLE
    ./bootstrap.ps1
    # Standard installation with developer profile
    
.EXAMPLE
    ./bootstrap.ps1 -Profile Full -Verbose
    # Full installation with verbose output
    
.EXAMPLE
    curl -sL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 | pwsh -
    # Remote installation
    
.NOTES
    Version: 1.0.0
    This is the primary entry point for AitherZero installation
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Minimal', 'Developer', 'Full')]
    [string]$Profile = 'Developer',
    
    [Parameter()]
    [switch]$SkipPrerequisites,
    
    [Parameter()]
    [switch]$Offline,
    
    [Parameter()]
    [string]$InstallPath = $null,
    
    [Parameter()]
    [switch]$Force
)

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Global variables
$script:BootstrapVersion = '1.0.0'
$script:MinPowerShellVersion = '7.0.0'
$script:ProjectName = 'AitherZero'
$script:GitHubOrg = 'wizzense'
$script:GitHubRepo = 'AitherZero'
$script:SupportedPlatforms = @('Windows', 'Linux', 'macOS')

# Color configuration for better visibility
$script:Colors = @{
    Success = 'Green'
    Info = 'Cyan'
    Warning = 'Yellow'
    Error = 'Red'
    Header = 'Magenta'
}

#region Helper Functions

function Write-BootstrapLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Header')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = $script:Colors[$Level]
    
    switch ($Level) {
        'Header' { 
            Write-Host ""
            Write-Host ("=" * 60) -ForegroundColor $color
            Write-Host $Message -ForegroundColor $color
            Write-Host ("=" * 60) -ForegroundColor $color
        }
        'Error' {
            Write-Host "[$timestamp] ERROR: $Message" -ForegroundColor $color
        }
        'Warning' {
            Write-Host "[$timestamp] WARN: $Message" -ForegroundColor $color
        }
        'Success' {
            Write-Host "[$timestamp] SUCCESS: $Message" -ForegroundColor $color
        }
        default {
            Write-Host "[$timestamp] INFO: $Message" -ForegroundColor $color
        }
    }
}

function Test-Administrator {
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } else {
        # On Unix, check if running as root or with sudo
        return ($(id -u) -eq 0)
    }
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
    
    if ($IsWindows) {
        $info.Platform = 'Windows'
        $info.Version = [System.Environment]::OSVersion.Version.ToString()
        $info.Architecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
        
        # Check if running in WSL
        if (Test-Path '/proc/version') {
            $procVersion = Get-Content '/proc/version' -Raw
            if ($procVersion -match 'microsoft|wsl') {
                $info.IsWSL = $true
                $info.Platform = 'Linux'
                $info.Distribution = 'WSL'
            }
        }
    } elseif ($IsLinux) {
        $info.Platform = 'Linux'
        
        # Get distribution info
        if (Test-Path '/etc/os-release') {
            $osRelease = Get-Content '/etc/os-release' | ConvertFrom-StringData
            $info.Distribution = $osRelease.ID
            $info.Version = $osRelease.VERSION_ID
        }
        
        $info.Architecture = (uname -m)
    } elseif ($IsMacOS) {
        $info.Platform = 'macOS'
        $info.Version = (sw_vers -productVersion)
        $info.Architecture = (uname -m)
    } else {
        throw "Unsupported platform detected"
    }
    
    return $info
}

function Install-PowerShell7 {
    param([hashtable]$PlatformInfo)
    
    Write-BootstrapLog "Installing PowerShell 7..." -Level Info
    
    switch ($PlatformInfo.Platform) {
        'Windows' {
            if (-not $PlatformInfo.IsWSL) {
                # Download and install PowerShell MSI
                $url = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
                $installer = Join-Path $env:TEMP "PowerShell-7.msi"
                
                Write-BootstrapLog "Downloading PowerShell 7..." -Level Info
                Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
                
                Write-BootstrapLog "Installing PowerShell 7..." -Level Info
                Start-Process msiexec.exe -ArgumentList "/i", $installer, "/quiet", "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1", "ENABLE_PSREMOTING=1" -Wait
                
                Remove-Item $installer -Force
            }
        }
        'Linux' {
            switch ($PlatformInfo.Distribution) {
                { $_ -in 'ubuntu', 'debian' } {
                    # Install PowerShell via package manager
                    $commands = @(
                        "wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb",
                        "sudo dpkg -i packages-microsoft-prod.deb",
                        "sudo apt-get update",
                        "sudo apt-get install -y powershell",
                        "rm packages-microsoft-prod.deb"
                    )
                    
                    foreach ($cmd in $commands) {
                        Write-BootstrapLog "Running: $cmd" -Level Info
                        Invoke-Expression $cmd
                    }
                }
                { $_ -in 'rhel', 'centos', 'fedora' } {
                    $commands = @(
                        "curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo",
                        "sudo yum install -y powershell"
                    )
                    
                    foreach ($cmd in $commands) {
                        Write-BootstrapLog "Running: $cmd" -Level Info
                        Invoke-Expression $cmd
                    }
                }
                default {
                    Write-BootstrapLog "Please install PowerShell 7 manually from: https://aka.ms/powershell" -Level Warning
                    throw "Automated installation not available for $($PlatformInfo.Distribution)"
                }
            }
        }
        'macOS' {
            if (Test-Command 'brew') {
                Write-BootstrapLog "Installing PowerShell via Homebrew..." -Level Info
                & brew install --cask powershell
            } else {
                Write-BootstrapLog "Installing Homebrew first..." -Level Info
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                & brew install --cask powershell
            }
        }
    }
    
    Write-BootstrapLog "PowerShell 7 installation completed" -Level Success
}

function Install-Prerequisites {
    param([hashtable]$PlatformInfo)
    
    Write-BootstrapLog "Installing prerequisites for $($PlatformInfo.Platform)..." -Level Info
    
    $prerequisites = @{
        'Windows' = @{
            Commands = @('git', 'code')
            Installer = {
                # Install Chocolatey if not present
                if (-not (Test-Command 'choco')) {
                    Write-BootstrapLog "Installing Chocolatey..." -Level Info
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
                }
                
                # Install prerequisites via Chocolatey
                $packages = @('git', 'vscode', 'nodejs')
                foreach ($package in $packages) {
                    Write-BootstrapLog "Installing $package..." -Level Info
                    choco install $package -y --no-progress
                }
                
                # Enable WSL if on Windows
                if (-not $PlatformInfo.IsWSL) {
                    Write-BootstrapLog "Enabling WSL 2..." -Level Info
                    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
                    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
                }
            }
        }
        'Linux' = @{
            Commands = @('git', 'curl', 'wget')
            Installer = {
                $packages = @('git', 'curl', 'wget', 'build-essential', 'nodejs', 'npm')
                
                switch ($PlatformInfo.Distribution) {
                    { $_ -in 'ubuntu', 'debian' } {
                        Write-BootstrapLog "Updating package lists..." -Level Info
                        sudo apt-get update
                        
                        Write-BootstrapLog "Installing packages..." -Level Info
                        sudo apt-get install -y $packages
                    }
                    { $_ -in 'rhel', 'centos', 'fedora' } {
                        Write-BootstrapLog "Installing packages..." -Level Info
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
                    Write-BootstrapLog "Installing Homebrew..." -Level Info
                    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                }
                
                # Install prerequisites
                $packages = @('git', 'node', 'visual-studio-code')
                foreach ($package in $packages) {
                    Write-BootstrapLog "Installing $package..." -Level Info
                    brew install $package
                }
            }
        }
    }
    
    # Check and install prerequisites
    $prereq = $prerequisites[$PlatformInfo.Platform]
    $missingCommands = @()
    
    foreach ($cmd in $prereq.Commands) {
        if (-not (Test-Command $cmd)) {
            $missingCommands += $cmd
        }
    }
    
    if ($missingCommands.Count -gt 0) {
        Write-BootstrapLog "Missing prerequisites: $($missingCommands -join ', ')" -Level Warning
        
        if ($prereq.Installer) {
            & $prereq.Installer
        }
    } else {
        Write-BootstrapLog "All prerequisites are already installed" -Level Success
    }
}

function Get-AitherZero {
    param(
        [string]$InstallPath,
        [hashtable]$PlatformInfo
    )
    
    Write-BootstrapLog "Downloading AitherZero..." -Level Info
    
    # Determine installation path
    if (-not $InstallPath) {
        if ($PlatformInfo.Platform -eq 'Windows' -and -not $PlatformInfo.IsWSL) {
            $InstallPath = Join-Path $env:USERPROFILE 'AitherZero'
        } else {
            $InstallPath = Join-Path $HOME 'AitherZero'
        }
    }
    
    # Check if already exists
    if (Test-Path $InstallPath) {
        if ($Force) {
            Write-BootstrapLog "Removing existing installation..." -Level Warning
            Remove-Item -Path $InstallPath -Recurse -Force
        } else {
            Write-BootstrapLog "AitherZero already exists at $InstallPath" -Level Warning
            $response = Read-Host "Remove and reinstall? (y/N)"
            if ($response -eq 'y') {
                Remove-Item -Path $InstallPath -Recurse -Force
            } else {
                return $InstallPath
            }
        }
    }
    
    # Clone repository
    Write-BootstrapLog "Cloning AitherZero repository..." -Level Info
    $gitUrl = "https://github.com/$script:GitHubOrg/$script:GitHubRepo.git"
    
    try {
        git clone $gitUrl $InstallPath --depth 1
        Write-BootstrapLog "Repository cloned successfully" -Level Success
    } catch {
        Write-BootstrapLog "Failed to clone repository: $_" -Level Error
        throw
    }
    
    return $InstallPath
}

function Initialize-AitherZero {
    param(
        [string]$InstallPath,
        [string]$Profile
    )
    
    Write-BootstrapLog "Initializing AitherZero..." -Level Info
    
    # Change to installation directory
    Push-Location $InstallPath
    
    try {
        # Run developer setup
        $setupScript = Join-Path $InstallPath "Start-DeveloperSetup.ps1"
        if (Test-Path $setupScript) {
            Write-BootstrapLog "Running developer setup..." -Level Info
            
            $setupParams = @{
                Profile = if ($Profile -eq 'Minimal') { 'Quick' } else { 'Full' }
            }
            
            if ($Profile -eq 'Minimal') {
                $setupParams['SkipAITools'] = $true
                $setupParams['SkipGitHooks'] = $true
            }
            
            & $setupScript @setupParams
        }
        
        # Run initial application setup
        $startScript = Join-Path $InstallPath "Start-AitherZero.ps1"
        if (Test-Path $startScript) {
            Write-BootstrapLog "Running initial setup wizard..." -Level Info
            & $startScript -Setup -InstallationProfile $(if ($Profile -eq 'Full') { 'full' } else { 'developer' })
        }
        
        Write-BootstrapLog "AitherZero initialization completed" -Level Success
        
    } finally {
        Pop-Location
    }
}

function Add-PathEnvironment {
    param(
        [string]$InstallPath,
        [hashtable]$PlatformInfo
    )
    
    Write-BootstrapLog "Adding AitherZero to PATH..." -Level Info
    
    $binPath = Join-Path $InstallPath "bin"
    
    # Create bin directory if it doesn't exist
    if (-not (Test-Path $binPath)) {
        New-Item -Path $binPath -ItemType Directory -Force | Out-Null
    }
    
    # Create launcher script
    $launcherPath = Join-Path $binPath "aitherzero"
    $launcherContent = @"
#!/usr/bin/env pwsh
& '$InstallPath/Start-AitherZero.ps1' `$args
"@
    
    Set-Content -Path $launcherPath -Value $launcherContent -Encoding UTF8
    
    if ($PlatformInfo.Platform -ne 'Windows' -or $PlatformInfo.IsWSL) {
        chmod +x $launcherPath
    }
    
    # Add to PATH
    if ($PlatformInfo.Platform -eq 'Windows' -and -not $PlatformInfo.IsWSL) {
        # Add to user PATH on Windows
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($currentPath -notlike "*$binPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binPath", "User")
            Write-BootstrapLog "Added to Windows PATH (restart shell to take effect)" -Level Success
        }
    } else {
        # Add to shell profile on Unix
        $shellProfile = $null
        
        if (Test-Path "$HOME/.bashrc") {
            $shellProfile = "$HOME/.bashrc"
        } elseif (Test-Path "$HOME/.zshrc") {
            $shellProfile = "$HOME/.zshrc"
        }
        
        if ($shellProfile) {
            $exportLine = "export PATH=`$PATH:$binPath"
            if (-not (Select-String -Path $shellProfile -Pattern $binPath -SimpleMatch -Quiet)) {
                Add-Content -Path $shellProfile -Value "`n# AitherZero"
                Add-Content -Path $shellProfile -Value $exportLine
                Write-BootstrapLog "Added to $shellProfile (restart shell to take effect)" -Level Success
            }
        }
    }
}

function Show-CompletionMessage {
    param(
        [string]$InstallPath,
        [hashtable]$PlatformInfo
    )
    
    Write-BootstrapLog "AitherZero Bootstrap Complete!" -Level Header
    
    Write-Host ""
    Write-Host "Installation Summary:" -ForegroundColor Cyan
    Write-Host "  Platform: $($PlatformInfo.Platform) $($PlatformInfo.Version)" -ForegroundColor White
    Write-Host "  Location: $InstallPath" -ForegroundColor White
    Write-Host "  Profile: $Profile" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Restart your shell to update PATH" -ForegroundColor White
    Write-Host "  2. Run 'aitherzero' to start the application" -ForegroundColor White
    Write-Host "  3. Run 'aitherzero -Help' for available options" -ForegroundColor White
    Write-Host ""
    
    if ($PlatformInfo.Platform -eq 'Windows' -and -not $PlatformInfo.IsWSL) {
        Write-Host "Windows-specific notes:" -ForegroundColor Yellow
        Write-Host "  - WSL 2 has been enabled (restart required)" -ForegroundColor White
        Write-Host "  - Run 'wsl --install -d Debian' to install Debian" -ForegroundColor White
        Write-Host "  - VS Code integration available via Remote-WSL extension" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "For documentation, visit: https://github.com/$script:GitHubOrg/$script:GitHubRepo" -ForegroundColor Gray
    Write-Host ""
}

#endregion

#region Main Execution

try {
    # Show header
    Write-BootstrapLog "$script:ProjectName Bootstrap v$script:BootstrapVersion" -Level Header
    
    # Check if running with sufficient privileges
    if ($PlatformInfo.Platform -eq 'Windows' -and -not $PlatformInfo.IsWSL -and -not (Test-Administrator)) {
        Write-BootstrapLog "Administrator privileges required on Windows" -Level Warning
        Write-BootstrapLog "Restarting with elevated privileges..." -Level Info
        
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($PSBoundParameters.Count -gt 0) {
            $arguments += " " + ($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join " "
        }
        
        Start-Process PowerShell -Verb RunAs -ArgumentList $arguments -Wait
        exit
    }
    
    # Detect platform
    Write-BootstrapLog "Detecting platform..." -Level Info
    $platformInfo = Get-PlatformInfo
    Write-BootstrapLog "Detected: $($platformInfo.Platform) $($platformInfo.Version) ($($platformInfo.Architecture))" -Level Success
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-BootstrapLog "PowerShell 7+ required (current: $($PSVersionTable.PSVersion))" -Level Warning
        
        if (-not $SkipPrerequisites) {
            Install-PowerShell7 -PlatformInfo $platformInfo
            
            Write-BootstrapLog "Please restart this script with PowerShell 7" -Level Warning
            Write-Host "Run: pwsh $PSCommandPath $($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" } | Join-String -Separator ' ')" -ForegroundColor Yellow
            exit
        }
    }
    
    # Install prerequisites
    if (-not $SkipPrerequisites) {
        Install-Prerequisites -PlatformInfo $platformInfo
    }
    
    # Download/Clone AitherZero
    $installLocation = Get-AitherZero -InstallPath $InstallPath -PlatformInfo $platformInfo
    
    # Initialize AitherZero
    Initialize-AitherZero -InstallPath $installLocation -Profile $Profile
    
    # Add to PATH
    Add-PathEnvironment -InstallPath $installLocation -PlatformInfo $platformInfo
    
    # Show completion message
    Show-CompletionMessage -InstallPath $installLocation -PlatformInfo $platformInfo
    
} catch {
    Write-BootstrapLog "Bootstrap failed: $_" -Level Error
    Write-BootstrapLog $_.ScriptStackTrace -Level Error
    exit 1
}

#endregion