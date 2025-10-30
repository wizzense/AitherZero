#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0402_Run-UnitTests
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0402_Run-UnitTests
    Stage: Testing
    Description: Runs all unit tests using Pester framework with code coverage
    Generated: 2025-10-30 02:34:24
#>

Describe '0402_Run-UnitTests' -Tag 'Unit', 'AutomationScript', 'Testing' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0402_Run-UnitTests.ps1'
        $script:ScriptName = '0402_Run-UnitTests'
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

        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: PassThru' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('PassThru') | Should -Be $true
        }

        It 'Should have parameter: NoCoverage' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NoCoverage') | Should -Be $true
        }

        It 'Should have parameter: CI' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CI') | Should -Be $true
        }

        It 'Should have parameter: UseCache' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('UseCache') | Should -Be $true
        }

        It 'Should have parameter: ForceRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ForceRun') | Should -Be $true
        }

        It 'Should have parameter: CacheMinutes' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CacheMinutes') | Should -Be $true
        }

        It 'Should have parameter: CoverageThreshold' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CoverageThreshold') | Should -Be $true
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
