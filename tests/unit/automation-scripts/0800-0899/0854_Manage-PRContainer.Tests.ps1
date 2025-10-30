#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0854_Manage-PRContainer
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0854_Manage-PRContainer
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0854_Manage-PRContainer' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0854_Manage-PRContainer.ps1'
        $script:ScriptName = '0854_Manage-PRContainer'
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
        It 'Should have parameter: Action' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Action') | Should -Be $true
        }

        It 'Should have parameter: PRNumber' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('PRNumber') | Should -Be $true
        }

        It 'Should have parameter: Command' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Command') | Should -Be $true
        }

        It 'Should have parameter: ImageTag' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ImageTag') | Should -Be $true
        }

        It 'Should have parameter: Port' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Port') | Should -Be $true
        }

        It 'Should have parameter: Follow' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Follow') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
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
