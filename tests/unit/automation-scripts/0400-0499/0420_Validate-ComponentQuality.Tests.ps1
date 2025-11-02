#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0420_Validate-ComponentQuality
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0420_Validate-ComponentQuality
    Stage: Testing
    Description: Comprehensive quality validation tool that checks:
    Generated: 2025-11-02 21:41:15
#>

Describe '0420_Validate-ComponentQuality' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0420_Validate-ComponentQuality.ps1'
        $script:ScriptName = '0420_Validate-ComponentQuality'
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

        It 'Should have parameter: Recursive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Recursive') | Should -Be $true
        }

        It 'Should have parameter: SkipChecks' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipChecks') | Should -Be $true
        }

        It 'Should have parameter: ExcludeDataFiles' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ExcludeDataFiles') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: FailOnWarnings' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('FailOnWarnings') | Should -Be $true
        }

        It 'Should have parameter: MinimumScore' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MinimumScore') | Should -Be $true
        }

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
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
