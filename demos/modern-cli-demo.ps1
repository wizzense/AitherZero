#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Demo script for the new AitherZero Modern CLI
.DESCRIPTION
    Demonstrates the smooth, interactive, and scriptable CLI interface
#>

param(
    [switch]$SkipInteractive,
    [switch]$QuickDemo
)

# Setup
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:ModernCLI = Join-Path $script:ProjectRoot "az-modern.ps1"

function Write-DemoHeader {
    param([string]$Title)
    
    Write-Host "`n" -NoNewline
    Write-Host "╔" -ForegroundColor Cyan -NoNewline
    Write-Host ("═" * ($Title.Length + 2)) -ForegroundColor Cyan -NoNewline
    Write-Host "╗" -ForegroundColor Cyan
    Write-Host "║ $Title ║" -ForegroundColor Cyan
    Write-Host "╚" -ForegroundColor Cyan -NoNewline
    Write-Host ("═" * ($Title.Length + 2)) -ForegroundColor Cyan -NoNewline
    Write-Host "╝" -ForegroundColor Cyan
    Write-Host ""
}

function Wait-ForUser {
    param([string]$Message = "Press Enter to continue...")
    if (-not $QuickDemo) {
        Write-Host $Message -ForegroundColor DarkGray
        Read-Host | Out-Null
    } else {
        Start-Sleep -Seconds 1
    }
}

try {
    Clear-Host
    
    Write-Host "🚀 AitherZero Modern CLI Demo" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host "This demo showcases the new modern CLI interface that addresses" -ForegroundColor White
    Write-Host "the issues with the current 'clunky and buggy' UI system." -ForegroundColor White
    Write-Host ""
    Write-Host "Key Improvements:" -ForegroundColor Yellow
    Write-Host "  ✓ Intuitive command patterns (az action target)" -ForegroundColor Green
    Write-Host "  ✓ Interactive fuzzy search navigation" -ForegroundColor Green  
    Write-Host "  ✓ Full scriptability for CI/CD workflows" -ForegroundColor Green
    Write-Host "  ✓ Consistent UX across all operations" -ForegroundColor Green
    Write-Host "  ✓ Real-time feedback and progress" -ForegroundColor Green
    Write-Host "  ✓ Zero-config setup" -ForegroundColor Green
    
    Wait-ForUser
    
    # Demo 1: Basic Help and Commands
    Write-DemoHeader "Demo 1: Command Discovery & Help"
    
    Write-Host "Let's start with basic help:" -ForegroundColor White
    Write-Host "> az-modern help" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI help
    
    Wait-ForUser
    
    # Demo 2: Listing Resources  
    Write-DemoHeader "Demo 2: Discovering Available Resources"
    
    Write-Host "List all automation scripts:" -ForegroundColor White
    Write-Host "> az-modern list scripts" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI list scripts
    
    Wait-ForUser "`nPress Enter to see playbooks..."
    
    Write-Host "List all playbooks (organized by category):" -ForegroundColor White
    Write-Host "> az-modern list playbooks" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI list playbooks
    
    Wait-ForUser
    
    # Demo 3: Search Functionality
    Write-DemoHeader "Demo 3: Powerful Search"
    
    Write-Host "Search for test-related items:" -ForegroundColor White
    Write-Host "> az-modern search test" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI search test
    
    Wait-ForUser "`nPress Enter to search for security items..."
    
    Write-Host "Search for security-related items:" -ForegroundColor White
    Write-Host "> az-modern search security" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI search security
    
    Wait-ForUser
    
    # Demo 4: Configuration
    Write-DemoHeader "Demo 4: Configuration Management"
    
    Write-Host "Show current configuration:" -ForegroundColor White
    Write-Host "> az-modern config get" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI config get
    
    Wait-ForUser "`nPress Enter to change theme..."
    
    Write-Host "Change theme to dark mode:" -ForegroundColor White
    Write-Host "> az-modern config set theme dark" -ForegroundColor Gray
    Write-Host ""
    
    & $script:ModernCLI config set theme dark
    
    Wait-ForUser
    
    # Demo 5: Script Execution (if not in CI)
    if ($env:CI -ne 'true' -and $env:GITHUB_ACTIONS -ne 'true') {
        Write-DemoHeader "Demo 5: Direct Script Execution"
        
        Write-Host "Execute a script directly (simulated):" -ForegroundColor White
        Write-Host "> az-modern run script 0402" -ForegroundColor Gray
        Write-Host ""
        Write-Host "[In a real environment, this would run the unit tests]" -ForegroundColor Yellow
        Write-Host "✓ Script 0402 executed successfully" -ForegroundColor Green
        
        Wait-ForUser
    }
    
    # Demo 6: Interactive Features (if not skipped)
    if (-not $SkipInteractive -and [Environment]::UserInteractive -and $env:CI -ne 'true') {
        Write-DemoHeader "Demo 6: Interactive Playbook Selection"
        
        Write-Host "Interactive playbook selection with fuzzy search:" -ForegroundColor White
        Write-Host "> az-modern run playbook" -ForegroundColor Gray
        Write-Host ""
        Write-Host "This would open an interactive fuzzy search menu where you can:" -ForegroundColor Yellow
        Write-Host "  • Type to filter playbooks in real-time" -ForegroundColor White
        Write-Host "  • Use arrow keys to navigate" -ForegroundColor White
        Write-Host "  • Press Enter to select or Esc to cancel" -ForegroundColor White
        Write-Host "  • See descriptions and categories" -ForegroundColor White
        
        Wait-ForUser
    }
    
    # Demo 7: CI/CD Usage
    Write-DemoHeader "Demo 7: CI/CD Integration"
    
    Write-Host "Perfect for CI/CD workflows with clear, scriptable commands:" -ForegroundColor White
    Write-Host ""
    Write-Host "# Run specific test sequence" -ForegroundColor Green
    Write-Host "az-modern run sequence 0400-0499" -ForegroundColor Gray
    Write-Host ""
    Write-Host "# Execute specific playbook" -ForegroundColor Green  
    Write-Host "az-modern run playbook tech-debt-analysis" -ForegroundColor Gray
    Write-Host ""
    Write-Host "# Check available resources" -ForegroundColor Green
    Write-Host "az-modern list scripts" -ForegroundColor Gray
    Write-Host ""
    Write-Host "# Search for specific functionality" -ForegroundColor Green
    Write-Host "az-modern search deploy" -ForegroundColor Gray
    
    Wait-ForUser
    
    # Demo 8: Legacy Compatibility
    Write-DemoHeader "Demo 8: Legacy Menu Compatibility"
    
    Write-Host "Full backward compatibility with existing menu system:" -ForegroundColor White
    Write-Host "> az-modern menu" -ForegroundColor Gray
    Write-Host ""
    Write-Host "[This would launch the existing Start-AitherZero.ps1 interactive menu]" -ForegroundColor Yellow
    Write-Host "✓ Legacy menu mode available for transition period" -ForegroundColor Green
    
    Wait-ForUser
    
    # Summary
    Write-DemoHeader "🎉 Demo Complete!"
    
    Write-Host "The AitherZero Modern CLI provides:" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔥 Smooth Interactive Experience:" -ForegroundColor Yellow
    Write-Host "   • Fuzzy search with real-time filtering" -ForegroundColor White
    Write-Host "   • Intuitive keyboard navigation" -ForegroundColor White
    Write-Host "   • Smart auto-completion" -ForegroundColor White
    Write-Host ""
    Write-Host "⚡ CI/CD Ready:" -ForegroundColor Yellow
    Write-Host "   • Clear, predictable command patterns" -ForegroundColor White
    Write-Host "   • Scriptable without user interaction" -ForegroundColor White
    Write-Host "   • Proper exit codes and error handling" -ForegroundColor White
    Write-Host ""
    Write-Host "🛠️ Developer Friendly:" -ForegroundColor Yellow
    Write-Host "   • Discoverable commands and help" -ForegroundColor White
    Write-Host "   • Consistent argument patterns" -ForegroundColor White
    Write-Host "   • Rich search and filtering" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Backward Compatible:" -ForegroundColor Yellow
    Write-Host "   • Works alongside existing UI" -ForegroundColor White
    Write-Host "   • Uses same underlying orchestration" -ForegroundColor White
    Write-Host "   • Gradual migration path" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Ready to try it? Run: " -ForegroundColor Cyan -NoNewline
    Write-Host "./az-modern.ps1" -ForegroundColor White -NoNewline
    Write-Host " in interactive mode!" -ForegroundColor Cyan
    
} catch {
    Write-Host "Demo error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    exit 1
}

Write-Host ""