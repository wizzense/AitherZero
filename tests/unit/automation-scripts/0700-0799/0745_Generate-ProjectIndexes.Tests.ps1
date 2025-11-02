#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0745_Generate-ProjectIndexes
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0745_Generate-ProjectIndexes
    Stage: Automation
    Description: Automatically generates index.md files for all directories in the project,
    Generated: 2025-11-02 21:41:15
#>

Describe '0745_Generate-ProjectIndexes' -Tag 'Unit', 'AutomationScript', 'Automation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0745_Generate-ProjectIndexes.ps1'
        $script:ScriptName = '0745_Generate-ProjectIndexes'
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

        It 'Should have parameter: RootPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RootPath') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have parameter: UpdateManifest' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UpdateManifest') | Should -Be $true
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
