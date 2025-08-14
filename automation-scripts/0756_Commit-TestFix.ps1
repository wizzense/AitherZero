#Requires -Version 7.0

<#
.SYNOPSIS
    Commit successful test fixes to git
.DESCRIPTION
    Commits resolved test fixes to git with appropriate commit messages.
    Updates the tracker with commit information.
    
    Exit Codes:
    0   - Commits made or nothing to commit
    1   - Error during commit
    
.NOTES
    Stage: Testing
    Order: 0756
    Dependencies: 0751, 0755, git
    Tags: testing, git, automation, commit
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$IssueId,  # Specific issue to commit
    [switch]$CommitAll,  # Commit all resolved issues
    [switch]$Push,  # Push commits to remote
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0756
    Dependencies = @('0751', '0755')
    Tags = @('testing', 'git', 'automation', 'commit')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'White'
        'Debug' = 'Gray'
    }[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Update-GitHubIssue {
    param(
        [hashtable]$Issue,
        [string]$Comment
    )
    
    if (-not $Issue.githubIssue) {
        return
    }
    
    try {
        gh issue comment $Issue.githubIssue --body "$Comment" 2>&1 | Out-Null
    }
    catch {
        Write-ScriptLog -Level Warning -Message "Failed to update GitHub issue: $_"
    }
}

try {
    # Load tracker
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Error -Message "Tracker file not found. Run 0751_Load-TestTracker.ps1 first."
        exit 1
    }
    
    $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
    Write-ScriptLog -Message "Loaded tracker with $($tracker.issues.Count) issues"
    
    # Find issues to commit
    $issuesToCommit = if ($IssueId) {
        @($tracker.issues | Where-Object { $_.id -eq $IssueId -and $_.status -eq 'resolved' -and -not $_.fixCommit })
    } elseif ($CommitAll) {
        @($tracker.issues | Where-Object { $_.status -eq 'resolved' -and -not $_.fixCommit })
    } else {
        # Default: commit the most recently resolved issue
        @($tracker.issues | Where-Object { $_.status -eq 'resolved' -and -not $_.fixCommit } | Select-Object -First 1)
    }
    
    if ($issuesToCommit.Count -eq 0) {
        Write-ScriptLog -Message "No resolved issues to commit"
        
        $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' })
        $committed = @($resolved | Where-Object { $_.fixCommit })
        $uncommitted = @($resolved | Where-Object { -not $_.fixCommit })
        
        Write-Host "`n📊 Commit Status:" -ForegroundColor Cyan
        Write-Host "  Total Resolved: $($resolved.Count)" -ForegroundColor Green
        Write-Host "  Committed: $($committed.Count)" -ForegroundColor Gray
        Write-Host "  Uncommitted: $($uncommitted.Count)" -ForegroundColor Yellow
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    Write-ScriptLog -Message "Found $($issuesToCommit.Count) resolved issue(s) to commit"
    
    # Check for uncommitted changes
    $gitStatus = git status --porcelain 2>&1
    if (-not $gitStatus) {
        Write-ScriptLog -Level Warning -Message "No uncommitted changes found"
        Write-ScriptLog -Message "Marking issues as committed anyway (changes may have been committed manually)"
        
        foreach ($issue in $issuesToCommit) {
            $issue.fixCommit = git rev-parse HEAD 2>&1
            $issue.committedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    $committed = 0
    
    foreach ($issue in $issuesToCommit) {
        Write-Host "`n📝 Committing fix for issue $($issue.id): $($issue.testName)" -ForegroundColor Cyan
        
        # Find files related to this test
        $filesToCommit = @()
        
        if ($issue.file -and (Test-Path $issue.file)) {
            # Check if the test file has changes
            $testFileStatus = git status --porcelain $issue.file 2>&1
            if ($testFileStatus) {
                $filesToCommit += $issue.file
            }
            
            # Try to find the source file being tested
            $sourceFile = $issue.file -replace '\.Tests\.ps1$', '.ps1'
            if ($sourceFile -ne $issue.file -and (Test-Path $sourceFile)) {
                $sourceFileStatus = git status --porcelain $sourceFile 2>&1
                if ($sourceFileStatus) {
                    $filesToCommit += $sourceFile
                }
            }
            
            # Check for module files
            $moduleFile = $issue.file -replace '\.Tests\.ps1$', '.psm1'
            if ($moduleFile -ne $issue.file -and (Test-Path $moduleFile)) {
                $moduleFileStatus = git status --porcelain $moduleFile 2>&1
                if ($moduleFileStatus) {
                    $filesToCommit += $moduleFile
                }
            }
        }
        
        if ($filesToCommit.Count -eq 0) {
            Write-ScriptLog -Level Warning -Message "No files to commit for issue $($issue.id)"
            Write-ScriptLog -Message "Committing all changes instead"
            $filesToCommit = @('.')
        }
        
        # Truncate long test names for commit message
        $shortName = if ($issue.testName.Length -gt 50) {
            $issue.testName.Substring(0, 50) + "..."
        } else {
            $issue.testName
        }
        
        # Build commit message
        $commitMsg = "fix: $shortName"
        
        if ($issue.githubIssue) {
            $commitMsg += "`n`nFixes #$($issue.githubIssue)"
        }
        
        $commitMsg += @"

Auto-fixed by Claude Code

Test: $($issue.testName)
File: $($issue.file):$($issue.line)
Attempts: $($issue.attempts)
"@
        
        # Stage and commit files
        if ($PSCmdlet.ShouldProcess(($filesToCommit -join ', '), "Stage and commit files")) {
            Write-ScriptLog -Message "Staging files: $($filesToCommit -join ', ')"
            git add $filesToCommit 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-ScriptLog -Level Error -Message "Failed to stage files"
                continue
            }
            
            Write-ScriptLog -Message "Creating commit"
            git commit -m "$commitMsg" 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                $issue.fixCommit = git rev-parse HEAD 2>&1
                $issue.committedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                $committed++
                
                Write-Host "✅ Committed: $($issue.fixCommit.Substring(0, 8))" -ForegroundColor Green
                
                # Update GitHub issue
                Update-GitHubIssue -Issue $issue -Comment "✅ Fix committed: ``$($issue.fixCommit.Substring(0, 8))``"
            } else {
                Write-ScriptLog -Level Warning -Message "Failed to create commit"
            }
        }
    }
    
    # Push if requested
    if ($Push -and $committed -gt 0) {
        Write-Host "`n🚀 Pushing commits to remote..." -ForegroundColor Cyan
        
        if ($PSCmdlet.ShouldProcess("origin $($tracker.currentBranch)", "Push commits")) {
            git push -u origin $tracker.currentBranch 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Pushed to origin/$($tracker.currentBranch)" -ForegroundColor Green
            } else {
                Write-ScriptLog -Level Warning -Message "Failed to push commits"
            }
        }
    }
    
    # Save tracker
    $tracker.updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($PSCmdlet.ShouldProcess($TrackerPath, "Save updated tracker")) {
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
        Write-ScriptLog -Message "Tracker updated"
    }
    
    # Summary
    Write-Host "`n📊 Commit Summary:" -ForegroundColor Cyan
    Write-Host "  Committed: $committed" -ForegroundColor Green
    
    $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' })
    $withCommits = @($resolved | Where-Object { $_.fixCommit })
    $withoutCommits = @($resolved | Where-Object { -not $_.fixCommit })
    
    Write-Host "`n  Total Resolved:" -ForegroundColor Cyan
    Write-Host "    With Commits: $($withCommits.Count)" -ForegroundColor Green
    Write-Host "    Without Commits: $($withoutCommits.Count)" -ForegroundColor $(if ($withoutCommits.Count -gt 0) { 'Yellow' } else { 'Gray' })
    
    if ($withCommits.Count -gt 0 -and $withoutCommits.Count -eq 0) {
        Write-Host "`n🎉 All resolved issues have been committed!" -ForegroundColor Green
        Write-Host "💡 Next step: Run 0757_Create-FixPR.ps1 to create a pull request" -ForegroundColor Yellow
    }
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to commit test fix: $_"
    exit 1
}