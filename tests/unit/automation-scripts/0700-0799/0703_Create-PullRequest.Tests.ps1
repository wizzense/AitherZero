#Requires -Version 7.0

BeforeAll {
    # Mock the development modules
    $script:MockCalls = @{}

    # Create mock GitAutomation module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Get-GitStatus {
            return @{
                Clean = $true
                Branch = 'feature/test-feature'
                Ahead = 1
                UpstreamBranch = 'origin/feature/test-feature'
                Modified = @()
                Untracked = @()
            }
        }

        function Get-GitRepository {
            return @{
                Path = '/mock/repo'
                Branch = 'feature/test-feature'
                RemoteUrl = 'https://github.com/test/repo'
            }
        }

        function Test-GitHubCLI {
            # Mock GitHub CLI as available
        }

        function Sync-GitRepository {
            param($Operation)
            $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
        }

        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Create mock PullRequestManager module
    New-Module -Name 'MockPullRequestManager' -ScriptBlock {
        function New-PullRequest {
            param($Title, $Body, $Head, $Base, $Draft, $Reviewers, $Assignees, $Labels, $AutoMerge, $OpenInBrowser)
            $script:MockCalls['New-PullRequest'] += @{
                Title = $Title
                Body = $Body
                Head = $Head
                Base = $Base
                Draft = $Draft
                Reviewers = $Reviewers
                Assignees = $Assignees
                Labels = $Labels
                AutoMerge = $AutoMerge
                OpenInBrowser = $OpenInBrowser
            }
            return @{
                Number = 42
                Url = 'https://github.com/test/repo/pull/42'
            }
        }

        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Create mock IssueTracker module
    New-Module -Name 'MockIssueTracker' -ScriptBlock {
        function Add-GitHubIssueComment {
            param($Number, $Body)
            $script:MockCalls['Add-GitHubIssueComment'] += @{ Number = $Number; Body = $Body }
        }

        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock gh {
        switch -Regex ($arguments -join ' ') {
            'api user --jq' { return 'testuser' }
            default { return '' }
        }
    }

    Mock Test-Path { return $false }
    Mock Get-Content { return "## PR Template Content" }
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'y' }

    # Mock the analyze issues script
    Mock Invoke-Expression {
        return @{
            MatchedIssues = @(
                @{ Number = 123; Title = 'Related issue' }
            )
            PRBodySection = "`n## Related Issues`nCloses #123"
        }
    } -ParameterFilter { $Command -like "*0805_Analyze-OpenIssues.ps1*" }

    # Mock other automation scripts
    Mock Invoke-Expression { } -ParameterFilter { $Command -like "*0402_Run-UnitTests.ps1*" }
    Mock Invoke-Expression { } -ParameterFilter { $Command -like "*0404_Run-PSScriptAnalyzer.ps1*" }

    # Initialize mock calls tracking
    $script:MockCalls = @{
        'New-PullRequest' = @()
        'Sync-GitRepository' = @()
        'Add-GitHubIssueComment' = @()
    }
}

Describe "0703_Create-PullRequest" {
    BeforeEach {
        $script:MockCalls = @{
            'New-PullRequest' = @()
            'Sync-GitRepository' = @()
            'Add-GitHubIssueComment' = @()
        }

        # Reset to clean feature branch state
        New-Module -Name 'MockGitAutomation' -ScriptBlock {
            function Get-GitStatus {
                return @{
                    Clean = $true
                    Branch = 'feature/test-feature'
                    Ahead = 1
                    UpstreamBranch = 'origin/feature/test-feature'
                    Modified = @()
                    Untracked = @()
                }
            }

            function Get-GitRepository {
                return @{
                    Path = '/mock/repo'
                    Branch = 'feature/test-feature'
                    RemoteUrl = 'https://github.com/test/repo'
                }
            }

            function Test-GitHubCLI { }

            function Sync-GitRepository {
                param($Operation)
                $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
            }

            Export-ModuleMember -Function *
        } | Import-Module -Force
    }

    Context "Parameter Validation" {
        It "Should require Title parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf } | Should -Not -Throw
        }

        It "Should validate Template parameter values" {
            $validTemplates = @('feature', 'bugfix', 'hotfix', 'docs', 'refactor')
            foreach ($template in $validTemplates) {
                { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" -Template $template -WhatIf } | Should -Not -Throw
            }
        }

        It "Should validate MergeMethod parameter values" {
            $validMethods = @('merge', 'squash', 'rebase')
            foreach ($method in $validMethods) {
                { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" -MergeMethod $method -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context "Branch Validation" {
        It "Should prevent PR creation from main branch" {
            New-Module -Name 'MockGitAutomationMain' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'main' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" } | Should -Throw -ExpectedMessage "*Cannot create PR from default branch*"
        }

        It "Should prevent PR creation from master branch" {
            New-Module -Name 'MockGitAutomationMaster' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'master' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" } | Should -Throw -ExpectedMessage "*Cannot create PR from default branch*"
        }
    }

    Context "GitHub CLI Validation" {
        It "Should check GitHub CLI availability" {
            New-Module -Name 'MockGitAutomationNoGH' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'feature/test' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { throw "GitHub CLI not available" }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" } | Should -Throw -ExpectedMessage "*GitHub CLI not available*"
        }
    }

    Context "Uncommitted Changes Handling" {
        BeforeAll {
            # Mock dirty repository state
            New-Module -Name 'MockGitAutomationDirty' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Branch = 'feature/test'
                        Modified = @(@{ Path = 'file1.txt' })
                        Untracked = @(@{ Path = 'file2.txt' })
                    }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }

        It "Should warn about uncommitted changes in interactive mode" {
            Mock Read-Host { return 'n' }

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test"

            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*uncommitted changes*" }
            Should -Invoke Read-Host
        }

        It "Should proceed with Force when repository is dirty" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" -Force -WhatIf

            $script:MockCalls['New-PullRequest'] | Should -HaveCount 1
        }

        It "Should proceed with NonInteractive when repository is dirty" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" -NonInteractive -WhatIf

            $script:MockCalls['New-PullRequest'] | Should -HaveCount 1
        }
    }

    Context "Branch Pushing" {
        It "Should push branch when ahead of remote" {
            New-Module -Name 'MockGitAutomationAhead' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $true
                        Branch = 'feature/test'
                        Ahead = 2
                        UpstreamBranch = 'origin/feature/test'
                    }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                function Sync-GitRepository {
                    param($Operation)
                    $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" -WhatIf

            $script:MockCalls['Sync-GitRepository'] | Should -HaveCount 1
            $syncCall = $script:MockCalls['Sync-GitRepository'] | Select-Object -First 1
            $syncCall.Operation | Should -Be "Push"
        }

        It "Should push branch when no upstream branch exists" {
            New-Module -Name 'MockGitAutomationNoUpstream' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $true
                        Branch = 'feature/test'
                        Ahead = 0
                        UpstreamBranch = $null
                    }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                function Sync-GitRepository {
                    param($Operation)
                    $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test" -WhatIf

            $script:MockCalls['Sync-GitRepository'] | Should -HaveCount 1
        }
    }

    Context "Pull Request Creation" {
        It "Should create basic pull request" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            $script:MockCalls['New-PullRequest'] | Should -HaveCount 1
            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Title | Should -Be "Test PR"
            $prCall.Head | Should -Be "feature/test-feature"
        }

        It "Should use custom body when provided" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Body "Custom body" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Body | Should -Be "Custom body"
        }

        It "Should use custom base branch when provided" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Base "develop" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Base | Should -Be "develop"
        }

        It "Should create draft PR when Draft switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Draft -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Draft | Should -Be $true
        }

        It "Should set reviewers when provided" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Reviewers @('reviewer1', 'reviewer2') -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Reviewers | Should -Contain 'reviewer1'
            $prCall.Reviewers | Should -Contain 'reviewer2'
        }

        It "Should set assignees when provided" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Assignees @('user1') -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Assignees | Should -Contain 'user1'
        }

        It "Should auto-assign to current user when no assignees provided" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Assignees | Should -Contain 'testuser'
        }

        It "Should set labels when provided" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Labels @('bug', 'urgent') -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Labels | Should -Contain 'bug'
            $prCall.Labels | Should -Contain 'urgent'
        }

        It "Should enable AutoMerge when specified and not draft" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -AutoMerge -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.AutoMerge | Should -Be $true
        }

        It "Should not enable AutoMerge for draft PRs" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Draft -AutoMerge -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.AutoMerge | Should -Not -Be $true
        }
    }

    Context "Label Auto-Detection" {
        It "Should detect enhancement label for feature branches" {
            New-Module -Name 'MockGitAutomationFeature' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'feature/new-ui' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Labels | Should -Contain 'enhancement'
        }

        It "Should detect bug label for fix branches" {
            New-Module -Name 'MockGitAutomationFix' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'fix/issue-123' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Labels | Should -Contain 'bug'
        }

        It "Should detect documentation label for docs branches" {
            New-Module -Name 'MockGitAutomationDocs' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'docs/update-readme' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Labels | Should -Contain 'documentation'
        }
    }

    Context "Template Usage" {
        It "Should use default template when no custom body provided" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*pull_request_template.md*" }

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            Should -Invoke Get-Content -ParameterFilter { $Path -like "*pull_request_template.md*" }
        }

        It "Should use specific template when Template parameter is provided" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like "*feature.md*" }

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Template "feature" -WhatIf

            Should -Invoke Test-Path -ParameterFilter { $Path -like "*feature.md*" }
        }
    }

    Context "Issue Analysis Integration" {
        It "Should analyze related issues and include in PR body" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Body | Should -Match "Closes #123"
        }

        It "Should include manual issue references when Closes parameter is provided" {
            Mock Invoke-Expression { return $null } -ParameterFilter { $arguments[0] -like "*0805_Analyze-OpenIssues.ps1*" }

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Closes @(456, 789) -WhatIf

            $prCall = $script:MockCalls['New-PullRequest'] | Select-Object -First 1
            $prCall.Body | Should -Match "Closes #456"
            $prCall.Body | Should -Match "Closes #789"
        }
    }

    Context "Checks Execution" {
        It "Should run checks when RunChecks switch is used and not draft" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -RunChecks -WhatIf

            Should -Invoke & -ParameterFilter { $arguments[0] -like "*0402_Run-UnitTests.ps1*" }
            Should -Invoke & -ParameterFilter { $arguments[0] -like "*0404_Run-PSScriptAnalyzer.ps1*" }
        }

        It "Should not run checks for draft PRs" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -Draft -RunChecks -WhatIf

            Should -Not -Invoke & -ParameterFilter { $arguments[0] -like "*0402_Run-UnitTests.ps1*" }
        }
    }

    Context "Issue Linking" {
        It "Should link to issue when LinkIssue switch is used and issue number found in branch" {
            New-Module -Name 'MockGitAutomationIssueLink' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'feature/123-new-feature' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -LinkIssue -WhatIf

            $script:MockCalls['Add-GitHubIssueComment'] | Should -HaveCount 1
            $commentCall = $script:MockCalls['Add-GitHubIssueComment'] | Select-Object -First 1
            $commentCall.Number | Should -Be 123
        }
    }

    Context "WhatIf Support" {
        It "Should show PR operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -WhatIf

            # Mock functions should still be called for validation but actual operations skipped
            $script:MockCalls['New-PullRequest'] | Should -HaveCount 1
        }
    }

    Context "Error Handling" {
        It "Should handle PR creation failures" {
            New-Module -Name 'MockPullRequestManagerError' -ScriptBlock {
                function New-PullRequest { throw "API error" }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" } | Should -Throw
        }

        It "Should handle issue comment failures gracefully" {
            New-Module -Name 'MockIssueTrackerError' -ScriptBlock {
                function Add-GitHubIssueComment { throw "Comment failed" }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            New-Module -Name 'MockGitAutomationIssueLink' -ScriptBlock {
                function Get-GitStatus {
                    return @{ Clean = $true; Branch = 'feature/123-new-feature' }
                }
                function Get-GitRepository { return @{} }
                function Test-GitHubCLI { }
                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0703_Create-PullRequest.ps1" -Title "Test PR" -LinkIssue -WhatIf } | Should -Not -Throw
        }
    }
}
