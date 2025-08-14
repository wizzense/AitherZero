@{
    Name = 'claude-fix-with-tracking'
    Description = 'Fix one test failure with full GitHub issue tracking'
    Version = '4.0.0'
    Author = 'AitherZero Automation'
    Tags = @('AI', 'Testing', 'GitHub', 'Claude', 'BugFix', 'Tracking')
    
    Variables = @{
        TestResultsPath = './tests/results'
        TrackerFile = './test-fix-tracker.json'
        ClaudeCLI = 'claude'
        CreateGitHubIssues = $true
        GitHubRepo = 'wizzense/AitherZero'
    }
    
    Stages = @(
        @{
            Name = 'LoadTracker'
            Description = 'Load or create test tracker'
            Sequence = @('0751')
            Parameters = @{
                CreateBranch = $true
            }
        }
        
        @{
            Name = 'ProcessTestResults'
            Description = 'Process test results and add failures to tracker'
            Sequence = @('0752')
        }
        
        @{
            Name = 'CreateGitHubIssue'
            Description = 'Create GitHub issue for next open test'
            Sequence = @('0753')
            Condition = '$Variables.CreateGitHubIssues'
        }
        
        @{
            Name = 'FixWithClaude'
            Description = 'Fix the issue using Claude Code'
            Sequence = @('0754')
            Parameters = @{
                DemoMode = '-not (Get-Command claude -ErrorAction SilentlyContinue)'
            }
        }
        
        @{
            Name = 'ValidateAndCommit'
            Description = 'Validate fix and commit if successful'
            Sequence = @('0755', '0756')
        }
    )
    
    ErrorHandling = @{
        OnStageFailure = 'Continue'
        OnScriptError = 'Log'
        MaxRetries = 0
    }
}