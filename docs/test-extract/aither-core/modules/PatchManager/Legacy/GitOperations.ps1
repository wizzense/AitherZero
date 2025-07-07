function CreatePatchBranch {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BaseBranch = 'main'
    )

    if ([string]::IsNullOrWhiteSpace($BranchName)) {
        throw "Branch name cannot be null, empty, or whitespace"
    }
    
    if ([string]::IsNullOrWhiteSpace($BaseBranch)) {
        throw "Base branch name cannot be null, empty, or whitespace"
    }

    Write-Host "Creating patch branch: $BranchName from base branch: $BaseBranch" -ForegroundColor Cyan
    
    # Validate branch name format
    if ($BranchName -match '[^a-zA-Z0-9/_-]') {
        throw "Invalid branch name: '$BranchName'. Branch names can only contain letters, numbers, hyphens, underscores, and forward slashes."
    }
    
    git checkout -b $BranchName $BaseBranch
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create branch: $BranchName"
    }
}

function CommitChanges {
    param(
        [string]$CommitMessage
    )

    Write-Host "Committing changes..." -ForegroundColor Cyan
    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to commit changes."
    }
}

function Test-GitHubAuthentication {
    <#
    .SYNOPSIS
        Tests GitHub CLI authentication status
        
    .DESCRIPTION
        Checks if the user is authenticated with GitHub CLI and can access the repository
        
    .EXAMPLE
        Test-GitHubAuthentication
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check if gh CLI is available
        $ghVersion = gh --version 2>$null
        if (-not $ghVersion) {
            return @{
                Success = $false
                Message = "GitHub CLI (gh) is not installed or not in PATH"
                Authenticated = $false
            }
        }
        
        # Check authentication status
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{
                Success = $true
                Message = "GitHub CLI is authenticated"
                Authenticated = $true
                Details = $authStatus
            }
        } else {
            return @{
                Success = $false
                Message = "GitHub CLI is not authenticated. Please run 'gh auth login'"
                Authenticated = $false
                Details = $authStatus
            }
        }
    } catch {
        return @{
            Success = $false
            Message = "Error checking GitHub authentication: $($_.Exception.Message)"
            Authenticated = $false
        }
    }
}
