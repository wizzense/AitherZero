#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0440_Validate-Workflows
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0440_Validate-Workflows
    Stage: Testing
    Description: Comprehensive validation of GitHub Actions workflows including:
    Generated: 2025-11-04 20:39:42
#>

Describe '0440_Validate-Workflows' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0440_Validate-Workflows.ps1'
        $script:ScriptName = '0440_Validate-Workflows'

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
        It 'Should have parameter: Path' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Path') | Should -Be $true
        }

        It 'Should have parameter: Strict' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Strict') | Should -Be $true
        }

        It 'Should have parameter: AutoFix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AutoFix') | Should -Be $true
        }

        It 'Should have parameter: OutputFormat' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputFormat') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

        It 'Should have parameter: CheckDependencies' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckDependencies') | Should -Be $true
        }

        It 'Should have parameter: CheckSecrets' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckSecrets') | Should -Be $true
        }

        It 'Should have parameter: CheckDeprecated' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckDeprecated') | Should -Be $true
        }

        It 'Should have parameter: CheckBestPractices' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckBestPractices') | Should -Be $true
        }

        It 'Should have parameter: All' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('All') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }
    }

    Context 'Execution' {
        It 'Should execute with WhatIf' {
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
            # Skip if not in CI
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            
            # This test only runs in CI
            $script:TestEnv.IsCI | Should -Be $true
            $env:CI | Should -Not -BeNullOrEmpty
        }

        It 'Should adapt to local environment' {
            # Skip if in CI
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Local-only validation"
                return
            }
            
            # This test only runs locally
            $script:TestEnv.IsCI | Should -Be $false
        }
    }
}
