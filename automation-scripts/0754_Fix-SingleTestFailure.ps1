#Requires -Version 7.0

<#
.SYNOPSIS
    Fix a single test failure using Claude Code CLI
.DESCRIPTION
    Invokes Claude Code CLI to fix the next open test failure in the tracker.
    Updates the tracker with fix attempts and status.
    
    Exit Codes:
    0   - Fix attempted or no issues to fix
    1   - Error attempting fix
    
.NOTES
    Stage: Testing
    Order: 0754
    Dependencies: 0751, 0752, 0750, claude CLI
    Tags: testing, automation, ai, claude, bugfix
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$ClaudeCLI = 'claude',
    [string]$IssueId,  # Specific issue ID to fix
    [int]$MaxAttempts = 3,
    [switch]$DemoMode,  # Run without actually invoking Claude
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0754
    Dependencies = @('0751', '0752', '0750')
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
    
    if (-not $Issue.githubIssue) {
        return
    }
    
    try {
        if ($Comment) {
            gh issue comment $Issue.githubIssue --body "$Comment" 2>&1 | Out-Null
        }
        
        if ($Labels) {
            gh issue edit $Issue.githubIssue --add-label ($Labels -join ',') 2>&1 | Out-Null
        }
    }
    catch {
        Write-ScriptLog -Level Warning -Message "Failed to update GitHub issue: $_"
    }
}

try {
    # Check for Claude CLI (unless in demo mode)
    if (-not $DemoMode -and -not (Get-Command $ClaudeCLI -ErrorAction SilentlyContinue)) {
        Write-ScriptLog -Level Warning -Message "Claude CLI not found. Install from: https://github.com/anthropics/claude-cli"
        Write-ScriptLog -Message "Running in demo mode instead"
        $DemoMode = $true
    }
    
    # Load tracker
    if (-not (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Error -Message "Tracker file not found. Run 0751_Load-TestTracker.ps1 first."
        exit 1
    }
    
    $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
    
    # Ensure issues is an array
    if ($tracker.issues -isnot [array]) {
        $tracker.issues = @($tracker.issues)
    }
    
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
    $initialFiles = git status --porcelain 2>&1 | Out-String
    # Get list of files before Claude makes changes
    $beforeFiles = @(git diff --name-only 2>&1)
    $beforeStatus = @(git status --porcelain 2>&1 | ForEach-Object { ($_ -split ' ')[-1] })
    
    # Update GitHub issue with detailed start information
    $startComment = @"
🔧 **Starting Fix Attempt #$($issueToFix.attempts)**

## Test Failure Details
- **Test:** ``$($issueToFix.testName)``
- **Location:** ``$($issueToFix.file):$($issueToFix.line)``
- **Error Type:** ``$($issueToFix.error -split ':' | Select-Object -First 1)``

## Error Message
\`\`\`
$($issueToFix.error)
\`\`\`

## Automation Process
1. 🤖 Invoking Claude Code with remediation-assistant persona
2. 🔍 Claude will analyze the test and source code
3. 🔨 Claude will apply minimal fixes to resolve the issue
4. ✅ Automated validation will verify the fix
5. 💾 Changes will be committed if successful

🕒 Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
    Update-GitHubIssue -Issue $issueToFix -Comment $startComment
    
    # Load remediation assistant persona if available
    $personaPath = Join-Path $PSScriptRoot '../../.claude/agents/remediation-assistant.md'
    $personaContent = if (Test-Path $personaPath) {
        Get-Content $personaPath -Raw
        Write-ScriptLog -Message "Loaded remediation-assistant persona from: $personaPath"
    } else {
        Write-ScriptLog -Level Warning -Message "Persona file not found: $personaPath"
        ""
    }
    
    # Build Claude prompt with persona
    $prompt = @"
$personaContent

## SPECIFIC TASK: Fix PowerShell Test Failure

You are acting as a remediation specialist to fix a specific test failure.

Test Name: $($issueToFix.testName)
File: $($issueToFix.file)
Line: $($issueToFix.line)

Error Message:
$($issueToFix.fullError)

Stack Trace:
$($issueToFix.stackTrace)

## Requirements:
1. Fix ONLY this specific test failure
2. Make minimal changes to fix the issue
3. Do not modify other tests or unrelated code
4. Ensure the fix is correct and complete
5. Follow existing code patterns and conventions
6. Use proper PowerShell error handling
7. Add appropriate logging using Write-CustomLog if available

## Context:
This is attempt $($issueToFix.attempts + 1) of $MaxAttempts to fix this issue.

Apply your remediation expertise to safely fix this test failure.
"@
    
    # Create directory for Claude artifacts if it doesn't exist
    $claudeDir = './claude-artifacts'
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
        Write-ScriptLog -Message "Created Claude artifacts directory: $claudeDir"
    }
    
    # Save prompt for debugging/reference
    $promptFile = Join-Path $claudeDir "fix-$($issueToFix.id)-attempt$($issueToFix.attempts)-prompt.txt"
    if ($PSCmdlet.ShouldProcess($promptFile, "Save Claude prompt")) {
        $prompt | Out-File $promptFile
        Write-ScriptLog -Message "Prompt saved to: $promptFile"
    }
    
    # Invoke Claude
    if ($DemoMode) {
        Write-Host "`n[DEMO MODE] Would invoke: $ClaudeCLI -p <prompt>" -ForegroundColor DarkGray
        Write-Host "Prompt saved to: $promptFile" -ForegroundColor DarkGray
        Write-ScriptLog -Level Warning -Message "Demo mode - fix must be applied manually"
        
        # In demo mode, mark as attempted but still open
        $issueToFix.status = 'open'
    } else {
        Write-Host "`n🤖 Invoking Claude Code to fix the issue..." -ForegroundColor Magenta
        
        if ($PSCmdlet.ShouldProcess("Claude Code", "Invoke to fix test failure")) {
            # Log Claude invocation
            Write-ScriptLog -Message "Invoking Claude CLI: $ClaudeCLI -p <prompt>"
            Write-ScriptLog -Message "Prompt file: $promptFile"
            Write-ScriptLog -Message "Prompt length: $($prompt.Length) characters"
            
            # Run Claude with the prompt in print mode and capture output
            $startTime = Get-Date
            Write-ScriptLog -Message "Starting Claude at: $startTime"
            
            # Update GitHub issue that Claude is processing
            Update-GitHubIssue -Issue $issueToFix -Comment @"
🤖 **Claude is now analyzing the code...**

- 🕰️ Started: $(Get-Date -Format 'HH:mm:ss')
- 📝 Analyzing test failure pattern
- 🔍 Examining source code
- 💡 Determining optimal fix strategy

_This may take 3-7 minutes depending on complexity..._
"@
            
            # Start a background job to provide periodic updates
            $updateJob = Start-Job -ScriptBlock {
                param($issueId, $githubIssue, $startTime)
                $elapsed = 0
                while ($elapsed -lt 600) { # Max 10 minutes
                    Start-Sleep -Seconds 60
                    $elapsed += 60
                    $minutes = [math]::Round($elapsed / 60, 1)
                    
                    # Try to update (will fail when main process completes)
                    try {
                        if ($githubIssue) {
                            $updateMsg = "⌚ Claude is still working... ($minutes minutes elapsed)"
                            gh issue comment $githubIssue --body "$updateMsg" 2>&1 | Out-Null
                        }
                    } catch {
                        break
                    }
                }
            } -ArgumentList $issueToFix.id, $issueToFix.githubIssue, $startTime
            
            $claudeResult = & $ClaudeCLI -p "$prompt" 2>&1
            
            # Stop the update job
            Stop-Job -Job $updateJob -ErrorAction SilentlyContinue
            Remove-Job -Job $updateJob -ErrorAction SilentlyContinue
            
            $endTime = Get-Date
            $duration = $endTime - $startTime
            Write-ScriptLog -Message "Claude completed in: $($duration.TotalSeconds) seconds"
            
            # Save Claude's response to file for review
            $responseFile = Join-Path $claudeDir "fix-$($issueToFix.id)-attempt$($issueToFix.attempts)-response.txt"
            $claudeResult | Out-File $responseFile
            Write-ScriptLog -Message "Claude response saved to: $responseFile"
            
            # Log Claude's output (first 500 chars for brevity)
            $outputPreview = if ($claudeResult) {
                $fullOutput = $claudeResult -join "`n"
                if ($fullOutput.Length -gt 500) {
                    $fullOutput.Substring(0, 500) + "... (truncated)"
                } else {
                    $fullOutput
                }
            } else {
                "(no output)"
            }
            Write-ScriptLog -Message "Claude output preview: $outputPreview"
            
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog -Message "Claude Code completed successfully"
                $issueToFix.status = 'validating'
                
                # Identify files actually changed by Claude
                $afterFiles = @(git diff --name-only 2>&1)
                $afterStatus = @(git status --porcelain 2>&1 | ForEach-Object { ($_ -split ' ')[-1] })
                
                # Find new/modified files
                $claudeChangedFiles = @()
                $claudeChangedFiles += Compare-Object $beforeFiles $afterFiles -PassThru | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
                $claudeChangedFiles += Compare-Object $beforeStatus $afterStatus -PassThru | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
                $claudeChangedFiles = $claudeChangedFiles | Select-Object -Unique
                
                # Store the changed files in the issue for the commit step
                if (-not $issueToFix.ContainsKey('changedFiles')) {
                    $issueToFix.Add('changedFiles', @($claudeChangedFiles))
                } else {
                    $issueToFix.changedFiles = @($claudeChangedFiles)
                }
                
                Write-ScriptLog -Message "Claude modified files: $($claudeChangedFiles -join ', ')"
                
                # Update GitHub issue with completion
                $filesChanged = git diff --name-only 2>&1 | Out-String
                Update-GitHubIssue -Issue $issueToFix -Comment @"
✅ **Claude has completed the fix!**

- ⏱️ Duration: $([math]::Round($duration.TotalSeconds)) seconds
- 📁 Files modified:
\`\`\`
$filesChanged
\`\`\`
- 🎯 Status: Moving to validation phase

_The fix will now be validated by running the test..._
"@
            } else {
                Write-ScriptLog -Level Warning -Message "Claude Code returned non-zero exit code: $LASTEXITCODE"
                Write-ScriptLog -Level Warning -Message "Full Claude output: $($claudeResult -join "`n")"
                $issueToFix.status = 'open'
                
                # Update GitHub issue with failure
                Update-GitHubIssue -Issue $issueToFix -Comment @"
⚠️ **Claude encountered an issue**

- Exit code: $LASTEXITCODE
- Duration: $([math]::Round($duration.TotalSeconds)) seconds
- Status: Will retry if attempts remaining

<details>
<summary>Error Details</summary>

\`\`\`
$($claudeResult -join "`n" | Select-Object -First 500)
\`\`\`

</details>
"@
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