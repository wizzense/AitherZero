#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Example extension setup script
.DESCRIPTION
    Demonstrates a numbered automation script from an extension
.NOTES
    Stage: Setup
    Dependencies: None
    Tags: Example, Extension, Setup
#>

param()

Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           Example Extension - Setup Script (8000)             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "🔧 Running example extension setup..." -ForegroundColor Green

# Example setup tasks
$tasks = @(
    "Creating extension directories..."
    "Checking dependencies..."
    "Configuring extension..."
    "Initializing data storage..."
    "Setup completed!"
)

foreach ($task in $tasks) {
    Write-Host "   $task" -ForegroundColor White
    Start-Sleep -Milliseconds 300
}

Write-Host "`n✅ Example extension setup completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run script 8001 to check status: " -NoNewline -ForegroundColor White
Write-Host "./Start-AitherZero.ps1 -Mode Run -Target 8001" -ForegroundColor Cyan
Write-Host "  2. Use Example mode: " -NoNewline -ForegroundColor White
Write-Host "./Start-AitherZero.ps1 -Mode Example -Target demo -Action run" -ForegroundColor Cyan
Write-Host "  3. Use commands: " -NoNewline -ForegroundColor White
Write-Host "Get-ExampleData" -ForegroundColor Cyan
Write-Host ""
