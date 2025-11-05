#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstration of BreadcrumbNavigation functionality
.DESCRIPTION
    Shows how breadcrumb navigation tracks the user's path
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     BreadcrumbNavigation Component Demonstration              ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Import the module
$modulePath = Join-Path $PSScriptRoot "domains/experience/Components/BreadcrumbNavigation.psm1"
Import-Module $modulePath -Force

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "1. Creating Navigation Stack" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$stack = New-BreadcrumbStack
Write-Host "`n✅ Created new breadcrumb stack" -ForegroundColor Green
Write-Host "   Depth: " -NoNewline -ForegroundColor White
Write-Host (Get-BreadcrumbDepth -Stack $stack) -ForegroundColor Cyan

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "2. Navigating Through Menus" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`nStarting at root:" -ForegroundColor White
Write-Host "  " -NoNewline
Show-Breadcrumb -Stack $stack -IncludeRoot

Write-Host "`nNavigating to 'Run' mode..." -ForegroundColor White
Push-Breadcrumb -Stack $stack -Name "Run" -Context @{ Mode = 'Run' }
Write-Host "  " -NoNewline
Show-Breadcrumb -Stack $stack -IncludeRoot

Write-Host "`nNavigating to 'Testing' category..." -ForegroundColor White
Push-Breadcrumb -Stack $stack -Name "Testing" -Context @{ Category = 'Testing' }
Write-Host "  " -NoNewline
Show-Breadcrumb -Stack $stack -IncludeRoot

Write-Host "`nNavigating to specific script..." -ForegroundColor White
Push-Breadcrumb -Stack $stack -Name "[0402] Run Unit Tests" -Context @{ ScriptNumber = '0402' }
Write-Host "  " -NoNewline
Show-Breadcrumb -Stack $stack -IncludeRoot

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "3. Going Back" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`nGoing back one level..." -ForegroundColor White
Pop-Breadcrumb -Stack $stack
Write-Host "  " -NoNewline
Show-Breadcrumb -Stack $stack -IncludeRoot

Write-Host "`nGoing back one more level..." -ForegroundColor White
Pop-Breadcrumb -Stack $stack
Write-Host "  " -NoNewline
Show-Breadcrumb -Stack $stack -IncludeRoot

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "4. Custom Separators" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Push-Breadcrumb -Stack $stack -Name "Testing"
Push-Breadcrumb -Stack $stack -Name "Unit Tests"

Write-Host "`nDefault separator ( > ):" -ForegroundColor White
$path1 = Get-BreadcrumbPath -Stack $stack -IncludeRoot
Write-Host "  $path1" -ForegroundColor Cyan

Write-Host "`nCustom separator ( / ):" -ForegroundColor White
$path2 = Get-BreadcrumbPath -Stack $stack -IncludeRoot -Separator " / "
Write-Host "  $path2" -ForegroundColor Cyan

Write-Host "`nCustom separator ( → ):" -ForegroundColor White
$path3 = Get-BreadcrumbPath -Stack $stack -IncludeRoot -Separator " → "
Write-Host "  $path3" -ForegroundColor Cyan

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "5. Current Context" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

$current = Get-CurrentBreadcrumb -Stack $stack
Write-Host "`nCurrent breadcrumb:" -ForegroundColor White
Write-Host "  Name: $($current.Name)" -ForegroundColor Cyan
Write-Host "  Context: $($current.Context | ConvertTo-Json -Compress)" -ForegroundColor Cyan

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "6. Clearing Navigation" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host "`nBefore clear:" -ForegroundColor White
Write-Host "  Depth: " -NoNewline -ForegroundColor White
Write-Host (Get-BreadcrumbDepth -Stack $stack) -ForegroundColor Cyan

Clear-BreadcrumbStack -Stack $stack
Write-Host "`nAfter clear:" -ForegroundColor White
Write-Host "  Depth: " -NoNewline -ForegroundColor White
Write-Host (Get-BreadcrumbDepth -Stack $stack) -ForegroundColor Cyan

Write-Host "`n╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║    BreadcrumbNavigation Demo Complete                         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
