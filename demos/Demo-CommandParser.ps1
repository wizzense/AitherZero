#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstration of CommandParser functionality
.DESCRIPTION
    Shows how commands are parsed, validated, and built
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        CommandParser Component Demonstration                  ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Import the module
$modulePath = Join-Path $PSScriptRoot "domains/experience/Components/CommandParser.psm1"
Import-Module $modulePath -Force

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "1. Parsing Full Commands" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$testCommands = @(
    "-Mode Run -Target 0402"
    "-Mode Orchestrate -Playbook test-quick"
    "-Mode Search -Query security"
)

foreach ($cmd in $testCommands) {
    Write-Host "`nInput: " -NoNewline -ForegroundColor White
    Write-Host $cmd -ForegroundColor Cyan
    
    $result = Parse-AitherCommand -CommandText $cmd
    
    if ($result.IsValid) {
        Write-Host "✅ Valid Command" -ForegroundColor Green
        Write-Host "  Mode: $($result.Mode)" -ForegroundColor White
        foreach ($key in $result.Parameters.Keys) {
            Write-Host "  $key`: $($result.Parameters[$key])" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Invalid: $($result.Error)" -ForegroundColor Red
    }
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "2. Shortcut Resolution" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$shortcuts = @("test", "lint", "0402", "quick-test")

foreach ($shortcut in $shortcuts) {
    Write-Host "`nShortcut: " -NoNewline -ForegroundColor White
    Write-Host $shortcut -ForegroundColor Cyan
    
    $result = Parse-AitherCommand -CommandText $shortcut
    
    if ($result.IsValid) {
        Write-Host "✅ Resolves to:" -ForegroundColor Green
        $fullCmd = Build-AitherCommand -Mode $result.Mode -Parameters $result.Parameters
        Write-Host "  $fullCmd" -ForegroundColor Yellow
    }
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "3. Command Suggestions" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$partialCommands = @("-Mode R", "-Mode Run ")

foreach ($partial in $partialCommands) {
    Write-Host "`nPartial: " -NoNewline -ForegroundColor White
    Write-Host $partial -ForegroundColor Cyan
    
    $suggestions = Get-CommandSuggestions -PartialCommand $partial
    Write-Host "💡 Suggestions: " -NoNewline -ForegroundColor White
    Write-Host ($suggestions -join ", ") -ForegroundColor Yellow
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "4. Error Handling" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$invalidCommands = @(
    "-Mode Run"
    "-Mode InvalidMode"
    "random text"
)

foreach ($cmd in $invalidCommands) {
    Write-Host "`nInput: " -NoNewline -ForegroundColor White
    Write-Host $cmd -ForegroundColor Cyan
    
    $result = Parse-AitherCommand -CommandText $cmd
    
    if (-not $result.IsValid) {
        Write-Host "❌ Error: " -NoNewline -ForegroundColor Red
        Write-Host $result.Error -ForegroundColor Yellow
    }
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "5. Building Commands" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`nBuilding from components:" -ForegroundColor White
$cmd = Build-AitherCommand -Mode 'Run' -Parameters @{ Target = '0402' }
Write-Host "  Mode: Run, Target: 0402" -ForegroundColor Cyan
Write-Host "  Result: " -NoNewline -ForegroundColor White
Write-Host $cmd -ForegroundColor Yellow

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        CommandParser Demo Complete                            ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
