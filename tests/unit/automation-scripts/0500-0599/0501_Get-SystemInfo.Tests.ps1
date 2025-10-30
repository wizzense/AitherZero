#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0501_Get-SystemInfo
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0501_Get-SystemInfo
    Stage: Validation
    Description: Gather and display comprehensive system information
    Generated: 2025-10-30 02:11:49
#>

Describe '0501_Get-SystemInfo' -Tag 'Unit', 'AutomationScript', 'Validation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0501_Get-SystemInfo.ps1'
        $script:ScriptName = '0501_Get-SystemInfo'
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

        It 'Should have parameter: AsJson' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('AsJson') | Should -Be $true
        }

        It 'Should have parameter: OutputFormat' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputFormat') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Validation' {
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
