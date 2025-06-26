#Requires -Version 7.0

BeforeAll {
    # Directly source the function file to test individual functions
    $projectRoot = $env:PROJECT_ROOT
    $functionPath = Join-Path $projectRoot "$env:PWSH_MODULES_PATH/PatchManager/Public/BranchStrategy.ps1"
    . $functionPath
}

Describe "BranchStrategy Module" {
    Context "Syntax Validation" {
        It "Should have valid PowerShell syntax" {
            $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $functionPath = Join-Path $projectRoot "$env:PWSH_MODULES_PATH/PatchManager/Public/BranchStrategy.ps1"
            
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($functionPath, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
    
    Context "Get-SanitizedBranchName Function" {
        It "Should sanitize branch names correctly" {
            $result = Get-SanitizedBranchName -Description "Fix syntax errors!"
            $result | Should -Match "^patch/\d{8}-\d{6}-fix-syntax-errors$"
        }
        
        It "Should handle custom prefix" {
            $result = Get-SanitizedBranchName -Description "test fix" -Prefix "hotfix"
            $result | Should -Match "^hotfix/\d{8}-\d{6}-test-fix$"
        }
        
        It "Should handle no timestamp when specified" {
            $result = Get-SanitizedBranchName -Description "test fix" -IncludeTimestamp:$false
            $result | Should -Be "patch/test-fix"
        }
        
        It "Should truncate long descriptions" {
            $longDesc = "a" * 50
            $result = Get-SanitizedBranchName -Description $longDesc -IncludeTimestamp:$false
            $result | Should -Be "patch/$("a" * 40)"
        }
    }
    
    Context "Test-BranchProtection Function" {
        It "Should protect main branches" {
            Test-BranchProtection -BranchName "main" | Should -BeTrue
            Test-BranchProtection -BranchName "master" | Should -BeTrue
            Test-BranchProtection -BranchName "develop" | Should -BeTrue
        }
        
        It "Should allow feature branches" {
            Test-BranchProtection -BranchName "feature/new-feature" | Should -BeFalse
            Test-BranchProtection -BranchName "patch/fix-something" | Should -BeFalse
        }
    }
      Context "Get-IntelligentBranchStrategy Function" {
        It "Should generate appropriate branch name for bug fixes" {
            $result = Get-IntelligentBranchStrategy -PatchDescription "Fix critical bug in parser" -ForceNewBranch
            $result.Success | Should -BeTrue
            $result.NewBranchName | Should -Match "^patch/\d{8}-\d{6}-Fix-critical-bug-in-parser$"
        }
        
        It "Should generate appropriate branch name for features" {
            $result = Get-IntelligentBranchStrategy -PatchDescription "Add new validation feature" -ForceNewBranch
            $result.Success | Should -BeTrue
            $result.NewBranchName | Should -Match "^patch/\d{8}-\d{6}-Add-new-validation-feature$"
        }
        
        It "Should skip branch creation when already on feature branch" {
            $result = Get-IntelligentBranchStrategy -PatchDescription "Test patch" -CurrentBranch "feature/existing-branch"
            $result.Success | Should -BeTrue
            $result.SkipBranchCreation | Should -BeTrue
            $result.NewBranchName | Should -Be "feature/existing-branch"
        }
    }
}
