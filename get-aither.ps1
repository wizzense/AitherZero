# AitherZero One-Liner Download Script - FIXED VERSION
# PowerShell 5.1+ Compatible - Can be executed via iex/Invoke-Expression
# 
# USAGE:
# iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither.ps1'))

param(
    [string]$InstallPath = $PWD.Path,
    [ValidateSet('minimal', 'standard', 'developer', 'full')]
    [string]$Profile = 'standard',
    [switch]$Silent,
    [switch]$Force
)

# Banner
function Show-Banner {
    Write-Host ""
    Write-Host "     _    _ _   _               ______                    " -ForegroundColor Cyan
    Write-Host "    / \  (_) |_| |__   ___ _ _|__  / ___ _ __ ___       " -ForegroundColor Cyan
    Write-Host "   / _ \ | | __| '_ \ / _ \ '__/ / / _ \ '__/ _ \      " -ForegroundColor Cyan
    Write-Host "  / ___ \| | |_| | | |  __/ | / /_|  __/ | | (_) |     " -ForegroundColor Cyan
    Write-Host " /_/   \_\_|\__|_| |_|\___|_|/____/\___|_|  \___/      " -ForegroundColor Cyan
    Write-Host ""
    Write-Host " Infrastructure Automation Framework" -ForegroundColor White
    Write-Host ""
}

# Configuration
$config = @{
    Owner = "wizzense"
    Repo = "AitherZero"
    Branch = "main"
}

# Test network connectivity
function Test-Network {
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "AitherZero-Installer")
        # Fixed: Added quotes around URL
        $null = $wc.DownloadString("https://api.github.com/repos/$($config.Owner)/$($config.Repo)")
        return $true
    } catch {
        return $false
    }
}

# Download function with retry
function Download-WithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxRetries = 3
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Write-Host "Downloading (Attempt $i/$MaxRetries)..." -ForegroundColor Yellow
            
            $wc = New-Object System.Net.WebClient
            $wc.Headers.Add("User-Agent", "AitherZero-Installer")
            $wc.DownloadFile($Url, $OutFile)
            
            if (Test-Path $OutFile) {
                $fileSize = (Get-Item $OutFile).Length
                if ($fileSize -gt 0) {
                    Write-Host "Download successful ($fileSize bytes)" -ForegroundColor Green
                    return $true
                }
            }
        }
        catch {
            Write-Host "Download attempt $i failed: $_" -ForegroundColor Red
            if ($i -lt $MaxRetries) {
                Write-Host "Retrying in 2 seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
    return $false
}

# Main installation function
function Install-AitherZero {
    Show-Banner
    
    Write-Host "Installation Path: $InstallPath" -ForegroundColor Cyan
    Write-Host "Profile: $Profile" -ForegroundColor Cyan
    Write-Host ""
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5 -or 
        ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
        Write-Host "ERROR: PowerShell 5.1 or higher is required" -ForegroundColor Red
        Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Red
        return
    }
    
    # Test network
    Write-Host "Testing network connectivity..." -ForegroundColor Yellow
    if (-not (Test-Network)) {
        Write-Host "ERROR: Cannot reach GitHub. Check your internet connection." -ForegroundColor Red
        return
    }
    Write-Host "Network check passed" -ForegroundColor Green
    
    # Prepare paths
    $tempDir = Join-Path $env:TEMP "AitherZero-Install-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $zipFile = Join-Path $tempDir "aitherzero.zip"
    $extractPath = Join-Path $tempDir "extract"
    $finalPath = Join-Path $InstallPath "AitherZero"
    
    # Check if already exists
    if ((Test-Path $finalPath) -and -not $Force) {
        Write-Host "ERROR: AitherZero already exists at: $finalPath" -ForegroundColor Red
        Write-Host "Use -Force to overwrite or choose a different location" -ForegroundColor Yellow
        return
    }
    
    # Create temp directory
    Write-Host "Creating temporary directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # Download
    $downloadUrl = "https://github.com/$($config.Owner)/$($config.Repo)/archive/refs/heads/$($config.Branch).zip"
    
    if (-not (Download-WithRetry -Url $downloadUrl -OutFile $zipFile)) {
        Write-Host "ERROR: Failed to download AitherZero after multiple attempts" -ForegroundColor Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }
    
    # Extract
    Write-Host "Extracting files..." -ForegroundColor Yellow
    try {
        # Create extraction directory
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        
        # Use built-in extraction for PowerShell 5.1+
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractPath)
        
        Write-Host "Extraction successful" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to extract files: $_" -ForegroundColor Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }
    
    # Find extracted folder
    $extractedFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
    if (-not $extractedFolder) {
        Write-Host "ERROR: No extracted folder found" -ForegroundColor Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }
    
    # Move to final location
    Write-Host "Installing to: $finalPath" -ForegroundColor Yellow
    try {
        if (Test-Path $finalPath) {
            if ($Force) {
                Write-Host "Removing existing installation..." -ForegroundColor Yellow
                Remove-Item -Path $finalPath -Recurse -Force
            }
        }
        
        # Ensure parent directory exists
        $parentPath = Split-Path -Parent $finalPath
        if (-not (Test-Path $parentPath)) {
            New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
        }
        
        Move-Item -Path $extractedFolder.FullName -Destination $finalPath -Force
        Write-Host "Installation successful" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to move files: $_" -ForegroundColor Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }
    
    # Cleanup
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    # Run quick setup
    Write-Host ""
    Write-Host "Running quick setup..." -ForegroundColor Cyan
    
    $setupScript = Join-Path $finalPath "quick-setup-simple.ps1"
    if (Test-Path $setupScript) {
        try {
            Set-Location $finalPath
            & $setupScript -Profile $Profile -Silent:$Silent
        }
        catch {
            Write-Host "WARNING: Quick setup encountered an error: $_" -ForegroundColor Yellow
            Write-Host "You can run setup manually later" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Quick setup script not found, skipping..." -ForegroundColor Yellow
    }
    
    # Final message
    Write-Host ""
    Write-Host "===================================" -ForegroundColor Green
    Write-Host " AitherZero Installation Complete! " -ForegroundColor Green
    Write-Host "===================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation location: $finalPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To get started:" -ForegroundColor Yellow
    Write-Host "  cd AitherZero" -ForegroundColor White
    Write-Host "  .\Start-AitherZero.ps1" -ForegroundColor White
    Write-Host ""
    
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Write-Host "NOTE: You're using PowerShell 5.1" -ForegroundColor Yellow
        Write-Host "For the best experience, consider upgrading to PowerShell 7+" -ForegroundColor Yellow
        Write-Host "Download from: https://aka.ms/powershell" -ForegroundColor Yellow
    }
}

# Execute installation
Install-AitherZero