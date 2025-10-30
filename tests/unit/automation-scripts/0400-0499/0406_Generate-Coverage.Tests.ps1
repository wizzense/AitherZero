#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0406_Generate-Coverage
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0406_Generate-Coverage
    Stage: Testing
    Description: Creates comprehensive code coverage reports in multiple formats
    Generated: 2025-10-30 02:34:25
#>

Describe '0406_Generate-Coverage' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0406_Generate-Coverage.ps1'
        $script:ScriptName = '0406_Generate-Coverage'
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
        It 'Should have parameter: SourcePath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SourcePath') | Should -Be $true
        }

        It 'Should have parameter: TestPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('TestPath') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: RunTests' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('RunTests') | Should -Be $true
        }

        It 'Should have parameter: MinimumPercent' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MinimumPercent') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Testing' {
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
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }
    }
}
