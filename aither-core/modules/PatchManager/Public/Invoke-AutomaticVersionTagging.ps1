#Requires -Version 7.0

<#
.SYNOPSIS
    Automatically creates Git tags when VERSION file changes are detected

.DESCRIPTION
    This function provides automatic version tagging functionality for the PatchManager workflow:
    - Detects when the VERSION file has been changed in recent commits
    - Reads the new version from the VERSION file
    - Creates a git tag in the format "v{version}" (e.g., "v0.11.0")
    - Pushes the tag to the remote repository
    - Only processes commits to the main branch
    - Integrates with the existing release workflow to trigger builds

.PARAMETER CommitSha
    Specific commit SHA to check for VERSION file changes (optional - defaults to HEAD)

.PARAMETER BranchName
    Branch name to check (defaults to current branch, only processes main branch)

.PARAMETER ForceTag
    Create the tag even if it already exists (will recreate it)

.PARAMETER DryRun
    Preview what would be done without making changes

.PARAMETER Silent
    Suppress informational output (only show errors and warnings)

.EXAMPLE
    Invoke-AutomaticVersionTagging
    # Check current commit for VERSION file changes and create tag if needed

.EXAMPLE
    Invoke-AutomaticVersionTagging -CommitSha "abc123def456"
    # Check specific commit for VERSION file changes

.EXAMPLE
    Invoke-AutomaticVersionTagging -DryRun
    # Preview what would be done without creating tags

.EXAMPLE
    Invoke-AutomaticVersionTagging -ForceTag
    # Force create tag even if it already exists

.NOTES
    This function is designed to be called automatically by PatchManager workflows
    after successful merges to the main branch. It integrates with the existing
    release automation to create a complete VERSION change → tag creation → 
    release workflow trigger → build artifacts → GitHub release pipeline.
#>

function Invoke-AutomaticVersionTagging {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CommitSha,

        [Parameter(Mandatory = $false)]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [switch]$ForceTag,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Silent
    )

    begin {
        $ErrorActionPreference = 'Stop'

        # Find project root
        $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
        if (-not $projectRoot) {
            throw "Could not find project root"
        }

        # Helper function for logging
        function Write-TagLog {
            param([string]$Message, [string]$Level = "INFO")

            if ($Silent -and $Level -eq "INFO") {
                return
            }

            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level $Level -Message "AutoVersionTagging: $Message"
            } else {
                $color = @{
                    'INFO' = 'Cyan'
                    'SUCCESS' = 'Green'
                    'WARNING' = 'Yellow'
                    'ERROR' = 'Red'
                }[$Level]
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $color
            }
        }

        # Get current version from VERSION file
        function Get-CurrentVersion {
            $versionFile = Join-Path $projectRoot "VERSION"
            if (-not (Test-Path $versionFile)) {
                throw "VERSION file not found at: $versionFile"
            }
            return (Get-Content $versionFile -Raw).Trim()
        }

        # Check if VERSION file was changed in specific commit
        function Test-VersionFileChanged {
            param([string]$CommitSha)
            
            try {
                $changedFiles = git diff --name-only "$CommitSha^" "$CommitSha" 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-TagLog "Could not check changed files for commit $CommitSha" -Level "WARNING"
                    return $false
                }
                
                $versionChanged = $changedFiles -contains "VERSION"
                return $versionChanged
            } catch {
                Write-TagLog "Error checking VERSION file changes: $($_.Exception.Message)" -Level "WARNING"
                return $false
            }
        }

        # Check if we're on main branch
        function Test-IsMainBranch {
            param([string]$BranchName)
            
            if (-not $BranchName) {
                $BranchName = git branch --show-current 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-TagLog "Could not determine current branch" -Level "WARNING"
                    return $false
                }
            }
            
            return ($BranchName -eq "main" -or $BranchName -eq "master")
        }
    }

    process {
        try {
            if (-not $Silent) {
                Write-Host ""
                Write-Host "🏷️  Automatic Version Tagging" -ForegroundColor Magenta
                Write-Host ("=" * 40) -ForegroundColor Magenta
            }

            # Step 1: Determine commit to check
            if (-not $CommitSha) {
                $CommitSha = git rev-parse HEAD 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "Could not get current commit SHA: $CommitSha"
                }
            }

            Write-TagLog "Checking commit: $CommitSha" -Level "INFO"

            # Step 2: Check if we're on main branch
            if (-not (Test-IsMainBranch -BranchName $BranchName)) {
                Write-TagLog "Not on main branch - automatic tagging only applies to main branch" -Level "INFO"
                return @{
                    Success = $true
                    Message = "Not on main branch - tagging skipped"
                    TagCreated = $false
                    Branch = $BranchName
                    DryRun = $DryRun.IsPresent
                }
            }

            # Step 3: Check if VERSION file was changed
            if (-not (Test-VersionFileChanged -CommitSha $CommitSha)) {
                Write-TagLog "VERSION file not changed in commit $CommitSha" -Level "INFO"
                return @{
                    Success = $true
                    Message = "VERSION file not changed - tagging skipped"
                    TagCreated = $false
                    CommitSha = $CommitSha
                    DryRun = $DryRun.IsPresent
                }
            }

            Write-TagLog "VERSION file changed detected!" -Level "SUCCESS"

            # Step 4: Get current version
            $version = Get-CurrentVersion
            $tagName = "v$version"

            Write-TagLog "Current version: $version" -Level "INFO"
            Write-TagLog "Tag to create: $tagName" -Level "INFO"

            # Step 5: Check if tag already exists
            $existingTag = git tag -l $tagName 2>&1
            if ($LASTEXITCODE -eq 0 -and $existingTag -and -not $ForceTag) {
                Write-TagLog "Tag $tagName already exists. Use -ForceTag to recreate it." -Level "WARNING"
                return @{
                    Success = $true
                    Message = "Tag already exists - creation skipped"
                    TagCreated = $false
                    TagName = $tagName
                    Version = $version
                    DryRun = $DryRun.IsPresent
                }
            }

            if ($existingTag -and $ForceTag) {
                Write-TagLog "Removing existing tag $tagName (ForceTag mode)" -Level "WARNING"
                if (-not $DryRun) {
                    git tag -d $tagName 2>&1 | Out-Null
                    git push origin ":refs/tags/$tagName" 2>&1 | Out-Null
                }
            }

            # Step 6: Create and push tag
            Write-TagLog "Creating release tag $tagName..." -Level "INFO"

            if ($DryRun) {
                Write-TagLog "DRY RUN: Would create tag $tagName for version $version" -Level "INFO"
                Write-TagLog "DRY RUN: Would push tag to origin" -Level "INFO"
                Write-TagLog "DRY RUN: Would trigger release workflow" -Level "INFO"
            } else {
                if ($PSCmdlet.ShouldProcess($tagName, "Create and push version tag")) {
                    # Create the tag
                    $tagMessage = @"
Automatic release tag v$version

Version $version release with automatic tagging.

Changes detected in VERSION file at commit $CommitSha

🤖 Generated automatically by PatchManager v3.0

Co-Authored-By: Claude <noreply@anthropic.com>
"@

                    $tagResult = git tag -a $tagName -m $tagMessage 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to create tag: $tagResult"
                    }

                    Write-TagLog "Tag created successfully" -Level "SUCCESS"

                    # Push tag to remote
                    Write-TagLog "Pushing tag to origin..." -Level "INFO"
                    $pushResult = git push origin $tagName 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Failed to push tag: $pushResult"
                    }

                    Write-TagLog "Tag pushed successfully" -Level "SUCCESS"

                    # Provide user feedback
                    if (-not $Silent) {
                        Write-Host ""
                        Write-Host "✅ Version tag $tagName created and pushed successfully!" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "🚀 GitHub Actions should now trigger the release workflow" -ForegroundColor Cyan
                        Write-Host "   This will create build artifacts and publish the release" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "Monitor progress at:" -ForegroundColor Cyan
                        Write-Host "  • Actions: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
                        Write-Host "  • Release: https://github.com/wizzense/AitherZero/releases/tag/$tagName" -ForegroundColor Cyan
                    }
                }
            }

            # Step 7: Return success result
            return @{
                Success = $true
                Message = if ($DryRun) { "Dry run completed - tag would be created" } else { "Version tag created successfully" }
                TagCreated = -not $DryRun.IsPresent
                TagName = $tagName
                Version = $version
                CommitSha = $CommitSha
                DryRun = $DryRun.IsPresent
            }

        } catch {
            $errorMessage = "Automatic version tagging failed: $($_.Exception.Message)"
            Write-TagLog $errorMessage -Level "ERROR"
            
            if (-not $Silent) {
                Write-Host ""
                Write-Host "❌ Automatic version tagging failed" -ForegroundColor Red
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""
                Write-Host "You can manually create the tag using:" -ForegroundColor Yellow
                Write-Host "  Invoke-PostMergeTagging -PRNumber <PR_NUMBER> -Description 'Manual tag creation'" -ForegroundColor Yellow
            }

            return @{
                Success = $false
                Message = $errorMessage
                TagCreated = $false
                Error = $_.Exception.Message
                DryRun = $DryRun.IsPresent
            }
        }
    }
}

# Export the function
Export-ModuleMember -Function Invoke-AutomaticVersionTagging