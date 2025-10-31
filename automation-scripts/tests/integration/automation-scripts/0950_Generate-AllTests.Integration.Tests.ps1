#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0950_Generate-AllTests
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-10-30 03:24:50
#>

Describe '0950_Generate-AllTests Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0950_Generate-AllTests.ps1'
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
}
