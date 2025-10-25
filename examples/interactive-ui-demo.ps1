#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Demonstration of the new interactive UI system
.DESCRIPTION
    Shows the new component-based, truly interactive UI system with arrow key navigation
#>

param(
    [switch]$UseClassic,
    [switch]$Debug
)

# Setup paths
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:UIPath = Join-Path $script:ProjectRoot "domains/experience"

# Import modules
try {
    # Import the main UI module
    Import-Module (Join-Path $script:UIPath "UserInterface.psm1") -Force

    # Force interactive mode unless classic is requested
    if (-not $UseClassic) {
        $env:AITHERZERO_USE_INTERACTIVE_UI = 'true'
    }

    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         AitherZero Interactive UI System Demo                 ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Demo 1: Simple Menu
    Write-Host "Demo 1: Simple Interactive Menu" -ForegroundColor Yellow
    Write-Host "Use arrow keys to navigate, Enter to select, ESC to cancel" -ForegroundColor DarkGray
    Write-Host ""

    $environments = @("Development", "Staging", "Production", "Testing", "Local")
    $selected = Show-UIMenu -Title "Select Environment" -Items $environments -ShowNumbers

    if ($selected) {
        Write-Host "`nYou selected: $selected" -ForegroundColor Green
    } else {
        Write-Host "`nMenu cancelled" -ForegroundColor Yellow
    }

    Write-Host "`nPress Enter to continue..." -ForegroundColor DarkGray
    Read-Host

    # Demo 2: Menu with Objects
    Clear-Host
    Write-Host "Demo 2: Menu with Complex Items" -ForegroundColor Yellow
    Write-Host ""

    $services = @(
        [PSCustomObject]@{ Name = "Web Server"; Description = "nginx v1.21.0"; Status = "Running" }
        [PSCustomObject]@{ Name = "Database"; Description = "PostgreSQL 14"; Status = "Running" }
        [PSCustomObject]@{ Name = "Cache"; Description = "Redis 6.2"; Status = "Stopped" }
        [PSCustomObject]@{ Name = "Message Queue"; Description = "RabbitMQ 3.9"; Status = "Running" }
        [PSCustomObject]@{ Name = "Search Engine"; Description = "Elasticsearch 7.15"; Status = "Running" }
    )

    $selected = Show-UIMenu -Title "Service Management" -Items $services

    if ($selected) {
        Write-Host "`nSelected service:" -ForegroundColor Green
        Write-Host "  Name: $($selected.Name)" -ForegroundColor White
        Write-Host "  Description: $($selected.Description)" -ForegroundColor Gray
        Write-Host "  Status: $($selected.Status)" -ForegroundColor $(if ($selected.Status -eq "Running") { "Green" } else { "Red" })
    }

    Write-Host "`nPress Enter to continue..." -ForegroundColor DarkGray
    Read-Host

    # Demo 3: Multi-Select Menu
    Clear-Host
    Write-Host "Demo 3: Multi-Select Menu" -ForegroundColor Yellow
    Write-Host "Use Space to select/deselect items" -ForegroundColor DarkGray
    Write-Host ""

    $features = @(
        "Code Analysis"
        "Auto-formatting"
        "Syntax Highlighting"
        "IntelliSense"
        "Debugging Tools"
        "Git Integration"
        "Terminal Integration"
        "Extension Support"
    )

    $selected = Show-UIMenu -Title "Select Features to Enable" -Items $features -MultiSelect -ShowNumbers

    if ($selected) {
        Write-Host "`nSelected features:" -ForegroundColor Green
        $selected | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    }

    Write-Host "`nPress Enter to continue..." -ForegroundColor DarkGray
    Read-Host

    # Demo 4: Large Menu with Scrolling
    Clear-Host
    Write-Host "Demo 4: Large Menu with Scrolling" -ForegroundColor Yellow
    Write-Host "Menu will scroll when you navigate beyond visible items" -ForegroundColor DarkGray
    Write-Host ""

    $scripts = 1..50 | ForEach-Object {
        "Script_{0:D4}.ps1" -f $_
    }

    $selected = Show-UIMenu -Title "Select Script (50 items)" -Items $scripts -ShowNumbers

    if ($selected) {
        Write-Host "`nYou selected: $selected" -ForegroundColor Green
    }

    Write-Host "`nPress Enter to continue..." -ForegroundColor DarkGray
    Read-Host

    # Demo 5: Menu with Custom Actions
    Clear-Host
    Write-Host "Demo 5: Menu with Custom Actions" -ForegroundColor Yellow
    Write-Host "Press 'H' for help, 'Q' to quit" -ForegroundColor DarkGray
    Write-Host ""

    $operations = @(
        "Install Dependencies"
        "Run Tests"
        "Build Project"
        "Deploy to Server"
        "View Logs"
    )

    $result = Show-UIMenu -Title "Operations Menu" -Items $operations -CustomActions @{
        'H' = 'Show Help'
        'Q' = 'Quit Application'
    }

    if ($result.Action) {
        Write-Host "`nCustom action triggered: $($result.Action)" -ForegroundColor Magenta
    } elseif ($result) {
        Write-Host "`nOperation selected: $result" -ForegroundColor Green
    }

    # Summary
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    Demo Complete!                             ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "The new interactive UI system provides:" -ForegroundColor Cyan
    Write-Host "  ✓ Real keyboard navigation (arrow keys, page up/down, home/end)" -ForegroundColor White
    Write-Host "  ✓ Multi-select support with Space key" -ForegroundColor White
    Write-Host "  ✓ Scrolling for large lists" -ForegroundColor White
    Write-Host "  ✓ Search/filter capability" -ForegroundColor White
    Write-Host "  ✓ Custom actions and hotkeys" -ForegroundColor White
    Write-Host "  ✓ Support for complex objects" -ForegroundColor White
    Write-Host "  ✓ Proper component architecture" -ForegroundColor White
    Write-Host "  ✓ Full test coverage" -ForegroundColor White
    Write-Host ""
    Write-Host "To use in your code:" -ForegroundColor Yellow
    Write-Host '  $selection = Show-UIMenu -Title "My Menu" -Items $items' -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host "Error running demo: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
} finally {
    # Cleanup
    $env:AITHERZERO_USE_INTERACTIVE_UI = $null
}