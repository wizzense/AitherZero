#Requires -Version 7.0

BeforeAll {
    # Mock the GitAutomation module functions
    $script:MockCalls = @{}

    # Create mock GitAutomation module
    New-Module -Name 'MockGitAutomation' -ScriptBlock {
        function Get-GitStatus {
            return @{
                Clean = $false
                Modified = @(@{ Path = 'file1.txt' }, @{ Path = 'file2.txt' })
                Staged = @(@{ Path = 'staged.txt' })
                Untracked = @(@{ Path = 'new.txt' })
            }
        }

        function Invoke-GitCommit {
            param($Message, $Type, $Scope, $Body, $CoAuthors, $AutoStage, $SignOff)
            $script:MockCalls['Invoke-GitCommit'] += @{
                Message = $Message
                Type = $Type
                Scope = $Scope
                Body = $Body
                CoAuthors = $CoAuthors
                AutoStage = $AutoStage
                SignOff = $SignOff
            }
            return @{ Hash = 'abc123456'; Message = $Message }
        }

        function Sync-GitRepository {
            param($Operation)
            $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
        }

        Export-ModuleMember -Function *
    } | Import-Module -Force

    # Mock external commands
    Mock git {
        switch -Regex ($arguments -join ' ') {
            'log -1 --stat' { return 'commit abc123' }
            default { return '' }
        }
    }

    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Write-Error { }
    Mock Read-Host { return 'y' }

    # Initialize mock calls tracking
    $script:MockCalls = @{
        'Invoke-GitCommit' = @()
        'Sync-GitRepository' = @()
    }
}

Describe "0702_Create-Commit" {
    BeforeEach {
        $script:MockCalls = @{
            'Invoke-GitCommit' = @()
            'Sync-GitRepository' = @()
        }

        # Reset mock to return non-clean status
        New-Module -Name 'MockGitAutomation' -ScriptBlock {
            function Get-GitStatus {
                return @{
                    Clean = $false
                    Modified = @(@{ Path = 'file1.txt' })
                    Staged = @(@{ Path = 'staged.txt' })
                    Untracked = @(@{ Path = 'new.txt' })
                }
            }

            function Invoke-GitCommit {
                param($Message, $Type, $Scope, $Body, $CoAuthors, $AutoStage, $SignOff)
                $script:MockCalls['Invoke-GitCommit'] += @{
                    Message = $Message
                    Type = $Type
                    Scope = $Scope
                    Body = $Body
                    CoAuthors = $CoAuthors
                    AutoStage = $AutoStage
                    SignOff = $SignOff
                }
                return @{ Hash = 'abc123456'; Message = $Message }
            }

            function Sync-GitRepository {
                param($Operation)
                $script:MockCalls['Sync-GitRepository'] += @{ Operation = $Operation }
            }

            Export-ModuleMember -Function *
        } | Import-Module -Force
    }

    Context "Parameter Validation" {
        It "Should require Type parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Message "test commit" } | Should -Not -Throw
        }

        It "Should require Message parameter" {
            { & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" } | Should -Not -Throw
        }

        It "Should validate Type parameter values" {
            $validTypes = @('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert')
            foreach ($type in $validTypes) {
                { & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type $type -Message "test" -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context "Commit Message Building" {
        It "Should create basic commit with type and message" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "add new feature" -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Type | Should -Be "feat"
            $commitCall.Message | Should -Be "add new feature"
        }

        It "Should include scope when provided" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "add feature" -Scope "ui" -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Scope | Should -Be "ui"
        }

        It "Should include body when provided" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "add feature" -Body "This is the body" -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Body | Should -Be "This is the body"
        }

        It "Should handle breaking changes" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "add feature" -Breaking -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Message | Should -Be "add feature\!"
        }

        It "Should include issue references" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "add feature" -Closes @(123, 456) -Refs @(789) -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.Body | Should -Match "Closes #123"
            $commitCall.Body | Should -Match "Closes #456"
            $commitCall.Body | Should -Match "Refs #789"
        }

        It "Should include co-authors when provided" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "add feature" -CoAuthors @('John Doe <john@example.com>') -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.CoAuthors | Should -Contain 'John Doe <john@example.com>'
        }
    }

    Context "Staging Behavior" {
        It "Should use AutoStage when specified" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -AutoStage -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.AutoStage | Should -Be $true
        }

        It "Should use SignOff when specified" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -SignOff -WhatIf

            $commitCall = $script:MockCalls['Invoke-GitCommit'] | Select-Object -First 1
            $commitCall.SignOff | Should -Be $true
        }
    }

    Context "Push Behavior" {
        It "Should push to remote when Push switch is used" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -Push -WhatIf

            $script:MockCalls['Sync-GitRepository'] | Should -HaveCount 1
            $syncCall = $script:MockCalls['Sync-GitRepository'] | Select-Object -First 1
            $syncCall.Operation | Should -Be "Push"
        }

        It "Should handle push failures gracefully" {
            New-Module -Name 'MockGitAutomationPushError' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Modified = @(@{ Path = 'file1.txt' })
                        Staged = @(@{ Path = 'staged.txt' })
                        Untracked = @()
                    }
                }

                function Invoke-GitCommit {
                    param($Message, $Type, $Scope, $Body, $CoAuthors, $AutoStage, $SignOff)
                    return @{ Hash = 'abc123456'; Message = $Message }
                }

                function Sync-GitRepository { throw "Push failed" }

                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -Push -WhatIf } | Should -Not -Throw
            Should -Invoke Write-Warning
        }
    }

    Context "Message Length Validation" {
        It "Should warn about long commit messages in interactive mode" {
            Mock Read-Host { return 'n' }
            $longMessage = "a" * 100

            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message $longMessage

            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*chars*" }
            Should -Invoke Read-Host
        }

        It "Should proceed with long messages in non-interactive mode" {
            $longMessage = "a" * 100

            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message $longMessage -NonInteractive -WhatIf

            $script:MockCalls['Invoke-GitCommit'] | Should -HaveCount 1
        }

        It "Should proceed with long messages when Force is used" {
            $longMessage = "a" * 100

            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message $longMessage -Force -WhatIf

            $script:MockCalls['Invoke-GitCommit'] | Should -HaveCount 1
        }
    }

    Context "Clean Repository Handling" {
        BeforeAll {
            # Mock clean repository state
            New-Module -Name 'MockGitAutomationClean' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $true
                        Modified = @()
                        Staged = @()
                        Untracked = @()
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }

        It "Should exit early when repository is clean and no AutoStage" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test"

            $script:MockCalls['Invoke-GitCommit'] | Should -HaveCount 0
        }

        It "Should exit early in non-interactive mode when repository is clean" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -NonInteractive

            $script:MockCalls['Invoke-GitCommit'] | Should -HaveCount 0
        }
    }

    Context "Staged Files Handling" {
        BeforeAll {
            # Mock repository with no staged files
            New-Module -Name 'MockGitAutomationNoStaged' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Modified = @(@{ Path = 'file1.txt' })
                        Staged = @()
                        Untracked = @(@{ Path = 'new.txt' })
                    }
                }
                Export-ModuleMember -Function *
            } | Import-Module -Force
        }

        It "Should warn when no files are staged in interactive mode" {
            Mock Read-Host { return 'n' }

            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test"

            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*No files staged*" }
        }

        It "Should exit when no files are staged in non-interactive mode" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -NonInteractive

            $script:MockCalls['Invoke-GitCommit'] | Should -HaveCount 0
        }
    }

    Context "WhatIf Support" {
        It "Should show commit operations without executing them when WhatIf is used" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -WhatIf

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*WhatIf*" }
        }

        It "Should not push when WhatIf is used even with Push switch" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -Push -WhatIf

            $script:MockCalls['Sync-GitRepository'] | Should -HaveCount 0
        }
    }

    Context "Error Handling" {
        It "Should handle commit failures" {
            New-Module -Name 'MockGitAutomationCommitError' -ScriptBlock {
                function Get-GitStatus {
                    return @{
                        Clean = $false
                        Modified = @()
                        Staged = @(@{ Path = 'staged.txt' })
                        Untracked = @()
                    }
                }

                function Invoke-GitCommit { throw "Commit failed" }

                Export-ModuleMember -Function *
            } | Import-Module -Force

            { & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" } | Should -Throw
        }

        It "Should handle module import failures" {
            Mock Import-Module { throw "Module not found" }

            { & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" } | Should -Throw
        }
    }

    Context "Git Log Display" {
        It "Should display commit details after successful commit" {
            & "/workspaces/AitherZero/automation-scripts/0702_Create-Commit.ps1" -Type "feat" -Message "test" -WhatIf

            Should -Invoke git -ParameterFilter { $arguments -contains 'log' -and $arguments -contains '-1' -and $arguments -contains '--stat' }
        }
    }
}
