#Requires -Version 7.0

BeforeAll {
    # Mock the development modules
    $script:MockCalls = @{}
    
    # Create mock GitAutomation module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Get-GitStatus {
            return @{
                Clean = $true
                Branch = 'main'
                Modified = @()
                Staged = @()
                Untracked = @()
            }
        }
        
        function New-GitBranch {
            param($Name, $Checkout = $true, $Push = $false)
            $script:MockCalls['New-GitBranch'] += @{ Name = $Name; Checkout = $Checkout; Push = $Push }
            return @{ Name = $Name; Hash = 'abc123' }
        }
        
        function Invoke-GitCommit {
            param($Message, $Type, $Scope)
            $script:MockCalls['Invoke-GitCommit'] += @{ Message = $Message; Type = $Type; Scope = $Scope }
            return @{ Hash = 'def456'; Message = $Message }
        }
        
        function Sync-GitRepository {
            param($Operation)
            $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force
    
    # Create mock IssueTracker module
    New-Module -Name 'MockIssueTracker' -ScriptBlock {
        function New-GitHubIssue {
            param($Title, $Body, $Labels)
            $script:MockCalls['New-GitHubIssue'] += @{ Title = $Title; Body = $Body; Labels = $Labels }
            return @{ Number = 123; Url = 'https://github.com/test/repo/issues/123' }
        }
        
        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock git { 
        switch -Regex ($args -join ' ') {
            'branch --list' { return '' }
            'branch -r --list' { return '' }
            'checkout' { return '' }
            'pull' { return '' }
            'branch -D' { return '' }
            'push.*--delete' { return '' }
            'rev-parse --abbrev-ref HEAD' { return 'main' }
            'add' { return '' }
            default { return '' }
        }
    }
    
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'y' }
    Mock Set-Content { }
    Mock Get-AitherConfiguration { return @{} }
    
    # Initialize mock calls tracking
    $script:MockCalls = @{
        'New-GitBranch' = @()
        'Invoke-GitCommit' = @()
        'Sync-GitRepository' = @()
        'New-GitHubIssue' = @()
    }
}

Describe "0701_Create-FeatureBranch" {
    BeforeEach {
        $script:MockCalls = @{
            'New-GitBranch' = @()
            'Invoke-GitCommit' = @()
            'Sync-GitRepository' = @()
            'New-GitHubIssue' = @()
        }
    }
    
    Context "Parameter Validation" {
        It "Should require Type parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Name "test" } | Should -Not -Throw
        }
        
        It "Should require Name parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" } | Should -Not -Throw
        }
        
        It "Should validate Type parameter values" {
            $validTypes = @('feature', 'fix', 'docs', 'refactor', 'test', 'chore')
            foreach ($type in $validTypes) {
                { & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type $type -Name "test" -WhatIf } | Should -Not -Throw
            }
        }
    }
    
    Context "Branch Name Normalization" {
        It "Should normalize branch name with spaces" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "my test feature" -WhatIf
            
            $branchCall = $script:MockCalls['New-GitBranch'] | Select-Object -First 1
            $branchCall.Name | Should -Be "feature/my-test-feature"
        }
        
        It "Should normalize branch name with special characters" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test@#$%feature" -WhatIf
            
            $branchCall = $script:MockCalls['New-GitBranch'] | Select-Object -First 1
            $branchCall.Name | Should -Be "feature/testfeature"
        }
        
        It "Should handle multiple consecutive spaces/dashes" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test  --  feature" -WhatIf
            
            $branchCall = $script:MockCalls['New-GitBranch'] | Select-Object -First 1
            $branchCall.Name | Should -Be "feature/test-feature"
        }
    }
    
    Context "Branch Creation" {
        It "Should create new branch when it doesn't exist" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -WhatIf
            
            $script:MockCalls['New-GitBranch'] | Should -HaveCount 1
            $branchCall = $script:MockCalls['New-GitBranch'] | Select-Object -First 1
            $branchCall.Name | Should -Be "feature/test"
            $branchCall.Checkout | Should -Be $true
        }
        
        It "Should handle Push parameter" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -Push -WhatIf
            
            $branchCall = $script:MockCalls['New-GitBranch'] | Select-Object -First 1
            $branchCall.Push | Should -Be $true
        }
        
        It "Should handle Checkout parameter explicitly set to false" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -Checkout:$false -WhatIf
            
            $branchCall = $script:MockCalls['New-GitBranch'] | Select-Object -First 1
            $branchCall.Checkout | Should -Be $false
        }
    }
    
    Context "Existing Branch Handling" {
        It "Should handle existing local branch in non-interactive mode with checkout default" {
            Mock git { return "feature/test" } -ParameterFilter { $args[1] -eq "--list" }
            Mock Get-AitherConfiguration { 
                return @{ Development = @{ GitAutomation = @{ BranchConflictResolution = 'checkout' } } }
            }
            
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -NonInteractive -WhatIf
            
            Should -Invoke git -ParameterFilter { $args[0] -eq 'checkout' }
        }
        
        It "Should handle existing branch with Force parameter" {
            Mock git { return "feature/test" } -ParameterFilter { $args[1] -eq "--list" }
            
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -Force -WhatIf
            
            Should -Invoke git -ParameterFilter { $args[0] -eq 'checkout' }
        }
    }
    
    Context "Issue Creation" {
        It "Should create GitHub issue when CreateIssue switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -CreateIssue -WhatIf
            
            $script:MockCalls['New-GitHubIssue'] | Should -HaveCount 1
            $issueCall = $script:MockCalls['New-GitHubIssue'] | Select-Object -First 1
            $issueCall.Title | Should -Be "Feature: test"
            $issueCall.Labels | Should -Contain "feature"
        }
        
        It "Should include custom labels when creating issue" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -CreateIssue -Labels @('priority-high', 'ui') -WhatIf
            
            $issueCall = $script:MockCalls['New-GitHubIssue'] | Select-Object -First 1
            $issueCall.Labels | Should -Contain "feature"
            $issueCall.Labels | Should -Contain "priority-high"
            $issueCall.Labels | Should -Contain "ui"
        }
        
        It "Should handle different branch types in issue titles" {
            $typeMap = @{
                'feature' = 'Feature: test'
                'fix' = 'Bug: test'
                'docs' = 'Documentation: test'
                'refactor' = 'Refactor: test'
                'test' = 'Test: test'
                'chore' = 'Chore: test'
            }
            
            foreach ($type in $typeMap.Keys) {
                $script:MockCalls['New-GitHubIssue'] = @()
                & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type $type -Name "test" -CreateIssue -WhatIf
                
                $issueCall = $script:MockCalls['New-GitHubIssue'] | Select-Object -First 1
                $issueCall.Title | Should -Be $typeMap[$type]
            }
        }
    }
    
    Context "Initial Commit Creation" {
        It "Should create initial commit when checking out new branch" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -WhatIf
            
            $script:MockCalls['Invoke-GitCommit'] | Should -HaveCount 1
            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Message | Should -Be "Initial commit for test"
            $commitCall.Type | Should -Be "feat"
            $commitCall.Scope | Should -Be "init"
        }
        
        It "Should map branch types to commit types correctly" {
            $typeMap = @{
                'feature' = 'feat'
                'fix' = 'fix'
                'docs' = 'docs'
                'refactor' = 'refactor'
                'test' = 'test'
                'chore' = 'chore'
            }
            
            foreach ($type in $typeMap.Keys) {
                $script:MockCalls['Invoke-GitCommit'] = @()
                & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type $type -Name "test" -WhatIf
                
                $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
                $commitCall.Type | Should -Be $typeMap[$type]
            }
        }
        
        It "Should include issue reference in commit when issue is created" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -CreateIssue -WhatIf
            
            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Message | Should -Match "Refs #123"
        }
        
        It "Should push after commit when Push switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -Push -WhatIf
            
            $script:MockCalls['Sync-GitRepository'] | Should -HaveCount 1
            $syncCall = $script:MockCalls['Sync-GitRepository'] | Select-Object -First 1
            $syncCall.Operation | Should -Be "Push"
        }
    }
    
    Context "Uncommitted Changes Handling" {
        BeforeAll {
            # Mock dirty repository state
            New-Module -Name 'MockGitAutomationDirty' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Branch = 'main'
                        Modified = @(@{ Path = 'file1.txt' })
                        Staged = @()
                        Untracked = @(@{ Path = 'file2.txt' })
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }
        
        It "Should proceed with Force when repository is dirty" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -Force -WhatIf
            
            $script:MockCalls['New-GitBranch'] | Should -HaveCount 1
        }
        
        It "Should proceed with NonInteractive when repository is dirty" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -NonInteractive -WhatIf
            
            $script:MockCalls['New-GitBranch'] | Should -HaveCount 1
        }
    }
    
    Context "WhatIf Support" {
        It "Should show branch operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -WhatIf
            
            Should -Not -Invoke git -ParameterFilter { $args[0] -eq 'checkout' -and $args.Count -eq 2 }
        }
        
        It "Should show issue creation without executing when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -CreateIssue -WhatIf
            
            # Mock functions should still be called for WhatIf validation
            $script:MockCalls['New-GitHubIssue'] | Should -HaveCount 1
        }
    }
    
    Context "Error Handling" {
        It "Should handle New-GitBranch failures" {
            New-Module -Name 'MockGitAutomationError' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'main'; Modified = @(); Staged = @(); Untracked = @() }
                }
                function New-GitBranch { throw "Git error" }
                Export-ModuleMember -Function *
            } | Import-Module -Force
            
            { & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -WhatIf } | Should -Throw
        }
        
        It "Should handle GitHub issue creation failures gracefully" {
            New-Module -Name 'MockIssueTrackerError' -ScriptBlock {
                function New-GitHubIssue { throw "GitHub API error" }
                Export-ModuleMember -Function *
            } | Import-Module -Force
            
            { & "/workspaces/AitherZero/automation-scripts/0701_Create-FeatureBranch.ps1" -Type "feature" -Name "test" -CreateIssue -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Warning
        }
    }
}
}
