BeforeDiscovery {
    $script:PatchManagerModulePath = Join-Path $PSScriptRoot '../../aither-core/modules/PatchManager'
    $script:TestAppName = 'PatchManager'
    
    # Verify the PatchManager module exists
    if (-not (Test-Path $script:PatchManagerModulePath)) {
        throw "PatchManager module not found at: $script:PatchManagerModulePath"
    }
}

Describe 'Git Workflow Integration - Critical Infrastructure Testing' -Tags @('Critical', 'Infrastructure', 'Git', 'Integration') {
    
    BeforeAll {
        # Import test utilities
        . "$PSScriptRoot/../Shared/Test-Utilities.ps1"
        
        # Set up isolated test environment
        $script:TestWorkspace = New-TestWorkspace -TestName 'git-integration-tests'
        
        # Save original environment
        $script:OriginalProjectRoot = $env:PROJECT_ROOT
        $script:OriginalUserProfile = $env:USERPROFILE
        $script:OriginalHome = $env:HOME
        $script:OriginalGitUser = $env:GIT_AUTHOR_NAME
        $script:OriginalGitEmail = $env:GIT_AUTHOR_EMAIL
        
        # Create test directory structure
        $script:TestProjectRoot = Join-Path $script:TestWorkspace 'AitherZero'
        $script:TestModulesDir = Join-Path $script:TestProjectRoot 'aither-core' 'modules'
        $script:TestSharedDir = Join-Path $script:TestProjectRoot 'aither-core' 'shared'
        $script:TestConfigsDir = Join-Path $script:TestProjectRoot 'configs'
        $script:TestOpenTofuDir = Join-Path $script:TestProjectRoot 'opentofu'
        $script:TestGitDir = Join-Path $script:TestProjectRoot '.git'
        
        @($script:TestProjectRoot, $script:TestModulesDir, $script:TestSharedDir,
          $script:TestConfigsDir, $script:TestOpenTofuDir) | ForEach-Object {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
        
        # Set test environment variables
        $env:PROJECT_ROOT = $script:TestProjectRoot
        $env:USERPROFILE = $script:TestWorkspace
        $env:HOME = $script:TestWorkspace
        $env:GIT_AUTHOR_NAME = 'Test User'
        $env:GIT_AUTHOR_EMAIL = 'test@example.com'
        
        # Initialize test Git repository
        Push-Location $script:TestProjectRoot
        git init 2>&1 | Out-Null
        git config user.name 'Test User'
        git config user.email 'test@example.com'
        git config init.defaultBranch main
        
        # Create initial commit
        'Initial commit' | Out-File -FilePath (Join-Path $script:TestProjectRoot 'README.md') -Encoding UTF8
        git add . 2>&1 | Out-Null
        git commit -m "Initial commit" 2>&1 | Out-Null
        
        # Add mock remotes for different repository types
        git remote add origin https://github.com/wizzense/AitherZero.git 2>&1 | Out-Null
        git remote add upstream https://github.com/Aitherium/AitherLabs.git 2>&1 | Out-Null
        git remote add root https://github.com/Aitherium/Aitherium.git 2>&1 | Out-Null
        Pop-Location
        
        # Create Find-ProjectRoot utility
        $findProjectRootContent = @"
function Find-ProjectRoot {
    param([string]`$StartPath, [switch]`$Force)
    return '$script:TestProjectRoot'
}
"@
        $findProjectRootPath = Join-Path $script:TestSharedDir 'Find-ProjectRoot.ps1'
        $findProjectRootContent | Out-File -FilePath $findProjectRootPath -Encoding UTF8
        
        # Copy PatchManager module to test environment
        $testPatchManagerModulePath = Join-Path $script:TestModulesDir 'PatchManager'
        Copy-Item -Path "$script:PatchManagerModulePath\*" -Destination $testPatchManagerModulePath -Recurse -Force
        
        # Create mock Logging module
        $testLoggingModulePath = Join-Path $script:TestModulesDir 'Logging'
        New-Item -ItemType Directory -Path $testLoggingModulePath -Force | Out-Null
        @'
function Write-CustomLog {
    param([string]$Level, [string]$Message)
    Write-Host "[$Level] $Message"
}
Export-ModuleMember -Function Write-CustomLog
'@ | Out-File -FilePath (Join-Path $testLoggingModulePath 'Logging.psm1') -Encoding UTF8
        
        # Mock Git commands for controlled testing
        $script:MockGitCommands = @{}
        $script:MockGitBranches = @('main', 'develop', 'patch/test-branch')
        $script:MockGitRemoteBranches = @('origin/main', 'origin/develop', 'upstream/main')
        $script:MockGitTags = @('v1.0.0', 'v1.1.0', 'v1.2.0')
        $script:MockGitStatus = ''
        $script:MockGitDivergence = @{ Ahead = 0; Behind = 0 }
        
        Mock git {
            param($Command)
            
            $script:MockGitCommands[$Command] = $args
            
            switch ($Command) {
                'remote' {
                    if ($args[0] -eq '-v') {
                        return @(
                            'origin	https://github.com/wizzense/AitherZero.git (fetch)',
                            'origin	https://github.com/wizzense/AitherZero.git (push)',
                            'upstream	https://github.com/Aitherium/AitherLabs.git (fetch)',
                            'upstream	https://github.com/Aitherium/AitherLabs.git (push)'
                        )
                    }
                    return ''
                }
                'branch' {
                    if ($args[0] -eq '--show-current') {
                        return 'main'
                    }
                    if ($args[0] -eq '--format="%(refname:short)"') {
                        return $script:MockGitBranches
                    }
                    if ($args[0] -eq '-r' -and $args[1] -eq '--format="%(refname:short)"') {
                        return $script:MockGitRemoteBranches
                    }
                    return $script:MockGitBranches -join "`n"
                }
                'fetch' {
                    return 'Fetching origin...'
                }
                'rev-parse' {
                    return 'abc123def456'  # Mock commit hash
                }
                'rev-list' {
                    if ($args -contains '--count') {
                        if ($args -like '*origin/main..main*') {
                            return $script:MockGitDivergence.Ahead.ToString()
                        }
                        if ($args -like '*main..origin/main*') {
                            return $script:MockGitDivergence.Behind.ToString()
                        }
                    }
                    return '0'
                }
                'status' {
                    if ($args[0] -eq '--porcelain') {
                        return $script:MockGitStatus
                    }
                    return 'On branch main'
                }
                'ls-remote' {
                    if ($args -contains '--heads') {
                        return 'abc123	refs/heads/main'
                    }
                    if ($args -contains '--tags') {
                        return $script:MockGitTags | ForEach-Object { "def456	refs/tags/$_" }
                    }
                    return ''
                }
                'tag' {
                    if ($args[0] -eq '-l') {
                        return $script:MockGitTags
                    }
                    return ''
                }
                'show-ref' {
                    if ($args[0] -eq '--tags') {
                        return $script:MockGitTags | ForEach-Object { "def456 refs/tags/$_" }
                    }
                    return ''
                }
                'log' {
                    if ($args -contains '--oneline') {
                        return 'abc123 Test commit message'
                    }
                    return ''
                }
                'add' {
                    return ''
                }
                'commit' {
                    return 'Committed successfully'
                }
                'push' {
                    return 'Pushed to origin'
                }
                'pull' {
                    return 'Already up to date'
                }
                'reset' {
                    return 'Reset to origin/main'
                }
                'stash' {
                    return 'Stashed changes'
                }
                default {
                    return ''
                }
            }
        } -ModuleName $script:TestAppName
        
        # Mock GitHub CLI
        Mock gh {
            param($Command)
            
            switch ($Command) {
                'auth' {
                    if ($args[0] -eq 'status') {
                        return 'Logged in to github.com as test-user'
                    }
                    return ''
                }
                'pr' {
                    if ($args[0] -eq 'create') {
                        return 'https://github.com/wizzense/AitherZero/pull/123'
                    }
                    if ($args[0] -eq 'list') {
                        return ''
                    }
                    return ''
                }
                'issue' {
                    if ($args[0] -eq 'create') {
                        return 'https://github.com/wizzense/AitherZero/issues/456'
                    }
                    return ''
                }
                'label' {
                    if ($args[0] -eq 'list') {
                        return 'patch	Auto-created by PatchManager'
                    }
                    return ''
                }
                default {
                    return ''
                }
            }
        } -ModuleName $script:TestAppName
        
        # Mock external tools
        Mock Get-Command { 
            param($Name)
            if ($Name -in @('git', 'gh')) {
                return @{ Name = $Name }
            }
            return $null
        } -ModuleName $script:TestAppName
        
        # Mock Write-Host to capture output
        Mock Write-Host { } -ModuleName $script:TestAppName
        
        # Import PatchManager module from test location
        Import-Module $testPatchManagerModulePath -Force -Global
        
        # Create test files for Git operations
        $testFiles = @(
            'aither-core/modules/TestModule/TestModule.psm1',
            'configs/test-config.json',
            'opentofu/main.tf',
            'Start-AitherZero.ps1'
        )
        
        foreach ($file in $testFiles) {
            $filePath = Join-Path $script:TestProjectRoot $file
            $fileDir = Split-Path $filePath -Parent
            New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
            "Test content for $file" | Out-File -FilePath $filePath -Encoding UTF8
        }
    }
    
    AfterAll {
        # Restore original environment
        $env:PROJECT_ROOT = $script:OriginalProjectRoot
        $env:USERPROFILE = $script:OriginalUserProfile
        $env:HOME = $script:OriginalHome
        $env:GIT_AUTHOR_NAME = $script:OriginalGitUser
        $env:GIT_AUTHOR_EMAIL = $script:OriginalGitEmail
        
        # Remove imported modules
        Remove-Module PatchManager -Force -ErrorAction SilentlyContinue
        Remove-Module Logging -Force -ErrorAction SilentlyContinue
        
        # Clean up test workspace
        if ($script:TestWorkspace -and (Test-Path $script:TestWorkspace)) {
            Remove-Item -Path $script:TestWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    BeforeEach {
        # Reset mock state
        $script:MockGitCommands.Clear()
        $script:MockGitStatus = ''
        $script:MockGitDivergence = @{ Ahead = 0; Behind = 0 }
        
        # Ensure we're in the test project directory
        Set-Location $script:TestProjectRoot
    }
    
    Context 'Repository Detection and Configuration' {
        
        It 'Should detect AitherZero development repository correctly' {
            { $repoInfo = Get-GitRepositoryInfo } | Should -Not -Throw
            
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo | Should -Not -BeNullOrEmpty
            $repoInfo.Owner | Should -Be 'wizzense'
            $repoInfo.Name | Should -Be 'AitherZero'
            $repoInfo.FullName | Should -Be 'wizzense/AitherZero'
            $repoInfo.Type | Should -Be 'Development'
            $repoInfo.GitHubRepo | Should -Be 'wizzense/AitherZero'
            $repoInfo.CurrentBranch | Should -Be 'main'
        }
        
        It 'Should detect fork chain correctly' {
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.ForkChain | Should -Not -BeNullOrEmpty
            $repoInfo.ForkChain.Count | Should -BeGreaterOrEqual 1
            
            $origin = $repoInfo.ForkChain | Where-Object { $_.Name -eq 'origin' }
            $origin | Should -Not -BeNullOrEmpty
            $origin.Owner | Should -Be 'wizzense'
            $origin.Repo | Should -Be 'AitherZero'
            $origin.Type | Should -Be 'Development'
        }
        
        It 'Should handle repository remotes correctly' {
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.Remotes | Should -Not -BeNullOrEmpty
            $repoInfo.Remotes.origin | Should -Be 'https://github.com/wizzense/AitherZero.git'
            $repoInfo.Remotes.upstream | Should -Be 'https://github.com/Aitherium/AitherLabs.git'
        }
        
        It 'Should handle different repository types across fork chain' {
            # Test AitherLabs repository detection
            Mock git { 
                if ($args[0] -eq 'remote' -and $args[1] -eq '-v') {
                    return @(
                        'origin	https://github.com/Aitherium/AitherLabs.git (fetch)',
                        'origin	https://github.com/Aitherium/AitherLabs.git (push)',
                        'upstream	https://github.com/Aitherium/Aitherium.git (fetch)',
                        'upstream	https://github.com/Aitherium/Aitherium.git (push)'
                    )
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.Type | Should -Be 'Public'
            $repoInfo.Owner | Should -Be 'Aitherium'
            $repoInfo.Name | Should -Be 'AitherLabs'
        }
        
        It 'Should fallback gracefully when Git info unavailable' {
            # Mock Git commands to fail
            Mock git { throw "Not a git repository" } -ModuleName $script:TestAppName
            
            { $repoInfo = Get-GitRepositoryInfo } | Should -Not -Throw
            
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.Owner | Should -Be 'wizzense'
            $repoInfo.Name | Should -Be 'AitherZero'
            $repoInfo.Type | Should -Be 'Development'
        }
        
        It 'Should handle missing remote configuration' {
            Mock git {
                if ($args[0] -eq 'remote' -and $args[1] -eq '-v') {
                    return ''
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            { Get-GitRepositoryInfo } | Should -Throw -ExpectedMessage "*No origin remote found*"
        }
    }
    
    Context 'Branch Synchronization and Management' {
        
        It 'Should synchronize up-to-date branch successfully' {
            # Mock branch is up to date
            $script:MockGitDivergence = @{ Ahead = 0; Behind = 0 }
            
            { $result = Sync-GitBranch -BranchName 'main' } | Should -Not -Throw
            
            $result = Sync-GitBranch -BranchName 'main'
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Branch | Should -Be 'main'
            $result.Message | Should -Be 'Synchronization completed successfully'
        }
        
        It 'Should handle branch ahead of remote' {
            # Mock branch ahead of remote
            $script:MockGitDivergence = @{ Ahead = 3; Behind = 0 }
            
            $result = Sync-GitBranch -BranchName 'main'
            $result.Success | Should -Be $true
        }
        
        It 'Should handle branch behind remote' {
            # Mock branch behind remote
            $script:MockGitDivergence = @{ Ahead = 0; Behind = 2 }
            
            $result = Sync-GitBranch -BranchName 'main'
            $result.Success | Should -Be $true
        }
        
        It 'Should handle diverged branches with force reset' {
            # Mock diverged branch
            $script:MockGitDivergence = @{ Ahead = 2; Behind = 3 }
            
            { $result = Sync-GitBranch -BranchName 'main' -Force } | Should -Not -Throw
            
            $result = Sync-GitBranch -BranchName 'main' -Force
            $result.Success | Should -Be $true
            
            # Verify reset command was called
            $script:MockGitCommands['reset'] | Should -Not -BeNullOrEmpty
        }
        
        It 'Should stash and restore uncommitted changes during reset' {
            # Mock uncommitted changes and diverged branch
            $script:MockGitStatus = 'M file1.ps1'
            $script:MockGitDivergence = @{ Ahead = 1; Behind = 1 }
            
            $result = Sync-GitBranch -BranchName 'main' -Force
            $result.Success | Should -Be $true
            
            # Verify stash commands were called
            $script:MockGitCommands['stash'] | Should -Not -BeNullOrEmpty
        }
        
        It 'Should cleanup orphaned branches when requested' {
            # Mock orphaned branches
            $script:MockGitBranches = @('main', 'old-feature', 'another-old-branch')
            $script:MockGitRemoteBranches = @('origin/main')  # Only main exists on remote
            
            { $result = Sync-GitBranch -CleanupOrphaned } | Should -Not -Throw
            
            $result = Sync-GitBranch -CleanupOrphaned
            $result.Success | Should -Be $true
        }
        
        It 'Should validate tags when requested' {
            { $result = Sync-GitBranch -ValidateTags } | Should -Not -Throw
            
            $result = Sync-GitBranch -ValidateTags
            $result.Success | Should -Be $true
        }
        
        It 'Should handle local-only branches' {
            # Mock branch that doesn't exist on remote
            Mock git {
                if ($args[0] -eq 'ls-remote' -and $args -contains '--heads') {
                    return ''  # No remote branch
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            $result = Sync-GitBranch -BranchName 'local-only-branch'
            $result.Success | Should -Be $true
            $result.LocalOnly | Should -Be $true
        }
        
        It 'Should use current branch when not specified' {
            $result = Sync-GitBranch
            $result.Success | Should -Be $true
            $result.Branch | Should -Be 'main'
        }
        
        It 'Should handle Git fetch failures' {
            # Mock fetch failure
            Mock git {
                if ($args[0] -eq 'fetch') {
                    $global:LASTEXITCODE = 1
                    throw "Fetch failed"
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            { Sync-GitBranch } | Should -Throw -ExpectedMessage "*Failed to fetch from remote*"
        }
    }
    
    Context 'Pull Request and Issue Creation' {
        
        It 'Should create pull request with comprehensive details' {
            $testDescription = 'Fix critical infrastructure issue'
            $testBranch = 'patch/fix-critical-issue'
            $testFiles = @('aither-core/modules/TestModule/TestModule.psm1')
            
            { $result = New-PatchPR -Description $testDescription -BranchName $testBranch -AffectedFiles $testFiles } | Should -Not -Throw
            
            $result = New-PatchPR -Description $testDescription -BranchName $testBranch -AffectedFiles $testFiles
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.PullRequestUrl | Should -Be 'https://github.com/wizzense/AitherZero/pull/123'
            $result.PullRequestNumber | Should -Be '123'
            $result.Title | Should -Be "Patch: $testDescription"
        }
        
        It 'Should create pull request with issue linking' {
            $testDescription = 'Fix module loading bug'
            $testBranch = 'patch/fix-loading'
            $testIssue = 456
            
            $result = New-PatchPR -Description $testDescription -BranchName $testBranch -IssueNumber $testIssue
            $result.Success | Should -Be $true
            $result.PullRequestUrl | Should -Contain 'github.com'
        }
        
        It 'Should handle dry run mode' {
            $result = New-PatchPR -Description 'Test patch' -BranchName 'patch/test' -DryRun
            $result.Success | Should -Be $true
            $result.DryRun | Should -Be $true
            $result.Title | Should -Be 'Patch: Test patch'
            $result.Body | Should -Not -BeNullOrEmpty
        }
        
        It 'Should commit pending changes before creating PR' {
            # Mock uncommitted changes
            $script:MockGitStatus = 'M file1.ps1'
            
            $result = New-PatchPR -Description 'Test commit' -BranchName 'patch/test-commit'
            $result.Success | Should -Be $true
            
            # Verify commit commands were called
            $script:MockGitCommands['add'] | Should -Not -BeNullOrEmpty
            $script:MockGitCommands['commit'] | Should -Not -BeNullOrEmpty
        }
        
        It 'Should push branch to remote before creating PR' {
            $result = New-PatchPR -Description 'Test push' -BranchName 'patch/test-push'
            $result.Success | Should -Be $true
            
            # Verify push command was called
            $script:MockGitCommands['push'] | Should -Not -BeNullOrEmpty
        }
        
        It 'Should handle existing pull request gracefully' {
            # Mock PR already exists
            Mock gh {
                if ($args[0] -eq 'pr' -and $args[1] -eq 'create') {
                    $global:LASTEXITCODE = 1
                    return 'already exists https://github.com/wizzense/AitherZero/pull/789'
                }
                return & $script:OriginalGh @args
            } -ModuleName $script:TestAppName
            
            $result = New-PatchPR -Description 'Existing PR test' -BranchName 'patch/existing'
            $result.Success | Should -Be $true
            $result.PullRequestUrl | Should -Be 'https://github.com/wizzense/AitherZero/pull/789'
            $result.Message | Should -Be 'Using existing pull request'
        }
        
        It 'Should handle GitHub CLI unavailability' {
            # Mock gh command not found
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'gh' } -ModuleName $script:TestAppName
            
            { New-PatchPR -Description 'No GH CLI' -BranchName 'patch/no-gh' } | Should -Throw -ExpectedMessage "*GitHub CLI (gh) not found*"
        }
        
        It 'Should handle repository detection failure' {
            # Mock repository detection failure
            Mock Get-GitRepositoryInfo { throw "No repository detected" } -ModuleName $script:TestAppName
            
            { New-PatchPR -Description 'No repo' -BranchName 'patch/no-repo' } | Should -Throw -ExpectedMessage "*Failed to detect repository information*"
        }
        
        It 'Should create patch label if missing' {
            # Mock missing label
            Mock gh {
                if ($args[0] -eq 'label' -and $args[1] -eq 'list') {
                    return ''  # No patch label
                }
                return & $script:OriginalGh @args
            } -ModuleName $script:TestAppName
            
            $result = New-PatchPR -Description 'Create label test' -BranchName 'patch/label-test'
            $result.Success | Should -Be $true
        }
        
        It 'Should handle push failures' {
            # Mock push failure
            Mock git {
                if ($args[0] -eq 'push') {
                    $global:LASTEXITCODE = 1
                    throw "Push failed"
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            { New-PatchPR -Description 'Push fail test' -BranchName 'patch/push-fail' } | Should -Throw -ExpectedMessage "*Failed to push branch*"
        }
    }
    
    Context 'Cross-Fork Repository Integration' {
        
        It 'Should handle AitherLabs public repository' {
            # Mock AitherLabs repository
            Mock git {
                if ($args[0] -eq 'remote' -and $args[1] -eq '-v') {
                    return @(
                        'origin	https://github.com/Aitherium/AitherLabs.git (fetch)',
                        'origin	https://github.com/Aitherium/AitherLabs.git (push)'
                    )
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.Type | Should -Be 'Public'
            $repoInfo.Owner | Should -Be 'Aitherium'
            $repoInfo.Name | Should -Be 'AitherLabs'
        }
        
        It 'Should handle Aitherium premium repository' {
            # Mock Aitherium repository
            Mock git {
                if ($args[0] -eq 'remote' -and $args[1] -eq '-v') {
                    return @(
                        'origin	https://github.com/Aitherium/Aitherium.git (fetch)',
                        'origin	https://github.com/Aitherium/Aitherium.git (push)'
                    )
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.Type | Should -Be 'Premium'
            $repoInfo.Owner | Should -Be 'Aitherium'
            $repoInfo.Name | Should -Be 'Aitherium'
        }
        
        It 'Should work across different repository contexts' {
            # Test that PatchManager functions work regardless of repository
            $repositories = @(
                @{ Owner = 'wizzense'; Name = 'AitherZero'; Type = 'Development' },
                @{ Owner = 'Aitherium'; Name = 'AitherLabs'; Type = 'Public' },
                @{ Owner = 'Aitherium'; Name = 'Aitherium'; Type = 'Premium' }
            )
            
            foreach ($repo in $repositories) {
                Mock git {
                    if ($args[0] -eq 'remote' -and $args[1] -eq '-v') {
                        $url = "https://github.com/$($repo.Owner)/$($repo.Name).git"
                        return @(
                            "origin	$url (fetch)",
                            "origin	$url (push)"
                        )
                    }
                    return & $script:OriginalGit @args
                } -ModuleName $script:TestAppName
                
                $repoInfo = Get-GitRepositoryInfo
                $repoInfo.Owner | Should -Be $repo.Owner
                $repoInfo.Name | Should -Be $repo.Name
                $repoInfo.Type | Should -Be $repo.Type
                
                # Verify PR creation would work
                $result = New-PatchPR -Description "Test for $($repo.Name)" -BranchName 'patch/cross-fork-test' -DryRun
                $result.Success | Should -Be $true
            }
        }
    }
    
    Context 'Integration with Infrastructure Deployment' {
        
        It 'Should detect infrastructure-related file changes' {
            $infraFiles = @(
                'opentofu/main.tf',
                'opentofu/variables.tf',
                'configs/infrastructure.json',
                'aither-core/modules/OpenTofuProvider/OpenTofuProvider.psm1'
            )
            
            foreach ($file in $infraFiles) {
                $filePath = Join-Path $script:TestProjectRoot $file
                $fileDir = Split-Path $filePath -Parent
                New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
                "Infrastructure config" | Out-File -FilePath $filePath -Encoding UTF8
            }
            
            $result = New-PatchPR -Description 'Infrastructure updates' -BranchName 'patch/infra-update' -AffectedFiles $infraFiles -DryRun
            $result.Success | Should -Be $true
            $result.Body | Should -Contain 'opentofu/main.tf'
            $result.Body | Should -Contain 'OpenTofuProvider'
        }
        
        It 'Should integrate with lab deployment workflows' {
            $labFiles = @(
                'aither-core/modules/LabRunner/LabRunner.psm1',
                'configs/lab-config.yaml',
                'opentofu/lab-infrastructure.tf'
            )
            
            $result = New-PatchPR -Description 'Lab deployment fixes' -BranchName 'patch/lab-fixes' -AffectedFiles $labFiles -DryRun
            $result.Success | Should -Be $true
            $result.Body | Should -Contain 'LabRunner'
            $result.Body | Should -Contain 'lab-config'
        }
        
        It 'Should handle configuration changes that affect Git workflows' {
            $configFiles = @(
                'configs/patch-manager-config.json',
                'configs/git-workflow.yaml',
                '.gitignore'
            )
            
            foreach ($file in $configFiles) {
                $filePath = Join-Path $script:TestProjectRoot $file
                "Config content" | Out-File -FilePath $filePath -Encoding UTF8
            }
            
            $result = New-PatchPR -Description 'Git workflow configuration' -BranchName 'patch/git-config' -AffectedFiles $configFiles -DryRun
            $result.Success | Should -Be $true
        }
    }
    
    Context 'Git Workflow Resilience and Error Handling' {
        
        It 'Should handle merge conflicts during sync' {
            # Mock merge conflict scenario
            Mock git {
                if ($args[0] -eq 'pull') {
                    $global:LASTEXITCODE = 1
                    throw "Merge conflict"
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            # Should handle gracefully
            $result = Sync-GitBranch -BranchName 'main'
            $result.Success | Should -Be $true
        }
        
        It 'Should handle network connectivity issues' {
            # Mock network failure
            Mock git {
                if ($args[0] -eq 'fetch') {
                    $global:LASTEXITCODE = 1
                    throw "Network error"
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            { Sync-GitBranch } | Should -Throw -ExpectedMessage "*Failed to fetch from remote*"
        }
        
        It 'Should handle authentication failures' {
            # Mock auth failure for GitHub CLI
            Mock gh {
                if ($args[0] -eq 'auth' -and $args[1] -eq 'status') {
                    $global:LASTEXITCODE = 1
                    throw "Not authenticated"
                }
                return & $script:OriginalGh @args
            } -ModuleName $script:TestAppName
            
            # Should detect and continue (authentication check is not blocking)
            $result = New-PatchPR -Description 'Auth test' -BranchName 'patch/auth-test' -DryRun
            $result.Success | Should -Be $true
        }
        
        It 'Should handle corrupted Git repository state' {
            # Mock corrupted repo
            Mock git {
                if ($args[0] -eq 'branch' -and $args[1] -eq '--show-current') {
                    throw "Corrupted repository"
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            # Repository detection should fallback gracefully
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo.CurrentBranch | Should -Be 'main'  # Fallback value
        }
        
        It 'Should handle disk space issues during operations' {
            # Mock disk space error
            Mock git {
                if ($args[0] -eq 'commit') {
                    $global:LASTEXITCODE = 1
                    throw "No space left on device"
                }
                return & $script:OriginalGit @args
            } -ModuleName $script:TestAppName
            
            # Should handle gracefully and continue
            $result = New-PatchPR -Description 'Disk space test' -BranchName 'patch/disk-test'
            # Should not crash completely
        }
        
        It 'Should validate Git repository integrity' {
            # This would be extended to check .git directory health
            Test-Path (Join-Path $script:TestProjectRoot '.git') | Should -Be $true
            
            # Repository info should work
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'Performance and Resource Management' {
        
        It 'Should complete branch sync within reasonable time' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Sync-GitBranch -BranchName 'main'
            $stopwatch.Stop()
            
            $result.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 10000  # Less than 10 seconds
        }
        
        It 'Should handle large repository operations efficiently' {
            # Mock large repository with many branches and tags
            $script:MockGitBranches = @()
            for ($i = 1; $i -le 100; $i++) {
                $script:MockGitBranches += "feature/branch-$i"
            }
            $script:MockGitTags = @()
            for ($i = 1; $i -le 50; $i++) {
                $script:MockGitTags += "v1.0.$i"
            }
            
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Sync-GitBranch -CleanupOrphaned -ValidateTags
            $stopwatch.Stop()
            
            $result.Success | Should -Be $true
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 15000  # Less than 15 seconds
        }
        
        It 'Should manage memory efficiently during Git operations' {
            # Get initial memory usage
            $initialMemory = [GC]::GetTotalMemory($false)
            
            # Perform multiple Git operations
            for ($i = 1; $i -le 10; $i++) {
                Sync-GitBranch -BranchName 'main'
                New-PatchPR -Description "Test $i" -BranchName "patch/test-$i" -DryRun
                Get-GitRepositoryInfo | Out-Null
            }
            
            # Force garbage collection
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            [GC]::Collect()
            
            $finalMemory = [GC]::GetTotalMemory($false)
            $memoryIncrease = $finalMemory - $initialMemory
            
            $memoryIncrease | Should -BeLessThan 25MB  # Memory increase should be reasonable
        }
        
        It 'Should handle concurrent Git operations safely' {
            # Test multiple simultaneous operations
            $jobs = @()
            for ($i = 1; $i -le 5; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($ModulePath, $ProjectRoot, $TestNumber)
                    
                    $env:PROJECT_ROOT = $ProjectRoot
                    Set-Location $ProjectRoot
                    Import-Module $ModulePath -Force
                    
                    # Perform Git operations
                    Get-GitRepositoryInfo | Out-Null
                    Sync-GitBranch -BranchName 'main'
                    New-PatchPR -Description "Concurrent test $TestNumber" -BranchName "patch/concurrent-$TestNumber" -DryRun
                } -ArgumentList $testPatchManagerModulePath, $script:TestProjectRoot, $i
            }
            
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            # All operations should complete successfully
            $results | Should -Not -BeNullOrEmpty
        }
    }
    
    Context 'End-to-End Git Workflow Integration' {
        
        It 'Should execute complete patch workflow with Git integration' {
            # Simulate complete workflow: sync -> changes -> commit -> PR
            
            # Step 1: Sync branch
            $syncResult = Sync-GitBranch -BranchName 'main'
            $syncResult.Success | Should -Be $true
            
            # Step 2: Create changes (mock)
            $script:MockGitStatus = 'M aither-core/modules/TestModule/TestModule.psm1'
            
            # Step 3: Create PR
            $prResult = New-PatchPR -Description 'End-to-end workflow test' -BranchName 'patch/e2e-test'
            $prResult.Success | Should -Be $true
            
            # Verify complete workflow
            $prResult.PullRequestUrl | Should -Not -BeNullOrEmpty
            $script:MockGitCommands['commit'] | Should -Not -BeNullOrEmpty
            $script:MockGitCommands['push'] | Should -Not -BeNullOrEmpty
        }
        
        It 'Should integrate with infrastructure deployment pipelines' {
            # Test integration with infrastructure changes
            $infraFiles = @(
                'opentofu/main.tf',
                'aither-core/modules/OpenTofuProvider/OpenTofuProvider.psm1'
            )
            
            # Create PR for infrastructure changes
            $result = New-PatchPR -Description 'Infrastructure pipeline integration' -BranchName 'patch/infra-pipeline' -AffectedFiles $infraFiles -DryRun
            $result.Success | Should -Be $true
            
            # Verify infrastructure-specific content in PR
            $result.Body | Should -Contain 'Infrastructure'
            $result.Body | Should -Contain 'Quality Assurance Checklist'
            $result.Body | Should -Contain 'Cross-Platform'
        }
        
        It 'Should validate complete Git workflow state' {
            # Verify repository state is clean after operations
            $repoInfo = Get-GitRepositoryInfo
            $repoInfo | Should -Not -BeNullOrEmpty
            
            # Verify no uncommitted changes after operations
            $script:MockGitStatus = ''  # Clean state
            $syncResult = Sync-GitBranch
            $syncResult.Success | Should -Be $true
            
            # Verify Git commands were executed properly
            $script:MockGitCommands.Keys | Should -Contain 'fetch'
            $script:MockGitCommands.Keys | Should -Contain 'branch'
        }
    }
}