#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
}

Describe 'PatchManager Performance Tests' -Tag 'Performance' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Helper function to measure execution time
        function Measure-ExecutionTime {
            param([scriptblock]$ScriptBlock)
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = & $ScriptBlock
            $stopwatch.Stop()
            return @{
                Result = $result
                ElapsedMilliseconds = $stopwatch.ElapsedMilliseconds
            }
        }
        
        # Create test repository
        $script:TestRoot = Join-Path $TestDrive 'PatchManagerPerformance'
        $script:TestRepo = Join-Path $script:TestRoot 'perf-repo'
        New-Item -Path $script:TestRepo -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRepo
        
        # Initialize git repository
        git init --initial-branch=main 2>&1 | Out-Null
        git config user.email "perf@example.com" 2>&1 | Out-Null
        git config user.name "Performance Test" 2>&1 | Out-Null
        
        # Create initial commit with multiple files
        1..50 | ForEach-Object {
            "Initial content for file $_" | Set-Content "file$_.ps1"
        }
        git add . 2>&1 | Out-Null
        git commit -m "Initial commit with 50 files" 2>&1 | Out-Null
        
        # Mock external dependencies for performance testing
        Mock gh { 'https://github.com/test/repo/issues/123' } -ModuleName $script:ModuleName
        Mock Get-GitRepositoryInfo {
            @{
                Owner = 'perftest'
                Name = 'perfrepo'
                FullName = 'perftest/perfrepo'
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
    
    Context 'Basic Operation Performance' {
        It 'Should complete patch workflow quickly (< 3 seconds)' {
            $patchOp = { 'Performance test' | Set-Content 'perf-test.txt' }
            
            $timing = Measure-ExecutionTime {
                Invoke-PatchWorkflow -PatchDescription "Performance test" -PatchOperation $patchOp -CreateIssue:$false -Force
            }
            
            $timing.ElapsedMilliseconds | Should -BeLessThan 3000
            $timing.Result.Success | Should -Be $true
        }
        
        It 'Should create issues efficiently (< 500ms)' {
            $timing = Measure-ExecutionTime {
                New-PatchIssue -Description "Performance issue test" -DryRun
            }
            
            $timing.ElapsedMilliseconds | Should -BeLessThan 500
            $timing.Result.DryRun | Should -Be $true
        }
        
        It 'Should create PRs efficiently (< 1 second)' {
            # Create a test branch first
            git checkout -b 'perf/pr-test' 2>&1 | Out-Null
            'PR performance test' | Set-Content 'pr-perf.txt'
            git add . 2>&1 | Out-Null
            git commit -m "PR performance test" 2>&1 | Out-Null
            
            $timing = Measure-ExecutionTime {
                New-PatchPR -Description "Performance PR test" -BranchName 'perf/pr-test' -DryRun
            }
            
            git checkout main 2>&1 | Out-Null
            git branch -D 'perf/pr-test' 2>&1 | Out-Null
            
            $timing.ElapsedMilliseconds | Should -BeLessThan 1000
            $timing.Result.DryRun | Should -Be $true
        }
        
        It 'Should sync branches efficiently (< 2 seconds)' {
            $timing = Measure-ExecutionTime {
                Sync-GitBranch -BranchName 'main'
            }
            
            $timing.ElapsedMilliseconds | Should -BeLessThan 2000
            $timing.Result.Success | Should -Be $true
        }
        
        It 'Should rollback efficiently (< 1 second)' {
            # Create a commit to rollback
            'Rollback test' | Set-Content 'rollback-perf.txt'
            git add . 2>&1 | Out-Null
            git commit -m "Rollback performance test" 2>&1 | Out-Null
            
            $timing = Measure-ExecutionTime {
                Invoke-PatchRollback -RollbackType "LastCommit" -Force
            }
            
            $timing.ElapsedMilliseconds | Should -BeLessThan 1000
            $timing.Result.Success | Should -Be $true
        }
    }
    
    Context 'Scaling Performance' {
        It 'Should handle large patch operations efficiently' {
            $largePatchOp = {
                # Modify many files
                1..20 | ForEach-Object {
                    "Updated content for file $_ at $(Get-Date)" | Set-Content "file$_.ps1"
                }
                
                # Create new files
                21..30 | ForEach-Object {
                    "New content for file $_" | Set-Content "newfile$_.ps1"
                }
            }
            
            $timing = Measure-ExecutionTime {
                Invoke-PatchWorkflow -PatchDescription "Large patch operation" -PatchOperation $largePatchOp -CreateIssue:$false -Force
            }
            
            # Should complete within 5 seconds even with 30 files
            $timing.ElapsedMilliseconds | Should -BeLessThan 5000
            $timing.Result.Success | Should -Be $true
        }
        
        It 'Should handle multiple rapid patch operations' {
            $results = @()
            $totalTime = Measure-ExecutionTime {
                1..10 | ForEach-Object {
                    $patchOp = { "Rapid patch $_" | Set-Content "rapid$_.txt" }
                    $result = Invoke-PatchWorkflow -PatchDescription "Rapid patch $_" -PatchOperation $patchOp -CreateIssue:$false -Force
                    $results += $result
                }
            }
            
            # 10 operations should complete within 15 seconds
            $totalTime.ElapsedMilliseconds | Should -BeLessThan 15000
            $results | Should -HaveCount 10
            $results | ForEach-Object { $_.Success | Should -Be $true }
        }
        
        It 'Should maintain performance with many affected files' {
            $manyFilesOp = {
                # Touch many existing files
                1..50 | ForEach-Object {
                    "Performance test update $_" | Add-Content "file$_.ps1"
                }
            }
            
            $timing = Measure-ExecutionTime {
                Invoke-PatchWorkflow -PatchDescription "Many files patch" -PatchOperation $manyFilesOp -CreateIssue:$false -Force
            }
            
            # Should handle 50 files within 4 seconds
            $timing.ElapsedMilliseconds | Should -BeLessThan 4000
            $timing.Result.Success | Should -Be $true
        }
    }
    
    Context 'Memory Usage Performance' {
        It 'Should not leak memory during repeated operations' {
            # Get initial memory
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform many operations
            1..20 | ForEach-Object {
                $patchOp = { "Memory test $_" | Set-Content "memtest$_.txt" }
                Invoke-PatchWorkflow -PatchDescription "Memory test $_" -PatchOperation $patchOp -CreateIssue:$false -Force
                
                # Cleanup files to prevent disk space issues
                Remove-Item "memtest$_.txt" -ErrorAction SilentlyContinue
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            $finalMemory = [GC]::GetTotalMemory($false)
            
            # Memory increase should be minimal (< 50MB)
            $memoryIncrease = ($finalMemory - $initialMemory) / 1MB
            $memoryIncrease | Should -BeLessThan 50
        }
        
        It 'Should handle large patch descriptions efficiently' {
            $largePatchOp = { 'Large description test' | Set-Content 'large-desc.txt' }
            $largeDescription = "A" * 10000  # 10KB description
            
            $timing = Measure-ExecutionTime {
                Invoke-PatchWorkflow -PatchDescription $largeDescription -PatchOperation $largePatchOp -CreateIssue:$false -Force
            }
            
            # Large description shouldn't significantly impact performance
            $timing.ElapsedMilliseconds | Should -BeLessThan 3000
            $timing.Result.Success | Should -Be $true
        }
    }
    
    Context 'Git Operation Performance' {
        It 'Should perform git operations efficiently' {
            # Measure git status checks
            $statusTime = Measure-ExecutionTime {
                1..10 | ForEach-Object {
                    git status --porcelain 2>&1 | Out-Null
                }
            }
            
            # 10 status checks should be very fast
            $statusTime.ElapsedMilliseconds | Should -BeLessThan 1000
        }
        
        It 'Should handle branch operations efficiently' {
            $branchTime = Measure-ExecutionTime {
                # Create and switch between branches
                1..5 | ForEach-Object {
                    git checkout -b "perf-branch-$_" 2>&1 | Out-Null
                    git checkout main 2>&1 | Out-Null
                    git branch -D "perf-branch-$_" 2>&1 | Out-Null
                }
            }
            
            # Branch operations should be fast
            $branchTime.ElapsedMilliseconds | Should -BeLessThan 2000
        }
        
        It 'Should handle commit operations efficiently' {
            $commitTime = Measure-ExecutionTime {
                1..5 | ForEach-Object {
                    "Commit perf test $_" | Set-Content "commit-perf-$_.txt"
                    git add "commit-perf-$_.txt" 2>&1 | Out-Null
                    git commit -m "Performance commit $_" 2>&1 | Out-Null
                }
            }
            
            # 5 commits should complete quickly
            $commitTime.ElapsedMilliseconds | Should -BeLessThan 3000
        }
    }
    
    Context 'Concurrent Operation Simulation' {
        It 'Should handle simulated concurrent patch workflows' -Skip {
            # Skip this test as PowerShell runspaces would be complex to set up
            # and PatchManager is designed for sequential operation
            $true | Should -Be $true
        }
    }
    
    Context 'Error Handling Performance' {
        It 'Should fail fast when git is not available' {
            Mock git { throw "git not found" } -ModuleName $script:ModuleName
            
            $timing = Measure-ExecutionTime {
                try {
                    Invoke-PatchWorkflow -PatchDescription "Git not available test" -CreateIssue:$false -Force
                } catch {
                    # Expected to fail
                }
            }
            
            # Should fail quickly, not hang
            $timing.ElapsedMilliseconds | Should -BeLessThan 500
        }
        
        It 'Should handle patch operation failures efficiently' {
            $failingPatchOp = { throw "Patch operation failed" }
            
            $timing = Measure-ExecutionTime {
                try {
                    Invoke-PatchWorkflow -PatchDescription "Failing patch" -PatchOperation $failingPatchOp -CreateIssue:$false -Force
                } catch {
                    # Expected to fail
                }
            }
            
            # Error handling should be fast
            $timing.ElapsedMilliseconds | Should -BeLessThan 1000
        }
    }
    
    Context 'Resource Cleanup Performance' {
        It 'Should clean up temporary branches efficiently' {
            # Create several patch workflows to generate branches
            $branches = @()
            1..5 | ForEach-Object {
                $patchOp = { "Cleanup test $_" | Set-Content "cleanup$_.txt" }
                $result = Invoke-PatchWorkflow -PatchDescription "Cleanup test $_" -PatchOperation $patchOp -CreateIssue:$false -Force
                $branches += $result.BranchName
            }
            
            # Measure cleanup time
            $cleanupTime = Measure-ExecutionTime {
                $branches | ForEach-Object {
                    if (git branch --list $_ 2>&1) {
                        git branch -D $_ 2>&1 | Out-Null
                    }
                }
            }
            
            # Cleanup should be fast
            $cleanupTime.ElapsedMilliseconds | Should -BeLessThan 1000
        }
    }
    
    Context 'Comparative Performance' {
        It 'Should demonstrate performance improvement over multiple individual git commands' {
            # Measure individual git operations
            $individualTime = Measure-ExecutionTime {
                git checkout -b 'manual-patch' 2>&1 | Out-Null
                'Manual content' | Set-Content 'manual.txt'
                git add . 2>&1 | Out-Null
                git commit -m "Manual patch" 2>&1 | Out-Null
                git checkout main 2>&1 | Out-Null
                git branch -D 'manual-patch' 2>&1 | Out-Null
            }
            
            # Measure PatchManager workflow
            $patchManagerTime = Measure-ExecutionTime {
                $patchOp = { 'PatchManager content' | Set-Content 'patchmanager.txt' }
                Invoke-PatchWorkflow -PatchDescription "PatchManager test" -PatchOperation $patchOp -CreateIssue:$false -Force
            }
            
            # PatchManager should be competitive or better
            # Allow some overhead for additional features like validation
            $ratio = $patchManagerTime.ElapsedMilliseconds / $individualTime.ElapsedMilliseconds
            $ratio | Should -BeLessThan 2.0  # Should not be more than 2x slower
            
            Write-Host "Individual operations: $($individualTime.ElapsedMilliseconds)ms"
            Write-Host "PatchManager workflow: $($patchManagerTime.ElapsedMilliseconds)ms"
            Write-Host "Ratio: $([Math]::Round($ratio, 2))"
        }
    }
}