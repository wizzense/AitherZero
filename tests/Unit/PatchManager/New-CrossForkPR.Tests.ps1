#Requires -Version 7.0
#Requires -Modules Pester

BeforeDiscovery {
    $script:ModulePath = Join-Path $PSScriptRoot '../../../aither-core/modules/PatchManager'
    $script:ModuleName = 'PatchManager'
    $script:FunctionName = 'New-CrossForkPR'
}

Describe 'PatchManager.New-CrossForkPR' -Tag 'Unit' {
    BeforeAll {
        # Import module
        Import-Module $script:ModulePath -Force
        
        # Mock external dependencies
        Mock Write-CustomLog { } -ModuleName $script:ModuleName
        Mock Write-Host { } -ModuleName $script:ModuleName
        Mock Get-Command { $true } -ModuleName $script:ModuleName
        
        # Mock git operations
        Mock git {
            if ($args -contains 'remote' -and $args -contains 'get-url') {
                return 'https://github.com/testuser/AitherZero.git'
            }
            if ($args -contains 'push') {
                $script:LASTEXITCODE = 0
                return 'Pushed successfully'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock GitHub CLI
        Mock gh {
            if ($args -contains 'pr' -and $args -contains 'create') {
                return 'https://github.com/AitherLabs/AitherZero/pull/456'
            }
            return ''
        } -ModuleName $script:ModuleName
        
        # Mock repository detection functions
        Mock Get-GitRepositoryInfo {
            @{
                Owner = 'testuser'
                Name = 'AitherZero'
                FullName = 'testuser/AitherZero'
                Type = 'fork'
                Branch = 'feature/test'
                Remote = 'origin'
                UpstreamOwner = 'AitherLabs'
                RootOwner = 'Aitherium'
            }
        } -ModuleName $script:ModuleName
        
        # Mock fork chain detection
        Mock Get-ForkChainInfo {
            @{
                Current = @{ Owner = 'testuser'; Repo = 'AitherZero' }
                Upstream = @{ Owner = 'AitherLabs'; Repo = 'AitherZero' }
                Root = @{ Owner = 'Aitherium'; Repo = 'AitherZero' }
                Chain = @('testuser/AitherZero', 'AitherLabs/AitherZero', 'Aitherium/AitherZero')
            }
        } -ModuleName $script:ModuleName
        
        # Create test directory
        $script:TestRoot = Join-Path $TestDrive 'CrossForkPRTest'
        New-Item -Path $script:TestRoot -ItemType Directory -Force | Out-Null
        Set-Location $script:TestRoot
    }
    
    AfterAll {
        Remove-Module $script:ModuleName -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Parameter Validation' {
        It 'Should require Description parameter' {
            { New-CrossForkPR -BranchName "test-branch" } | Should -Throw
        }
        
        It 'Should require BranchName parameter' {
            { New-CrossForkPR -Description "Test PR" } | Should -Throw
        }
        
        It 'Should accept valid required parameters' {
            { New-CrossForkPR -Description "Test PR" -BranchName "test-branch" -DryRun } | Should -Not -Throw
        }
        
        It 'Should validate TargetFork parameter values' {
            { New-CrossForkPR -Description "Test" -BranchName "test" -TargetFork "invalid" } | Should -Throw
        }
        
        It 'Should accept valid TargetFork values' {
            $validTargets = @('current', 'upstream', 'root')
            
            foreach ($target in $validTargets) {
                { New-CrossForkPR -Description "Test" -BranchName "test" -TargetFork $target -DryRun } | Should -Not -Throw
            }
        }
        
        It 'Should use current as default TargetFork' {
            $result = New-CrossForkPR -Description "Default target test" -BranchName "test-branch" -DryRun
            
            $result.TargetFork | Should -Be 'current'
        }
    }
    
    Context 'Fork Chain Detection' {
        It 'Should detect repository information' {
            New-CrossForkPR -Description "Detection test" -BranchName "test-branch" -DryRun
            
            Should -Invoke Get-GitRepositoryInfo -ModuleName $script:ModuleName
        }
        
        It 'Should detect fork chain information' {
            New-CrossForkPR -Description "Fork chain test" -BranchName "test-branch" -TargetFork "upstream" -DryRun
            
            Should -Invoke Get-ForkChainInfo -ModuleName $script:ModuleName
        }
        
        It 'Should handle repository detection failure' {
            Mock Get-GitRepositoryInfo { throw "No git repo" } -ModuleName $script:ModuleName
            
            { New-CrossForkPR -Description "No repo test" -BranchName "test-branch" } | Should -Throw "*No git repo*"
        }
    }
    
    Context 'Target Fork Handling' {
        It 'Should target current repository for current TargetFork' {
            $result = New-CrossForkPR -Description "Current target" -BranchName "test-branch" -TargetFork "current" -DryRun
            
            $result.TargetRepository | Should -Be 'testuser/AitherZero'
            $result.TargetFork | Should -Be 'current'
        }
        
        It 'Should target upstream repository for upstream TargetFork' {
            $result = New-CrossForkPR -Description "Upstream target" -BranchName "test-branch" -TargetFork "upstream" -DryRun
            
            $result.TargetRepository | Should -Be 'AitherLabs/AitherZero'
            $result.TargetFork | Should -Be 'upstream'
        }
        
        It 'Should target root repository for root TargetFork' {
            $result = New-CrossForkPR -Description "Root target" -BranchName "test-branch" -TargetFork "root" -DryRun
            
            $result.TargetRepository | Should -Be 'Aitherium/AitherZero'
            $result.TargetFork | Should -Be 'root'
        }
    }
    
    Context 'Branch Management' {
        It 'Should push branch to origin before creating PR' {
            New-CrossForkPR -Description "Push test" -BranchName "test-branch" -TargetFork "current"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'push' -and
                $args -contains 'origin' -and
                $args -contains 'test-branch'
            }
        }
        
        It 'Should set upstream tracking on push' {
            New-CrossForkPR -Description "Tracking test" -BranchName "test-branch" -TargetFork "upstream"
            
            Should -Invoke git -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'push' -and
                $args -contains '--set-upstream'
            }
        }
        
        It 'Should handle push failure gracefully' {
            Mock git {
                if ($args -contains 'push') {
                    $script:LASTEXITCODE = 1
                    throw "Push failed"
                }
                return ''
            } -ModuleName $script:ModuleName
            
            { New-CrossForkPR -Description "Push failure" -BranchName "test-branch" } | Should -Throw "*Push failed*"
        }
    }
    
    Context 'Pull Request Creation' {
        It 'Should create PR with proper repository target' {
            New-CrossForkPR -Description "PR creation test" -BranchName "test-branch" -TargetFork "upstream"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains 'pr' -and
                $args -contains 'create' -and
                $args -contains '--repo' -and
                $args -contains 'AitherLabs/AitherZero'
            }
        }
        
        It 'Should include cross-fork information in PR title' {
            New-CrossForkPR -Description "Cross-fork promotion" -BranchName "feature/new" -TargetFork "upstream"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--title' -and
                ($args | Where-Object { $_ -match 'Cross-fork.*promotion' })
            }
        }
        
        It 'Should set correct head reference for cross-fork PR' {
            New-CrossForkPR -Description "Head ref test" -BranchName "test-branch" -TargetFork "upstream"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $args -contains '--head' -and
                $args -contains 'testuser:test-branch'
            }
        }
    }
    
    Context 'Issue Linking' {
        It 'Should link issue when IssueNumber provided' {
            New-CrossForkPR -Description "Issue link test" -BranchName "test-branch" -IssueNumber 123 -TargetFork "current"
            
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
            New-CrossForkPR -Description "No issue link" -BranchName "test-branch" -TargetFork "current"
            
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
            $files = @('src/module.ps1', 'config/settings.json', 'docs/README.md')
            
            New-CrossForkPR -Description "Files test" -BranchName "test-branch" -AffectedFiles $files -TargetFork "current"
            
            Should -Invoke gh -ModuleName $script:ModuleName -ParameterFilter {
                $bodyIndex = [Array]::IndexOf($args, '--body')
                if ($bodyIndex -ge 0) {
                    $body = $args[$bodyIndex + 1]
                    $body -match 'src/module\.ps1' -and
                    $body -match 'config/settings\.json' -and
                    $body -match 'docs/README\.md'
                } else {
                    $false
                }
            }
        }
    }
    
    Context 'Dry Run Mode' {
        It 'Should not create actual PR in dry run mode' {
            $result = New-CrossForkPR -Description "Dry run test" -BranchName "test-branch" -TargetFork "upstream" -DryRun
            
            Should -Invoke gh -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'pr' -and $args -contains 'create'
            }
            
            $result.DryRun | Should -Be $true
        }
        
        It 'Should not push branch in dry run mode' {
            New-CrossForkPR -Description "Dry run push test" -BranchName "test-branch" -DryRun
            
            Should -Invoke git -ModuleName $script:ModuleName -Times 0 -ParameterFilter {
                $args -contains 'push'
            }
        }
        
        It 'Should log dry run information' {
            New-CrossForkPR -Description "Dry run logging" -BranchName "test-branch" -TargetFork "root" -DryRun
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "DRY RUN" -and $Level -eq 'WARN'
            }
        }
    }
    
    Context 'Cross-Fork Scenarios' {
        It 'Should handle AitherZero to AitherLabs promotion' {
            $result = New-CrossForkPR -Description "Promote feature to public" -BranchName "feature/public" -TargetFork "upstream"
            
            $result.TargetRepository | Should -Be 'AitherLabs/AitherZero'
            $result.CrossFork | Should -Be $true
            $result.Direction | Should -Be 'testuser/AitherZero → AitherLabs/AitherZero'
        }
        
        It 'Should handle AitherLabs to Aitherium promotion' {
            Mock Get-GitRepositoryInfo {
                @{
                    Owner = 'AitherLabs'
                    Name = 'AitherZero'
                    FullName = 'AitherLabs/AitherZero'
                    Type = 'fork'
                    Branch = 'enterprise/feature'
                    Remote = 'origin'
                    UpstreamOwner = 'Aitherium'
                }
            } -ModuleName $script:ModuleName
            
            $result = New-CrossForkPR -Description "Add enterprise feature" -BranchName "enterprise/premium" -TargetFork "root"
            
            $result.TargetRepository | Should -Be 'Aitherium/AitherZero'
            $result.CrossFork | Should -Be $true
        }
    }
    
    Context 'Error Handling' {
        It 'Should handle GitHub CLI not available' {
            Mock Get-Command { $false } -ModuleName $script:ModuleName -ParameterFilter {
                $Name -eq 'gh'
            }
            
            { New-CrossForkPR -Description "No gh test" -BranchName "test-branch" } | Should -Throw "*GitHub CLI*not found*"
        }
        
        It 'Should handle PR creation failure' {
            Mock gh { throw "API error" } -ModuleName $script:ModuleName
            
            { New-CrossForkPR -Description "PR failure" -BranchName "test-branch" } | Should -Throw "*API error*"
        }
        
        It 'Should handle invalid target fork chain' {
            Mock Get-ForkChainInfo {
                @{
                    Current = @{ Owner = 'testuser'; Repo = 'AitherZero' }
                    Upstream = $null  # No upstream
                    Root = $null
                    Chain = @('testuser/AitherZero')
                }
            } -ModuleName $script:ModuleName
            
            { New-CrossForkPR -Description "Invalid chain" -BranchName "test-branch" -TargetFork "upstream" } | Should -Throw "*upstream repository*not found*"
        }
    }
    
    Context 'URL Extraction and Return Values' {
        It 'Should extract PR number from URL' {
            Mock gh { 'https://github.com/AitherLabs/AitherZero/pull/789' } -ModuleName $script:ModuleName
            
            $result = New-CrossForkPR -Description "URL extraction" -BranchName "test-branch" -TargetFork "upstream"
            
            $result.PRNumber | Should -Be 789
            $result.PRUrl | Should -Be 'https://github.com/AitherLabs/AitherZero/pull/789'
        }
        
        It 'Should return comprehensive result object' {
            $result = New-CrossForkPR -Description "Result test" -BranchName "test-branch" -TargetFork "upstream" -DryRun
            
            $result | Should -HaveProperty 'Success'
            $result | Should -HaveProperty 'TargetFork'
            $result | Should -HaveProperty 'TargetRepository'
            $result | Should -HaveProperty 'CrossFork'
            $result | Should -HaveProperty 'Direction'
            $result | Should -HaveProperty 'BranchName'
        }
        
        It 'Should indicate success for successful cross-fork PR' {
            $result = New-CrossForkPR -Description "Success test" -BranchName "test-branch" -TargetFork "upstream"
            
            $result.Success | Should -Be $true
            $result.CrossFork | Should -Be $true
        }
    }
    
    Context 'Logging and Progress' {
        It 'Should log cross-fork PR creation process' {
            New-CrossForkPR -Description "Logging test" -BranchName "test-branch" -TargetFork "upstream"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Creating cross-fork PR" -and $Level -eq 'INFO'
            }
        }
        
        It 'Should log target repository information' {
            New-CrossForkPR -Description "Target logging" -BranchName "test-branch" -TargetFork "root"
            
            Should -Invoke Write-CustomLog -ModuleName $script:ModuleName -ParameterFilter {
                $Message -match "Target repository: Aitherium/AitherZero" -and $Level -eq 'INFO'
            }
        }
    }
}