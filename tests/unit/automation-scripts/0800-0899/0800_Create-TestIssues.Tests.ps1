#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0800_Create-TestIssues
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0800_Create-TestIssues
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0800_Create-TestIssues' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0800_Create-TestIssues.ps1'
        $script:ScriptName = '0800_Create-TestIssues'
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
        It 'Should have parameter: Source' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Source') | Should -Be $true
        }

        It 'Should have parameter: ResultsPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ResultsPath') | Should -Be $true
        }

        It 'Should have parameter: Labels' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Labels') | Should -Be $true
        }

        It 'Should have parameter: DefaultPriority' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DefaultPriority') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: GroupByFile' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('GroupByFile') | Should -Be $true
        }

        It 'Should have parameter: MaxIssues' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxIssues') | Should -Be $true
        }

        It 'Should have parameter: UpdateExisting' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UpdateExisting') | Should -Be $true
        }

        It 'Should have parameter: Milestone' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Milestone') | Should -Be $true
        }

        It 'Should have parameter: Assignees' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Assignees') | Should -Be $true
        }

        It 'Should have parameter: NonInteractive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NonInteractive') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Unknown' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Stage:'
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
