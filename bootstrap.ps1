#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Ultra-simple AitherZero bootstrap script for one-liner execution

.DESCRIPTION
    Clean, readable script that downloads and runs AitherZero.
    Compatible with PowerShell 5.1+ and designed for endpoints without GUI.
    
    For Linux/macOS users, use bootstrap.sh instead:
    curl -sSL https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.sh | bash

.EXAMPLE
    # Windows one-liner usage:
    iex (irm "https://raw.githubusercontent.com/wizzense/AitherZero/main/bootstrap.ps1")

.NOTES
    AitherZero Bootstrap v1.1 - Fixed extraction and path issues
#>

[CmdletBinding()]
param()

# Enable TLS 1.2 for PowerShell 5.1 compatibility
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Write-Host "🚀 Downloading AitherZero..." -ForegroundColor Cyan
    
    # Get latest Windows release
    $release = Invoke-RestMethod "https://api.github.com/repos/wizzense/AitherZero/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*-windows-*.zip" } | Select-Object -First 1
    
    if (-not $asset) {
        throw "No Windows release found"
    }
    
    Write-Host "📦 Found release: $($asset.name)" -ForegroundColor Green
    
    # Download and extract
    $zipFile = "AitherZero.zip"
    Write-Host "⬇️  Downloading $($asset.name)..." -ForegroundColor Yellow
    Invoke-WebRequest $asset.browser_download_url -OutFile $zipFile
    
    Write-Host "📂 Extracting..." -ForegroundColor Yellow
    
    # Create temporary extraction directory
    $tempExtract = "AitherZero-temp-extract"
    if (Test-Path $tempExtract) {
        Remove-Item $tempExtract -Recurse -Force
    }
    
    Expand-Archive $zipFile -DestinationPath $tempExtract -Force
    Remove-Item $zipFile
    
    # Find the AitherZero directory inside temp extract
    $innerFolder = Get-ChildItem -Path $tempExtract -Directory | Where-Object { $_.Name -like "AitherZero*" } | Select-Object -First 1
    
    if ($innerFolder) {
        # Move contents from inner folder to current directory
        Write-Host "📁 Moving files from $($innerFolder.Name) to current directory..." -ForegroundColor Yellow
        Get-ChildItem -Path $innerFolder.FullName | ForEach-Object {
            Move-Item -Path $_.FullName -Destination "." -Force
        }
        Remove-Item $tempExtract -Recurse -Force
        Write-Host "✅ Extracted to: $(Get-Location)" -ForegroundColor Green
    } else {
        # No nested folder, move everything from temp
        Get-ChildItem -Path $tempExtract | ForEach-Object {
            Move-Item -Path $_.FullName -Destination "." -Force
        }
        Remove-Item $tempExtract -Recurse -Force
        Write-Host "✅ Extracted to: $(Get-Location)" -ForegroundColor Green
    }
    
    # Auto-start with best available method
    Write-Host "🚀 Starting AitherZero..." -ForegroundColor Cyan
    if (Test-Path "quick-setup-simple.ps1") {
        & ".\quick-setup-simple.ps1" -Auto
    } elseif (Test-Path "Start-AitherZero.ps1") {
        & ".\Start-AitherZero.ps1" -Auto
    } else {
        Write-Host "✅ AitherZero ready! Run .\Start-AitherZero.ps1 to begin." -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Try manual download from: https://github.com/wizzense/AitherZero/releases" -ForegroundColor Yellow
    exit 1
}