#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0700_Setup-GitEnvironment
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0700_Setup-GitEnvironment
    Stage: Development
    Description: Configures Git with recommended settings, aliases, and hooks for the project.
    Generated: 2025-11-02 21:41:15
#>

Describe '0700_Setup-GitEnvironment' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0700_Setup-GitEnvironment.ps1'
        $script:ScriptName = '0700_Setup-GitEnvironment'
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
        It 'Should have parameter: UserName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UserName') | Should -Be $true
        }

        It 'Should have parameter: UserEmail' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UserEmail') | Should -Be $true
        }

        It 'Should have parameter: Global' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Global') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
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
