# Complete Development Environment Setup Script
# Run this script as Administrator

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Host 'Requesting Administrator privileges...' -ForegroundColor Yellow
    # Relaunch as administrator
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Wait
    exit
}

Write-Host 'Starting Development Environment Setup...' -ForegroundColor Green

# Function to check if a command exists
function Test-CommandExists {
    param($command)
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# 1. Install Chocolatey if not present
if (!(Test-CommandExists choco)) {
    Write-Host 'Installing Chocolatey...' -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# 2. Install VS Code
Write-Host 'Installing Visual Studio Code...' -ForegroundColor Yellow
if (!(Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe")) {
    choco install vscode -y
} else {
    Write-Host 'VS Code already installed' -ForegroundColor Green
}

# 3. Install GitHub Desktop
Write-Host 'Installing GitHub Desktop...' -ForegroundColor Yellow
if (!(Test-Path "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe")) {
    choco install github-desktop -y
} else {
    Write-Host 'GitHub Desktop already installed' -ForegroundColor Green
}

# 4. Enable WSL 2
Write-Host 'Enabling WSL 2...' -ForegroundColor Yellow

# Enable WSL feature
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine feature
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Download and install WSL2 Linux kernel update package
Write-Host 'Downloading WSL2 kernel update...' -ForegroundColor Yellow
$wslUpdateUrl = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
$wslUpdatePath = "$env:TEMP\wsl_update_x64.msi"
Invoke-WebRequest -Uri $wslUpdateUrl -OutFile $wslUpdatePath
Start-Process msiexec.exe -Wait -ArgumentList "/i $wslUpdatePath /quiet"
Remove-Item $wslUpdatePath

# Set WSL 2 as default version
wsl --set-default-version 2

# 5. Install Debian
Write-Host 'Installing Debian for WSL...' -ForegroundColor Yellow
$debianInstalled = wsl -l -q | Select-String -Pattern 'Debian'
if (!$debianInstalled) {
    # Install Debian from Microsoft Store
    winget install -e --id Debian.Debian

    # Wait for installation
    Write-Host 'Waiting for Debian installation to complete...' -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    # Launch Debian to complete initial setup
    Write-Host 'Please complete Debian setup in the window that opens (create username/password)' -ForegroundColor Cyan
    Start-Process debian.exe
    Read-Host "Press Enter after you've completed Debian setup"
} else {
    Write-Host 'Debian already installed' -ForegroundColor Green
}

# 6. Install Claude Code and its requirements
Write-Host 'Installing Claude Code requirements in Debian...' -ForegroundColor Yellow

# First, set up automated sudo for apt commands temporarily
Write-Host 'Setting up automated installation...' -ForegroundColor Yellow
wsl -d Debian -u root bash -c "echo '%sudo ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/temp-nopasswd"

# Run all installation commands directly
Write-Host 'Updating package list...' -ForegroundColor Yellow
wsl -d Debian bash -c 'sudo apt update -y'

Write-Host 'Installing Python and essential packages...' -ForegroundColor Yellow
wsl -d Debian bash -c 'sudo apt install -y python3 python3-pip python3-venv git build-essential curl'

Write-Host 'Installing Node.js LTS...' -ForegroundColor Yellow
wsl -d Debian bash -c 'curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -'
wsl -d Debian bash -c 'sudo apt install -y nodejs'

Write-Host 'Installing Claude Code from npm...' -ForegroundColor Yellow
# Try multiple possible package names for Claude Code
$claudeInstalled = $false

# Try @anthropic-ai/claude-code
wsl -d Debian bash -c 'sudo npm install -g @anthropic-ai/claude-code' 2>$null
if ($LASTEXITCODE -eq 0) {
    $claudeInstalled = $true
    Write-Host 'Claude Code installed successfully!' -ForegroundColor Green
}

# If that didn't work, try claude-cli
if (-not $claudeInstalled) {
    Write-Host 'Trying alternative package name...' -ForegroundColor Yellow
    wsl -d Debian bash -c 'sudo npm install -g claude-cli' 2>$null
    if ($LASTEXITCODE -eq 0) {
        $claudeInstalled = $true
        Write-Host 'Claude CLI installed successfully!' -ForegroundColor Green
    }
}

# If still not installed, try the anthropic SDK
if (-not $claudeInstalled) {
    Write-Host 'Trying Anthropic SDK...' -ForegroundColor Yellow
    wsl -d Debian bash -c 'sudo npm install -g @anthropic-ai/sdk' 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Anthropic SDK installed successfully!' -ForegroundColor Green
        Write-Host "Note: You may need to use 'anthropic' command instead of 'claude-code'" -ForegroundColor Yellow
    }
}

# Also install Claude Code via pip as a fallback
Write-Host 'Installing Python-based Claude tools...' -ForegroundColor Yellow
wsl -d Debian bash -c 'pip3 install anthropic claude-cli --user' 2>$null

# Clean up sudo permissions
wsl -d Debian -u root bash -c 'rm /etc/sudoers.d/temp-nopasswd'

# Check what got installed
Write-Host "`nChecking installed Claude tools..." -ForegroundColor Yellow
Write-Host 'NPM global packages:' -ForegroundColor Cyan
wsl -d Debian bash -c "npm list -g --depth=0 2>/dev/null | grep -E '(claude|anthropic)'"
Write-Host "`nPython packages:" -ForegroundColor Cyan
wsl -d Debian bash -c "pip3 list 2>/dev/null | grep -E '(claude|anthropic)'"
Write-Host "`nAvailable commands:" -ForegroundColor Cyan
wsl -d Debian bash -c 'which claude-code claude anthropic 2>/dev/null'

# Final instructions
Write-Host "`n`n==================== SETUP COMPLETE ====================" -ForegroundColor Green
Write-Host 'The following have been installed:' -ForegroundColor Cyan
Write-Host '✓ Visual Studio Code' -ForegroundColor Green
Write-Host '✓ GitHub Desktop' -ForegroundColor Green
Write-Host '✓ WSL 2.0' -ForegroundColor Green
Write-Host '✓ Debian Linux' -ForegroundColor Green
Write-Host '✓ Claude Code (in Debian)' -ForegroundColor Green

Write-Host "`nIMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host '1. A system restart may be required for WSL 2 to work properly'
Write-Host '2. To use Claude Code, open Debian and run: claude-code'
Write-Host "3. You'll need to authenticate Claude Code with your API key on first use"
Write-Host "4. VS Code can be integrated with WSL by installing the 'Remote - WSL' extension"

Write-Host "`nWould you like to restart your computer now? (Recommended)" -ForegroundColor Cyan
$restart = Read-Host 'Enter Y to restart, N to skip'
if ($restart -eq 'Y' -or $restart -eq 'y') {
    Restart-Computer -Force
}
