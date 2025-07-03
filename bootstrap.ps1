# AitherZero Bootstrap Script v1.2 - PowerShell 5.1+ Compatible
# Usage: iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")

# Enable TLS 1.2 for older systems
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Simple error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Downloading AitherZero..." -ForegroundColor Cyan
    
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
    
    Write-Host "📦 Found release: $($windowsAsset.name)" -ForegroundColor Green
    
    # Download
    $zipFile = "AitherZero.zip"
    Write-Host "⬇️  Downloading $($windowsAsset.name)..." -ForegroundColor Yellow
    
    # Use different method for PS 5.1 vs 7+
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Invoke-WebRequest -Uri $windowsAsset.browser_download_url -OutFile $zipFile -UseBasicParsing
    } else {
        # PS 5.1 compatible download
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($windowsAsset.browser_download_url, (Join-Path $PWD $zipFile))
        $webClient.Dispose()
    }
    
    Write-Host "📂 Extracting..." -ForegroundColor Yellow
    
    # Create temp directory
    $tempDir = "AitherZero-temp-$(Get-Random)"
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
        Get-ChildItem -Path $innerDir.FullName -Force | ForEach-Object {
            Move-Item -Path $_.FullName -Destination $PWD -Force
        }
    } else {
        # Move all items from temp dir
        Get-ChildItem -Path $tempDir -Force | ForEach-Object {
            Move-Item -Path $_.FullName -Destination $PWD -Force
        }
    }
    
    # Clean up temp directory
    Remove-Item $tempDir -Recurse -Force
    
    Write-Host "✅ Extracted to: $PWD" -ForegroundColor Green
    
    # Auto-start
    Write-Host "🚀 Starting AitherZero..." -ForegroundColor Cyan
    
    $startScript = $null
    if (Test-Path ".\quick-setup-simple.ps1") {
        $startScript = ".\quick-setup-simple.ps1"
    } elseif (Test-Path ".\Start-AitherZero.ps1") {
        $startScript = ".\Start-AitherZero.ps1"
    }
    
    if ($startScript) {
        & $startScript -Auto
    } else {
        Write-Host "✅ AitherZero ready! Run .\Start-AitherZero.ps1 to begin." -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Installation failed: $_" -ForegroundColor Red
    Write-Host "💡 Try manual download from: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Yellow
    exit 1
}