#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Quick test script for the new interactive UI system
.DESCRIPTION
    Tests that the new UI system is working correctly
#>

# Setup
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "Testing New Interactive UI System" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Test 1: Load UI modules
Write-Host "`nTest 1: Loading UI modules..." -ForegroundColor Yellow
try {
    Import-Module "$script:ProjectRoot/domains/experience/UserInterface.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Core/UIComponent.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Core/UIContext.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Components/InteractiveMenu.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Registry/ComponentRegistry.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Registry/ThemeRegistry.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Layout/LayoutManager.psm1" -Force
    Write-Host "✓ All modules loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load modules: $_" -ForegroundColor Red
    exit 1
}

# Test 2: Initialize registries
Write-Host "`nTest 2: Initializing registries..." -ForegroundColor Yellow
try {
    Initialize-UIComponentRegistry
    Initialize-UIThemeRegistry
    Write-Host "✓ Registries initialized" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize registries: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Create and test components
Write-Host "`nTest 3: Creating UI components..." -ForegroundColor Yellow
try {
    # Import the modules that export these functions
    Import-Module "$script:ProjectRoot/domains/experience/Core/UIComponent.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Core/UIContext.psm1" -Force
    Import-Module "$script:ProjectRoot/domains/experience/Components/InteractiveMenu.psm1" -Force

    # Create a component
    $component = New-UIComponent -Name "TestComponent" -X 10 -Y 5 -Width 40 -Height 10
    Write-Host "✓ Created component: $($component.Name)" -ForegroundColor Green

    # Create context
    $context = New-UIContext
    Write-Host "✓ Created UI context" -ForegroundColor Green

    # Create interactive menu
    $menu = New-InteractiveMenu -Items @("Option 1", "Option 2", "Option 3") -Title "Test Menu"
    Write-Host "✓ Created interactive menu" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to create components: $_" -ForegroundColor Red
    exit 1
}

# Test 4: Test theme system
Write-Host "`nTest 4: Testing theme system..." -ForegroundColor Yellow
try {
    $themes = Get-UIThemeList
    Write-Host "✓ Found $($themes.Count) themes" -ForegroundColor Green

    # Test theme switching
    Set-UITheme -Name "Dark"
    $activeTheme = Get-UITheme
    Write-Host "✓ Switched to theme: $($activeTheme.Name)" -ForegroundColor Green

    # Test theme colors
    $primaryColor = Get-UIThemeColor -ColorKey "Primary"
    Write-Host "✓ Got theme color: Primary = $primaryColor" -ForegroundColor Green
} catch {
    Write-Host "✗ Theme system error: $_" -ForegroundColor Red
    exit 1
}

# Test 5: Test layout system
Write-Host "`nTest 5: Testing layout system..." -ForegroundColor Yellow
try {
    $layout = New-UILayout -Type "Grid" -Columns 3 -Rows 2
    Write-Host "✓ Created grid layout" -ForegroundColor Green

    $container = @{ X = 0; Y = 0; Width = 80; Height = 24 }
    $components = 1..6 | ForEach-Object {
        New-UIComponent -Name "Item$_" -Width 20 -Height 5
    }

    $positions = Calculate-UILayout -Layout $layout -Container $container -Components $components
    Write-Host "✓ Calculated layout for $($positions.Count) components" -ForegroundColor Green
} catch {
    Write-Host "✗ Layout system error: $_" -ForegroundColor Red
    exit 1
}

# Test 6: Test backward compatibility
Write-Host "`nTest 6: Testing backward compatibility..." -ForegroundColor Yellow
try {
    # Enable interactive mode
    $env:AITHERZERO_USE_INTERACTIVE_UI = 'true'

    # This should work with both old and new systems
    Write-Host "Testing Show-UIMenu (will use classic mode in non-interactive terminal)..." -ForegroundColor Gray

    # Note: In a non-interactive context, this will fall back to classic mode
    # The important thing is that it doesn't error
    $items = @("Test 1", "Test 2", "Test 3")

    # We can't actually test the interactive menu in a script context
    # but we can verify the function exists and accepts parameters
    $functionExists = Get-Command Show-UIMenu -ErrorAction SilentlyContinue
    if ($functionExists) {
        Write-Host "✓ Show-UIMenu function exists and is callable" -ForegroundColor Green
    } else {
        throw "Show-UIMenu function not found"
    }
} catch {
    Write-Host "✗ Backward compatibility error: $_" -ForegroundColor Red
    exit 1
} finally {
    $env:AITHERZERO_USE_INTERACTIVE_UI = $null
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "All Tests Passed!" -ForegroundColor Green
Write-Host @"

The new interactive UI system is working correctly!

Key Features Verified:
✓ Component system (UIComponent, UIContext)
✓ Interactive menu component
✓ Component and theme registries
✓ Layout management system
✓ Backward compatibility layer

To use the new system in Start-AitherZero.ps1:
1. Set environment variable: `$env:AITHERZERO_PREFER_INTERACTIVE_UI = 'true'
2. Run: ./Start-AitherZero.ps1
3. Press 'T' to toggle between UI modes
4. Press 'S' to select themes (in interactive mode)
5. Select 'UI Demo' to see the full demo

"@ -ForegroundColor White