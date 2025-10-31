#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0705_Push-Branch
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0705_Push-Branch
    Stage: Unknown
    Generated: 2025-10-30 02:11:49
#>

Describe '0705_Push-Branch' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0705_Push-Branch.ps1'
        $script:ScriptName = '0705_Push-Branch'
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
        It 'Should have parameter: Branch' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Branch') | Should -Be $true
        }

        It 'Should have parameter: Remote' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Remote') | Should -Be $true
        }

        It 'Should have parameter: SetUpstream' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SetUpstream') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have parameter: ForceWithLease' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ForceWithLease') | Should -Be $true
        }

        It 'Should have parameter: Tags' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Tags') | Should -Be $true
        }

        It 'Should have parameter: All' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('All') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: NonInteractive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NonInteractive') | Should -Be $true
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
