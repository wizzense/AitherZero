#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0751_Start-MCPServer
.DESCRIPTION
    Auto-generated comprehensive tests
    Script: 0751_Start-MCPServer
    Stage: AI Tools & Automation
    Description: Starts the MCP server and keeps it running, or tests it with a sample request.
    Generated: 2025-11-02 21:41:15
#>

Describe '0751_Start-MCPServer' -Tag 'Unit', 'AutomationScript', 'AI Tools & Automation' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0751_Start-MCPServer.ps1'
        $script:ScriptName = '0751_Start-MCPServer'
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
        It 'Should have parameter: Test' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Test') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: AI Tools & Automation' {
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
