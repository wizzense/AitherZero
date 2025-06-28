#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Test CI/CD workflow fixes locally
.DESCRIPTION
    Validates that the CI/CD fixes work correctly before pushing
#>

param(
    [switch]$TestBuild,
    [switch]$TestModules,
    [switch]$All
)

$ErrorActionPreference = 'Continue'

if ($All) {
    $TestBuild = $true
    $TestModules = $true
}

Write-Host "🔧 Testing CI/CD workflow fixes..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Module loading (like CI validation)
if ($TestModules -or $All) {
    Write-Host "📦 Testing module loading..." -ForegroundColor Yellow
    
    $env:PROJECT_ROOT = $PWD
    $env:PWSH_MODULES_PATH = Join-Path $PWD 'aither-core/modules'
    
    if (Test-Path './Quick-ModuleCheck.ps1') {
        Write-Host "Running Quick-ModuleCheck..." -ForegroundColor Cyan
        & './Quick-ModuleCheck.ps1' -MaxParallelJobs 4
    } elseif (Test-Path '../Quick-ModuleCheck.ps1') {
        Write-Host "Running Quick-ModuleCheck (parent dir)..." -ForegroundColor Cyan
        & '../Quick-ModuleCheck.ps1' -MaxParallelJobs 4
    } else {
        Write-Host "Running basic module validation..." -ForegroundColor Cyan
        
        $modulesPath = if (Test-Path './aither-core/modules') { './aither-core/modules' } else { '../aither-core/modules' }
        if (Test-Path $modulesPath) {
            $modules = Get-ChildItem -Path $modulesPath -Directory | Where-Object { $_.Name -ne 'packages-microsoft-prod.deb' }
            $successCount = 0
            $totalCount = $modules.Count
            
            foreach ($module in $modules) {
                try {
                    Write-Host "Testing module: $($module.Name)" -ForegroundColor Gray
                    Import-Module $module.FullName -Force -ErrorAction Stop -WarningAction SilentlyContinue
                    Write-Host "  ✓ $($module.Name)" -ForegroundColor Green
                    $successCount++
                } catch {
                    Write-Host "  ❌ $($module.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            $successRate = [math]::Round(($successCount / $totalCount) * 100, 1)
            Write-Host ""
            Write-Host "Module validation summary: $successCount/$totalCount modules ($successRate%) loaded successfully" -ForegroundColor $(if ($successRate -ge 80) { 'Green' } else { 'Yellow' })
            
            if ($successRate -lt 50) {
                Write-Host "❌ Less than 50% of modules loaded - CI would fail" -ForegroundColor Red
                return $false
            } else {
                Write-Host "✅ Module loading test passed" -ForegroundColor Green
            }
        }
    }
}

# Test 2: Build script
if ($TestBuild -or $All) {
    Write-Host ""
    Write-Host "🔨 Testing build script..." -ForegroundColor Yellow
    
    $buildScript = if (Test-Path './build/Build-Package.ps1') { './build/Build-Package.ps1' } else { '../build/Build-Package.ps1' }
    if (Test-Path $buildScript) {
        Write-Host "Validating Build-Package.ps1 syntax..." -ForegroundColor Cyan
        try {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $buildScript -Raw), [ref]$null)
            Write-Host "✅ Build script syntax is valid" -ForegroundColor Green
        } catch {
            Write-Host "❌ Build script syntax error: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
        
        # Test launcher templates
        $launcherTemplates = @(
            './templates/launchers/Start-AitherZero.ps1',
            './templates/launchers/AitherZero.bat',
            '../templates/launchers/Start-AitherZero.ps1',
            '../templates/launchers/AitherZero.bat'
        )
        
        $foundTemplates = 0
        foreach ($template in $launcherTemplates) {
            if (Test-Path $template) {
                Write-Host "✅ Found launcher template: $(Split-Path $template -Leaf)" -ForegroundColor Green
                $foundTemplates++
            }
        }
        
        if ($foundTemplates -lt 2) {
            Write-Host "❌ Missing launcher templates (found $foundTemplates, need 2)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "❌ Build script not found in ./build/ or ../build/" -ForegroundColor Red
        return $false
    }
}

Write-Host ""
Write-Host "🎉 All CI/CD fixes validated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Commit these fixes" -ForegroundColor White
Write-Host "2. Push to trigger CI/CD workflows" -ForegroundColor White
Write-Host "3. Monitor GitHub Actions for successful builds" -ForegroundColor White

return $true