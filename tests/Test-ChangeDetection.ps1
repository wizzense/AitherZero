#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
Test the package-aware CI change detection logic locally

.DESCRIPTION
This script simulates the GitHub Actions change detection logic to test
how different file changes would be categorized and what test level would
be assigned.

.EXAMPLE
./Test-ChangeDetection.ps1 -Files "aither-core/modules/LabRunner/Public/Start-Lab.ps1"
./Test-ChangeDetection.ps1 -Files "aither-core/modules/PatchManager/Public/Invoke-PatchWorkflow.ps1"
./Test-ChangeDetection.ps1 -Files "configs/default-config.json","README.md"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Files,
    
    [Parameter()]
    [switch]$ShowDetails
)

function Test-AffectsPackages {
    param([string]$File)
    
    switch -Wildcard ($File) {
        # Core application files
        "aither-core/aither-core.ps1" { return $true }
        "aither-core/modules/Logging/*" { return $true }
        "aither-core/modules/LabRunner/*" { return $true }
        "aither-core/modules/DevEnvironment/*" { return $true }
        "aither-core/modules/BackupManager/*" { return $true }
        "aither-core/modules/ScriptManager/*" { return $true }
        "aither-core/modules/UnifiedMaintenance/*" { return $true }
        "aither-core/modules/ParallelExecution/*" { return $true }
        "aither-core/shared/*" { return $true }
        
        # Runtime scripts (exclude dev/test/build)
        "aither-core/scripts/*" {
            if ($File -match "(test|dev|build)") { return $false }
            return $true
        }
        
        # Configuration templates
        "configs/default-config.json" { return $true }
        "configs/core-runner-config.json" { return $true }
        "configs/recommended-config.json" { return $true }
        
        # Infrastructure
        "opentofu/infrastructure/*" { return $true }
        "opentofu/providers/*" { return $true }
        "opentofu/modules/*" { return $true }
        
        # Documentation in packages
        "README.md" { return $true }
        "LICENSE" { return $true }
        
        # Launcher templates
        "templates/launchers/*" { return $true }
        
        default { return $false }
    }
}

function Get-ChangeCategory {
    param([string]$File)
    
    switch -Wildcard ($File) {
        # Core runtime-critical files
        "aither-core/aither-core.ps1" { return "core" }
        "aither-core/modules/Logging/*" { return "core" }
        "aither-core/modules/LabRunner/*" { return "core" }
        "aither-core/modules/BackupManager/*" { return "core" }
        "aither-core/modules/ScriptManager/*" { return "core" }
        "aither-core/modules/UnifiedMaintenance/*" { return "core" }
        "aither-core/modules/ParallelExecution/*" { return "core" }
        
        # PatchManager and dev tools
        "aither-core/modules/PatchManager/*" { return "patchmanager" }
        "aither-core/modules/TestingFramework/*" { return "patchmanager" }
        "aither-core/modules/ISOManager/*" { return "patchmanager" }
        "aither-core/modules/ISOCustomizer/*" { return "patchmanager" }
        "aither-core/modules/RemoteConnection/*" { return "patchmanager" }
        "aither-core/modules/SecureCredentials/*" { return "patchmanager" }
        "aither-core/modules/OpenTofuProvider/*" { return "patchmanager" }
        "aither-core/modules/RepoSync/*" { return "patchmanager" }
        
        # Build and CI tooling
        "build/*" { return "build" }
        ".github/workflows/*" { return "build" }
        "Quick-*.ps1" { return "build" }
        "*-Release.ps1" { return "build" }
        "Turbo-*.ps1" { return "build" }
        "Power-*.ps1" { return "build" }
        
        # Documentation
        "docs/*" { return "docs" }
        "*.md" { return "docs" }
        "CONTRIBUTING" { return "docs" }
        "LICENSE" { return "docs" }
        
        # Configuration
        "configs/*" { return "config" }
        ".vscode/*" { return "config" }
        "*.json" { return "config" }
        "*.psd1" { return "config" }
        
        # Tests
        "tests/*" {
            if ($File -match "PatchManager|TestingFramework|DevEnvironment") {
                return "patchmanager"
            }
            return "core"
        }
        
        default { return "other" }
    }
}

Write-Host "🔍 Testing Package-Aware CI Change Detection" -ForegroundColor Cyan
Write-Host "Files to analyze: $($Files -join ', ')" -ForegroundColor Yellow
Write-Host ""

$coreChanges = $false
$patchmanagerOnly = $true
$buildToolingOnly = $false
$docsConfigOnly = $false
$affectsPackages = $false

$categories = @{
    core = @()
    patchmanager = @()
    build = @()
    docs = @()
    config = @()
    other = @()
}

foreach ($file in $Files) {
    Write-Host "Analyzing: $file" -ForegroundColor White
    
    $category = Get-ChangeCategory -File $file
    $categories[$category] += $file
    
    $affects = Test-AffectsPackages -File $file
    if ($affects) {
        $affectsPackages = $true
        Write-Host "  📦 Affects release packages" -ForegroundColor Green
    }
    
    Write-Host "  🏷️  Category: $category" -ForegroundColor Cyan
    
    # Update flags based on category
    switch ($category) {
        "core" {
            $coreChanges = $true
            $patchmanagerOnly = $false
            $buildToolingOnly = $false
            $docsConfigOnly = $false
        }
        "patchmanager" {
            # Keep patchmanagerOnly true unless other categories are found
        }
        "build" {
            $patchmanagerOnly = $false
            if (-not $coreChanges) { $buildToolingOnly = $true }
        }
        "docs" {
            $patchmanagerOnly = $false
            if (-not $coreChanges -and -not $buildToolingOnly) { $docsConfigOnly = $true }
        }
        "config" {
            $patchmanagerOnly = $false
            if (-not $coreChanges -and -not $buildToolingOnly) { $docsConfigOnly = $true }
        }
        "other" {
            $patchmanagerOnly = $false
            $buildToolingOnly = $false
            $docsConfigOnly = $false
        }
    }
}

# Determine final change type and test level
if ($coreChanges) {
    $changeType = "core"
    $testLevel = "complete"
    $explanation = "Core changes detected - full test suite required"
} elseif ($patchmanagerOnly -and -not $coreChanges) {
    $changeType = "patchmanager-only"
    $testLevel = "minimal"
    $explanation = "PatchManager-only changes - minimal test suite"
} elseif ($buildToolingOnly -and -not $coreChanges) {
    $changeType = "build-tooling"
    $testLevel = "build-validation"
    $explanation = "Build tooling changes - build validation tests"
} elseif ($docsConfigOnly -and -not $coreChanges -and $patchmanagerOnly) {
    $changeType = "docs-config-only"
    $testLevel = "docs"
    $explanation = "Documentation/config-only changes - skip core tests"
} else {
    $changeType = "mixed"
    $testLevel = "complete"
    $explanation = "Mixed changes - full test suite required"
}

# Special handling for package-affecting changes
if ($affectsPackages -and -not $coreChanges) {
    $testLevel = "package-validation"
    $explanation = "Package-affecting non-core changes - validate packages"
}

Write-Host ""
Write-Host "📊 Change Analysis Results:" -ForegroundColor Yellow
Write-Host "  Change Type: $changeType" -ForegroundColor Green
Write-Host "  Test Level: $testLevel" -ForegroundColor Green
Write-Host "  Affects Packages: $affectsPackages" -ForegroundColor Green
Write-Host "  Core Changes: $coreChanges" -ForegroundColor Green
Write-Host "  PatchManager Only: $patchmanagerOnly" -ForegroundColor Green
Write-Host "  Explanation: $explanation" -ForegroundColor Cyan

if ($ShowDetails) {
    Write-Host ""
    Write-Host "📁 File Categories:" -ForegroundColor Yellow
    foreach ($cat in $categories.Keys) {
        if ($categories[$cat].Count -gt 0) {
            Write-Host "  $cat`: $($categories[$cat] -join ', ')" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "⏱️  Expected CI Duration:" -ForegroundColor Yellow
switch ($testLevel) {
    "minimal" { Write-Host "  1-2 minutes" -ForegroundColor Green }
    "build-validation" { Write-Host "  2-3 minutes" -ForegroundColor Green }
    "docs" { Write-Host "  30 seconds" -ForegroundColor Green }
    "package-validation" { Write-Host "  3-5 minutes" -ForegroundColor Green }
    "complete" { Write-Host "  10-15 minutes" -ForegroundColor Yellow }
}
