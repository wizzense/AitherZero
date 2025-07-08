# AitherZero Bootstrap Script v2.1 - PowerShell 5.1+ Compatible
# Usage: iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
#
# Environment Variables for Automation:
# $env:AITHER_BOOTSTRAP_MODE = 'update'|'clean'|'new'|'remove'|'cancel'
# $env:AITHER_PROFILE = 'minimal'|'standard'|'development'
# $env:AITHER_INSTALL_DIR = 'custom/path' (default: ./AitherZero)
# $env:AITHER_AUTO_INSTALL_PS7 = 'true' (auto-install PowerShell 7 if needed)
# $env:AITHER_NON_INTERACTIVE = 'true' (run in non-interactive mode)
# $env:AITHER_NO_AUTOSTART = 'true' (skip auto-start after installation)
#
# New in v2.1:
# - Installs to subdirectory by default (./AitherZero) for easier cleanup
# - Added 'remove' option to completely uninstall AitherZero
# - Better error handling and auto-start with quick-setup.ps1

# Enable TLS 1.2 for older systems
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Simple error handling
$ErrorActionPreference = 'Stop'

# Helper function for proper exit with pause on error
function Exit-Bootstrap {
    param(
        [int]$ExitCode = 1,
        [string]$Message
    )

    if ($Message) {
        Write-Host $Message -ForegroundColor $(if ($ExitCode -eq 0) { 'Green' } else { 'Red' })
    }

    # If running interactively and not in CI, pause before exit on error
    if ($ExitCode -ne 0 -and -not $env:CI -and -not $env:AITHER_BOOTSTRAP_MODE -and -not [System.Console]::IsInputRedirected) {
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    # Clean up temp files
    if ($env:AITHER_TEMP_BOOTSTRAP -and (Test-Path $env:AITHER_TEMP_BOOTSTRAP)) {
        Remove-Item $env:AITHER_TEMP_BOOTSTRAP -Force -ErrorAction SilentlyContinue
        Remove-Item env:AITHER_TEMP_BOOTSTRAP -ErrorAction SilentlyContinue
    }

    exit $ExitCode
}

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
                    $fullPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $PWD $OutFile }
                    $webClient.DownloadFile($Uri, $fullPath)
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

# Helper function to install PowerShell 7 - PORTABLE-FIRST (NO UAC REQUIRED)
function Install-PowerShell7-Portable {
    param(
        [switch]$Force,
        [switch]$NonInteractive
    )

    Write-Host "[~] Checking for PowerShell 7..." -ForegroundColor Yellow

    # Get the latest PowerShell release info once
    $ps7Release = $null
    try {
        $ps7ApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $ps7Release = Invoke-RestMethod -Uri $ps7ApiUrl -UseBasicParsing -TimeoutSec 30
    } catch {
        Write-Host "[!] Warning: Could not fetch latest PowerShell release info, using fallback" -ForegroundColor Yellow
    }

    # Define platform-specific paths - check existing installations first
    $isWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5
    
    if ($isWindows) {
        $possiblePaths = @(
            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe",  # Portable (preferred)
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",           # System install
            "$env:ProgramFiles\PowerShell\7.5.2\pwsh.exe",      # Version-specific
            "$env:ProgramFiles\PowerShell\7.4.1\pwsh.exe"       # Version-specific
        )
        $portableDir = "$env:LOCALAPPDATA\Microsoft\PowerShell\7"
        # Get the actual download URL from GitHub API
        if ($ps7Release) {
            $ps7Asset = $ps7Release.assets | Where-Object { $_.name -match "PowerShell-.*-win-x64\.zip$" } | Select-Object -First 1
            if ($ps7Asset) {
                $zipUrl = $ps7Asset.browser_download_url
            } else {
                # Fallback to manual construction if asset not found
                $zipUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$($ps7Release.tag_name.TrimStart('v'))/PowerShell-$($ps7Release.tag_name.TrimStart('v'))-win-x64.zip"
            }
        } else {
            # Ultimate fallback - use a known working version
            $zipUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/PowerShell-7.5.2-win-x64.zip"
        }
    } elseif ($IsMacOS) {
        $possiblePaths = @(
            "$HOME/.local/share/powershell/pwsh",               # Portable (preferred)
            "/opt/homebrew/bin/pwsh",                          # Homebrew
            "/usr/local/bin/pwsh"                              # System install
        )
        $portableDir = "$HOME/.local/share/powershell"
        # Get the actual download URL from GitHub API
        if ($ps7Release) {
            $ps7Asset = $ps7Release.assets | Where-Object { $_.name -match "powershell-.*-osx-x64\.tar\.gz$" } | Select-Object -First 1
            if ($ps7Asset) {
                $zipUrl = $ps7Asset.browser_download_url
            } else {
                # Fallback to manual construction if asset not found
                $zipUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$($ps7Release.tag_name.TrimStart('v'))/powershell-$($ps7Release.tag_name.TrimStart('v'))-osx-x64.tar.gz"
            }
        } else {
            # Ultimate fallback - use a known working version
            $zipUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/powershell-7.5.2-osx-x64.tar.gz"
        }
    } else {
        $possiblePaths = @(
            "$HOME/.local/share/powershell/pwsh",               # Portable (preferred)
            "/usr/bin/pwsh"                                     # System install
        )
        $portableDir = "$HOME/.local/share/powershell"
        # Get the actual download URL from GitHub API
        if ($ps7Release) {
            $ps7Asset = $ps7Release.assets | Where-Object { $_.name -match "powershell-.*-linux-x64\.tar\.gz$" } | Select-Object -First 1
            if ($ps7Asset) {
                $zipUrl = $ps7Asset.browser_download_url
            } else {
                # Fallback to manual construction if asset not found
                $zipUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$($ps7Release.tag_name.TrimStart('v'))/powershell-$($ps7Release.tag_name.TrimStart('v'))-linux-x64.tar.gz"
            }
        } else {
            # Ultimate fallback - use a known working version
            $zipUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.5.2/powershell-7.5.2-linux-x64.tar.gz"
        }
    }

    # Check if PowerShell 7 is already available
    if (-not $Force) {
        foreach ($path in $possiblePaths) {
            if ($path -and (Test-Path $path)) {
                Write-Host "[+] PowerShell 7 found at: $path" -ForegroundColor Green
                # Add to PATH if not already there
                if ($isWindows) {
                    $pathDir = Split-Path $path
                    if ($env:PATH -notlike "*$pathDir*") {
                        $env:PATH = "$pathDir;$env:PATH"
                    }
                } else {
                    $pathDir = Split-Path $path
                    if ($env:PATH -notlike "*$pathDir*") {
                        $env:PATH = "$pathDir`:$env:PATH"
                    }
                }
                return $path
            }
        }

        # Also check if pwsh is in PATH
        $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwshCommand) {
            Write-Host "[+] PowerShell 7 found in PATH: $($pwshCommand.Source)" -ForegroundColor Green
            return $pwshCommand.Source
        }
    }

    # Install PowerShell 7 portable (NO ADMIN REQUIRED)
    Write-Host "[~] Installing PowerShell 7 (portable, no admin required)..." -ForegroundColor Cyan

    try {
        # Create installation directory
        if (Test-Path $portableDir) {
            Write-Host "[~] Cleaning existing installation..." -ForegroundColor Yellow
            Remove-Item $portableDir -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path $portableDir | Out-Null

        # Download PowerShell 7
        Write-Host "[~] Downloading PowerShell 7..." -ForegroundColor Yellow
        $tempFile = if ($isWindows) { 
            "$env:TEMP\PowerShell-portable.zip" 
        } else { 
            "/tmp/powershell-portable.tar.gz" 
        }

        Invoke-WebRequestWithRetry -Uri $zipUrl -OutFile $tempFile

        # Extract based on platform
        Write-Host "[~] Extracting to user directory..." -ForegroundColor Yellow
        if ($isWindows) {
            # Windows - extract ZIP
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                Expand-Archive -Path $tempFile -DestinationPath $portableDir -Force
            } else {
                # PowerShell 5.1 compatible extraction
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $portableDir)
            }
            $pwshExecutable = Join-Path $portableDir "pwsh.exe"
        } else {
            # Linux/macOS - extract TAR.GZ
            if ($IsMacOS) {
                & tar -xzf $tempFile -C $portableDir
            } else {
                & tar -xzf $tempFile -C $portableDir
            }
            $pwshExecutable = Join-Path $portableDir "pwsh"
            # Make executable
            & chmod +x $pwshExecutable
        }

        # Clean up download
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

        # Verify installation
        if (Test-Path $pwshExecutable) {
            Write-Host "[+] PowerShell 7 installed successfully!" -ForegroundColor Green
            Write-Host "[i] Installed to: $portableDir" -ForegroundColor Cyan

            # Add to PATH for current session
            $pathDir = Split-Path $pwshExecutable
            if ($isWindows) {
                if ($env:PATH -notlike "*$pathDir*") {
                    $env:PATH = "$pathDir;$env:PATH"
                }
            } else {
                if ($env:PATH -notlike "*$pathDir*") {
                    $env:PATH = "$pathDir`:$env:PATH"
                }
            }

            return $pwshExecutable
        } else {
            throw "PowerShell 7 extraction completed but executable not found"
        }

    } catch {
        Write-Host "[!] Portable installation failed: $_" -ForegroundColor Red
        Write-Host "[i] Please install PowerShell 7 manually from: https://aka.ms/powershell" -ForegroundColor Yellow
        throw "PowerShell 7 installation failed: $_"
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
    $profileType = $env:AITHER_PROFILE
    if (-not $profileType) {
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

            $profileType = switch ($profileChoice) {
                '1' { 'minimal' }
                '2' { 'developer' }
                '3' { 'full' }
            }
        } else {
            # Non-interactive mode defaults to developer
            $profileType = 'developer'
        }
    }

    Write-Host ">> Downloading AitherZero ($profileType profile)..." -ForegroundColor Cyan

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

    # Extract version from release tag with improved regex
    $releaseVersion = if ($release.tag_name -match '^v?([0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.-]+)?)$') {
        $matches[1]
    } elseif ($release.tag_name -match '^v?(.+)$') {
        # Fallback for other version formats
        $matches[1]
    } else {
        Write-Host "[!] Could not extract version from release tag: $($release.tag_name)" -ForegroundColor Yellow
        $release.tag_name
    }
    Write-Host "[i] Release version: $releaseVersion" -ForegroundColor Cyan

    # Find Windows ZIP file for the selected profile
    $windowsAsset = $null
    # Map bootstrap profile names to build profile names
    $buildProfile = switch ($profileType) {
        'minimal' { 'minimal' }
        'developer' { 'developer' }  # Use developer package which includes SetupWizard
        'full' { 'developer' }  # Build uses 'developer' for full profile
        default { 'standard' }
    }
    # Updated pattern to match versioned files: AitherZero-{version}-{profile}-windows.zip
    # Make pattern more flexible to handle variations
    $profilePattern = "AitherZero-.*?-?$buildProfile-windows\.zip$"

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
            # Updated pattern to match versioned files
            if ($asset.name -match "AitherZero-.*-windows\.zip$") {
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
        # Check if file already exists to avoid redundant downloads
        if (Test-Path $zipFile) {
            Write-Host "[i] Using existing download: $zipFile" -ForegroundColor Cyan
        } else {
            Invoke-WebRequestWithRetry -Uri $windowsAsset.browser_download_url -OutFile $zipFile
        }
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
    Write-Host "[i] Profile: $profileType" -ForegroundColor Cyan
    Write-Host "[i] To remove later, delete the AitherZero folder or run bootstrap.ps1 again and select Remove" -ForegroundColor Gray

    # Auto-start
    Write-Host ">> Starting AitherZero ($profileType profile)..." -ForegroundColor Cyan

    # Ensure we're in the correct directory for the application
    $extractionPath = Get-Location
    Write-Host "[~] Working directory: $extractionPath" -ForegroundColor Yellow

    # Determine which script to run
    $startScript = $null
    if (Test-Path ".\Start-AitherZero.ps1") {
        # Use main launcher
        $startScript = ".\Start-AitherZero.ps1"
        # Add -Setup parameter for first-time installation
        $startParams = @{Setup = $true; InstallationProfile = $profileType}

        # Add non-interactive mode if specified
        if ($env:AITHER_NON_INTERACTIVE -eq 'true' -or $env:AITHER_BOOTSTRAP_MODE) {
            $startParams['NonInteractive'] = $true
        }

        # Check if we should skip auto-start
        if ($env:AITHER_NO_AUTOSTART -eq 'true') {
            Write-Host "[i] Auto-start disabled. To start AitherZero manually, run:" -ForegroundColor Cyan
            Write-Host "    ./Start-AitherZero.ps1" -ForegroundColor White
            Exit-Bootstrap -ExitCode 0 -Message "[+] Installation completed successfully!"
        }
    }

    if ($startScript) {
        # Set working directory and start with explicit path
        Push-Location $extractionPath
        try {
            Write-Host "[~] Starting from: $(Get-Location)" -ForegroundColor Yellow

            # Check PowerShell version
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                Write-Host "[!] PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) detected" -ForegroundColor Yellow
                Write-Host "[i] AitherZero requires PowerShell 7.0 or later" -ForegroundColor Cyan

                # Check for non-interactive mode
                $installPS7 = $false
                if ($env:AITHER_AUTO_INSTALL_PS7 -eq 'true' -or $env:AITHER_BOOTSTRAP_MODE) {
                    Write-Host "[i] Non-interactive mode: Auto-installing PowerShell 7..." -ForegroundColor Cyan
                    $installPS7 = $true
                } else {
                    # Interactive prompt
                    Write-Host ""
                    Write-Host "[?] Would you like to install PowerShell 7 now? (Y/n)" -ForegroundColor Yellow
                    $response = Read-Host
                    if (-not $response -or $response -match '^[Yy]') {
                        $installPS7 = $true
                    }
                }

                if ($installPS7) {
                    Write-Host "[~] Installing PowerShell 7..." -ForegroundColor Cyan
                    try {
                        $pwsh7Path = Install-PowerShell7-Portable -NonInteractive:($env:AITHER_BOOTSTRAP_MODE -ne $null)

                        if ($pwsh7Path -and (Test-Path $pwsh7Path)) {
                            Write-Host "[+] PowerShell 7 ready!" -ForegroundColor Green
                            Write-Host "[~] Continuing installation with PowerShell 7..." -ForegroundColor Cyan
                            
                            # No complex relaunch - just continue with PS7 available in PATH
                            # PS7 is now available via $pwsh7Path or in $env:PATH
                            
                        } else {
                            throw "PowerShell 7 installation completed but executable not found"
                        }
                    } catch {
                        Write-Host "[!] Failed to install PowerShell 7: $_" -ForegroundColor Red
                        Write-Host "[i] Please install manually from: https://aka.ms/powershell" -ForegroundColor Yellow
                        Write-Host "[i] Then run this bootstrap script again" -ForegroundColor Yellow

                        # In non-interactive mode, exit with error
                        if ($env:AITHER_BOOTSTRAP_MODE) {
                            Exit-Bootstrap -ExitCode 1 -Message "[!] PowerShell 7 installation failed in non-interactive mode"
                        }

                        # In interactive mode, allow continuing with PS 5.1
                        Write-Host ""
                        Write-Host "[?] Continue with limited functionality? (y/N)" -ForegroundColor Yellow
                        $continueResponse = Read-Host
                        if ($continueResponse -notmatch '^[Yy]') {
                            Exit-Bootstrap -ExitCode 1 -Message "[!] Installation cancelled by user"
                        }
                    }
                } else {
                    Write-Host "[!] PowerShell 7 is required. Please install from: https://aka.ms/powershell" -ForegroundColor Red
                    Write-Host "[i] Then run this bootstrap script again" -ForegroundColor Yellow
                    Exit-Bootstrap -ExitCode 1 -Message "[!] PowerShell 7 installation declined"
                }
            }

            # PowerShell 7 is now available if it was installed

            # Use PowerShell 7 if we're in PS 5.1 and PS7 was found/installed
            $usePwsh7 = $false
            $pwsh7Executable = $null
            
            # Check if we should use PowerShell 7 (use the result from Install-PowerShell7-Portable)
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                # First, try to use the PS7 path from the installation/detection above
                if ($pwsh7Path -and (Test-Path $pwsh7Path)) {
                    $pwsh7Executable = $pwsh7Path
                    $usePwsh7 = $true
                    Write-Host "[i] Using PowerShell 7 from: $pwsh7Path" -ForegroundColor Cyan
                } else {
                    # Fallback: try to find PowerShell 7 in common locations
                    $pwsh7Candidates = @(
                        "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe",
                        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                        "$env:ProgramFiles\PowerShell\7.5.2\pwsh.exe",
                        "$env:ProgramFiles\PowerShell\7.4.1\pwsh.exe"
                    )
                    
                    foreach ($candidate in $pwsh7Candidates) {
                        if (Test-Path $candidate) {
                            $pwsh7Executable = $candidate
                            $usePwsh7 = $true
                            Write-Host "[i] Found PowerShell 7 at: $candidate" -ForegroundColor Cyan
                            break
                        }
                    }
                    
                    # Also check PATH
                    if (-not $pwsh7Executable) {
                        $pwshInPath = Get-Command pwsh -ErrorAction SilentlyContinue
                        if ($pwshInPath) {
                            $pwsh7Executable = $pwshInPath.Source
                            $usePwsh7 = $true
                            Write-Host "[i] Found PowerShell 7 in PATH: $($pwshInPath.Source)" -ForegroundColor Cyan
                        }
                    }
                }
            }
            
            # Execute the start script
            try {
                if ($usePwsh7 -and $pwsh7Executable) {
                    Write-Host "[~] Launching AitherZero with PowerShell 7..." -ForegroundColor Cyan
                    # Convert parameters to argument string
                    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$startScript`"")
                    if ($startParams.Setup) { $argList += "-Setup" }
                    if ($startParams.InstallationProfile) { $argList += "-InstallationProfile"; $argList += $startParams.InstallationProfile }
                    if ($startParams.NonInteractive) { $argList += "-NonInteractive" }
                    
                    & $pwsh7Executable @argList
                } else {
                    # Use current PowerShell version
                    & $startScript @startParams
                }
            } catch {
                if ($_.Exception.Message -like '*running scripts is disabled*' -or $_.Exception.Message -like '*execution policy*') {
                    Write-Host "[!] PowerShell execution policy prevents running scripts" -ForegroundColor Red
                    Write-Host "[i] To enable scripts, run as Administrator:" -ForegroundColor Cyan
                    Write-Host "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
                    Write-Host "[i] Or run AitherZero with:" -ForegroundColor Cyan
                    if ($usePwsh7 -and $pwsh7Executable) {
                        Write-Host "    `"$pwsh7Executable`" -ExecutionPolicy Bypass -File `"$startScript`" -Setup" -ForegroundColor White
                    } else {
                        Write-Host "    powershell.exe -ExecutionPolicy Bypass -File .\Start-AitherZero.ps1 -Setup" -ForegroundColor White
                    }
                } elseif ($_.Exception.Message -like '*#requires*') {
                    Write-Host "[!] Script requires PowerShell 7 but PowerShell 5.1 is being used" -ForegroundColor Red
                    Write-Host "[i] To run AitherZero, use PowerShell 7:" -ForegroundColor Cyan
                    if ($pwsh7Executable) {
                        Write-Host "    `"$pwsh7Executable`" -File `"$startScript`" -Setup" -ForegroundColor White
                    } else {
                        Write-Host "    Install PowerShell 7 from: https://aka.ms/powershell" -ForegroundColor White
                    }
                } else {
                    # Rethrow if it's a different error
                    throw
                }
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
    Exit-Bootstrap -ExitCode 1 -Message "[!] Bootstrap failed: $_"
}
