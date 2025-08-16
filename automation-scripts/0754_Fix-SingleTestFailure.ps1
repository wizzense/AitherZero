#Requires -Version 7.0

<#
.SYNOPSIS
    Fix a single test failure using Claude Code with test-runner agent
.DESCRIPTION
    Invokes Claude Code's Task tool with test-runner agent to fix the next open test failure.
    Updates the tracker with fix attempts and status.
    Logs everything to GitHub issues AND local logs.
    
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

# Create detailed log file for this session
$sessionId = [Guid]::NewGuid().ToString().Substring(0, 8)
$detailedLogPath = "./logs/test-fix/claude-fix-$sessionId.log"
if (-not (Test-Path "./logs/test-fix")) {
    New-Item -ItemType Directory -Path "./logs/test-fix" -Force | Out-Null
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'White'
        'Debug' = 'Gray'
    }[$Level]
    
    # Console output
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    # Detailed file logging
    $logEntry = "[$timestamp] [$Level] [0754_Fix-SingleTestFailure] $Message"
    Add-Content -Path $detailedLogPath -Value $logEntry -Force
    
    # Also log to main orchestration log if available
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message "[0754] $Message"
    }
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
            
            # Log comment to file as well
            Add-Content -Path $detailedLogPath -Value "`n=== GitHub Issue Update ===" -Force
            Add-Content -Path $detailedLogPath -Value "Issue: #$($Issue.githubIssue)" -Force
            Add-Content -Path $detailedLogPath -Value "Comment:`n$Comment" -Force
            Add-Content -Path $detailedLogPath -Value "=== End Issue Update ===`n" -Force
            
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
    Write-ScriptLog -Message "Starting Claude Code test-runner agent fix session (ID: $sessionId)"
    Write-ScriptLog -Message "Detailed log: $detailedLogPath"
    
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
    
    # Log to detailed file
    Add-Content -Path $detailedLogPath -Value "`n=== Starting Fix Attempt ===" -Force
    Add-Content -Path $detailedLogPath -Value "Issue ID: $($issueToFix.id)" -Force
    Add-Content -Path $detailedLogPath -Value "Test: $($issueToFix.testName)" -Force
    Add-Content -Path $detailedLogPath -Value "File: $($issueToFix.file):$($issueToFix.line)" -Force
    Add-Content -Path $detailedLogPath -Value "Error: $($issueToFix.error)" -Force
    Add-Content -Path $detailedLogPath -Value "Attempt: $($issueToFix.attempts + 1) of $MaxAttempts" -Force
    
    # Update status
    $issueToFix.status = 'fixing'
    $issueToFix.attempts++
    $issueToFix.lastAttempt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    
    # Capture initial state for comparison
    $beforeFiles = @(git diff --name-only 2>&1)
    $beforeStatus = @(git status --porcelain 2>&1 | ForEach-Object { ($_ -split ' ')[-1] })
    
    # Update GitHub issue with start information
    $startComment = @"
# 🔧 Starting Fix Attempt #$($issueToFix.attempts)

## Session Information
- **Session ID**: $sessionId
- **Timestamp**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Agent**: Claude Code test-runner
- **Log File**: logs/test-fix/claude-fix-$sessionId.log

## Test Failure Details
- **Test**: \`$($issueToFix.testName)\`
- **Location**: \`$($issueToFix.file):$($issueToFix.line)\`
- **Error Type**: \`$($issueToFix.error -split ':' | Select-Object -First 1)\`

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

🤖 Invoking Claude Code test-runner agent...
"@
    Update-GitHubIssue -Issue $issueToFix -Comment $startComment
    
    # Create directory for Claude artifacts if it doesn't exist
    $claudeDir = './claude-artifacts'
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    
    Write-Host "`n🤖 Invoking Claude test-runner agent to fix the test..." -ForegroundColor Magenta
    
    if ($PSCmdlet.ShouldProcess("Claude test-runner agent", "Fix test failure")) {
        $startTime = Get-Date
        
        # Determine if this is likely a test bug vs implementation bug
        $testBugIndicators = @(
            'Expected .* to be .*, but got',
            'Expected an exception to be thrown, but no exception was thrown',
            'Should -Be',
            'Should -Throw',
            'Assert-Mock',
            'property .* cannot be found'
        )
        
        $isLikelyTestBug = $false
        foreach ($indicator in $testBugIndicators) {
            if ($issueToFix.error -match $indicator) {
                $isLikelyTestBug = $true
                break
            }
        }
        
        # Build a comprehensive prompt for Claude
        Write-Host "`n📝 Preparing test failure details for Claude..." -ForegroundColor Cyan
        Write-Host "  Test: $($issueToFix.testName)" -ForegroundColor Gray
        Write-Host "  File: $($issueToFix.file)" -ForegroundColor Gray
        Write-Host "  Error: $($issueToFix.error)" -ForegroundColor Gray
        Write-Host "  Likely test bug: $isLikelyTestBug" -ForegroundColor Gray
        
        Write-ScriptLog -Message "Preparing Claude prompt (likely test bug: $isLikelyTestBug)"
        
        # Build a clear, actionable prompt for Claude
        Write-Host "`n🤖 Calling Claude test-runner agent to fix the test..." -ForegroundColor Cyan
        
        $claudePrompt = @"
You are a PowerShell test expert using the test-runner agent. Fix this test failure.

## Test Failure Details
- **Test Name**: $($issueToFix.testName)
- **Test File**: $($issueToFix.file)
- **Line Number**: $($issueToFix.line)
- **Error Message**: $($issueToFix.error)
- **Stack Trace**: $($issueToFix.stackTrace)
- **Attempt**: $($issueToFix.attempts) of $MaxAttempts

## Important Context
$(if ($isLikelyTestBug) {
@"
⚠️ **This appears to be a test bug, not an implementation bug.**
The test expectations may be incorrect. Common issues:
- Test expects wrong exit code or exception behavior
- Mock setup is missing or incorrect  
- Test has wrong assertions
- Test is duplicated multiple times
"@
} else {
@"
This appears to be an implementation bug where the code doesn't match test expectations.
Fix the implementation to make the test pass.
"@
})

## Your Task
1. First, read the test file at: $($issueToFix.file)
2. If the test references other files, read those too
3. Analyze the root cause - is it the test or the implementation?
4. Fix the issue using Edit or MultiEdit tools
5. Make minimal changes - fix ONLY this specific failure
6. Follow existing code patterns and conventions

## Special Instructions
$(if ($issueToFix.attempts -gt 1) {
@"
⚠️ Previous fix attempts failed. Try a different approach:
- If you tried fixing the implementation, try fixing the test instead
- If you tried fixing the test, ensure you understand what it's actually testing
- Check for duplicate test cases with the same name
- Verify mock setups match the test assertions
"@
})

Remember:
- Tests can be wrong - don't assume the test is correct
- Check if the test makes sense for what it's testing
- Some tests expect exceptions but the code handles errors gracefully
- Exit codes depend on actual behavior, not test assumptions

Fix this test failure now using the most appropriate approach.
"@
        
        # Log the prompt
        Add-Content -Path $detailedLogPath -Value "`n=== Claude Prompt ===" -Force
        Add-Content -Path $detailedLogPath -Value $claudePrompt -Force
        Add-Content -Path $detailedLogPath -Value "=== End Prompt ===`n" -Force
        
        # Call Claude CLI directly with the prompt
        Write-Host "  Invoking Claude with test-runner agent..." -ForegroundColor Gray
        try {
            # Call Claude and give it time to work
            Write-Host "  ⏳ Waiting for Claude to analyze and fix (this may take 30-90 seconds)..." -ForegroundColor Yellow
            
            # Write prompt to temp file and invoke Claude
            $promptFile = [System.IO.Path]::GetTempFileName()
            $claudePrompt | Out-File -FilePath $promptFile -Encoding UTF8
            
            # Start Claude in background with prompt file
            $claudeJob = Start-Job -ScriptBlock {
                param($promptFile)
                # Use bash to invoke claude since it's a shell alias
                bash -c "claude < '$promptFile'" 2>&1
            } -ArgumentList $promptFile
            
            # Wait up to 120 seconds for Claude to complete (give more time for complex fixes)
            $waitResult = Wait-Job -Job $claudeJob -Timeout 120
            
            if ($waitResult) {
                Write-Host "✅ Claude completed execution" -ForegroundColor Green
                $claudeOutput = Receive-Job -Job $claudeJob
                Remove-Job -Job $claudeJob
                
                # Clean up temp file
                if (Test-Path $promptFile) {
                    Remove-Item $promptFile -Force
                }
                
                # Log Claude's complete response
                if ($claudeOutput) {
                    $claudeResponse = $claudeOutput -join "`n"
                    
                    # Log to file
                    Add-Content -Path $detailedLogPath -Value "`n=== Claude Response ===" -Force
                    Add-Content -Path $detailedLogPath -Value $claudeResponse -Force
                    Add-Content -Path $detailedLogPath -Value "=== End Response ===`n" -Force
                    
                    # Update GitHub issue with Claude's full response
                    $claudeComment = @"
## 🤖 Claude Test-Runner Agent Response

### Prompt Sent to Claude:
<details>
<summary>Click to expand prompt (Session: $sessionId)</summary>

\`\`\`
$claudePrompt
\`\`\`

</details>

### Claude's Full Response:
<details>
<summary>Click to expand full response</summary>

\`\`\`
$claudeResponse
\`\`\`

</details>

### Execution Details
- ⏱️ Processing time: 120 seconds or less
- 📝 Status: Analyzing changes...
- 📁 Log file: logs/test-fix/claude-fix-$sessionId.log
"@
                    Update-GitHubIssue -Issue $issueToFix -Comment $claudeComment
                }
                
                Write-ScriptLog -Message "Claude test-runner agent executed successfully for issue $($issueToFix.id)"
            } else {
                Write-Host "⚠️ Claude is still running after 120 seconds, continuing..." -ForegroundColor Yellow
                Stop-Job -Job $claudeJob
                $partialOutput = Receive-Job -Job $claudeJob
                Remove-Job -Job $claudeJob -Force
                
                # Clean up temp file
                if (Test-Path $promptFile) {
                    Remove-Item $promptFile -Force
                }
                
                # Log partial output
                if ($partialOutput) {
                    Add-Content -Path $detailedLogPath -Value "`n=== Claude Partial Response (Timeout) ===" -Force
                    Add-Content -Path $detailedLogPath -Value ($partialOutput -join "`n") -Force
                    Add-Content -Path $detailedLogPath -Value "=== End Partial Response ===`n" -Force
                    
                    $timeoutComment = @"
⚠️ **Claude Timeout After 120 Seconds**

### Partial Output Received:
<details>
<summary>Click to expand partial output</summary>

\`\`\`
$($partialOutput -join "`n")
\`\`\`

</details>

The agent may still be processing. Checking for file changes...
Session log: logs/test-fix/claude-fix-$sessionId.log
"@
                    Update-GitHubIssue -Issue $issueToFix -Comment $timeoutComment
                }
                
                Write-ScriptLog -Level Warning -Message "Claude timed out after 120 seconds"
            }
        }
        catch {
            Write-Host "⚠️ Error calling Claude: $_" -ForegroundColor Yellow
            Write-ScriptLog -Level Warning -Message "Claude execution error: $_"
            
            # Log error to file
            Add-Content -Path $detailedLogPath -Value "`n=== Claude Error ===" -Force
            Add-Content -Path $detailedLogPath -Value $_.ToString() -Force
            Add-Content -Path $detailedLogPath -Value "=== End Error ===`n" -Force
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
            
            Write-ScriptLog -Message "Claude made changes to $($changedFiles.Count) file(s): $($changedFiles -join ', ')"
            
            $issueToFix.status = 'validating'
            
            # Store changed files for commit step
            if (-not $issueToFix.ContainsKey('changedFiles')) {
                $issueToFix.Add('changedFiles', @($changedFiles))
            } else {
                $issueToFix.changedFiles = @($changedFiles)
            }
            
            # Get diff for GitHub and logging
            $gitDiff = git diff 2>&1 | Select-Object -First 200
            $filesChanged = git diff --name-only 2>&1 | Out-String
            
            # Log diff to file
            Add-Content -Path $detailedLogPath -Value "`n=== Git Diff ===" -Force
            Add-Content -Path $detailedLogPath -Value (git diff 2>&1 | Out-String) -Force
            Add-Content -Path $detailedLogPath -Value "=== End Diff ===`n" -Force
            
            Update-GitHubIssue -Issue $issueToFix -Comment @"
## ✅ Claude Code has completed the fix!

### Execution Summary
- ⏱️ Duration: $([math]::Round($duration.TotalSeconds)) seconds
- 🤖 Agent: test-runner
- 📁 Session log: logs/test-fix/claude-fix-$sessionId.log

### Files Modified:
\`\`\`
$filesChanged
\`\`\`

### Code Changes Applied:
<details>
<summary>View diff (first 200 lines)</summary>

\`\`\`diff
$($gitDiff -join "`n")
\`\`\`

</details>

### Next Steps
- 🎯 Status: Moving to validation phase
- 🧪 The fix will now be validated by running the test

_Full session details available in: logs/test-fix/claude-fix-$sessionId.log_
"@
        } else {
            Write-Host "`n⚠️ No changes detected yet" -ForegroundColor Yellow
            Write-Host "Claude Code may need more time or manual intervention" -ForegroundColor Yellow
            
            Write-ScriptLog -Level Warning -Message "No changes detected after Claude execution"
            
            $issueToFix.status = 'open'
            
            Update-GitHubIssue -Issue $issueToFix -Comment @"
⚠️ **No Changes Detected**

- Duration: $([math]::Round($duration.TotalSeconds)) seconds
- Attempts: $($issueToFix.attempts) of $MaxAttempts
- Status: Will retry if attempts remaining
- Session log: logs/test-fix/claude-fix-$sessionId.log

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
    Write-Host "  Log: $detailedLogPath" -ForegroundColor Gray
    
    if ($issueToFix.status -eq 'validating') {
        Write-Host "`n💡 Next step: Run 0755_Validate-TestFix.ps1 to verify the fix" -ForegroundColor Yellow
    } elseif ($issueToFix.attempts -ge $MaxAttempts) {
        Write-Host "`n⚠️ Max attempts reached. Manual intervention required." -ForegroundColor Red
        
        # Mark as failed
        $issueToFix.status = 'failed'
        Update-GitHubIssue -Issue $issueToFix -Comment "❌ Failed to auto-fix after $MaxAttempts attempts. Manual intervention required. Check logs: logs/test-fix/" -Labels @('needs-manual-fix')
        
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
    }
    
    # Final log entry
    Add-Content -Path $detailedLogPath -Value "`n=== Session Complete ===" -Force
    Add-Content -Path $detailedLogPath -Value "End Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')" -Force
    Add-Content -Path $detailedLogPath -Value "Status: $($issueToFix.status)" -Force
    Add-Content -Path $detailedLogPath -Value "=== End Session ===`n" -Force
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to fix test failure: $_"
    
    # Log error to file
    if ($detailedLogPath) {
        Add-Content -Path $detailedLogPath -Value "`n=== FATAL ERROR ===" -Force
        Add-Content -Path $detailedLogPath -Value $_.ToString() -Force
        Add-Content -Path $detailedLogPath -Value $_.ScriptStackTrace -Force
        Add-Content -Path $detailedLogPath -Value "=== End Error ===`n" -Force
    }
    
    exit 1
}