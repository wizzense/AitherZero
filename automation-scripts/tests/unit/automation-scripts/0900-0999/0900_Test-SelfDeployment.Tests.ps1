#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0900_Test-SelfDeployment
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0900_Test-SelfDeployment
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0900_Test-SelfDeployment' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0900_Test-SelfDeployment.ps1'
        $script:ScriptName = '0900_Test-SelfDeployment'
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

        It 'Should have parameter: TestPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestPath') | Should -Be $true
        }

        It 'Should have parameter: CleanupOnSuccess' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CleanupOnSuccess') | Should -Be $true
        }

        It 'Should have parameter: FullTest' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('FullTest') | Should -Be $true
        }

        It 'Should have parameter: QuickTest' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('QuickTest') | Should -Be $true
        }

        It 'Should have parameter: Branch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Branch') | Should -Be $true
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
