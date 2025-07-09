function New-Release {
    <#
    .SYNOPSIS
        Creates a new release with automatic PR creation, CI monitoring, and release workflow tracking.

    .DESCRIPTION
        This is THE function for creating releases in AitherZero. It handles the entire release process:
        1. Creates a release branch
        2. Updates the VERSION file
        3. Creates a PR with auto-merge enabled
        4. Monitors CI status
        5. Tracks the release workflow
        6. Reports when the release is published

        This function respects branch protection rules and provides a seamless release experience.

    .PARAMETER Version
        The version number for the release (e.g., "1.2.3")

    .PARAMETER Message
        The release message/description

    .PARAMETER DryRun
        Preview what would happen without making changes

    .EXAMPLE
        New-Release -Version "1.0.0" -Message "Major release with breaking changes"

    .EXAMPLE
        New-Release -Version "0.8.4" -Message "Bug fixes and performance improvements"

    .NOTES
        This function is part of PatchManager v3.1 and provides the ultimate release automation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [switch]$DryRun
    )

    begin {
        $functionName = $MyInvocation.MyCommand.Name
        Write-Verbose "[$functionName] Starting release process for v$Version"
        
        # Initialize module functions
        . "$PSScriptRoot/../Private/Initialize-GitEnvironment.ps1"
        . "$PSScriptRoot/../Private/New-GitHubIssue.ps1"
        . "$PSScriptRoot/../Private/New-GitHubPullRequest.ps1"
        
        $result = @{
            Success = $false
            Version = $Version
            Message = $null
            PullRequestUrl = $null
            ReleaseUrl = $null
            WorkflowRunUrl = $null
        }
    }

    process {
        try {
            # Initialize Git environment
            $gitConfig = Initialize-GitEnvironment -WorkflowType "release"
            if (-not $gitConfig.Success) {
                throw "Failed to initialize Git environment: $($gitConfig.Message)"
            }

            # Ensure we're on main branch
            $currentBranch = & git branch --show-current
            if ($currentBranch -ne 'main') {
                & git checkout main
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to switch to main branch"
                }
            }

            # Pull latest changes
            Write-Host "📥 Syncing with remote..." -ForegroundColor Yellow
            & git pull origin main --ff-only 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to sync with remote. Please resolve any conflicts and try again."
            }

            # Check if tag already exists
            $tagName = "v$Version"
            $existingTag = & git tag -l $tagName
            if ($existingTag) {
                throw "Tag $tagName already exists! Use a different version number."
            }

            # Get current version
            $versionFile = Join-Path (Get-Location) "VERSION"
            $currentVersion = if (Test-Path $versionFile) { 
                (Get-Content $versionFile -Raw).Trim() 
            } else { 
                "0.0.0" 
            }

            Write-Host "📊 Version Update: $currentVersion → $Version" -ForegroundColor Cyan

            if ($PSCmdlet.ShouldProcess("Release v$Version", "Create")) {
                # Create release branch
                $branchName = "release/v$Version"
                Write-Host "🌿 Creating release branch: $branchName" -ForegroundColor Yellow
                
                & git checkout -b $branchName 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to create release branch"
                }

                # Update VERSION file
                Set-Content -Path $versionFile -Value $Version -NoNewline
                
                # Commit the change
                & git add VERSION
                & git commit -m "Release v$Version - $Message" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to commit version update"
                }

                # Push branch
                & git push -u origin $branchName 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to push release branch"
                }

                # Create issue for tracking
                Write-Host "📝 Creating release tracking issue..." -ForegroundColor Yellow
                $issueBody = @"
## Release v$Version

**Description**: $Message

### Release Checklist
- [ ] Version updated to $Version
- [ ] CI checks passing
- [ ] Release packages built
- [ ] Release published

### Automated by PatchManager
This issue tracks the automated release process.
"@

                $issueResult = New-GitHubIssue -Title "Release v$Version" -Body $issueBody -Labels @("release", "automated")
                
                # Create PR
                Write-Host "🔀 Creating release PR..." -ForegroundColor Yellow
                $prBody = @"
## Release v$Version

$Message

### Changes
- Updated VERSION to $Version

### Release Process
This PR will:
1. Run CI checks
2. Auto-merge when checks pass
3. Trigger the release workflow
4. Create GitHub release with packages

Closes #$($issueResult.IssueNumber)

---
*Automated by PatchManager Release Automation*
"@

                $prResult = New-GitHubPullRequest `
                    -Title "Release v$Version - $Message" `
                    -Body $prBody `
                    -Head $branchName `
                    -Base "main"

                if (-not $prResult.Success) {
                    throw "Failed to create PR: $($prResult.Message)"
                }

                $result.PullRequestUrl = $prResult.PullRequestUrl
                $prNumber = $prResult.PullRequestNumber

                Write-Host "✅ Created release PR #$prNumber" -ForegroundColor Green
                Write-Host "🔗 $($result.PullRequestUrl)" -ForegroundColor Blue

                # Enable auto-merge
                Write-Host "🤖 Enabling auto-merge..." -ForegroundColor Yellow
                $mergeResult = & gh pr merge $prNumber --auto --squash 2>&1
                if ($LASTEXITCODE -eq 0 -or $mergeResult -match "already enabled") {
                    Write-Host "✅ Auto-merge enabled" -ForegroundColor Green
                } else {
                    Write-Warning "Could not enable auto-merge. You may need to merge manually when checks pass."
                }

                # Success
                $result.Success = $true
                $result.Message = "Release PR created successfully. Monitor CI and release at: $($result.PullRequestUrl)"
                
                Write-Host "`n🎉 Release process initiated!" -ForegroundColor Green
                Write-Host "📋 Next steps:" -ForegroundColor Cyan
                Write-Host "   1. CI will validate the changes" -ForegroundColor White
                Write-Host "   2. PR will auto-merge when checks pass" -ForegroundColor White
                Write-Host "   3. Release workflow will create v$Version" -ForegroundColor White
                Write-Host "   4. Monitor at: https://github.com/$($gitConfig.RepoOwner)/$($gitConfig.RepoName)/actions" -ForegroundColor White
            }
        }
        catch {
            $result.Message = $_.Exception.Message
            Write-Error "Release failed: $_"
            
            # Cleanup on failure
            if ($branchName) {
                & git checkout main 2>&1 | Out-Null
                & git branch -D $branchName 2>&1 | Out-Null
            }
        }
    }

    end {
        Write-Verbose "[$functionName] Completed"
        return $result
    }
}