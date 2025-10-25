#Requires -Version 7.0

<#
.SYNOPSIS
    AitherZero Issue Tracker Module
.DESCRIPTION
    Provides GitHub issue tracking and management capabilities using the GitHub CLI (gh).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module state
$script:IssueState = @{
    Repository = $null
    Labels = @{}
    Milestones = @{}
    Cache = @{}
}

# Import dependencies
$script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:LoggingModule = Join-Path $script:ProjectRoot "domains/utilities/Logging.psm1"

if (Test-Path $script:LoggingModule) {
    Import-Module $script:LoggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-IssueLog {
    param(
        [string]$Message,
        [string]$Level = 'Information',
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "IssueTracker" -Data $Data
    } else {
        Write-Host "[$Level] $Message"
    }
}

function Test-GitHubCLI {
    <#
    .SYNOPSIS
        Verify GitHub CLI is installed and authenticated
    #>
    [CmdletBinding()]
    param()
    
    try {
        $ghPath = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghPath) {
            throw "GitHub CLI (gh) is not installed. Install from: https://cli.github.com/"
        }
        
        # Check authentication
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI is not authenticated. Run: gh auth login"
        }
        
        return $true
    } catch {
        Write-IssueLog "GitHub CLI check failed: $_" -Level Error
        throw
    }
}

function Get-GitHubRepository {
    <#
    .SYNOPSIS
        Get current GitHub repository information
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Get repo info from gh
        $repoInfo = gh repo view --json name,owner,defaultBranchRef,isPrivate,url | ConvertFrom-Json
        
        $script:IssueState.Repository = @{
            Owner = $repoInfo.owner.login
            Name = $repoInfo.name
            FullName = "$($repoInfo.owner.login)/$($repoInfo.name)"
            DefaultBranch = $repoInfo.defaultBranchRef.name
            IsPrivate = $repoInfo.isPrivate
            Url = $repoInfo.url
        }
        
        Write-IssueLog "Retrieved repository information" -Data $script:IssueState.Repository
        return $script:IssueState.Repository
        
    } catch {
        Write-IssueLog "Failed to get repository information: $_" -Level Error
        throw
    }
}

function New-GitHubIssue {
    <#
    .SYNOPSIS
        Create a new GitHub issue
    .DESCRIPTION
        Creates a new GitHub issue with support for labels, assignees, and milestones.
    .PARAMETER Title
        Issue title
    .PARAMETER Body
        Issue body/description
    .PARAMETER Labels
        Array of label names to apply
    .PARAMETER Assignees
        Array of GitHub usernames to assign
    .PARAMETER Milestone
        Milestone name or number
    .PARAMETER Project
        Project board name or number
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        
        [Parameter(Mandatory)]
        [string]$Body,
        
        [string[]]$Labels,
        
        [string[]]$Assignees,
        
        [string]$Milestone,
        
        [string]$Project,
        
        [switch]$OpenInBrowser
    )

    try {
        Test-GitHubCLI
        
        # Build gh command
        $ghArgs = @('issue', 'create', '--title', $Title, '--body', $Body)
        
        if ($Labels) {
            $ghArgs += '--label'
            $ghArgs += ($Labels -join ',')
        }
        
        if ($Assignees) {
            $ghArgs += '--assignee'
            $ghArgs += ($Assignees -join ',')
        }
        
        if ($Milestone) {
            $ghArgs += '--milestone', $Milestone
        }
        
        if ($Project) {
            $ghArgs += '--project', $Project
        }
        
        if ($PSCmdlet.ShouldProcess("Create issue: $Title")) {
            $result = gh @ghArgs

            # Extract issue number from output
            if ($result -match '#(\d+)') {
                $issueNumber = $Matches[1]
                
                Write-IssueLog "Created issue #$issueNumber" -Data @{
                    Number = $issueNumber
                    Title = $Title
                    Labels = $Labels
                    Assignees = $Assignees
                }
                
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-AuditLog -EventType "GitHubIssue" -Action "CreateIssue" -Target "#$issueNumber" -Result "Success" -Details @{
                        Title = $Title
                        Labels = $Labels
                    }
                }
                
                if ($OpenInBrowser) {
                    gh issue view $issueNumber --web
                }
                
                return @{
                    Number = $issueNumber
                    Title = $Title
                    Url = $result
                    Success = $true
                }
            }
        }
        
    } catch {
        Write-IssueLog "Failed to create issue: $_" -Level Error
        throw
    }
}

function Update-GitHubIssue {
    <#
    .SYNOPSIS
        Update an existing GitHub issue
    .DESCRIPTION
        Updates issue properties including title, body, labels, and state.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,
        
        [string]$Title,
        
        [string]$Body,
        
        [string[]]$AddLabels,
        
        [string[]]$RemoveLabels,
        
        [string[]]$Assignees,
        
        [ValidateSet('open', 'closed')]
        [string]$State,
        
        [string]$Milestone
    )

    try {
        Test-GitHubCLI
        
        # Build gh command
        $ghArgs = @('issue', 'edit', $Number)
        $hasChanges = $false
        
        if ($Title) {
            $ghArgs += '--title', $Title
            $hasChanges = $true
        }
        
        if ($Body) {
            $ghArgs += '--body', $Body
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
        
        if ($Assignees) {
            $ghArgs += '--assignee', ($Assignees -join ',')
            $hasChanges = $true
        }
        
        if ($Milestone) {
            $ghArgs += '--milestone', $Milestone
            $hasChanges = $true
        }
        
        if (-not $hasChanges) {
            Write-Warning "No changes specified for issue #$Number"
            return
        }
        
        if ($PSCmdlet.ShouldProcess("Update issue #$Number")) {
            gh @ghArgs

            if ($LASTEXITCODE -eq 0) {
                Write-IssueLog "Updated issue #$Number" -Data @{
                    Number = $Number
                    UpdatedFields = $ghArgs | Where-Object { $_ -match '^--' }
                }
                
                # Handle state change separately
                if ($State) {
                    if ($State -eq 'closed') {
                        gh issue close $Number
                    } else {
                        gh issue reopen $Number
                    }
                    Write-IssueLog "Changed issue #$Number state to: $State"
                }
                
                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }
        
    } catch {
        Write-IssueLog "Failed to update issue: $_" -Level Error
        throw
    }
}

function Get-GitHubIssues {
    <#
    .SYNOPSIS
        Get GitHub issues with filtering options
    .DESCRIPTION
        Retrieves GitHub issues with various filtering options.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('open', 'closed', 'all')]
        [string]$State = 'open',
        
        [string[]]$Labels,
        
        [string]$Assignee,
        
        [string]$Author,
        
        [string]$Milestone,
        
        [int]$Limit = 30,
        
        [string]$Search
    )

    try {
        Test-GitHubCLI
        
        # Build gh command
        $ghArgs = @('issue', 'list', '--state', $State, '--limit', $Limit)
        
        if ($Labels) {
            $ghArgs += '--label', ($Labels -join ',')
        }
        
        if ($Assignee) {
            $ghArgs += '--assignee', $Assignee
        }
        
        if ($Author) {
            $ghArgs += '--author', $Author
        }
        
        if ($Milestone) {
            $ghArgs += '--milestone', $Milestone
        }
        
        if ($Search) {
            $ghArgs += '--search', $Search
        }
        
        # Get JSON output
        $ghArgs += '--json', 'number,title,state,author,assignees,labels,createdAt,updatedAt,url'
        
        $issues = gh @ghArgs | ConvertFrom-Json
        
        Write-IssueLog "Retrieved $($issues.Count) issues" -Data @{
            State = $State
            Count = $issues.Count
        }
        
        # Transform to consistent format
        $formattedIssues = $issues | ForEach-Object {
            @{
                Number = $_.number
                Title = $_.title
                State = $_.state
                Author = $_.author.login
                Assignees = $_.assignees.login
                Labels = $_.labels.name
                CreatedAt = $_.createdAt
                UpdatedAt = $_.updatedAt
                Url = $_.url
            }
        }
        
        return $formattedIssues
        
    } catch {
        Write-IssueLog "Failed to get issues: $_" -Level Error
        throw
    }
}

function Add-GitHubIssueComment {
    <#
    .SYNOPSIS
        Add a comment to a GitHub issue
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,
        
        [Parameter(Mandatory)]
        [string]$Body
    )

    try {
        Test-GitHubCLI
        
        if ($PSCmdlet.ShouldProcess("Add comment to issue #$Number")) {
            gh issue comment $Number --body $Body

            if ($LASTEXITCODE -eq 0) {
                Write-IssueLog "Added comment to issue #$Number"
                
                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }
        
    } catch {
        Write-IssueLog "Failed to add comment: $_" -Level Error
        throw
    }
}

function Close-GitHubIssue {
    <#
    .SYNOPSIS
        Close a GitHub issue with optional comment
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [int]$Number,
        
        [string]$Comment,
        
        [ValidateSet('completed', 'not_planned')]
        [string]$Reason = 'completed'
    )

    try {
        Test-GitHubCLI
        
        if ($PSCmdlet.ShouldProcess("Close issue #$Number")) {
            # Add comment if provided
            if ($Comment) {
                gh issue comment $Number --body $Comment
            }

            # Close the issue
            $ghArgs = @('issue', 'close', $Number)
            if ($Reason -eq 'not_planned') {
                $ghArgs += '--reason', 'not planned'
            }
            
            gh @ghArgs

            if ($LASTEXITCODE -eq 0) {
                Write-IssueLog "Closed issue #$Number" -Data @{
                    Number = $Number
                    Reason = $Reason
                }
                
                if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                    Write-AuditLog -EventType "GitHubIssue" -Action "CloseIssue" -Target "#$Number" -Result "Success" -Details @{
                        Reason = $Reason
                    }
                }
                
                return @{
                    Number = $Number
                    Success = $true
                }
            }
        }
        
    } catch {
        Write-IssueLog "Failed to close issue: $_" -Level Error
        throw
    }
}

function Get-GitHubLabels {
    <#
    .SYNOPSIS
        Get available GitHub labels for the repository
    #>
    [CmdletBinding()]
    param()
    
    try {
        Test-GitHubCLI
        
        $labels = gh label list --json name,description,color | ConvertFrom-Json
        
        $script:IssueState.Labels = $labels | ForEach-Object {
            @{
                Name = $_.name
                Description = $_.description
                Color = $_.color
            }
        }
        
        Write-IssueLog "Retrieved $($labels.Count) labels"
        return $script:IssueState.Labels
        
    } catch {
        Write-IssueLog "Failed to get labels: $_" -Level Error
        throw
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Test-GitHubCLI',
    'Get-GitHubRepository',
    'New-GitHubIssue',
    'Update-GitHubIssue',
    'Get-GitHubIssues',
    'Add-GitHubIssueComment',
    'Close-GitHubIssue',
    'Get-GitHubLabels'
)