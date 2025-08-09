#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Test the improved menu system
.DESCRIPTION
    Tests the new better menu with proper keyboard navigation
#>

# Setup paths
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "Testing Better Menu System" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host ""

# Import the module
Import-Module "$script:ProjectRoot/domains/experience/BetterMenu.psm1" -Force

# Test 1: Simple menu
Write-Host "Test 1: Simple Menu" -ForegroundColor Yellow
Write-Host "Use arrow keys or j/k to navigate, Enter to select, Esc/q to cancel" -ForegroundColor DarkGray
Write-Host ""

$items = @("Option 1", "Option 2", "Option 3", "Option 4", "Option 5")
$selected = Show-BetterMenu -Title "Simple Menu Test" -Items $items -ShowNumbers

if ($selected) {
    Write-Host "`nYou selected: $selected" -ForegroundColor Green
} else {
    Write-Host "`nCancelled" -ForegroundColor Yellow
}

Write-Host "`nPress Enter to continue to next test..." -ForegroundColor DarkGray
Read-Host

# Test 2: Menu with objects
Clear-Host
Write-Host "Test 2: Menu with Complex Objects" -ForegroundColor Yellow
Write-Host ""

$services = @(
    [PSCustomObject]@{ Name = "Web Server"; Description = "nginx - Running on port 80" }
    [PSCustomObject]@{ Name = "Database"; Description = "PostgreSQL 14 - Running" }
    [PSCustomObject]@{ Name = "Cache"; Description = "Redis 6.2 - Stopped" }
    [PSCustomObject]@{ Name = "Queue"; Description = "RabbitMQ - Running" }
    [PSCustomObject]@{ Name = "Search"; Description = "Elasticsearch - Running" }
)

$selected = Show-BetterMenu -Title "Service Manager" -Items $services

if ($selected) {
    Write-Host "`nSelected service:" -ForegroundColor Green
    Write-Host "  Name: $($selected.Name)" -ForegroundColor White
    Write-Host "  Description: $($selected.Description)" -ForegroundColor Gray
}

Write-Host "`nPress Enter to continue to next test..." -ForegroundColor DarkGray
Read-Host

# Test 3: Long list with scrolling
Clear-Host
Write-Host "Test 3: Long List with Scrolling" -ForegroundColor Yellow
Write-Host "This will show scroll indicators and page navigation" -ForegroundColor DarkGray
Write-Host ""

$longList = 1..50 | ForEach-Object { "Item $_" }
$selected = Show-BetterMenu -Title "Long List (50 items)" -Items $longList -ShowNumbers

if ($selected) {
    Write-Host "`nYou selected: $selected" -ForegroundColor Green
}

Write-Host "`nPress Enter to continue to next test..." -ForegroundColor DarkGray
Read-Host

# Test 4: Multi-select
Clear-Host
Write-Host "Test 4: Multi-Select Menu" -ForegroundColor Yellow
Write-Host "Use Space to toggle selection, Enter when done" -ForegroundColor DarkGray
Write-Host ""

$features = @(
    "Feature A"
    "Feature B"
    "Feature C"
    "Feature D"
    "Feature E"
)

$selected = Show-BetterMenu -Title "Select Features" -Items $features -MultiSelect -ShowNumbers

if ($selected) {
    Write-Host "`nYou selected:" -ForegroundColor Green
    $selected | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
}

Write-Host "`nPress Enter to continue to next test..." -ForegroundColor DarkGray
Read-Host

# Test 5: Custom actions
Clear-Host
Write-Host "Test 5: Menu with Custom Actions" -ForegroundColor Yellow
Write-Host ""

$items = @("Start", "Stop", "Restart", "Status")
$result = Show-BetterMenu -Title "Service Control" -Items $items -CustomActions @{
    'H' = 'Help'
    'R' = 'Refresh'
    'Q' = 'Quit'
}

if ($result -is [hashtable] -and $result.Action) {
    Write-Host "`nCustom action: $($result.Action)" -ForegroundColor Magenta
} elseif ($result) {
    Write-Host "`nSelected: $result" -ForegroundColor Green
} else {
    Write-Host "`nCancelled" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "Better Menu Features:" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Arrow keys (↑/↓) for navigation" -ForegroundColor Green
Write-Host "✓ Vim-style keys (j/k) for navigation" -ForegroundColor Green
Write-Host "✓ Page Up/Down for fast scrolling" -ForegroundColor Green
Write-Host "✓ Home/End to jump to first/last" -ForegroundColor Green
Write-Host "✓ Number keys for quick jump (1-99)" -ForegroundColor Green
Write-Host "✓ Letter keys to jump to items" -ForegroundColor Green
Write-Host "✓ Space for multi-select" -ForegroundColor Green
Write-Host "✓ Single Enter to select" -ForegroundColor Green
Write-Host "✓ Escape or q to cancel" -ForegroundColor Green
Write-Host "✓ Visual highlighting of current item" -ForegroundColor Green
Write-Host "✓ Scroll indicators for long lists" -ForegroundColor Green
Write-Host "✓ Position indicator [x of y]" -ForegroundColor Green
Write-Host ""