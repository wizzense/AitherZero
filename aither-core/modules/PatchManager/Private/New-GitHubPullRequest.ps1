function New-GitHubPullRequest {
    <#
    .SYNOPSIS
        Creates a new GitHub pull request using the GitHub CLI.

    .DESCRIPTION
        Creates a new GitHub pull request with the specified title, body, head branch, and base branch
        using the GitHub CLI. This function is used by PatchManager's release automation.

    .PARAMETER Title
        The title of the pull request

    .PARAMETER Body
        The body content of the pull request

    .PARAMETER Head
        The head branch (source branch) for the pull request

    .PARAMETER Base
        The base branch (target branch) for the pull request (default: main)

    .PARAMETER Labels
        Array of labels to apply to the pull request

    .PARAMETER Reviewers
        Array of GitHub usernames to request reviews from

    .PARAMETER Draft
        Create the pull request as a draft

    .EXAMPLE
        New-GitHubPullRequest -Title "Release v1.0.0" -Body "Release PR" -Head "release/v1.0.0" -Base "main"

    .NOTES
        Requires GitHub CLI (gh) to be installed and authenticated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter(Mandatory = $true)]
        [string]$Head,

        [Parameter()]
        [string]$Base = "main",

        [Parameter()]
        [string[]]$Labels = @(),

        [Parameter()]
        [string[]]$Reviewers = @(),

        [Parameter()]
        [switch]$Draft
    )

    begin {
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Creating pull request: $Head -> $Base"
        
        $result = @{
            Success = $false
            PullRequestNumber = $null
            PullRequestUrl = $null
            Message = $null
        }
    }

    process {
        try {
            # Check if GitHub CLI is available
            $ghCommand = Get-Command 'gh' -ErrorAction SilentlyContinue
            if (-not $ghCommand) {
                throw "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
            }

            # Build the gh pr create command
            $ghArgs = @('pr', 'create', '--title', $Title, '--body', $Body, '--head', $Head, '--base', $Base)
            
            # Add labels if provided
            if ($Labels.Count -gt 0) {
                $labelsString = $Labels -join ','
                $ghArgs += @('--label', $labelsString)
            }
            
            # Add reviewers if provided
            if ($Reviewers.Count -gt 0) {
                $reviewersString = $Reviewers -join ','
                $ghArgs += @('--reviewer', $reviewersString)
            }
            
            # Add draft flag if specified
            if ($Draft) {
                $ghArgs += '--draft'
            }

            Write-Verbose "[$functionName] Executing: gh $($ghArgs -join ' ')"
            
            # Execute the command
            $output = & gh @ghArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                # Parse the output to get PR URL and number
                $prUrl = $output.Trim()
                if ($prUrl -match 'github\.com/.*/pull/(\d+)$') {
                    $prNumber = $Matches[1]
                    
                    $result.Success = $true
                    $result.PullRequestNumber = $prNumber
                    $result.PullRequestUrl = $prUrl
                    $result.Message = "Pull request #$prNumber created successfully"
                    
                    Write-Verbose "[$functionName] Pull request created: #$prNumber at $prUrl"
                } else {
                    # Some versions of gh output differently, try to handle that
                    if ($output -match 'https://github\.com/.*/pull/\d+') {
                        $prUrl = $Matches[0]
                        if ($prUrl -match '/pull/(\d+)$') {
                            $prNumber = $Matches[1]
                            
                            $result.Success = $true
                            $result.PullRequestNumber = $prNumber
                            $result.PullRequestUrl = $prUrl
                            $result.Message = "Pull request #$prNumber created successfully"
                        }
                    } else {
                        $result.Message = "Pull request created but could not parse PR number from output: $output"
                    }
                }
            } else {
                throw "GitHub CLI command failed with exit code $LASTEXITCODE. Output: $output"
            }
        }
        catch {
            $result.Message = $_.Exception.Message
            Write-Error "[$functionName] Failed to create GitHub pull request: $_"
        }
    }

    end {
        Write-Verbose "[$functionName] Completed"
        return $result
    }
}