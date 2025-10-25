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

# Helper function to install PowerShell 7
function Install-PowerShell7 {
    param(
        [switch]$Force,
        [switch]$NonInteractive
    )

    Write-Host "[~] Detecting platform and checking for existing PowerShell 7..." -ForegroundColor Yellow

    # Check if already installed
    $pwsh7Path = $null
    $isWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $PSVersionTable.PSVersion.Major -le 5

    if ($isWindows) {
        $pwsh7Path = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
    } elseif ($IsMacOS) {
        $pwsh7Path = "/usr/local/bin/pwsh"
    } else {
        $pwsh7Path = "/usr/bin/pwsh"
    }

    if ((Test-Path $pwsh7Path) -and -not $Force) {
        Write-Host "[+] PowerShell 7 already installed at: $pwsh7Path" -ForegroundColor Green
        return $pwsh7Path
    }

    Write-Host "[~] Installing PowerShell 7 for your platform..." -ForegroundColor Cyan

    # Download and install based on platform
    if ($isWindows) {
        # Try winget first as it's more reliable
        Write-Host "[~] Checking for winget..." -ForegroundColor Yellow
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            try {
                Write-Host "[~] Installing PowerShell 7 via winget..." -ForegroundColor Cyan
                & winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --disable-interactivity
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[+] PowerShell 7 installed successfully via winget!" -ForegroundColor Green

                    # Wait for PowerShell 7 to be available and find its path
                    Write-Host "[~] Locating PowerShell 7 installation..." -ForegroundColor Yellow
                    $maxAttempts = 10
                    $attempt = 0
                    $pwsh7Path = $null

                    while ($attempt -lt $maxAttempts -and -not $pwsh7Path) {
                        $attempt++
                        Start-Sleep -Seconds 2

                        # Check common locations
                        $checkPaths = @(
                            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
                            "$env:ProgramFiles\PowerShell\7.5.2\pwsh.exe",
                            "$env:ProgramFiles\PowerShell\7.4.1\pwsh.exe",
                            "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe"
                        )

                        foreach ($checkPath in $checkPaths) {
                            if (Test-Path $checkPath) {
                                $pwsh7Path = $checkPath
                                break
                            }
                        }

                        # Also check if pwsh is in PATH
                        if (-not $pwsh7Path) {
                            $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
                            if ($pwshCommand) {
                                $pwsh7Path = $pwshCommand.Source
                            }
                        }
                    }

                    if ($pwsh7Path) {
                        Write-Host "[+] Found PowerShell 7 at: $pwsh7Path" -ForegroundColor Green
                        return $pwsh7Path
                    } else {
                        throw "PowerShell 7 installed but executable not found after $maxAttempts attempts"
                    }
                }
            } catch {
                Write-Host "[!] Winget installation failed: $_" -ForegroundColor Yellow
                Write-Host "[~] Falling back to MSI installer..." -ForegroundColor Yellow
            }
        }

        Write-Host "[~] Downloading PowerShell 7 MSI installer..." -ForegroundColor Yellow
        # Get latest release URL
        try {
            $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest" -UseBasicParsing
            $msiAsset = $latestRelease.assets | Where-Object { $_.name -like "PowerShell-*-win-x64.msi" } | Select-Object -First 1
            $msiUrl = $msiAsset.browser_download_url

            if (-not $msiUrl) {
                # Fallback to known good version
                $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
            }
        } catch {
            # Fallback URL if API fails
            $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/PowerShell-7.4.1-win-x64.msi"
        }

        $msiPath = "$env:TEMP\PowerShell-7-win-x64.msi"

        try {
            Invoke-WebRequestWithRetry -Uri $msiUrl -OutFile $msiPath
            Write-Host "[~] Download complete. Installing PowerShell 7..." -ForegroundColor Yellow

            # Check if running as admin
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

            if ($isAdmin) {
                # Install silently
                $arguments = "/i `"$msiPath`" /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1"
                $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru

                if ($process.ExitCode -eq 0) {
                    Write-Host "[+] PowerShell 7 installed successfully!" -ForegroundColor Green
                    # Return the standard PowerShell 7 path after MSI installation
                    return "$env:ProgramFiles\PowerShell\7\pwsh.exe"
                } else {
                    throw "MSI installation failed with exit code: $($process.ExitCode)"
                }
            } else {
                # Try portable installation for non-admin users
                Write-Host "[!] No administrator privileges - trying portable installation..." -ForegroundColor Yellow

                try {
                    # Download portable zip instead
                    $zipUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-win-x64.zip"
                    $zipPath = "$env:TEMP\PowerShell-7-win-x64.zip"
                    $portableDir = "$env:LOCALAPPDATA\Microsoft\PowerShell\7"

                    Write-Host "[~] Downloading PowerShell 7 portable..." -ForegroundColor Yellow
                    Invoke-WebRequestWithRetry -Uri $zipUrl -OutFile $zipPath

                    Write-Host "[~] Installing to user directory..." -ForegroundColor Yellow
                    if (Test-Path $portableDir) {
                        Remove-Item $portableDir -Recurse -Force
                    }
                    New-Item -ItemType Directory -Force -Path $portableDir | Out-Null

                    # Extract portable version
                    if ($PSVersionTable.PSVersion.Major -ge 7) {
                        Expand-Archive -Path $zipPath -DestinationPath $portableDir -Force
                    } else {
                        $shell = New-Object -ComObject Shell.Application
                        $zip = $shell.NameSpace($zipPath)
                        $dest = $shell.NameSpace($portableDir)
                        $dest.CopyHere($zip.Items(), 4)
                    }

                    # Add to PATH for current session
                    $env:PATH = "$portableDir;$env:PATH"

                    # Verify installation
                    $portablePwsh = Join-Path $portableDir "pwsh.exe"
                    if (Test-Path $portablePwsh) {
                        Write-Host "[+] PowerShell 7 installed successfully (portable)!" -ForegroundColor Green
                        Write-Host "[i] Installed to: $portableDir" -ForegroundColor Cyan
                        # Return the portable PowerShell 7 path
                        return $portablePwsh
                    } else {
                        throw "Portable installation failed - pwsh.exe not found"
                    }

                    # Clean up
                    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

                } catch {
                    Write-Host "[!] Portable installation failed: $_" -ForegroundColor Red
                    Write-Host "[!] Please install PowerShell 7 manually from: https://aka.ms/powershell" -ForegroundColor Yellow
                    throw "PowerShell 7 installation failed"
                }
            }
        } finally {
            if (Test-Path $msiPath) {
                Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    elseif ($IsMacOS) {
        Write-Host "[~] Installing PowerShell 7 for macOS..." -ForegroundColor Yellow

        # Try Homebrew first (non-interactive)
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-Host "[~] Using Homebrew to install PowerShell..." -ForegroundColor Yellow
            try {
                & brew install --cask powershell 2>/dev/null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[+] PowerShell 7 installed via Homebrew!" -ForegroundColor Green
                    # Return the standard Homebrew PowerShell path
                    return "/opt/homebrew/bin/pwsh"
                }
            } catch {
                Write-Host "[!] Homebrew installation failed, trying portable..." -ForegroundColor Yellow
            }
        }

        # Portable installation for macOS
        Write-Host "[~] Installing PowerShell 7 portable for macOS..." -ForegroundColor Yellow
        try {
            $tarUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/powershell-lts-osx-x64.tar.gz"
            $installDir = "$HOME/.local/share/powershell"
            $tarPath = "/tmp/powershell-osx.tar.gz"

            # Create installation directory
            & mkdir -p $installDir

            # Download and extract
            Write-Host "[~] Downloading PowerShell portable..." -ForegroundColor Yellow
            & curl -L $tarUrl -o $tarPath

            Write-Host "[~] Extracting to user directory..." -ForegroundColor Yellow
            & tar -xzf $tarPath -C $installDir

            # Make executable
            & chmod +x "$installDir/pwsh"

            # Add to PATH for current session
            $env:PATH = "$installDir" + ":" + $env:PATH

            # Verify installation
            if (Test-Path "$installDir/pwsh") {
                Write-Host "[+] PowerShell 7 installed successfully (portable)!" -ForegroundColor Green
                Write-Host "[i] Installed to: $installDir" -ForegroundColor Cyan
                # Return the portable PowerShell 7 path
                return "$installDir/pwsh"
            } else {
                throw "Portable installation failed - pwsh not found"
            }

            # Clean up
            & rm -f $tarPath

        } catch {
            Write-Host "[!] PowerShell 7 installation failed: $_" -ForegroundColor Red
            Write-Host "[!] Please install manually from: https://aka.ms/powershell" -ForegroundColor Yellow
            throw "PowerShell 7 installation failed"
        }
    }
    else {
        Write-Host "[~] Installing PowerShell 7 for Linux..." -ForegroundColor Yellow
        # Try package managers first (if user has sudo access)

        if (Test-Path /etc/debian_version) {
            # Debian/Ubuntu - try with sudo first
            Write-Host "[~] Detected Debian/Ubuntu. Attempting package installation..." -ForegroundColor Yellow
            try {
                if (Get-Command sudo -ErrorAction SilentlyContinue) {
                    & wget -q "https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb 2>/dev/null
                    & sudo dpkg -i /tmp/packages-microsoft-prod.deb 2>/dev/null
                    & sudo apt-get update -qq 2>/dev/null
                    & sudo apt-get install -y powershell 2>/dev/null
                    & rm -f /tmp/packages-microsoft-prod.deb

                    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                        Write-Host "[+] PowerShell 7 installed via apt!" -ForegroundColor Green
                        # Return the standard Linux PowerShell path
                        return "/usr/bin/pwsh"
                    }
                }
            } catch {
                Write-Host "[!] Package installation failed, trying portable..." -ForegroundColor Yellow
            }
        } elseif (Test-Path /etc/redhat-release) {
            # RHEL/CentOS/Fedora
            Write-Host "[~] Detected RHEL/CentOS/Fedora. Attempting package installation..." -ForegroundColor Yellow
            try {
                if (Get-Command sudo -ErrorAction SilentlyContinue) {
                    & sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null
                    & curl -s https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo >/dev/null 2>&1

                    if (Get-Command dnf -ErrorAction SilentlyContinue) {
                        & sudo dnf install -y powershell 2>/dev/null
                    } else {
                        & sudo yum install -y powershell 2>/dev/null
                    }

                    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
                        Write-Host "[+] PowerShell 7 installed via package manager!" -ForegroundColor Green
                        # Return the standard Linux PowerShell path
                        return "/usr/bin/pwsh"
                    }
                }
            } catch {
                Write-Host "[!] Package installation failed, trying portable..." -ForegroundColor Yellow
            }
        }

        # If we reach here, package installation failed, use portable installation
        Write-Host "[~] Installing PowerShell 7 portable for Linux..." -ForegroundColor Yellow
        try {
            $tarUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/powershell-lts-linux-x64.tar.gz"
            $installDir = "$HOME/.local/share/powershell"
            $tarPath = "/tmp/powershell-linux.tar.gz"

            # Create installation directory
            & mkdir -p $installDir

            # Download and extract
            Write-Host "[~] Downloading PowerShell portable..." -ForegroundColor Yellow
            & curl -L $tarUrl -o $tarPath

            Write-Host "[~] Extracting to user directory..." -ForegroundColor Yellow
            & tar -xzf $tarPath -C $installDir

            # Make executable
            & chmod +x "$installDir/pwsh"

            # Add to PATH for current session
            $env:PATH = "$installDir" + ":" + $env:PATH

            # Verify installation
            if (Test-Path "$installDir/pwsh") {
                Write-Host "[+] PowerShell 7 installed successfully (portable)!" -ForegroundColor Green
                Write-Host "[i] Installed to: $installDir" -ForegroundColor Cyan
                # Return the portable PowerShell 7 path
                return "$installDir/pwsh"
            } else {
                throw "Portable installation failed - pwsh not found"
            }

            # Clean up
            & rm -f $tarPath

        } catch {
            Write-Host "[!] PowerShell 7 installation failed: $_" -ForegroundColor Red
            Write-Host "[!] Please install manually from: https://aka.ms/powershell" -ForegroundColor Yellow
            throw "PowerShell 7 installation failed"
        }
    }

    # Verify installation - check multiple possible locations
    $pwsh7Found = $false
    $pwsh7Location = ""

    # Check standard locations
    $possiblePaths = @(
        $pwsh7Path,  # Standard system location
        "$env:LOCALAPPDATA\Microsoft\PowerShell\7\pwsh.exe",  # Windows portable
        "$HOME/.local/share/powershell/pwsh",  # Linux/macOS portable
        (Get-Command pwsh -ErrorAction SilentlyContinue).Source  # In PATH
    )

    foreach ($path in $possiblePaths) {
        if ($path -and (Test-Path $path)) {
            $pwsh7Found = $true
            $pwsh7Location = $path
            break
        }
    }

    if ($pwsh7Found) {
        Write-Host "[+] PowerShell 7 installation verified!" -ForegroundColor Green
        Write-Host "[i] Located at: $pwsh7Location" -ForegroundColor Cyan
        return $pwsh7Location
    } else {
        throw "PowerShell 7 installation completed but executable not found in any expected location"
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
    $ProfileName = $env:AITHER_PROFILE
    if (-not $ProfileName) {
        if (-not $env:AITHER_BOOTSTRAP_MODE) {
            Write-Host ""
            Write-Host "Select AitherZero Profile:" -ForegroundColor Cyan
            Write-Host "  [1] Minimal (5-8 MB) - Core infrastructure deployment only" -ForegroundColor White
            Write-Host "  [2] Developer (15-25 MB) - Development environment (recommended)" -ForegroundColor Green
            Write-Host "  [3] Full (35-50 MB) - Complete enterprise environment" -ForegroundColor White
            Write-Host ""

            do {
                $ProfileNameChoice = Read-Host "Enter your choice (1/2/3) [default: 2]"
                if (-not $ProfileNameChoice) { $ProfileNameChoice = '2' }
            } while ($ProfileNameChoice -notmatch '^[123]$')

            $ProfileName = switch ($ProfileNameChoice) {
                '1' { 'minimal' }
                '2' { 'developer' }
                '3' { 'full' }
            }
        } else {
            # Non-interactive mode defaults to developer
            $ProfileName = 'developer'
        }
    }

    Write-Host ">> Downloading AitherZero ($ProfileName profile)..." -ForegroundColor Cyan

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

    # Extract version from release tag
    $releaseVersion = if ($release.tag_name -match '^v?(.+)$') {
        $Matches[1]
    } else {
        Write-Host "[!] Could not extract version from release tag: $($release.tag_name)" -ForegroundColor Yellow
        $release.tag_name
    }
    Write-Host "[i] Release version: $releaseVersion" -ForegroundColor Cyan

    # Find Windows ZIP file for the selected profile
    $windowsAsset = $null
    # Map bootstrap profile names to build profile names
    $buildProfile = switch ($ProfileName) {
        'minimal' { 'minimal' }
        'developer' { 'development' }  # Use development package which includes SetupWizard
        'full' { 'development' }  # Build uses 'development' for full profile
        default { 'standard' }
    }
    # Updated pattern to match versioned files: AitherZero-{version}-{profile}-windows.zip
    $ProfileNamePattern = "AitherZero-.*-$buildProfile-windows\.zip$"

    foreach ($asset in $release.assets) {
        if ($asset.name -match $ProfileNamePattern) {
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
    Write-Host "[i] Profile: $ProfileName" -ForegroundColor Cyan
    Write-Host "[i] To remove later, delete the AitherZero folder or run bootstrap.ps1 again and select Remove" -ForegroundColor Gray

    # Auto-start
    Write-Host ">> Starting AitherZero ($ProfileName profile)..." -ForegroundColor Cyan

    # Ensure we're in the correct directory for the application
    $extractionPath = Get-Location
    Write-Host "[~] Working directory: $extractionPath" -ForegroundColor Yellow

    # Determine which script to run
    $startScript = $null
    if (Test-Path ".\Start-AitherZero.ps1") {
        # Use main launcher
        $startScript = ".\Start-AitherZero.ps1"
        # Add -Setup parameter for first-time installation
        $startParams = @{Setup = $true; InstallationProfile = $ProfileName}

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
                        $pwsh7Path = Install-PowerShell7 -NonInteractive:($env:AITHER_BOOTSTRAP_MODE -ne $null)

                        if (Test-Path $pwsh7Path) {
                            Write-Host "[+] PowerShell 7 installed successfully!" -ForegroundColor Green
                            Write-Host "[~] Re-launching bootstrap in PowerShell 7..." -ForegroundColor Cyan

                            # Prepare arguments for re-launch
                            $scriptPath = $MyInvocation.MyCommand.Path
                            if (-not $scriptPath) { $scriptPath = $PSCommandPath }

                            # When running via iex, save script to temp for re-launch
                            if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
                                Write-Host "[~] Saving bootstrap script for re-launch..." -ForegroundColor Yellow
                                $tempScriptPath = Join-Path $env:TEMP "aitherzero-bootstrap-$(Get-Random).ps1"

                                # Download script content
                                try {
                                    $scriptContent = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1" -UseBasicParsing
                                    Set-Content -Path $tempScriptPath -Value $scriptContent.Content -Encoding UTF8
                                    $scriptPath = $tempScriptPath
                                    $env:AITHER_TEMP_BOOTSTRAP = $tempScriptPath
                                } catch {
                                    throw "Failed to download bootstrap script for re-launch: $_"
                                }
                            }

                            # Re-launch in PowerShell 7 with proper window handling
                            $relaunchArgs = @(
                                "-NoExit",  # Keep window open
                                "-NoProfile",
                                "-ExecutionPolicy", "Bypass",
                                "-File", "`"$scriptPath`""
                            )

                            # Preserve environment variables
                            $env:AITHER_PS7_RELAUNCHED = 'true'

                            Write-Host "[~] Starting new PowerShell 7 window..." -ForegroundColor Cyan
                            Write-Host "[i] Bootstrap will continue in the new window" -ForegroundColor Yellow

                            # Start new process
                            Start-Process $pwsh7Path -ArgumentList $relaunchArgs -Wait

                            # Exit current process
                            Exit-Bootstrap -ExitCode 0 -Message "[+] Bootstrap completed in new window"
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

            # If we got here with PS7, we may have been relaunched
            if ($env:AITHER_PS7_RELAUNCHED -eq 'true') {
                Write-Host "[+] Successfully relaunched in PowerShell 7!" -ForegroundColor Green
                Remove-Item env:AITHER_PS7_RELAUNCHED -ErrorAction SilentlyContinue
            }

            # For PowerShell 5.1, don't check execution policy in-process
            # Just try to run and handle the error
            try {
                & $startScript @startParams
            } catch {
                if ($_.Exception.Message -like '*running scripts is disabled*' -or $_.Exception.Message -like '*execution policy*') {
                    Write-Host "[!] PowerShell execution policy prevents running scripts" -ForegroundColor Red
                    Write-Host "[i] To enable scripts, run as Administrator:" -ForegroundColor Cyan
                    Write-Host "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
                    Write-Host "[i] Or run AitherZero with:" -ForegroundColor Cyan
                    Write-Host "    powershell.exe -ExecutionPolicy Bypass -File .\Start-AitherZero.ps1 -Setup" -ForegroundColor White
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