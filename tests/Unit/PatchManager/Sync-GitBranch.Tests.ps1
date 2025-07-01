#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'Sync-GitBranch'
}

Describe 'PatchManager.Sync-GitBranch' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Write-Host { } -ModuleName $script:ModuleName
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        
        # Mock git operations
        Mock git {
            if ($args -contains 'branch' -and $args -contains '--show-current') {
                return 'main'
            }
            if ($args -contains 'fetch') {
                $script:LASTEXITCODE = 0
                return 'Fetching origin'
            }
            if ($args -contains 'rev-parse') {
                if ($args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'origin/main') {
                    return 'def456'
                }
                return 'ghi789'
            }
            if ($args -contains 'merge-base') {
                return 'abc123'
            }
            if ($args -contains 'status' -and $args -contains '--porcelain') {
                return ''  # Clean working tree
            }
            if ($args -contains 'checkout') {
                $script:LASTEXITCODE = 0
                return 'Switched to branch main'
            }
            if ($args -contains 'reset') {
                $script:LASTEXITCODE = 0
                return 'HEAD is now at def456'
            }
            if ($args -contains 'branch' -and $args -contains '-r') {
                return @(
                    'origin/main',
                    'origin/develop',
                    'origin/feature/test'
                )
            }
            if ($args -contains 'branch' -and $args -contains '-a') {
                return @(
                    '* main',
                    '  develop',
                    '  feature/test',
                    '  remotes/origin/main',
                    '  remotes/origin/develop'
                )
            }
            if ($args -contains 'tag' -and $args -contains '--list') {
                return @('v1.0.0', 'v1.1.0', 'v2.0.0')
            }
            if ($args -contains 'ls-remote') {
                return @(
                    'def456	refs/heads/main',
                    'ghi789	refs/heads/develop',
                    'jkl012	refs/tags/v1.0.0',
                    'mno345	refs/tags/v1.1.0'
                )
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'SyncGitBranchTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Handling' {
        It 'Should use current branch when BranchName not specified' {
            $result = Sync-GitBranch
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'branch' -and $args -contains '--show-current'
            }
            
            $result.BranchName | Should -Be 'main'
        }
        
        It 'Should use specified BranchName' {
            $result = Sync-GitBranch -BranchName 'develop'
            
            $result.BranchName | Should -Be 'develop'
        }
        
        It 'Should handle empty current branch' {
            Mock git {
                if ($args -contains 'branch' -and $args -contains '--show-current') {
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Sync-GitBranch } | Should -Throw "*Could not determine current branch*"
        }
    }
    
    Context 'Basic Synchronization' {
        It 'Should fetch from remote' {
            Sync-GitBranch -BranchName 'main'
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'fetch' -and $args -contains 'origin'
            }
        }
        
        It 'Should log synchronization start' {
            Sync-GitBranch -BranchName 'main'
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Starting Git branch synchronization" -and
                $Level -eq 'INFO'
            }
        }
        
        It 'Should log branch being synchronized' {
            Sync-GitBranch -BranchName 'feature/test'
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Synchronizing branch: feature/test" -and
                $Level -eq 'INFO'
            }
        }
    }
    
    Context 'Divergence Detection' {
        It 'Should detect when local and remote are in sync' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'abc123'  # Same commit
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main'
            
            $result.Diverged | Should -Be $false
            $result.Synchronized | Should -Be $true
        }
        
        It 'Should detect when local is ahead of remote' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'def456'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'abc123'
                }
                if ($args -contains 'merge-base') {
                    return 'abc123'  # Remote is ancestor of local
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main'
            
            $result.LocalAhead | Should -Be $true
            $result.Action | Should -Match 'ahead'
        }
        
        It 'Should detect when local is behind remote' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'def456'
                }
                if ($args -contains 'merge-base') {
                    return 'abc123'  # Local is ancestor of remote
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main'
            
            $result.LocalBehind | Should -Be $true
            $result.Action | Should -Match 'behind'
        }
        
        It 'Should detect true divergence' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'def456'
                }
                if ($args -contains 'merge-base') {
                    return 'ghi789'  # Different from both
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main'
            
            $result.Diverged | Should -Be $true
            $result.Action | Should -Match 'diverged'
        }
    }
    
    Context 'Force Reset Handling' {
        It 'Should reset local branch when Force is used and diverged' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'def456'
                }
                if ($args -contains 'merge-base') {
                    return 'ghi789'  # Diverged
                }
                if ($args -contains 'status' -and $args -contains '--porcelain') {
                    return ''  # Clean working tree
                }
                if ($args -contains 'reset' -and $args -contains '--hard') {
                    $script:LASTEXITCODE = 0
                    return 'HEAD is now at def456'
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main' -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'reset' -and 
                $args -contains '--hard' -and 
                $args -contains 'origin/main'
            }
            
            $result.ForceReset | Should -Be $true
        }
        
        It 'Should check working tree before force reset' {
            Sync-GitBranch -BranchName 'main' -Force
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'status' -and $args -contains '--porcelain'
            }
        }
        
        It 'Should warn about uncommitted changes before force reset' {
            Mock git {
                if ($args -contains 'status' -and $args -contains '--porcelain') {
                    return 'M file1.ps1'  # Dirty working tree
                }
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'def456'
                }
                if ($args -contains 'merge-base') {
                    return 'ghi789'
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main' -Force
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Working tree has uncommitted changes" -and
                $Level -eq 'WARN'
            }
        }
    }
    
    Context 'Orphaned Branch Cleanup' {
        It 'Should clean up orphaned branches when CleanupOrphaned is used' {
            Mock git {
                if ($args -contains 'branch' -and $args -contains '-r') {
                    return @('origin/main', 'origin/develop')
                }
                if ($args -contains 'branch' -and $args -contains '-a') {
                    return @(
                        '* main',
                        '  develop',
                        '  orphaned-branch',  # This doesn't exist on remote
                        '  remotes/origin/main',
                        '  remotes/origin/develop'
                    )
                }
                if ($args -contains 'branch' -and $args -contains '-D') {
                    $script:LASTEXITCODE = 0
                    return 'Deleted branch orphaned-branch'
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -CleanupOrphaned
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'branch' -and
                $args -contains '-D' -and
                $args -contains 'orphaned-branch'
            }
            
            $result.OrphanedBranchesRemoved | Should -HaveCount 1
            $result.OrphanedBranchesRemoved | Should -Contain 'orphaned-branch'
        }
        
        It 'Should skip cleanup when CleanupOrphaned not specified' {
            $result = Sync-GitBranch -BranchName 'main'
            
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'branch' -and $args -contains '-D'
            }
            
            $result.OrphanedBranchesRemoved | Should -BeNullOrEmpty
        }
    }
    
    Context 'Tag Validation' {
        It 'Should validate tags when ValidateTags is used' {
            Sync-GitBranch -ValidateTags
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'tag' -and $args -contains '--list'
            }
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'ls-remote' -and $args -contains '--tags'
            }
        }
        
        It 'Should detect duplicate tags' {
            Mock git {
                if ($args -contains 'tag' -and $args -contains '--list') {
                    return @('v1.0.0', 'v1.1.0', 'v1.0.0')  # Duplicate
                }
                if ($args -contains 'ls-remote' -and $args -contains '--tags') {
                    return @(
                        'abc123	refs/tags/v1.0.0',
                        'def456	refs/tags/v1.1.0'
                    )
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -ValidateTags
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "duplicate.*tag" -and $Level -eq 'WARN'
            }
        }
        
        It 'Should skip tag validation when ValidateTags not specified' {
            Sync-GitBranch -BranchName 'main'
            
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'tag' -and $args -contains '--list'
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle fetch failure' {
            Mock git {
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 1
                    throw "fetch failed"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Sync-GitBranch -BranchName 'main' } | Should -Throw "*fetch failed*"
        }
        
        It 'Should handle reset failure' {
            Mock git {
                if ($args -contains 'reset') {
                    $script:LASTEXITCODE = 1
                    throw "reset failed"
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Sync-GitBranch -BranchName 'main' -Force } | Should -Throw "*reset failed*"
        }
        
        It 'Should handle missing remote branch' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'origin/nonexistent') {
                    $script:LASTEXITCODE = 1
                    throw "fatal: bad revision"
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { Sync-GitBranch -BranchName 'nonexistent' } | Should -Throw "*bad revision*"
        }
    }
    
    Context 'ShouldProcess Support' {
        It 'Should support WhatIf for force reset' {
            Mock git {
                if ($args -contains 'rev-parse' -and $args -contains 'HEAD') {
                    return 'abc123'
                }
                if ($args -contains 'rev-parse' -and $args -contains 'origin/main') {
                    return 'def456'
                }
                if ($args -contains 'merge-base') {
                    return 'ghi789'  # Diverged
                }
                if ($args -contains 'fetch') {
                    $script:LASTEXITCODE = 0
                    return ''
                }
                return ''
            } -ModuleName $script:ModuleName
            
            $result = Sync-GitBranch -BranchName 'main' -Force -WhatIf
            
            # Should not actually perform reset in WhatIf mode
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'reset' -and $args -contains '--hard'
            }
        }
    }
    
    Context 'Return Value Structure' {
        It 'Should return comprehensive result object' {
            $result = Sync-GitBranch -BranchName 'main'
            
            $result | Should -HaveProperty 'Success'
            $result | Should -HaveProperty 'BranchName'
            $result | Should -HaveProperty 'Synchronized'
            $result | Should -HaveProperty 'Diverged'
            $result | Should -HaveProperty 'Action'
            $result | Should -HaveProperty 'Message'
        }
        
        It 'Should indicate success for normal sync' {
            $result = Sync-GitBranch -BranchName 'main'
            
            $result.Success | Should -Be $true
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }
}