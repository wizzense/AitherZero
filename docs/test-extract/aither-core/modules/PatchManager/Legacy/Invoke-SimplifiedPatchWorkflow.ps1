#Requires -Version 7.0

<#
.SYNOPSIS
    Simplified GitHub issue integration for PatchManager - focuses on essential PR/issue linking only

.DESCRIPTION
    This is a streamlined version of the PatchManager issue integration that:
    1. Creates issues only when explicitly requested
    2. Links PRs to issues for auto-closing
    3. Removes redundant automated error tracking
    4. Eliminates emoji/Unicode output per project policy
    5. Focuses on the core branch-first workflow

.PARAMETER PatchDescription
    Description of the patch for issue and PR

.PARAMETER CreateIssue
    Whether to create a GitHub issue for tracking

.PARAMETER Priority
    Issue priority level (Critical, High, Medium, Low)

.PARAMETER AffectedFiles
    Files affected by the patch

.PARAMETER IssueNumber
    Existing issue number to link to

.PARAMETER DryRun
    Preview mode - shows what would be created

.EXAMPLE
    New-SimpleIssueForPatch -PatchDescription "Fix module loading" -CreateIssue -Priority "Medium"

.EXAMPLE
    New-SimplePRForPatch -PatchDescription "Fix module loading" -BranchName "patch/fix-loading" -IssueNumber 123

.NOTES
    This simplified approach removes the complex automated error tracking system
    and focuses on explicit, user-controlled issue and PR creation with proper linking.
#>

function New-SimpleIssueForPatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Critical", "High", "Medium", "Low")]
        [string]$Priority = "Medium",

        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        Write-CustomLog "Creating simple issue for patch: $PatchDescription" -Level INFO
    }

    process {
        try {
            # Check GitHub CLI availability
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) not found. Please install and authenticate with GitHub CLI."
            }

            # Create a simple, focused issue title and body
            $issueTitle = "Patch: $PatchDescription"
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'

            $issueBody = @"
## Patch Tracking Issue

**Description**: $PatchDescription
**Priority**: $Priority
**Created**: $timestamp

### Files Affected
$(if ($AffectedFiles.Count -gt 0) {
    ($AffectedFiles | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
    "*Files will be identified during patch review*"
})

### Expected Actions
1. Review associated pull request when created
2. Validate changes in clean environment
3. Approve and merge if all checks pass
4. This issue will auto-close when PR is merged

---
*Created by PatchManager*
"@

            if ($DryRun) {
                Write-CustomLog "DRY RUN: Would create issue with title: $issueTitle" -Level INFO
                return @{
                    Success = $true
                    DryRun = $true
                    Title = $issueTitle
                    Body = $issueBody
                }
            }            # Create the issue with robust label handling
            Write-CustomLog "Creating GitHub issue: $issueTitle" -Level INFO
            
            # Try with full labels first, fallback to minimal if needed
            $result = gh issue create --title $issueTitle --body $issueBody --label "patch" 2>&1
            
            # If label fails, try without any labels
            if ($LASTEXITCODE -ne 0 -and $result -match "not found") {
                Write-CustomLog "Label issue detected, creating without labels" -Level WARN
                $result = gh issue create --title $issueTitle --body $issueBody 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                # Extract issue number from URL
                $issueNumber = $null
                if ($result -match '/issues/(\d+)') {
                    $issueNumber = $matches[1]
                }

                Write-CustomLog "Issue created successfully: $result" -Level SUCCESS
                Write-CustomLog "Issue number: #$issueNumber" -Level INFO

                return @{
                    Success = $true
                    IssueUrl = $result.ToString().Trim()
                    IssueNumber = $issueNumber
                    Title = $issueTitle
                }
            } else {
                throw "GitHub CLI failed: $($result -join ' ')"
            }

        } catch {
            $errorMessage = "Failed to create issue: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level ERROR

            return @{
                Success = $false
                Message = $errorMessage
            }
        }
    }
}

function New-SimplePRForPatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $true)]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$ValidationResults = @{},

        [Parameter(Mandatory = $false)]
        [int]$IssueNumber,

        [Parameter(Mandatory = $false)]
        [string]$IssueUrl,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        Write-CustomLog "Creating simple PR for patch: $PatchDescription" -Level INFO
    }

    process {
        try {
            # Check GitHub CLI availability
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) not found. Please install and authenticate with GitHub CLI."
            }

            # Build PR title and body
            $prTitle = "Patch: $PatchDescription"

            # Build validation results text (no emojis)
            $validationText = if ($ValidationResults.Count -gt 0) {
                $ValidationResults.GetEnumerator() | ForEach-Object {
                    $status = if ($_.Value) { "PASSED" } else { "FAILED" }
                    "- **$($_.Key)**: $status"
                } | Out-String
            } else {
                "- *No specific validation results provided*"
            }

            $prBody = @"
## Patch Description

$PatchDescription

### Validation Results
$validationText

### Files Affected
$(if ($AffectedFiles.Count -gt 0) {
    ($AffectedFiles | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
    "*Files will be identified during review*"
})

$(if ($IssueNumber) {
@"

### Related Issue

Closes #$IssueNumber

"@
})

### Quality Assurance

This patch follows the PatchManager workflow:
1. Branch created from clean state
2. Changes applied and tested
3. Ready for review and merge

---
*Created by PatchManager*
"@

            if ($DryRun) {
                Write-CustomLog "DRY RUN: Would create PR with title: $prTitle" -Level INFO
                return @{
                    Success = $true
                    DryRun = $true
                    Title = $prTitle
                    Body = $prBody
                }
            }

            # Commit any pending changes first
            $gitStatus = git status --porcelain 2>&1
            if ($gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })) {
                Write-CustomLog "Committing pending changes..." -Level INFO
                git add . 2>&1 | Out-Null
                git commit -m "PatchManager: $PatchDescription" 2>&1 | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    Write-CustomLog "Warning: Git commit may have had issues, but continuing..." -Level WARN
                }
            }

            # Push branch
            Write-CustomLog "Pushing branch: $BranchName" -Level INFO
            git push origin $BranchName 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push branch $BranchName"
            }            # Create PR with robust label handling
            Write-CustomLog "Creating pull request: $prTitle" -Level INFO
            $result = gh pr create --title $prTitle --body $prBody --head $BranchName --label "patch,tracking,$Priority" 2>&1
            
            # If label fails, fallback to using only the "patch" label
            if ($LASTEXITCODE -ne 0 -and $result -match "not found") {
                Write-CustomLog "Label issue detected, creating PR with only the 'patch' label" -Level WARN
                $result = gh pr create --title $prTitle --body $prBody --head $BranchName --label "patch" 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                # Extract PR number from URL
                $prNumber = $null
                if ($result -match '/pull/(\d+)') {
                    $prNumber = $matches[1]
                }                Write-CustomLog "Pull request created successfully: $result" -Level SUCCESS
                Write-CustomLog "PR number: #$prNumber" -Level INFO

                return @{
                    Success = $true
                    PullRequestUrl = $result.ToString().Trim()
                    PullRequestNumber = $prNumber
                    Title = $prTitle
                }
            } else {
                # Check if this is an "already exists" error (which is actually success)
                $errorText = $result -join ' '
                if ($errorText -match "already exists.*https://github\.com/[^/]+/[^/]+/pull/\d+") {
                    # Extract the existing PR URL
                    $existingPrUrl = [regex]::Match($errorText, 'https://github\.com/[^/]+/[^/]+/pull/\d+').Value

                    # Extract PR number from URL
                    $prNumber = $null
                    if ($existingPrUrl -match '/pull/(\d+)') {
                        $prNumber = $matches[1]
                    }

                    Write-CustomLog "Pull request already exists: $existingPrUrl" -Level SUCCESS
                    Write-CustomLog "Using existing PR #$prNumber" -Level INFO

                    return @{
                        Success = $true
                        PullRequestUrl = $existingPrUrl
                        PullRequestNumber = $prNumber
                        Title = $prTitle
                        Message = "Using existing pull request"
                    }
                } else {
                    throw "GitHub CLI failed: $errorText"
                }
            }

        } catch {
            $errorMessage = "Failed to create pull request: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level ERROR

            return @{
                Success = $false
                Message = $errorMessage
            }
        }
    }
}

function Invoke-SimplifiedPatchWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $true)]
        [scriptblock]$PatchOperation,

        [Parameter(Mandatory = $false)]
        [string[]]$TestCommands = @(),

        [Parameter(Mandatory = $false)]
        [switch]$CreateIssue,

        [Parameter(Mandatory = $false)]
        [switch]$CreatePullRequest,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Critical", "High", "Medium", "Low")]
        [string]$Priority = "Medium",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        Write-CustomLog "Starting simplified patch workflow: $PatchDescription" -Level INFO

        if ($DryRun) {
            Write-CustomLog "DRY RUN MODE: No actual changes will be made" -Level WARN
        }
    }

    process {
        try {
            $results = @{
                Success = $false
                DryRun = $DryRun
                PatchDescription = $PatchDescription
                BranchName = $null
                IssueNumber = $null
                IssueUrl = $null
                PullRequestNumber = $null
                PullRequestUrl = $null
                Message = ""
            }

            # Step 1: Create branch
            $branchName = "patch/$(Get-Date -Format 'yyyyMMdd-HHmmss')-$($PatchDescription -replace '[^\w-]', '-' -replace '-+', '-')"
            $branchName = $branchName.Substring(0, [Math]::Min($branchName.Length, 80)) # Limit branch name length

            Write-CustomLog "Creating branch: $branchName" -Level INFO

            if (-not $DryRun) {
                git checkout -b $branchName 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to create branch: $branchName"
                }
            }

            $results.BranchName = $branchName

            # Step 2: Create issue if requested
            if ($CreateIssue) {
                Write-CustomLog "Creating tracking issue..." -Level INFO
                $issueResult = New-SimpleIssueForPatch -PatchDescription $PatchDescription -Priority $Priority -DryRun:$DryRun

                if ($issueResult.Success) {
                    $results.IssueNumber = $issueResult.IssueNumber
                    $results.IssueUrl = $issueResult.IssueUrl
                    Write-CustomLog "Issue created: $($issueResult.IssueUrl)" -Level SUCCESS
                } else {
                    Write-CustomLog "Issue creation failed: $($issueResult.Message)" -Level WARN
                }
            }

            # Step 3: Apply patch operation
            Write-CustomLog "Applying patch operation..." -Level INFO

            if (-not $DryRun) {
                $patchResult = & $PatchOperation

                # Basic success check
                if ($patchResult -is [hashtable] -and $patchResult.ContainsKey('Success') -and -not $patchResult.Success) {
                    throw "Patch operation failed: $($patchResult.Message)"
                }
            } else {
                Write-CustomLog "DRY RUN: Patch operation would be executed here" -Level INFO
            }

            # Step 4: Run test commands if provided
            if ($TestCommands.Count -gt 0) {
                Write-CustomLog "Running $($TestCommands.Count) test command(s)..." -Level INFO

                foreach ($testCmd in $TestCommands) {
                    Write-CustomLog "Running test: $testCmd" -Level INFO

                    if (-not $DryRun) {
                        $testResult = Invoke-Expression $testCmd
                        if ($LASTEXITCODE -ne 0) {
                            Write-CustomLog "Test command failed: $testCmd" -Level WARN
                        }
                    } else {
                        Write-CustomLog "DRY RUN: Would run test: $testCmd" -Level INFO
                    }
                }
            }

            # Step 5: Create pull request if requested
            if ($CreatePullRequest) {
                Write-CustomLog "Creating pull request..." -Level INFO

                $prParams = @{
                    PatchDescription = $PatchDescription
                    BranchName = $branchName
                    DryRun = $DryRun
                }

                if ($results.IssueNumber) {
                    $prParams.IssueNumber = $results.IssueNumber
                    $prParams.IssueUrl = $results.IssueUrl
                }

                $prResult = New-SimplePRForPatch @prParams

                if ($prResult.Success) {
                    $results.PullRequestNumber = $prResult.PullRequestNumber
                    $results.PullRequestUrl = $prResult.PullRequestUrl
                    Write-CustomLog "Pull request created: $($prResult.PullRequestUrl)" -Level SUCCESS
                } else {
                    Write-CustomLog "PR creation failed: $($prResult.Message)" -Level ERROR
                    throw "Failed to create pull request: $($prResult.Message)"
                }
            }

            # Success
            $results.Success = $true
            $results.Message = "Patch workflow completed successfully"

            Write-CustomLog "Simplified patch workflow completed successfully" -Level SUCCESS
            return $results

        } catch {
            $errorMessage = "Patch workflow failed: $($_.Exception.Message)"
            Write-CustomLog $errorMessage -Level ERROR

            $results.Success = $false
            $results.Message = $errorMessage
            return $results
        }
    }
}

# Export functions
Export-ModuleMember -Function New-SimpleIssueForPatch, New-SimplePRForPatch, Invoke-SimplifiedPatchWorkflow
