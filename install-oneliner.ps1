# AitherZero One-Liner Installer
# This script is designed to work with PowerShell 5.1+ and be executed via Invoke-Expression
#
# ONE-LINER USAGE:
# iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/install-oneliner.ps1')
#
# OR FOR POWERSHELL 3.0+:
# (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/wizzense/AitherZero/main/install-oneliner.ps1') | iex

# Simple installation without parameters
$ErrorActionPreference = 'Stop'

Write-Host "`nAitherZero Quick Installer" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Create temp file for the installer
$installerUrl = 'https://raw.githubusercontent.com/wizzense/AitherZero/main/get-aither-fixed.ps1'
$tempFile = [System.IO.Path]::GetTempFileName() + '.ps1'

try {
    Write-Host "`nDownloading installer..." -ForegroundColor Yellow
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "PowerShell")
    $wc.DownloadFile($installerUrl, $tempFile)
    
    Write-Host "Running installer..." -ForegroundColor Yellow
    
    # Execute the installer
    & $tempFile
    
} catch {
    Write-Host "`nERROR: Installation failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    Write-Host "`nAlternative: Download and run manually:" -ForegroundColor Yellow
    Write-Host "1. Download: https://github.com/wizzense/AitherZero/archive/refs/heads/main.zip" -ForegroundColor White
    Write-Host "2. Extract the ZIP file" -ForegroundColor White
    Write-Host "3. Run: .\AitherZero\Start-AitherZero.ps1 -Setup" -ForegroundColor White
    
} finally {
    # Cleanup
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}