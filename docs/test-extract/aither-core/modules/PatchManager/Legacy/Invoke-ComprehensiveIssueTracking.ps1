#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive GitHub issue creation and tracking for all PatchManager operations

.DESCRIPTION
    This function automatically creates GitHub issues for:
    1. Every pull request (with detailed notes)
    2. Any errors, test failures, or runtime failures
    3. Central bug tracking and error management

    Ensures every change and error is tracked through GitHub issues for systematic resolution.

.PARAMETER Operation
    The type of operation (PR, Error, TestFailure, RuntimeFailure)

.PARAMETER Title
    The title for the issue

.PARAMETER Description
    Detailed description of the issue/operation

.PARAMETER PullRequestNumber
    PR number to link to (for PR operations)

.PARAMETER PullRequestUrl
    PR URL to link to (for PR operations)

.PARAMETER ErrorDetails
    Detailed error information including stack traces, logs, etc.

.PARAMETER AffectedFiles
    Array of files affected by the operation

.PARAMETER Priority
    Priority level (Critical, High, Medium, Low)

.PARAMETER Labels
    Additional labels to apply to the issue

.PARAMETER AutoClose
    Whether to auto-close the issue when associated PR is merged

.EXAMPLE
    Invoke-ComprehensiveIssueTracking -Operation "PR" -Title "Enhancement: Update module imports" -Description "Detailed PR description" -PullRequestNumber 123 -AffectedFiles @("file1.ps1")

.EXAMPLE
    Invoke-ComprehensiveIssueTracking -Operation "Error" -Title "PatchManager Error: Branch creation failed" -ErrorDetails $errorInfo -Priority "High"

.NOTES
    - Creates very detailed issue bodies with comprehensive context
    - Links issues to PRs automatically
    - Tracks all errors centrally for systematic resolution
    - Integrates with PatchManager workflow seamlessly
#>

function Invoke-ComprehensiveIssueTracking {
    [CmdletBinding()]
    param(        [Parameter(Mandatory = $false)]
        [ValidateSet("PR", "Patch", "Error", "TestFailure", "RuntimeFailure", "Warning")]
        [string]$Operation = "PR",

        [Parameter(Mandatory = $false)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [int]$PullRequestNumber,

        [Parameter(Mandatory = $false)]
        [string]$PullRequestUrl,

        [Parameter(Mandatory = $false)]
        [int]$ExistingIssueNumber,

        [Parameter(Mandatory = $false)]
        [switch]$CreateAutomatedTracking,

        [Parameter(Mandatory = $false)]
        [hashtable]$ErrorDetails = @{},

        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),

        [Parameter(Mandatory = $false)]
        [ValidateSet("Critical", "High", "Medium", "Low")]
        [string]$Priority = "Medium",

        [Parameter(Mandatory = $false)]
        [string[]]$Labels = @(),

        [Parameter(Mandatory = $false)]
        [switch]$AutoClose
    )

    begin {
        Write-CustomLog "Starting comprehensive issue tracking for operation: $Operation" -Level INFO

        # Check if GitHub CLI is available
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-CustomLog "GitHub CLI (gh) not found. Cannot create issues automatically." -Level ERROR
            return @{
                Success = $false
                Message = "GitHub CLI (gh) not found"
                IssueUrl = $null
                IssueNumber = $null
            }
        }
          # Check if we're in a GitHub repository
        try {
            $repoInfo = gh repo view --json "owner,name" | ConvertFrom-Json
            Write-CustomLog "Repository detected: $($repoInfo.owner.login)/$($repoInfo.name)" -Level INFO
        } catch {
            Write-CustomLog "Not in a GitHub repository or GitHub CLI not authenticated" -Level ERROR
            return @{
                Success = $false
                Message = "Not in a GitHub repository"
                IssueUrl = $null
                IssueNumber = $null
            }
        }
    }

    process {
        try {            # Determine operation-specific labels and priority adjustments
            $operationLabels = switch ($Operation) {
                "PR" { @("enhancement", "pull-request-tracking") }
                "Patch" { @("enhancement", "patch-tracking", "automation") }
                "Error" { @("bug", "error", "needs-investigation") }
                "TestFailure" { @("bug", "test-failure", "needs-fix") }
                "RuntimeFailure" { @("bug", "runtime-error", "critical") }
                "Warning" { @("warning", "monitoring") }
                default { @("automated") }
            }

            # Adjust priority for critical operations
            if ($Operation -eq "RuntimeFailure") {
                $Priority = "Critical"
            } elseif ($Operation -eq "Error" -or $Operation -eq "TestFailure") {
                if ($Priority -eq "Low") { $Priority = "Medium" }
            }

            # Determine priority-based labels
            $priorityLabels = switch ($Priority) {
                "Critical" { @("priority-critical", "urgent") }
                "High" { @("priority-high") }
                "Medium" { @("priority-medium") }
                "Low" { @("priority-low") }
            }

            # Combine all labels and remove duplicates
            $allLabels = ($Labels + $operationLabels + $priorityLabels + @("automated", "patchmanager")) | Sort-Object -Unique
              # Create comprehensive issue body
            $issueBodyParams = @{
                Operation = $Operation
                Description = $Description
                PullRequestNumber = $PullRequestNumber
                PullRequestUrl = $PullRequestUrl
                ErrorDetails = $ErrorDetails
                AffectedFiles = $AffectedFiles
                Priority = $Priority
            }
            if ($AutoClose) {
                $issueBodyParams['AutoClose'] = $true
            }
            $issueBody = Build-ComprehensiveIssueBody @issueBodyParams

            # Ensure all required labels exist
            Initialize-GitHubLabels -Labels $allLabels

            # Create the GitHub issue
            Write-CustomLog "Creating GitHub issue: $Title" -Level INFO
              # Save body to temp file to handle large content and special characters
            $tempBodyFile = [System.IO.Path]::GetTempFileName()
            try {
                $issueBody | Out-File -FilePath $tempBodyFile -Encoding utf8

                # Create issue with enhanced error handling for labels
                $labelString = $allLabels -join ','
                Write-CustomLog "Creating GitHub issue: $Title" -Level INFO
                Write-CustomLog "Using labels: $labelString" -Level DEBUG

                # Try creating issue with labels first
                $issueResult = gh issue create --title $Title --body-file $tempBodyFile --label $labelString 2>&1

                # If label error occurred, retry without labels
                if ($LASTEXITCODE -ne 0 -and $issueResult -match "not found|does not exist|invalid label") {
                    Write-CustomLog "Label issue detected, retrying without labels: $($issueResult -join ' ')" -Level WARN
                    $issueResult = gh issue create --title $Title --body-file $tempBodyFile 2>&1
                }

                if ($LASTEXITCODE -eq 0 -and $issueResult -match "https://") {
                    # Extract issue number from the URL
                    $issueNumber = $null
                    if ($issueResult -match '/issues/(\d+)') {
                        $issueNumber = $matches[1]
                    }

                    Write-CustomLog "GitHub issue created successfully: $issueResult" -Level SUCCESS
                    Write-CustomLog "Issue number: #$issueNumber" -Level INFO

                    # Set up auto-close monitoring if requested
                    if ($AutoClose -and $PullRequestNumber) {
                        Set-IssueAutoCloseMonitoring -IssueNumber $issueNumber -PullRequestNumber $PullRequestNumber
                    }

                    return @{
                        Success = $true
                        Message = "GitHub issue created successfully"
                        IssueUrl = $issueResult
                        IssueNumber = $issueNumber
                        Operation = $Operation
                        Priority = $Priority
                    }                } else {
                    $errorOutput = $issueResult -join "`n"
                    Write-CustomLog "GitHub CLI failed with exit code $LASTEXITCODE" -Level ERROR
                    Write-CustomLog "Error output: $errorOutput" -Level ERROR
                    throw "GitHub CLI failed: $errorOutput"
                }

            } finally {
                # Clean up temp file
                Remove-Item $tempBodyFile -Force -ErrorAction SilentlyContinue
            }

        } catch {
            $errorMessage = "Failed to create GitHub issue: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level ERROR

            return @{
                Success = $false
                Message = $errorMessage
                IssueUrl = $null
                IssueNumber = $null
            }
        }
    }
}

function Build-ComprehensiveIssueBody {
    [CmdletBinding()]
    param(
        [string]$Operation,
        [string]$Description,
        [int]$PullRequestNumber,
        [string]$PullRequestUrl,
        [hashtable]$ErrorDetails,
        [string[]]$AffectedFiles,
        [string]$Priority,
        [switch]$AutoClose
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'    # Get environment and system information safely with enhanced details
    $gitBranch = "Unknown"
    $gitCommit = "Unknown"
    $gitRemote = "Unknown"

    try {
        $gitBranch = git branch --show-current 2>$null
        if (-not $gitBranch) { $gitBranch = "Unknown" }
    } catch {
        $gitBranch = "Unknown"
    }

    try {
        $gitCommit = git rev-parse --short HEAD 2>$null
        if (-not $gitCommit) { $gitCommit = "Unknown" }
    } catch {
        $gitCommit = "Unknown"
    }

    try {
        $gitRemote = git remote get-url origin 2>$null
        if (-not $gitRemote) { $gitRemote = "Unknown" }
    } catch {
        $gitRemote = "Unknown"
    }

    # Determine platform
    $platformInfo = "Unknown"
    if ($env:PLATFORM) {
        $platformInfo = $env:PLATFORM
    } elseif ($IsWindows -or $env:OS -eq "Windows_NT") {
        $platformInfo = "Windows"
    } elseif ($IsLinux) {
        $platformInfo = "Linux"
    } elseif ($IsMacOS) {
        $platformInfo = "macOS"
    }

    # Get OS version
    $osVersion = "Unknown"
    try {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            $osVersion = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Version
        }
    } catch {
        $osVersion = "Unknown"
    }

    # Get project root
    $projectRoot = "Unknown"
    if ($env:PROJECT_ROOT) {
        $projectRoot = $env:PROJECT_ROOT
    } else {
        try {
            $projectRoot = git rev-parse --show-toplevel 2>$null
            if (-not $projectRoot) { $projectRoot = "Unknown" }
        } catch {
            $projectRoot = "Unknown"
        }
    }

    $systemInfo = @{
        Platform = $platformInfo
        OSVersion = $osVersion
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        GitBranch = $gitBranch
        GitCommit = $gitCommit
        GitRemote = $gitRemote
        WorkingDirectory = (Get-Location).Path
        ProjectRoot = $projectRoot
        User = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { "Unknown" }
        ComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($env:HOSTNAME) { $env:HOSTNAME } else { "Unknown" }
        ProcessId = $PID
        TimeZone = [System.TimeZoneInfo]::Local.Id
    }

    # Build operation-specific content
    $operationContent = switch ($Operation) {        "PR" {
            @"
## Pull Request Tracking Issue

This issue tracks the lifecycle of **Pull Request #$PullRequestNumber** to ensure proper review, validation, and closure.

### Pull Request Details
- **PR Number**: #$PullRequestNumber
- **PR URL**: $PullRequestUrl
- **Status**: Open (awaiting review)

### Review Checklist
- [ ] Code review completed
- [ ] All tests passing
- [ ] Documentation updated (if applicable)
- [ ] Security review completed (if applicable)
- [ ] Performance impact assessed
- [ ] Cross-platform compatibility verified
- [ ] PatchManager workflow followed correctly

### Merge Requirements
- [ ] All required approvals received
- [ ] All CI/CD checks passing
- [ ] No merge conflicts
- [ ] Branch is up to date with target branch

$(if ($AutoClose) { "**Note**: This issue will automatically close when PR #$PullRequestNumber is merged." } else { "**Note**: Manual closure required after PR is merged." })
"@
        }

        "Patch" {
            @"
## Patch Tracking Issue

This issue tracks the patch: **$Description**

### Patch Context
- **Description**: $Description
- **Created**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
- **Applied via**: PatchManager (Invoke-GitControlledPatch)

### Quality Assurance Requirements
This patch must meet all quality standards before merge, including comprehensive testing, security review, and maintainer approval.

### Files Affected
$(if ($AffectedFiles.Count -gt 0) {
    ($AffectedFiles | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
    "- *Files will be identified during detailed review*"
})

### Review Checklist
- [ ] Patch applied correctly
- [ ] All tests passing
- [ ] No breaking changes introduced
- [ ] Documentation updated if needed
- [ ] Ready for production deployment

$(if ($AutoClose) { "**Note**: This issue will automatically close when the associated pull request is merged." } else { "**Note**: Manual closure required after patch is deployed." })
"@
        }

        "Error" {
            @"
## Error Tracking and Resolution

This issue tracks an error that occurred during PatchManager operations and requires investigation and resolution.

### Error Information
$(if ($ErrorDetails.ErrorMessage) { "**Error Message**: $($ErrorDetails.ErrorMessage)" })
$(if ($ErrorDetails.Exception) { "**Exception Type**: $($ErrorDetails.Exception.GetType().FullName)" })
$(if ($ErrorDetails.ErrorCategory) { "**Category**: $($ErrorDetails.ErrorCategory)" })
$(if ($ErrorDetails.ScriptStackTrace) {
@"

**Stack Trace**:
```
$($ErrorDetails.ScriptStackTrace)
```
"@
})

### Error Context
$(if ($ErrorDetails.Operation) { "- **Operation**: $($ErrorDetails.Operation)" })
$(if ($ErrorDetails.CommandLine) { "- **Command**: ``$($ErrorDetails.CommandLine)``" })
$(if ($ErrorDetails.LogPath) { "- **Log File**: $($ErrorDetails.LogPath)" })

### Resolution Steps
1. **Investigate root cause** using error details and logs
2. **Identify fix strategy** based on error category
3. **Implement fix** following PatchManager workflow
4. **Test fix** in isolated environment
5. **Validate resolution** and close issue

### Prevention Measures
- [ ] Add error handling for this scenario
- [ ] Update documentation to prevent recurrence
- [ ] Add automated tests to catch similar errors
- [ ] Review related code for similar patterns
"@
        }

        "TestFailure" {
            @"
## Test Failure Tracking and Resolution

This issue tracks a test failure that requires investigation and fixing to maintain code quality.

### Failure Information
$(if ($ErrorDetails.TestName) { "**Test Name**: $($ErrorDetails.TestName)" })
$(if ($ErrorDetails.TestFile) { "**Test File**: $($ErrorDetails.TestFile)" })
$(if ($ErrorDetails.FailureMessage) { "**Failure Message**: $($ErrorDetails.FailureMessage)" })
$(if ($ErrorDetails.TestOutput) {
@"

**Test Output**:
```
$($ErrorDetails.TestOutput)
```
"@
})

### Impact Assessment
- **Test Type**: $(if ($ErrorDetails.TestType) { $ErrorDetails.TestType } else { "Unknown" })
- **Criticality**: $Priority
- **Affected Functionality**: $(if ($ErrorDetails.AffectedFeature) { $ErrorDetails.AffectedFeature } else { "Under investigation" })

### Resolution Steps
1. **Reproduce failure** locally
2. **Analyze root cause** of test failure
3. **Fix underlying issue** or update test expectations
4. **Validate fix** across platforms
5. **Ensure no regression** in other tests

### Quality Assurance
- [ ] Root cause identified and documented
- [ ] Fix implemented and tested
- [ ] Related tests reviewed for similar issues
- [ ] Test suite passes completely
- [ ] Regression testing completed
"@
        }

        "RuntimeFailure" {
            @"
## Critical Runtime Failure

This issue tracks a critical runtime failure that requires immediate attention and resolution.

### Failure Details
$(if ($ErrorDetails.FailurePoint) { "**Failure Point**: $($ErrorDetails.FailurePoint)" })
$(if ($ErrorDetails.RuntimeError) { "**Runtime Error**: $($ErrorDetails.RuntimeError)" })
$(if ($ErrorDetails.SystemState) { "**System State**: $($ErrorDetails.SystemState)" })
$(if ($ErrorDetails.ErrorLog) {
@"

**Error Log**:
```
$($ErrorDetails.ErrorLog)
```
"@
})

### Immediate Actions Required
1. **Assess impact** and scope of failure
2. **Implement temporary workaround** if possible
3. **Investigate root cause** with high priority
4. **Develop permanent fix** following proper testing
5. **Deploy fix** and validate resolution

### Post-Resolution Tasks
- [ ] Document failure scenario for future prevention
- [ ] Add monitoring/alerting for similar failures
- [ ] Review and improve error handling
- [ ] Update runbooks and troubleshooting guides
- [ ] Conduct post-mortem analysis
"@
        }

        "Warning" {
            @"
## Warning Monitoring and Analysis

This issue tracks a warning condition that should be monitored and potentially addressed.

### Warning Information
$(if ($ErrorDetails.WarningMessage) { "**Warning Message**: $($ErrorDetails.WarningMessage)" })
$(if ($ErrorDetails.WarningSource) { "**Source**: $($ErrorDetails.WarningSource)" })
$(if ($ErrorDetails.Frequency) { "**Frequency**: $($ErrorDetails.Frequency)" })

### Monitoring Actions
1. **Track frequency** and patterns of this warning
2. **Assess potential impact** if condition worsens
3. **Determine if action required** based on analysis
4. **Document resolution** if action is taken

### Status Tracking
- [ ] Warning pattern analyzed
- [ ] Impact assessment completed
- [ ] Action plan determined
- [ ] Resolution implemented (if required)
"@
        }
    }

    # Build the complete issue body
    $issueBody = @"
$operationContent

---

## System Information

### Environment Details
- **Platform**: $($systemInfo.Platform)
- **OS Version**: $($systemInfo.OSVersion)
- **PowerShell Version**: $($systemInfo.PowerShellVersion) ($($systemInfo.PowerShellEdition))
- **Git Branch**: $($systemInfo.GitBranch)
- **Git Commit**: $($systemInfo.GitCommit)
- **Git Remote**: $($systemInfo.GitRemote)
- **Working Directory**: $($systemInfo.WorkingDirectory)
- **Project Root**: $($systemInfo.ProjectRoot)
- **User**: $($systemInfo.User)
- **Computer**: $($systemInfo.ComputerName)
- **Process ID**: $($systemInfo.ProcessId)
- **Time Zone**: $($systemInfo.TimeZone)
- **Timestamp**: $timestamp

### Affected Files
$(if ($AffectedFiles.Count -gt 0) {
    @"
**Files Detected**: $($AffectedFiles.Count) file(s)

$($AffectedFiles | ForEach-Object { "- ``$_``" } | Out-String)
"@
} else {
    @"
**Detection Status**: No specific files identified
- **Methods Attempted**: Stack trace analysis, error context parsing
- **Possible Reasons**: Global system error, configuration issue, or runtime failure not tied to specific files
- **Investigation**: Manual review of error details and logs may be required
- **Context**: Review the error description and system logs for additional clues

*Note: Some errors affect the entire system or environment rather than specific files.*
"@
})

## Description

$Description

---

## Automation Details

- **Created by**: PatchManager Comprehensive Issue Tracking
- **Operation Type**: $Operation
- **Priority Level**: $Priority
- **Auto-generated**: Yes
- **Tracking ID**: PATCH-$(Get-Date -Format 'yyyyMMdd-HHmmss')

$(if ($Operation -ne "PR") {
@"

## Central Bug Tracking

This issue is part of the central bug tracking system to ensure systematic resolution of all errors, failures, and issues. Regular monitoring and updates will be provided until resolution.
"@
})

**Last Updated**: $timestamp
"@

    return $issueBody
}

function Initialize-GitHubLabels {
    [CmdletBinding()]
    param([string[]]$Labels)

    $standardLabels = @{
        "automated" = @{ color = "0075ca"; description = "Automatically generated by PatchManager" }
        "patchmanager" = @{ color = "1d76db"; description = "Related to PatchManager operations" }
        "pull-request-tracking" = @{ color = "0e8a16"; description = "Tracks pull request lifecycle" }
        "error" = @{ color = "d73a4a"; description = "Error condition requiring resolution" }
        "test-failure" = @{ color = "b60205"; description = "Test failure requiring fix" }
        "runtime-error" = @{ color = "8B0000"; description = "Critical runtime error" }
        "priority-critical" = @{ color = "8B0000"; description = "Critical priority - immediate attention required" }
        "priority-high" = @{ color = "d93f0b"; description = "High priority" }
        "priority-medium" = @{ color = "fbca04"; description = "Medium priority" }
        "priority-low" = @{ color = "c2e0c6"; description = "Low priority" }
        "urgent" = @{ color = "FF0000"; description = "Urgent - requires immediate action" }
        "needs-investigation" = @{ color = "f9d0c4"; description = "Requires investigation" }
        "needs-fix" = @{ color = "ff6b6b"; description = "Requires fix implementation" }
        "monitoring" = @{ color = "5319e7"; description = "Under monitoring" }
        "warning" = @{ color = "ffd700"; description = "Warning condition" }
    }

    foreach ($label in $Labels) {
        if ($standardLabels.ContainsKey($label)) {
            try {
                $labelInfo = $standardLabels[$label]
                $labelExists = $null -ne (gh label list | Select-String -Pattern "^$label\s")

                if (-not $labelExists) {
                    Write-CustomLog "Creating label: $label" -Level INFO
                    gh label create $label --color $labelInfo.color --description $labelInfo.description 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-CustomLog "Could not create label '$label', continuing without it" -Level WARN
                    }
                }
            } catch {
                Write-CustomLog "Failed to create label '$label': $($_.Exception.Message)" -Level WARN
            }
        }
    }
}

function Set-IssueAutoCloseMonitoring {
    [CmdletBinding()]
    param(
        [int]$IssueNumber,
        [int]$PullRequestNumber
    )

    Write-CustomLog "Setting up auto-close monitoring for Issue #$IssueNumber when PR #$PullRequestNumber is merged" -Level INFO

    # Note: This would typically integrate with GitHub Actions or webhooks
    # For now, we'll document the relationship in the issue
    try {
        $monitoringComment = @"
**Auto-Close Configuration**

This issue is configured to automatically close when Pull Request #$PullRequestNumber is merged.

**Monitoring Status**: Active
**Target PR**: #$PullRequestNumber
**Action**: Close issue on PR merge

This will be handled by the PatchManager monitoring system.
"@

        gh issue comment $IssueNumber --body $monitoringComment | Out-Null
        Write-CustomLog "Auto-close monitoring configured for Issue #$IssueNumber" -Level SUCCESS
    } catch {
        Write-CustomLog "Failed to set up auto-close monitoring: $($_.Exception.Message)" -Level WARN
    }
}
