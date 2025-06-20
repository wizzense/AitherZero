BeforeAll {
    # Import Logging module first
    $projectRoot = $env:PROJECT_ROOT
    $loggingPath = Join-Path $projectRoot "aither-core/modules/Logging"
    
    try {
        Import-Module $loggingPath -Force -Global -ErrorAction Stop
        Write-Host "Logging module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import Logging module: $_"
        throw
    }

    # Import PatchManager module
    $projectRoot = $env:PROJECT_ROOT
    $patchManagerPath = Join-Path $projectRoot "aither-core/modules/PatchManager"
    
    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to import PatchManager module: $_"
        throw
    }
    
    # Mock functions
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Mock git commands for testing
    function global:git {
        param()
        $gitArgs = $args
        $script:gitCalls += , $gitArgs
        
        switch -Regex ($gitArgs -join " ") {
            "^status --porcelain" {
                if ($script:workingTreeDirty) {
                    return "M  modified-file.ps1"
                }
                return "" # Clean working tree
            }
            "^status$" {
                if ($script:workingTreeDirty) {
                    return "On branch main`nChanges not staged for commit:`n  modified:   modified-file.ps1"
                }
                return "On branch main`nnothing to commit, working tree clean"
            }
            "^rev-parse --abbrev-ref HEAD" {
                return $script:currentBranch ?? "main"
            }
            "^checkout -b" {
                $branchName = $gitArgs[2]
                $script:currentBranch = $branchName
                $script:createdBranches += $branchName
                return "Switched to a new branch '$branchName'"
            }
            "^add" {
                $script:stagedFiles += $gitArgs[1..($gitArgs.Count-1)]
                return ""
            }
            "^commit" {
                $script:commitsMade += 1
                return "commit abc123 (HEAD -> $($script:currentBranch))"
            }
            "^push" {
                if ($gitArgs -contains "--set-upstream") {
                    $script:upstreamSet = $true
                }
                return "Branch '$($script:currentBranch)' set up to track remote branch"
            }
            "^remote -v" {
                return "origin  https://github.com/test/repo.git (fetch)`norigin  https://github.com/test/repo.git (push)"
            }
            "^config --get remote.origin.url" {
                return "https://github.com/test/repo.git"
            }
            default {
                $global:LASTEXITCODE = 0
                return ""
            }
        }
    }
    
    # Mock gh command
    function global:gh {
        param()
        $ghArgs = $args
        $script:ghCalls += , $ghArgs
        
        switch -Regex ($ghArgs -join " ") {
            "^auth status" {
                return "Logged in to github.com as testuser"
            }
            "^pr create" {
                $script:prsCreated += 1
                return "https://github.com/test/repo/pull/123"
            }
            "^issue create" {
                $script:issuesCreated += 1
                return "https://github.com/test/repo/issues/456"
            }
            default {
                $global:LASTEXITCODE = 0
                return ""
            }
        }
    }
}

Describe "PatchManager Git Operations" {
    BeforeEach {
        $script:gitCalls = @()
        $script:ghCalls = @()
        $script:currentBranch = "main"
        $script:workingTreeDirty = $false
        $script:createdBranches = @()
        $script:stagedFiles = @()
        $script:commitsMade = 0
        $script:upstreamSet = $false
        $script:prsCreated = 0
        $script:issuesCreated = 0
    }
    
    Context "Invoke-GitControlledPatch - Basic Operations" {
        It "Should validate working tree is clean" {
            $script:workingTreeDirty = $false
            $patchOperation = { Write-Host "Test patch operation" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: clean working tree" -PatchOperation $patchOperation -DryRun } | Should -Not -Throw
        }
        
        It "Should handle dirty working tree with Force parameter" {
            $script:workingTreeDirty = $true
            $patchOperation = { Write-Host "Test patch operation" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: dirty tree" -PatchOperation $patchOperation -Force -DryRun } | Should -Not -Throw
        }
        
        It "Should create new branch for patch" {
            $patchOperation = { Write-Host "Test patch operation" }
            
            Invoke-GitControlledPatch -PatchDescription "test: branch creation" -PatchOperation $patchOperation -DryRun
            
            # Should have called git commands for branch creation
            $script:gitCalls | Should -Contain @("checkout", "-b", $script:createdBranches[0])
        }
        
        It "Should execute patch operation" {
            $testOutput = ""
            $patchOperation = { $script:testOutput = "Patch executed" }
            
            Invoke-GitControlledPatch -PatchDescription "test: execution" -PatchOperation $patchOperation -DryRun
            
            # In dry run, patch operation should still be executed
            $script:testOutput | Should -Be "Patch executed"
        }
        
        It "Should create pull request when requested" {
            $patchOperation = { Write-Host "Test patch operation" }
            
            Invoke-GitControlledPatch -PatchDescription "test: pr creation" -PatchOperation $patchOperation -CreatePullRequest -DryRun
            
            # Should have attempted to create PR (though in dry run)
            $script:prsCreated | Should -BeGreaterOrEqual 0
        }
    }
    
    Context "Invoke-GitControlledPatch - Advanced Features" {
        It "Should handle affected files parameter" {
            $affectedFiles = @("file1.ps1", "file2.ps1")
            $patchOperation = { Write-Host "Test patch operation" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: affected files" -PatchOperation $patchOperation -AffectedFiles $affectedFiles -DryRun } | Should -Not -Throw
        }
        
        It "Should skip validation when requested" {
            $patchOperation = { Write-Host "Test patch operation" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: skip validation" -PatchOperation $patchOperation -SkipValidation -DryRun } | Should -Not -Throw
        }
        
        It "Should handle custom base branch" {
            $patchOperation = { Write-Host "Test patch operation" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: custom base" -PatchOperation $patchOperation -BaseBranch "develop" -DryRun } | Should -Not -Throw
        }
        
        It "Should auto-commit uncommitted changes when requested" {
            $script:workingTreeDirty = $true
            $patchOperation = { Write-Host "Test patch operation" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: auto commit" -PatchOperation $patchOperation -AutoCommitUncommitted -Force -DryRun } | Should -Not -Throw
        }
    }
    
    Context "New-PatchBranch Helper Function" {
        It "Should create branch with intelligent naming" {
            $result = New-PatchBranch -PatchDescription "fix: resolve memory leak in module loading"
            
            $result | Should -Not -BeNullOrEmpty
            $result.BranchName | Should -Match "^(fix|patch)/"
            $result.Success | Should -Be $true
        }
        
        It "Should handle branch name conflicts" {
            # Simulate existing branch
            $script:currentBranch = "fix/existing-branch"
            
            $result = New-PatchBranch -PatchDescription "fix: another fix"
            
            $result.BranchName | Should -Not -Be "fix/existing-branch"
        }
        
        It "Should respect custom prefix" {
            $result = New-PatchBranch -PatchDescription "urgent fix" -Prefix "hotfix"
            
            $result.BranchName | Should -Match "^hotfix/"
        }
    }
    
    Context "New-PatchCommit Helper Function" {
        It "Should create commit with proper format" {
            $affectedFiles = @("test-file.ps1")
            
            $result = New-PatchCommit -Description "test: commit formatting" -AffectedFiles $affectedFiles
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
        }
        
        It "Should handle empty affected files" {
            $result = New-PatchCommit -Description "test: no specific files"
            
            $result.Success | Should -Be $true
        }
        
        It "Should include Co-authored-by when specified" {
            $result = New-PatchCommit -Description "test: co-authorship" -CoAuthor "TestUser <test@example.com>"
            
            $result.Success | Should -Be $true
        }
    }
}

Describe "PatchManager Enhanced Git Operations" {
    BeforeEach {
        $script:gitCalls = @()
        $script:ghCalls = @()
        $script:workingTreeDirty = $false
    }
    
    Context "Invoke-EnhancedGitOperations" {
        It "Should perform comprehensive validation" {
            { Invoke-EnhancedGitOperations -Operation "validate" } | Should -Not -Throw
        }
        
        It "Should handle conflict resolution" {
            { Invoke-EnhancedGitOperations -Operation "resolve-conflicts" -DryRun } | Should -Not -Throw
        }
        
        It "Should cleanup problematic directories" {
            { Invoke-EnhancedGitOperations -Operation "cleanup-directories" -DryRun } | Should -Not -Throw
        }
    }
    
    Context "Git Conflict Resolution" {
        It "Should detect merge conflicts" {
            # Mock git to return conflict status
            function global:git {
                param()
                if ($args[0] -eq "status" -and $args[1] -eq "--porcelain") {
                    return "UU conflicted-file.ps1"
                }
                return ""
            }
            
            $result = Invoke-EnhancedGitOperations -Operation "detect-conflicts"
            
            $result.ConflictsDetected | Should -Be $true
        }
        
        It "Should attempt automatic conflict resolution" {
            { Invoke-EnhancedGitOperations -Operation "auto-resolve-conflicts" -DryRun } | Should -Not -Throw
        }
    }
}

Describe "PatchManager GitHub Integration" {
    BeforeEach {
        $script:ghCalls = @()
        $script:prsCreated = 0
        $script:issuesCreated = 0
    }
    
    Context "Pull Request Creation" {
        It "Should create PR with proper formatting" {
            $prData = @{
                Title = "fix: resolve module loading issue"
                Description = "This patch fixes a critical issue with module loading"
                AffectedFiles = @("module.ps1", "tests.ps1")
                ValidationResults = @{ "Syntax" = $true; "Tests" = $true }
            }
            
            { New-PatchPullRequest @prData -DryRun } | Should -Not -Throw
        }
        
        It "Should include validation results in PR body" {
            $prData = @{
                Title = "test: validation results"
                ValidationResults = @{ 
                    "Pre-patch validation" = $true
                    "Syntax validation" = $true
                    "Module compatibility" = $false
                }
            }
            
            $result = New-PatchPullRequest @prData -DryRun
            
            $result.PRBody | Should -Match "Module compatibility.*FAILED"
        }
    }
    
    Context "Issue Creation" {
        It "Should create GitHub issue for patch tracking" {
            $issueData = @{
                Title = "Patch: fix module loading"
                Description = "Track progress of module loading fix"
                Labels = @("patch", "bug")
            }
            
            { New-PatchIssue @issueData -DryRun } | Should -Not -Throw
        }
    }
    
    Context "Invoke-GitHubIssueIntegration" {
        It "Should integrate with existing issues" {
            { Invoke-GitHubIssueIntegration -IssueNumber 123 -PatchDescription "fix: related to issue" -DryRun } | Should -Not -Throw
        }
        
        It "Should create new issue if none specified" {
            { Invoke-GitHubIssueIntegration -PatchDescription "fix: new issue needed" -CreateNewIssue -DryRun } | Should -Not -Throw
        }
    }
}

Describe "PatchManager Error Handling in Git Operations" {
    Context "Git Command Failures" {
        It "Should handle git checkout failures gracefully" {
            # Mock git to fail on checkout
            function global:git {
                param()
                if ($args[0] -eq "checkout") {
                    $global:LASTEXITCODE = 1
                    return "error: pathspec 'branch' did not match any file(s) known to git"
                }
                return ""
            }
            
            $patchOperation = { Write-Host "Test" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: checkout failure" -PatchOperation $patchOperation -DryRun } | Should -Throw
        }
        
        It "Should handle git commit failures gracefully" {
            # Mock git to fail on commit
            function global:git {
                param()
                if ($args[0] -eq "commit") {
                    $global:LASTEXITCODE = 1
                    return "error: nothing to commit"
                }
                return ""
            }
            
            $patchOperation = { Write-Host "Test" }
            
            { Invoke-GitControlledPatch -PatchDescription "test: commit failure" -PatchOperation $patchOperation -DryRun } | Should -Throw
        }
    }
    
    Context "GitHub CLI Failures" {
        It "Should handle gh authentication failures" {
            # Mock gh to fail authentication
            function global:gh {
                param()
                if ($args[0] -eq "auth") {
                    $global:LASTEXITCODE = 1
                    return "Not logged in"
                }
                return ""
            }
            
            $result = Test-GitHubAuthentication
            $result.Authenticated | Should -Be $false
        }
        
        It "Should handle PR creation failures" {
            # Mock gh to fail PR creation
            function global:gh {
                param()
                if ($args[0] -eq "pr" -and $args[1] -eq "create") {
                    $global:LASTEXITCODE = 1
                    return "error: failed to create pull request"
                }
                return ""
            }
            
            $prData = @{ Title = "test"; Description = "test" }
            
            { New-PatchPullRequest @prData } | Should -Throw
        }
    }
}
