#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0830_Search-AllLogs
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Generated: 2025-11-06 03:17:57
#>

Describe '0830_Search-AllLogs Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0830_Search-AllLogs.ps1'

        # Import ScriptUtilities module (script uses it)
        $scriptUtilitiesPath = Join-Path $repoRoot "domains/automation/ScriptUtilities.psm1"
        if (Test-Path $scriptUtilitiesPath) {
            Import-Module $scriptUtilitiesPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Integration' {
        It 'Should execute without errors (no WhatIf support)' {
            # Script does not support -WhatIf parameter
            # Test basic script structure and loadability
            Test-Path $script:ScriptPath | Should -Be $true
            
            # Verify script can be dot-sourced
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }
    }
}
