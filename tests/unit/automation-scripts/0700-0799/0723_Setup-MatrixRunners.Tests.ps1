#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0723_Setup-MatrixRunners
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0723_Setup-MatrixRunners
    Stage: Automation
    Description: Provisions a matrix of GitHub Actions runners across different platforms and configurations
    Generated: 2025-11-02 21:41:15
#>

Describe '0723_Setup-MatrixRunners' -Tag 'Unit', 'AutomationScript', 'Automation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0723_Setup-MatrixRunners.ps1'
        $script:ScriptName = '0723_Setup-MatrixRunners'
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
        It 'Should have parameter: Organization' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Organization') | Should -Be $true
        }

        It 'Should have parameter: Repository' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Repository') | Should -Be $true
        }

        It 'Should have parameter: Matrix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Matrix') | Should -Be $true
        }

        It 'Should have parameter: Token' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Token') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: Parallel' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Parallel') | Should -Be $true
        }

        It 'Should have parameter: MaxConcurrency' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxConcurrency') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Automation' {
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
