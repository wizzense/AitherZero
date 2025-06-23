#Requires -Version 7.0

<#
.SYNOPSIS
    Dynamically detects the current Git repository information for GitHub operations.

.DESCRIPTION
    This function dynamically determines the correct repository information
    from the current Git context, making PatchManager work seamlessly across
    all forks (AitherZero, AitherLabs, Aitherium) without hardcoded values.

.EXAMPLE
    $repoInfo = Get-GitRepositoryInfo
    gh issue create --repo "$($repoInfo.Owner)/$($repoInfo.Name)" --title "Test"

.NOTES
    This replaces hardcoded repository references and enables the same
    PatchManager code to work across the entire fork chain.
#>

function Get-GitRepositoryInfo {
    [CmdletBinding()]
    param()

    try {
        # Get the origin remote URL
        $remoteUrl = git remote get-url origin 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get remote URL: $remoteUrl"
        }

        # Parse different URL formats
        $owner = $null
        $repoName = $null

        if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
            $owner = $matches[1]
            $repoName = $matches[2]
        }
        elseif ($remoteUrl -match 'https://github\.com/([^/]+)/([^/\.]+)') {
            $owner = $matches[1]
            $repoName = $matches[2]
        }
        else {
            throw "Could not parse GitHub repository from URL: $remoteUrl"
        }

        # Get current branch
        $currentBranch = git branch --show-current 2>&1
        if ($LASTEXITCODE -ne 0) {
            $currentBranch = "main" # fallback
        }

        # Determine repository type based on owner/name
        $repoType = switch ($owner) {
            "wizzense" { "Development" }
            "Aitherium" {
                switch ($repoName) {
                    "AitherLabs" { "Public" }
                    "Aitherium" { "Premium" }
                    default { "Unknown" }
                }
            }
            default { "Unknown" }
        }

        return @{
            Owner = $owner
            Name = $repoName
            FullName = "$owner/$repoName"
            Url = $remoteUrl.Trim()
            CurrentBranch = $currentBranch.Trim()
            Type = $repoType
            GitHubRepo = "$owner/$repoName"  # Format for --repo parameter
        }

    } catch {
        # Fallback to environment detection or defaults
        Write-Warning "Could not detect repository info: $($_.Exception.Message)"

        # Try to determine from current directory name
        $currentPath = (Get-Location).Path
        if ($currentPath -match 'AitherZero') {
            return @{
                Owner = "wizzense"
                Name = "AitherZero"
                FullName = "wizzense/AitherZero"
                Url = "https://github.com/wizzense/AitherZero.git"
                CurrentBranch = "main"
                Type = "Development"
                GitHubRepo = "wizzense/AitherZero"
            }
        }
        elseif ($currentPath -match 'AitherLabs') {
            return @{
                Owner = "Aitherium"
                Name = "AitherLabs"
                FullName = "Aitherium/AitherLabs"
                Url = "https://github.com/Aitherium/AitherLabs.git"
                CurrentBranch = "main"
                Type = "Public"
                GitHubRepo = "Aitherium/AitherLabs"
            }
        }
        else {
            throw "Could not determine repository information"
        }
    }
}

Export-ModuleMember -Function Get-GitRepositoryInfo
