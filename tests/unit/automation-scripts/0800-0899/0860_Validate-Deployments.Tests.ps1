#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0860_Validate-Deployments
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0860_Validate-Deployments
    Stage: Integration
    Description: Comprehensive validation script that checks:
    Generated: 2025-11-02 21:41:16
#>

Describe '0860_Validate-Deployments' -Tag 'Unit', 'AutomationScript', 'Integration' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0860_Validate-Deployments.ps1'
        $script:ScriptName = '0860_Validate-Deployments'
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
        It 'Should have parameter: CheckPages' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckPages') | Should -Be $true
        }

        It 'Should have parameter: CheckContainers' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckContainers') | Should -Be $true
        }

        It 'Should have parameter: CheckLocal' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CheckLocal') | Should -Be $true
        }

        It 'Should have parameter: Detailed' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Detailed') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Integration' {
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
