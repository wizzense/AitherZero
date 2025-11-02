#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0721_Configure-RunnerEnvironment
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-02 21:41:15
#>

Describe '0721_Configure-RunnerEnvironment Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0721_Configure-RunnerEnvironment.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
