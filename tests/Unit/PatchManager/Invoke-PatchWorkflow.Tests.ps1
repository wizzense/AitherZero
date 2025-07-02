#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'Invoke-PatchWorkflow'
}

Describe 'PatchManager.Invoke-PatchWorkflow' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock git { } -ModuleName $script:ModuleName
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Import-Module { } -ModuleName $script:ModuleName
        Mock Get-Module { } -ModuleName $script:ModuleName
        Mock Write-Host { } -ModuleName $script:ModuleName
        
        # Mock internal functions
        Mock New-PatchIssue { 
            @{ 
                IssueNumber = 123
                IssueUrl = 'https://github.com/test/repo/issues/123'
                Success = $true 
            }
        } -ModuleName $script:ModuleName
        
        Mock New-PatchPR {
            @{
                PRNumber = 456
                PRUrl = 'https://github.com/test/repo/pull/456'
                Success = $true
            }
        } -ModuleName $script:ModuleName
        
        Mock Sync-GitBranch {
            @{ Success = $true; Message = 'Synced successfully' }
        } -ModuleName $script:ModuleName
        
        Mock Test-Path { $true } -ModuleName $script:ModuleName
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'PatchManagerTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require PatchDescription parameter' {
            { Invoke-PatchWorkflow } | Should -Throw
        }
        
        It 'Should accept valid PatchDescription' {
            Mock git { 
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchWorkflow -PatchDescription "Test patch" -CreateIssue:$false -DryRun } | Should -Not -Throw
        }
        
        It 'Should validate Priority parameter values' {
            { Invoke-PatchWorkflow -PatchDescription "Test" -Priority "Invalid" -DryRun } | Should -Throw
        }
        
        It 'Should accept valid Priority values' {
            $validPriorities = @('Low', 'Medium', 'High', 'Critical')
            
            Mock git { 
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            foreach ($priority in $validPriorities) {
                { Invoke-PatchWorkflow -PatchDescription "Test" -Priority $priority -CreateIssue:$false -DryRun } | Should -Not -Throw
            }
        }
        
        It 'Should validate TargetFork parameter values' {
            { Invoke-PatchWorkflow -PatchDescription "Test" -TargetFork "invalid" -DryRun } | Should -Throw
        }
        
        It 'Should validate ConsolidationStrategy parameter values' {
            { Invoke-PatchWorkflow -PatchDescription "Test" -ConsolidationStrategy "invalid" -DryRun } | Should -Throw
        }
    }
    
    Context 'Merge Conflict Detection' {
        It 'Should detect and fail on merge conflicts' {
            Mock git {
                if ($args -contains 'grep' -and $args -contains '^<<<<<<< HEAD') {
                    return @('file1.ps1', 'file2.ps1')
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchWorkflow -PatchDescription "Test with conflicts" } | Should -Throw "*MERGE CONFLICTS DETECTED*"
        }
        
        It 'Should proceed when no merge conflicts exist' {
            Mock git {
                if ($args -contains 'grep') { return $null }
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchWorkflow -PatchDescription "Test no conflicts" -CreateIssue:$false -DryRun } | Should -Not -Throw
        }
    }
    
    Context 'Working Tree Management' {
        It 'Should stash uncommitted changes' {
            Mock git {
                if ($args -contains 'status' -and $args -contains '--porcelain') {
                    return @('M file1.ps1', 'A file2.ps1')
                }
                if ($args -contains 'stash' -and $args -contains 'push') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchWorkflow -PatchDescription "Test stash" -CreateIssue:$false -DryRun
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'stash' -and $args -contains 'push'
            } -Times 0 # Because DryRun
        }
        
        It 'Should handle clean working tree' {
            Mock git {
                if ($args -contains 'status' -and $args -contains '--porcelain') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            { Invoke-PatchWorkflow -PatchDescription "Clean tree test" -CreateIssue:$false -DryRun } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Working tree is clean"
            }
        }
    }
    
    Context 'Branch Management' {
        It 'Should switch to main branch if on different branch' {
            $callCount = 0
            Mock git {
                if ($args -contains 'branch' -and $args -contains '--show-current') {
                    if ($callCount -eq 0) {
                        $script:callCount++
                        return 'feature-branch'
                    }
                    return 'main'
                }
                if ($args -contains 'checkout' -and $args -contains 'main') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                if ($args -contains 'status') { return '' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchWorkflow -PatchDescription "Branch test" -CreateIssue:$false -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'checkout' -and $args -contains 'main'
            }
        }
        
        It 'Should use Sync-GitBranch when available' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Mock Get-Command { $true } -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'Sync-GitBranch'
            }
            
            Invoke-PatchWorkflow -PatchDescription "Sync test" -CreateIssue:$false -Force
            
            Should -Invoke Sync-GitBranch -ModuleName $script:ModuleName -ParameterFilter {
                $BranchName -eq 'main' -and $Force -eq $true
            }
        }
    }
    
    Context 'Dry Run Mode' {
        It 'Should not make actual changes in dry run mode' {
            Mock git {
                if ($args -contains 'status') { return 'M file.ps1' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Invoke-PatchWorkflow -PatchDescription "Dry run test" -DryRun -CreateIssue:$false
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'stash'
            } -Times 0
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "DRY RUN MODE"
            }
        }
    }
    
    Context 'Issue Creation' {
        It 'Should create issue by default' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "Issue test" -Force
            
            Should -Invoke New-PatchIssue -ModuleName $script:ModuleName
            $result.IssueCreated | Should -Be $true
            $result.IssueNumber | Should -Be 123
        }
        
        It 'Should skip issue creation when CreateIssue is false' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "No issue test" -CreateIssue:$false -Force
            
            Should -Invoke New-PatchIssue -ModuleName $script:ModuleName -Times 0
            $result.IssueCreated | Should -Be $false
        }
    }
    
    Context 'Pull Request Creation' {
        It 'Should create PR when CreatePR switch is used' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "PR test" -CreatePR -Force
            
            Should -Invoke New-PatchPR -ModuleName $script:ModuleName
            $result.PRCreated | Should -Be $true
            $result.PRNumber | Should -Be 456
        }
        
        It 'Should not create PR by default' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "No PR test" -CreateIssue:$false -Force
            
            Should -Invoke New-PatchPR -ModuleName $script:ModuleName -Times 0
            $result.PRCreated | Should -Be $false
        }
    }
    
    Context 'Test Command Execution' {
        It 'Should execute test commands when provided' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Mock Invoke-Expression { "Test passed" } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "Test commands" -TestCommands @('Test-Module') -CreateIssue:$false -Force
            
            Should -Invoke Invoke-Expression -ModuleName $script:ModuleName -ParameterFilter {
                $Command -eq 'Test-Module'
            }
        }
        
        It 'Should handle test failures gracefully' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Mock Invoke-Expression { throw "Test failed" } -ModuleName $script:ModuleName
            
            { Invoke-PatchWorkflow -PatchDescription "Failed test" -TestCommands @('Test-Fail') -CreateIssue:$false -Force } | Should -Not -Throw
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Test command failed" -and $Level -eq 'WARN'
            }
        }
    }
    
    Context 'Patch Operation Execution' {
        It 'Should execute patch operation when provided' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $operationExecuted = $false
            $patchOp = { $script:operationExecuted = $true }
            
            Invoke-PatchWorkflow -PatchDescription "Op test" -PatchOperation $patchOp -CreateIssue:$false -Force
            
            $operationExecuted | Should -Be $true
        }
        
        It 'Should handle patch operation errors' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $patchOp = { throw "Operation failed" }
            
            { Invoke-PatchWorkflow -PatchDescription "Error op" -PatchOperation $patchOp -CreateIssue:$false -Force } | Should -Throw "*Operation failed*"
        }
    }
    
    Context 'Auto Consolidation' {
        It 'Should trigger consolidation when AutoConsolidate is used' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Mock Invoke-IntelligentPRConsolidation {
                @{ Success = $true; ConsolidatedPRs = 2 }
            } -ModuleName $script:ModuleName
            
            $result = Invoke-PatchWorkflow -PatchDescription "Consolidate test" -CreatePR -AutoConsolidate -Force
            
            Should -Invoke Invoke-IntelligentPRConsolidation -ModuleName $script:ModuleName -ParameterFilter {
                $Strategy -eq 'Compatible' -and $MaxPRs -eq 5
            }
        }
        
        It 'Should respect ConsolidationStrategy parameter' {
            Mock git {
                if ($args -contains 'status') { return '' }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            Mock Invoke-IntelligentPRConsolidation {
                @{ Success = $true }
            } -ModuleName $script:ModuleName
            
            Invoke-PatchWorkflow -PatchDescription "Strategy test" -CreatePR -AutoConsolidate -ConsolidationStrategy "SameAuthor" -Force
            
            Should -Invoke Invoke-IntelligentPRConsolidation -ModuleName $script:ModuleName -ParameterFilter {
                $Strategy -eq 'SameAuthor'
            }
        }
    }
    
    Context 'Error Recovery' {
        It 'Should restore stash on error' {
            Mock git {
                if ($args -contains 'status' -and $args -contains '--porcelain') {
                    return 'M file.ps1'
                }
                if ($args -contains 'stash' -and $args -contains 'push') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                if ($args -contains 'stash' -and $args -contains 'pop') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                if ($args -contains 'branch' -and $args -contains '--show-current') { return 'main' }
                if ($args -contains 'grep') { return $null }
                return ''
            } -ModuleName $script:ModuleName
            
            $patchOp = { throw "Operation error" }
            
            try {
                Invoke-PatchWorkflow -PatchDescription "Stash restore test" -PatchOperation $patchOp -CreateIssue:$false -Force
            } catch {
                # Expected to throw
            }
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'stash' -and $args -contains 'pop'
            }
        }
    }
}