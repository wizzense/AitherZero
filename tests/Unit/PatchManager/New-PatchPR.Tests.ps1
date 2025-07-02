#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'New-PatchPR'
}

Describe 'PatchManager.New-PatchPR' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Write-Host { } -ModuleName $script:ModuleName
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        Mock Get-Variable { } -ModuleName $script:ModuleName
        
        # Mock git operations
        Mock git {
            if ($args -contains 'config' -and $args -contains 'user.email') {
                return 'test@example.com'
            }
            if ($args -contains 'config' -and $args -contains 'user.name') {
                return 'Test User'
            }
            if ($args -contains 'remote' -and $args -contains 'get-url') {
                return 'https://github.com/testuser/testrepo.git'
            }
            if ($args -contains 'branch' -and $args -contains '--show-current') {
                return 'patch/test-branch'
            }
            if ($args -contains 'log' -and $args -contains '--oneline') {
                return @(
                    'abc123 Latest commit',
                    'def456 Previous commit',
                    'ghi789 Initial commit'
                )
            }
            if ($args -contains 'diff' -and $args -contains '--name-only') {
                return @('file1.ps1', 'file2.ps1')
            }
            if ($args -contains 'push') {
                $script:LASTEXITCODE = 0
                return ''
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock gh CLI
        Mock gh {
            if ($args -contains 'pr' -and $args -contains 'create') {
                return 'https://github.com/testuser/testrepo/pull/456'
            }
            if ($args -contains 'pr' -and $args -contains 'list') {
                return ''
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock Get-GitRepositoryInfo
        Mock Get-GitRepositoryInfo {
            @{
                Owner = 'testuser'
                Name = 'testrepo'
                FullName = 'testuser/testrepo'
                Type = 'fork'
                Branch = 'patch/test-branch'
                Remote = 'origin'
            }
        } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'PatchManagerPRTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Description parameter' {
            { New-PatchPR -BranchName "test-branch" } | Should -Throw
        }
        
        It 'Should require BranchName parameter' {
            { New-PatchPR -Description "Test PR" } | Should -Throw
        }
        
        It 'Should accept valid required parameters' {
            { New-PatchPR -Description "Test PR" -BranchName "patch/test" -DryRun } | Should -Not -Throw
        }
        
        It 'Should accept optional IssueNumber' {
            { New-PatchPR -Description "Test" -BranchName "patch/test" -IssueNumber 123 -DryRun } | Should -Not -Throw
        }
        
        It 'Should accept optional AffectedFiles' {
            { New-PatchPR -Description "Test" -BranchName "patch/test" -AffectedFiles @('file1.ps1') -DryRun } | Should -Not -Throw
        }
    }
    
    Context 'GitHub CLI Availability' {
        It 'Should check for gh CLI availability' {
            New-PatchPR -Description "Test" -BranchName "patch/test" -DryRun
            
            Should -Invoke Get-Command -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'gh'
            }
        }
        
        It 'Should throw error if gh CLI not available' {
            Mock Get-Command { $false } -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'gh'
            }
            
            { New-PatchPR -Description "Test" -BranchName "patch/test" } | Should -Throw "*GitHub CLI*not found*"
        }
    }
    
    Context 'Dry Run Mode' {
        It 'Should not create actual PR in dry run mode' {
            $result = New-PatchPR -Description "Dry run test" -BranchName "patch/dry-run" -DryRun
            
            Should -Invoke gh -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'pr' -and $args -contains 'create'
            }
            
            $result.DryRun | Should -Be $true
        }
        
        It 'Should log dry run information' {
            New-PatchPR -Description "Dry run logging" -BranchName "patch/test" -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "DRY RUN" -and $Level -eq 'WARN'
            }
        }
    }
    
    Context 'Pull Request Creation' {
        It 'Should create PR with proper title' {
            New-PatchPR -Description "Fix module loading" -BranchName "patch/fix-loading"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'pr' -and
                $args -contains 'create' -and
                $args -contains '--title' -and
                $args -contains 'Patch: Fix module loading'
            }
        }
        
        It 'Should push branch before creating PR' {
            New-PatchPR -Description "Test push" -BranchName "patch/test-push"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'push' -and
                $args -contains 'origin' -and
                $args -contains 'patch/test-push'
            }
        }
        
        It 'Should set upstream tracking on push' {
            New-PatchPR -Description "Test tracking" -BranchName "patch/test-track"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'push' -and
                $args -contains '--set-upstream'
            }
        }
    }
    
    Context 'Issue Linking' {
        It 'Should link issue when IssueNumber provided' {
            New-PatchPR -Description "Fix bug" -BranchName "patch/fix" -IssueNumber 123
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0 -and $bodyIndex + 1 -lt $args.Count) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'Fixes #123' -or $body -match 'Closes #123'
                } else {
                    $false
                }
            }
        }
        
        It 'Should not include issue link when not provided' {
            New-PatchPR -Description "No issue" -BranchName "patch/no-issue"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -notmatch 'Fixes #' -and $body -notmatch 'Closes #'
                } else {
                    $true
                }
            }
        }
    }
    
    Context 'Affected Files Handling' {
        It 'Should include affected files in PR body' {
            $files = @('module1.ps1', 'config.json', 'README.md')
            
            New-PatchPR -Description "Multi-file change" -BranchName "patch/multi" -AffectedFiles $files
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'module1\.ps1' -and
                    $body -match 'config\.json' -and
                    $body -match 'README\.md'
                } else {
                    $false
                }
            }
        }
        
        It 'Should auto-detect affected files if not provided' {
            New-PatchPR -Description "Auto-detect files" -BranchName "patch/auto"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'diff' -and
                $args -contains '--name-only'
            }
        }
    }
    
    Context 'Repository Detection' {
        It 'Should detect repository information' {
            New-PatchPR -Description "Repo test" -BranchName "patch/repo"
            
            Should -Invoke Get-GitRepositoryInfo -ModuleName $script:ModuleName
        }
        
        It 'Should handle repository detection failure' {
            Mock Get-GitRepositoryInfo { throw "No git repo" } -ModuleName $script:ModuleName
            
            { New-PatchPR -Description "No repo" -BranchName "patch/test" } | Should -Throw "*Failed to detect repository*"
        }
    }
    
    Context 'Commit Information' {
        It 'Should include recent commits in PR body' {
            New-PatchPR -Description "Commit info test" -BranchName "patch/commits"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'log' -and
                $args -contains '--oneline'
            }
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'Recent Commits' -or $body -match 'Changes'
                } else {
                    $false
                }
            }
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle push failure' {
            Mock git {
                if ($args -contains 'push') {
                    $script:LASTEXITCODE = 1
                    throw "Failed to push"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { New-PatchPR -Description "Push fail" -BranchName "patch/fail" } | Should -Throw "*Failed to push*"
        }
        
        It 'Should handle PR creation failure' {
            Mock gh { throw "API error" } -ModuleName $script:ModuleName
            
            { New-PatchPR -Description "PR fail" -BranchName "patch/fail" } | Should -Throw "*API error*"
        }
        
        It 'Should provide meaningful error for authentication issues' {
            Mock gh {
                Write-Error "error: not authenticated"
                throw "Authentication required"
            } -ModuleName $script:ModuleName
            
            { New-PatchPR -Description "Auth test" -BranchName "patch/auth" } | Should -Throw "*Authentication*"
        }
    }
    
    Context 'PR URL Extraction' {
        It 'Should extract PR number from URL' {
            Mock gh { 'https://github.com/testuser/testrepo/pull/789' } -ModuleName $script:ModuleName
            
            $result = New-PatchPR -Description "URL test" -BranchName "patch/url"
            
            $result.PRNumber | Should -Be 789
            $result.PRUrl | Should -Be 'https://github.com/testuser/testrepo/pull/789'
        }
        
        It 'Should handle different URL formats' {
            Mock gh { '456' } -ModuleName $script:ModuleName
            
            $result = New-PatchPR -Description "Number test" -BranchName "patch/num"
            
            $result.PRNumber | Should -Be 456
        }
    }
    
    Context 'Progress Context' {
        It 'Should detect parent progress context' {
            # Simulate parent progress context
            $script:progressId = 100
            
            New-PatchPR -Description "Progress test" -BranchName "patch/progress" -DryRun
            
            Should -Invoke Get-Variable -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'progressId' -and $Scope -eq 1
            }
        }
    }
    
    Context 'Base Branch Handling' {
        It 'Should target main branch by default' {
            New-PatchPR -Description "Base test" -BranchName "patch/base"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--base' -and
                $args -contains 'main'
            }
        }
    }
    
    Context 'PR Body Content' {
        It 'Should include comprehensive information in PR body' {
            New-PatchPR -Description "Comprehensive test" -BranchName "patch/comp" -IssueNumber 100
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    # Should include various sections
                    $body -match 'Description' -and
                    $body -match 'Testing' -and
                    $body -match 'Environment'
                } else {
                    $false
                }
            }
        }
    }
}