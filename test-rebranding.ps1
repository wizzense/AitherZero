#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Test script to verify Aitherium rebranding and module functionality

.DESCRIPTION
    This script tests:
    - PowerShell Core installation
    - Pester and PSScriptAnalyzer availability
    - Core Aitherium modules loading
    - Basic functionality after rebranding
#>

Write-Host "🚀 Aitherium Infrastructure Automation - Post-Rebranding Test" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Test 1: PowerShell Version
Write-Host "`n🔍 Test 1: PowerShell Version" -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVersion" -ForegroundColor Green
if ($psVersion.Major -ge 7) {
    Write-Host "✅ PowerShell 7+ confirmed" -ForegroundColor Green
} else {
    Write-Host "❌ PowerShell 7+ required" -ForegroundColor Red
    exit 1
}

# Test 2: Required Modules
Write-Host "`n🔍 Test 2: Required Modules" -ForegroundColor Yellow
$requiredModules = @("Pester", "PSScriptAnalyzer")
foreach ($module in $requiredModules) {
    try {
        Import-Module $module -Force
        $version = (Get-Module $module).Version
        Write-Host "✅ $module v$version imported" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to import $module" -ForegroundColor Red
        exit 1
    }
}

# Test 3: Aitherium Modules
Write-Host "`n🔍 Test 3: Aitherium Core Modules" -ForegroundColor Yellow
$aitheriumModules = @("Logging", "DevEnvironment", "PatchManager", "BackupManager", "LabRunner")
$moduleResults = @{}

foreach ($module in $aitheriumModules) {
    try {
        $modulePath = "./aither-core/modules/$module"
        Import-Module $modulePath -Force
        $moduleInfo = Get-Module $module
        Write-Host "✅ $module v$($moduleInfo.Version) loaded" -ForegroundColor Green
        $moduleResults[$module] = $true
    } catch {
        Write-Host "❌ Failed to load $module`: $($_.Exception.Message)" -ForegroundColor Red
        $moduleResults[$module] = $false
    }
}

# Test 4: Module Manifest Validation
Write-Host "`n🔍 Test 4: Module Manifest Validation" -ForegroundColor Yellow
$manifestFiles = Get-ChildItem -Path "./aither-core/modules" -Filter "*.psd1" -Recurse
foreach ($manifest in $manifestFiles) {
    try {
        $manifestData = Test-ModuleManifest $manifest.FullName
        Write-Host "✅ $($manifest.Name) manifest valid" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($manifest.Name) manifest invalid: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test 5: Rebranding Check
Write-Host "`n🔍 Test 5: Rebranding Verification" -ForegroundColor Yellow
$rebrandingChecks = @{
    "README.md contains Aitherium" = (Get-Content "./README.md" -Raw) -match "Aitherium"
    "Core runner has Aitherium banner" = (Get-Content "./core-runner/core_app/core-runner.ps1" -Raw) -match "Aitherium"
    "LICENSE updated to Aitherium" = (Get-Content "./LICENSE" -Raw) -match "Aitherium Contributors"
}

foreach ($check in $rebrandingChecks.Keys) {
    if ($rebrandingChecks[$check]) {
        Write-Host "✅ $check" -ForegroundColor Green
    } else {
        Write-Host "❌ $check" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n📊 Summary" -ForegroundColor Cyan
$successfulModules = ($moduleResults.Values | Where-Object { $_ -eq $true }).Count
$totalModules = $moduleResults.Count
Write-Host "Modules loaded: $successfulModules/$totalModules" -ForegroundColor $(if ($successfulModules -eq $totalModules) { 'Green' } else { 'Yellow' })

if ($successfulModules -eq $totalModules) {
    Write-Host "`n🎉 All tests passed! Aitherium rebranding successful!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n⚠️  Some issues found. Review the output above." -ForegroundColor Yellow
    exit 1
}
