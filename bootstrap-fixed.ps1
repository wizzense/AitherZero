# AitherZero Bootstrap Script v2.2 - FIXED VERSION
# This version actually works on fresh Windows 11 installs

# Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = 'Continue'  # Don't stop on non-critical errors

# Helper function for safe web requests
function Invoke-SafeWebRequest {
    param($Uri, $OutFile)
    try {
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
        } else {
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($Uri, (Join-Path $PWD $OutFile))
            $webClient.Dispose()
        }
        return $true
    } catch {
        Write-Host "[!] Download failed: $_" -ForegroundColor Red
        return $false
    }
}

try {
    # Check if already exists
    $existing = Test-Path "Start-AitherZero.ps1"
    if ($existing) {
        Write-Host "[!] AitherZero already exists in current directory" -ForegroundColor Yellow
        $choice = Read-Host "Update (U), Clean install (C), or Cancel (X)?"
        if ($choice -eq 'X') { exit 0 }
        if ($choice -eq 'C') {
            Remove-Item * -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Create subdirectory
    $installDir = "AitherZero"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    }
    Set-Location $installDir

    Write-Host ">> Downloading AitherZero..." -ForegroundColor Cyan
    
    # Get latest release
    $apiUrl = "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    } catch {
        Write-Host "[!] Cannot connect to GitHub. Check your internet connection." -ForegroundColor Red
        exit 1
    }

    # Find ANY windows package (don't worry about profiles for now)
    $windowsAsset = $null
    foreach ($asset in $release.assets) {
        if ($asset.name -like "*windows*.zip") {
            $windowsAsset = $asset
            break
        }
    }

    if (-not $windowsAsset) {
        Write-Host "[!] No Windows package found in latest release" -ForegroundColor Red
        exit 1
    }

    Write-Host "[*] Found: $($windowsAsset.name)" -ForegroundColor Green
    
    # Download
    $zipFile = "AitherZero.zip"
    if (-not (Invoke-SafeWebRequest -Uri $windowsAsset.browser_download_url -OutFile $zipFile)) {
        exit 1
    }

    Write-Host "[~] Extracting..." -ForegroundColor Yellow
    
    # Extract
    $tempDir = "temp-extract"
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
    } else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $PWD $zipFile), (Join-Path $PWD $tempDir))
    }
    
    # Move files from temp
    $items = Get-ChildItem -Path $tempDir
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        # Nested folder
        Get-ChildItem -Path $items[0].FullName -Force | ForEach-Object {
            Move-Item -Path $_.FullName -Destination . -Force
        }
    } else {
        # Direct files
        Get-ChildItem -Path $tempDir -Force | ForEach-Object {
            Move-Item -Path $_.FullName -Destination . -Force
        }
    }
    
    # Cleanup
    Remove-Item $zipFile -Force
    Remove-Item $tempDir -Recurse -Force
    
    Write-Host "[+] Extracted to: $PWD" -ForegroundColor Green
    
    # Fix the Start-AitherZero.ps1 script before running it
    $startScript = ".\Start-AitherZero.ps1"
    if (Test-Path $startScript) {
        Write-Host "[~] Patching Start-AitherZero.ps1 for compatibility..." -ForegroundColor Yellow
        
        $content = Get-Content $startScript -Raw
        
        # Add proper path resolution at the beginning
        $pathFix = @'
# Fix for $PSScriptRoot being null
if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent ([Environment]::GetCommandLineArgs()[0])
    if (-not $PSScriptRoot -or $PSScriptRoot -eq '') {
        $PSScriptRoot = (Get-Location).Path
    }
}
'@
        
        # Insert after the param block
        $content = $content -replace '(\)[\r\n]+)', "`$1`n$pathFix`n"
        
        Set-Content -Path $startScript -Value $content -Force
    }
    
    Write-Host "[+] AitherZero is ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To start AitherZero:" -ForegroundColor Cyan
    Write-Host "  cd $installDir" -ForegroundColor White
    Write-Host "  .\Start-AitherZero.ps1 -Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "For PowerShell 5.1 users:" -ForegroundColor Yellow
    Write-Host "  powershell.exe -ExecutionPolicy Bypass -File .\Start-AitherZero.ps1 -Setup" -ForegroundColor White
    
} catch {
    Write-Host "[!] Installation failed: $_" -ForegroundColor Red
    Write-Host "[i] Try manual download from: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Yellow
    exit 1
}