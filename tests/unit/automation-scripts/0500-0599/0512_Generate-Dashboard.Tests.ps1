#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0512_Generate-Dashboard
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0512_Generate-Dashboard
    Stage: Reporting
    Description: Creates HTML and Markdown dashboards showing project health, test results,
    Generated: 2025-11-02 21:41:15
#>

Describe '0512_Generate-Dashboard' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0512_Generate-Dashboard.ps1'
        $script:ScriptName = '0512_Generate-Dashboard'
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

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: TemplatePath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TemplatePath') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: Open' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Open') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 40
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
