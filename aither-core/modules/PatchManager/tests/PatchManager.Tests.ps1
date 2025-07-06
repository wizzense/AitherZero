#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Comprehensive test suite for PatchManager v3.0 module

.DESCRIPTION
    Tests atomic operations, smart mode detection, workflow automation,
    and integration with GitHub Actions and CI/CD systems.
#>

Describe "PatchManager v3.0 Module Tests" {
    BeforeAll {
        # Import the module
        $ModulePath = Join-Path $PSScriptRoot "../PatchManager.psm1"
        Import-Module $ModulePath -Force
        
        # Set up test environment
        $TestRepo = Join-Path $TestDrive "test-repo"
        New-Item -ItemType Directory -Path $TestRepo -Force
        
        Push-Location $TestRepo
        
        # Initialize git repo
        git init
        git config user.email "test@example.com"
        git config user.name "Test User"
        
        # Create initial commit
        "Initial content" | Out-File -FilePath "README.md"
        git add README.md
        git commit -m "Initial commit"
    }
    
    AfterAll {
        Pop-Location
    }

    Context "Module Loading and Initialization" {
        It "Should load the module successfully" {
            Get-Module PatchManager | Should -Not -BeNullOrEmpty
        }

        It "Should export all expected v3.0 functions" {
            $ExpectedFunctions = @(
                'New-Patch', 'New-QuickFix', 'New-Feature', 'New-Hotfix',
                'Invoke-AtomicOperation', 'Get-SmartOperationMode', 'Invoke-MultiModeOperation'
            )
            
            foreach ($Function in $ExpectedFunctions) {
                Get-Command $Function -Module PatchManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }

        It "Should maintain backward compatibility with legacy functions" {
            $LegacyFunctions = @(
                'Invoke-PatchWorkflow', 'New-PatchIssue', 'New-PatchPR',
                'Invoke-PatchRollback', 'Sync-GitBranch'
            )
            
            foreach ($Function in $LegacyFunctions) {
                Get-Command $Function -Module PatchManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Smart Operation Mode Detection" {
        It "Should detect Simple mode for low-risk operations" {
            $Analysis = Get-SmartOperationMode -PatchDescription "Fix typo in documentation"
            
            $Analysis.RecommendedMode | Should -Be "Simple"
            $Analysis.RiskLevel | Should -Be "Low"
            $Analysis.ShouldCreatePR | Should -Be $false
        }

        It "Should detect Standard mode for normal operations" {
            $Analysis = Get-SmartOperationMode -PatchDescription "Add new feature for user management"
            
            $Analysis.RecommendedMode | Should -Be "Standard"
            $Analysis.ShouldCreatePR | Should -Be $true
        }

        It "Should detect high-risk operations requiring PR review" {
            $Analysis = Get-SmartOperationMode -PatchDescription "Critical security fix for authentication"
            
            $Analysis.RiskLevel | Should -Be "High"
            $Analysis.ShouldCreatePR | Should -Be $true
            $Analysis.ShouldCreateIssue | Should -Be $true
        }

        It "Should provide confidence scores and reasoning" {
            $Analysis = Get-SmartOperationMode -PatchDescription "Update API documentation"
            
            $Analysis.Confidence | Should -BeGreaterThan 0.5
            $Analysis.Reasoning | Should -Not -BeNullOrEmpty
        }
    }

    Context "Atomic Operations Framework" {
        It "Should execute simple operations atomically" {
            $TestOperation = {
                "Test content" | Out-File -FilePath "test-file.txt"
                return "Operation completed"
            }
            
            $Result = Invoke-AtomicOperation -Operation $TestOperation -OperationName "Test Operation"
            
            $Result.Success | Should -Be $true
            $Result.OperationName | Should -Be "Test Operation"
            Test-Path "test-file.txt" | Should -Be $true
        }

        It "Should validate pre-conditions before execution" {
            $PreCondition = { $false }  # Always fail
            $TestOperation = { "Should not execute" }
            
            $Result = Invoke-AtomicOperation -Operation $TestOperation -OperationName "Test" -PreConditions $PreCondition
            
            $Result.Success | Should -Be $false
            $Result.Error | Should -Match "Pre-conditions failed"
        }

        It "Should detect merge conflicts and prevent execution" {
            # Create a file with conflict markers
            @"
Some content
<<<<<<< HEAD
Conflicted content
=======
Other content
>>>>>>> branch
More content
"@ | Out-File -FilePath "conflict-file.txt"

            $TestOperation = { "Operation" }
            
            $Result = Invoke-AtomicOperation -Operation $TestOperation -OperationName "Test"
            
            $Result.Success | Should -Be $false
            $Result.Error | Should -Match "MERGE CONFLICTS DETECTED"
        }

        It "Should capture initial state and provide rollback context" {
            $TestOperation = {
                "Modified content" | Out-File -FilePath "README.md"
            }
            
            $InitialContent = Get-Content "README.md" -Raw
            $Result = Invoke-AtomicOperation -Operation $TestOperation -OperationName "Test"
            
            $Result.Context.InitialBranch | Should -Not -BeNullOrEmpty
            $Result.Context.InitialCommit | Should -Not -BeNullOrEmpty
            $Result.Context.StartTime | Should -Not -BeNullOrEmpty
        }
    }

    Context "Patch Creation Workflows" {
        It "Should create patches in dry-run mode without making changes" {
            $InitialCommit = git rev-parse HEAD
            
            $Result = New-Patch -Description "Test dry run patch" -DryRun
            
            $Result.Success | Should -Be $true
            $Result.DryRun | Should -Be $true
            git rev-parse HEAD | Should -Be $InitialCommit  # No new commits
        }

        It "Should respect user mode preferences" {
            $Result = New-Patch -Description "Test patch" -Mode "Standard" -DryRun
            
            $Result.Mode | Should -Be "Standard"
        }

        It "Should apply smart recommendations when mode is Auto" {
            $Result = New-Patch -Description "Fix critical security issue" -Mode "Auto" -DryRun
            
            $Result.Mode | Should -Be "Standard"  # Should upgrade due to security keywords
        }
    }

    Context "Feature Development Workflow" {
        It "Should create feature branches with proper naming" {
            $Changes = {
                "Feature implementation" | Out-File -FilePath "feature.txt"
            }
            
            $Result = New-Feature -Description "Add authentication module" -Changes $Changes -DryRun
            
            $Result.Success | Should -Be $true
            $Result.Mode | Should -Be "Standard"
        }

        It "Should automatically enable PR creation for features" {
            $Changes = { "Feature code" }
            
            $Result = New-Feature -Description "New feature" -Changes $Changes -DryRun
            
            # Features should automatically create PRs for review
            $Result.Result.ShouldCreatePR | Should -Be $true
        }
    }

    Context "Quick Fix Workflow" {
        It "Should handle simple fixes efficiently" {
            $Changes = {
                $Content = Get-Content "README.md"
                $Content = $Content -replace "Initial", "Updated"
                Set-Content "README.md" -Value $Content
            }
            
            $Result = New-QuickFix -Description "Fix typo in README" -Changes $Changes -DryRun
            
            $Result.Success | Should -Be $true
        }

        It "Should use appropriate mode for quick fixes" {
            $Changes = { "Quick fix" }
            
            $Result = New-QuickFix -Description "Minor documentation fix" -Changes $Changes -DryRun
            
            # Quick fixes might use Simple mode for efficiency
            $Result.Mode | Should -BeIn @("Simple", "Standard")
        }
    }

    Context "Hotfix Workflow" {
        It "Should handle emergency fixes with high priority" {
            $Changes = {
                "Critical fix implementation" | Out-File -FilePath "hotfix.txt"
            }
            
            $Result = New-Hotfix -Description "Emergency security patch" -Changes $Changes -DryRun
            
            $Result.Success | Should -Be $true
            # Hotfixes should always create PRs for critical review
            $Result.Result.ShouldCreatePR | Should -Be $true
        }

        It "Should prioritize hotfixes appropriately" {
            $Changes = { "Hotfix code" }
            
            $Result = New-Hotfix -Description "Critical production fix" -Changes $Changes -DryRun
            
            $Result.Mode | Should -Be "Standard"  # High priority operations use Standard mode
        }
    }

    Context "Git Repository Integration" {
        It "Should detect git repository information correctly" {
            # This assumes Get-GitRepositoryInfo function exists
            if (Get-Command Get-GitRepositoryInfo -ErrorAction SilentlyContinue) {
                $RepoInfo = Get-GitRepositoryInfo
                
                $RepoInfo | Should -Not -BeNullOrEmpty
                $RepoInfo.IsGitRepository | Should -Be $true
            }
        }

        It "Should handle branch operations safely" {
            $InitialBranch = git branch --show-current
            
            # Test that operations don't leave us on wrong branch
            $Result = New-Patch -Description "Test branch safety" -DryRun
            
            $CurrentBranch = git branch --show-current
            $CurrentBranch | Should -Be $InitialBranch
        }

        It "Should detect uncommitted changes appropriately" {
            # Create uncommitted change
            "Uncommitted content" | Out-File -FilePath "uncommitted.txt"
            
            $Analysis = Get-SmartOperationMode -PatchDescription "Test with uncommitted changes"
            
            $Analysis.Warnings | Should -Contain "Uncommitted changes detected - will be included in patch"
            
            # Clean up
            Remove-Item "uncommitted.txt" -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Error Handling and Recovery" {
        It "Should handle invalid operations gracefully" {
            $InvalidOperation = {
                throw "Simulated error"
            }
            
            $Result = Invoke-AtomicOperation -Operation $InvalidOperation -OperationName "Invalid Test"
            
            $Result.Success | Should -Be $false
            $Result.Error | Should -Match "Simulated error"
        }

        It "Should provide meaningful error messages" {
            $Result = New-Patch -Description "" -DryRun  # Invalid empty description
            
            $Result.Success | Should -Be $false
            $Result.Error | Should -Not -BeNullOrEmpty
        }

        It "Should maintain repository state on failure" {
            $InitialCommit = git rev-parse HEAD
            $FailingOperation = { throw "Operation failed" }
            
            $Result = Invoke-AtomicOperation -Operation $FailingOperation -OperationName "Failing Test"
            
            # Repository should be in same state
            git rev-parse HEAD | Should -Be $InitialCommit
        }
    }

    Context "Performance and Efficiency" {
        It "Should complete operations within reasonable time" {
            $StartTime = Get-Date
            
            $Result = New-Patch -Description "Performance test" -DryRun
            
            $Duration = (Get-Date) - $StartTime
            $Duration.TotalSeconds | Should -BeLessThan 5  # Operations should be fast
        }

        It "Should provide timing information" {
            $Result = New-Patch -Description "Timing test" -DryRun
            
            $Result.Duration | Should -Not -BeNullOrEmpty
            $Result.Duration | Should -BeOfType [TimeSpan]
        }
    }

    Context "Legacy Compatibility" {
        It "Should support legacy Invoke-PatchWorkflow syntax" {
            $LegacyOperation = {
                "Legacy operation" | Out-File -FilePath "legacy.txt"
            }
            
            # This should work with legacy alias
            $Result = Invoke-PatchWorkflow -PatchDescription "Legacy test" -PatchOperation $LegacyOperation -DryRun
            
            $Result.Success | Should -Be $true
        }

        It "Should translate legacy parameters correctly" {
            $Result = Invoke-PatchWorkflow -PatchDescription "Legacy patch" -DryRun
            
            $Result | Should -Not -BeNullOrEmpty
            $Result.Description | Should -Be "Legacy patch"
        }
    }

    Context "Integration with CI/CD" {
        It "Should provide CI-friendly output format" {
            $Result = New-Patch -Description "CI test" -DryRun
            
            # Result should be serializable and contain key information
            $Result.Success | Should -BeOfType [Boolean]
            $Result.Mode | Should -BeOfType [String]
            $Result.Description | Should -BeOfType [String]
        }

        It "Should handle CI environment detection" {
            # Simulate CI environment
            $env:CI = "true"
            
            try {
                $Result = New-Patch -Description "CI environment test" -DryRun
                
                # Should work in CI environment
                $Result.Success | Should -Be $true
            } finally {
                Remove-Item Env:CI -ErrorAction SilentlyContinue
            }
        }
    }
}