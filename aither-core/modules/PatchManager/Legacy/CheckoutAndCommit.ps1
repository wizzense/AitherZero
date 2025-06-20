function Invoke-CheckoutAndCommit {
    <#
    .SYNOPSIS
        Creates a new branch and commits changes
    
    .DESCRIPTION
        This function creates a new Git branch and commits all staged changes with the specified message.
        Compatible with PowerShell 5.1 and 7.x.
    
    .PARAMETER BranchName
        Name of the branch to create
    
    .PARAMETER BaseBranch
        Base branch to create the new branch from (default: main)
    
    .PARAMETER CommitMessage
        Commit message for the changes
    
    .EXAMPLE
        Invoke-CheckoutAndCommit -BranchName "feature/new-fix" -CommitMessage "Fix compatibility issues"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BaseBranch = 'main',
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CommitMessage
    )    # Import Git operations
    if ($PSScriptRoot) {
        $gitOpsPath = Join-Path $PSScriptRoot 'GitOperations.ps1'
        if (Test-Path $gitOpsPath) {
            . $gitOpsPath
        } else {
            Write-Warning "GitOperations.ps1 not found at $gitOpsPath"
        }
    } else {
        Write-Warning "PSScriptRoot not available, cannot import GitOperations.ps1"
    }

    try {
        # Validate inputs
        if ([string]::IsNullOrWhiteSpace($BranchName)) {
            throw "Branch name is required and cannot be empty"
        }
        
        if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
            throw "Commit message is required and cannot be empty"
        }

        # Create a new branch
        CreatePatchBranch -BranchName $BranchName -BaseBranch $BaseBranch
        Write-Host "Branch '$BranchName' created successfully." -ForegroundColor Green

        # Stage all changes
        git add -A
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stage changes."
        }

        # Commit changes
        CommitChanges -CommitMessage $CommitMessage
        Write-Host "Changes committed successfully with message: '$CommitMessage'." -ForegroundColor Green
        
        return @{
            Success = $true
            BranchName = $BranchName
            CommitMessage = $CommitMessage
        }
    } catch {
        Write-Error "An error occurred: $_"
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}
