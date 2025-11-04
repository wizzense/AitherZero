#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0962_Run-Playbook
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-04 08:53:23
#>

Describe '0962_Run-Playbook Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0962_Run-Playbook.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
