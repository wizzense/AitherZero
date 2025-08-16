@{
    Name = 'test-fix-loop'
    Description = 'Continuous test fixing loop with Claude Code - runs until all issues are resolved or failed'
    Version = '1.0.0'
    Author = 'AitherZero Automation'
    Tags = @('testing', 'automation', 'claude', 'github', 'bugfix', 'loop')
    
    Variables = @{
        TrackerFile = './test-fix-tracker.json'
        TestResultsPath = './tests/results'
        CreateGitHubIssues = $true
        MaxAttempts = 3
        BaseBranch = 'main'
        MaxLoops = 50  # Prevent infinite loops
    }
    
    # This is a repeating workflow that processes one issue at a time
    Stages = @(
        @{
            Name = 'InitializeOnce'
            Description = 'One-time initialization'
            Sequence = @('0751', '0752')  # Load tracker and process results
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                TestResultsPath = '$Variables.TestResultsPath'
                CreateBranch = $true
            }
            RunOnce = $true  # Only run on first iteration
        }
        
        @{
            Name = 'FixSingleIssue'
            Description = 'Fix one test failure'
            Sequence = @('0754')  # Fix with Claude
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
                MaxAttempts = '$Variables.MaxAttempts'
            }
            # Only run if there are open issues
            Condition = '@($tracker.issues | Where-Object { $_.status -eq "open" -and $_.attempts -lt $Variables.MaxAttempts }).Count -gt 0'
        }
        
        @{
            Name = 'ValidateAndCommit'
            Description = 'Validate and commit if successful'
            Sequence = @('0755', '0756')  # Validate and commit
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
            }
            # Only run if there are issues being validated
            Condition = '@($tracker.issues | Where-Object { $_.status -in @("validating", "fixing") }).Count -gt 0'
        }
        
        @{
            Name = 'CreateGitHubIssues'
            Description = 'Create GitHub issues for new failures'
            Sequence = @('0753')
            Parameters = @{
                TrackerPath = '$Variables.TrackerFile'
            }
            Condition = '$Variables.CreateGitHubIssues'
            # Only run if there are issues without GitHub issues
            AdditionalCondition = '@($tracker.issues | Where-Object { $_.status -eq "open" -and -not $_.githubIssue }).Count -gt 0'
        }
    )
    
    # Loop configuration
    Loop = @{
        Enabled = $true
        # Continue while there are open issues with attempts remaining
        ContinueCondition = '@($tracker.issues | Where-Object { $_.status -eq "open" -and $_.attempts -lt $Variables.MaxAttempts }).Count -gt 0'
        MaxIterations = '$Variables.MaxLoops'
        DelayBetweenIterations = 2  # seconds
    }
    
    ErrorHandling = @{
        OnStageFailure = 'Continue'
        OnScriptError = 'Log'
        MaxRetries = 0
    }
    
    # Final summary script to run after loop completes
    FinalScript = @{
        ScriptBlock = {
            param($tracker, $Variables)
            
            $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
            $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
            $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
            
            Write-Host "`n" -NoNewline
            Write-Host "=" * 60 -ForegroundColor Cyan
            Write-Host "FINAL TEST FIX SUMMARY" -ForegroundColor Cyan
            Write-Host "=" * 60 -ForegroundColor Cyan
            Write-Host "  Total Issues: $($tracker.issues.Count)"
            Write-Host "  Resolved: $resolved" -ForegroundColor Green
            Write-Host "  Failed (max attempts): $failed" -ForegroundColor Red
            Write-Host "  Still Open: $open" -ForegroundColor Yellow
            
            if ($resolved -gt 0) {
                Write-Host "`n✅ Successfully fixed $resolved test failure(s)!" -ForegroundColor Green
                Write-Host "💡 Next step: Run 0757_Create-FixPR.ps1 to create a pull request" -ForegroundColor Yellow
            }
            
            if ($failed -gt 0) {
                Write-Host "`n⚠️ $failed issue(s) require manual intervention" -ForegroundColor Red
            }
        }
    }
}