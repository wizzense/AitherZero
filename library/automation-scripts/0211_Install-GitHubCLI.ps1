#Requires -Version 7.0

<#
.SYNOPSIS
    Install GitHub CLI (gh)
.DESCRIPTION
    Installs the GitHub CLI tool for command-line interaction with GitHub.
    Supports Windows, Linux, and macOS.
.PARAMETER Force
    Force reinstallation even if already installed
.PARAMETER Configure
    Configure gh after installation (authentication)
.EXAMPLE
    ./0211_Install-GitHubCLI.ps1
.EXAMPLE
    ./0211_Install-GitHubCLI.ps1 -Force -Configure
.NOTES
    Stage: Development Tools
    Dependencies: None
    Tags: github, cli, development, git
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Configure
)

$ErrorActionPreference = 'Stop'

# Check if already installed
$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue

if ($ghInstalled -and -not $Force) {
    Write-Host "[✓] GitHub CLI is already installed: $(gh --version)" -ForegroundColor Green
    exit 0
}

Write-Host "[i] Installing GitHub CLI..." -ForegroundColor Cyan

try {
    if ($IsWindows -or $PSVersionTable.Platform -eq 'Win32NT') {
        # Windows installation
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "  Using winget..." -ForegroundColor Gray
            winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
        }
        elseif (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "  Using Chocolatey..." -ForegroundColor Gray
            choco install gh -y
        }
        else {
            Write-Host "  Downloading installer..." -ForegroundColor Gray
            $downloadUrl = 'https://github.com/cli/cli/releases/latest/download/gh_windows_amd64.msi'
            $installerPath = Join-Path $env:TEMP 'gh_installer.msi'
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /quiet /norestart" -Wait
            Remove-Item $installerPath -Force
        }
    }
    elseif ($IsLinux) {
        # Linux installation
        if (Test-Path '/etc/debian_version') {
            Write-Host "  Using apt..." -ForegroundColor Gray
            sudo apt-get update -qq
            sudo apt-get install -y gh
        }
        elseif (Test-Path '/etc/redhat-release') {
            Write-Host "  Using dnf/yum..." -ForegroundColor Gray
            sudo dnf install -y gh || sudo yum install -y gh
        }
        else {
            Write-Host "  Using binary installation..." -ForegroundColor Gray
            $downloadUrl = 'https://github.com/cli/cli/releases/latest/download/gh_linux_amd64.tar.gz'
            $tempFile = '/tmp/gh.tar.gz'
            
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing
            sudo tar -xzf $tempFile -C /usr/local --strip-components=1
            rm $tempFile
        }
    }
    elseif ($IsMacOS) {
        # macOS installation
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-Host "  Using Homebrew..." -ForegroundColor Gray
            brew install gh
        }
        else {
            Write-Error "Homebrew is required for macOS installation"
            exit 1
        }
    }
    
    # Verify installation
    $ghInstalled = Get-Command gh -ErrorAction SilentlyContinue
    
    if ($ghInstalled) {
        $version = (gh --version | Select-Object -First 1)
        Write-Host "[✓] GitHub CLI installed successfully: $version" -ForegroundColor Green
        
        # Configure if requested
        if ($Configure) {
            Write-Host "[i] Configuring GitHub CLI..." -ForegroundColor Cyan
            Write-Host "  Run: gh auth login" -ForegroundColor Yellow
            gh auth login
        }
        
        exit 0
    }
    else {
        Write-Error "GitHub CLI installation failed - command not found"
        exit 1
    }
}
catch {
    Write-Error "Failed to install GitHub CLI: $($_.Exception.Message)"
    exit 1
}
