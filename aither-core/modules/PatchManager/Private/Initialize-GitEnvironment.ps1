function Initialize-GitEnvironment {
    <#
    .SYNOPSIS
        Initializes Git environment and validates repository state for PatchManager operations.

    .DESCRIPTION
        This function validates Git configuration, repository state, and credentials.
        It ensures the environment is ready for Git operations like release management.

    .PARAMETER WorkflowType
        The type of workflow being initialized (e.g., "release", "patch", "feature")

    .EXAMPLE
        $result = Initialize-GitEnvironment -WorkflowType "release"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$WorkflowType = "general"
    )

    $result = @{
        Success = $false
        Message = ""
        RepoOwner = ""
        RepoName = ""
        CurrentBranch = ""
        IsClean = $false
        HasRemote = $false
    }

    try {
        # Check if we're in a Git repository
        $gitRoot = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not in a Git repository"
        }

        # Get repository information
        $remoteUrl = & git config --get remote.origin.url 2>$null
        if ($remoteUrl) {
            $result.HasRemote = $true
            
            # Parse GitHub repository info
            if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
                $result.RepoOwner = $matches[1]
                $result.RepoName = $matches[2]
            }
        }

        # Get current branch
        $result.CurrentBranch = & git branch --show-current 2>$null
        if ($LASTEXITCODE -ne 0) {
            $result.CurrentBranch = "unknown"
        }

        # Check repository status
        $status = & git status --porcelain 2>$null
        $result.IsClean = [string]::IsNullOrEmpty($status)

        # Validate Git user configuration
        $userName = & git config user.name 2>$null
        $userEmail = & git config user.email 2>$null
        
        if ([string]::IsNullOrEmpty($userName) -or [string]::IsNullOrEmpty($userEmail)) {
            throw "Git user configuration missing. Run: git config --global user.name 'Your Name' && git config --global user.email 'your.email@example.com'"
        }

        # Check for GitHub CLI if needed for advanced operations
        if ($WorkflowType -eq "release") {
            $ghVersion = & gh --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "GitHub CLI not found. Some features may be limited."
            }
        }

        $result.Success = $true
        $result.Message = "Git environment initialized successfully"
        
        Write-Verbose "Git Environment:"
        Write-Verbose "  Repository: $($result.RepoOwner)/$($result.RepoName)"
        Write-Verbose "  Branch: $($result.CurrentBranch)"
        Write-Verbose "  Clean: $($result.IsClean)"
        Write-Verbose "  Remote: $($result.HasRemote)"

    }
    catch {
        $result.Message = $_.Exception.Message
        Write-Error "Failed to initialize Git environment: $_"
    }

    return $result
}