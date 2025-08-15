#Requires -Version 7.0

<#
.SYNOPSIS
    Fix a single test failure using Claude Code with test-runner agent
.DESCRIPTION
    Invokes Claude Code's Task tool with test-runner agent to fix the next open test failure.
    Updates the tracker with fix attempts and status.
    
    Exit Codes:
    0   - Fix attempted or no issues to fix
    1   - Error attempting fix
    
.NOTES
    Stage: Testing
    Order: 0754
    Dependencies: 0751, 0752, Claude Code
    Tags: testing, automation, ai, claude, bugfix
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$IssueId,  # Specific issue ID to fix
    [int]$MaxAttempts = 3,
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0754
    Dependencies = @('0751', '0752')
    Tags = @('testing', 'automation', 'ai', 'claude', 'bugfix')
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
        [string]$Comment,
        [string[]]$Labels
    )
    
    # Check if githubIssue exists and has a value
    if (-not $Issue.ContainsKey('githubIssue') -or -not $Issue.githubIssue) {
        Write-ScriptLog -Level Warning -Message "No GitHub issue number found for issue $($Issue.id)"
        return
    }
    
    try {
        if ($Comment) {
            Write-ScriptLog -Message "Updating GitHub issue #$($Issue.githubIssue) with comment"
            gh issue comment $Issue.githubIssue --body "$Comment" 2>&1 | Out-Null
        }
        
        if ($Labels) {
            Write-ScriptLog -Message "Adding labels to GitHub issue #$($Issue.githubIssue): $($Labels -join ', ')"
            gh issue edit $Issue.githubIssue --add-label ($Labels -join ',') 2>&1 | Out-Null
        }
    }
    catch {
        Write-ScriptLog -Level Warning -Message "Failed to update GitHub issue: $_"
    }
}

try {
    Write-ScriptLog -Message "Claude Code test-runner agent will fix test failures"
    
    # Load tracker
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Error -Message "Tracker file not found. Run 0751_Load-TestTracker.ps1 first."
        exit 1
    }
    
    $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
    Write-ScriptLog -Message "Loaded tracker with $($tracker.issues.Count) issues"
    
    # Find issue to fix
    $issueToFix = if ($IssueId) {
        $tracker.issues | Where-Object { $_.id -eq $IssueId }
    } else {
        # Get next open issue that hasn't exceeded max attempts
        $tracker.issues | Where-Object { 
            $_.status -eq 'open' -and $_.attempts -lt $MaxAttempts 
        } | Select-Object -First 1
    }
    
    if (-not $issueToFix) {
        Write-ScriptLog -Message "No issues available to fix"
        
        $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
        $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
        $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
        
        Write-Host "`n📊 Issue Status:" -ForegroundColor Cyan
        Write-Host "  Open: $open" -ForegroundColor Yellow
        Write-Host "  Resolved: $resolved" -ForegroundColor Green
        Write-Host "  Failed (max attempts): $failed" -ForegroundColor Red
        
        if ($open -eq 0 -and $resolved -gt 0) {
            Write-Host "`n🎉 All fixable issues resolved!" -ForegroundColor Green
            Write-Host "💡 Run 0757_Create-FixPR.ps1 to create a pull request" -ForegroundColor Yellow
        }
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    Write-Host "`n🎯 Fixing issue $($issueToFix.id): $($issueToFix.testName)" -ForegroundColor Yellow
    Write-Host "  File: $($issueToFix.file):$($issueToFix.line)" -ForegroundColor Gray
    Write-Host "  Error: $($issueToFix.error)" -ForegroundColor Red
    Write-Host "  Attempt: $($issueToFix.attempts + 1) of $MaxAttempts" -ForegroundColor Cyan
    
    # Update status
    $issueToFix.status = 'fixing'
    $issueToFix.attempts++
    $issueToFix.lastAttempt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Capture initial state for comparison
    $beforeFiles = @(git diff --name-only 2>&1)
    $beforeStatus = @(git status --porcelain 2>&1 | ForEach-Object { ($_ -split ' ')[-1] })
    
    # Update GitHub issue with start information
    $startComment = @"
🔧 **Starting Fix Attempt #$($issueToFix.attempts)**

## Test Failure Details
- **Test:** ``$($issueToFix.testName)``
- **Location:** ``$($issueToFix.file):$($issueToFix.line)``
- **Error Type:** ``$($issueToFix.error -split ':' | Select-Object -First 1)``
- **Method:** Claude Code Task Agent (test-runner)

## Error Message
\`\`\`
$($issueToFix.error)
\`\`\`

## Stack Trace
<details>
<summary>Click to expand</summary>

\`\`\`
$($issueToFix.stackTrace)
\`\`\`

</details>

🤖 Claude Code test-runner agent is analyzing and fixing the issue...
"@
    Update-GitHubIssue -Issue $issueToFix -Comment $startComment
    
    # Create directory for Claude artifacts if it doesn't exist
    $claudeDir = './claude-artifacts'
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    
    Write-Host "`n🤖 Invoking Claude CLI to fix the test..." -ForegroundColor Magenta
    
    if ($PSCmdlet.ShouldProcess("Claude CLI", "Fix test failure")) {
        $startTime = Get-Date
        
        # Build the prompt for Claude
        $fixPrompt = @"
Fix this PowerShell test failure. You are an expert PowerShell developer.

Test: $($issueToFix.testName)
File: $($issueToFix.file)
Line: $($issueToFix.line)
Error: $($issueToFix.error)

Stack Trace:
$($issueToFix.stackTrace)

Instructions:
1. Analyze the test failure
2. Identify the root cause
3. Fix ONLY this specific test failure
4. Make minimal changes
5. Follow existing code patterns

The test file content is provided below. Fix the issue.
"@
        
        Write-Host "`n📝 Sending test failure to Claude CLI..." -ForegroundColor Cyan
        Write-Host "  Test: $($issueToFix.testName)" -ForegroundColor Gray
        Write-Host "  File: $($issueToFix.file)" -ForegroundColor Gray
        Write-Host "  Error: $($issueToFix.error)" -ForegroundColor Gray
        
        # Use the claude command directly - it's available in the environment
        $claudeWrapper = "claude"
        
        # Build a clear, actionable prompt for Claude
        Write-Host "`n🤖 Calling Claude CLI to fix the test..." -ForegroundColor Cyan
        
        $claudePrompt = @"
Fix this PowerShell test failure:

Test: $($issueToFix.testName)
File: $($issueToFix.file)  
Line: $($issueToFix.line)
Error: $($issueToFix.error)

Stack trace: $($issueToFix.stackTrace)

Instructions:
1. Read the test file at $($issueToFix.file)
2. Analyze what's causing the error at line $($issueToFix.line)
3. Fix ONLY this specific test failure - make minimal changes
4. Use the Edit or MultiEdit tool to make the necessary changes
5. Follow existing code patterns

This is attempt $($issueToFix.attempts) of $MaxAttempts.
$(if ($issueToFix.attempts -gt 1) { "Previous attempts failed - try a different approach." })

Fix this test now.
"@
        
        # Call Claude CLI directly with the prompt
        Write-Host "  Invoking Claude with fix request..." -ForegroundColor Gray
        try {
            # Call Claude and give it time to work
            Write-Host "  ⏳ Waiting for Claude to analyze and fix (this may take 30-60 seconds)..." -ForegroundColor Yellow
            
            # Write prompt to temp file and invoke Claude
            $promptFile = [System.IO.Path]::GetTempFileName()
            $claudePrompt | Out-File -FilePath $promptFile -Encoding UTF8
            
            # Start Claude in background with prompt file
            $claudeJob = Start-Job -ScriptBlock {
                param($promptFile)
                # Use bash to invoke claude since it's a shell alias
                bash -c "claude < '$promptFile'" 2>&1
            } -ArgumentList $promptFile
            
            # Wait up to 90 seconds for Claude to complete
            $waitResult = Wait-Job -Job $claudeJob -Timeout 90
            
            if ($waitResult) {
                Write-Host "✅ Claude completed execution" -ForegroundColor Green
                $claudeOutput = Receive-Job -Job $claudeJob
                Remove-Job -Job $claudeJob
                
                # Clean up temp file
                if (Test-Path $promptFile) {
                    Remove-Item $promptFile -Force
                }
                
                Write-ScriptLog -Message "Claude executed successfully for issue $($issueToFix.id)"
            } else {
                Write-Host "⚠️ Claude is still running after 90 seconds, continuing..." -ForegroundColor Yellow
                Stop-Job -Job $claudeJob
                Remove-Job -Job $claudeJob -Force
                
                # Clean up temp file
                if (Test-Path $promptFile) {
                    Remove-Item $promptFile -Force
                }
                
                Write-ScriptLog -Level Warning -Message "Claude timed out after 90 seconds"
            }
        }
        catch {
            Write-Host "⚠️ Error calling Claude: $_" -ForegroundColor Yellow
            Write-ScriptLog -Level Warning -Message "Claude execution error: $_"
        }
        
        # Give additional time for file system to sync
        Write-Host "  🔄 Waiting for file system sync..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
        
        # Check for changes
        $afterFiles = @(git diff --name-only 2>&1)
        $afterStatus = @(git status --porcelain 2>&1 | ForEach-Object { ($_ -split ' ')[-1] })
        
        # Find new/modified files - simple git diff check
        $changedFiles = @(git diff --name-only 2>&1 | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' })
        
        # Also check for new untracked files
        $newFiles = @(git status --porcelain 2>&1 | Where-Object { $_ -match '^\?\?' } | ForEach-Object { ($_ -split ' ')[-1] } | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' })
        if ($newFiles) {
            $changedFiles += $newFiles
        }
        
        $changedFiles = @($changedFiles | Select-Object -Unique)
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        if ($changedFiles.Count -gt 0) {
            Write-Host "`n✅ Claude Code has made changes to fix the issue!" -ForegroundColor Green
            Write-Host "Files modified: $($changedFiles -join ', ')" -ForegroundColor Gray
            
            $issueToFix.status = 'validating'
            
            # Store changed files for commit step
            if (-not $issueToFix.ContainsKey('changedFiles')) {
                $issueToFix.Add('changedFiles', @($changedFiles))
            } else {
                $issueToFix.changedFiles = @($changedFiles)
            }
            
            # Get diff for GitHub
            $gitDiff = git diff 2>&1 | Select-Object -First 100
            $filesChanged = git diff --name-only 2>&1 | Out-String
            
            Update-GitHubIssue -Issue $issueToFix -Comment @"
✅ **Claude Code has completed the fix!**

- ⏱️ Duration: $([math]::Round($duration.TotalSeconds)) seconds
- 🤖 Agent: test-runner
- 📁 Files modified:
\`\`\`
$filesChanged
\`\`\`

## Code Changes Applied:
<details>
<summary>View diff (first 100 lines)</summary>

\`\`\`diff
$($gitDiff -join "`n")
\`\`\`

</details>

- 🎯 Status: Moving to validation phase

_The fix will now be validated by running the test..._
"@
        } else {
            Write-Host "`n⚠️ No changes detected yet" -ForegroundColor Yellow
            Write-Host "Claude Code may need more time or manual intervention" -ForegroundColor Yellow
            
            $issueToFix.status = 'open'
            
            Update-GitHubIssue -Issue $issueToFix -Comment @"
⚠️ **No Changes Detected**

- Duration: $([math]::Round($duration.TotalSeconds)) seconds
- Attempts: $($issueToFix.attempts) of $MaxAttempts
- Status: Will retry if attempts remaining

The test-runner agent may need additional context or the issue may require manual intervention.
"@
        }
        
        Write-ScriptLog -Message "Fix attempt completed in: $($duration.TotalSeconds) seconds"
    }
    
    # Save tracker
    $tracker.updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($PSCmdlet.ShouldProcess($TrackerPath, "Save updated tracker")) {
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
        Write-ScriptLog -Message "Tracker updated"
    }
    
    # Summary
    Write-Host "`n📊 Fix Attempt Summary:" -ForegroundColor Cyan
    Write-Host "  Issue: $($issueToFix.id)" -ForegroundColor Gray
    Write-Host "  Test: $($issueToFix.testName)" -ForegroundColor Gray
    Write-Host "  Status: $($issueToFix.status)" -ForegroundColor $(
        switch ($issueToFix.status) {
            'validating' { 'Yellow' }
            'open' { 'Red' }
            default { 'Gray' }
        }
    )
    Write-Host "  Attempts: $($issueToFix.attempts)/$MaxAttempts" -ForegroundColor Gray
    
    if ($issueToFix.status -eq 'validating') {
        Write-Host "`n💡 Next step: Run 0755_Validate-TestFix.ps1 to verify the fix" -ForegroundColor Yellow
    } elseif ($issueToFix.attempts -ge $MaxAttempts) {
        Write-Host "`n⚠️ Max attempts reached. Manual intervention required." -ForegroundColor Red
        
        # Mark as failed
        $issueToFix.status = 'failed'
        Update-GitHubIssue -Issue $issueToFix -Comment "❌ Failed to auto-fix after $MaxAttempts attempts. Manual intervention required." -Labels @('needs-manual-fix')
        
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
    }
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to fix test failure: $_"
    exit 1
}