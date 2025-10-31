#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0730_Setup-AIAgents
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0730_Setup-AIAgents
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0730_Setup-AIAgents' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0730_Setup-AIAgents.ps1'
        $script:ScriptName = '0730_Setup-AIAgents'
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
        It 'Should have parameter: Provider' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Provider') | Should -Be $true
        }

        It 'Should have parameter: ValidateOnly' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ValidateOnly') | Should -Be $true
        }

        It 'Should have parameter: ConfigPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ConfigPath') | Should -Be $true
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
