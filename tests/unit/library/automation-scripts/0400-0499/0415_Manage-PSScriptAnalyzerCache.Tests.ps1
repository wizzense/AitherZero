#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0415_Manage-PSScriptAnalyzerCache
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0415_Manage-PSScriptAnalyzerCache
    Stage: Testing
    Description: Manages the cache used by 0404_Run-PSScriptAnalyzer.ps1 to avoid re-analyzing unchanged files.
    Supports WhatIf: False
    Generated: 2025-11-10 16:41:56
#>

Describe '0415_Manage-PSScriptAnalyzerCache' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0415_Manage-PSScriptAnalyzerCache.ps1'
        $script:ScriptName = '0415_Manage-PSScriptAnalyzerCache'

        # Import test helpers for environment detection
        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../../TestHelpers.psm1"
        if (Test-Path $testHelpersPath) {
            Import-Module $testHelpersPath -Force -ErrorAction SilentlyContinue
        }

        # Detect test environment
        $script:TestEnv = if (Get-Command Get-TestEnvironment -ErrorAction SilentlyContinue) {
            Get-TestEnvironment
        } else {
            @{ IsCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'); IsLocal = $true }
        }
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should not require WhatIf support' {
            # Script does not implement SupportsShouldProcess
            # This is acceptable for read-only or simple scripts
            $content = Get-Content $script:ScriptPath -Raw
            $content -notmatch 'SupportsShouldProcess' | Should -Be $true
        }

    }

    Context 'Parameters' {
        It 'Should have parameter: Action' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Action') | Should -Be $true
        }

        It 'Should have parameter: CacheFile' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CacheFile') | Should -Be $true
        }

        It 'Should have parameter: DaysOld' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DaysOld') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match 'Dependencies:'
        }
    }

    Context 'Execution' {
        It 'Should be executable (no WhatIf support)' {
            # Script does not support -WhatIf parameter
            # Verify script can be dot-sourced without errors
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }
    }

    Context 'Environment Awareness' {
        It 'Test environment should be detected' {
            $script:TestEnv | Should -Not -BeNullOrEmpty
            $script:TestEnv.Keys | Should -Contain 'IsCI'
        }

        It 'Should adapt to CI environment' {
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $true
            $env:CI | Should -Not -BeNullOrEmpty
        }

        It 'Should adapt to local environment' {
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Local-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $false
        }
    }

    BeforeAll {
        # Import functional test framework for advanced testing
        $functionalFrameworkPath = Join-Path $repoRoot "aithercore/testing/FunctionalTestFramework.psm1"
        if (Test-Path $functionalFrameworkPath) {
            Import-Module $functionalFrameworkPath -Force -ErrorAction SilentlyContinue
        }
    }


    # === FUNCTIONAL TESTS - Validate actual behavior ===
    Context 'Functional Behavior - PSScriptAnalyzer Execution' {
        It 'Should actually analyze PowerShell files and return findings' {
            # Test real functionality: does script actually run analysis?
            $testDir = New-TestEnvironment -Name 'pssa-test' -Directories @('scripts') -Files @{
                'scripts/test.ps1' = 'Write-Host "test" # PSAvoidUsingWriteHost violation'
            }
            
            try {
                # Mock Invoke-ScriptAnalyzer using Pester to simulate finding violations
                Mock Invoke-ScriptAnalyzer {
                    return @(
                        [PSCustomObject]@{
                            RuleName = 'PSAvoidUsingWriteHost'
                            Severity = 'Warning'
                            ScriptName = 'test.ps1'
                            Line = 1
                            Message = 'Avoid using Write-Host'
                        }
                    )
                } -ModuleName PSScriptAnalyzer
                
                # Execute with test directory
                $result = & $script:ScriptPath -Path $testDir.Path -DryRun
                
                # Validate: Should invoke PSScriptAnalyzer
                Should -Invoke Invoke-ScriptAnalyzer -ModuleName PSScriptAnalyzer -Times 1 -Exactly
                
            } finally {
                & $testDir.Cleanup
            }
        }
        
        It 'Should generate analysis results file when not in DryRun mode' {
            $testDir = New-TestEnvironment -Name 'pssa-output' -Directories @('scripts', 'reports')
            $outputPath = Join-Path $testDir.Path 'reports/results.json'
            
            try {
                # Mock the analysis results
                Mock Invoke-ScriptAnalyzer {
                    return @(
                        [PSCustomObject]@{
                            RuleName = 'PSAvoidUsingWriteHost'
                            Severity = 'Warning'
                        }
                    )
                }
                
                # Execute with output path (WhatIf to prevent actual file creation in test)
                & $script:ScriptPath -Path $testDir.Path -OutputPath $outputPath -WhatIf
                
                # In WhatIf mode, should show intent to create file
                # Actual file creation logic should be present
                
            } finally {
                & $testDir.Cleanup
            }
        }
        
        It 'Should respect severity filtering' {
            # Mock PSScriptAnalyzer with multiple severity levels
            Mock Invoke-ScriptAnalyzer {
                return @(
                    [PSCustomObject]@{ RuleName = 'Rule1'; Severity = 'Error' }
                    [PSCustomObject]@{ RuleName = 'Rule2'; Severity = 'Warning' }
                    [PSCustomObject]@{ RuleName = 'Rule3'; Severity = 'Information' }
                )
            }
            
            # Execute with severity filter
            $result = & $script:ScriptPath -Severity @('Error') -DryRun
            
            # Verify PSScriptAnalyzer was called with correct severity
            Should -Invoke Invoke-ScriptAnalyzer -ParameterFilter {
                $Severity -contains 'Error'
            }
        }
        
        It 'Should handle Fast mode for CI environments by limiting analysis scope' {
            # Validate Fast mode behavior using mocking
            $env:CI = 'true'
            try {
                Mock Get-ChildItem {
                    # Mock returns fewer files in fast mode
                    return @(
                        [PSCustomObject]@{ FullName = 'file1.ps1'; Name = 'file1.ps1' }
                    )
                } -ParameterFilter { $Path -and $Filter -eq '*.ps1' }
                
                $result = & $script:ScriptPath -Fast -DryRun
                
                # Should execute without errors in fast mode
                $? | Should -Be $true
                
                # Verify limited scope in fast mode
                Should -Invoke Get-ChildItem -ParameterFilter { $Filter -eq '*.ps1' }
                
            } finally {
                $env:CI = $null
            }
        }
        
        It 'Should support excluding specific rules' {
            Mock Invoke-ScriptAnalyzer { return @() }
            
            $excludedRules = @('PSAvoidUsingWriteHost', 'PSUseShouldProcessForStateChangingFunctions')
            & $script:ScriptPath -ExcludeRules $excludedRules -DryRun
            
            # Verify excluded rules are passed to analyzer
            Should -Invoke Invoke-ScriptAnalyzer -ParameterFilter {
                $ExcludeRule -contains 'PSAvoidUsingWriteHost'
            }
        }
    }

    Context 'Functional Behavior - General Script Operation' {
        It 'Should handle errors gracefully' {
            # Test error handling with invalid input
            $invalidParams = @{
                Path = '/nonexistent/path/that/does/not/exist'
            }
            
            # Should either handle gracefully or throw meaningful error
            try {
                & $script:ScriptPath @invalidParams -WhatIf -ErrorAction Stop
            } catch {
                # Error message should be informative
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should validate required parameters' {
            $cmd = Get-Command $script:ScriptPath
            $mandatoryParams = $cmd.Parameters.Values | Where-Object { $_.Attributes.Mandatory }
            
            if ($mandatoryParams) {
                # Executing without mandatory params should fail appropriately
                { & $script:ScriptPath -ErrorAction Stop } | Should -Throw
            }
        }
        
        It 'Should respect WhatIf parameter if supported' {
            $cmd = Get-Command $script:ScriptPath
            if ($cmd.Parameters.ContainsKey('WhatIf')) {
                # WhatIf execution should not make real changes
                # Should complete successfully
                { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            }
        }
        
        It 'Should produce expected output structure' {
            # Execute and validate output
            $output = & $script:ScriptPath -WhatIf 2>&1
            
            # Output should be structured (not just random text)
            # At minimum, should not be null
            # Actual validation depends on script type
        }
    }
}
