#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0901_Test-LocalDeployment
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0901_Test-LocalDeployment
    Stage: Validation
    Description: Validates that AitherZero can deploy and set itself up locally without
    Generated: 2025-11-02 21:41:16
#>

Describe '0901_Test-LocalDeployment' -Tag 'Unit', 'AutomationScript', 'Validation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0901_Test-LocalDeployment.ps1'
        $script:ScriptName = '0901_Test-LocalDeployment'
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

        It 'Should have parameter: QuickTest' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('QuickTest') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Validation' {
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
