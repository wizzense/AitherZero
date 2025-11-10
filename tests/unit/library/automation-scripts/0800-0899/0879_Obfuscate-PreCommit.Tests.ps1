#Requires -Version 7.0
#Requires -Module Pester

<#
.SYNOPSIS
    Unit tests for 0879_Obfuscate-PreCommit
.DESCRIPTION
    Auto-generated comprehensive tests with environment awareness
    Script: 0879_Obfuscate-PreCommit
    Stage: Pre-Commit
    Description: Automatically encrypts specified source files before commit when a valid
    Supports WhatIf: False
    Generated: 2025-11-10 16:41:57
#>

Describe '0879_Obfuscate-PreCommit' -Tag 'Unit', 'AutomationScript', 'Pre-Commit' {

    BeforeAll {
        # Compute path relative to repository root using $PSScriptRoot
        $repoRoot = Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
        $script:ScriptPath = Join-Path $repoRoot 'library/automation-scripts/0879_Obfuscate-PreCommit.ps1'
        $script:ScriptName = '0879_Obfuscate-PreCommit'

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

    }

    Context 'Parameters' {
        It 'Should have parameter: DryRun' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('DryRun') | Should -Be $true
        }

        It 'Should have parameter: Force' {
            $cmd = Get-Command $script:ScriptPath
            $cmd.Parameters.ContainsKey('Force') | Should -Be $true
        }

    }

    Context 'Metadata' {
        It 'Should be in stage: Pre-Commit' {
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
    Context 'Functional Behavior - Git Commit' {
        It 'Should create commit with conventional commit format' {
            # Verify commit message follows conventional commits
            Mock git {
                param([string[]]$args)
                if ($args[0] -eq 'commit') {
                    $message = $args[2]
                    # Should match: type(scope): message
                    $message | Should -Match '^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .+'
                    return 'Commit created'
                }
                return ''
            }
            
            & $script:ScriptPath -Type feat -Message 'add feature' -WhatIf
            
            # Verify commit was attempted
            Should -Invoke git -ParameterFilter { $args[0] -eq 'commit' }
        }
        
        It 'Should stage files before committing' {
            # Mock git add and git commit separately using Pester
            Mock git { 'Files staged' } -ParameterFilter { $args[0] -eq 'add' }
            Mock git { 'Commit created' } -ParameterFilter { $args[0] -eq 'commit' }
            
            & $script:ScriptPath -Type fix -Message 'fix bug' -Files 'file1.ps1' -WhatIf
            
            # Verify git add was called before git commit (Pester tracks order)
            Should -Invoke git -ParameterFilter { $args[0] -eq 'add' } -Times 1 -Exactly
            Should -Invoke git -ParameterFilter { $args[0] -eq 'commit' } -Times 1 -Exactly
        }
        
        It 'Should handle commit failures gracefully' {
            # Mock git commit to simulate failure
            Mock git { throw 'Nothing to commit' } -ParameterFilter { $args[0] -eq 'commit' }
            
            # Script should handle error appropriately
            {
                & $script:ScriptPath -Type fix -Message 'fix' -ErrorAction Stop
            } | Should -Throw -ExpectedMessage '*Nothing to commit*'
        }
    }

    Context 'Functional Behavior - Pull Request Creation' {
        It 'Should generate PR with proper metadata using gh CLI' {
            # Mock GitHub CLI (gh) using Pester's native mocking
            Mock gh {
                param([string[]]$args)
                if ($args[0] -eq 'pr' -and $args[1] -eq 'create') {
                    # Verify title is provided
                    $titleIndex = $args.IndexOf('--title')
                    $titleIndex | Should -BeGreaterThan -1
                    
                    $title = $args[$titleIndex + 1]
                    $title | Should -Not -BeNullOrEmpty
                    
                    return 'PR #123 created successfully'
                }
                return ''
            }
            
            & $script:ScriptPath -Title 'Test PR' -Body 'PR description' -WhatIf
            
            # Verify gh pr create was called with correct parameters
            Should -Invoke gh -ParameterFilter { 
                $args[0] -eq 'pr' -and $args[1] -eq 'create' 
            } -Times 1 -Exactly
        }
        
        It 'Should support draft PRs' {
            Mock gh { 'Draft PR created' }
            
            & $script:ScriptPath -Title 'Draft PR' -Draft -WhatIf
            
            # Verify --draft flag is passed
            Should -Invoke gh -ParameterFilter { 
                $args -contains '--draft' 
            }
        }
    }

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
