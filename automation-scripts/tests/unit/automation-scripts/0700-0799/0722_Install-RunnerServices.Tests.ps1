#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0722_Install-RunnerServices
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0722_Install-RunnerServices
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0722_Install-RunnerServices' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0722_Install-RunnerServices.ps1'
        $script:ScriptName = '0722_Install-RunnerServices'
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
        It 'Should have parameter: RunnerName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunnerName') | Should -Be $true
        }

        It 'Should have parameter: ServiceType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ServiceType') | Should -Be $true
        }

        It 'Should have parameter: StartupType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('StartupType') | Should -Be $true
        }

        It 'Should have parameter: RunAsUser' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunAsUser') | Should -Be $true
        }

        It 'Should have parameter: EnableMonitoring' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('EnableMonitoring') | Should -Be $true
        }

        It 'Should have parameter: LogLevel' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LogLevel') | Should -Be $true
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
