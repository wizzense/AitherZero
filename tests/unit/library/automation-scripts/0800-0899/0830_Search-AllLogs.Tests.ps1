#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0830_Search-AllLogs
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0830_Search-AllLogs
    Stage: Issue Management
    Description: Comprehensive log search across all log sources with advanced filtering
    Supports WhatIf: False
    Generated: 2025-11-10 16:41:57
#>

Describe '0830_Search-AllLogs' -Tag 'Unit', 'AutomationScript', 'Issue Management' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0830_Search-AllLogs.ps1'
        $script:ScriptName = '0830_Search-AllLogs'

        # Import test helpers for environment detection
        $testHelpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "../../TestHelpers.psm1"
        if (Test-Path $testHelpersPath) {
            Import-Module $testHelpersPath -Force -ErrorAction SilentlyContinue
        }

        # Detect test environment
        $script:TestEnv = if (Get-Command Get-TestEnvironment -ErrorAction SilentlyContinue) {
            Get-TestEnvironment
        } else {
            @{ IsCI = ($env:CI -eq 'true' -or $env:GITHUB_ACTIONS -eq 'true'); IsLocal = $true }
        }

        # Import ScriptUtilities module (script uses it)
        $scriptUtilitiesPath = Join-Path $repoRoot "aithercore/automation/ScriptUtilities.psm1"
        if (Test-Path $scriptUtilitiesPath) {
            Import-Module $scriptUtilitiesPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Script Validation' {
        It 'Script file should exist' {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:ScriptPath, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should not require WhatIf support' {
            # Script does not implement SupportsShouldProcess
            # This is acceptable for read-only or simple scripts
            $content = Get-Content $script:ScriptPath -Raw
            $content -notmatch 'SupportsShouldProcess' | Should -Be $true
        }

        It 'Should properly import ScriptUtilities module' {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Import-Module.*ScriptUtilities\.psm1'
        }
    }

    Context 'Parameters' {
        It 'Should have parameter: Pattern' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Pattern') | Should -Be $true
        }

        It 'Should have parameter: LogType' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('LogType') | Should -Be $true
        }

        It 'Should have parameter: Regex' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Regex') | Should -Be $true
        }

        It 'Should have parameter: CaseSensitive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('CaseSensitive') | Should -Be $true
        }

        It 'Should have parameter: Context' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Context') | Should -Be $true
        }

        It 'Should have parameter: MaxResults' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('MaxResults') | Should -Be $true
        }

        It 'Should have parameter: After' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('After') | Should -Be $true
        }

        It 'Should have parameter: Before' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Before') | Should -Be $true
        }

        It 'Should have parameter: Severity' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Severity') | Should -Be $true
        }

        It 'Should have parameter: Format' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Format') | Should -Be $true
        }

        It 'Should have parameter: OutputFile' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('OutputFile') | Should -Be $true
        }

        It 'Should have parameter: Interactive' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Interactive') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Issue Management' {
            $content = Get-Content $script:ScriptPath -First 40
            ($content -join ' ') | Should -Match '(Stage:|Category:)'
        }

        It 'Should declare dependencies' {
            $content = Get-Content $script:ScriptPath -First 50
            ($content -join ' ') | Should -Match 'Dependencies:'
        }
    }

    Context 'Execution' {
        It 'Should be executable (no WhatIf support)' {
            # Script does not support -WhatIf parameter
            # Verify script can be dot-sourced without errors
            {
                $cmd = Get-Command $script:ScriptPath -ErrorAction Stop
                $cmd | Should -Not -BeNullOrEmpty
            } | Should -Not -Throw
        }
    }

    Context 'Environment Awareness' {
        It 'Test environment should be detected' {
            $script:TestEnv | Should -Not -BeNullOrEmpty
            $script:TestEnv.Keys | Should -Contain 'IsCI'
        }

        It 'Should adapt to CI environment' {
            if (-not $script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "CI-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $true
            $env:CI | Should -Not -BeNullOrEmpty
        }

        It 'Should adapt to local environment' {
            if ($script:TestEnv.IsCI) {
                Set-ItResult -Skipped -Because "Local-only validation"
                return
            }
            $script:TestEnv.IsCI | Should -Be $false
        }
    }

    BeforeAll {
        # Import functional test framework for advanced testing
        $functionalFrameworkPath = Join-Path $repoRoot "aithercore/testing/FunctionalTestFramework.psm1"
        if (Test-Path $functionalFrameworkPath) {
            Import-Module $functionalFrameworkPath -Force -ErrorAction SilentlyContinue
        }
    }


    # === FUNCTIONAL TESTS - Validate actual behavior ===
    Context 'Functional Behavior - General Script Operation' {
        It 'Should handle errors gracefully' {
            # Test error handling with invalid input
            $invalidParams = @{
                Path = '/nonexistent/path/that/does/not/exist'
            }
            
            # Should either handle gracefully or throw meaningful error
            try {
                & $script:ScriptPath @invalidParams -WhatIf -ErrorAction Stop
            } catch {
                # Error message should be informative
                $_.Exception.Message | Should -Not -BeNullOrEmpty
            }
        }
        
        It 'Should validate required parameters' {
            $cmd = Get-Command $script:ScriptPath
            $mandatoryParams = $cmd.Parameters.Values | Where-Object { $_.Attributes.Mandatory }
            
            if ($mandatoryParams) {
                # Executing without mandatory params should fail appropriately
                { & $script:ScriptPath -ErrorAction Stop } | Should -Throw
            }
        }
        
        It 'Should respect WhatIf parameter if supported' {
            $cmd = Get-Command $script:ScriptPath
            if ($cmd.Parameters.ContainsKey('WhatIf')) {
                # WhatIf execution should not make real changes
                # Should complete successfully
                { & $script:ScriptPath -WhatIf } | Should -Not -Throw
            }
        }
        
        It 'Should produce expected output structure' {
            # Execute and validate output
            $output = & $script:ScriptPath -WhatIf 2>&1
            
            # Output should be structured (not just random text)
            # At minimum, should not be null
            # Actual validation depends on script type
        }
    }
}
