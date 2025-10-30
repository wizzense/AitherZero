#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0709_Post-PRComment
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0709_Post-PRComment
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0709_Post-PRComment' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0709_Post-PRComment.ps1'
        $script:ScriptName = '0709_Post-PRComment'
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
        It 'Should have parameter: TestResultsPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestResultsPath') | Should -Be $true
        }

        It 'Should have parameter: Repository' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Repository') | Should -Be $true
        }

        It 'Should have parameter: RunId' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunId') | Should -Be $true
        }

        It 'Should have parameter: PRNumber' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('PRNumber') | Should -Be $true
        }

        It 'Should have parameter: Token' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Token') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
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
