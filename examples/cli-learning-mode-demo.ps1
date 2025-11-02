#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Demo of CLI Learning Mode - Interactive teaching tool
.DESCRIPTION
    Demonstrates how the interactive menu now shows CLI commands for every action,
    helping users learn to use AitherZero from the command line
#>

$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$cliHelperPath = Join-Path $script:ProjectRoot "domains/experience/CLIHelper.psm1"

# Import module
Import-Module $cliHelperPath -Force

Clear-Host

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    AitherZero CLI Learning Mode Demo                      ║" -ForegroundColor Cyan
Write-Host "║    Interactive Teaching Tool                              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Like Active Directory Admin Center, AitherZero now shows   " -ForegroundColor White
Write-Host "  you the CLI commands for everything you do interactively!  " -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to continue"
Clear-Host

# Demo 1: CLI Command Display
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  Demo 1: CLI Command Display" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "When you select an action in the interactive menu," -ForegroundColor White
Write-Host "you'll see the exact CLI command that performs that action:" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to see example"

Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Run -Target 0402" -Description "Run unit tests from CLI"

Write-Host ""
Write-Host "💡 You can copy this command and run it directly!" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to continue"
Clear-Host

# Demo 2: Compact Mode
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  Demo 2: Compact Display" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "Commands can also be shown in a compact format:" -ForegroundColor White
Write-Host ""

Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick" -Compact

Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 3: Learning Mode
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  Demo 3: CLI Learning Mode" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "Enable CLI Learning Mode to see commands for EVERY action:" -ForegroundColor White
Write-Host ""

Enable-CLILearningMode

Write-Host ""
Write-Host "Now when you use the interactive menu:" -ForegroundColor Cyan
Write-Host "  1. Select an action" -ForegroundColor White
Write-Host "  2. See the CLI command displayed" -ForegroundColor White
Write-Host "  3. Press Enter to execute" -ForegroundColor White
Write-Host "  4. Learn as you go!" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to continue"

Write-Host ""
Write-Host "You can toggle it on/off anytime with 'L' in the main menu" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to continue"

Disable-CLILearningMode

Clear-Host

# Demo 4: Command Examples
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  Demo 4: Command Examples" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "Here are some examples of commands you'll learn:" -ForegroundColor White
Write-Host ""

Write-Host "📝 Testing:" -ForegroundColor Cyan
Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Sequence '0402'" -Compact

Write-Host ""
Write-Host "🎭 Playbooks:" -ForegroundColor Cyan
Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Orchestrate -Playbook 'infrastructure-lab'" -Compact

Write-Host ""
Write-Host "🔧 Infrastructure:" -ForegroundColor Cyan
Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Run -Target 0105" -Compact

Write-Host ""
Write-Host "📊 Reports:" -ForegroundColor Cyan
Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Run -Target 0510" -Compact

Write-Host ""
Write-Host "🔀 Git Automation:" -ForegroundColor Cyan
Show-CLICommand -Command "./Start-AitherZero.ps1 -Mode Run -Target 0701" -Compact

Write-Host ""
Read-Host "Press Enter to continue"
Clear-Host

# Demo 5: How to Use
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              How to Use CLI Learning Mode                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "🎯 " -NoNewline -ForegroundColor Yellow
Write-Host "In Interactive Mode:" -ForegroundColor White
Write-Host "   1. Start: " -NoNewline -ForegroundColor Gray
Write-Host "./Start-AitherZero.ps1 -Mode Interactive" -ForegroundColor Cyan

Write-Host "   2. Press " -NoNewline -ForegroundColor Gray
Write-Host "'L'" -NoNewline -ForegroundColor Yellow
Write-Host " to toggle learning mode" -ForegroundColor Gray

Write-Host "   3. Select any menu option" -ForegroundColor Gray
Write-Host "   4. See the CLI command displayed" -ForegroundColor Gray
Write-Host "   5. Press Enter to execute" -ForegroundColor Gray
Write-Host ""

Write-Host "🎓 " -NoNewline -ForegroundColor Yellow
Write-Host "From PowerShell:" -ForegroundColor White
Write-Host "   • Enable:  " -NoNewline -ForegroundColor Gray
Write-Host "Enable-CLILearningMode" -ForegroundColor Cyan
Write-Host "   • Disable: " -NoNewline -ForegroundColor Gray
Write-Host "Disable-CLILearningMode" -ForegroundColor Cyan
Write-Host "   • Check:   " -NoNewline -ForegroundColor Gray
Write-Host "Test-CLILearningMode" -ForegroundColor Cyan
Write-Host ""

Write-Host "💡 " -NoNewline -ForegroundColor Yellow
Write-Host "Pro Tips:" -ForegroundColor White
Write-Host "   • Learning mode is saved in your environment" -ForegroundColor Gray
Write-Host "   • Copy commands to build your own scripts" -ForegroundColor Gray
Write-Host "   • Use tab completion for parameters" -ForegroundColor Gray
Write-Host "   • Commands work outside interactive mode too!" -ForegroundColor Gray
Write-Host ""

Read-Host "Press Enter to continue"
Clear-Host

# Summary
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║                   Summary                                  ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

Write-Host "✅ New Features:" -ForegroundColor Green
Write-Host "   • CLI Command Display - See CLI for every action" -ForegroundColor White
Write-Host "   • Learning Mode - Toggle teaching mode on/off" -ForegroundColor White
Write-Host "   • Command Bar - Prominent display with descriptions" -ForegroundColor White
Write-Host "   • AD-Style Learning - Like AD Admin Center" -ForegroundColor White
Write-Host ""

Write-Host "🎯 Benefits:" -ForegroundColor Cyan
Write-Host "   • Learn CLI while using interactive mode" -ForegroundColor White
Write-Host "   • Build automation scripts easily" -ForegroundColor White
Write-Host "   • Discover command parameters" -ForegroundColor White
Write-Host "   • Transition from GUI to CLI smoothly" -ForegroundColor White
Write-Host ""

Write-Host "🚀 Get Started:" -ForegroundColor Yellow
Write-Host "   ./Start-AitherZero.ps1 -Mode Interactive" -ForegroundColor Cyan
Write-Host "   Press 'L' to enable learning mode" -ForegroundColor Gray
Write-Host ""

Write-Host "📚 Documentation:" -ForegroundColor Blue
Write-Host "   • User Guide: docs/CLI-MODERNIZATION.md" -ForegroundColor Gray
Write-Host "   • Examples: examples/cli-modernization-demo.ps1" -ForegroundColor Gray
Write-Host ""

Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "         Thank you for trying CLI Learning Mode!" -ForegroundColor Yellow
Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
