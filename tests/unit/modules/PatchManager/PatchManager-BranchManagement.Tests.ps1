BeforeAll {
    # Import Logging module first
    $projectRoot = $env:PROJECT_ROOT
    $loggingPath = Join-Path $projectRoot "$env:PWSH_MODULES_PATH/Logging"
    
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
    $patchManagerPath = Join-Path $projectRoot "$env:PWSH_MODULES_PATH/PatchManager"
    
    try {
        Import-Module $patchManagerPath -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to import PatchManager module: $_"
        throw
    }
    
    # Mock functions for testing
    function global:Write-CustomLog {
        param([string]$Message, [string]$Level = "INFO")
        Write-Host "[$Level] $Message"
    }
    
    # Mock git to simulate various branch scenarios
    function global:git {
        param()
        $gitArgs = $args
        $script:gitCalls += , $gitArgs
        
        switch -Regex ($gitArgs -join " ") {
            "^branch -r$" {
                return @(
                    "  origin/main",
                    "  origin/feature/active-work",
                    "  origin/hotfix/old-fix-123",
                    "  origin/feature/merged-feature",
                    "  origin/release/v1.0.0"
                )
            }
            "^branch -r --merged" {
                return @(
                    "  origin/hotfix/old-fix-123",
                    "  origin/feature/merged-feature"
                )
            }
            "^log.*--format.*--since" {
                $branchName = $gitArgs[-1]
                if ($branchName -like "*old-fix*" -or $branchName -like "*merged-feature*") {
                    return "" # No recent commits
                } else {
                    return "abc123 Recent commit" # Has recent commits
                }
            }
            "^push.*--delete" {
                $deleteIndex = [Array]::IndexOf($gitArgs, "--delete")
                if ($deleteIndex -ne -1 -and $deleteIndex + 1 -lt $gitArgs.Count) {
                    $branchToDelete = $gitArgs[$deleteIndex + 1]
                    $script:deletedBranches += $branchToDelete
                    return "Deleted remote branch $branchToDelete"
                }
            }
            "^branch -D" {
                $branchToDelete = $gitArgs[2]
                $script:deletedLocalBranches += $branchToDelete
                return "Deleted local branch $branchToDelete"
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
        
        if ($ghArgs[0] -eq "pr" -and $ghArgs[1] -eq "list") {
            # Return empty array for merged PRs associated with branches
            return "[]"
        }
        
        $global:LASTEXITCODE = 0
        return ""
    }
}

Describe "PatchManager Branch Management" {
    BeforeEach {
        $script:gitCalls = @()
        $script:deletedBranches = @()
        $script:deletedLocalBranches = @()
    }
    
    Context "Get-IntelligentBranchStrategy" {
        It "Should create strategy for new patch" {
            $result = Get-IntelligentBranchStrategy -PatchDescription "fix: resolve issue with module loading"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.CurrentBranch | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle force new branch parameter" {
            $result = Get-IntelligentBranchStrategy -PatchDescription "feat: add new feature" -ForceNewBranch
            
            $result.SkipBranchCreation | Should -Be $false
        }
        
        It "Should detect protected branches" {
            $result = Get-IntelligentBranchStrategy -PatchDescription "fix: test" -CurrentBranch "main"
            
            # Should not skip branch creation when on protected branch
            $result.SkipBranchCreation | Should -Be $false
        }
    }
    
    Context "Test-BranchProtection" {
        It "Should identify protected branches" {
            Test-BranchProtection -BranchName "main" | Should -Be $true
            Test-BranchProtection -BranchName "master" | Should -Be $true
            Test-BranchProtection -BranchName "develop" | Should -Be $true
        }
        
        It "Should allow feature branches" {
            Test-BranchProtection -BranchName "feature/new-feature" | Should -Be $false
            Test-BranchProtection -BranchName "hotfix/bug-123" | Should -Be $false
        }
          It "Should handle custom protected patterns" {
            $customPatterns = @("release/*", "prod/*")
            Test-BranchProtection -BranchName "release/v1.0.0" -ProtectedBranches $customPatterns | Should -Be $true
            Test-BranchProtection -BranchName "prod/staging" -ProtectedBranches $customPatterns | Should -Be $true
        }
    }
    
    Context "Get-SanitizedBranchName" {
        It "Should sanitize branch names properly" {
            $result = Get-SanitizedBranchName -Description "Fix: Resolve Issue #123 with special chars!"
            
            $result | Should -Not -Match "[^a-zA-Z0-9\-/]"
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should include timestamp by default" {
            $result = Get-SanitizedBranchName -Description "test fix"
            
            $result | Should -Match "\d{8}-\d{6}"
        }
        
        It "Should exclude timestamp when requested" {
            $result = Get-SanitizedBranchName -Description "test fix" -IncludeTimestamp:$false
            
            $result | Should -Not -Match "\d{8}-\d{6}"
        }
        
        It "Should use custom prefix" {
            $result = Get-SanitizedBranchName -Description "test fix" -Prefix "hotfix"
            
            $result | Should -Match "^hotfix/"
        }
    }
}
