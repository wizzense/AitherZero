#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0802_Load-ObfuscatedModule
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Generated: 2025-11-07 19:47:25
#>

Describe '0802_Load-ObfuscatedModule Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'automation-scripts/0802_Load-ObfuscatedModule.ps1'
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
