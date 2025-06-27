#Requires -Version 7.0
<#
.SYNOPSIS
    Error handling module for PatchManager

.DESCRIPTION
    Provides standardized error handling functions for PatchManager operations
    including logging, structured error objects, and recovery operations.

.NOTES
    - Integrated with GitHub issue reporting
    - Creates comprehensive error logs
    - Provides recovery suggestions
    - Tagged error categorization
#>

function HandlePatchError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord = $null,
        [Parameter(Mandatory = $false)]
        [ValidateSet("Git", "PatchValidation", "BranchStrategy", "PullRequest", "Rollback", "General")]
        [string]$ErrorCategory = "General",

        [Parameter(Mandatory = $false)]
        [string]$LogPath = "logs/patch-errors.log",

        [Parameter(Mandatory = $false)]
        [switch]$Silent = $false,

        [Parameter(Mandatory = $false)]
        [int]$IssueNumber = $null
    )

    # Create log directory if needed
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
            if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    }

    # Construct timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Create error log entry
    $logEntry = @"
[$timestamp] [$ErrorCategory] ERROR:
$ErrorMessage

"@

    # Add error record details if available
    if ($ErrorRecord) {
        $logEntry += @"
Exception: $($ErrorRecord.Exception.GetType().FullName)
Stack Trace:
$($ErrorRecord.ScriptStackTrace)

"@
    }

    # Write to log file
    $logEntry | Out-File -FilePath $LogPath -Append

    # Display error unless silent mode is enabled
    if (-not $Silent) {
        Write-Host "[$ErrorCategory] Error: $ErrorMessage" -ForegroundColor Red

        if ($ErrorRecord) {
            Write-Host "See $LogPath for details" -ForegroundColor Yellow
        }
    }
    # Update GitHub issue if provided
    if ($IssueNumber) {
        try {
            # Build suggested actions based on error category
            $suggestedActions = switch ($ErrorCategory) {
                "Git" { "- Check Git repository status and permissions" }
                "PatchValidation" { "- Review changes for syntax errors or validation issues" }
                "BranchStrategy" { "- Verify branch naming and repository structure" }
                "PullRequest" { "- Ensure GitHub permissions are correct" }
                "Rollback" { "- Manual intervention may be required" }
                default { "- Review error details and logs" }
            }

            $issueComment = @"
##  FAILError Encountered

**Category**: $ErrorCategory
**Time**: $timestamp
**Details**: $ErrorMessage

### Suggested Actions
$suggestedActions
- Review error log for detailed troubleshooting
"@

            # Use GitHub CLI to add comment
            gh issue comment $IssueNumber --body $issueComment 2>&1 | Out-Null
        } catch {
            # Silently continue if GitHub issue update fails
            $issueUpdateError = "Failed to update GitHub issue: $($_.Exception.Message)"
            $issueUpdateError | Out-File -FilePath $LogPath -Append
        }
    }

    # Create structured error object
    $errorObject = [PSCustomObject]@{
        Timestamp   = $timestamp
        Category    = $ErrorCategory
        Message     = $ErrorMessage
        Exception   = $ErrorRecord?.Exception
        StackTrace  = $ErrorRecord?.ScriptStackTrace
        LogPath     = $LogPath
        IssueNumber = $IssueNumber
    }
    return $errorObject
}

# Write-PatchLog function removed to avoid conflicts with internal functions
# Use Write-CustomLog from the centralized Logging module instead

# Note: Export-ModuleMember is handled by the parent module
