#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
Execute the test structure reorganization

.DESCRIPTION
This test performs the actual cleanup and reorganization of the test structure.
Run with -WhatIf to see what would be done without making changes.
#>

param(
    [switch]$WhatIf = $false
)

BeforeAll {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $testsRoot = $PSScriptRoot
    
    function Execute-Action {
        param([string]$Action, [scriptblock]$ScriptBlock)
        
        if ($WhatIf) {
            Write-Host "WOULD DO: $Action" -ForegroundColor Yellow
        } else {
            Write-Host "DOING: $Action" -ForegroundColor Green
            & $ScriptBlock
        }
    }
}

Describe "Test Structure Cleanup Execution" {
    
    Context "Backup File Removal" {
        It "Should remove backup files" {
            $backupFiles = Get-ChildItem $testsRoot -Filter "*.backup*" -Recurse
            Write-Host "Found $($backupFiles.Count) backup files to remove"
            
            Execute-Action "Remove $($backupFiles.Count) backup files" {
                $backupFiles | Remove-Item -Force
            }
            
            # Verify removal (only if not WhatIf)
            if (-not $WhatIf) {
                $remainingBackups = Get-ChildItem $testsRoot -Filter "*.backup*" -Recurse
                $remainingBackups.Count | Should -Be 0
            }
        }
    }
    
    Context "Directory Structure Creation" {
        It "Should create clean directory structure" {
            $directories = @(
                "unit/modules/PatchManager",
                "unit/modules/LabRunner", 
                "unit/modules/TestingFramework",
                "unit/modules/ScriptManager",
                "unit/modules/BackupManager",
                "integration/workflows",
                "integration/deployment",
                "system/endtoend",
                "config"
            )
            
            foreach ($dir in $directories) {
                $fullPath = Join-Path $testsRoot $dir
                Execute-Action "Create directory $dir" {
                    if (-not (Test-Path $fullPath)) { New-Item -Path $fullPath -ItemType Directory -Force | Out-Null }
                }
                
                if (-not $WhatIf) {
                    Test-Path $fullPath | Should -Be $true
                }
            }
        }
    }
    
    Context "PatchManager Tests Relocation" {
        It "Should move PatchManager tests to proper location" {
            $sourceDir = Join-Path $testsRoot "PatchManager.Tests"
            $targetDir = Join-Path $testsRoot "unit/modules/PatchManager"
            
            if (Test-Path $sourceDir) {
                $testFiles = Get-ChildItem $sourceDir -Filter "*.Tests.ps1"
                Write-Host "Moving $($testFiles.Count) PatchManager test files"
                
                foreach ($file in $testFiles) {
                    $targetFile = Join-Path $targetDir $file.Name
                    Execute-Action "Move $($file.Name) to unit/modules/PatchManager/" {
                        Move-Item $file.FullName $targetFile -Force
                    }
                }
                
                Execute-Action "Remove empty PatchManager.Tests directory" {
                    Remove-Item $sourceDir -Force -Recurse
                }
                
                if (-not $WhatIf) {
                    Test-Path $sourceDir | Should -Be $false
                    $movedFiles = Get-ChildItem $targetDir -Filter "*.Tests.ps1"
                    $movedFiles.Count | Should -Be $testFiles.Count
                }
            }
        }
    }
    
    Context "Consolidate Core Tests" {
        It "Should organize comprehensive tests in system directory" {
            $comprehensiveTests = @(
                "SystematicValidation.Tests.ps1",
                "ParallelExecution.Tests.ps1",
                "ComprehensiveCodeQuality.Tests.ps1",
                "ModuleStructure.Tests.ps1"
            )
            
            $systemDir = Join-Path $testsRoot "system"
            
            foreach ($test in $comprehensiveTests) {
                $sourceFile = Join-Path $testsRoot $test
                $targetFile = Join-Path $systemDir $test
                
                if (Test-Path $sourceFile) {
                    Execute-Action "Move $test to system/" {
                        Move-Item $sourceFile $targetFile -Force
                    }
                    
                    if (-not $WhatIf) {
                        Test-Path $targetFile | Should -Be $true
                    }
                }
            }
        }
    }
    
    Context "Configuration Files Organization" {
        It "Should move configuration files to config directory" {
            $configFiles = @(
                "TestConfiguration.psd1",
                "PesterConfiguration.psd1", 
                "PSScriptAnalyzerSettings.psd1",
                ".pssa-test-rules.psd1"
            )
            
            $configDir = Join-Path $testsRoot "config"
            
            foreach ($config in $configFiles) {
                $sourceFile = Join-Path $testsRoot $config
                $targetFile = Join-Path $configDir $config
                
                if (Test-Path $sourceFile) {
                    Execute-Action "Move $config to config/" {
                        Move-Item $sourceFile $targetFile -Force
                    }
                    
                    if (-not $WhatIf) {
                        Test-Path $targetFile | Should -Be $true
                    }
                }
            }
        }
    }
    
    Context "Master Test Scripts Organization" {
        It "Should keep master test scripts in root but clean them up" {
            $masterScripts = @(
                "Run-MasterTests.ps1",
                "Invoke-DynamicTests.ps1", 
                "Invoke-IntelligentTests.ps1",
                "Setup-TestingFramework.ps1"
            )
            
            foreach ($script in $masterScripts) {
                $scriptPath = Join-Path $testsRoot $script
                if (Test-Path $scriptPath) {
                    Write-Host "Keeping master script: $script in root" -ForegroundColor Cyan
                    Test-Path $scriptPath | Should -Be $true
                }
            }
        }
    }
}

Describe "Post-Cleanup Validation" {
    
    Context "Verify Clean Structure" {
        It "Should have clean test directory structure" {
            $expectedDirs = @("unit", "integration", "system", "config", "helpers", "data", "results")
            
            foreach ($dir in $expectedDirs) {
                $dirPath = Join-Path $testsRoot $dir
                if (-not $WhatIf) {
                    Test-Path $dirPath | Should -Be $true
                }
                Write-Host "✓ Directory exists: $dir" -ForegroundColor Green
            }
        }
        
        It "Should have no backup files remaining" {
            if (-not $WhatIf) {
                $backupFiles = Get-ChildItem $testsRoot -Filter "*.backup*" -Recurse
                $backupFiles.Count | Should -Be 0
            }
        }
        
        It "Should have PatchManager tests in correct location" {
            $patchManagerDir = Join-Path $testsRoot "unit/modules/PatchManager"
            if (-not $WhatIf) {
                Test-Path $patchManagerDir | Should -Be $true
                $testFiles = Get-ChildItem $patchManagerDir -Filter "*.Tests.ps1"
                $testFiles.Count | Should -BeGreaterThan 0
            }
        }
        
        It "Should have comprehensive tests in system directory" {
            $systemDir = Join-Path $testsRoot "system"
            if (-not $WhatIf) {
                Test-Path $systemDir | Should -Be $true
                $comprehensiveTests = Get-ChildItem $systemDir -Filter "*Validation*.Tests.ps1"
                $comprehensiveTests.Count | Should -BeGreaterThan 0
            }
        }
    }
}
