#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0960_Track-DocumentationFreshness
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0960_Track-DocumentationFreshness
    Stage: 0960 (Documentation Tracking)
    Description: Analyzes when documentation files were last modified compared to the code they document.
    Generated: 2025-11-04 07:53:36
#>

Describe '0960_Track-DocumentationFreshness' -Tag 'Unit', 'AutomationScript', '0960 (Documentation Tracking)' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0960_Track-DocumentationFreshness.ps1'
        $script:ScriptName = '0960_Track-DocumentationFreshness'

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
        It 'Should have parameter: ReportOnly' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ReportOnly') | Should -Be $true
        }

        It 'Should have parameter: CheckStale' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckStale') | Should -Be $true
        }

        It 'Should have parameter: StaleDays' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('StaleDays') | Should -Be $true
        }

        It 'Should have parameter: CreateIssues' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CreateIssues') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: 0960 (Documentation Tracking)' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match 'Dependencies:'
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
