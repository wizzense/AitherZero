# AitherZero Uninstall Script
# Quick removal script that can be run from the AitherZero directory
#
# Usage: .\uninstall.ps1

Write-Host ""
Write-Host "AitherZero Uninstaller" -ForegroundColor Red
Write-Host "=====================" -ForegroundColor Red
Write-Host ""

# Check if we're in an AitherZero directory
if (-not (Test-Path ".\Start-AitherZero.ps1")) {
    Write-Host "[!] This script must be run from the AitherZero installation directory" -ForegroundColor Red
    Write-Host "[i] Looking for AitherZero installations..." -ForegroundColor Yellow
    
    # Search common locations
    $searchPaths = @(
        ".\AitherZero",
        "..\AitherZero",
        "$env:USERPROFILE\AitherZero",
        "$env:USERPROFILE\Downloads\AitherZero"
    )
    
    $found = $false
    foreach ($path in $searchPaths) {
        if ((Test-Path $path) -and (Test-Path "$path\Start-AitherZero.ps1")) {
            Write-Host "[+] Found AitherZero at: $path" -ForegroundColor Green
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Write-Host "[!] Could not find AitherZero installation" -ForegroundColor Red
        exit 1
    }
    
    exit 1
}

# Use the removal script if it exists
if (Test-Path ".\scripts\Remove-AitherZero.ps1") {
    & .\scripts\Remove-AitherZero.ps1
} else {
    # Fallback to direct removal
    Write-Host "[!] Removal script not found, using direct removal" -ForegroundColor Yellow
    
    $confirm = Read-Host "Remove AitherZero from this directory? (yes/N)"
    if ($confirm -ne 'yes') {
        Write-Host "[!] Uninstall cancelled" -ForegroundColor Yellow
        exit 0
    }
    
    # Get parent directory before removal
    $parentDir = Split-Path -Parent (Get-Location)
    
    # Remove files
    $items = Get-ChildItem -Force | Where-Object { $_.Name -ne 'uninstall.ps1' }
    foreach ($item in $items) {
        try {
            Remove-Item $item.FullName -Recurse -Force
            Write-Host "  [-] Removed: $($item.Name)" -ForegroundColor Gray
        } catch {
            Write-Host "  [!] Failed to remove: $($item.Name)" -ForegroundColor Red
        }
    }
    
    Write-Host "[+] AitherZero has been removed" -ForegroundColor Green
    
    # Offer to remove the directory itself
    Set-Location $parentDir
    $currentDir = Split-Path -Leaf (Get-Location)
    Write-Host "[?] Remove the empty directory?" -ForegroundColor Yellow
    $removeDir = Read-Host "(y/N)"
    if ($removeDir -eq 'y' -or $removeDir -eq 'Y') {
        Remove-Item $currentDir -Force
        Write-Host "[+] Directory removed" -ForegroundColor Green
    }
}