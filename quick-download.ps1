#Requires -Version 5.1
<#
.SYNOPSIS
    SUPER SIMPLE AitherZero Download & Run

.DESCRIPTION
    The absolute easiest way to get and run AitherZero.
    Downloads, extracts, and starts AitherZero in one command.

.EXAMPLE
    iwr https://raw.githubusercontent.com/wizzense/AitherZero/main/quick-download.ps1 -useb | iex
#>

$ErrorActionPreference = 'Stop'

Write-Host '🚀 AitherZero Super Simple Download...' -ForegroundColor Green

try {
    # Get latest release
    $release = Invoke-RestMethod 'https://api.github.com/repos/wizzense/AitherZero/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -like '*Release.zip' }

    if (-not $asset) {
        throw 'No release package found'
    }

    Write-Host "📦 Downloading $($asset.name)..." -ForegroundColor Cyan

    # Download and extract
    $zipPath = 'AitherZero.zip'
    Invoke-WebRequest $asset.browser_download_url -OutFile $zipPath
    Expand-Archive $zipPath -Force
    Remove-Item $zipPath

    # Find folder and start
    $folder = Get-ChildItem -Directory | Where-Object { $_.Name -like 'AitherZero-*' } | Select-Object -First 1

    if ($folder) {
        Write-Host '✅ Ready! Starting AitherZero...' -ForegroundColor Green
        Set-Location $folder.FullName
        & '.\Start-AitherZero.ps1'
    } else {
        Write-Host '❌ Could not find extracted folder' -ForegroundColor Red
    }

} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host '💡 Try manual download: https://github.com/wizzense/AitherZero/releases/latest' -ForegroundColor Yellow
}
