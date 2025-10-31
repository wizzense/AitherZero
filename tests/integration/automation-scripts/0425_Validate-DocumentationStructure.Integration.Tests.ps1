#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0425_Validate-DocumentationStructure
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-10-31 16:45:52
#>

Describe '0425_Validate-DocumentationStructure Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0425_Validate-DocumentationStructure.ps1'
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
}
