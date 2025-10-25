#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Quick demo of the improved menu system
.DESCRIPTION
    Shows the better menu in action with arrow key navigation
#>

$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import modules
Import-Module "$script:ProjectRoot/domains/experience/UserInterface.psm1" -Force

Clear-Host
Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║           BETTER MENU SYSTEM - NOW WORKING!                 ║
╚══════════════════════════════════════════════════════════════╝

The menu system has been fixed with REAL keyboard navigation:

✓ Arrow Keys (↑/↓) - Navigate up and down
✓ j/k - Vim-style navigation
✓ Enter - Select item (SINGLE press!)
✓ Numbers - Jump to item (1-99)
✓ Letters - Jump to first item with that letter
✓ Page Up/Down - Fast scrolling
✓ Home/End - Jump to first/last
✓ Escape/q - Cancel

Let's try it!

"@ -ForegroundColor Cyan

Write-Host "Press Enter to see the menu in action..." -ForegroundColor Yellow
Read-Host

# Demo the menu
$items = @(
    [PSCustomObject]@{ Name = "Quick Setup"; Description = "Run profile-based setup" }
    [PSCustomObject]@{ Name = "Run Tests"; Description = "Execute test suites" }
    [PSCustomObject]@{ Name = "Deploy"; Description = "Deploy to environment" }
    [PSCustomObject]@{ Name = "Git Operations"; Description = "Branch, commit, PR" }
    [PSCustomObject]@{ Name = "Infrastructure"; Description = "Manage infrastructure" }
    [PSCustomObject]@{ Name = "Documentation"; Description = "Generate docs" }
    [PSCustomObject]@{ Name = "Settings"; Description = "Configure system" }
)

$selected = Show-UIMenu -Title "AitherZero Main Menu" -Items $items -ShowNumbers

if ($selected) {
    Write-Host "`n✅ You selected: $($selected.Name)" -ForegroundColor Green
    Write-Host "   $($selected.Description)" -ForegroundColor DarkGray
} else {
    Write-Host "`n❌ Menu cancelled" -ForegroundColor Yellow
}

Write-Host "`nThe menu now:" -ForegroundColor Cyan
Write-Host "• Actually responds to arrow keys" -ForegroundColor White
Write-Host "• Works with single Enter press" -ForegroundColor White
Write-Host "• Shows visual feedback (► marker)" -ForegroundColor White
Write-Host "• Supports number shortcuts" -ForegroundColor White
Write-Host "• Has smooth scrolling for long lists" -ForegroundColor White
Write-Host ""