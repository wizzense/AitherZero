#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Final verification test matching the exact problem statement
.DESCRIPTION
    Tests the exact command from the problem statement: Invoke-AitherSequence 0500,0501
#>

$ErrorActionPreference = 'Stop'

Write-Host "`n=== Final Verification Test ===" -ForegroundColor Cyan
Write-Host "Testing: Invoke-AitherSequence 0500,0501`n" -ForegroundColor Yellow

# Set environment
$env:AITHERZERO_SUPPRESS_BANNER = '1'
$env:AITHERZERO_NONINTERACTIVE = '1'

# Get project root
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import module
Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force -ErrorAction Stop

Write-Host "Running: Invoke-AitherSequence 0500,0501 -DryRun`n" -ForegroundColor Cyan

try {
    # This is the exact syntax from the problem statement
    Invoke-AitherSequence 0500,0501 -DryRun
    
    Write-Host "`n✓ SUCCESS! The command works without errors." -ForegroundColor Green
    Write-Host "✓ Problem is fixed: Array syntax (0500,0501) is now supported.`n" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "`n✗ FAILED! Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nThe problem is NOT fixed.`n" -ForegroundColor Red
    exit 1
}
