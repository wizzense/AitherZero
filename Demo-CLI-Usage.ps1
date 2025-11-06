#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstration of unified CLI usage
.DESCRIPTION
    Shows how CLI commands work with the command parser
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          CLI Command Usage Demonstration                      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Import the module
$modulePath = Join-Path $PSScriptRoot "domains/experience/Components/CommandParser.psm1"
Import-Module $modulePath -Force

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Example CLI Commands" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$examples = @(
    @{
        Description = "Run a specific script"
        Command = "./Start-AitherZero.ps1 -Mode Run -Target 0402"
        Shortcut = "./Start-AitherZero.ps1 0402"
    }
    @{
        Description = "Run test suite"
        Command = "./Start-AitherZero.ps1 -Mode Run -Target `"0402,0404,0407`""
        Shortcut = "./Start-AitherZero.ps1 test"
    }
    @{
        Description = "Run linter"
        Command = "./Start-AitherZero.ps1 -Mode Run -Target 0404"
        Shortcut = "./Start-AitherZero.ps1 lint"
    }
    @{
        Description = "Run playbook"
        Command = "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick"
        Shortcut = "./Start-AitherZero.ps1 quick-test"
    }
    @{
        Description = "Search for security tools"
        Command = "./Start-AitherZero.ps1 -Mode Search -Query security"
        Shortcut = "(no shortcut)"
    }
)

foreach ($example in $examples) {
    Write-Host "`n📋 $($example.Description)" -ForegroundColor White
    Write-Host "   Full command:  " -NoNewline -ForegroundColor DarkGray
    Write-Host $example.Command -ForegroundColor Cyan
    Write-Host "   Shortcut:      " -NoNewline -ForegroundColor DarkGray
    Write-Host $example.Shortcut -ForegroundColor Yellow
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Parsing CLI Arguments" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`n🔍 Demonstrating command parsing:" -ForegroundColor White

$testCmds = @(
    "-Mode Run -Target 0402",
    "test",
    "0404"
)

foreach ($cmd in $testCmds) {
    Write-Host "`n  Input:  " -NoNewline -ForegroundColor DarkGray
    Write-Host $cmd -ForegroundColor Cyan
    
    $parsed = Parse-AitherCommand -CommandText $cmd
    
    if ($parsed.IsValid) {
        Write-Host "  ✅ Valid" -ForegroundColor Green
        Write-Host "  Mode:   " -NoNewline -ForegroundColor DarkGray
        Write-Host $parsed.Mode -ForegroundColor Yellow
        foreach ($key in $parsed.Parameters.Keys) {
            Write-Host "  $key`:  " -NoNewline -ForegroundColor DarkGray
            Write-Host $parsed.Parameters[$key] -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Invalid: $($parsed.Error)" -ForegroundColor Red
    }
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Command-Line to Menu Translation" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`n📊 How CLI maps to Interactive Menu:" -ForegroundColor White

$mappings = @(
    @{
        CLI = "-Mode Run"
        Menu = "Navigate: Main > Run"
    }
    @{
        CLI = "-Mode Run -Target 0402"
        Menu = "Navigate: Main > Run > Testing > [0402] Run Unit Tests"
    }
    @{
        CLI = "-Mode Orchestrate -Playbook test-quick"
        Menu = "Navigate: Main > Orchestrate > test-quick"
    }
)

foreach ($mapping in $mappings) {
    Write-Host "`n  CLI:   " -NoNewline -ForegroundColor DarkGray
    Write-Host $mapping.CLI -ForegroundColor Cyan
    Write-Host "  Menu:  " -NoNewline -ForegroundColor DarkGray
    Write-Host $mapping.Menu -ForegroundColor Yellow
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Learning Progression" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`n🎓 User Journey:" -ForegroundColor White
Write-Host ""
Write-Host "  Phase 1: New User" -ForegroundColor Cyan
Write-Host "    • Uses arrow keys in menu" -ForegroundColor White
Write-Host "    • Sees command: -Mode Run -Target 0402" -ForegroundColor DarkGray
Write-Host "    • Learns CLI structure naturally" -ForegroundColor White
Write-Host ""
Write-Host "  Phase 2: Learning User" -ForegroundColor Cyan
Write-Host "    • Types: -Mode Run" -ForegroundColor White
Write-Host "    • Menu completes with options" -ForegroundColor DarkGray
Write-Host "    • Faster than pure navigation" -ForegroundColor White
Write-Host ""
Write-Host "  Phase 3: Power User" -ForegroundColor Cyan
Write-Host "    • Skips menu entirely" -ForegroundColor White
Write-Host "    • Uses CLI directly: ./Start-AitherZero.ps1 test" -ForegroundColor DarkGray
Write-Host "    • Creates automation scripts" -ForegroundColor White

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              CLI Demo Complete                                ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
