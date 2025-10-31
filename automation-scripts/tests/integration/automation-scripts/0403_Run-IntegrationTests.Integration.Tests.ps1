#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0403_Run-IntegrationTests
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-10-30 02:34:25
#>

Describe '0403_Run-IntegrationTests Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = './automation-scripts/0403_Run-IntegrationTests.ps1'
        $script:TestConfig = @{ Automation = @{ DryRun = $true } }
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -Configuration $script:TestConfig -WhatIf } | Should -Not -Throw
        }
    }
}
