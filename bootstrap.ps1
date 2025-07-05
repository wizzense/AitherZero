# AitherZero Bootstrap Script v2.1 - PowerShell 5.1+ Compatible
# Usage: iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
# 
# Environment Variables for Automation:
# $env:AITHER_BOOTSTRAP_MODE = 'update'|'clean'|'new'|'remove'|'cancel'
# $env:AITHER_PROFILE = 'minimal'|'standard'|'development'
# $env:AITHER_INSTALL_DIR = 'custom/path' (default: ./AitherZero)
# $env:AITHER_AUTO_INSTALL_PS7 = 'true' (auto-install PowerShell 7 if needed)
# $env:AITHER_REINSTALL_PS7 = 'true' (force reinstall PowerShell 7)
# $env:AITHER_PS7_MSI_URL = 'custom-url' (override PS7 download URL)
# $env:AITHER_BYPASS_PS7_CHECK = 'true' (skip PS7 check entirely)
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
    
    # If running interactively and not in CI, pause before exit
    if (-not $env:CI -and -not $env:AITHER_BOOTSTRAP_MODE -and -not [System.Console]::IsInputRedirected) {
        # Check if we're in a terminal that will close
        $parentProcess = Get-Process -Id $PID
        if ($parentProcess.Parent -and $parentProcess.Parent.ProcessName -match 'explorer|cmd') {
            Write-Host ""
            Write-Host "Press any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
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
    
    # Check for reinstall/clean request
    if (($env:AITHER_REINSTALL_PS7 -eq 'true' -or $env:AITHER_CLEAN_PS7 -eq 'true') -and (Test-Path $pwsh7Path)) {
        Write-Host "[~] Removing existing PowerShell 7 installation..." -ForegroundColor Yellow
        if ($isWindows) {
            # Try to uninstall via MSI
            try {
                $ps7Installed = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | 
                    Where-Object { $_.DisplayName -like "PowerShell 7*" }
                
                if ($ps7Installed -and $ps7Installed.UninstallString) {
                    $uninstallCmd = $ps7Installed.UninstallString
                    if ($uninstallCmd -match 'msiexec.exe /[IX] \{([^}]+)\}') {
                        $productCode = $matches[1]
                        Write-Host "[~] Uninstalling PowerShell 7 (Product Code: $productCode)..." -ForegroundColor Yellow
                        $process = Start-Process msiexec.exe -ArgumentList "/x", "{$productCode}", "/quiet", "/norestart" -Wait -PassThru
                        if ($process.ExitCode -eq 0) {
                            Write-Host "[+] PowerShell 7 uninstalled successfully" -ForegroundColor Green
                        }
                    }
                }
            } catch {
                Write-Host "[!] Could not uninstall existing PowerShell 7: $_" -ForegroundColor Yellow
            }
        }
        $Force = $true
    }
    
    if ((Test-Path $pwsh7Path) -and -not $Force) {
        Write-Host "[+] PowerShell 7 already installed at: $pwsh7Path" -ForegroundColor Green
        return $pwsh7Path
    }
    
    Write-Host "[~] Installing PowerShell 7 for your platform..." -ForegroundColor Cyan
    
    # Download and install based on platform
    if ($isWindows) {
        Write-Host "[~] Downloading PowerShell 7 MSI installer..." -ForegroundColor Yellow
        
        # Check for custom MSI URL
        if ($env:AITHER_PS7_MSI_URL) {
            $msiUrl = $env:AITHER_PS7_MSI_URL
            Write-Host "[i] Using custom PS7 MSI URL: $msiUrl" -ForegroundColor Yellow
        } else {
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
                } else {
                    throw "MSI installation failed with exit code: $($process.ExitCode)"
                }
            } else {
                Write-Host "[!] Administrator privileges required for installation" -ForegroundColor Yellow
                
                if ($NonInteractive) {
                    throw "Cannot install PowerShell 7 without administrator privileges in non-interactive mode"
                }
                
                Write-Host "[~] Launching installer with elevation prompt..." -ForegroundColor Cyan
                Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`"" -Verb RunAs -Wait
                
                # Check if installation succeeded
                if (Test-Path $pwsh7Path) {
                    Write-Host "[+] PowerShell 7 installed successfully!" -ForegroundColor Green
                } else {
                    throw "Installation appears to have failed - PowerShell 7 not found at expected location"
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
        # macOS: Use brew if available, otherwise download pkg
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            Write-Host "[~] Using Homebrew to install PowerShell..." -ForegroundColor Yellow
            & brew install --cask powershell
        } else {
            Write-Host "[~] Downloading PowerShell pkg installer..." -ForegroundColor Yellow
            $pkgUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/powershell-lts.pkg"
            $pkgPath = "/tmp/powershell-lts.pkg"
            & curl -L $pkgUrl -o $pkgPath
            Write-Host "[~] Installing PowerShell package..." -ForegroundColor Yellow
            & sudo installer -pkg $pkgPath -target /
            & rm $pkgPath
        }
    }
    else {
        Write-Host "[~] Installing PowerShell 7 for Linux..." -ForegroundColor Yellow
        # Linux: Use package manager or direct download
        if (Test-Path /etc/debian_version) {
            # Debian/Ubuntu
            Write-Host "[~] Detected Debian/Ubuntu. Using apt package manager..." -ForegroundColor Yellow
            & wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
            & sudo dpkg -i /tmp/packages-microsoft-prod.deb
            & sudo apt-get update
            & sudo apt-get install -y powershell
            & rm /tmp/packages-microsoft-prod.deb
        } elseif (Test-Path /etc/redhat-release) {
            # RHEL/CentOS/Fedora
            Write-Host "[~] Detected RHEL/CentOS/Fedora. Using yum/dnf..." -ForegroundColor Yellow
            & sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            & curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
            & sudo yum install -y powershell
        } else {
            # Generic Linux - download tar.gz
            Write-Host "[~] Using generic Linux installation method..." -ForegroundColor Yellow
            $tarUrl = "https://github.com/PowerShell/PowerShell/releases/latest/download/powershell-lts-linux-x64.tar.gz"
            $installDir = "/opt/microsoft/powershell/7"
            & sudo mkdir -p $installDir
            & curl -L $tarUrl | sudo tar -xz -C $installDir
            & sudo chmod +x "$installDir/pwsh"
            & sudo ln -s "$installDir/pwsh" /usr/bin/pwsh
        }
    }
    
    # Verify installation
    if (Test-Path $pwsh7Path) {
        Write-Host "[+] PowerShell 7 installation verified!" -ForegroundColor Green
        return $pwsh7Path
    } else {
        throw "PowerShell 7 installation completed but executable not found at: $pwsh7Path"
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
            
            # Check PowerShell version (unless bypassed)
            if ($env:AITHER_BYPASS_PS7_CHECK -eq 'true') {
                Write-Host "[i] PowerShell 7 check bypassed by environment variable" -ForegroundColor Yellow
            } elseif ($PSVersionTable.PSVersion.Major -lt 7) {
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