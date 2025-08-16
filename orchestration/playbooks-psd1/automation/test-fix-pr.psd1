@{
    Name = 'test-fix-pr'
    Description = 'Create pull request with resolved test fixes'
    Version = '1.0.0'
    Author = 'AitherZero Automation'
    Tags = @('testing', 'github', 'pr', 'automation')
    
    Variables = @{
        TrackerFile = './test-fix-tracker.json'
        BaseBranch = 'main'
        ArchiveTracker = $true
    }
    
    Stages = @(
        @{
            Name = 'CommitRemaining'
            Description = 'Commit any remaining resolved issues'
            Sequence = @('0756')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                CommitAll = $true
                Push = $true
            }
        }
        
        @{
            Name = 'CreatePR'
            Description = 'Create pull request with all fixes'
            Sequence = @('0757')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                BaseBranch = '$Variables.BaseBranch'
                ArchiveTracker = '$Variables.ArchiveTracker'
            }
        }
    )
    
    ErrorHandling = @{
        OnStageFailure = 'Stop'
        OnScriptError = 'Log'
    }
}