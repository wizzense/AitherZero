#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0737_Monitor-AIUsage
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0737_Monitor-AIUsage
    Stage: Automation
    Description: Tracks API usage, generates cost reports, monitors rate limits,
    Generated: 2025-11-02 21:41:15
#>

Describe '0737_Monitor-AIUsage' -Tag 'Unit', 'AutomationScript', 'Automation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0737_Monitor-AIUsage.ps1'
        $script:ScriptName = '0737_Monitor-AIUsage'
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
        It 'Should have parameter: ReportType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ReportType') | Should -Be $true
        }

        It 'Should have parameter: Period' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Period') | Should -Be $true
        }

        It 'Should have parameter: SendAlert' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SendAlert') | Should -Be $true
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
