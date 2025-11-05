#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0901_Test-LocalDeployment
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Generated: 2025-11-04 20:50:01
#>

Describe '0901_Test-LocalDeployment Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0901_Test-LocalDeployment.ps1'
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
