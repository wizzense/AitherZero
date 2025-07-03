# AitherZero Bootstrap Script - Ultra Simple & Compatible
# Works with PowerShell 5.1+ and handles flat package structure

Write-Host "🚀 Downloading AitherZero..." -ForegroundColor Cyan

# Find latest release
$release = irm "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
$asset = $release.assets | Where-Object { $_.name -like "*windows*.zip" } | Select-Object -First 1

if (-not $asset) {
    Write-Host "❌ No Windows release found!" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Found release: $($asset.name)" -ForegroundColor Green

# Download to temp
$tempFile = Join-Path $env:TEMP "AitherZero-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
Write-Host "⬇️  Downloading $($asset.name)..." -ForegroundColor Yellow

try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "AitherZero-Bootstrap")
    $wc.DownloadFile($asset.browser_download_url, $tempFile)
}
catch {
    Write-Host "❌ Download failed: $_" -ForegroundColor Red
    exit 1
}

# Extract
$extractPath = Join-Path $pwd.Path "AitherZero"
if (Test-Path $extractPath) {
    Write-Host "📂 Removing existing AitherZero directory..." -ForegroundColor Yellow
    Remove-Item $extractPath -Recurse -Force
}

Write-Host "📂 Extracting..." -ForegroundColor Yellow
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $extractPath)

# Cleanup temp file
Remove-Item $tempFile -Force

Write-Host "✅ Extracted to: $extractPath" -ForegroundColor Green

# Check and fix directory structure if needed
$needsRestructure = $false
if ((Test-Path (Join-Path $extractPath "modules")) -and 
    -not (Test-Path (Join-Path $extractPath "aither-core" "modules"))) {
    Write-Host "🔧 Fixing directory structure..." -ForegroundColor Yellow
    
    # Create aither-core directory
    $aithercorePath = Join-Path $extractPath "aither-core"
    New-Item -ItemType Directory -Path $aithercorePath -Force | Out-Null
    
    # Move directories
    Move-Item (Join-Path $extractPath "modules") (Join-Path $aithercorePath "modules") -Force
    Move-Item (Join-Path $extractPath "shared") (Join-Path $aithercorePath "shared") -Force
    
    # Move core files
    if (Test-Path (Join-Path $extractPath "aither-core.ps1")) {
        Move-Item (Join-Path $extractPath "aither-core.ps1") $aithercorePath -Force
    }
    if (Test-Path (Join-Path $extractPath "aither-core-bootstrap.ps1")) {
        Move-Item (Join-Path $extractPath "aither-core-bootstrap.ps1") $aithercorePath -Force
    }
    
    Write-Host "✅ Directory structure fixed" -ForegroundColor Green
}

# Start AitherZero
Write-Host "🚀 Starting AitherZero..." -ForegroundColor Cyan
Set-Location $extractPath

# Try to run setup
if (Test-Path ".\quick-setup-simple.ps1") {
    & .\quick-setup-simple.ps1 -Auto
}
elseif (Test-Path ".\Start-AitherZero.ps1") {
    & .\Start-AitherZero.ps1 -Setup
}
else {
    Write-Host "Ready! Run .\aither.ps1 to start" -ForegroundColor Green
}