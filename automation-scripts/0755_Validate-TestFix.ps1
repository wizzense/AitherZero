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
    [switch]$RetryOnFailure,  # Automatically retry failed validations
    [int]$MaxRetries = 3,  # Maximum retry attempts
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
    Write-ScriptLog -Message "Loaded tracker with $($tracker.issues.Count) issues"
    
    # Find issues to validate
    $issuesToValidate = if ($IssueId) {
        @($tracker.issues | Where-Object { $_.id -eq $IssueId })
    } elseif ($ValidateAll) {
        @($tracker.issues | Where-Object { $_.status -in @('validating', 'fixing') })
    } else {
        # Default: validate the most recent 'validating' or 'fixing' issue
        @($tracker.issues | Where-Object { $_.status -in @('validating', 'fixing') } | Select-Object -First 1)
    }
    
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
        
        # Run the specific test with detailed output
        Write-ScriptLog -Message "Running test: $($issue.testName)"
        
        if ($PSCmdlet.ShouldProcess($issue.testName, "Run Pester test")) {
            # Capture detailed test output
            $testOutput = @()
            $testResult = Invoke-Pester -Path $issue.file -FullNameFilter "*$($issue.testName)*" -PassThru -Output Detailed 4>&1 | Tee-Object -Variable testOutput
            
            # Convert output to string
            $testOutputString = $testOutput -join "`n"
            
            $validated++
            
            if ($testResult.FailedCount -eq 0) {
                Write-Host "✅ TEST PASSED! Issue $($issue.id) is resolved!" -ForegroundColor Green
                $issue.status = 'resolved'
                $issue.resolvedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                $passed++
                
                # Update GitHub issue
                $comment = @"
✅ **Test Fixed Successfully!**

Test is now PASSING after attempt #$($issue.attempts).

## Validation Results
- **Status:** ✅ PASSING
- **Duration:** $($testResult.Duration.TotalSeconds) seconds
- **Validated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Test File:** ``$($issue.file):$($issue.line)``

## Test Output
<details>
<summary>Full Pester Output</summary>

\`\`\`powershell
$testOutputString
\`\`\`

</details>

## Next Steps
- ✅ Test is now passing
- 📝 Changes are ready for commit
- 🔀 A Pull Request can be created to merge the fix
- ⚠️ **Issue will remain open until PR is merged**

---
*The test has been successfully fixed by Claude Code automation. Issue will be closed when the PR is merged.*
"@
                Update-GitHubIssue -Issue $issue -Comment $comment -AddLabels @('fixed', 'ready-for-pr')
                
            } else {
                Write-Host "❌ Test still failing after attempt $($issue.attempts)" -ForegroundColor Red
                $issue.status = 'open'
                $failed++
                
                # Extract current failure details from test
                $currentError = if ($testResult.Tests -and $testResult.Tests.Count -gt 0) {
                    $failedTest = $testResult.Tests | Where-Object { $_.Result -eq 'Failed' } | Select-Object -First 1
                    if ($failedTest -and $failedTest.ErrorRecord) {
                        $failedTest.ErrorRecord.Exception.Message
                    } else {
                        "Test failed but no error details available"
                    }
                } else {
                    "Unable to extract error details"
                }
                
                # Include test output in failure message
                $failureComment = @"
❌ **Test Still Failing After Fix Attempt**

## Test Results
- **Status:** ❌ FAILING
- **Attempt:** #$($issue.attempts)
- **Duration:** $($testResult.Duration.TotalSeconds) seconds
- **Failed Count:** $($testResult.FailedCount)

## Current Error
\`\`\`
$currentError
\`\`\`

## Test Output
<details>
<summary>Full Pester Output</summary>

\`\`\`powershell
$testOutputString
\`\`\`

</details>

$(if ($RetryOnFailure -and $issue.attempts -lt $maxAttempts) { "🔄 Will automatically retry with a different approach..." } else { "💡 Manual intervention may be required" })
"@
                
                # Check if max attempts reached
                $maxAttempts = if ($MaxRetries -gt 0) { $MaxRetries } else { 3 }
                if ($issue.attempts -ge $maxAttempts) {
                    Write-ScriptLog -Level Warning -Message "Max attempts ($maxAttempts) reached for issue $($issue.id)"
                    $issue.status = 'failed'
                    
                    # Post the failure comment with max attempts message
                    Update-GitHubIssue -Issue $issue -Comment $failureComment -AddLabels @('needs-manual-fix')
                } else {
                    # Update issue with current failure
                    Update-GitHubIssue -Issue $issue -Comment $failureComment
                    
                    # Automatically retry if requested
                    if ($RetryOnFailure -and $issue.attempts -lt $maxAttempts) {
                        Write-ScriptLog -Message "Automatically retrying fix for issue $($issue.id)..."
                        
                        # Brief pause before retry
                        Start-Sleep -Seconds 5
                        
                        # Update issue status
                        Update-GitHubIssue -Issue $issue -Comment "🔄 **Retrying fix with attempt #$($issue.attempts + 1)**"
                        
                        # Call the fix script again
                        $fixScript = Join-Path $PSScriptRoot "0754_Fix-SingleTestFailure.ps1"
                        if (Test-Path $fixScript) {
                            Write-ScriptLog -Message "Invoking fix script: $fixScript"
                            
                            if ($PSCmdlet.ShouldProcess($fixScript, "Retry fix for issue $($issue.id)")) {
                                & $fixScript -TrackerPath $TrackerPath -IssueId $issue.id -MaxAttempts $maxAttempts
                                
                                # Reload tracker to get updated data
                                $tracker = Get-Content $TrackerPath -Raw | ConvertFrom-Json -AsHashtable
                                
                                # Re-validate after retry
                                Write-ScriptLog -Message "Re-validating after retry..."
                                Start-Sleep -Seconds 2
                                
                                # Run test again
                                $retryTestResult = Invoke-Pester -Path $issue.file -FullNameFilter "*$($issue.testName)*" -PassThru -Output None
                                
                                if ($retryTestResult.FailedCount -eq 0) {
                                    Write-Host "✅ TEST PASSED after retry! Issue $($issue.id) is resolved!" -ForegroundColor Green
                                    $issue.status = 'resolved'
                                    $issue.resolvedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                                    $passed++
                                    $failed--  # Adjust the count
                                    
                                    Update-GitHubIssue -Issue $issue -Comment @"
✅ **Fixed on retry!**

Test is now passing after retry attempt #$($issue.attempts + 1).

**Validation Results:**
- Test: PASSING ✅
- Validated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

The issue has been automatically resolved by Claude Code.
"@ -AddLabels @('fixed', 'auto-resolved')
                                } else {
                                    Write-ScriptLog -Level Warning -Message "Test still failing after retry"
                                }
                            }
                        } else {
                            Write-ScriptLog -Level Error -Message "Fix script not found: $fixScript"
                        }
                    }
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