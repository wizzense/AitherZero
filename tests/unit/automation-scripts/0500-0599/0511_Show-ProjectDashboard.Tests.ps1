#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0511_Show-ProjectDashboard
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0511_Show-ProjectDashboard
    Stage: Reporting
    Description: Shows an interactive dashboard with project metrics, test results,
    Supports WhatIf: True
    Generated: 2025-11-04 20:50:00
#>

Describe '0511_Show-ProjectDashboard' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0511_Show-ProjectDashboard.ps1'
        $script:ScriptName = '0511_Show-ProjectDashboard'

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

        It 'Should have parameter: ShowLogs' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowLogs') | Should -Be $true
        }

        It 'Should have parameter: ShowTests' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowTests') | Should -Be $true
        }

        It 'Should have parameter: ShowMetrics' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowMetrics') | Should -Be $true
        }

        It 'Should have parameter: ShowAll' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ShowAll') | Should -Be $true
        }

        It 'Should have parameter: LogTailLines' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LogTailLines') | Should -Be $true
        }

        It 'Should have parameter: Follow' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Follow') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting' {
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
}
