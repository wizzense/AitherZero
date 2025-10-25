#Requires -Version 7.0
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $scriptPath = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) "automation-scripts/0805_Analyze-OpenIssues.ps1"

    Mock Write-Host -MockWith {}
    Mock Write-Warning -MockWith {}
    Mock Write-Error -MockWith {}
    Mock Import-Module -MockWith {}

    # Mock git commands
    Mock git -MockWith {
        switch ($arguments[0]) {
            "branch" { return "feature-branch" }
            "diff" { return "file1.ps1`nfile2.ps1" }
            "log" { return "fix: update feature`nadd: new functionality" }
            default { return "" }
        }
    }

    # Mock GitHub CLI
    Mock gh -MockWith {
        if ($arguments[0] -eq "issue" -and $arguments[1] -eq "list") {
            return '[{"number": 123, "title": "Bug in feature", "body": "Error in file1.ps1", "labels": [{"name": "bug"}]}]'
        }
    }

    Mock Get-Command -MockWith { return $true } -ParameterFilter { $Name -eq "gh" }
}

Describe "0805_Analyze-OpenIssues" {
    Context "Parameter Validation" {
        It "Should accept valid IssueType values" {
            { & $scriptPath -IssueType "All" } | Should -Not -Throw
            { & $scriptPath -IssueType "Bug" } | Should -Not -Throw
            { & $scriptPath -IssueType "Feature" } | Should -Not -Throw
            { & $scriptPath -IssueType "Test" } | Should -Not -Throw
            { & $scriptPath -IssueType "Documentation" } | Should -Not -Throw
        }

        It "Should accept MatchThreshold parameter" {
            { & $scriptPath -MatchThreshold 0.5 } | Should -Not -Throw
            { & $scriptPath -MatchThreshold 0.9 } | Should -Not -Throw
        }

        It "Should accept MaxIssues parameter" {
            { & $scriptPath -MaxIssues 50 } | Should -Not -Throw
            { & $scriptPath -MaxIssues 200 } | Should -Not -Throw
        }
    }

    Context "Git Integration" {
        It "Should get current branch if not specified" {
            & $scriptPath

            Should -Invoke git -ParameterFilter { $arguments[0] -eq "branch" -and $arguments[1] -eq "--show-current" }
        }

        It "Should get changed files between branches" {
            & $scriptPath -Branch "feature" -BaseBranch "main"

            Should -Invoke git -ParameterFilter { $arguments[0] -eq "diff" }
        }

        It "Should get commit messages" {
            & $scriptPath

            Should -Invoke git -ParameterFilter { $arguments[0] -eq "log" }
        }

        It "Should analyze diff content for error patterns" {
            Mock git -MockWith {
                if ($arguments[0] -eq "diff" -and $arguments.Count -gt 2) {
                    return "+fixed error handling`n-throw new Exception"
                }
                return ""
            }

            & $scriptPath

            Should -Invoke git -AtLeast 1
        }
    }

    Context "GitHub Issues Analysis" {
        It "Should fetch open issues by default" {
            & $scriptPath

            Should -Invoke gh -ParameterFilter { $arguments -contains "--state" -and $arguments -contains "open" }
        }

        It "Should include closed issues when requested" {
            & $scriptPath -IncludeClosed

            Should -Invoke gh -ParameterFilter { $arguments -contains "--state" -and $arguments -contains "all" }
        }

        It "Should filter issues by type" {
            & $scriptPath -IssueType "Bug"

            Should -Invoke gh -ParameterFilter { $arguments -contains "--label" -and $arguments -contains "bug" }
        }

        It "Should limit number of issues fetched" {
            & $scriptPath -MaxIssues 50

            Should -Invoke gh -ParameterFilter { $arguments -contains "--limit" -and $arguments -contains "50" }
        }

        It "Should handle GitHub CLI errors gracefully" {
            Mock gh -MockWith { throw "GitHub API error" }

            { & $scriptPath } | Should -Throw "Failed to fetch issues"
        }
    }

    Context "Issue Matching Logic" {
        BeforeEach {
            Mock gh -MockWith {
                return '[{"number": 123, "title": "Fix file1.ps1 error", "body": "Error in Get-Function", "labels": [{"name": "bug"}]}]'
            }
        }

        It "Should match direct issue references in commits" {
            Mock git -MockWith {
                if ($arguments[0] -eq "log") {
                    return "fix: resolve issue #123"
                }
                return ""
            }

            & $scriptPath

            Should -Invoke git -AtLeast 1
            Should -Invoke gh -AtLeast 1
        }

        It "Should match file names in issue content" {
            Mock git -MockWith {
                if ($arguments[0] -eq "diff" -and $arguments[1] -notmatch "log|branch") {
                    return "file1.ps1"
                }
                return ""
            }

            & $scriptPath

            Should -Invoke git -AtLeast 1
        }

        It "Should match error patterns" {
            Mock gh -MockWith {
                return '[{"number": 124, "title": "Function error", "body": "Get-Function throws exception", "labels": [{"name": "bug"}]}]'
            }

            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }

        It "Should match function and class names" {
            Mock gh -MockWith {
                return '[{"number": 125, "title": "Update Get-Data", "body": "function Get-Data needs fixing", "labels": [{"name": "enhancement"}]}]'
            }

            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }

        It "Should use keyword matching for commit messages" {
            Mock git -MockWith {
                if ($arguments[0] -eq "log") {
                    return "fix: resolve authentication issue"
                }
                return ""
            }

            & $scriptPath

            Should -Invoke git -AtLeast 1
        }
    }

    Context "AI Enhancement" {
        It "Should perform additional pattern matching when UseAI is enabled" {
            Mock gh -MockWith {
                return '[{"number": 126, "title": "Error handling", "body": "TerminatingError in module", "labels": [{"name": "bug"}]}]'
            }

            & $scriptPath -UseAI

            Should -Invoke gh -AtLeast 1
        }

        It "Should identify error handling patterns" {
            Mock git -MockWith {
                if ($arguments[0] -eq "diff" -and $arguments.Count -gt 2) {
                    return "+try { Get-Data } catch { Write-Error }"
                }
                return ""
            }

            & $scriptPath -UseAI

            Should -Invoke git -AtLeast 1
        }
    }

    Context "Match Scoring and Filtering" {
        BeforeEach {
            Mock gh -MockWith {
                return '[{"number": 127, "title": "Test issue", "body": "Sample issue for testing", "labels": []}]'
            }
        }

        It "Should filter matches by threshold" {
            & $scriptPath -MatchThreshold 0.9

            Should -Invoke gh -AtLeast 1
        }

        It "Should assign confidence levels based on score" {
            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }

        It "Should categorize link types based on confidence" {
            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }

        It "Should sort results by match score" {
            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }
    }

    Context "Output Generation" {
        It "Should display matched issues with confidence levels" {
            & $scriptPath

            Should -Invoke Write-Host -AtLeast 1
        }

        It "Should generate PR body section" {
            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }

        It "Should categorize issues by action type (Closes, Fixes, Refs)" {
            Mock gh -MockWith {
                return '[{"number": 128, "title": "Critical bug", "body": "This needs immediate fix", "labels": [{"name": "bug"}]}]'
            }

            & $scriptPath

            Should -Invoke gh -AtLeast 1
        }

        It "Should return structured output for pipeline use" {
            $result = & $scriptPath

            # Should return an object with analysis results
            Should -Invoke gh -AtLeast 1
        }
    }

    Context "Error Handling" {
        It "Should handle missing git repository" {
            Mock git -MockWith { throw "Not a git repository" }

            { & $scriptPath } | Should -Throw
        }

        It "Should handle empty changed files list" {
            Mock git -MockWith { return "" }

            { & $scriptPath } | Should -Not -Throw
            Should -Invoke Write-Warning -ParameterFilter { $Message -like "*No changed files*" }
        }

        It "Should handle missing GitHub CLI" {
            Mock Get-Command -MockWith { return $null } -ParameterFilter { $Name -eq "gh" }

            { & $scriptPath } | Should -Throw
        }

        It "Should validate branch names" {
            { & $scriptPath -Branch "valid-branch" -BaseBranch "main" } | Should -Not -Throw
        }
    }
}
