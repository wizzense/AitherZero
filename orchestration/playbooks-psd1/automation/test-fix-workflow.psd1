@{
    Name = 'test-fix-workflow'
    Description = 'Automated test fixing workflow with Claude Code and GitHub integration - processes one issue per run'
    Version = '2.0.0'
    Author = 'AitherZero Automation'
    Tags = @('testing', 'automation', 'claude', 'github', 'bugfix')
    
    Variables = @{
        TrackerFile = './test-fix-tracker.json'
        TestResultsPath = './tests/reports'
        TestResultsMaxAge = 1  # Days
        CreateGitHubIssues = $true
        MaxAttempts = 3
        MaxLoops = 1  # Process only one issue per playbook run
        BaseBranch = 'main'
        NonInteractive = $true
        UseClaudeAgents = $true
        LogPath = './logs/test-fix'
    }
    
    Stages = @(
        @{
            Name = 'RunTestFixLoop'
            Description = 'Run complete test-fix loop for one issue'
            Sequence = @('0758')
            Variables = @{
                TrackerPath = './test-fix-tracker.json'
                MaxLoops = 1  # Process only one issue
                MaxAttempts = 3
                CreateGitHubIssues = $true
                NonInteractive = $true
            }
        }
    )
    
    ErrorHandling = @{
        OnStageFailure = 'Continue'
        OnScriptError = 'Log'
        MaxRetries = 0
    }
}