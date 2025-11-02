#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0410_Run-PSScriptAnalyzer-Fast
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0410_Run-PSScriptAnalyzer-Fast
    Stage: Testing
    Description: Optimized PSScriptAnalyzer that excludes slow directories and focuses on critical issues only.
    Generated: 2025-11-02 21:41:15
#>

Describe '0410_Run-PSScriptAnalyzer-Fast' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0410_Run-PSScriptAnalyzer-Fast.ps1'
        $script:ScriptName = '0410_Run-PSScriptAnalyzer-Fast'
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
        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: CoreOnly' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CoreOnly') | Should -Be $true
        }

        It 'Should have parameter: MaxFiles' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxFiles') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
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
