#!/usr/bin/env pwsh

# Detailed test to understand the module loading issue
cd /workspaces/AitherZero

try {
    Write-Host "Testing detailed module behavior..." -ForegroundColor Cyan

    # Check if files exist
    $moduleRoot = "./aither-core/domains/experience"
    $privateDir = Join-Path $moduleRoot "Private"
    $publicDir = Join-Path $moduleRoot "Public"

    Write-Host "Private directory exists: $(Test-Path $privateDir)" -ForegroundColor White
    Write-Host "Public directory exists: $(Test-Path $publicDir)" -ForegroundColor White

    # List private functions
    $privateFunctions = Get-ChildItem -Path $privateDir -Filter '*.ps1' -ErrorAction SilentlyContinue
    Write-Host "Private functions found: $($privateFunctions.Count)" -ForegroundColor White
    $privateFunctions | ForEach-Object { Write-Host "  - $($_.BaseName)" -ForegroundColor Gray }

    # List public functions
    $publicFunctions = Get-ChildItem -Path $publicDir -Filter '*.ps1' -ErrorAction SilentlyContinue
    Write-Host "Public functions found: $($publicFunctions.Count)" -ForegroundColor White
    $publicFunctions | ForEach-Object { Write-Host "  - $($_.BaseName)" -ForegroundColor Gray }

    Write-Host "`nImporting module..." -ForegroundColor Cyan
    Import-Module $moduleRoot -Force -ErrorAction Stop

    Write-Host "Module imported successfully" -ForegroundColor Green

    # Test if Start-InteractiveMode works
    Write-Host "`nTesting Start-InteractiveMode in dry-run mode..." -ForegroundColor Cyan

    # Try to manually test one of the missing functions
    try {
        $testResult = & {
            try {
                # This should work if the private functions are properly loaded
                Initialize-TerminalUI -ErrorAction Stop
                Write-Host "✓ Initialize-TerminalUI works" -ForegroundColor Green
                return $true
            } catch {
                Write-Host "❌ Initialize-TerminalUI failed: $_" -ForegroundColor Red
                return $false
            }
        }
    } catch {
        Write-Host "❌ Could not test Initialize-TerminalUI: $_" -ForegroundColor Red
    }

} catch {
    Write-Host "❌ ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
}

