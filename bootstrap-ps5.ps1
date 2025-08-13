# Bootstrap script specifically for PowerShell 5.1 on Windows
# This handles the PS5.1 -> PS7 transition more gracefully

<#
.SYNOPSIS
    PowerShell 5.1 Bootstrap Wrapper for AitherZero
.DESCRIPTION
    Handles installation and upgrade from PowerShell 5.1 to PowerShell 7
.EXAMPLE
    # One-liner for PowerShell 5.1
    iwr -useb https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap-ps5.ps1 | iex
#>

param(
    [string]$InstallProfile = 'Standard',
    [string]$Branch = 'main',
    [switch]$NonInteractive = ($env:CI -eq 'true')
)

$ErrorActionPreference = 'Stop'

# Enable TLS 1.2 for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host @"

    ___   _ _   _               ____                
   / _ \ (_) |_| |__   ___ _ __|_  /___ _ __ ___   
  / /_\ \| | __| '_ \ / _ \ '__/ // _ \ '__/ _ \  
 / /_\\  \| | |_| | | |  __/ | / /|  __/ | | (_) | 
 \____/  |_|\__|_| |_|\___|_|/____\___|_|  \___/  
                                                    
    PowerShell 5.1 Bootstrap Installer
    =====================================
"@ -ForegroundColor Cyan

# Check PowerShell version
Write-Host "[*] Current PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow

if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Host "[+] PowerShell 7+ detected. Running main bootstrap..." -ForegroundColor Green
    
    # Already on PS7, just run the main bootstrap
    $bootstrapUrl = "https://raw.githubusercontent.com/wizzense/AitherZero/$Branch/bootstrap.ps1"
    $bootstrapScript = Invoke-WebRequest -Uri $bootstrapUrl -UseBasicParsing
    
    # Execute with original parameters
    $scriptBlock = [scriptblock]::Create($bootstrapScript.Content)
    & $scriptBlock -InstallProfile $InstallProfile -Branch $Branch -NonInteractive:$NonInteractive
    exit $LASTEXITCODE
}

Write-Host "[!] PowerShell 5.1 detected. Checking for PowerShell 7..." -ForegroundColor Yellow

# Check if PowerShell 7 is already installed
$pwshPath = $null
$possiblePaths = @(
    "$env:ProgramFiles\PowerShell\7\pwsh.exe",
    "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe",
    "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe",
    "$env:LOCALAPPDATA\Microsoft\PowerShell\pwsh.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $pwshPath = $path
        Write-Host "[+] Found PowerShell 7 at: $pwshPath" -ForegroundColor Green
        break
    }
}

# Check in PATH
if (-not $pwshPath) {
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwshCmd) {
        $pwshPath = $pwshCmd.Source
        Write-Host "[+] Found PowerShell 7 in PATH: $pwshPath" -ForegroundColor Green
    }
}

# Install PowerShell 7 if not found
if (-not $pwshPath) {
    Write-Host "[!] PowerShell 7 not found. Installing..." -ForegroundColor Yellow
    
    # Check for winget first (faster and cleaner)
    $hasWinget = Get-Command winget -ErrorAction SilentlyContinue
    
    if ($hasWinget) {
        Write-Host "[*] Installing PowerShell 7 via winget..." -ForegroundColor Cyan
        
        try {
            # Accept source agreements silently
            winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements --silent
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[+] PowerShell 7 installed successfully via winget!" -ForegroundColor Green
                
                # Find the installed path
                foreach ($path in $possiblePaths) {
                    if (Test-Path $path) {
                        $pwshPath = $path
                        break
                    }
                }
            } else {
                throw "Winget install failed with exit code: $LASTEXITCODE"
            }
        } catch {
            Write-Host "[!] Winget install failed: $_" -ForegroundColor Yellow
            Write-Host "[*] Falling back to MSI installer..." -ForegroundColor Yellow
        }
    }
    
    # Fallback to MSI installer
    if (-not $pwshPath) {
        Write-Host "[*] Downloading PowerShell 7 MSI installer..." -ForegroundColor Cyan
        
        $msiUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7-win-x64.msi"
        $msiPath = Join-Path $env:TEMP "PowerShell-7-win-x64.msi"
        
        try {
            # Download with progress
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($msiUrl, $msiPath)
            
            Write-Host "[*] Installing PowerShell 7..." -ForegroundColor Cyan
            
            # Check if running as admin
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            
            if ($isAdmin) {
                # Install silently
                $arguments = "/i `"$msiPath`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1"
                Start-Process msiexec.exe -ArgumentList $arguments -Wait -NoNewWindow
            } else {
                # Request elevation
                Write-Host "[!] Administrator privileges required for installation." -ForegroundColor Yellow
                
                if (-not $NonInteractive) {
                    $response = Read-Host "Elevate to administrator? (Y/n)"
                    if ($response -ne 'n') {
                        $arguments = "/i `"$msiPath`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1"
                        Start-Process msiexec.exe -ArgumentList $arguments -Verb RunAs -Wait
                    } else {
                        Write-Host "[-] Installation cancelled. Please run as administrator." -ForegroundColor Red
                        exit 1
                    }
                } else {
                    Write-Host "[-] Cannot install without admin rights in non-interactive mode." -ForegroundColor Red
                    exit 1
                }
            }
            
            # Clean up
            Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            
            Write-Host "[+] PowerShell 7 installed successfully!" -ForegroundColor Green
            
            # Find the installed path
            foreach ($path in $possiblePaths) {
                if (Test-Path $path) {
                    $pwshPath = $path
                    break
                }
            }
            
        } catch {
            Write-Host "[-] Failed to install PowerShell 7: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# Verify PowerShell 7 is available
if (-not $pwshPath -or -not (Test-Path $pwshPath)) {
    Write-Host "[-] PowerShell 7 installation completed but executable not found." -ForegroundColor Red
    Write-Host "[!] Please restart your terminal and run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "[+] PowerShell 7 is available at: $pwshPath" -ForegroundColor Green

# Download and run the main bootstrap script in PowerShell 7
Write-Host "[*] Launching AitherZero bootstrap in PowerShell 7..." -ForegroundColor Cyan

# Download the main bootstrap script
$bootstrapUrl = "https://raw.githubusercontent.com/wizzense/AitherZero/$Branch/bootstrap.ps1"
$localBootstrap = Join-Path $env:TEMP "aitherzero-bootstrap.ps1"

try {
    Write-Host "[*] Downloading bootstrap script..." -ForegroundColor White
    Invoke-WebRequest -Uri $bootstrapUrl -OutFile $localBootstrap -UseBasicParsing
    
    # Build arguments
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$localBootstrap`"",
        "-InstallProfile", $InstallProfile,
        "-Branch", $Branch
    )
    
    if ($NonInteractive) {
        $arguments += "-NonInteractive"
    }
    
    Write-Host "[*] Starting PowerShell 7 with bootstrap..." -ForegroundColor Cyan
    Write-Host "[*] Command: $pwshPath $($arguments -join ' ')" -ForegroundColor Gray
    
    # Launch PowerShell 7 with the bootstrap script
    $process = Start-Process -FilePath $pwshPath -ArgumentList $arguments -PassThru -NoNewWindow -Wait
    
    # Clean up
    Remove-Item $localBootstrap -Force -ErrorAction SilentlyContinue
    
    if ($process.ExitCode -eq 0) {
        Write-Host "[+] Bootstrap completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Close this PowerShell 5.1 window" -ForegroundColor White
        Write-Host "  2. Open PowerShell 7 (pwsh)" -ForegroundColor White
        Write-Host "  3. Navigate to your AitherZero directory" -ForegroundColor White
        Write-Host "  4. Run: ./Start-AitherZero.ps1" -ForegroundColor White
    } else {
        Write-Host "[-] Bootstrap failed with exit code: $($process.ExitCode)" -ForegroundColor Red
    }
    
    exit $process.ExitCode
    
} catch {
    Write-Host "[-] Failed to run bootstrap: $_" -ForegroundColor Red
    
    # Clean up on error
    if (Test-Path $localBootstrap) {
        Remove-Item $localBootstrap -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}