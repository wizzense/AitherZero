#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Integration tests for 0221_Install-VSBuildTools
.DESCRIPTION
    Auto-generated integration tests
    Supports WhatIf: True
    Generated: 2025-11-10 16:41:56
#>

Describe '0221_Install-VSBuildTools Integration' -Tag 'Integration', 'AutomationScript' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0221_Install-VSBuildTools.ps1'

        # Import ScriptUtilities module (script uses it)
        $scriptUtilitiesPath = Join-Path $repoRoot "aithercore/automation/ScriptUtilities.psm1"
        if (Test-Path $scriptUtilitiesPath) {
            Import-Module $scriptUtilitiesPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Integration' {
        BeforeAll {
            # Import functional test framework
            $functionalFrameworkPath = Join-Path $repoRoot "aithercore/testing/FunctionalTestFramework.psm1"
            if (Test-Path $functionalFrameworkPath) {
                Import-Module $functionalFrameworkPath -Force -ErrorAction SilentlyContinue
            }
        }

        It 'Should execute in test mode with WhatIf and produce expected output' {
            # FUNCTIONAL TEST: Validate actual WhatIf behavior
            $output = & $script:ScriptPath -WhatIf 2>&1 | Out-String
            
            # Should produce informative WhatIf output
            $output | Should -Not -BeNullOrEmpty
            
            # WhatIf output should indicate what would be done
            # Common patterns: "What if:", "Would", "Performing the operation"
            $output | Should -Match '(What if:|Would|Performing|DRY RUN)'
        }
    }
}
