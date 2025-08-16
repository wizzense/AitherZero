@{
    Name = 'claude-create-fix-pr'
    Description = 'Create PR with all resolved issues from automated fixes'
    Version = '1.0.0'
    Author = 'AitherZero Automation'
    Tags = @('GitHub', 'PR', 'Automation', 'Claude')
    
    Variables = @{
        TrackerFile = './test-fix-tracker.json'
        BaseBranch = 'main'  # Base branch for PR
    }
    
    Stages = @(
        @{
            Name = 'PrepareForPR'
            Description = 'Ensure all changes are committed'
            Sequence = @('0756')
            Parameters = @{
                CommitAll = $true
            }
        }
        
        @{
            Name = 'CreatePullRequest'
            Description = 'Create PR with resolved issues'
            Sequence = @('0757')
            Parameters = @{
                BaseBranch = '$Variables.BaseBranch'
                ArchiveTracker = $true
            }
        }
    )
    
    ErrorHandling = @{
        OnStageFailure = 'Continue'
        OnScriptError = 'Log'
    }
}