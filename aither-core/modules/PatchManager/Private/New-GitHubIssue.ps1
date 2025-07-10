function New-GitHubIssue {
    <#
    .SYNOPSIS
        Creates a new GitHub issue using the GitHub CLI.

    .DESCRIPTION
        Creates a new GitHub issue with the specified title, body, and labels using the GitHub CLI.
        This function is used by PatchManager's release automation.

    .PARAMETER Title
        The title of the issue

    .PARAMETER Body
        The body content of the issue

    .PARAMETER Labels
        Array of labels to apply to the issue

    .PARAMETER Assignee
        GitHub username to assign the issue to

    .EXAMPLE
        New-GitHubIssue -Title "Release v1.0.0" -Body "Release tracking issue" -Labels @("release", "automated")

    .NOTES
        Requires GitHub CLI (gh) to be installed and authenticated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Body,

        [Parameter()]
        [string[]]$Labels = @(),

        [Parameter()]
        [string]$Assignee
    )

    begin {
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Creating GitHub issue: $Title"
        
        $result = @{
            Success = $false
            IssueNumber = $null
            IssueUrl = $null
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

            # Build the gh issue create command
            $ghArgs = @('issue', 'create', '--title', $Title, '--body', $Body)
            
            # Add labels if provided
            if ($Labels.Count -gt 0) {
                $labelsString = $Labels -join ','
                $ghArgs += @('--label', $labelsString)
            }
            
            # Add assignee if provided
            if ($Assignee) {
                $ghArgs += @('--assignee', $Assignee)
            }

            Write-Verbose "[$functionName] Executing: gh $($ghArgs -join ' ')"
            
            # Execute the command
            $output = & gh @ghArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                # Parse the output to get issue URL and number
                $issueUrl = $output.Trim()
                if ($issueUrl -match 'github\.com/.*/issues/(\d+)$') {
                    $issueNumber = $Matches[1]
                    
                    $result.Success = $true
                    $result.IssueNumber = $issueNumber
                    $result.IssueUrl = $issueUrl
                    $result.Message = "Issue #$issueNumber created successfully"
                    
                    Write-Verbose "[$functionName] Issue created: #$issueNumber at $issueUrl"
                } else {
                    $result.Message = "Issue created but could not parse issue number from output: $output"
                }
            } else {
                throw "GitHub CLI command failed with exit code $LASTEXITCODE. Output: $output"
            }
        }
        catch {
            $result.Message = $_.Exception.Message
            Write-Error "[$functionName] Failed to create GitHub issue: $_"
        }
    }

    end {
        Write-Verbose "[$functionName] Completed"
        return $result
    }
}