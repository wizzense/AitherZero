#Requires -Version 7.0

<#
.SYNOPSIS
    Validate that a test fix was successful
.DESCRIPTION
    Runs the specific test that was being fixed to verify it now passes.
    Updates the tracker with the validation result.
    
    Exit Codes:
    0   - Validation completed (pass or fail)
    1   - Error during validation
    
.NOTES
    Stage: Testing
    Order: 0755
    Dependencies: 0751, 0754, Pester
    Tags: testing, validation, automation
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$IssueId,  # Specific issue to validate
    [switch]$ValidateAll,  # Validate all 'validating' status issues
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0755
    Dependencies = @('0751', '0754')
    Tags = @('testing', 'validation', 'automation')
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
        [string[]]$AddLabels,
        [string[]]$RemoveLabels,
        [switch]$Close
    )
    
    if (-not $Issue.githubIssue) {
        return
    }
    
    try {
        if ($Comment) {
            gh issue comment $Issue.githubIssue --body "$Comment" 2>&1 | Out-Null
        }
        
        if ($AddLabels) {
            gh issue edit $Issue.githubIssue --add-label ($AddLabels -join ',') 2>&1 | Out-Null
        }
        
        if ($RemoveLabels) {
            gh issue edit $Issue.githubIssue --remove-label ($RemoveLabels -join ',') 2>&1 | Out-Null
        }
        
        if ($Close) {
            gh issue close $Issue.githubIssue --comment "Auto-closed: Test now passing" 2>&1 | Out-Null
        }
    }
    catch {
        Write-ScriptLog -Level Warning -Message "Failed to update GitHub issue: $_"
    }
}

try {
    # Ensure Pester is available
    if (-not (Get-Module -ListAvailable -Name Pester)) {
        Write-ScriptLog -Level Error -Message "Pester is not installed. Run 0400_Install-TestingTools.ps1 first."
        exit 1
    }
    
    Import-Module Pester -MinimumVersion 5.0 -Force
    
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
    
    # Find issues to validate
    $issuesToValidate = @(if ($IssueId) {
        $tracker.issues | Where-Object { $_.id -eq $IssueId }
    } elseif ($ValidateAll) {
        $tracker.issues | Where-Object { $_.status -in @('validating', 'fixing') }
    } else {
        # Default: validate the most recent 'validating' or 'fixing' issue
        $tracker.issues | Where-Object { $_.status -in @('validating', 'fixing') } | Select-Object -First 1
    })
    
    if ($issuesToValidate.Count -eq 0) {
        Write-ScriptLog -Message "No issues to validate"
        
        $validating = @($tracker.issues | Where-Object { $_.status -eq 'validating' }).Count
        $fixing = @($tracker.issues | Where-Object { $_.status -eq 'fixing' }).Count
        
        Write-Host "`n📊 Validation Status:" -ForegroundColor Cyan
        Write-Host "  Awaiting Validation: $validating" -ForegroundColor Yellow
        Write-Host "  Being Fixed: $fixing" -ForegroundColor Yellow
        
        if ($PassThru) {
            return $tracker
        }
        exit 0
    }
    
    Write-ScriptLog -Message "Validating $($issuesToValidate.Count) issue(s)"
    
    $validated = 0
    $passed = 0
    $failed = 0
    
    foreach ($issue in $issuesToValidate) {
        Write-Host "`n🔍 Validating issue $($issue.id): $($issue.testName)" -ForegroundColor Cyan
        Write-Host "  File: $($issue.file)" -ForegroundColor Gray
        
        if (-not $issue.file -or -not (Test-Path $issue.file)) {
            Write-ScriptLog -Level Warning -Message "Test file not found: $($issue.file)"
            $issue.status = 'open'
            $failed++
            continue
        }
        
        # Run the specific test
        Write-ScriptLog -Message "Running test: $($issue.testName)"
        
        # Update GitHub issue that validation is starting
        if ($issue.githubIssue) {
            Update-GitHubIssue -Issue $issue -Comment @"
🔍 **Starting validation...**

- 🧪 Running test: ``$($issue.testName)``
- 📍 Location: ``$($issue.file):$($issue.line)``
- 🔄 Attempt: $($issue.attempts) of 3

_Checking if the fix resolved the issue..._
"@
        }
        
        if ($PSCmdlet.ShouldProcess($issue.testName, "Run Pester test")) {
            $testResult = Invoke-Pester -Path $issue.file -FullNameFilter "*$($issue.testName)*" -PassThru -Output None
            
            $validated++
            
            if ($testResult.FailedCount -eq 0) {
                Write-Host "✅ TEST PASSED! Issue $($issue.id) is resolved!" -ForegroundColor Green
                $issue.status = 'resolved'
                $issue.resolvedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                $passed++
                
                # Get Claude's response if available
                $responseFile = "./claude-artifacts/fix-$($issue.id)-attempt$($issue.attempts)-response.txt"
                $claudeResponse = if (Test-Path $responseFile) {
                    $content = Get-Content $responseFile -Raw
                    # Truncate if too long for GitHub comment
                    if ($content.Length -gt 3000) {
                        $content.Substring(0, 3000) + "`n`n... (truncated)"
                    } else {
                        $content
                    }
                } else {
                    "(Claude response not available)"
                }
                
                # Get the actual changes made
                $changedFiles = git diff --name-only HEAD~1 HEAD 2>&1 | Out-String
                $diffSummary = git diff --stat HEAD~1 HEAD 2>&1 | Out-String
                
                # Update GitHub issue with detailed information
                $comment = @"
✅ **Fixed!**

Test is now passing after attempt #$($issue.attempts).

## Fix Details

**Test:** ``$($issue.testName)``
**File:** ``$($issue.file):$($issue.line)``
**Original Error:** 
\`\`\`
$($issue.error)
\`\`\`

## Claude's Solution

<details>
<summary>Claude's Response (click to expand)</summary>

\`\`\`
$claudeResponse
\`\`\`

</details>

## Changes Made

**Modified Files:**
\`\`\`
$changedFiles
\`\`\`

**Change Summary:**
\`\`\`
$diffSummary
\`\`\`

## Validation
- ✅ Test: PASSING
- 📅 Validated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- ⏱️ Fix Duration: ~$($issue.attempts * 5) minutes
- 🤖 Automated by: Claude Code

---
*This issue was automatically resolved by the AitherZero test automation system.*
"@
                Update-GitHubIssue -Issue $issue -Comment $comment -AddLabels @('fixed', 'auto-resolved')
                
            } else {
                Write-Host "❌ Test still failing after attempt $($issue.attempts)" -ForegroundColor Red
                $issue.status = 'open'
                $failed++
                
                # Check if max attempts reached
                $maxAttempts = 3
                if ($issue.attempts -ge $maxAttempts) {
                    Write-ScriptLog -Level Warning -Message "Max attempts ($maxAttempts) reached for issue $($issue.id)"
                    $issue.status = 'failed'
                    
                    $comment = @"
❌ **Failed to auto-fix after $($issue.attempts) attempts**

This issue requires manual intervention.
Test is still failing after multiple automated fix attempts.

**Status:** Needs manual fix
"@
                    Update-GitHubIssue -Issue $issue -Comment $comment -AddLabels @('needs-manual-fix')
                } else {
                    Update-GitHubIssue -Issue $issue -Comment "❌ Attempt #$($issue.attempts) failed. Test still not passing."
                }
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
    Write-Host "`n📊 Validation Summary:" -ForegroundColor Cyan
    Write-Host "  Validated: $validated" -ForegroundColor Gray
    Write-Host "  Passed: $passed" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor Red
    
    $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
    $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
    $failedTotal = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
    
    Write-Host "`n  Total Status:" -ForegroundColor Cyan
    Write-Host "    Open: $open" -ForegroundColor Yellow
    Write-Host "    Resolved: $resolved" -ForegroundColor Green
    Write-Host "    Failed (max attempts): $failedTotal" -ForegroundColor Red
    
    if ($passed -gt 0) {
        Write-Host "`n💡 Next step: Run 0756_Commit-TestFix.ps1 to commit the fixes" -ForegroundColor Yellow
    }
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to validate test fix: $_"
    exit 1
}