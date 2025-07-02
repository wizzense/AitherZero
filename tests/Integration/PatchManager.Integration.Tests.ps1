#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
}

Describe 'PatchManager Module Integration Tests' -Tag 'Integration' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Create test repository structure
        $script:TestRoot = Join-Path $TestDrive 'PatchManagerIntegration'
        $script:TestRepo = Join-Path $script:TestRoot 'test-repo'
        New-Item -Path $script:TestRepo -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRepo
        
        # Initialize git repository
        git init --initial-branch=main 2>&1 | Out-Null
        git config user.email "test@example.com" 2>&1 | Out-Null
        git config user.name "Test User" 2>&1 | Out-Null
        
        # Create initial files
        'Initial content' | Set-Content 'test-file.ps1'
        'Initial readme' | Set-Content 'README.md'
        git add . 2>&1 | Out-Null
        git commit -m "Initial commit" 2>&1 | Out-Null
        
        # Mock GitHub CLI for integration tests
        Mock gh {
            if ($args -contains 'issue' -and $args -contains 'create') {
                return 'https://github.com/test/repo/issues/123'
            }
            if ($args -contains 'pr' -and $args -contains 'create') {
                return 'https://github.com/test/repo/pull/456'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock Get-GitRepositoryInfo for integration
        Mock Get-GitRepositoryInfo {
            @{
                Owner = 'testuser'
                Name = 'testrepo'
                FullName = 'testuser/testrepo'
                Type = 'origin'
                Branch = (git branch --show-current)
                Remote = 'origin'
            }
        } -ModuleName $script:ModuleName
    }
    
    AfterAll {
        Set-Location $TestDrive
        Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Full Patch Workflow Integration' {
        It 'Should complete full patch workflow without issues' {
            $patchOperation = {
                'Updated content' | Set-Content 'test-file.ps1'
                'Updated line' | Add-Content 'README.md'
            }
            
            $result = Invoke-PatchWorkflow -PatchDescription "Integration test patch" -PatchOperation $patchOperation -CreateIssue:$false -Force
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.BranchCreated | Should -Be $true
            $result.CommitCreated | Should -Be $true
        }
        
        It 'Should create issue and PR in combined workflow' {
            $patchOperation = {
                'Another update' | Set-Content 'new-file.ps1'
            }
            
            $result = Invoke-PatchWorkflow -PatchDescription "Issue and PR test" -PatchOperation $patchOperation -CreatePR -Force
            
            $result.IssueCreated | Should -Be $true
            $result.PRCreated | Should -Be $true
            $result.IssueNumber | Should -Be 123
            $result.PRNumber | Should -Be 456
        }
        
        It 'Should handle test command execution' {
            $testExecuted = $false
            $patchOperation = {
                'Test content' | Set-Content 'test-output.txt'
            }
            
            # Mock Test-Path to simulate test command
            Mock Test-Path { $true } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "Test execution patch" -PatchOperation $patchOperation -TestCommands @('Test-Path test-output.txt') -CreateIssue:$false -Force
            
            $result.TestsExecuted | Should -Be $true
            Test-Path 'test-output.txt' | Should -Be $true
        }
    }
    
    Context 'Branch Management Integration' {
        It 'Should create unique branch names for different patches' {
            $branches = @()
            
            1..3 | ForEach-Object {
                $patchOp = { "Content $_" | Set-Content "file$_.txt" }
                $result = Invoke-PatchWorkflow -PatchDescription "Test patch $_" -PatchOperation $patchOp -CreateIssue:$false -Force
                $branches += $result.BranchName
            }
            
            # All branch names should be unique
            $branches | Select-Object -Unique | Should -HaveCount 3
            
            # All branches should follow patch/ pattern
            $branches | ForEach-Object { $_ | Should -Match '^patch/' }
        }
        
        It 'Should switch back to main after patch creation' {
            $patchOp = { 'Branch test' | Set-Content 'branch-test.txt' }
            
            Invoke-PatchWorkflow -PatchDescription "Branch switch test" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            $currentBranch = git branch --show-current
            $currentBranch | Should -Be 'main'
        }
    }
    
    Context 'Sync-GitBranch Integration' {
        It 'Should sync with fake remote setup' {
            # Create a bare repository to simulate remote
            $bareRepo = Join-Path $script:TestRoot 'bare-repo.git'
            git init --bare $bareRepo 2>&1 | Out-Null
            
            # Add it as remote
            git remote add origin $bareRepo 2>&1 | Out-Null
            git push -u origin main 2>&1 | Out-Null
            
            $result = Sync-GitBranch -BranchName 'main'
            
            $result.Success | Should -Be $true
            $result.BranchName | Should -Be 'main'
        }
        
        It 'Should handle sync when no remote exists' {
            # Remove remote for this test
            git remote remove origin 2>&1 | Out-Null
            
            # Sync should handle missing remote gracefully
            { Sync-GitBranch -BranchName 'main' } | Should -Throw
        }
    }
    
    Context 'Issue and PR Creation Integration' {
        It 'Should create issue with proper formatting' {
            $result = New-PatchIssue -Description "Integration test issue" -Priority "High" -AffectedFiles @('test-file.ps1', 'README.md')
            
            $result.Success | Should -Be $true
            $result.IssueUrl | Should -Match 'github.com/.*/issues/\d+'
            $result.IssueNumber | Should -Be 123
        }
        
        It 'Should create PR with branch and issue linking' {
            # Create a test branch
            git checkout -b 'patch/pr-test' 2>&1 | Out-Null
            'PR test content' | Set-Content 'pr-test.txt'
            git add . 2>&1 | Out-Null
            git commit -m "PR test commit" 2>&1 | Out-Null
            
            $result = New-PatchPR -Description "Integration PR test" -BranchName 'patch/pr-test' -IssueNumber 123
            
            $result.Success | Should -Be $true
            $result.PRUrl | Should -Match 'github.com/.*/pull/\d+'
            $result.PRNumber | Should -Be 456
            
            # Switch back to main
            git checkout main 2>&1 | Out-Null
        }
    }
    
    Context 'Rollback Integration' {
        It 'Should rollback last commit successfully' {
            # Make a commit to rollback
            'Temporary content' | Set-Content 'temp-file.txt'
            git add . 2>&1 | Out-Null
            git commit -m "Temporary commit for rollback test" 2>&1 | Out-Null
            
            $beforeRollback = git rev-parse HEAD
            
            $result = Invoke-PatchRollback -RollbackType "LastCommit" -Force
            
            $afterRollback = git rev-parse HEAD
            
            $result.Success | Should -Be $true
            $afterRollback | Should -Not -Be $beforeRollback
            Test-Path 'temp-file.txt' | Should -Be $false
        }
        
        It 'Should rollback to specific commit' {
            # Get initial commit hash
            $initialCommit = git log --oneline | Select-Object -Last 1 | ForEach-Object { $_.Split(' ')[0] }
            
            # Make some commits
            'File 1' | Set-Content 'file1.txt'
            git add . 2>&1 | Out-Null
            git commit -m "Commit 1" 2>&1 | Out-Null
            
            'File 2' | Set-Content 'file2.txt'
            git add . 2>&1 | Out-Null
            git commit -m "Commit 2" 2>&1 | Out-Null
            
            $result = Invoke-PatchRollback -RollbackType "SpecificCommit" -CommitHash $initialCommit -Force
            
            $result.Success | Should -Be $true
            Test-Path 'file1.txt' | Should -Be $false
            Test-Path 'file2.txt' | Should -Be $false
        }
    }
    
    Context 'Error Recovery Integration' {
        It 'Should handle dirty working tree during patch workflow' {
            # Create uncommitted changes
            'Uncommitted content' | Set-Content 'uncommitted.txt'
            
            $patchOp = { 'Patch content' | Set-Content 'patch-file.txt' }
            
            # Should handle uncommitted changes by stashing
            $result = Invoke-PatchWorkflow -PatchDescription "Dirty tree test" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            $result.Success | Should -Be $true
            $result.StashCreated | Should -Be $true
        }
        
        It 'Should restore stash on patch operation failure' {
            # Create uncommitted changes
            'Important uncommitted work' | Set-Content 'important.txt'
            
            $failingPatchOp = { throw "Patch operation failed" }
            
            try {
                Invoke-PatchWorkflow -PatchDescription "Failing patch" -PatchOperation $failingPatchOp -CreateIssue:$false -Force
            } catch {
                # Expected to fail
            }
            
            # Stash should have been restored
            Test-Path 'important.txt' | Should -Be $true
            Get-Content 'important.txt' | Should -Be 'Important uncommitted work'
        }
    }
    
    Context 'Cross-Function Integration' {
        It 'Should maintain consistency across patch workflow and rollback' {
            $initialState = git rev-parse HEAD
            
            # Create patch
            $patchOp = { 'Integration test' | Set-Content 'integration.txt' }
            $patchResult = Invoke-PatchWorkflow -PatchDescription "Integration consistency test" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            $afterPatch = git rev-parse HEAD
            
            # Rollback the patch
            $rollbackResult = Invoke-PatchRollback -RollbackType "LastCommit" -Force
            
            $afterRollback = git rev-parse HEAD
            
            # Should be back to initial state
            $afterRollback | Should -Be $initialState
            $patchResult.Success | Should -Be $true
            $rollbackResult.Success | Should -Be $true
        }
        
        It 'Should work with sync after patch creation' {
            # Create patch with branch
            $patchOp = { 'Sync test' | Set-Content 'sync-test.txt' }
            $patchResult = Invoke-PatchWorkflow -PatchDescription "Sync integration test" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            # Should be back on main
            $currentBranch = git branch --show-current
            $currentBranch | Should -Be 'main'
            
            # Sync should work without issues
            $syncResult = Sync-GitBranch -BranchName 'main'
            
            $patchResult.Success | Should -Be $true
            $syncResult.Success | Should -Be $true
        }
    }
    
    Context 'Performance Integration' {
        It 'Should complete full workflow within reasonable time' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            $patchOp = { 'Performance test' | Set-Content 'perf-test.txt' }
            $result = Invoke-PatchWorkflow -PatchDescription "Performance test patch" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            $stopwatch.Stop()
            
            $result.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # 5 seconds max
        }
        
        It 'Should handle multiple rapid patch operations' {
            $results = @()
            
            1..5 | ForEach-Object {
                $patchOp = { "Rapid patch $_" | Set-Content "rapid-$_.txt" }
                $result = Invoke-PatchWorkflow -PatchDescription "Rapid patch $_" -PatchOperation $patchOp -CreateIssue:$false -Force
                $results += $result
            }
            
            $results | ForEach-Object { $_.Success | Should -Be $true }
            $results | Should -HaveCount 5
        }
    }
    
    Context 'Module State Integrity' {
        It 'Should maintain clean module state across operations' {
            # Perform various operations
            $patchOp = { 'State test' | Set-Content 'state-test.txt' }
            Invoke-PatchWorkflow -PatchDescription "State test" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            New-PatchIssue -Description "State test issue" -DryRun
            
            $prBranch = git branch --show-current
            if ($prBranch -ne 'main') {
                git checkout main 2>&1 | Out-Null
            }
            
            Sync-GitBranch -BranchName 'main'
            
            # Module should still be functional
            $finalResult = Invoke-PatchWorkflow -PatchDescription "Final state test" -PatchOperation { 'Final' | Set-Content 'final.txt' } -CreateIssue:$false -Force
            
            $finalResult.Success | Should -Be $true
        }
    }
}