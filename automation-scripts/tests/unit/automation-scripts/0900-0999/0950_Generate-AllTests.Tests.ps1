#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0950_Generate-AllTests
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0950_Generate-AllTests
    Stage: Unknown
    Description: This script automatically generates and maintains tests for ALL AitherZero components:
    Generated: 2025-10-30 03:24:50
#>

Describe '0950_Generate-AllTests' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0950_Generate-AllTests.ps1'
        $script:ScriptName = '0950_Generate-AllTests'
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
        It 'Should have parameter: Mode' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Mode') | Should -Be $true
        }

        It 'Should have parameter: Configuration' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Configuration') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have parameter: RunTests' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunTests') | Should -Be $true
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
                $params.Configuration = @{}
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }
    }
}
