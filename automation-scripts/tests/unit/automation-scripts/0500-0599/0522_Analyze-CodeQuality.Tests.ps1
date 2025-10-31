#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0522_Analyze-CodeQuality
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0522_Analyze-CodeQuality
    Stage: Reporting
    Description: Code quality analysis for tech debt reporting
    Generated: 2025-10-30 02:11:49
#>

Describe '0522_Analyze-CodeQuality' -Tag 'Unit', 'AutomationScript', 'Reporting' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0522_Analyze-CodeQuality.ps1'
        $script:ScriptName = '0522_Analyze-CodeQuality'
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

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: UseCache' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UseCache') | Should -Be $true
        }

        It 'Should have parameter: Detailed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Detailed') | Should -Be $true
        }

        It 'Should have parameter: MaxFunctionLength' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxFunctionLength') | Should -Be $true
        }

        It 'Should have parameter: MaxComplexity' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxComplexity') | Should -Be $true
        }

        It 'Should have parameter: ExcludePaths' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ExcludePaths') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Reporting' {
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
