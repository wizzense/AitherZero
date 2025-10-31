#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0530_View-Logs
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0530_View-Logs
    Stage: Reporting
    Description: View and manage AitherZero logs
    Generated: 2025-10-30 02:11:49
#>

Describe '0530_View-Logs' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0530_View-Logs.ps1'
        $script:ScriptName = '0530_View-Logs'
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
        It 'Should have parameter: Configuration' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Configuration') | Should -Be $true
        }

        It 'Should have parameter: Mode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Mode') | Should -Be $true
        }

        It 'Should have parameter: Tail' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Tail') | Should -Be $true
        }

        It 'Should have parameter: Follow' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Follow') | Should -Be $true
        }

        It 'Should have parameter: SearchPattern' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SearchPattern') | Should -Be $true
        }

        It 'Should have parameter: Level' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Level') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting' {
            $content = Get-Content $script:ScriptPath -First 20
            ($content -join ' ') | Should -Match 'Stage:'
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
                $params.Configuration = @{}
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }
    }
}
