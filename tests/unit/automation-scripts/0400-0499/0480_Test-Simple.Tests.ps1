#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0480_Test-Simple
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0480_Test-Simple
    Stage: Testing
    Description: Completely redesigned testing infrastructure that:
    Generated: 2025-11-02 21:41:15
#>

Describe '0480_Test-Simple' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0480_Test-Simple.ps1'
        $script:ScriptName = '0480_Test-Simple'
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
        It 'Should have parameter: TestPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestPath') | Should -Be $true
        }

        It 'Should have parameter: Mode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Mode') | Should -Be $true
        }

        It 'Should have parameter: Workers' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Workers') | Should -Be $true
        }

        It 'Should have parameter: BatchSize' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('BatchSize') | Should -Be $true
        }

        It 'Should have parameter: FailFast' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('FailFast') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

        It 'Should have parameter: Quiet' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Quiet') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 20
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
}
