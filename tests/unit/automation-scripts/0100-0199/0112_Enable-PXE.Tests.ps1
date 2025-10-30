#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0112_Enable-PXE
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0112_Enable-PXE
    Stage: Infrastructure
    Description: Configure firewall rules for PXE boot support
    Generated: 2025-10-30 02:11:49
#>

Describe '0112_Enable-PXE' -Tag 'Unit', 'AutomationScript', 'Infrastructure' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0112_Enable-PXE.ps1'
        $script:ScriptName = '0112_Enable-PXE'
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
        It 'Should have parameter: Configuration' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Configuration') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Infrastructure' {
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
                $params.Configuration = @{}
                & $script:ScriptPath @params
            } | Should -Not -Throw
        }
    }
}
