#!/usr/bin/env pwsh
#Requires -Version 5.1

<#
.SYNOPSIS
    Validates that critical features are present in the build
.DESCRIPTION
    Ensures essential features like dynamic menu system are properly integrated
    before packaging. This prevents releases with missing functionality.
.PARAMETER BuildPath
    Path to the build directory to validate
.PARAMETER FailFast
    Stop validation on first failure
#>

param(
    [string]$BuildPath = $PWD,
    [switch]$FailFast
)

Write-Host "`n🔍 AitherZero Build Feature Validation" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Validating build at: $BuildPath" -ForegroundColor Gray
Write-Host ""

$validationResults = @()
$criticalFailures = 0

function Test-BuildFeature {
    param(
        [string]$Name,
        [string]$Description,
        [scriptblock]$Test,
        [switch]$Critical
    )
    
    Write-Host "🔍 Testing: $Name" -ForegroundColor Yellow
    Write-Host "   $Description" -ForegroundColor Gray
    
    try {
        $result = & $Test
        if ($result.Success) {
            Write-Host "   ✅ PASS" -ForegroundColor Green
            if ($result.Details) {
                $result.Details | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
            }
            $status = 'PASS'
        } else {
            $status = if ($Critical) { 'CRITICAL FAILURE' } else { 'FAIL' }
            Write-Host "   ❌ $status" -ForegroundColor Red
            if ($result.Details) {
                $result.Details | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
            }
            if ($Critical) {
                $script:criticalFailures++
                if ($FailFast) {
                    throw "Critical feature validation failed: $Name"
                }
            }
        }
    } catch {
        $status = if ($Critical) { 'CRITICAL ERROR' } else { 'ERROR' }
        Write-Host "   ❌ $status" -ForegroundColor Red
        Write-Host "      $_" -ForegroundColor Red
        if ($Critical) {
            $script:criticalFailures++
            if ($FailFast) {
                throw
            }
        }
    }
    
    $script:validationResults += [PSCustomObject]@{
        Name = $Name
        Status = $status
        Critical = $Critical
        Description = $Description
    }
    
    Write-Host ""
}

# Test 1: Dynamic Menu System Present
Test-BuildFeature -Name "Dynamic Menu System" -Critical -Description "Verify aither-core.ps1 contains Show-DynamicMenu integration" -Test {
    $coreScript = Join-Path $BuildPath "aither-core.ps1"
    $altCoreScript = Join-Path $BuildPath "aither-core/aither-core.ps1"
    
    # Try both possible locations
    $scriptPath = if (Test-Path $coreScript) { $coreScript } elseif (Test-Path $altCoreScript) { $altCoreScript } else { $null }
    
    if (-not $scriptPath) {
        return @{
            Success = $false
            Details = @("aither-core.ps1 not found in expected locations")
        }
    }
    
    $content = Get-Content $scriptPath -Raw
    $hasShowDynamicMenu = $content -match "Show-DynamicMenu"
    $hasModuleDiscovery = $content -match "Get-ModuleCapabilities"
    
    if ($hasShowDynamicMenu -and $hasModuleDiscovery) {
        return @{
            Success = $true
            Details = @("✓ Show-DynamicMenu integration found", "✓ Module discovery system present")
        }
    } else {
        return @{
            Success = $false
            Details = @(
                "Show-DynamicMenu found: $hasShowDynamicMenu",
                "Module discovery found: $hasModuleDiscovery",
                "Core script appears to have old static menu system"
            )
        }
    }
}

# Test 2: Dynamic Menu Support Files Present
Test-BuildFeature -Name "Dynamic Menu Support Files" -Critical -Description "Verify supporting files for dynamic menu system exist" -Test {
    $requiredFiles = @(
        "shared/Show-DynamicMenu.ps1",
        "shared/Get-ModuleCapabilities.ps1",
        "modules/SetupWizard/Public/Edit-Configuration.ps1"
    )
    
    $missingFiles = @()
    $foundFiles = @()
    
    foreach ($file in $requiredFiles) {
        $fullPath = Join-Path $BuildPath $file
        if (Test-Path $fullPath) {
            $foundFiles += $file
        } else {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -eq 0) {
        return @{
            Success = $true
            Details = @("All $($requiredFiles.Count) support files found") + $foundFiles
        }
    } else {
        return @{
            Success = $false
            Details = @("Missing $($missingFiles.Count) required files:") + $missingFiles
        }
    }
}

# Test 3: PowerShell Compatibility
Test-BuildFeature -Name "PowerShell Compatibility" -Description "Verify launcher handles PowerShell 5.1 and 7+" -Test {
    $launcher = Join-Path $BuildPath "Start-AitherZero.ps1"
    
    if (-not (Test-Path $launcher)) {
        return @{
            Success = $false
            Details = @("Start-AitherZero.ps1 not found")
        }
    }
    
    $content = Get-Content $launcher -Raw
    $hasBootstrap = $content -match "aither-core-bootstrap\.ps1"
    $hasVersionCheck = $content -match "\$PSVersionTable\.PSVersion\.Major"
    
    if ($hasBootstrap -and $hasVersionCheck) {
        return @{
            Success = $true
            Details = @("✓ PowerShell version detection present", "✓ Bootstrap script integration found")
        }
    } else {
        return @{
            Success = $false
            Details = @(
                "Bootstrap integration: $hasBootstrap",
                "Version check: $hasVersionCheck"
            )
        }
    }
}

# Test 4: Module Structure Validation
Test-BuildFeature -Name "Module Structure" -Description "Verify core modules are present and properly structured" -Test {
    $coreModules = @("PatchManager", "SetupWizard", "Logging", "LabRunner", "BackupManager")
    $modulesPath = Join-Path $BuildPath "modules"
    
    if (-not (Test-Path $modulesPath)) {
        return @{
            Success = $false
            Details = @("Modules directory not found at: $modulesPath")
        }
    }
    
    $missingModules = @()
    $foundModules = @()
    
    foreach ($module in $coreModules) {
        $modulePath = Join-Path $modulesPath $module
        if (Test-Path $modulePath) {
            # Check for manifest
            $manifestPath = Join-Path $modulePath "$module.psd1"
            if (Test-Path $manifestPath) {
                $foundModules += "$module (with manifest)"
            } else {
                $foundModules += "$module (no manifest)"
            }
        } else {
            $missingModules += $module
        }
    }
    
    if ($missingModules.Count -eq 0) {
        return @{
            Success = $true
            Details = @("All $($coreModules.Count) core modules found:") + $foundModules
        }
    } else {
        return @{
            Success = $false
            Details = @("Missing $($missingModules.Count) core modules:") + $missingModules + @("Found:") + $foundModules
        }
    }
}

# Test 5: Configuration System
Test-BuildFeature -Name "Configuration System" -Description "Verify configuration editing capabilities are present" -Test {
    $configEditor = Join-Path $BuildPath "modules/SetupWizard/Public/Edit-Configuration.ps1"
    $reviewConfig = Join-Path $BuildPath "modules/SetupWizard/Public/Review-Configuration.ps1"
    
    $editPresent = Test-Path $configEditor
    $reviewPresent = Test-Path $reviewConfig
    
    if ($editPresent -and $reviewPresent) {
        return @{
            Success = $true
            Details = @("✓ Edit-Configuration.ps1 found", "✓ Review-Configuration.ps1 found")
        }
    } else {
        return @{
            Success = $false
            Details = @(
                "Edit-Configuration present: $editPresent",
                "Review-Configuration present: $reviewPresent"
            )
        }
    }
}

# Summary
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "📊 Validation Summary" -ForegroundColor Green
Write-Host ""

$total = $validationResults.Count
$passed = ($validationResults | Where-Object { $_.Status -eq 'PASS' }).Count
$failed = $total - $passed
$criticalFailed = ($validationResults | Where-Object { $_.Critical -and $_.Status -ne 'PASS' }).Count

Write-Host "Total Tests: $total" -ForegroundColor White
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { 'Red' } else { 'Green' })
Write-Host "Critical Failures: $criticalFailed" -ForegroundColor $(if ($criticalFailed -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($criticalFailed -gt 0) {
    Write-Host "❌ BUILD VALIDATION FAILED" -ForegroundColor Red
    Write-Host "Critical features are missing or broken. Build should NOT be released." -ForegroundColor Red
    Write-Host ""
    Write-Host "Critical Failures:" -ForegroundColor Red
    $validationResults | Where-Object { $_.Critical -and $_.Status -ne 'PASS' } | ForEach-Object {
        Write-Host "  • $($_.Name): $($_.Status)" -ForegroundColor Red
    }
    exit 1
} elseif ($failed -gt 0) {
    Write-Host "⚠️ BUILD VALIDATION PASSED WITH WARNINGS" -ForegroundColor Yellow
    Write-Host "Build is functional but has non-critical issues." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "✅ BUILD VALIDATION PASSED" -ForegroundColor Green
    Write-Host "All features validated successfully. Build is ready for release." -ForegroundColor Green
    exit 0
}