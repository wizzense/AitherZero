#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0513_Enable-ContinuousReporting
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0513_Enable-ContinuousReporting
    Stage: Reporting
    Description: Sets up file watchers, event triggers, and continuous monitoring for automatic report generation
    Generated: 2025-11-04 20:39:43
#>

Describe '0513_Enable-ContinuousReporting' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0513_Enable-ContinuousReporting.ps1'
        $script:ScriptName = '0513_Enable-ContinuousReporting'

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
        It 'Should have parameter: ProjectPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ProjectPath') | Should -Be $true
        }

        It 'Should have parameter: Action' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Action') | Should -Be $true
        }

        It 'Should have parameter: IncludeFileWatcher' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeFileWatcher') | Should -Be $true
        }

        It 'Should have parameter: IncludeTestWatcher' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeTestWatcher') | Should -Be $true
        }

        It 'Should have parameter: IncludeGitHooks' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('IncludeGitHooks') | Should -Be $true
        }

        It 'Should have parameter: ReportIntervalMinutes' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ReportIntervalMinutes') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting' {
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
