# AitherZero Bootstrap Script v2.1 - PowerShell 5.1+ Compatible
# Usage: iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
# 
# Environment Variables for Automation:
# $env:AITHER_BOOTSTRAP_MODE = 'update'|'clean'|'new'|'remove'|'cancel'
# $env:AITHER_PROFILE = 'minimal'|'standard'|'development'
# $env:AITHER_INSTALL_DIR = 'custom/path' (default: ./AitherZero)
#
# New in v2.1:
# - Installs to subdirectory by default (./AitherZero) for easier cleanup
# - Added 'remove' option to completely uninstall AitherZero
# - Better error handling and auto-start with quick-setup.ps1

# Enable TLS 1.2 for older systems
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Simple error handling
$ErrorActionPreference = 'Stop'

# Helper function for network requests with retry
function Invoke-WebRequestWithRetry {
    param(
        [string]$Uri,
        [string]$OutFile,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 2
    )
    
    $attempt = 0
    while ($attempt -lt $MaxRetries) {
        $attempt++
        try {
            if ($OutFile) {
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 30
                } else {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($Uri, (Join-Path $PWD $OutFile))
                    $webClient.Dispose()
                }
            } else {
                return Invoke-RestMethod -Uri $Uri -UseBasicParsing -TimeoutSec 30
            }
            return $true
        } catch {
            if ($attempt -lt $MaxRetries) {
                Write-Host "[!] Network error (attempt $attempt/$MaxRetries): $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "[~] Retrying in $RetryDelay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelay
            } else {
                throw
            }
        }
    }
}

try {
    # Check if AitherZero already exists
    $aither_files = @('Start-AitherZero.ps1', 'aither-core')
    $existing_found = $false
    foreach ($file in $aither_files) {
        if (Test-Path $file) {
            $existing_found = $true
            break
        }
    }
    
    if ($existing_found) {
        # Check for non-interactive mode
        $mode = $env:AITHER_BOOTSTRAP_MODE
        if ($mode) {
            Write-Host "[i] Non-interactive mode: $mode" -ForegroundColor Cyan
            $choice = switch ($mode.ToLower()) {
                'update' { 'U' }
                'clean' { 'C' }
                'new' { 'N' }
                'remove' { 'R' }
                'cancel' { 'X' }
                default { 'U' }
            }
        } else {
            Write-Host "[!] AitherZero files detected in current directory" -ForegroundColor Yellow
            Write-Host "Choose an option:" -ForegroundColor Cyan
            Write-Host "  [U] Update existing installation (default)" -ForegroundColor White
            Write-Host "  [C] Clean install (remove existing files)" -ForegroundColor White
            Write-Host "  [N] Install to new subdirectory" -ForegroundColor White
            Write-Host "  [R] Remove AitherZero completely" -ForegroundColor Red
            Write-Host "  [X] Cancel installation" -ForegroundColor White
            
            $choice = Read-Host "Enter your choice (U/C/N/R/X)"
            if (-not $choice) { $choice = 'U' }
        }
        
        switch ($choice.ToUpper()) {
            'C' {
                Write-Host "[~] Cleaning existing installation..." -ForegroundColor Yellow
                $cleanup_items = @('Start-AitherZero.ps1', 'aither-core', 'aither.ps1', 
                                 'aither.bat', 'configs', 
                                 'opentofu', 'scripts', 'tests', 'build', 'docs')
                foreach ($item in $cleanup_items) {
                    if (Test-Path $item) {
                        Remove-Item $item -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            'N' {
                $subdir = "AitherZero-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Write-Host "[~] Creating new directory: $subdir" -ForegroundColor Cyan
                New-Item -ItemType Directory -Force -Path $subdir | Out-Null
                Set-Location $subdir
            }
            'R' {
                Write-Host "[~] Removing AitherZero installation..." -ForegroundColor Red
                $cleanup_items = @('Start-AitherZero.ps1', 'aither-core', 'aither.ps1', 
                                 'aither.bat', 'configs', 
                                 'opentofu', 'scripts', 'tests', 'build', 'docs',
                                 'LICENSE', 'README.md', 'VERSION', 'CHANGELOG.md',
                                 '.vscode', '.github', 'dist', 'logs', 'backups',
                                 'temp', 'bootstrap.ps1')
                
                $removedCount = 0
                foreach ($item in $cleanup_items) {
                    if (Test-Path $item) {
                        try {
                            Remove-Item $item -Recurse -Force -ErrorAction Stop
                            $removedCount++
                            Write-Host "  [-] Removed: $item" -ForegroundColor Gray
                        } catch {
                            Write-Host "  [!] Failed to remove: $item - $_" -ForegroundColor Yellow
                        }
                    }
                }
                
                Write-Host "[+] Removed $removedCount items" -ForegroundColor Green
                Write-Host "[i] AitherZero has been removed from this directory" -ForegroundColor Cyan
                exit 0
            }
            'X' {
                Write-Host "[!] Installation cancelled" -ForegroundColor Red
                exit 0
            }
            'U' {
                Write-Host "[~] Updating existing installation..." -ForegroundColor Cyan
            }
            default {
                Write-Host "[~] Updating existing installation..." -ForegroundColor Cyan
            }
        }
    } else {
        # No existing installation found - create a subdirectory by default
        $installDir = "AitherZero"
        if ($env:AITHER_INSTALL_DIR) {
            $installDir = $env:AITHER_INSTALL_DIR
        }
        
        # Check if running as admin and in system directory
        $currentPath = Get-Location
        $systemPaths = @('C:\Windows', 'C:\Program Files', 'C:\Program Files (x86)')
        $inSystemPath = $false
        foreach ($sysPath in $systemPaths) {
            if ($currentPath.Path.StartsWith($sysPath)) {
                $inSystemPath = $true
                break
            }
        }
        
        if ($inSystemPath) {
            # Running as admin in system directory - install to user directory instead
            $userPath = [Environment]::GetFolderPath('UserProfile')
            $installDir = Join-Path $userPath $installDir
            Write-Host "[!] Running from system directory. Installing to: $installDir" -ForegroundColor Yellow
        }
        
        Write-Host "[~] Creating installation directory: $installDir" -ForegroundColor Cyan
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Force -Path $installDir | Out-Null
        }
        Set-Location $installDir
    }
    
    # Determine profile
    $profile = $env:AITHER_PROFILE
    if (-not $profile) {
        if (-not $env:AITHER_BOOTSTRAP_MODE) {
            Write-Host ""
            Write-Host "Select AitherZero Profile:" -ForegroundColor Cyan
            Write-Host "  [1] Minimal (5-8 MB) - Core infrastructure deployment only" -ForegroundColor White
            Write-Host "  [2] Developer (15-25 MB) - Development environment (recommended)" -ForegroundColor Green
            Write-Host "  [3] Full (35-50 MB) - Complete enterprise environment" -ForegroundColor White
            Write-Host ""
            
            do {
                $profileChoice = Read-Host "Enter your choice (1/2/3) [default: 2]"
                if (-not $profileChoice) { $profileChoice = '2' }
            } while ($profileChoice -notmatch '^[123]$')
            
            $profile = switch ($profileChoice) {
                '1' { 'minimal' }
                '2' { 'developer' }
                '3' { 'full' }
            }
        } else {
            # Non-interactive mode defaults to developer
            $profile = 'developer'
        }
    }
    
    Write-Host ">> Downloading AitherZero ($profile profile)..." -ForegroundColor Cyan
    
    # Get latest Windows release with retry logic
    $apiUrl = "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
    try {
        Write-Host "[~] Checking for latest release..." -ForegroundColor Yellow
        $release = Invoke-WebRequestWithRetry -Uri $apiUrl
    } catch {
        Write-Host "[!] Failed to connect to GitHub API" -ForegroundColor Red
        Write-Host "[i] Please check your internet connection and try again" -ForegroundColor Yellow
        Write-Host "[i] Error: $($_.Exception.Message)" -ForegroundColor Gray
        exit 1
    }
    
    # Find Windows ZIP file for the selected profile
    $windowsAsset = $null
    # Map bootstrap profile names to build profile names
    $buildProfile = switch ($profile) {
        'minimal' { 'minimal' }
        'developer' { 'standard' }  # Build uses 'standard' for developer profile
        'full' { 'development' }  # Build uses 'development' for full profile
        default { 'standard' }
    }
    $profilePattern = "aitherzero-$buildProfile-windows-.*\.zip$"
    
    foreach ($asset in $release.assets) {
        if ($asset.name -match $profilePattern) {
            $windowsAsset = $asset
            break
        }
    }
    
    # Fallback to any Windows package if specific profile not found
    if (-not $windowsAsset) {
        Write-Host "[!] Specific profile '$buildProfile' not found, looking for any Windows package..." -ForegroundColor Yellow
        foreach ($asset in $release.assets) {
            if ($asset.name -match "aitherzero.*windows.*\.zip$") {
                $windowsAsset = $asset
                Write-Host "[i] Found alternative package: $($asset.name)" -ForegroundColor Cyan
                break
            }
        }
    }
    
    if (-not $windowsAsset) {
        throw "No Windows release found"
    }
    
    Write-Host "[*] Found release: $($windowsAsset.name)" -ForegroundColor Green
    
    # Download with retry logic
    $zipFile = "AitherZero.zip"
    Write-Host "[-] Downloading $($windowsAsset.name)..." -ForegroundColor Yellow
    
    try {
        Invoke-WebRequestWithRetry -Uri $windowsAsset.browser_download_url -OutFile $zipFile
    } catch {
        Write-Host "[!] Download failed after multiple attempts" -ForegroundColor Red
        Write-Host "[i] Error: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host "[i] You can manually download from: $($windowsAsset.browser_download_url)" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "[~] Extracting..." -ForegroundColor Yellow
    
    # Create temp directory
    $tempDir = "AitherZero-temp-$(Get-Random)"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    # Extract based on PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
    } else {
        # PS 5.1 compatible extraction
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $PWD $zipFile), (Join-Path $PWD $tempDir))
    }
    
    # Clean up ZIP
    Remove-Item $zipFile -Force
    
    # Find extracted content
    $extractedItems = Get-ChildItem -Path $tempDir
    
    # If there's a single directory, move its contents
    if ($extractedItems.Count -eq 1 -and $extractedItems[0].PSIsContainer) {
        $innerDir = $extractedItems[0]
        $sourceItems = Get-ChildItem -Path $innerDir.FullName -Force
    } else {
        # Use all items from temp dir
        $sourceItems = Get-ChildItem -Path $tempDir -Force
    }
    
    # Copy files with better error handling
    foreach ($item in $sourceItems) {
        $destPath = Join-Path $PWD $item.Name
        
        try {
            if (Test-Path $destPath) {
                # Try to remove existing item
                Remove-Item $destPath -Recurse -Force -ErrorAction Stop
            }
            
            # Copy instead of move for better reliability
            if ($item.PSIsContainer) {
                Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force
            } else {
                Copy-Item -Path $item.FullName -Destination $destPath -Force
            }
        } catch {
            # If removal fails, try to overwrite
            try {
                if ($item.PSIsContainer) {
                    # For directories, remove and recreate
                    if (Test-Path $destPath) {
                        # Try renaming old directory first
                        $backupPath = "$destPath.old"
                        if (Test-Path $backupPath) {
                            Remove-Item $backupPath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                        Rename-Item -Path $destPath -NewName "$($item.Name).old" -Force -ErrorAction SilentlyContinue
                    }
                    Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force
                } else {
                    Copy-Item -Path $item.FullName -Destination $destPath -Force
                }
            } catch {
                Write-Host "[!] Warning: Could not update $($item.Name): $_" -ForegroundColor Yellow
            }
        }
    }
    
    # Clean up temp directory
    Remove-Item $tempDir -Recurse -Force
    
    Write-Host "[+] Extracted to: $PWD" -ForegroundColor Green
    Write-Host "[i] Profile: $profile" -ForegroundColor Cyan
    Write-Host "[i] To remove later, delete the AitherZero folder or run bootstrap.ps1 again and select Remove" -ForegroundColor Gray
    
    # Auto-start
    Write-Host ">> Starting AitherZero ($profile profile)..." -ForegroundColor Cyan
    
    # Ensure we're in the correct directory for the application
    $extractionPath = Get-Location
    Write-Host "[~] Working directory: $extractionPath" -ForegroundColor Yellow
    
    # Determine which script to run
    $startScript = $null
    if (Test-Path ".\Start-AitherZero.ps1") {
        # Use main launcher
        $startScript = ".\Start-AitherZero.ps1"
        # Add -Setup parameter for first-time installation
        $startParams = @{Setup = $true; InstallationProfile = $profile}
    }
    
    if ($startScript) {
        # Set working directory and start with explicit path
        Push-Location $extractionPath
        try {
            Write-Host "[~] Starting from: $(Get-Location)" -ForegroundColor Yellow
            
            # Check PowerShell version
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                Write-Host "[!] PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) detected" -ForegroundColor Yellow
                Write-Host "[i] AitherZero requires PowerShell 7.0 or later for full functionality" -ForegroundColor Cyan
                Write-Host "[i] The setup wizard will help install PowerShell 7 if needed" -ForegroundColor Cyan
            }
            
            # Check execution policy first
            $executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
            if ($executionPolicy -eq 'Restricted') {
                Write-Host "[!] PowerShell execution policy is restricted" -ForegroundColor Yellow
                Write-Host "[i] To enable scripts, run as Administrator:" -ForegroundColor Cyan
                Write-Host "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
                Write-Host "[i] Or run AitherZero with:" -ForegroundColor Cyan
                Write-Host "    powershell.exe -ExecutionPolicy Bypass -File .\Start-AitherZero.ps1 -Setup" -ForegroundColor White
            } else {
                & $startScript @startParams
            }
        } catch {
            $errorMessage = $_.Exception.Message
            if ($errorMessage -like '*running scripts is disabled*') {
                Write-Host "[!] PowerShell execution policy prevents running scripts" -ForegroundColor Red
                Write-Host "[i] To fix this, run PowerShell as Administrator and execute:" -ForegroundColor Cyan
                Write-Host "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
                Write-Host "[i] Or for this session only:" -ForegroundColor Cyan
                Write-Host "    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process" -ForegroundColor White
            } else {
                Write-Host "[!] Failed to auto-start AitherZero: $errorMessage" -ForegroundColor Yellow
            }
            Write-Host "[+] AitherZero is ready! Run the following to start:" -ForegroundColor Green
            Write-Host "    .\Start-AitherZero.ps1 -Setup" -ForegroundColor White
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "[!] Start-AitherZero.ps1 not found in extraction directory" -ForegroundColor Yellow
        Write-Host "[~] Contents of current directory:" -ForegroundColor Yellow
        Get-ChildItem -Name | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Write-Host "[i] Please navigate to the AitherZero directory and run .\Start-AitherZero.ps1" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "[!] Installation failed: $_" -ForegroundColor Red
    Write-Host "[i] Try manual download from: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Yellow
    exit 1
}