#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Example extension status script
.DESCRIPTION
    Shows status of the example extension
.NOTES
    Stage: Status
    Dependencies: 8000
    Tags: Example, Extension, Status
#>

param()

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          Example Extension - Status Script (8001)             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📊 Example Extension Status" -ForegroundColor Green
Write-Host ""

Write-Host "Extension Name:    " -NoNewline -ForegroundColor White
Write-Host "ExampleExtension" -ForegroundColor Cyan

Write-Host "Version:           " -NoNewline -ForegroundColor White
Write-Host "1.0.0" -ForegroundColor Cyan

Write-Host "Status:            " -NoNewline -ForegroundColor White
Write-Host "Loaded ✓" -ForegroundColor Green

Write-Host "Scripts Available: " -NoNewline -ForegroundColor White
Write-Host "8000, 8001" -ForegroundColor Cyan

Write-Host "Commands:          " -NoNewline -ForegroundColor White
Write-Host "Get-ExampleData, Invoke-ExampleTask" -ForegroundColor Cyan

Write-Host "CLI Modes:         " -NoNewline -ForegroundColor White
Write-Host "Example" -ForegroundColor Cyan

Write-Host ""
Write-Host "✅ Extension is functioning correctly" -ForegroundColor Green
Write-Host ""
