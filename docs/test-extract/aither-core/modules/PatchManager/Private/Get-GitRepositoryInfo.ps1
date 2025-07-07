#Requires -Version 7.0

# Import Find-ProjectRoot from shared utilities
$sharedPath = Resolve-Path (Join-Path $PSScriptRoot "../../../shared/Find-ProjectRoot.ps1") -ErrorAction Stop
. $sharedPath

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
        # Ensure we're working from the project root for reliable git operations
        $projectRoot = Find-ProjectRoot
        Push-Location $projectRoot

        # Get all remotes to understand fork chain
        $remotes = @{}
        $remoteOutput = git remote -v 2>&1
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in $remoteOutput) {
                if ($line -match '(\w+)\s+([^\s]+)\s+\((fetch|push)\)') {
                    $remoteName = $matches[1]
                    $remoteUrl = $matches[2]
                    if (-not $remotes.ContainsKey($remoteName)) {
                        $remotes[$remoteName] = $remoteUrl
                    }
                }
            }
        }

        # Get the origin remote URL (current repository)
        $originUrl = $remotes['origin']
        if (-not $originUrl) {
            throw "No origin remote found"
        }

        # Parse repository information from origin
        $owner = $null
        $repoName = $null

        if ($originUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
            $owner = $matches[1]
            $repoName = $matches[2]
        }
        else {
            throw "Could not parse GitHub repository from URL: $originUrl"
        }

        # Get current branch
        $currentBranch = git branch --show-current 2>&1
        if ($LASTEXITCODE -ne 0) {
            $currentBranch = "main" # fallback
        }

        # Determine repository type and fork chain
        $repoType = "Unknown"
        $forkChain = @()

        if ($owner -eq "wizzense" -and $repoName -eq "AitherZero") {
            $repoType = "Development"
            $forkChain = @(
                @{ Name = "origin"; Owner = "wizzense"; Repo = "AitherZero"; GitHubRepo = "wizzense/AitherZero"; Type = "Development"; Description = "Your development fork" }
            )

            # Add upstream if it exists
            if ($remotes.ContainsKey('upstream')) {
                $upstreamUrl = $remotes['upstream']
                if ($upstreamUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
                    $upstreamOwner = $matches[1]
                    $upstreamRepo = $matches[2]
                    $forkChain += @{ Name = "upstream"; Owner = $upstreamOwner; Repo = $upstreamRepo; GitHubRepo = "$upstreamOwner/$upstreamRepo"; Type = "Public"; Description = "Public staging repository" }

                    # If upstream is AitherLabs, add Aitherium as the root
                    if ($upstreamOwner -eq "Aitherium" -and $upstreamRepo -eq "AitherLabs") {
                        $forkChain += @{ Name = "root"; Owner = "Aitherium"; Repo = "Aitherium"; GitHubRepo = "Aitherium/Aitherium"; Type = "Premium"; Description = "Premium/enterprise repository" }
                    }
                }
            }
        }
        elseif ($owner -eq "Aitherium" -and $repoName -eq "AitherLabs") {
            $repoType = "Public"
            $forkChain = @(
                @{ Name = "origin"; Owner = "Aitherium"; Repo = "AitherLabs"; GitHubRepo = "Aitherium/AitherLabs"; Type = "Public"; Description = "Public staging repository" }
            )

            # Add upstream to Aitherium if configured
            if ($remotes.ContainsKey('upstream')) {
                $upstreamUrl = $remotes['upstream']
                if ($upstreamUrl -match 'Aitherium/Aitherium') {
                    $forkChain += @{ Name = "upstream"; Owner = "Aitherium"; Repo = "Aitherium"; GitHubRepo = "Aitherium/Aitherium"; Type = "Premium"; Description = "Premium/enterprise repository" }
                }
            }
        }
        elseif ($owner -eq "Aitherium" -and $repoName -eq "Aitherium") {
            $repoType = "Premium"
            $forkChain = @(
                @{ Name = "origin"; Owner = "Aitherium"; Repo = "Aitherium"; GitHubRepo = "Aitherium/Aitherium"; Type = "Premium"; Description = "Premium/enterprise repository" }
            )
        }

        return @{
            Owner = $owner
            Name = $repoName
            FullName = "$owner/$repoName"
            Url = $originUrl.Trim()
            CurrentBranch = $currentBranch.Trim()
            Type = $repoType
            GitHubRepo = "$owner/$repoName"  # Format for --repo parameter
            Remotes = $remotes
            ForkChain = $forkChain
        }        } catch {
        # Fallback to environment detection or defaults
        Write-Warning "Could not detect repository info: $($_.Exception.Message)"        # Try to determine from current directory name
        $currentPath = $projectRoot
        if ($currentPath -match 'AitherZero') {
            return @{
                Owner = "wizzense"
                Name = "AitherZero"
                FullName = "wizzense/AitherZero"
                Url = "https://github.com/wizzense/AitherZero.git"
                CurrentBranch = "main"
                Type = "Development"
                GitHubRepo = "wizzense/AitherZero"
                Remotes = @{ origin = "https://github.com/wizzense/AitherZero.git" }
                ForkChain = @(
                    @{ Name = "origin"; Owner = "wizzense"; Repo = "AitherZero"; GitHubRepo = "wizzense/AitherZero"; Type = "Development"; Description = "Your development fork" }
                )
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
                Remotes = @{ origin = "https://github.com/Aitherium/AitherLabs.git" }
                ForkChain = @(
                    @{ Name = "origin"; Owner = "Aitherium"; Repo = "AitherLabs"; GitHubRepo = "Aitherium/AitherLabs"; Type = "Public"; Description = "Public staging repository" }
                )
            }
        } else {
            throw "Could not determine repository information"
        }
    } finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
}
