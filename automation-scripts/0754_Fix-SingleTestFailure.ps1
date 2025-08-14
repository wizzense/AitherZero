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
    
    # Update GitHub issue
    Update-GitHubIssue -Issue $issueToFix -Comment "🔧 Starting fix attempt #$($issueToFix.attempts) with Claude Code..."
    
    # Build Claude prompt
    $prompt = @"
Fix this ONE specific PowerShell test failure:

Test Name: $($issueToFix.testName)
File: $($issueToFix.file)
Line: $($issueToFix.line)

Error Message:
$($issueToFix.fullError)

Stack Trace:
$($issueToFix.stackTrace)

Requirements:
1. Fix ONLY this specific test failure
2. Make minimal changes to fix the issue
3. Do not modify other tests or unrelated code
4. Ensure the fix is correct and complete
5. Follow existing code patterns and conventions
"@
    
    # Save prompt for debugging/reference
    $promptFile = "./claude-fix-$($issueToFix.id)-attempt$($issueToFix.attempts).txt"
    if ($PSCmdlet.ShouldProcess($promptFile, "Save Claude prompt")) {
        $prompt | Out-File $promptFile
        Write-ScriptLog -Message "Prompt saved to: $promptFile"
    }
    
    # Invoke Claude
    if ($DemoMode) {
        Write-Host "`n[DEMO MODE] Would invoke: $ClaudeCLI code --auto-fix" -ForegroundColor DarkGray
        Write-Host "Prompt saved to: $promptFile" -ForegroundColor DarkGray
        Write-ScriptLog -Level Warning -Message "Demo mode - fix must be applied manually"
        
        # In demo mode, mark as attempted but still open
        $issueToFix.status = 'open'
    } else {
        Write-Host "`n🤖 Invoking Claude Code to fix the issue..." -ForegroundColor Magenta
        
        if ($PSCmdlet.ShouldProcess("Claude Code", "Invoke to fix test failure")) {
            # Run Claude with the prompt
            $claudeResult = & $ClaudeCLI code --auto-fix --prompt "$prompt" 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-ScriptLog -Message "Claude Code completed successfully"
                $issueToFix.status = 'validating'
            } else {
                Write-ScriptLog -Level Warning -Message "Claude Code returned non-zero exit code: $LASTEXITCODE"
                $issueToFix.status = 'open'
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