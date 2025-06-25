#Requires -Version 5.1
<#
.SYNOPSIS
    AitherZero Quick Download Script

.DESCRIPTION
    Downloads the latest AitherZero release and extracts it for immediate use.

.PARAMETER DestinationPath
    Where to download and extract AitherZero (default: current directory)

.PARAMETER OpenAfterDownload
    Whether to automatically start AitherZero after download

.EXAMPLE
    .\download-aitherzero.ps1

.EXAMPLE
    .\download-aitherzero.ps1 -DestinationPath "C:\Tools" -OpenAfterDownload
#>

[CmdletBinding()]
param(
    [string]$DestinationPath = ".",
    [switch]$OpenAfterDownload
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 AitherZero Quick Download Starting..." -ForegroundColor Green
    Write-Host "📂 Destination: $DestinationPath" -ForegroundColor Cyan

    # Get latest release info
    Write-Host "🔍 Checking for latest release..." -ForegroundColor Yellow
    $releaseInfo = Invoke-RestMethod "https://api.github.com/repos/wizzense/AitherZero/releases/latest"

    # Find the Release ZIP
    $releaseAsset = $releaseInfo.assets | Where-Object { $_.name -like "*Release.zip" }

    if (-not $releaseAsset) {
        throw "No Release.zip found in latest release. Available assets: $($releaseInfo.assets.name -join ', ')"
    }

    Write-Host "✅ Found release: $($releaseInfo.tag_name)" -ForegroundColor Green
    Write-Host "📦 Package: $($releaseAsset.name)" -ForegroundColor Cyan
    Write-Host "📊 Size: $([math]::Round($releaseAsset.size / 1MB, 2)) MB" -ForegroundColor Cyan

    # Download the release
    $zipPath = Join-Path $DestinationPath $releaseAsset.name
    Write-Host "📥 Downloading to: $zipPath" -ForegroundColor Yellow

    Invoke-WebRequest $releaseAsset.browser_download_url -OutFile $zipPath
    Write-Host "✅ Download complete!" -ForegroundColor Green

    # Extract the package
    Write-Host "📂 Extracting package..." -ForegroundColor Yellow
    Expand-Archive $zipPath -DestinationPath $DestinationPath -Force

    # Find the extracted folder
    $extractedFolders = Get-ChildItem $DestinationPath -Directory | Where-Object { $_.Name -like "AitherZero-*" }
    $aitherZeroFolder = $extractedFolders | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $aitherZeroFolder) {
        throw "Could not find extracted AitherZero folder"
    }

    Write-Host "✅ Extracted to: $($aitherZeroFolder.FullName)" -ForegroundColor Green

    # Show usage instructions
    Write-Host ""
    Write-Host "🎉 AitherZero Ready!" -ForegroundColor Green
    Write-Host "📋 To start AitherZero:" -ForegroundColor Cyan
    Write-Host "   cd `"$($aitherZeroFolder.FullName)`"" -ForegroundColor White
    Write-Host "   .\Start-AitherZero.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "🖱️ Or double-click: $($aitherZeroFolder.FullName)\Start-AitherZero.bat" -ForegroundColor Cyan

    # Clean up ZIP file
    Remove-Item $zipPath -Force
    Write-Host "🧹 Cleaned up download file" -ForegroundColor Green

    # Optionally start AitherZero
    if ($OpenAfterDownload) {
        Write-Host ""
        Write-Host "🚀 Starting AitherZero..." -ForegroundColor Green
        Set-Location $aitherZeroFolder.FullName
        & ".\Start-AitherZero.ps1"
    }

} catch {
    Write-Host "❌ Download failed: $($_.Exception.Message)" -ForegroundColor Red

    if ($_.Exception.Message -like "*404*") {
        Write-Host ""
        Write-Host "💡 No releases available yet. Try these alternatives:" -ForegroundColor Yellow
        Write-Host "   1. Check: https://github.com/wizzense/AitherZero/releases" -ForegroundColor White
        Write-Host "   2. Use bootstrap: iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1 -useb | iex" -ForegroundColor White
        Write-Host "   3. Git clone: git clone https://github.com/wizzense/AitherZero.git" -ForegroundColor White
    }

    exit 1
}