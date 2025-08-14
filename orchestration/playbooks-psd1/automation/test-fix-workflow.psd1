@{
    Name = 'test-fix-workflow'
    Description = 'Automated test fixing workflow with Claude Code and GitHub integration'
    Version = '1.0.0'
    Author = 'AitherZero Automation'
    Tags = @('testing', 'automation', 'claude', 'github', 'bugfix')
    
    Variables = @{
        TrackerFile = './test-fix-tracker.json'
        TestResultsPath = './tests/results'
        CreateGitHubIssues = $true
        MaxAttempts = 3
        BaseBranch = 'main'
    }
    
    Stages = @(
        @{
            Name = 'InitializeTracker'
            Description = 'Load or create test tracker with branch'
            Sequence = @('0751')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                CreateBranch = $true
            }
        }
        
        @{
            Name = 'ProcessResults'
            Description = 'Process test results and add failures'
            Sequence = @('0752')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                TestResultsPath = '$Variables.TestResultsPath'
            }
        }
        
        @{
            Name = 'CreateIssue'
            Description = 'Create GitHub issue for next failure'
            Sequence = @('0753')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
            }
            Condition = '$Variables.CreateGitHubIssues'
        }
        
        @{
            Name = 'FixIssue'
            Description = 'Fix single test failure with Claude'
            Sequence = @('0754')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                MaxAttempts = '$Variables.MaxAttempts'
            }
        }
        
        @{
            Name = 'ValidateFix'
            Description = 'Validate the fix was successful'
            Sequence = @('0755')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
            }
        }
        
        @{
            Name = 'CommitFix'
            Description = 'Commit successful fixes'
            Sequence = @('0756')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
            }
        }
    )
    
    ErrorHandling = @{
        OnStageFailure = 'Continue'
        OnScriptError = 'Log'
        MaxRetries = 0
    }
}