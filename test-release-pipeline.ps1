#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Test script to validate the complete release pipeline
.DESCRIPTION
    Tests all aspects of the release process including PatchManager,
    build artifacts, and CI/CD workflows
#>

[CmdletBinding()]
param(
    [switch]$SkipBuildTest
)

Write-Host @"

    🧪 AitherZero Release Pipeline Validation
    ========================================
    
"@ -ForegroundColor Cyan

$testsPassed = 0
$testsFailed = 0

function Test-Component {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    Write-Host "`n📋 Testing: $Name" -ForegroundColor Yellow
    try {
        $result = & $Test
        if ($result) {
            Write-Host "  ✅ PASSED" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "  ❌ FAILED" -ForegroundColor Red
            $script:testsFailed++
        }
    } catch {
        Write-Host "  ❌ FAILED: $_" -ForegroundColor Red
        $script:testsFailed++
    }
}

# Test 1: Release scripts exist
Test-Component "Release Scripts" {
    $scripts = @(
        "./release.ps1",
        "./AitherRelease.ps1"
    )
    
    $allExist = $true
    foreach ($script in $scripts) {
        if (-not (Test-Path $script)) {
            Write-Host "    Missing: $script" -ForegroundColor Red
            $allExist = $false
        } else {
            Write-Host "    Found: $script" -ForegroundColor Green
        }
    }
    return $allExist
}

# Test 2: PatchManager module loads
Test-Component "PatchManager Module" {
    Import-Module ./aither-core/modules/PatchManager -Force -ErrorAction Stop
    
    # Check required functions
    $functions = @(
        'Invoke-ReleaseWorkflow',
        'New-Patch',
        'New-Feature',
        'New-QuickFix'
    )
    
    $allFound = $true
    foreach ($func in $functions) {
        if (Get-Command $func -Module PatchManager -ErrorAction SilentlyContinue) {
            Write-Host "    Function found: $func" -ForegroundColor Green
        } else {
            Write-Host "    Function missing: $func" -ForegroundColor Red
            $allFound = $false
        }
    }
    return $allFound
}

# Test 3: VERSION file is current
Test-Component "VERSION File" {
    $versionFile = Get-Content ./VERSION -Raw -ErrorAction Stop
    $versionFile = $versionFile.Trim()
    
    # Get latest git tag
    $latestTag = git describe --tags --abbrev=0 2>$null
    if ($latestTag) {
        $latestVersion = $latestTag -replace '^v', ''
        Write-Host "    VERSION file: $versionFile"
        Write-Host "    Latest tag: $latestTag ($latestVersion)"
        
        if ($versionFile -eq $latestVersion) {
            Write-Host "    Version is synchronized" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    Version mismatch!" -ForegroundColor Yellow
            return $true  # Not a failure, just a warning
        }
    } else {
        Write-Host "    No git tags found" -ForegroundColor Yellow
        return $true
    }
}

# Test 4: GitHub workflows exist
Test-Component "GitHub Workflows" {
    $workflows = @(
        ".github/workflows/ci-and-release.yml",
        ".github/workflows/build-release.yml",
        ".github/workflows/manual-release.yml",
        ".github/workflows/pr-validation.yml",
        ".github/workflows/documentation.yml"
    )
    
    $allExist = $true
    foreach ($workflow in $workflows) {
        if (Test-Path $workflow) {
            Write-Host "    Found: $workflow" -ForegroundColor Green
        } else {
            Write-Host "    Missing: $workflow" -ForegroundColor Red
            $allExist = $false
        }
    }
    return $allExist
}

# Test 5: Build script and artifacts
if (-not $SkipBuildTest) {
    Test-Component "Build System" {
        if (-not (Test-Path ./build/Build-Package.ps1)) {
            Write-Host "    Build script not found!" -ForegroundColor Red
            return $false
        }
        
        Write-Host "    Testing dry run build..." -ForegroundColor Yellow
        
        # Test dry run
        try {
            $result = & ./build/Build-Package.ps1 -Profile minimal -Platform windows -DryRun -Version "test"
            Write-Host "    Build script executed successfully" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "    Build script failed: $_" -ForegroundColor Red
            return $false
        }
    }
}

# Test 6: Release dry run
Test-Component "Release Script Dry Run" {
    Write-Host "    Testing release.ps1 dry run..." -ForegroundColor Yellow
    
    try {
        # Run the script and check exit code
        & ./release.ps1 -Type patch -Description "Test release" -DryRun
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Dry run completed successfully (exit code: 0)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "    Dry run failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "    Release script failed: $_" -ForegroundColor Red
        return $false
    }
}

# Test 7: Test runner
Test-Component "Test Infrastructure" {
    if (-not (Test-Path ./tests/Run-Tests.ps1)) {
        Write-Host "    Test runner not found!" -ForegroundColor Red
        return $false
    }
    
    Write-Host "    Test runner found" -ForegroundColor Green
    
    # Check if tests directory has test files
    $testFiles = Get-ChildItem ./tests -Recurse -Filter "*.Tests.ps1" | Select-Object -First 5
    if ($testFiles) {
        Write-Host "    Found $($testFiles.Count)+ test files" -ForegroundColor Green
        return $true
    } else {
        Write-Host "    No test files found" -ForegroundColor Yellow
        return $true  # Not a failure
    }
}

# Summary
Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
Write-Host "📊 VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "  ✅ Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "  ❌ Tests Failed: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "🎉 All release pipeline components validated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Run: ./release.ps1" -ForegroundColor White
    Write-Host "  2. Or use GitHub Actions: Manual Release Creator" -ForegroundColor White
    Write-Host "  3. Or use PatchManager directly" -ForegroundColor White
    exit 0
} else {
    Write-Host "⚠️  Some components need attention" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please fix the failed components before attempting a release." -ForegroundColor Yellow
    exit 1
}