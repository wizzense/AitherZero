#Requires -Version 7.0
<#
.SYNOPSIS
    Automated GitHub issue resolution based on PR status
    
.DESCRIPTION
    This function handles automatic issue resolution when PRs are merged or closed:
    1. Monitors PR status changes
    2. Automatically closes issues when PRs are merged
    3. Keeps issues open when PRs are just closed (bug still needs fixing)
    4. Updates issue status with appropriate comments
    
.PARAMETER IssueNumber
    The GitHub issue number to monitor
    
.PARAMETER PullRequestNumber
    The associated PR number
    
.PARAMETER MonitorInterval
    How often to check PR status (default: 60 seconds)
    
.PARAMETER MaxMonitorHours
    Maximum time to monitor (default: 24 hours)
    
.EXAMPLE
    Invoke-GitHubIssueResolution -IssueNumber 123 -PullRequestNumber 45
    
.NOTES
    - Issues are only closed when PRs are merged (not just closed)
    - Closed PRs without merge keep the issue open for resubmission
    - Full audit trail of status changes
#>

function Invoke-GitHubIssueResolution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        
        [Parameter(Mandatory = $true)]
        [int]$PullRequestNumber,
        
        [Parameter(Mandatory = $false)]
        [int]$MonitorInterval = 60,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxMonitorHours = 24,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath = "logs/issue-resolution.log"
    )
    
    begin {
        # Initialize logging
        $logDir = Split-Path $LogPath
        if (-not (Test-Path $logDir)) {
            if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        }
        
        function Write-ResolutionLog {
            param([string]$Message, [string]$Level = "INFO")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] [$Level] [Issue #$IssueNumber] $Message"
            Add-Content -Path $LogPath -Value $logEntry
            
            switch ($Level) {
                "ERROR" { Write-Host $logEntry -ForegroundColor Red }
                "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
                "INFO" { Write-Host $logEntry -ForegroundColor Cyan }
                "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
                default { Write-Host $logEntry -ForegroundColor White }
            }
        }
        
        Write-ResolutionLog "Starting issue resolution monitoring for Issue #$IssueNumber, PR #$PullRequestNumber" "INFO"
    }
    
    process {
        function Get-PullRequestStatus {
            param([int]$PrNumber)
            
            try {
                $prInfo = gh pr view $PrNumber --json state,merged,mergedAt,closedAt,title,url | ConvertFrom-Json
                return @{
                    Success = $true
                    State = $prInfo.state
                    Merged = $prInfo.merged
                    MergedAt = $prInfo.mergedAt
                    ClosedAt = $prInfo.closedAt
                    Title = $prInfo.title
                    Url = $prInfo.url
                }
            } catch {
                Write-ResolutionLog "Error getting PR status: $($_.Exception.Message)" "ERROR"
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        function Resolve-IssueBasedOnPRStatus {
            param($PrStatus, [int]$IssueNum)
            
            try {
                if ($PrStatus.State -eq "MERGED" -and $PrStatus.Merged) {
                    # PR was merged - close the issue as resolved
                    Write-ResolutionLog "PR #$PullRequestNumber was merged, closing issue as resolved" "SUCCESS"
                    
                    $closeComment = @"
## ✅ Issue Resolved

**Pull Request Merged**: $($PrStatus.Url)
**Merged At**: $($PrStatus.MergedAt)

This issue has been automatically resolved because the associated pull request was successfully merged.

### Summary
- **Status**: ✅ Resolved
- **Resolution Method**: Pull request merge
- **PR Title**: $($PrStatus.Title)

The changes are now part of the main codebase. This issue is being closed automatically.
"@
                    
                    # Add comment and close issue
                    gh issue comment $IssueNum --body $closeComment | Out-Null
                    gh issue close $IssueNum --reason "completed" | Out-Null
                    
                    Write-ResolutionLog "Issue #$IssueNum closed as resolved (PR merged)" "SUCCESS"
                    return @{ Success = $true; Action = "Closed"; Reason = "PR merged" }
                    
                } elseif ($PrStatus.State -eq "CLOSED" -and -not $PrStatus.Merged) {
                    # PR was closed but not merged - keep issue open
                    Write-ResolutionLog "PR #$PullRequestNumber was closed without merging, keeping issue open" "WARN"
                    
                    $keepOpenComment = @"
## ⚠️ Pull Request Closed Without Merge

**Pull Request**: $($PrStatus.Url)
**Closed At**: $($PrStatus.ClosedAt)

The associated pull request was closed without being merged. **This issue remains open** because the underlying problem still needs to be addressed.

### Next Steps
- 🔄 **Reopen PR**: If this was closed by mistake, the PR can be reopened
- 🆕 **New PR**: Create a new pull request with different approach
- 🔍 **Investigation**: Determine why the PR was not suitable for merge

### Status
- **Issue Status**: 🔓 **Remains Open**
- **Reason**: PR closed without merge - bug still needs fixing
- **PR Title**: $($PrStatus.Title)

This issue will remain open until a successful fix is merged.
"@
                    
                    # Add comment but keep issue open
                    gh issue comment $IssueNum --body $keepOpenComment | Out-Null
                    
                    Write-ResolutionLog "Issue #$IssueNum kept open (PR closed without merge)" "WARN"
                    return @{ Success = $true; Action = "KeptOpen"; Reason = "PR closed without merge" }
                    
                } else {
                    # PR is still open - continue monitoring
                    Write-ResolutionLog "PR #$PullRequestNumber still open, continuing to monitor" "INFO"
                    return @{ Success = $true; Action = "Continue"; Reason = "PR still open" }
                }
                
            } catch {
                Write-ResolutionLog "Error resolving issue based on PR status: $($_.Exception.Message)" "ERROR"
                return @{ Success = $false; Error = $_.Exception.Message }
            }
        }
        
        function Start-ResolutionMonitoring {
            param([int]$IntervalSeconds, [int]$MaxHours)
            
            $startTime = Get-Date
            $endTime = $startTime.AddHours($MaxHours)
            $checkCount = 0
            
            Write-ResolutionLog "Starting resolution monitoring (interval: ${IntervalSeconds}s, max duration: ${MaxHours}h)" "INFO"
            
            while ((Get-Date) -lt $endTime) {
                $checkCount++
                Write-ResolutionLog "Resolution check #$checkCount" "INFO"
                
                # Get current PR status
                $prStatus = Get-PullRequestStatus -PrNumber $PullRequestNumber
                
                if (-not $prStatus.Success) {
                    Write-ResolutionLog "Failed to get PR status, will retry next cycle" "WARN"
                } else {
                    # Process based on current status
                    $resolution = Resolve-IssueBasedOnPRStatus -PrStatus $prStatus -IssueNum $IssueNumber
                    
                    if ($resolution.Success) {
                        if ($resolution.Action -in @("Closed", "KeptOpen")) {
                            Write-ResolutionLog "Issue resolution completed: $($resolution.Action) - $($resolution.Reason)" "SUCCESS"
                            break  # Monitoring complete
                        }
                        # Continue monitoring for "Continue" action
                    } else {
                        Write-ResolutionLog "Error in resolution processing: $($resolution.Error)" "ERROR"
                    }
                }
                
                # Wait for next check (unless we're done)
                if ((Get-Date) -lt $endTime) {
                    Write-ResolutionLog "Waiting $IntervalSeconds seconds until next check..." "INFO"
                    Start-Sleep -Seconds $IntervalSeconds
                }
            }
            
            if ($checkCount -gt 0) {
                Write-ResolutionLog "Resolution monitoring completed after $checkCount checks" "INFO"
            }
            
            # Check if we timed out
            if ((Get-Date) -ge $endTime) {
                Write-ResolutionLog "Monitoring timed out after $MaxHours hours" "WARN"
                
                # Add timeout comment to issue
                $timeoutComment = @"
## ⏰ Issue Resolution Monitoring Timeout

The automatic issue resolution monitoring has timed out after $MaxHours hours.

**Status**: The associated PR #$PullRequestNumber may still be under review.

### Manual Check Required
Please manually check the PR status and close this issue if appropriate:
- If PR is merged → Close this issue
- If PR is closed without merge → Keep this issue open for resubmission
- If PR is still under review → Monitor manually or restart monitoring

**Note**: This timeout does not affect the PR review process.
"@
                
                try {
                    gh issue comment $IssueNumber --body $timeoutComment | Out-Null
                    Write-ResolutionLog "Added timeout comment to issue" "INFO"
                } catch {
                    Write-ResolutionLog "Failed to add timeout comment: $($_.Exception.Message)" "ERROR"
                }
            }
        }
        
        # Start the monitoring process
        Start-ResolutionMonitoring -IntervalSeconds $MonitorInterval -MaxHours $MaxMonitorHours
    }
    
    end {
        Write-ResolutionLog "Issue resolution handler completed" "INFO"
    }
}

# Export the function


