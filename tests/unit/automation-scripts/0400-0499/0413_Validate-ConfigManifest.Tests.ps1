#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0413_Validate-ConfigManifest
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0413_Validate-ConfigManifest
    Stage: Testing
    Description: Performs comprehensive validation of config.psd1 including:
    Generated: 2025-11-02 21:41:15
#>

Describe '0413_Validate-ConfigManifest' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0413_Validate-ConfigManifest.ps1'
        $script:ScriptName = '0413_Validate-ConfigManifest'
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
        It 'Should have parameter: ConfigPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ConfigPath') | Should -Be $true
        }

        It 'Should have parameter: Fix' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Fix') | Should -Be $true
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
