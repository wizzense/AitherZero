#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0009_Setup-MCPServers
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0009_Setup-MCPServers
    Stage: Environment
    Description: This script provides complete MCP server lifecycle management:
    Generated: 2025-11-02 21:41:15
#>

Describe '0009_Setup-MCPServers' -Tag 'Unit', 'AutomationScript', 'Environment' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0009_Setup-MCPServers.ps1'
        $script:ScriptName = '0009_Setup-MCPServers'
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
        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It 'Should have parameter: SkipValidation' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('SkipValidation') | Should -Be $true
        }

        It 'Should have parameter: FixConfig' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('FixConfig') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Environment' {
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
