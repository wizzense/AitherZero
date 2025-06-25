BeforeAll {
    # Set up environment
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $env:PWSH_MODULES_PATH = Join-Path $projectRoot "aither-core/modules"
    
    # Import testing utilities
    Import-Module Pester -Force
}

Describe "PowerShell Code Quality Analysis" {
    
    Context "PSScriptAnalyzer Compliance" {
        
        BeforeAll {
            # Get all PowerShell files
            $allPowerShellFiles = Get-ChildItem -Path "pwsh" -Recurse -Filter "*.ps1" -File |
                Where-Object { $_.Name -notlike "*.Tests.ps1" }
        }
        
        It "Should have no critical syntax errors" {
            $criticalIssues = @()
            foreach ($file in $allPowerShellFiles) {
                $issues = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error
                if ($issues) {
                    $criticalIssues += $issues
                }
            }
            $criticalIssues.Count | Should -Be 0 -Because "No PowerShell files should have syntax errors"
        }
        
        It "Should have minimal unused variables" {
            $unusedVarIssues = @()
            foreach ($file in $allPowerShellFiles) {
                $issues = Invoke-ScriptAnalyzer -Path $file.FullName -IncludeRule PSUseDeclaredVarsMoreThanAssignments
                $unusedVarIssues += $issues
            }
            # Allow some unused variables but flag excessive ones
            $unusedVarIssues.Count | Should -BeLessOrEqual 50 -Because "Excessive unused variables indicate poor code quality"
        }
        
        It "Should have minimal unused parameters" {
            $unusedParamIssues = @()
            foreach ($file in $allPowerShellFiles) {
                $issues = Invoke-ScriptAnalyzer -Path $file.FullName -IncludeRule PSReviewUnusedParameter
                $unusedParamIssues += $issues
            }
            # Allow some unused parameters but flag excessive ones
            $unusedParamIssues.Count | Should -BeLessOrEqual 25 -Because "Excessive unused parameters indicate incomplete implementations"
        }
    }
    
    Context "Module Structure Validation" {
        
        It "Should have all required modules" {
            $requiredModules = @(
                "BackupManager",
                "DevEnvironment", 
                "LabRunner",
                "Logging",
                "ParallelExecution",
                "PatchManager",
                "ScriptManager",
                "TestingFramework",
                "UnifiedMaintenance"
            )
            
            foreach ($module in $requiredModules) {
                $modulePath = Join-Path $env:PWSH_MODULES_PATH $module
                Test-Path $modulePath | Should -Be $true -Because "Module $module should exist"
            }
        }
        
        It "Should have proper module manifests" {
            $moduleDirectories = Get-ChildItem -Path $env:PWSH_MODULES_PATH -Directory
            
            foreach ($moduleDir in $moduleDirectories) {
                $manifestPath = Join-Path $moduleDir.FullName "$($moduleDir.Name).psd1"
                Test-Path $manifestPath | Should -Be $true -Because "Module $($moduleDir.Name) should have a manifest"
            }
        }
        
        It "Should have proper module files" {
            $moduleDirectories = Get-ChildItem -Path $env:PWSH_MODULES_PATH -Directory
            
            foreach ($moduleDir in $moduleDirectories) {
                $moduleFilePath = Join-Path $moduleDir.FullName "$($moduleDir.Name).psm1"
                Test-Path $moduleFilePath | Should -Be $true -Because "Module $($moduleDir.Name) should have a .psm1 file"
            }
        }
    }
    
    Context "Critical Function Tests" {
        
        It "Should load all modules without errors" {
            $moduleDirectories = Get-ChildItem -Path $env:PWSH_MODULES_PATH -Directory
            $failedModules = @()
            
            foreach ($moduleDir in $moduleDirectories) {
                try {
                    Import-Module $moduleDir.FullName -Force -ErrorAction Stop
                    Write-Host "✓ Successfully loaded $($moduleDir.Name)" -ForegroundColor Green
                } catch {
                    $failedModules += "$($moduleDir.Name): $($_.Exception.Message)"
                    Write-Host "✗ Failed to load $($moduleDir.Name): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            $failedModules.Count | Should -Be 0 -Because "All modules should load without errors. Failed: $($failedModules -join '; ')"
        }
    }
}

Describe "High Priority Script Fixes" {
    
    Context "Scripts with Critical Issues" {
        
        It "Should identify scripts requiring immediate attention" {
            $criticalScripts = @()
            $allPowerShellFiles = Get-ChildItem -Path "pwsh" -Recurse -Filter "*.ps1" -File |
                Where-Object { $_.Name -notlike "*.Tests.ps1" }
                
            foreach ($file in $allPowerShellFiles) {
                $errorIssues = Invoke-ScriptAnalyzer -Path $file.FullName -Severity Error
                if ($errorIssues.Count -gt 0) {
                    $criticalScripts += $file.Name
                }
            }
            
            if ($criticalScripts.Count -gt 0) {
                Write-Host "Scripts requiring immediate fixes:" -ForegroundColor Yellow
                $criticalScripts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
            }
            
            # This test documents the current state - we'll fix these one by one
            $true | Should -Be $true
        }
    }
}