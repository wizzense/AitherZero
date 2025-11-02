#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Demo script showcasing the modernized CLI features
.DESCRIPTION
    Demonstrates the new help system, version display, and command cards
#>

$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$cliHelperPath = Join-Path $script:ProjectRoot "domains/experience/CLIHelper.psm1"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    AitherZero CLI Modernization Demo                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Import module
Import-Module $cliHelperPath -Force

# Demo 1: Version Info
Write-Host "📍 Demo 1: Modern Version Display" -ForegroundColor Yellow
Write-Host "  Command: " -NoNewline -ForegroundColor Gray
Write-Host "./Start-AitherZero.ps1 -Version" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to show version info"
Show-VersionInfo
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 2: Quick Help
Write-Host "📍 Demo 2: Quick Start Help" -ForegroundColor Yellow
Write-Host "  Command: " -NoNewline -ForegroundColor Gray
Write-Host "./Start-AitherZero.ps1 -Help (quick mode)" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter to show quick help"
Show-ModernHelp -HelpType quick
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 3: Command Reference
Write-Host "📍 Demo 3: Command Reference" -ForegroundColor Yellow
Write-Host "  All available commands with descriptions" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to show commands"
Show-ModernHelp -HelpType commands
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 4: Examples
Write-Host "📍 Demo 4: Common Examples" -ForegroundColor Yellow
Write-Host "  Real-world usage examples grouped by category" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to show examples"
Show-ModernHelp -HelpType examples
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 5: Script Categories
Write-Host "📍 Demo 5: Script Categories" -ForegroundColor Yellow
Write-Host "  Understanding the 0000-9999 numbering system" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to show categories"
Show-ModernHelp -HelpType scripts
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 6: Command Cards
Write-Host "📍 Demo 6: Quick Reference Cards" -ForegroundColor Yellow
Write-Host "  Focused quick reference for specific tasks" -ForegroundColor Gray
Write-Host ""

Write-Host "Testing Commands Card:" -ForegroundColor Cyan
Read-Host "Press Enter to show"
Show-CommandCard -CardType testing
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

Write-Host "Git Automation Commands Card:" -ForegroundColor Cyan
Read-Host "Press Enter to show"
Show-CommandCard -CardType git
Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Summary
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Demo Complete!                                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✨ Modern CLI Features Added:" -ForegroundColor Cyan
Write-Host "  ✅ Rich, formatted help system with emojis and colors" -ForegroundColor White
Write-Host "  ✅ Comprehensive version display with system info" -ForegroundColor White
Write-Host "  ✅ Multiple help types (quick, commands, examples, scripts)" -ForegroundColor White
Write-Host "  ✅ Quick reference cards for common tasks" -ForegroundColor White
Write-Host "  ✅ Consistent, professional CLI styling" -ForegroundColor White
Write-Host "  ✅ Beginner-friendly with clear examples" -ForegroundColor White
Write-Host ""
Write-Host "💡 Try it yourself:" -ForegroundColor Yellow
Write-Host "  ./Start-AitherZero.ps1 -Version" -ForegroundColor Gray
Write-Host "  ./Start-AitherZero.ps1 -Help" -ForegroundColor Gray
Write-Host ""
Write-Host "📚 Next improvements planned:" -ForegroundColor Yellow
Write-Host "  • Git-style subcommands" -ForegroundColor Gray
Write-Host "  • Command aliases and shortcuts" -ForegroundColor Gray
Write-Host "  • Improved tab completion" -ForegroundColor Gray
Write-Host "  • Interactive command builder" -ForegroundColor Gray
Write-Host ""
