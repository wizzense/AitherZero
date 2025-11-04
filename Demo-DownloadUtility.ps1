#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates the new DownloadUtility module capabilities.

.DESCRIPTION
    This script showcases the features of the new Invoke-FileDownload function
    including retry logic, intelligent caching, and download resume capabilities.

.EXAMPLE
    ./Demo-DownloadUtility.ps1
    
    Runs interactive demonstrations of all download utility features.
#>

[CmdletBinding()]
param()

# Import AitherZero module (which includes DownloadUtility)
Import-Module "$PSScriptRoot/AitherZero.psd1" -Force

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         DownloadUtility Module Demonstration                ║" -ForegroundColor Cyan
Write-Host "║   Intelligent Downloads with Retry, Resume & Validation     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check platform capabilities
Write-Host "═══ Test 1: Platform Capabilities ═══" -ForegroundColor Yellow
Write-Host ""

$bitsAvailable = Test-BitsAvailability
$downloadMethod = Get-DownloadMethod

Write-Host "Platform: " -NoNewline
if ($IsWindows) { Write-Host "Windows" -ForegroundColor Green }
elseif ($IsLinux) { Write-Host "Linux" -ForegroundColor Green }
elseif ($IsMacOS) { Write-Host "macOS" -ForegroundColor Green }

Write-Host "BITS Available: " -NoNewline
if ($bitsAvailable) { 
    Write-Host "Yes ✓" -ForegroundColor Green 
} else { 
    Write-Host "No (will use WebRequest fallback)" -ForegroundColor Yellow 
}

Write-Host "Recommended Method: " -NoNewline
Write-Host $downloadMethod -ForegroundColor Cyan

Write-Host ""
Start-Sleep -Seconds 2

# Test 2: Cached file detection (Idempotency)
Write-Host "═══ Test 2: Idempotent Downloads (Cached File Detection) ═══" -ForegroundColor Yellow
Write-Host ""

$tempDir = if ($IsWindows) { $env:TEMP } else { '/tmp' }
$testFile = Join-Path $tempDir "demo-cached-file.txt"
$testContent = "This is a test file created at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

Write-Host "Creating test file: $testFile"
Set-Content -Path $testFile -Value $testContent -Force

Write-Host "Attempting 'download' of existing file..."
$result = Invoke-FileDownload -Uri 'https://example.com/test.txt' `
    -OutFile $testFile `
    -SkipValidation

Write-Host ""
Write-Host "Result:" -ForegroundColor Cyan
Write-Host "  Success: $($result.Success)"
Write-Host "  Method: $($result.Method)" -ForegroundColor $(if ($result.Method -eq 'Cached') { 'Green' } else { 'Yellow' })
Write-Host "  File Size: $($result.FileSize) bytes"
Write-Host "  Attempts: $($result.Attempts)"
Write-Host "  Message: $($result.Message)"

if ($result.Method -eq 'Cached') {
    Write-Host ""
    Write-Host "✓ Cached file was detected and reused (idempotent operation)!" -ForegroundColor Green
}

# Cleanup
Remove-Item $testFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Start-Sleep -Seconds 2

# Test 3: Demonstrate retry logic (simulated with invalid URL)
Write-Host "═══ Test 3: Retry Logic with Exponential Backoff ═══" -ForegroundColor Yellow
Write-Host ""
Write-Host "Attempting download from invalid URL to demonstrate retry..."
Write-Host "(This will fail intentionally to show retry behavior)" -ForegroundColor Gray
Write-Host ""

$invalidFile = Join-Path $tempDir "demo-retry-test.txt"
$startTime = Get-Date

$result = Invoke-FileDownload -Uri 'https://invalid-domain-12345.example.com/file.txt' `
    -OutFile $invalidFile `
    -RetryCount 3 `
    -RetryDelaySeconds 1 `
    -ErrorAction SilentlyContinue

$duration = ((Get-Date) - $startTime).TotalSeconds

Write-Host ""
Write-Host "Retry Results:" -ForegroundColor Cyan
Write-Host "  Success: $($result.Success)"
Write-Host "  Attempts: $($result.Attempts)"
Write-Host "  Duration: $($duration.ToString('F1'))s"
Write-Host "  Message: $($result.Message)"

if ($result.Attempts -gt 1) {
    Write-Host ""
    Write-Host "✓ Retry logic executed with exponential backoff!" -ForegroundColor Green
    Write-Host "  (Delays: 1s, 2s, 4s between attempts)" -ForegroundColor Gray
}

Write-Host ""
Start-Sleep -Seconds 2

# Test 4: Show function parameters
Write-Host "═══ Test 4: Available Parameters ═══" -ForegroundColor Yellow
Write-Host ""

$params = (Get-Command Invoke-FileDownload).Parameters.Keys | Sort-Object
Write-Host "Invoke-FileDownload supports these parameters:" -ForegroundColor Cyan
foreach ($param in $params) {
    if ($param -notin @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 
                        'InformationAction', 'ErrorVariable', 'WarningVariable', 
                        'InformationVariable', 'OutVariable', 'OutBuffer', 
                        'PipelineVariable', 'WhatIf', 'Confirm')) {
        Write-Host "  • $param" -ForegroundColor White
    }
}

Write-Host ""
Start-Sleep -Seconds 2

# Summary
Write-Host "═══ Summary: Key Features ═══" -ForegroundColor Yellow
Write-Host ""
Write-Host "✓ Cross-platform support (BITS on Windows, WebRequest elsewhere)" -ForegroundColor Green
Write-Host "✓ Automatic retry with exponential backoff" -ForegroundColor Green
Write-Host "✓ Intelligent caching (idempotent downloads)" -ForegroundColor Green
Write-Host "✓ Content-Length validation" -ForegroundColor Green
Write-Host "✓ Automatic cleanup of partial/corrupt files" -ForegroundColor Green
Write-Host "✓ Download resume capability (BITS on Windows)" -ForegroundColor Green
Write-Host "✓ No console progress bar flooding" -ForegroundColor Green
Write-Host "✓ Detailed logging and metrics" -ForegroundColor Green
Write-Host ""

Write-Host "═══ Documentation ═══" -ForegroundColor Yellow
Write-Host ""
Write-Host "For complete documentation, see:" -ForegroundColor Cyan
Write-Host "  • domains/utilities/README-DownloadUtility.md"
Write-Host "  • docs/DOWNLOAD-UTILITY-MIGRATION.md"
Write-Host ""

Write-Host "═══ Migration Example ═══" -ForegroundColor Yellow
Write-Host ""
Write-Host "Before:" -ForegroundColor Red
Write-Host '  $ProgressPreference = ''SilentlyContinue''' -ForegroundColor Gray
Write-Host '  Invoke-WebRequest -Uri $url -OutFile $file' -ForegroundColor Gray
Write-Host '  $ProgressPreference = ''Continue''' -ForegroundColor Gray
Write-Host ""
Write-Host "After:" -ForegroundColor Green
Write-Host '  $result = Invoke-FileDownload -Uri $url -OutFile $file' -ForegroundColor Gray
Write-Host '  if (-not $result.Success) { throw $result.Message }' -ForegroundColor Gray
Write-Host ""

Write-Host "Demonstration complete!" -ForegroundColor Cyan
Write-Host ""
