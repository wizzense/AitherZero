#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Test script for the interactive menu system
.DESCRIPTION
    This script tests the BetterMenu functionality in a controlled way
#>

# Force non-CI environment for testing
$env:CI = $null
$env:GITHUB_ACTIONS = $null
$env:AITHERZERO_NONINTERACTIVE = $null

# Import the BetterMenu module
$betterMenuPath = Join-Path $PSScriptRoot "domains/experience/BetterMenu.psm1"
Import-Module $betterMenuPath -Force

# Test data
$testItems = @(
    [PSCustomObject]@{
        Name = "Option 1"
        Description = "First test option"
    },
    [PSCustomObject]@{
        Name = "Option 2"
        Description = "Second test option"
    },
    [PSCustomObject]@{
        Name = "Option 3"
        Description = "Third test option"
    },
    [PSCustomObject]@{
        Name = "Exit Test"
        Description = "Exit the test menu"
    }
)

Write-Host "Testing BetterMenu functionality..." -ForegroundColor Cyan
Write-Host "Use arrow keys, j/k, or numbers to navigate. Press Enter to select." -ForegroundColor Yellow
Write-Host "Press 'q' or Escape to quit the test." -ForegroundColor Yellow
Write-Host ""

try {
    $selection = Show-BetterMenu -Title "Test Menu" -Items $testItems -ShowNumbers -CustomActions @{ 'Q' = 'Quit Test' }
    
    if ($selection) {
        if ($selection -is [hashtable] -and $selection.Action -eq 'Q') {
            Write-Host "Test quit by user" -ForegroundColor Yellow
        } else {
            Write-Host "Selected: $($selection.Name)" -ForegroundColor Green
            Write-Host "Description: $($selection.Description)" -ForegroundColor Gray
        }
    } else {
        Write-Host "No selection made" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error during menu test: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nMenu test completed." -ForegroundColor Cyan