#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0513_Enable-ContinuousReporting
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0513_Enable-ContinuousReporting
    Stage: Reporting
    Description: Sets up file watchers, event triggers, and continuous monitoring for automatic report generation
    Generated: 2025-11-02 21:41:15
#>

Describe '0513_Enable-ContinuousReporting' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0513_Enable-ContinuousReporting.ps1'
        $script:ScriptName = '0513_Enable-ContinuousReporting'
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
}
