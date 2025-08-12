#!/usr/bin/env powershell
# PowerShell 5.1 Bootstrap for AitherZero
# This minimal script ensures PowerShell 7 is installed, then runs the main bootstrap

<#
.SYNOPSIS
    Minimal bootstrap script for PowerShell 5.1 that installs PowerShell 7 and runs main bootstrap
.DESCRIPTION
    This script is designed to work with PowerShell 5.1 on Windows. It will:
    1. Check if PowerShell 7 is installed
    2. Install PowerShell 7 if missing
    3. Re-launch the main bootstrap script in PowerShell 7
.EXAMPLE
    # One-liner for PowerShell 5.1
    iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-ps5.ps1 | iex
    
    # Or download and run
    Invoke-WebRequest -Uri https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-ps5.ps1 -OutFile bootstrap-ps5.ps1
    .\bootstrap-ps5.ps1
#>

[CmdletBinding()]
param(
    [string]$InstallProfile = 'Standard',
    [string]$InstallPath,
    [string]$Branch = 'main',
    [switch]$NonInteractive,
    [switch]$AutoInstallDeps = $true,
    [switch]$SkipAutoStart
)

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Message {
    param(
        [string]$Message,
        [string]$Level = 'Info'
    )
    
    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    
    Write-Host $Message -ForegroundColor $colors[$Level]
}

function Test-PowerShell7 {
    # Check if pwsh.exe exists in common locations
    $pwshPaths = @(
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe",
        "$env:ProgramFiles (x86)\PowerShell\7\pwsh.exe"
    )
    
    foreach ($path in $pwshPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Check if pwsh is in PATH
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        return $pwsh.Source
    }
    
    return $null
}

function Install-PowerShell7 {
    Write-Message "Installing PowerShell 7..." -Level Info
    
    try {
        # Try winget first (available on Windows 10 1709+)
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if ($winget) {
            Write-Message "Using winget to install PowerShell 7..." -Level Info
            
            # Accept source agreements silently
            $wingetArgs = @(
                "install",
                "--id", "Microsoft.PowerShell",
                "--source", "winget",
                "--accept-source-agreements",
                "--accept-package-agreements"
            )
            
            if ($NonInteractive) {
                $wingetArgs += "--silent"
            }
            
            $process = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-Message "PowerShell 7 installed successfully via winget!" -Level Success
                return $true
            } else {
                Write-Message "Winget installation failed, trying MSI method..." -Level Warning
            }
        }
        
        # Fallback to MSI download
        Write-Message "Downloading PowerShell 7 MSI installer..." -Level Info
        
        # Get latest release URL
        $apiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
        
        # Find the Windows x64 MSI
        $msiAsset = $release.assets | Where-Object { 
            $_.name -like "*win-x64.msi" -and $_.name -notlike "*preview*" 
        } | Select-Object -First 1
        
        if (-not $msiAsset) {
            # Fallback to hardcoded URL
            $downloadUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
        } else {
            $downloadUrl = $msiAsset.browser_download_url
        }
        
        $msiPath = "$env:TEMP\PowerShell-7-win-x64.msi"
        
        Write-Message "Downloading from: $downloadUrl" -Level Info
        Invoke-WebRequest -Uri $downloadUrl -OutFile $msiPath -UseBasicParsing
        
        if (-not (Test-Path $msiPath)) {
            throw "Failed to download PowerShell 7 installer"
        }
        
        Write-Message "Installing PowerShell 7 MSI..." -Level Info
        
        # Prepare MSI arguments
        $msiArgs = @(
            "/i",
            "`"$msiPath`"",
            "/quiet",
            "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
            "ENABLE_PSREMOTING=0",
            "REGISTER_MANIFEST=1"
        )
        
        # Check if we need admin rights
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
        } else {
            Write-Message "Requesting administrator privileges for installation..." -Level Warning
            $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -Verb RunAs
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Message "PowerShell 7 installed successfully!" -Level Success
            
            # Clean up
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            throw "MSI installation failed with exit code: $($process.ExitCode)"
        }
        
    } catch {
        Write-Message "Failed to install PowerShell 7: $_" -Level Error
        return $false
    }
}

# Main execution
Clear-Host
Write-Host @"

    _    _ _   _               ______               
   / \  (_) |_| |__   ___ _ _|__  /___ _ __ ___  
  / _ \ | | __| '_ \ / _ \ '__/ // _ \ '__/ _ \ 
 / ___ \| | |_| | | |  __/ | / /|  __/ | | (_) |
/_/   \_\_|\__|_| |_|\___|_|/____\___|_|  \___/ 
                                                 
        PowerShell 5.1 Bootstrap

"@ -ForegroundColor Cyan

Write-Message "Checking PowerShell version..." -Level Info
Write-Message "Current version: $($PSVersionTable.PSVersion)" -Level Info

# Check if we're already running PowerShell 7+
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Message "Already running PowerShell 7+, downloading main bootstrap..." -Level Success
    
    # Download and run main bootstrap
    $mainBootstrapUrl = "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1"
    $scriptContent = Invoke-WebRequest -Uri $mainBootstrapUrl -UseBasicParsing | Select-Object -ExpandProperty Content
    
    # Build arguments
    $scriptArgs = @{}
    if ($InstallProfile) { $scriptArgs['InstallProfile'] = $InstallProfile }
    if ($InstallPath) { $scriptArgs['InstallPath'] = $InstallPath }
    if ($Branch) { $scriptArgs['Branch'] = $Branch }
    if ($NonInteractive) { $scriptArgs['NonInteractive'] = $true }
    if ($AutoInstallDeps) { $scriptArgs['AutoInstallDeps'] = $true }
    if ($SkipAutoStart) { $scriptArgs['SkipAutoStart'] = $true }
    
    # Execute the script
    $scriptBlock = [scriptblock]::Create($scriptContent)
    & $scriptBlock @scriptArgs
    
    exit $LASTEXITCODE
}

# We're on PowerShell 5.1, need to check/install PowerShell 7
Write-Message "PowerShell 7 is required for AitherZero" -Level Warning

$pwshPath = Test-PowerShell7

if (-not $pwshPath) {
    Write-Message "PowerShell 7 not found" -Level Warning
    
    if (-not $NonInteractive) {
        $response = Read-Host "Install PowerShell 7 now? (Y/n)"
        if ($response -eq 'n') {
            Write-Message "Installation cancelled. PowerShell 7 is required for AitherZero." -Level Error
            exit 1
        }
    }
    
    $installed = Install-PowerShell7
    
    if (-not $installed) {
        Write-Message "Failed to install PowerShell 7. Please install manually from:" -Level Error
        Write-Message "https://github.com/PowerShell/PowerShell/releases" -Level Info
        exit 1
    }
    
    # Re-check for PowerShell 7
    $pwshPath = Test-PowerShell7
    
    if (-not $pwshPath) {
        # Default path after installation
        $pwshPath = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
        
        if (-not (Test-Path $pwshPath)) {
            Write-Message "PowerShell 7 installed but not found. Please restart your terminal and try again." -Level Error
            exit 1
        }
    }
} else {
    Write-Message "Found PowerShell 7 at: $pwshPath" -Level Success
}

# Download main bootstrap script
Write-Message "Downloading main bootstrap script..." -Level Info
$mainBootstrapUrl = "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1"
$tempBootstrap = "$env:TEMP\aitherzero-bootstrap.ps1"

try {
    Invoke-WebRequest -Uri $mainBootstrapUrl -OutFile $tempBootstrap -UseBasicParsing
    
    if (-not (Test-Path $tempBootstrap)) {
        throw "Failed to download bootstrap script"
    }
    
    Write-Message "Launching AitherZero bootstrap in PowerShell 7..." -Level Success
    
    # Build arguments for PowerShell 7
    $pwshArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $tempBootstrap
    )
    
    # Add our parameters
    if ($InstallProfile) { $pwshArgs += "-InstallProfile", $InstallProfile }
    if ($InstallPath) { $pwshArgs += "-InstallPath", $InstallPath }
    if ($Branch) { $pwshArgs += "-Branch", $Branch }
    if ($NonInteractive) { $pwshArgs += "-NonInteractive" }
    if ($AutoInstallDeps) { $pwshArgs += "-AutoInstallDeps" }
    if ($SkipAutoStart) { $pwshArgs += "-SkipAutoStart" }
    
    # Launch PowerShell 7 with the main bootstrap
    Write-Message "Starting PowerShell 7..." -Level Info
    Start-Process -FilePath $pwshPath -ArgumentList $pwshArgs -Wait -NoNewWindow
    
    # Clean up
    Remove-Item $tempBootstrap -Force -ErrorAction SilentlyContinue
    
    Write-Message "Bootstrap completed!" -Level Success
    
} catch {
    Write-Message "Failed to run bootstrap: $_" -Level Error
    
    # Clean up on error
    if (Test-Path $tempBootstrap) {
        Remove-Item $tempBootstrap -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}