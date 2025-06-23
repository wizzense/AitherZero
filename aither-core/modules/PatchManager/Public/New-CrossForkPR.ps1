#Requires -Version 7.0

<#
.SYNOPSIS
    Creates pull requests across the fork chain dynamically.

.DESCRIPTION
    This function extends PatchManager to create PRs not just within the current repository,
    but also across the fork chain (AitherZero → AitherLabs → Aitherium).

.PARAMETER Description
    Description of the patch

.PARAMETER BranchName
    Name of the branch to create PR from

.PARAMETER TargetFork
    Target fork for the PR. Options:
    - 'current' (default): Create PR in current repository
    - 'upstream': Create PR to upstream repository (AitherZero → AitherLabs)
    - 'root': Create PR to root repository (AitherLabs → Aitherium)

.PARAMETER IssueNumber
    Issue number to link (for auto-closing)

.PARAMETER AffectedFiles
    Files affected by the patch

.PARAMETER DryRun
    Preview what would be created without actually creating

.EXAMPLE
    New-CrossForkPR -Description "Fix bug" -BranchName "fix/bug" -TargetFork "current"

.EXAMPLE
    New-CrossForkPR -Description "Promote feature to public" -BranchName "feature/new" -TargetFork "upstream"

.EXAMPLE
    New-CrossForkPR -Description "Add enterprise feature" -BranchName "premium/enterprise" -TargetFork "root"

.NOTES
    This enables the same PatchManager code to work across the entire fork chain:
    - AitherZero (Development) → AitherLabs (Public) → Aitherium (Premium)
#>

function New-CrossForkPR {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [ValidateSet('current', 'upstream', 'root')]
        [string]$TargetFork = 'current',

        [Parameter(Mandatory = $false)]
        [int]$IssueNumber,

        [Parameter(Mandatory = $false)]
        [string[]]$AffectedFiles = @(),

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    begin {
        function Write-CrossForkLog {
            param($Message, $Level = "INFO")
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-CrossForkLog "Creating cross-fork pull request: $Description" -Level "INFO"
    }

    process {
        try {
            # Check GitHub CLI availability
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) not found. Please install and authenticate with GitHub CLI."
            }

            # Get repository information and fork chain
            try {
                $repoInfo = Get-GitRepositoryInfo
                Write-CrossForkLog "Detected repository: $($repoInfo.FullName) ($($repoInfo.Type))" -Level "INFO"
                Write-CrossForkLog "Available forks in chain: $($repoInfo.ForkChain.Count)" -Level "INFO"
                
                foreach ($fork in $repoInfo.ForkChain) {
                    Write-CrossForkLog "  - $($fork.Name): $($fork.GitHubRepo) ($($fork.Type))" -Level "INFO"
                }
            } catch {
                throw "Failed to detect repository information: $($_.Exception.Message)"
            }

            # Determine target repository
            $targetRepo = $null
            $targetRepoName = ""
            
            switch ($TargetFork) {
                'current' {
                    $targetRepo = $repoInfo.ForkChain | Where-Object { $_.Name -eq 'origin' } | Select-Object -First 1
                    $targetRepoName = "current repository ($($repoInfo.FullName))"
                }
                'upstream' {
                    $targetRepo = $repoInfo.ForkChain | Where-Object { $_.Name -eq 'upstream' } | Select-Object -First 1
                    if (-not $targetRepo) {
                        throw "No upstream repository found in fork chain. Available: $($repoInfo.ForkChain.Name -join ', ')"
                    }
                    $targetRepoName = "upstream repository ($($targetRepo.GitHubRepo))"
                }
                'root' {
                    $targetRepo = $repoInfo.ForkChain | Where-Object { $_.Name -eq 'root' } | Select-Object -First 1
                    if (-not $targetRepo) {
                        throw "No root repository found in fork chain. Available: $($repoInfo.ForkChain.Name -join ', ')"
                    }
                    $targetRepoName = "root repository ($($targetRepo.GitHubRepo))"
                }
            }

            if (-not $targetRepo) {
                throw "Could not determine target repository for fork: $TargetFork"
            }

            Write-CrossForkLog "Target: $targetRepoName" -Level "INFO"

            # Create enhanced PR title and body for cross-fork PRs
            $prTitle = "Patch: $Description"
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
            
            # Gather system and environment information
            $gitInfo = @{
                CurrentBranch = git branch --show-current 2>&1 | Out-String | ForEach-Object Trim
                LastCommit = git log -1 --oneline 2>&1 | Out-String | ForEach-Object Trim
                RepoStatus = git status --porcelain 2>&1 | Out-String | ForEach-Object Trim
                RemoteUrl = git remote get-url origin 2>&1 | Out-String | ForEach-Object Trim
            }
            
            $systemInfo = @{
                PowerShellVersion = $PSVersionTable.PSVersion.ToString()
                OS = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
                Hostname = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } elseif ($env:HOSTNAME) { $env:HOSTNAME } else { "Unknown" }
                UserContext = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { "Unknown" }
                WorkingDirectory = (Get-Location).Path
            }

            # Create fork-specific PR body
            $forkFlowDescription = switch ($TargetFork) {
                'current' { "**Internal PR**: Changes within the current repository" }
                'upstream' { "**Fork Promotion**: Promoting changes from development fork to public staging" }
                'root' { "**Enterprise Promotion**: Promoting features to premium/enterprise repository" }
            }

            $prBody = @"
## Cross-Fork Pull Request
**$Description**

### Fork Chain Information
$forkFlowDescription

| Aspect | Information |
|--------|-------------|
| **Source Repository** | $($repoInfo.FullName) ($($repoInfo.Type)) |
| **Target Repository** | $($targetRepo.GitHubRepo) ($($targetRepo.Type)) |
| **Fork Flow** | $($repoInfo.Type) → $($targetRepo.Type) |
| **Branch** | ``$BranchName`` |
| **Created** | $timestamp |

### Technical Details
| Aspect | Information |
|--------|-------------|
| **PowerShell** | $($systemInfo.PowerShellVersion) |
| **Platform** | $($systemInfo.OS) |
| **Host** | $($systemInfo.Hostname) |
| **User** | $($systemInfo.UserContext) |

### Files Affected
$(if ($AffectedFiles.Count -gt 0) {
    ($AffectedFiles | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
    "*Files will be identified during code review*"
})

### Git Information
| Property | Value |
|----------|-------|
| **Source Branch** | ``$($gitInfo.CurrentBranch)`` |
| **Last Commit** | ``$($gitInfo.LastCommit)`` |
| **Source Repository** | $($gitInfo.RemoteUrl) |
| **Working Tree** | $(if ($gitInfo.RepoStatus) { "Changes pending" } else { "Clean" }) |

### Fork Chain Workflow Status
- [x] Changes developed in source repository ($($repoInfo.Type))
- [x] Branch created and pushed to source
- [x] Cross-fork PR created to target ($($targetRepo.Type))
- [ ] Code review completed in target repository
- [ ] Tests passing in target environment
- [ ] Ready to merge in target repository

### Quality Assurance for Cross-Fork PR
This pull request follows the **PatchManager Cross-Fork Workflow**:

#### Pre-merge Validation
- [ ] **Source Compatibility**: Changes tested in source repository
- [ ] **Target Compatibility**: Changes compatible with target repository
- [ ] **Code Review**: All changes reviewed for target context
- [ ] **Testing**: Tests pass in target environment
- [ ] **Documentation**: Changes documented for target audience
- [ ] **Breaking Changes**: Impact assessed for target repository users

#### Cross-Fork Integration Checks
- [ ] **Module Loading**: All affected modules load correctly in target
- [ ] **Function Exports**: Module manifests compatible with target
- [ ] **Cross-Platform**: Changes work across all supported platforms
- [ ] **PowerShell Compatibility**: Compatible with target PowerShell version
- [ ] **Dependencies**: All dependencies available in target environment

$(if ($IssueNumber) {
    "### Related Issue`n**Closes #$IssueNumber** (in source repository)`n`nThis pull request addresses the issue in the source repository."
} else {
    "### Standalone Cross-Fork Patch`nThis is a standalone patch promoting changes across the fork chain."
})

### Fork Chain Context
**Complete Fork Chain**: 
$($repoInfo.ForkChain | ForEach-Object { "- **$($_.GitHubRepo)** ($($_.Type)): $($_.Description)" } | Out-String)

### Cross-Fork Automation Details
- **PatchManager Version**: 2.0 (Cross-Fork Enabled)
- **Workflow**: ``New-CrossForkPR -TargetFork $TargetFork``
- **Source Repository**: $($repoInfo.FullName)
- **Target Repository**: $($targetRepo.GitHubRepo)
- **Fork Strategy**: Dynamic cross-repository promotion
- **Auto-merge**: Not enabled (requires manual review in target)

### Review Guidelines for Cross-Fork PRs
1. **Verify compatibility** with target repository context
2. **Test functionality** in target environment
3. **Check for conflicts** with target repository changes
4. **Validate target-specific requirements**
5. **Ensure proper documentation** for target audience
6. **Review security implications** for target environment

---
*This cross-fork pull request was created by **PatchManager v2.0** with dynamic fork chain detection. The changes promote from $($repoInfo.Type) to $($targetRepo.Type) environment.*

**Cross-Fork Command**: ``New-CrossForkPR -Description "$Description" -TargetFork "$TargetFork"``
"@

            if ($DryRun) {
                Write-CrossForkLog "DRY RUN: Would create cross-fork PR" -Level "INFO"
                Write-CrossForkLog "  Source: $($repoInfo.FullName)" -Level "INFO"
                Write-CrossForkLog "  Target: $($targetRepo.GitHubRepo)" -Level "INFO"
                Write-CrossForkLog "  Title: $prTitle" -Level "INFO"
                return @{
                    Success = $true
                    DryRun = $true
                    Source = $repoInfo.FullName
                    Target = $targetRepo.GitHubRepo
                    Title = $prTitle
                    Body = $prBody
                }
            }

            # Ensure we have changes committed
            $gitStatus = git status --porcelain 2>&1
            if ($gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })) {
                Write-CrossForkLog "Committing pending changes..." -Level "INFO"
                git add . 2>&1 | Out-Null
                git commit -m "PatchManager Cross-Fork: $Description" 2>&1 | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    Write-CrossForkLog "Warning: Git commit may have had issues, but continuing..." -Level "WARN"
                }
            }

            # Push branch to source repository
            Write-CrossForkLog "Pushing branch to source repository: $BranchName" -Level "INFO"
            git push origin $BranchName 2>&1 | Out-Null

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push branch $BranchName to source repository"
            }

            # Ensure patch label exists in target repository
            $labelCheck = gh label list --repo $targetRepo.GitHubRepo --search "patch" 2>&1 | Out-String
            if (-not $labelCheck.Contains("patch")) {
                Write-CrossForkLog "Creating missing patch label in target repository" -Level "INFO"
                gh label create "patch" --repo $targetRepo.GitHubRepo --color "0366d6" --description "Auto-created by PatchManager" 2>&1 | Out-Null
            }

            # Create cross-fork label if it doesn't exist
            $crossForkLabelCheck = gh label list --repo $targetRepo.GitHubRepo --search "cross-fork" 2>&1 | Out-String
            if (-not $crossForkLabelCheck.Contains("cross-fork")) {
                Write-CrossForkLog "Creating cross-fork label in target repository" -Level "INFO"
                gh label create "cross-fork" --repo $targetRepo.GitHubRepo --color "ff6b6b" --description "Cross-fork promotion PR" 2>&1 | Out-Null
            }

            # Create the cross-fork PR
            Write-CrossForkLog "Creating cross-fork pull request: $prTitle" -Level "INFO"
            
            # For cross-fork PRs, we need to specify the head as user:branch format
            $headRef = "$($repoInfo.Owner):$BranchName"
            $result = gh pr create --repo $targetRepo.GitHubRepo --title $prTitle --body $prBody --head $headRef --label "patch,cross-fork" 2>&1

            # Handle any remaining label errors gracefully
            if ($LASTEXITCODE -ne 0 -and $result -match "not found") {
                Write-CrossForkLog "Label issue detected, creating PR without labels" -Level "WARN"
                $result = gh pr create --repo $targetRepo.GitHubRepo --title $prTitle --body $prBody --head $headRef 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                # Extract PR number from URL
                $prNumber = $null
                if ($result -match '/pull/(\d+)') {
                    $prNumber = $matches[1]
                }

                Write-CrossForkLog "Cross-fork pull request created successfully!" -Level "SUCCESS"
                Write-CrossForkLog "  Source: $($repoInfo.FullName)" -Level "SUCCESS"
                Write-CrossForkLog "  Target: $($targetRepo.GitHubRepo)" -Level "SUCCESS"
                Write-CrossForkLog "  URL: $result" -Level "SUCCESS"
                if ($prNumber) {
                    Write-CrossForkLog "  PR #$prNumber" -Level "SUCCESS"
                }

                return @{
                    Success = $true
                    PullRequestUrl = $result.ToString().Trim()
                    PullRequestNumber = $prNumber
                    Title = $prTitle
                    Source = $repoInfo.FullName
                    Target = $targetRepo.GitHubRepo
                    TargetFork = $TargetFork
                }
            } else {
                # Check if this is an "already exists" error
                $errorText = $result -join ' '
                if ($errorText -match "already exists.*https://github\.com/[^/]+/[^/]+/pull/\d+") {
                    $existingPrUrl = [regex]::Match($errorText, 'https://github\.com/[^/]+/[^/]+/pull/\d+').Value
                    
                    $prNumber = $null
                    if ($existingPrUrl -match '/pull/(\d+)') {
                        $prNumber = $matches[1]
                    }

                    Write-CrossForkLog "Cross-fork pull request already exists: $existingPrUrl" -Level "SUCCESS"
                    Write-CrossForkLog "Using existing PR #$prNumber" -Level "INFO"

                    return @{
                        Success = $true
                        PullRequestUrl = $existingPrUrl
                        PullRequestNumber = $prNumber
                        Title = $prTitle
                        Source = $repoInfo.FullName
                        Target = $targetRepo.GitHubRepo
                        TargetFork = $TargetFork
                        Message = "Using existing cross-fork pull request"
                    }
                } else {
                    throw "GitHub CLI failed to create cross-fork PR: $errorText"
                }
            }

        } catch {
            $errorMessage = "Failed to create cross-fork pull request: $($_.Exception.Message)"
            Write-CrossForkLog $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Message = $errorMessage
                Source = $repoInfo.FullName
                TargetFork = $TargetFork
            }
        }
    }
}

Export-ModuleMember -Function New-CrossForkPR
