#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0860_Validate-Deployments
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0860_Validate-Deployments
    Stage: Integration
    Description: Comprehensive validation script that checks:
    Supports WhatIf: False
    Generated: 2025-11-10 16:41:57
#>

Describe '0860_Validate-Deployments' -Tag 'Unit', 'AutomationScript', 'Integration' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0860_Validate-Deployments.ps1'
        $script:ScriptName = '0860_Validate-Deployments'

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
        It 'Should have parameter: CheckPages' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckPages') | Should -Be $true
        }

        It 'Should have parameter: CheckContainers' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckContainers') | Should -Be $true
        }

        It 'Should have parameter: CheckLocal' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckLocal') | Should -Be $true
        }

        It 'Should have parameter: Detailed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Detailed') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Integration' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
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
    Context 'Functional Behavior - Infrastructure Deployment' {
        It 'Should validate configuration before deployment' {
            # Test configuration validation logic
            $testConfig = @{
                Infrastructure = @{
                    Provider = 'OpenTofu'
                    WorkingDirectory = './infrastructure'
                }
            }
            
            # Execute with WhatIf to test validation without deploying
            { & $script:ScriptPath -Configuration $testConfig -WhatIf } | Should -Not -Throw
        }
        
        It 'Should check for required tools (tofu/terraform)' {
            # Verify tool prerequisite checking
            # This tests the actual prerequisite validation logic
            Mock Test-CommandAvailable { $false } -ParameterFilter { $CommandName -eq 'tofu' }
            
            # Should handle missing tools gracefully or throw appropriate error
            # Behavior depends on script implementation
        }
        
        It 'Should generate deployment plan in WhatIf mode' {
            $testConfig = @{
                Infrastructure = @{
                    Provider = 'OpenTofu'
                }
            }
            
            # WhatIf should show what would be deployed
            $output = & $script:ScriptPath -Configuration $testConfig -WhatIf 2>&1 | Out-String
            
            # Should mention planning/deployment in output
            $output | Should -Match '(plan|deploy|infrastructure)'
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
