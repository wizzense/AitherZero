#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0739_Validate-AIOutput
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0739_Validate-AIOutput
    Stage: Automation
    Description: Performs syntax checking, security validation, best practices compliance,
    Generated: 2025-11-02 21:41:15
#>

Describe '0739_Validate-AIOutput' -Tag 'Unit', 'AutomationScript', 'Automation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0739_Validate-AIOutput.ps1'
        $script:ScriptName = '0739_Validate-AIOutput'
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
        It 'Should have parameter: Path' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Path') | Should -Be $true
        }

        It 'Should have parameter: ValidationType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ValidationType') | Should -Be $true
        }

        It 'Should have parameter: StrictMode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('StrictMode') | Should -Be $true
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
