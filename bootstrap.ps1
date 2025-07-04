# AitherZero Bootstrap Script v1.6 - PowerShell 5.1+ Compatible
# Usage: iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")
# Non-interactive: $env:AITHER_BOOTSTRAP_MODE='update'|'clean'|'new'; iex (irm ...)

# Enable TLS 1.2 for older systems
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Simple error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if AitherZero already exists
    $aither_files = @('Start-AitherZero.ps1', 'aither-core', 'quick-setup-simple.ps1')
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
                'cancel' { 'X' }
                default { 'U' }
            }
        } else {
            Write-Host "[!] AitherZero files detected in current directory" -ForegroundColor Yellow
            Write-Host "Choose an option:" -ForegroundColor Cyan
            Write-Host "  [U] Update existing installation (default)" -ForegroundColor White
            Write-Host "  [C] Clean install (remove existing files)" -ForegroundColor White
            Write-Host "  [N] Install to new subdirectory" -ForegroundColor White
            Write-Host "  [X] Cancel installation" -ForegroundColor White
            
            $choice = Read-Host "Enter your choice (U/C/N/X)"
            if (-not $choice) { $choice = 'U' }
        }
        
        switch ($choice.ToUpper()) {
            'C' {
                Write-Host "[~] Cleaning existing installation..." -ForegroundColor Yellow
                $cleanup_items = @('Start-AitherZero.ps1', 'aither-core', 'aither.ps1', 
                                 'aither.bat', 'quick-setup-simple.ps1', 'configs', 
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
    }
    
    Write-Host ">> Downloading AitherZero..." -ForegroundColor Cyan
    
    # Get latest Windows release
    $apiUrl = "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    
    # Find Windows ZIP file
    $windowsAsset = $null
    foreach ($asset in $release.assets) {
        if ($asset.name -match "windows.*\.zip$") {
            $windowsAsset = $asset
            break
        }
    }
    
    if (-not $windowsAsset) {
        throw "No Windows release found"
    }
    
    Write-Host "[*] Found release: $($windowsAsset.name)" -ForegroundColor Green
    
    # Download
    $zipFile = "AitherZero.zip"
    Write-Host "[-] Downloading $($windowsAsset.name)..." -ForegroundColor Yellow
    
    # Use different method for PS 5.1 vs 7+
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Invoke-WebRequest -Uri $windowsAsset.browser_download_url -OutFile $zipFile -UseBasicParsing
    } else {
        # PS 5.1 compatible download
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($windowsAsset.browser_download_url, (Join-Path $PWD $zipFile))
        $webClient.Dispose()
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
    
    # Auto-start
    Write-Host ">> Starting AitherZero..." -ForegroundColor Cyan
    
    # Ensure we're in the correct directory for the application
    $extractionPath = Get-Location
    Write-Host "[~] Working directory: $extractionPath" -ForegroundColor Yellow
    
    $startScript = $null
    if (Test-Path ".\quick-setup-simple.ps1") {
        $startScript = ".\quick-setup-simple.ps1"
    } elseif (Test-Path ".\Start-AitherZero.ps1") {
        $startScript = ".\Start-AitherZero.ps1"
    }
    
    if ($startScript) {
        # Set working directory and start with explicit path
        Push-Location $extractionPath
        try {
            Write-Host "[~] Starting from: $(Get-Location)" -ForegroundColor Yellow
            & $startScript -Auto
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "[+] AitherZero ready! Run .\Start-AitherZero.ps1 to begin." -ForegroundColor Green
        Write-Host "[~] Working directory: $extractionPath" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "[!] Installation failed: $_" -ForegroundColor Red
    Write-Host "[i] Try manual download from: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Yellow
    exit 1
}