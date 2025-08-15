@{
    Name = 'test-fix-workflow'
    Description = 'Automated test fixing workflow with Claude Code and GitHub integration - processes one issue per run'
    Version = '3.0.0'
    Author = 'AitherZero Automation'
    Tags = @('testing', 'automation', 'claude', 'github', 'bugfix')
    
    Variables = @{
        TrackerFile = './test-fix-tracker.json'
        TestResultsPath = './tests/reports'
        TestResultsMaxAge = 1  # Hours
        CreateGitHubIssues = $true
        MaxAttempts = 3
        BaseBranch = 'main'
        NonInteractive = $true
        UseTaskAgent = $true  # Use Claude Task agent with test-runner
        LogPath = './logs/test-fix'
    }
    
    Stages = @(
        @{
            Name = 'Initialize'
            Description = 'Load tracker and process test results'
            Sequence = @('0751', '0752')
            Parameters = @{
                TrackerPath = './test-fix-tracker.json'
                TestResultsPath = './tests/reports'
                CreateBranch = $true
                MaxAgeHours = 1
            }
        }
        
        @{
            Name = 'CreateGitHubIssue'
            Description = 'Create GitHub issue for next open failure'
            Sequence = @('0753')
            Parameters = @{
                TrackerPath = './test-fix-tracker.json'
            }
            Condition = $true
        }
        
        @{
            Name = 'FixWithClaude'
            Description = 'Fix single test failure using Claude test-runner agent'
            Sequence = @('0754')
            Parameters = @{
                TrackerPath = './test-fix-tracker.json'
                MaxAttempts = 3
            }
        }
        
        @{
            Name = 'ValidateFix'
            Description = 'Validate the fix by running the test'
            Sequence = @('0755')
            Parameters = @{
                TrackerPath = './test-fix-tracker.json'
                ValidateAll = $false  # Only validate the fixed test
                RetryOnFailure = $true
                MaxRetries = 2
            }
        }
        
        @{
            Name = 'CommitFix'
            Description = 'Commit successful fix'
            Sequence = @('0756')
            Parameters = @{
                TrackerPath = './test-fix-tracker.json'
                CommitAll = $false  # Only commit if validated
            }
        }
    )
    
    ErrorHandling = @{
        OnStageFailure = 'Continue'
        OnScriptError = 'Log'
        MaxRetries = 0
        ScriptTimeout = 120  # 2 minutes per script to allow Claude time
    }
    
    # Summary to show after completion
    PostExecutionScript = {
        param($Variables)
        
        if (Test-Path $Variables.TrackerFile) {
            $tracker = Get-Content $Variables.TrackerFile -Raw | ConvertFrom-Json
            $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
            $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
            $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
            
            Write-Host "`nTest Fix Summary:" -ForegroundColor Cyan
            Write-Host "  Open: $open" -ForegroundColor Yellow
            Write-Host "  Resolved: $resolved" -ForegroundColor Green
            Write-Host "  Failed: $failed" -ForegroundColor Red
            
            if ($open -gt 0) {
                Write-Host "`nRun the playbook again to fix the next issue" -ForegroundColor Yellow
            }
        }
    }
}