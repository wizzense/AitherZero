#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0860_Validate-Deployments
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0860_Validate-Deployments
    Stage: Unknown
    Description: Comprehensive validation script that checks:
    Generated: 2025-11-02 08:36:29
#>

Describe '0860_Validate-Deployments' -Tag 'Unit', 'AutomationScript', 'Unknown' {

    BeforeAll {
        # Resolve script path relative to repository root
        $script:TestRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ProjectRoot = Split-Path $script:TestRoot -Parent
        $script:ScriptPath = Join-Path $script:ProjectRoot "automation-scripts/0860_Validate-Deployments.ps1"
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
        It 'Should be in stage: Unknown' {
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
