#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates the configuration management and extension system
.DESCRIPTION
    Shows how config drives the CLI/UI and how to switch configurations
#>

param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# Import modules
$projectRoot = $PSScriptRoot
Import-Module (Join-Path $projectRoot "domains/utilities/ExtensionManager.psm1") -Force
Import-Module (Join-Path $projectRoot "domains/configuration/ConfigManager.psm1") -Force

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    AitherZero - Config-Driven System Demonstration            ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Section 1: Configuration Discovery
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "1. Configuration Discovery" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

Initialize-ConfigManager
$configs = Get-AvailableConfigurations

Write-Host "Found $($configs.Count) configuration(s):" -ForegroundColor White
Write-Host ""

foreach ($config in $configs) {
    $marker = if ($config.Current) { "►" } else { " " }
    $color = if ($config.Current) { "Green" } else { "White" }
    
    Write-Host "  $marker $($config.Name)" -ForegroundColor $color
    Write-Host "    Profile: $($config.Profile)" -ForegroundColor DarkGray
    Write-Host "    Environment: $($config.Environment)" -ForegroundColor DarkGray
    Write-Host "    Last Modified: $($config.LastModified.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray
    Write-Host ""
}

# Section 2: Current Configuration
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "2. Current Configuration" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

$current = Get-CurrentConfiguration

Write-Host "Active Configuration: " -NoNewline -ForegroundColor White
Write-Host $current.Name -ForegroundColor Cyan
Write-Host "Profile: " -NoNewline -ForegroundColor White
Write-Host $current.Profile -ForegroundColor Yellow
Write-Host "Environment: " -NoNewline -ForegroundColor White
Write-Host $current.Environment -ForegroundColor Yellow
Write-Host "Version: " -NoNewline -ForegroundColor White
Write-Host $current.Version -ForegroundColor Yellow
Write-Host "Loaded: " -NoNewline -ForegroundColor White
Write-Host $current.LoadedAt.ToString('yyyy-MM-dd HH:mm:ss') -ForegroundColor Yellow

# Section 3: Manifest Capabilities
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "3. Capabilities from Manifest" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

$capabilities = Get-ManifestCapabilities

Write-Host "CLI Modes ($($capabilities.Modes.Count)):" -ForegroundColor Cyan
foreach ($mode in $capabilities.Modes) {
    Write-Host "  • $mode" -ForegroundColor White
}

Write-Host "`nEnabled Features ($($capabilities.Features.Count)):" -ForegroundColor Cyan
foreach ($feature in $capabilities.Features.Keys | Select-Object -First 10) {
    Write-Host "  • $feature" -ForegroundColor White
}

if ($capabilities.Features.Count -gt 10) {
    Write-Host "  ... and $($capabilities.Features.Count - 10) more" -ForegroundColor DarkGray
}

if ($capabilities.Extensions.Count -gt 0) {
    Write-Host "`nEnabled Extensions ($($capabilities.Extensions.Count)):" -ForegroundColor Cyan
    foreach ($ext in $capabilities.Extensions) {
        Write-Host "  • $ext" -ForegroundColor White
    }
}

# Section 4: Config-Driven UI Example
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "4. Config-Driven UI Example" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

Write-Host "The UI/CLI automatically adapts based on config.psd1:" -ForegroundColor White
Write-Host ""

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor DarkGray
Write-Host "║                  AitherZero Main Menu                          ║" -ForegroundColor DarkGray
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor DarkGray
Write-Host ""

$modeIndex = 1
foreach ($mode in $capabilities.Modes) {
    $icon = switch ($mode) {
        'Run' { '🎯' }
        'Orchestrate' { '📚' }
        'Search' { '🔍' }
        'List' { '📋' }
        'Test' { '✅' }
        'Validate' { '🔧' }
        default { '📌' }
    }
    
    Write-Host "  [$modeIndex] $icon $mode" -ForegroundColor Cyan
    $modeIndex++
}

Write-Host ""
Write-Host "  Menu items auto-generated from manifest capabilities!" -ForegroundColor Green

# Section 6: Usage Examples
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "6. Usage Examples" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Switch Configuration:" -ForegroundColor Cyan
Write-Host "  Show-ConfigurationSelector                 # Interactive selector" -ForegroundColor White
Write-Host "  Switch-Configuration -ConfigName 'config.example'" -ForegroundColor White
Write-Host ""

Write-Host "Edit Configuration:" -ForegroundColor Cyan
Write-Host "  Edit-Configuration                          # Edit current config" -ForegroundColor White
Write-Host "  Edit-Configuration -ConfigName 'config.example'" -ForegroundColor White
Write-Host ""

Write-Host "Create New Configuration:" -ForegroundColor Cyan
Write-Host "  Export-ConfigurationTemplate -OutputPath './config.dev.psd1' -Profile 'Developer'" -ForegroundColor White
Write-Host ""

Write-Host "Validate Configuration:" -ForegroundColor Cyan
Write-Host "  Test-ConfigurationValidity -Path './config.psd1'" -ForegroundColor White
Write-Host ""

Write-Host "Extension Management:" -ForegroundColor Cyan
Write-Host "  New-ExtensionTemplate -Name 'MyExtension' -Path './extensions'" -ForegroundColor White
Write-Host "  Import-Extension -Name 'ExampleExtension'" -ForegroundColor White
Write-Host "  Get-AvailableExtensions -LoadedOnly" -ForegroundColor White
Write-Host ""

# Summary
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "Summary" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

Write-Host "✅ Configuration system initialized" -ForegroundColor Green
Write-Host "✅ Manifest capabilities extracted" -ForegroundColor Green
Write-Host "✅ Extension system ready" -ForegroundColor Green
Write-Host "✅ UI/CLI driven by config.psd1" -ForegroundColor Green
Write-Host ""

Write-Host "Key Benefits:" -ForegroundColor Cyan
Write-Host "  • Single source of truth (config.psd1)" -ForegroundColor White
Write-Host "  • Easy config switching" -ForegroundColor White
Write-Host "  • UI automatically adapts" -ForegroundColor White
Write-Host "  • Extensible via extensions/" -ForegroundColor White
Write-Host "  • No hardcoded values" -ForegroundColor White
Write-Host ""

Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Demo Complete!                                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
