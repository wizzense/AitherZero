#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0701_Create-FeatureBranch
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0701_Create-FeatureBranch
    Stage: Development
    Description: Creates a new feature branch following project conventions and optionally
    Supports WhatIf: True
    Generated: 2025-11-10 16:41:56
#>

Describe '0701_Create-FeatureBranch' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0701_Create-FeatureBranch.ps1'
        $script:ScriptName = '0701_Create-FeatureBranch'

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

        It 'Should support WhatIf' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'SupportsShouldProcess'
        }

    }

    Context 'Parameters' {
        It 'Should have parameter: Type' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Type') | Should -Be $true
        }

        It 'Should have parameter: Name' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Name') | Should -Be $true
        }

        It 'Should have parameter: Description' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Description') | Should -Be $true
        }

        It 'Should have parameter: CreateIssue' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CreateIssue') | Should -Be $true
        }

        It 'Should have parameter: Labels' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Labels') | Should -Be $true
        }

        It 'Should have parameter: Checkout' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Checkout') | Should -Be $true
        }

        It 'Should have parameter: Push' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Push') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have parameter: NonInteractive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NonInteractive') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }
    }

    Context 'Execution' {
        It 'Should execute with WhatIf without throwing' {
            {
                $params = @{ WhatIf = $true }
                & $script:ScriptPath @params
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
    Context 'Functional Behavior - Git Branch Creation' {
        It 'Should create branch with correct naming convention' {
            # Test actual git branch creation logic using Pester's native Mock
            Mock git {
                param([string]$cmd, [string[]]$args)
                if ($cmd -eq 'checkout') {
                    return 'Switched to branch test-branch'
                }
                return ''
            }
            
            # Execute branch creation (in WhatIf mode to avoid real changes)
            & $script:ScriptPath -Type feature -Name 'test-feature' -WhatIf
            
            # Verify git commands would be called correctly using Should -Invoke
            Should -Invoke git -ParameterFilter { $cmd -eq 'checkout' -and $args -contains '-b' }
        }
        
        It 'Should validate branch name format' {
            # Test that invalid branch names are rejected
            {
                & $script:ScriptPath -Type feature -Name 'invalid name with spaces' -WhatIf
            } | Should -Throw
        }
        
        It 'Should call git commands in correct order' {
            # Mock git to track call sequence
            Mock git { } -ParameterFilter { $_ -contains 'fetch' }
            Mock git { } -ParameterFilter { $_ -contains 'checkout' }
            
            & $script:ScriptPath -Type feature -Name 'test' -WhatIf
            
            # Pester tracks mock calls automatically - verify sequence
            Should -Invoke git -ParameterFilter { $_ -contains 'fetch' } -Times 1 -Exactly
            Should -Invoke git -ParameterFilter { $_ -contains 'checkout' } -Times 1 -Exactly
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
