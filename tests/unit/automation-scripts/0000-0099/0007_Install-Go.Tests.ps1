#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0007_Install-Go
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0007_Install-Go
    Stage: Development
    Description: Install Go programming language using package managers (winget priority)
    Generated: 2025-10-30 02:11:49
#>

Describe '0007_Install-Go' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0007_Install-Go.ps1'
        $script:ScriptName = '0007_Install-Go'
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
        It 'Should be in stage: Development' {
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
