#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0416_Validate-ModuleManifest
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: False
    Generated: 2025-11-08 00:28:33
#>

Describe '0416_Validate-ModuleManifest Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0416_Validate-ModuleManifest.ps1'
    }

    Context 'Integration' {
        It 'Should have required structure (has mandatory parameters)' {
            # Script has mandatory parameters - cannot execute without them
            # Verify script structure instead
            Test-Path $script:ScriptPath | Should -Be $true
            
            # Verify Get-Command can read parameters
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd.Parameters.Count | Should -BeGreaterThan 0
            } | Should -Not -Throw
        }
    }
}
