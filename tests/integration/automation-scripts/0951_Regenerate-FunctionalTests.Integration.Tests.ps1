#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0951_Regenerate-FunctionalTests
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-04 07:53:36
#>

Describe '0951_Regenerate-FunctionalTests Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0951_Regenerate-FunctionalTests.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
