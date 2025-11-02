#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0701_Create-FeatureBranch
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0701_Create-FeatureBranch
    Stage: Development
    Description: Creates a new feature branch following project conventions and optionally
    Generated: 2025-11-02 21:41:15
#>

Describe '0701_Create-FeatureBranch' -Tag 'Unit', 'AutomationScript', 'Development' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1'
        $script:ScriptName = '0701_Create-FeatureBranch'
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
        It 'Should have parameter: Type' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Type') | Should -Be $true
        }

        It 'Should have parameter: Name' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Name') | Should -Be $true
        }

        It 'Should have parameter: Description' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Description') | Should -Be $true
        }

        It 'Should have parameter: CreateIssue' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CreateIssue') | Should -Be $true
        }

        It 'Should have parameter: Labels' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Labels') | Should -Be $true
        }

        It 'Should have parameter: Checkout' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Checkout') | Should -Be $true
        }

        It 'Should have parameter: Push' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Push') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

<<<<<<< HEAD
<<<<<<< HEAD
=======
=======
>>>>>>> bf56628fa1b22284358a1f4e67344a2a4ee9919d
        It 'Should have parameter: NonInteractive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('NonInteractive') | Should -Be $true
        }

<<<<<<< HEAD
>>>>>>> bf56628fa1b22284358a1f4e67344a2a4ee9919d
=======
>>>>>>> bf56628fa1b22284358a1f4e67344a2a4ee9919d
    }

    Context 'Metadata' {
        It 'Should be in stage: Development' {
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
