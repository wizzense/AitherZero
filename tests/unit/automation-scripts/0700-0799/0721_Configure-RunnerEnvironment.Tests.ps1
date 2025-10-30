#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0721_Configure-RunnerEnvironment
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0721_Configure-RunnerEnvironment
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0721_Configure-RunnerEnvironment' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0721_Configure-RunnerEnvironment.ps1'
        $script:ScriptName = '0721_Configure-RunnerEnvironment'
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
        It 'Should have parameter: ProfileName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ProfileName') | Should -Be $true
        }

        It 'Should have parameter: Platform' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Platform') | Should -Be $true
        }

        It 'Should have parameter: RunnerUser' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunnerUser') | Should -Be $true
        }

        It 'Should have parameter: InstallDependencies' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('InstallDependencies') | Should -Be $true
        }

        It 'Should have parameter: ConfigurePowerShell' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ConfigurePowerShell') | Should -Be $true
        }

        It 'Should have parameter: SetupTools' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SetupTools') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
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
