#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0852_Validate-PRDockerDeployment
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0852_Validate-PRDockerDeployment
    Stage: Testing
    Description: Comprehensive validation script that tests the PR Docker deployment process end-to-end.
    Generated: 2025-11-02 21:41:16
#>

Describe '0852_Validate-PRDockerDeployment' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0852_Validate-PRDockerDeployment.ps1'
        $script:ScriptName = '0852_Validate-PRDockerDeployment'
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
        It 'Should have parameter: PRNumber' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('PRNumber') | Should -Be $true
        }

        It 'Should have parameter: SkipBuild' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipBuild') | Should -Be $true
        }

        It 'Should have parameter: SkipCleanup' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipCleanup') | Should -Be $true
        }

        It 'Should have parameter: Detail' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Detail') | Should -Be $true
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
