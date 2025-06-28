#!/usr/bin/env pwsh
Write-Host "=== AitherZero Package Validation ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Current directory: $(Get-Location)" -ForegroundColor Yellow
Write-Host "Files in current directory:" -ForegroundColor Yellow
Get-ChildItem | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }
Write-Host ""

Write-Host "Environment variables:" -ForegroundColor Yellow
Write-Host "  PROJECT_ROOT: $env:PROJECT_ROOT" -ForegroundColor White
Write-Host "  PWSH_MODULES_PATH: $env:PWSH_MODULES_PATH" -ForegroundColor White
Write-Host ""

if (Test-Path "modules") {
    Write-Host "Modules directory contents:" -ForegroundColor Yellow
    Get-ChildItem "modules" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }
} else {
    Write-Host "❌ No modules directory found!" -ForegroundColor Red
}

if (Test-Path "scripts") {
    Write-Host "Scripts directory contents:" -ForegroundColor Yellow
    Get-ChildItem "scripts" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }
} else {
    Write-Host "❌ No scripts directory found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Attempting to load LabRunner module..." -ForegroundColor Yellow
try {
    Import-Module (Join-Path "modules" "LabRunner") -Force
    Write-Host "✅ LabRunner module loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load LabRunner: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor Cyan
