#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0754_Create-MCPServer
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0754_Create-MCPServer
    Stage: Automation
    Description: Scaffolds a new Model Context Protocol (MCP) server using the AitherZero
    Generated: 2025-11-03 18:29:59
#>

Describe '0754_Create-MCPServer' -Tag 'Unit', 'AutomationScript', 'Automation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0754_Create-MCPServer.ps1'
        $script:ScriptName = '0754_Create-MCPServer'
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
        It 'Should have parameter: ServerName' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('ServerName') | Should -Be $true
        }

        It 'Should have parameter: Description' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Description') | Should -Be $true
        }

        It 'Should have parameter: Author' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Author') | Should -Be $true
        }

        It 'Should have parameter: OutputPath' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputPath') | Should -Be $true
        }

        It 'Should have parameter: Organization' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Organization') | Should -Be $true
        }

        It 'Should have parameter: SkipInstall' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipInstall') | Should -Be $true
        }

        It 'Should have parameter: SkipGit' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipGit') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Automation' {
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
