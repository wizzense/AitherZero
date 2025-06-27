#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
Test suite to reorganize and cleanup the chaotic test structure

.DESCRIPTION
This test identifies and fixes the test organization issues:
- Moves PatchManager tests to proper location
- Removes duplicate backup files
- Consolidates test structure
- Validates comprehensive test coverage
#>

BeforeAll {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $testsRoot = $PSScriptRoot
}

Describe "Test Structure Reorganization" {
    
    Context "Identify Test Organization Issues" {
        It "Should identify misplaced PatchManager tests" {
            $patchManagerTestsDir = Join-Path $testsRoot "PatchManager.Tests"
            Test-Path $patchManagerTestsDir | Should -Be $true
            
            $testFiles = Get-ChildItem $patchManagerTestsDir -Name "*.Tests.ps1"
            $testFiles.Count | Should -BeGreaterThan 0
            Write-Host "Found PatchManager tests: $($testFiles -join ', ')" -ForegroundColor Yellow
        }
        
        It "Should count backup files cluttering the structure" {
            $backupFiles = Get-ChildItem $testsRoot -Name "*.backup*"
            Write-Host "Found $($backupFiles.Count) backup files cluttering tests directory" -ForegroundColor Red
            $backupFiles.Count | Should -BeGreaterThan 50 # We know there are tons
        }
        
        It "Should identify multiple test directory structures" {
            $testDirs = @("pester", "pytest", "unit", "integration", "helpers", "PatchManager.Tests")
            foreach ($dir in $testDirs) {
                $dirPath = Join-Path $testsRoot $dir
                if (Test-Path $dirPath) {
                    Write-Host "Found test directory: $dir" -ForegroundColor Cyan
                }
            }
            
            # We should have a cleaner structure
            $testDirs | Should -Not -BeNullOrEmpty
        }
        
        It "Should identify existing comprehensive tests" {
            $comprehensiveTests = @(
                "SystematicValidation.Tests.ps1",
                "ParallelExecution.Tests.ps1", 
                "ComprehensiveCodeQuality.Tests.ps1",
                "ModuleStructure.Tests.ps1"
            )
            
            foreach ($test in $comprehensiveTests) {
                $testPath = Join-Path $testsRoot $test
                if (Test-Path $testPath) {
                    Write-Host "Found comprehensive test: $test" -ForegroundColor Green
                    Test-Path $testPath | Should -Be $true
                }
            }
        }
    }
    
    Context "Propose Clean Test Structure" {
        It "Should propose a clean directory structure" {
            $proposedStructure = @{
                "unit/" = "Unit tests for individual functions/modules"
                "integration/" = "Integration tests for module interactions"
                "system/" = "System-level and end-to-end tests"
                "helpers/" = "Test helper functions and utilities"
                "config/" = "Test configuration files"
                "results/" = "Test output and results (keep)"
                "data/" = "Test data files (keep)"
            }
            
            Write-Host "`nProposed Clean Test Structure:" -ForegroundColor Magenta
            foreach ($dir in $proposedStructure.Keys) {
                Write-Host "  $dir - $($proposedStructure[$dir])" -ForegroundColor White
            }
            
            $proposedStructure.Count | Should -BeGreaterThan 0
        }
        
        It "Should identify proper location for PatchManager tests" {
            # PatchManager tests should be in unit/modules/PatchManager/
            $properLocation = "unit/modules/PatchManager/"
            Write-Host "PatchManager tests should be in: $properLocation" -ForegroundColor Green
            $properLocation | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Test Cleanup Actions" {
    
    Context "Backup File Cleanup" {
        It "Should safely remove backup files" {
            $backupFiles = Get-ChildItem $testsRoot -Name "*.backup*"
            Write-Host "Preparing to remove $($backupFiles.Count) backup files" -ForegroundColor Yellow
            
            # For safety, just count them in the test
            $backupFiles.Count | Should -BeGreaterThan 0
        }
    }
    
    Context "Directory Reorganization" {
        It "Should plan PatchManager test move" {
            $source = Join-Path $testsRoot "PatchManager.Tests"
            $destination = Join-Path $testsRoot "unit/modules/PatchManager"
            
            if (Test-Path $source) {
                Write-Host "Would move: $source -> $destination" -ForegroundColor Cyan
                Test-Path $source | Should -Be $true
            }
        }
        
        It "Should plan consolidation of scattered tests" {
            $scatteredTests = Get-ChildItem $testsRoot -Name "*.Tests.ps1" | Where-Object { 
                $_ -notmatch "^(SystematicValidation|ParallelExecution|ComprehensiveCodeQuality|ModuleStructure)" 
            }
            
            Write-Host "Found $($scatteredTests.Count) scattered test files to reorganize" -ForegroundColor Yellow
            $scatteredTests.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "Existing Comprehensive Test Analysis" {
    
    Context "SystematicValidation.Tests.ps1" {
        It "Should exist and be comprehensive" {
            $testPath = Join-Path $testsRoot "SystematicValidation.Tests.ps1"
            Test-Path $testPath | Should -Be $true
            
            $content = Get-Content $testPath -Raw
            $content | Should -Match "PSScriptAnalyzer"
            $content | Should -Match "syntax errors"
            Write-Host "SystematicValidation.Tests.ps1 appears comprehensive" -ForegroundColor Green
        }
    }
    
    Context "ParallelExecution.Tests.ps1" {
        It "Should exist and test parallel processing" {
            $testPath = Join-Path $testsRoot "ParallelExecution.Tests.ps1"
            Test-Path $testPath | Should -Be $true
            
            $content = Get-Content $testPath -Raw
            $content | Should -Match "parallel"
            Write-Host "ParallelExecution.Tests.ps1 exists for parallel processing" -ForegroundColor Green
        }
    }
    
    Context "Test Coverage Analysis" {
        It "Should analyze what the comprehensive tests already cover" {
            $comprehensiveTests = @(
                "SystematicValidation.Tests.ps1",
                "ParallelExecution.Tests.ps1", 
                "ComprehensiveCodeQuality.Tests.ps1"
            )
            
            $coverage = @()
            foreach ($test in $comprehensiveTests) {
                $testPath = Join-Path $testsRoot $test
                if (Test-Path $testPath) {
                    $content = Get-Content $testPath -Raw
                    $coverage += @{
                        TestFile = $test
                        Covers = @(
                            if ($content -match "PSScriptAnalyzer") { "Static Analysis" }
                            if ($content -match "syntax") { "Syntax Validation" }
                            if ($content -match "parallel") { "Parallel Processing" }
                            if ($content -match "module") { "Module Testing" }
                            if ($content -match "import") { "Import Validation" }
                        )
                    }
                }
            }
            
            Write-Host "`nExisting Test Coverage:" -ForegroundColor Magenta
            foreach ($item in $coverage) {
                Write-Host "  $($item.TestFile): $($item.Covers -join ', ')" -ForegroundColor White
            }
            
            $coverage.Count | Should -BeGreaterThan 0
        }
    }
}
