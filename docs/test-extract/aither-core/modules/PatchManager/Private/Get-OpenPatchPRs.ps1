#Requires -Version 7.0

<#
.SYNOPSIS
    Gets list of open pull requests created by PatchManager
    
.DESCRIPTION
    Internal function to check for existing open PRs before creating new ones.
    Part of PatchManager v3.1 PR awareness feature.
#>

function Get-OpenPatchPRs {
    [CmdletBinding()]
    param()
    
    try {
        # Check if gh is available
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            return @()
        }
        
        # Get repository info
        $repoInfo = Get-GitRepositoryInfo -ErrorAction SilentlyContinue
        if (-not $repoInfo) {
            return @()
        }
        
        # Get open PRs
        $prs = gh pr list --repo $repoInfo.GitHubRepo --state open --json number,title,headRefName,author,createdAt --limit 50 2>$null | ConvertFrom-Json
        
        # Filter for patch branches
        $patchPRs = $prs | Where-Object { 
            $_.headRefName -like "patch/*" -or 
            $_.headRefName -like "feature/*" -or
            $_.headRefName -like "hotfix/*"
        }
        
        return $patchPRs
        
    } catch {
        # Return empty array on error
        return @()
    }
}

Export-ModuleMember -Function Get-OpenPatchPRs