#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0530_Get-WorkflowRunReport
.DESCRIPTION
    Auto-generated integration tests
    Generated: 2025-11-03 15:15:17
#>

Describe '0530_Get-WorkflowRunReport Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        $script:ScriptPath = '/home/runner/work/AitherZero/AitherZero/automation-scripts/0530_Get-WorkflowRunReport.ps1'
    }

    Context 'Integration' {
        It 'Should execute in test mode' {
            { & $script:ScriptPath -WhatIf } | Should -Not -Throw
        }
    }
}
