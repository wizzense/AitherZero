#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Installs essential development tools: Git, GitHub CLI, Node.js/npm, Claude Code, and PowerShell 7

.DESCRIPTION
    Cross-platform installation script that sets up a complete development environment.

    On Windows:
    - Installs/configures WSL2 with Ubuntu
    - Calls the shell script to install tools in WSL
    - Optionally installs PowerShell 7 on Windows host

    On Linux/macOS:
    - Directly installs all tools using native package managers

    Tools installed:
    - Git (version control)
    - GitHub CLI (gh command)
    - Node.js and npm (JavaScript runtime and package manager)
    - Claude Code (Anthropic AI CLI tool)
    - PowerShell 7 (cross-platform shell)

.PARAMETER SkipWSL
    On Windows, skip WSL installation (assumes WSL is already configured)

.PARAMETER WSLUsername
    Username to create in WSL Ubuntu (required for new WSL installations)

.PARAMETER WSLPassword
    Password for WSL user (will prompt securely if not provided)

.PARAMETER SkipHostPowerShell
    On Windows, skip installing PowerShell 7 on the host system

.PARAMETER Force
    Force reinstallation even if tools are already present

.PARAMETER WhatIf
    Show what would be installed without making changes

.EXAMPLE
    # Windows - Install everything including WSL
    .\Install-DevTools.ps1 -WSLUsername "developer"

.EXAMPLE
    # Windows - Use existing WSL
    .\Install-DevTools.ps1 -SkipWSL

.EXAMPLE
    # Linux/macOS - Install all tools
    .\Install-DevTools.ps1

.EXAMPLE
    # Preview installation without changes
    .\Install-DevTools.ps1 -WhatIf

.NOTES
    Author: AitherZero Infrastructure Automation
    Version: 1.0.0
    Requires: PowerShell 7.0+

    Windows Requirements:
    - Administrator privileges (for WSL installation)
    - Windows 10 version 2004+ or Windows 11

    Linux Requirements:
    - sudo privileges
    - curl or wget

    macOS Requirements:
    - Homebrew (will be installed if missing)
    - Xcode Command Line Tools
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [switch]$SkipWSL,

    [Parameter()]
    [string]$WSLUsername,

    [Parameter()]
    [SecureString]$WSLPassword,

    [Parameter()]
    [switch]$SkipHostPowerShell,

    [Parameter()]
    [switch]$Force
)

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Initialize AitherZero framework
try {
    # Use shared utility for project root detection
    . "$PSScriptRoot/../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    $env:PROJECT_ROOT = $projectRoot

    # Import required modules
    Import-Module (Join-Path $projectRoot "aither-core/modules/Logging") -Force
    Import-Module (Join-Path $projectRoot "aither-core/modules/DevEnvironment") -Force

    Write-CustomLog -Level 'INFO' -Message "AitherZero Development Tools Installer started"
    Write-CustomLog -Level 'INFO' -Message "Project root: $projectRoot"
}
catch {
    Write-Warning "Could not load AitherZero modules. Running in standalone mode."
    # Define fallback Write-CustomLog function
    function global:Write-CustomLog {
        param([string]$Level, [string]$Message)
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN' { 'Yellow' }
            'SUCCESS' { 'Green' }
            'INFO' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Platform detection
$IsWindowsPlatform = $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5
$IsLinuxPlatform = ($PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux') -or $IsLinux
$IsMacOSPlatform = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Darwin'

# Additional platform detection for edge cases
if (-not $IsWindowsPlatform -and -not $IsLinuxPlatform -and -not $IsMacOSPlatform) {
    # Fallback detection
    if (Test-Path '/proc/version') {
        $IsLinuxPlatform = $true
    }
    elseif (Test-Path '/System/Library/CoreServices/SystemVersion.plist') {
        $IsMacOSPlatform = $true
    }
}

# Color functions for cross-platform output (enhanced with AitherZero logging)
function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )

    # Use AitherZero logging if available, otherwise fallback to basic coloring
    $level = switch ($Color) {
        'Red' { 'ERROR' }
        'Green' { 'SUCCESS' }
        'Yellow' { 'WARN' }
        'Cyan' { 'INFO' }
        default { 'INFO' }
    }

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $level -Message $Message
    }
    else {
        $colorMap = @{
            'Red' = 31; 'Green' = 32; 'Yellow' = 33; 'Blue' = 34; 'Cyan' = 36; 'White' = 37
        }

        if ($IsWindowsPlatform -and $Host.UI.RawUI) {
            Write-Host $Message -ForegroundColor $Color
        }
        else {
            $ansiColor = $colorMap[$Color]
            Write-Host "`e[${ansiColor}m${Message}`e[0m"
        }
    }
}

function Write-Step {
    param([string]$Message)
    Write-CustomLog -Level 'INFO' -Message "🔧 $Message"
}

function Write-Success {
    param([string]$Message)
    Write-CustomLog -Level 'SUCCESS' -Message "✅ $Message"
}

function Write-Warning {
    param([string]$Message)
    Write-CustomLog -Level 'WARN' -Message "⚠️  $Message"
}

function Write-Error {
    param([string]$Message)
    Write-CustomLog -Level 'ERROR' -Message "❌ $Message"
}

# Main installation function
function Install-DevTools {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-ColorMessage "🚀 AitherZero Development Tools Installer" -Color 'Blue'
    Write-ColorMessage "Installing: Git, GitHub CLI, Node.js/npm, Claude Code, PowerShell 7" -Color 'White'
    Write-Host ""

    # Detect platform and show info
    $platform = if ($IsWindowsPlatform) { "Windows" }
    elseif ($IsLinuxPlatform) { "Linux" }
    elseif ($IsMacOSPlatform) { "macOS" }
    else { "Unknown" }

    Write-ColorMessage "Platform detected: $platform" -Color 'Yellow'
    Write-ColorMessage "PowerShell version: $($PSVersionTable.PSVersion)" -Color 'Yellow'
    Write-Host ""

    if ($WhatIfPreference) {
        Write-ColorMessage "=== DRY RUN MODE - No changes will be made ===" -Color 'Yellow'
        Write-Host ""
    }

    try {
        switch ($platform) {
            'Windows' {
                Install-WindowsDevTools
            }
            'Linux' {
                Install-LinuxDevTools
            }
            'macOS' {
                Install-MacOSDevTools
            }
            default {
                throw "Unsupported platform: $platform"
            }
        }

        Write-Host ""
        Write-Success "Development tools installation completed successfully!"
        Show-PostInstallInstructions

    }
    catch {
        Write-Error "Installation failed: $($_.Exception.Message)"
        Write-Host ""
        Write-ColorMessage "For troubleshooting help, see: https://github.com/Aitherium/AitherZero/docs/troubleshooting.md" -Color 'Yellow'
        exit 1
    }
}

# Windows-specific installation
function Install-WindowsDevTools {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Setting up development environment for Windows"

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting Windows development tools installation"

        # Check if running as administrator
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        if (-not $isAdmin -and -not $SkipWSL) {
            throw "Administrator privileges required for WSL installation. Run PowerShell as Administrator or use -SkipWSL parameter."
        }

        # Install PowerShell 7 on host (optional)
        if (-not $SkipHostPowerShell) {
            Install-PowerShellWindows
        }

        # Use DevEnvironment module if available for WSL setup
        if (Get-Command Install-ClaudeCodeDependencies -ErrorAction SilentlyContinue) {
            Write-Step "Using AitherZero DevEnvironment module for WSL and tool setup"

            $installParams = @{
                WhatIf = $WhatIfPreference
                Force  = $Force
            }

            if (-not $SkipWSL) {
                $installParams['WSLUsername'] = $WSLUsername
                if ($WSLPassword) {
                    $installParams['WSLPassword'] = $WSLPassword
                }
            }
            else {
                $installParams['SkipWSL'] = $true
            }

            # Install Claude Code dependencies (includes Node.js, npm)
            Install-ClaudeCodeDependencies @installParams

            # Install additional tools using DevEnvironment module
            if (Get-Command Install-GeminiCLIDependencies -ErrorAction SilentlyContinue) {
                Write-Step "Installing additional development tools"
                Install-GeminiCLIDependencies @installParams
            }

        }
        else {
            # Fallback to manual WSL setup
            if (-not $SkipWSL) {
                Install-WSLEnvironment
            }
            else {
                Write-Step "Skipping WSL installation (using existing WSL)"
                Test-WSLAvailability
            }

            # Call Unix installation script in WSL
            Install-ToolsInWSL
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Windows development tools installation completed"

    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Windows installation failed: $($_.Exception.Message)"
        throw
    }
}

# Install tools in WSL using shell script
function Install-ToolsInWSL {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Installing development tools in WSL"

    try {
        $scriptPath = Join-Path $PSScriptRoot "install-dev-tools.sh"
        if (-not (Test-Path $scriptPath)) {
            Write-Warning "Unix installation script not found at $scriptPath"
            Write-CustomLog -Level 'WARN' -Message "Creating the script..."
            New-UnixInstallScript
        }

        if ($PSCmdlet.ShouldProcess("WSL", "Install development tools")) {
            $wslScriptPath = wsl wslpath -a $scriptPath
            wsl chmod +x $wslScriptPath

            $wslArgs = @()
            if ($Force) { $wslArgs += '--force' }
            if ($WhatIfPreference) { $wslArgs += '--whatif' }

            Write-CustomLog -Level 'INFO' -Message "Executing installation script in WSL: $wslScriptPath"
            wsl bash $wslScriptPath @wslArgs

            if ($LASTEXITCODE -eq 0) {
                Write-Success "Tools installed successfully in WSL"
            }
            else {
                throw "WSL installation script failed with exit code: $LASTEXITCODE"
            }
        }
    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Failed to install tools in WSL: $($_.Exception.Message)"
        throw
    }
}

# Linux-specific installation
function Install-LinuxDevTools {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Setting up development environment for Linux"

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting Linux development tools installation"

        # Use DevEnvironment module if available
        if (Get-Command Install-ClaudeCodeDependencies -ErrorAction SilentlyContinue) {
            Write-Step "Using AitherZero DevEnvironment module for tool installation"

            $installParams = @{
                WhatIf = $WhatIfPreference
                Force  = $Force
            }

            Install-ClaudeCodeDependencies @installParams

            # Install PowerShell 7 on Linux
            Install-PowerShellLinux

        }
        else {
            # Fallback to shell script
            Install-ToolsWithShellScript
        }

        Write-CustomLog -Level 'SUCCESS' -Message "Linux development tools installation completed"

    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "Linux installation failed: $($_.Exception.Message)"
        throw
    }
}

# macOS-specific installation
function Install-MacOSDevTools {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Setting up development environment for macOS"

    try {
        Write-CustomLog -Level 'INFO' -Message "Starting macOS development tools installation"

        # Install Homebrew if not present
        if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
            Write-Step "Installing Homebrew"
            if ($PSCmdlet.ShouldProcess("Homebrew", "Install")) {
                $installScript = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
                bash -c $installScript
            }
        }
        else {
            Write-Success "Homebrew already installed"
        }

        # Use DevEnvironment module if available
        if (Get-Command Install-ClaudeCodeDependencies -ErrorAction SilentlyContinue) {
            Write-Step "Using AitherZero DevEnvironment module for tool installation"

            $installParams = @{
                WhatIf = $WhatIfPreference
                Force  = $Force
            }

            Install-ClaudeCodeDependencies @installParams

        }
        else {
            # Fallback to shell script
            Install-ToolsWithShellScript
        }

        Write-CustomLog -Level 'SUCCESS' -Message "macOS development tools installation completed"

    }
    catch {
        Write-CustomLog -Level 'ERROR' -Message "macOS installation failed: $($_.Exception.Message)"
        throw
    }
}

# Install PowerShell 7 on Windows
function Install-PowerShellWindows {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Installing PowerShell 7 on Windows host"

    if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install on Windows")) {
        try {
            # Check if already installed
            $existingPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($existingPwsh -and -not $Force) {
                Write-Success "PowerShell 7 already installed: $($existingPwsh.Version)"
                return
            }

            # Download and install PowerShell 7
            $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.5.1-win-x64.msi"
            $tempPath = Join-Path $env:TEMP "PowerShell-7.5.1-win-x64.msi"

            Write-ColorMessage "Downloading PowerShell 7..." -Color 'Yellow'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath

            Write-ColorMessage "Installing PowerShell 7..." -Color 'Yellow'
            Start-Process msiexec -ArgumentList "/i `"$tempPath`" /quiet" -Wait

            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
            Write-Success "PowerShell 7 installed successfully"

        }
        catch {
            Write-Warning "Failed to install PowerShell 7 on Windows: $($_.Exception.Message)"
            Write-ColorMessage "You can manually install from: https://github.com/PowerShell/PowerShell/releases" -Color 'Yellow'
        }
    }
}

# Install PowerShell 7 on Linux
function Install-PowerShellLinux {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Installing PowerShell 7 on Linux"

    if ($PSCmdlet.ShouldProcess("PowerShell 7", "Install on Linux")) {
        try {
            # Check if already installed
            $existingPwsh = Get-Command pwsh -ErrorAction SilentlyContinue
            if ($existingPwsh -and -not $Force) {
                Write-Success "PowerShell 7 already installed: $($existingPwsh.Version)"
                return
            }

            # Detect Linux distribution
            if (Test-Path '/etc/os-release') {
                $osInfo = Get-Content '/etc/os-release' | ConvertFrom-StringData
                $distro = $osInfo.ID.ToLower()

                Write-CustomLog -Level 'INFO' -Message "Detected Linux distribution: $distro"

                switch ($distro) {
                    'ubuntu' {
                        Write-CustomLog -Level 'INFO' -Message "Installing PowerShell 7 on Ubuntu..."
                        $script = @"
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
rm -f packages-microsoft-prod.deb
"@
                        Invoke-Expression $script
                    }
                    { 'centos'; 'rhel'; 'fedora' } {
                        Write-CustomLog -Level 'INFO' -Message "Installing PowerShell 7 on $distro..."
                        $script = @"
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo rpm -Uvh https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
sudo dnf install -y powershell
"@
                        Invoke-Expression $script
                    }
                    default {
                        Write-Warning "Unsupported Linux distribution: $distro. Please install PowerShell 7 manually."
                    }
                }
            }

            Write-Success "PowerShell 7 installation completed"

        }
        catch {
            Write-Warning "Failed to install PowerShell 7 on Linux: $($_.Exception.Message)"
            Write-CustomLog -Level 'WARN' -Message "You can manually install from: https://github.com/PowerShell/PowerShell/releases"
        }
    }
}

# Install and configure WSL
function Install-WSLEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Installing and configuring WSL2 with Ubuntu"

    if ($PSCmdlet.ShouldProcess("WSL2", "Install and configure")) {
        # Check Windows version
        $windowsVersion = [System.Environment]::OSVersion.Version
        if ($windowsVersion.Major -lt 10 -or ($windowsVersion.Major -eq 10 -and $windowsVersion.Build -lt 19041)) {
            throw "Windows 10 version 2004 (build 19041) or later is required for WSL2"
        }

        # Enable WSL features
        Write-ColorMessage "Enabling WSL features..." -Color 'Yellow'
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart

        # Set WSL 2 as default
        wsl --set-default-version 2

        # Install Ubuntu if not already installed
        $distributions = wsl --list --quiet 2>$null
        if (-not ($distributions -contains "Ubuntu")) {
            Write-ColorMessage "Installing Ubuntu distribution..." -Color 'Yellow'
            wsl --install -d Ubuntu

            Write-Warning "WSL installation completed. You may need to restart your computer."
            Write-ColorMessage "After restart, run this script again with -SkipWSL to continue." -Color 'Yellow'
        }

        # Configure user if specified
        if ($WSLUsername) {
            Set-WSLUser
        }
    }
}

# Configure WSL user
function Set-WSLUser {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Configuring WSL user: $WSLUsername"

    if ($PSCmdlet.ShouldProcess("WSL user", "Configure")) {
        $password = if ($WSLPassword) {
            [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($WSLPassword)
            )
        }
        else {
            Read-Host -Prompt "Enter password for WSL user '$WSLUsername'" -AsSecureString |
            ForEach-Object { [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)
                ) }
        }

        # Create user in WSL
        $userScript = @"
#!/bin/bash
if ! id -u ${WSLUsername} >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash ${WSLUsername}
    echo '${WSLUsername}:${password}' | sudo chpasswd
    sudo usermod -aG sudo ${WSLUsername}
    echo '${WSLUsername} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${WSLUsername}
    echo "User ${WSLUsername} created successfully"
else
    echo "User ${WSLUsername} already exists"
fi
"@

        $userScript | wsl bash
    }
}

# Test WSL availability
function Test-WSLAvailability {
    try {
        $null = wsl --list --verbose 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL is available and configured"
            $distributions = wsl --list --quiet
            Write-ColorMessage "Available distributions: $($distributions -join ', ')" -Color 'Yellow'
        }
        else {
            throw "WSL is not properly configured"
        }
    }
    catch {
        throw "WSL is not available. Please install WSL first or run without -SkipWSL."
    }
}

# Create the Unix installation script
function New-UnixInstallScript {
    [CmdletBinding()]
    param()

    $scriptPath = Join-Path $PSScriptRoot "install-dev-tools.sh"

    if (Test-Path $scriptPath) {
        Write-ColorMessage "Unix installation script already exists at: $scriptPath" -Color 'Yellow'
        return
    }

    Write-ColorMessage "Creating Unix installation script at: $scriptPath" -Color 'Yellow'

    # Check if the script exists in the same directory
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Unix installation script not found. Please ensure install-dev-tools.sh is in the same directory as this PowerShell script."
        Write-ColorMessage "You can download it from: https://github.com/Aitherium/AitherZero/scripts/install-dev-tools.sh" -Color 'Yellow'
        throw "Required Unix installation script is missing"
    }
}

# Install tools using shell script (fallback method)
function Install-ToolsWithShellScript {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Step "Installing tools using shell script"

    $scriptPath = Join-Path $PSScriptRoot "install-dev-tools.sh"
    if (-not (Test-Path $scriptPath)) {
        Write-CustomLog -Level 'WARN' -Message "Creating Unix installation script..."
        New-UnixInstallScript
    }

    if ($PSCmdlet.ShouldProcess("Unix system", "Install development tools")) {
        chmod +x $scriptPath

        $bashArgs = @($scriptPath)
        if ($Force) { $bashArgs += '--force' }
        if ($WhatIfPreference) { $bashArgs += '--whatif' }

        Write-CustomLog -Level 'INFO' -Message "Executing installation script: $scriptPath"
        & bash @bashArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Tools installed successfully"
        }
        else {
            throw "Installation script failed with exit code: $LASTEXITCODE"
        }
    }
}

# Show post-installation instructions
function Show-PostInstallInstructions {
    Write-Host ""
    Write-ColorMessage "=== Post-Installation Instructions ===" -Color 'Blue'
    Write-Host ""

    if ($IsWindowsPlatform) {
        Write-ColorMessage "Windows Setup Complete:" -Color 'Green'
        Write-Host "1. Development tools are installed in WSL"
        Write-Host "2. To access tools, open WSL: wsl"
        Write-Host "3. Or use Windows Terminal with WSL profile"
        Write-Host ""
    }

    Write-ColorMessage "Verify Installation:" -Color 'Green'
    Write-Host "git --version"
    Write-Host "gh --version"
    Write-Host "node --version"
    Write-Host "npm --version"
    Write-Host "pwsh --version"
    Write-Host "claude --version"
    Write-Host ""

    Write-ColorMessage "Next Steps:" -Color 'Green'
    Write-Host "1. Configure Git: git config --global user.name 'Your Name'"
    Write-Host "2. Configure Git: git config --global user.email 'your.email@example.com'"
    Write-Host "3. Login to GitHub: gh auth login"
    Write-Host "4. Test Claude Code: claude --help"
    Write-Host ""

    Write-ColorMessage "For Claude Code setup:" -Color 'Yellow'
    Write-Host "- You'll need an Anthropic API key"
    Write-Host "- Visit: https://console.anthropic.com/"
    Write-Host "- Set environment variable: export ANTHROPIC_API_KEY='your-key-here'"
}

# Execute main function
try {
    Install-DevTools
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}
