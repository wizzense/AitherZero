#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Pull Request Manager Module
.DESCRIPTION
    Provides comprehensive pull request management capabilities using GitHub CLI.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:PRState = @{
    Repository = $null
    Templates = @{}
    AutoMergeQueue = @()
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"
$script:GitModule = Join-Path $PSScriptRoot "GitAutomation.psm1"

if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

if (Test-Path $script:GitModule) {
    Import-Module $script:GitModule -Force
}

function Write-PRLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "PullRequestManager" -Data $Data
    } else {
        Write-Host "[$Level] $Message"
    }
}

function New-PullRequest {
    <#
    .SYNOPSIS
        Create a new pull request
    .DESCRIPTION
        Creates a new pull request with support for templates, reviewers, and auto-merge.
    .PARAMETER Title
        Pull request title
    .PARAMETER Body
        Pull request body/description
    .PARAMETER Base
        Base branch (default: main)
    .PARAMETER Head
        Head branch (default: current branch)
    .PARAMETER Draft
        Create as draft PR
    .PARAMETER Reviewers
        Array of reviewers to request
    .PARAMETER Assignees
        Array of assignees
    .PARAMETER Labels
        Array of labels to apply
    .PARAMETER Milestone
        Milestone to assign
    .PARAMETER AutoMerge
        Enable auto-merge when checks pass
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [string]$Body,

        [string]$Base,

        [string]$Head,

        [switch]$Draft,

        [string[]]$Reviewers,

        [string[]]$Assignees,

        [string[]]$Labels,

        [string]$Milestone,

        [switch]$AutoMerge,

        [switch]$OpenInBrowser
    )

    try {
        # Ensure gh is available
        $ghPath = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghPath) {
            throw "GitHub CLI (gh) is not installed"
        }

        # Get current branch if head not specified
        if (-not $Head) {
            $Head = git branch --show-current
        }

        # Get default branch if base not specified
        if (-not $Base) {
            $Base = gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
        }

        # Build gh command
        $ghArgs = @('pr', 'create', '--title', $Title)

        if ($Body) {
            $ghArgs += '--body', $Body
        } else {
            # Use template if available
            $templatePath = Join-Path $script:ProjectRoot ".github/pull_request_template.md"
            if (Test-Path $templatePath) {
                $Body = Get-Content $templatePath -Raw
                $ghArgs += '--body', $Body
            }
        }

        $ghArgs += '--base', $Base, '--head', $Head

        if ($Draft) {
            $ghArgs += '--draft'
        }

        if ($Reviewers) {
            $ghArgs += '--reviewer', ($Reviewers -join ',')
        }

        if ($Assignees) {
            $ghArgs += '--assignee', ($Assignees -join ',')
        }

        if ($Labels) {
            $ghArgs += '--label', ($Labels -join ',')
        }

        if ($Milestone) {
            $ghArgs += '--milestone', $Milestone
        }

        if ($PSCmdlet.ShouldProcess("Create PR: $Title from $Head to $Base")) {
            $result = gh @ghArgs

            # Extract PR number from output
            if ($result -match '#(\d+)') {
                $prNumber = $Matches[1]

                Write-PRLog "Created pull request #$prNumber" -Data @{
                    Number = $prNumber
                    Title = $Title
                    Base = $Base
                    Head = $Head
                    Draft = $Draft
                }

                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-AuditLog -EventType "GitHubPR" -Action "CreatePR" -Target "#$prNumber" -Result "Success" -Details @{
                        Title = $Title
                        Base = $Base
                        Head = $Head
                    }
                }

                # Enable auto-merge if requested
                if ($AutoMerge -and -not $Draft) {
                    Enable-PullRequestAutoMerge -Number $prNumber
                }

                if ($OpenInBrowser) {
                    gh pr view $prNumber --web
                }

                return @{
                    Number = $prNumber
                    Title = $Title
                    Url = $result
                    Success = $true
                }
            }
        }

    } catch {
        Write-PRLog "Failed to create pull request: $_" -Level Error
        throw
    }
}

function Update-PullRequest {
    <#
    .SYNOPSIS
        Update an existing pull request
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [string]$Title,

        [string]$Body,

        [string]$Base,

        [string[]]$AddLabels,

        [string[]]$RemoveLabels,

        [string[]]$AddReviewers,

        [string[]]$RemoveReviewers,

        [switch]$MarkReady,

        [switch]$ConvertToDraft
    )

    try {
        # Build gh command
        $ghArgs = @('pr', 'edit', $Number)
        $hasChanges = $false

        if ($Title) {
            $ghArgs += '--title', $Title
            $hasChanges = $true
        }

        if ($Body) {
            $ghArgs += '--body', $Body
            $hasChanges = $true
        }

        if ($Base) {
            $ghArgs += '--base', $Base
            $hasChanges = $true
        }

        if ($AddLabels) {
            $ghArgs += '--add-label', ($AddLabels -join ',')
            $hasChanges = $true
        }

        if ($RemoveLabels) {
            $ghArgs += '--remove-label', ($RemoveLabels -join ',')
            $hasChanges = $true
        }

        if ($AddReviewers) {
            $ghArgs += '--add-reviewer', ($AddReviewers -join ',')
            $hasChanges = $true
        }

        if ($RemoveReviewers) {
            $ghArgs += '--remove-reviewer', ($RemoveReviewers -join ',')
            $hasChanges = $true
        }

        if (-not $hasChanges -and -not $MarkReady -and -not $ConvertToDraft) {
            Write-Warning "No changes specified for PR #$Number"
            return
        }

        if ($PSCmdlet.ShouldProcess("Update PR #$Number")) {
            if ($hasChanges) {
                gh @ghArgs
            }

            # Handle ready/draft state
            if ($MarkReady) {
                gh pr ready $Number
                Write-PRLog "Marked PR #$Number as ready for review"
            } elseif ($ConvertToDraft) {
                gh pr draft $Number
                Write-PRLog "Converted PR #$Number to draft"
            }

            if ($LASTEXITCODE -eq 0) {
                Write-PRLog "Updated pull request #$Number"
                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }

    } catch {
        Write-PRLog "Failed to update pull request: $_" -Level Error
        throw
    }
}

function Get-PullRequests {
    <#
    .SYNOPSIS
        Get pull requests with filtering options
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('open', 'closed', 'merged', 'all')]
        [string]$State = 'open',

        [string]$Base,

        [string]$Head,

        [string[]]$Labels,

        [string]$Author,

        [string]$Assignee,

        [int]$Limit = 30,

        [switch]$IncludeDrafts
    )

    try {
        # Build gh command
        $ghArgs = @('pr', 'list', '--limit', $Limit)

        if ($State -ne 'all') {
            $ghArgs += '--state', $State
        }

        if ($Base) {
            $ghArgs += '--base', $Base
        }

        if ($Head) {
            $ghArgs += '--head', $Head
        }

        if ($Labels) {
            $ghArgs += '--label', ($Labels -join ',')
        }

        if ($Author) {
            $ghArgs += '--author', $Author
        }

        if ($Assignee) {
            $ghArgs += '--assignee', $Assignee
        }

        # Get JSON output
        $ghArgs += '--json', 'number,title,state,author,assignees,labels,headRefName,baseRefName,createdAt,updatedAt,url,isDraft,mergeable,mergeStateStatus'

        $prs = gh @ghArgs | ConvertFrom-Json

        # Filter drafts if needed
        if (-not $IncludeDrafts) {
            $prs = $prs | Where-Object { -not $_.isDraft }
        }

        Write-PRLog "Retrieved $($prs.Count) pull requests" -Data @{
            State = $State
            Count = $prs.Count
        }

        # Transform to consistent format
        $formattedPRs = $prs | ForEach-Object {
            @{
                Number = $_.number
                Title = $_.title
                State = $_.state
                Author = $_.author.login
                Assignees = $_.assignees.login
                Labels = $_.labels.name
                HeadBranch = $_.headRefName
                BaseBranch = $_.baseRefName
                CreatedAt = $_.createdAt
                UpdatedAt = $_.updatedAt
                Url = $_.url
                IsDraft = $_.isDraft
                Mergeable = $_.mergeable
                MergeStatus = $_.mergeStateStatus
            }
        }

        return $formattedPRs

    } catch {
        Write-PRLog "Failed to get pull requests: $_" -Level Error
        throw
    }
}

function Merge-PullRequest {
    <#
    .SYNOPSIS
        Merge a pull request
    .DESCRIPTION
        Merges a pull request with various merge strategies.
    .PARAMETER Number
        PR number to merge
    .PARAMETER Method
        Merge method: merge, squash, or rebase
    .PARAMETER DeleteBranch
        Delete the head branch after merge
    .PARAMETER Message
        Custom merge commit message
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [ValidateSet('merge', 'squash', 'rebase')]
        [string]$Method = 'merge',

        [switch]$DeleteBranch,

        [string]$Message
    )

    try {
        # Check PR status first
        $pr = gh pr view $Number --json mergeable,mergeStateStatus,headRefName | ConvertFrom-Json

        if ($pr.mergeStateStatus -ne 'CLEAN') {
            throw "PR #$Number is not ready to merge. Status: $($pr.mergeStateStatus)"
        }

        if ($PSCmdlet.ShouldProcess("Merge PR #$Number using $Method")) {
            # Build merge command
            $ghArgs = @('pr', 'merge', $Number, "--$Method")

            if ($DeleteBranch) {
                $ghArgs += '--delete-branch'
            }

            if ($Message -and $Method -ne 'rebase') {
                $ghArgs += '--subject', $Message
            }

            # Merge the PR
            gh @ghArgs

            if ($LASTEXITCODE -eq 0) {
                Write-PRLog "Merged pull request #$Number" -Data @{
                    Number = $Number
                    Method = $Method
                    DeletedBranch = $DeleteBranch
                }

                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-AuditLog -EventType "GitHubPR" -Action "MergePR" -Target "#$Number" -Result "Success" -Details @{
                        Method = $Method
                        Branch = $pr.headRefName
                    }
                }

                return @{
                    Number = $Number
                    Method = $Method
                    Success = $true
                }
            }
        }

    } catch {
        Write-PRLog "Failed to merge pull request: $_" -Level Error
        throw
    }
}

function Enable-PullRequestAutoMerge {
    <#
    .SYNOPSIS
        Enable auto-merge for a pull request
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [ValidateSet('merge', 'squash', 'rebase')]
        [string]$Method = 'squash'
    )

    try {
        if ($PSCmdlet.ShouldProcess("Enable auto-merge for PR #$Number")) {
            gh pr merge $Number --auto "--$Method"

            if ($LASTEXITCODE -eq 0) {
                Write-PRLog "Enabled auto-merge for PR #$Number" -Data @{
                    Number = $Number
                    Method = $Method
                }

                # Add to tracking queue
                $script:PRState.AutoMergeQueue += @{
                    Number = $Number
                    Method = $Method
                    EnabledAt = Get-Date
                }

                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }

    } catch {
        Write-PRLog "Failed to enable auto-merge: $_" -Level Error
        throw
    }
}

function Add-PullRequestComment {
    <#
    .SYNOPSIS
        Add a comment to a pull request
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [Parameter(Mandatory)]
        [string]$Body
    )

    try {
        if ($PSCmdlet.ShouldProcess("Add comment to PR #$Number")) {
            gh pr comment $Number --body $Body

            if ($LASTEXITCODE -eq 0) {
                Write-PRLog "Added comment to PR #$Number"
                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }

    } catch {
        Write-PRLog "Failed to add comment: $_" -Level Error
        throw
    }
}

function Close-PullRequest {
    <#
    .SYNOPSIS
        Close a pull request without merging
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [string]$Comment,

        [switch]$DeleteBranch
    )

    try {
        if ($PSCmdlet.ShouldProcess("Close PR #$Number")) {
            # Add comment if provided
            if ($Comment) {
                gh pr comment $Number --body $Comment
            }

            # Close the PR
            gh pr close $Number

            if ($LASTEXITCODE -eq 0) {
                Write-PRLog "Closed pull request #$Number"

                # Delete branch if requested
                if ($DeleteBranch) {
                    $pr = gh pr view $Number --json headRefName | ConvertFrom-Json
                    git push origin --delete $pr.headRefName
                    Write-PRLog "Deleted branch: $($pr.headRefName)"
                }

                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }

    } catch {
        Write-PRLog "Failed to close pull request: $_" -Level Error
        throw
    }
}

function Get-PullRequestReviews {
    <#
    .SYNOPSIS
        Get reviews for a pull request
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Number
    )

    try {
        $reviews = gh pr review list $Number --json author,state,submittedAt,body | ConvertFrom-Json

        $formattedReviews = $reviews | ForEach-Object {
            @{
                Author = $_.author.login
                State = $_.state
                SubmittedAt = $_.submittedAt
                Body = $_.body
            }
        }

        Write-PRLog "Retrieved $($reviews.Count) reviews for PR #$Number"
        return $formattedReviews

    } catch {
        Write-PRLog "Failed to get reviews: $_" -Level Error
        throw
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-PullRequest',
    'Update-PullRequest',
    'Get-PullRequests',
    'Merge-PullRequest',
    'Enable-PullRequestAutoMerge',
    'Add-PullRequestComment',
    'Close-PullRequest',
    'Get-PullRequestReviews'
)