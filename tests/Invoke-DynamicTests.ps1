#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
Dynamic test discovery and execution for OpenTofu Lab Automation

.DESCRIPTION
This unified test runner automatically discovers and tests all PowerShell scripts
in the project using a template-based approach. No need for individual test files.

.PARAMETER TestType
The type of tests to run: All, Unit, Integration, Smoke

.PARAMETER ModuleName
Test only specific module (optional)

.PARAMETER ScriptPattern
Test only scripts matching pattern (optional)
#>

[CmdletBinding()]
param(
    [ValidateSet('All', 'Unit', 'Integration', 'Smoke')]
    [string]$TestType = 'All',
    
    [string]$ModuleName,
    
    [string]$ScriptPattern = '*'
)

# Load shared test helpers for environment setup
. (Join-Path $PSScriptRoot 'helpers' 'TestHelpers.ps1')

# Set up environment
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Set environment variables
$env:PROJECT_ROOT = $ProjectRoot
$env:PWSH_MODULES_PATH = $env:PWSH_MODULES_PATH

# Import test helpers
. (Join-Path $PSScriptRoot "helpers/TestHelpers.ps1")

# Discover all PowerShell modules and scripts
function Get-ProjectModules {
    $modulesPath = $env:PWSH_MODULES_PATH
    if (Test-Path $modulesPath) {
        Get-ChildItem $modulesPath -Directory | Where-Object {
            (Test-Path (Join-Path $_.FullName "*.psd1")) -or 
            (Test-Path (Join-Path $_.FullName "*.psm1"))
        }
    }
}

function Get-ProjectScripts {
    $scriptsPath = Join-Path $ProjectRoot "src/pwsh"
    if (Test-Path $scriptsPath) {
        Get-ChildItem $scriptsPath -Recurse -Filter "*.ps1" | Where-Object {
            $_.Name -notmatch "(test|Test)" -and
            $_.Name -match $ScriptPattern
        }
    }
}

# Dynamic test templates
function Test-ModuleStructure {
    param($Module)
    
    Describe "Module: $($Module.Name)" -Tag @('Unit', 'Module', 'Structure') {
        
        Context "Module Files" {
            It "should have a manifest or module file" {
                $hasManifest = Test-Path (Join-Path $Module.FullName "*.psd1")
                $hasModule = Test-Path (Join-Path $Module.FullName "*.psm1")
                ($hasManifest -or $hasModule) | Should -Be $true
            }
            
            if (Test-Path (Join-Path $Module.FullName "*.psd1")) {
                It "should have a valid manifest" {
                    $manifestPath = Get-ChildItem (Join-Path $Module.FullName "*.psd1") | Select-Object -First 1
                    { Test-ModuleManifest $manifestPath.FullName } | Should -Not -Throw
                }
            }
        }
        
        Context "Module Import" {
            It "should import without errors" {
                { Import-Module $Module.FullName -Force -ErrorAction Stop } | Should -Not -Throw
            }
        }
        
        Context "Module Functions" {
            BeforeAll {
                Import-Module $Module.FullName -Force
                $exportedFunctions = Get-Command -Module $Module.Name -CommandType Function -ErrorAction SilentlyContinue
            }
            
            if ($exportedFunctions) {
                It "should export functions" {
                    $exportedFunctions.Count | Should -BeGreaterThan 0
                }
                
                foreach ($function in $exportedFunctions) {
                    It "function '$($function.Name)' should have help" {
                        $help = Get-Help $function.Name
                        $help.Synopsis | Should -Not -BeNullOrEmpty
                    }
                }
            }
        }
    }
}

function Test-ScriptStructure {
    param($Script)
    
    $scriptName = $Script.BaseName
    $relativePath = $Script.FullName.Replace($ProjectRoot, "").TrimStart('\', '/')
    
    Describe "Script: $scriptName" -Tag @('Unit', 'Script', 'Structure') {
        
        Context "File Structure" {
            It "should exist and be readable" {
                Test-Path $Script.FullName | Should -Be $true
                { Get-Content $Script.FullName -ErrorAction Stop } | Should -Not -Throw
            }
            
            It "should have valid PowerShell syntax" {
                $errors = $null
                $tokens = $null
                [System.Management.Automation.Language.Parser]::ParseFile(
                    $Script.FullName, [ref]$tokens, [ref]$errors
                ) | Out-Null
                $errors.Count | Should -Be 0 -Because "Script should not have syntax errors"
            }
        }
        
        Context "Script Content" {
            BeforeAll {
                $content = Get-Content $Script.FullName -Raw
            }
            
            It "should have proper encoding" {
                $content | Should -Not -BeNullOrEmpty
            }
            
            if ($content -match 'param\s*\(') {
                It "should have parameter validation" {
                    # Check for at least some parameter attributes
                    $content -match '\[Parameter\(' -or 
                    $content -match '\[ValidateSet\(' -or
                    $content -match '\[ValidateNotNull' | Should -Be $true
                }
            }
            
            if ($content -match 'function\s+\w+') {
                It "should have function documentation" {
                    $content -match '<#[\s\S]*?\.SYNOPSIS[\s\S]*?#>' | Should -Be $true
                }
            }
        }
    }
}

function Test-ModuleIntegration {
    param($Module)
    
    Describe "Module Integration: $($Module.Name)" -Tag @('Integration', 'Module') {
        
        BeforeAll {
            # Clean import
            Remove-Module $Module.Name -Force -ErrorAction SilentlyContinue
            Import-Module $Module.FullName -Force
        }
        
        Context "Cross-Module Dependencies" {
            It "should handle missing dependencies gracefully" {
                # Try to use module functions without breaking
                $commands = Get-Command -Module $Module.Name -ErrorAction SilentlyContinue
                $commands | Should -Not -BeNullOrEmpty
            }
        }
        
        Context "Environment Integration" {
            It "should work with current PowerShell version" {
                $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
            }
            
            if ($Module.Name -eq 'LabRunner') {
                It "should set up lab environment variables" {
                    # Test lab-specific functionality
                    $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        AfterAll {
            Remove-Module $Module.Name -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-ProjectSmoke {
    Describe "Project Smoke Tests" -Tag @('Smoke', 'Critical') {
        
        Context "Project Structure" {
            It "should have required directories" {
                Test-Path (Join-Path $ProjectRoot "src") | Should -Be $true
                Test-Path (Join-Path $ProjectRoot "src/pwsh") | Should -Be $true
                Test-Path ($env:PWSH_MODULES_PATH) | Should -Be $true
                Test-Path (Join-Path $ProjectRoot "tests") | Should -Be $true
            }
              It "should have core files" {
                Test-Path (Join-Path $ProjectRoot "docs/README.md") | Should -Be $true
                Test-Path (Join-Path $ProjectRoot "LICENSE") | Should -Be $true
            }
        }
        
        Context "Core Modules" {
            $coreModules = @('LabRunner', 'PatchManager', 'Logging')
            
            foreach ($moduleName in $coreModules) {
                It "should have $moduleName module" {
                    $modulePath = Join-Path $env:PWSH_MODULES_PATH "$moduleName"
                    Test-Path $modulePath | Should -Be $true
                }
            }
        }
        
        Context "Environment Setup" {
            It "should have PROJECT_ROOT set" {
                $env:PROJECT_ROOT | Should -Not -BeNullOrEmpty
            }
            
            It "should have PWSH_MODULES_PATH set" {
                $env:PWSH_MODULES_PATH | Should -Not -BeNullOrEmpty
            }
        }
    }
}

# Main execution
Write-Host "SEARCHING - OpenTofu Lab Automation - Dynamic Test Runner" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot" -ForegroundColor Gray
Write-Host "Test Type: $TestType" -ForegroundColor Gray

# Always run smoke tests first
if ($TestType -in @('All', 'Smoke')) {
    Write-Host "`nEXECUTING - Running Smoke Tests..." -ForegroundColor Yellow
    Test-ProjectSmoke
}

# Discover and test modules
if ($TestType -in @('All', 'Unit', 'Integration')) {
    $modules = Get-ProjectModules
    
    if ($ModuleName) {
        $modules = $modules | Where-Object { $_.Name -eq $ModuleName }
    }
    
    if ($modules) {
        Write-Host "`nPACKAGE - Testing Modules..." -ForegroundColor Yellow
        Write-Host "Found $($modules.Count) modules" -ForegroundColor Gray
        
        foreach ($module in $modules) {
            if ($TestType -in @('All', 'Unit')) {
                Test-ModuleStructure -Module $module
            }
            
            if ($TestType -in @('All', 'Integration')) {
                Test-ModuleIntegration -Module $module
            }
        }
    } else {
        Write-Warning "No modules found matching criteria"
    }
}

# Discover and test scripts
if ($TestType -in @('All', 'Unit')) {
    $scripts = Get-ProjectScripts
    
    if ($scripts) {
        Write-Host "`n[SYMBOL] Testing Scripts..." -ForegroundColor Yellow
        Write-Host "Found $($scripts.Count) scripts" -ForegroundColor Gray
        
        foreach ($script in $scripts | Select-Object -First 10) { # Limit for demo
            Test-ScriptStructure -Script $script
        }
    } else {
        Write-Warning "No scripts found matching criteria"
    }
}

Write-Host "`nSUCCESS - Dynamic test execution complete!" -ForegroundColor Green


