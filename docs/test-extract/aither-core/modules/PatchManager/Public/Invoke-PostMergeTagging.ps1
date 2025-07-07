#Requires -Version 7.0

<#
.SYNOPSIS
    Creates release tags for merged PRs that are missing tags (recovery function)
    
.DESCRIPTION
    This function is designed to fix situations where:
    - A release PR was merged successfully
    - The VERSION file was updated
    - But the release tag was never created
    
    This is the recovery function to fix broken release automation.
    
.PARAMETER PRNumber
    The PR number that was merged
    
.PARAMETER Version
    The version that should be tagged (optional - will read from VERSION file)
    
.PARAMETER Description
    Description for the release tag
    
.PARAMETER Force
    Create the tag even if it already exists (will recreate it)
    
.EXAMPLE
    Invoke-PostMergeTagging -PRNumber 404 -Description "Fix build and release process to generate proper artifacts"
    
.EXAMPLE
    Invoke-PostMergeTagging -PRNumber 404 -Version "0.6.25" -Description "Fix build and release process" -Force
#>

function Invoke-PostMergeTagging {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$PRNumber,
        
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [switch]$Force
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
            
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level $Level -Message "PostMergeTagging: $Message"
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
    }
    
    process {
        try {
            Write-Host ""
            Write-Host "🏷️  Post-Merge Tag Creation" -ForegroundColor Magenta
            Write-Host ("=" * 40) -ForegroundColor Magenta
            
            # Step 1: Verify PR is merged
            Write-TagLog "Step 1: Verifying PR #$PRNumber is merged..."
            
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) is required but not available"
            }
            
            $prStatus = & gh pr view $PRNumber --json state,mergedAt,title | ConvertFrom-Json
            
            if ($prStatus.state -ne "MERGED") {
                throw "PR #$PRNumber is not merged (state: $($prStatus.state))"
            }
            
            Write-TagLog "PR #$PRNumber is merged: '$($prStatus.title)'" "SUCCESS"
            Write-TagLog "Merged at: $($prStatus.mergedAt)" "INFO"
            
            # Step 2: Determine version
            if (-not $Version) {
                $Version = Get-CurrentVersion
                Write-TagLog "Using version from VERSION file: $Version" "INFO"
            } else {
                Write-TagLog "Using specified version: $Version" "INFO"
            }
            
            # Step 3: Ensure we're on main and up to date
            Write-TagLog "Step 2: Syncing with main branch..."
            
            $currentBranch = & git branch --show-current
            if ($currentBranch -ne "main") {
                Write-TagLog "Switching to main branch..." "INFO"
                & git checkout main
            }
            
            Write-TagLog "Pulling latest changes..." "INFO"
            & git pull origin main
            
            # Step 4: Verify VERSION file
            $actualVersion = Get-CurrentVersion
            if ($actualVersion -ne $Version) {
                throw "VERSION file shows $actualVersion but expected $Version. PR may not have been merged properly."
            }
            
            Write-TagLog "VERSION file confirmed: $actualVersion" "SUCCESS"
            
            # Step 5: Check if tag already exists
            $tagName = "v$Version"
            $existingTag = & git tag -l $tagName
            
            if ($existingTag -and -not $Force) {
                Write-TagLog "Tag $tagName already exists. Use -Force to recreate it." "WARNING"
                return
            }
            
            if ($existingTag -and $Force) {
                Write-TagLog "Removing existing tag $tagName (Force mode)" "WARNING"
                & git tag -d $tagName
                & git push origin :refs/tags/$tagName
            }
            
            # Step 6: Create and push tag
            Write-TagLog "Step 3: Creating release tag $tagName..." "INFO"
            
            $tagMessage = @"
Release $tagName - $Description

$Description

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
            
            & git tag -a $tagName -m $tagMessage
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create tag (exit code: $LASTEXITCODE)"
            }
            
            Write-TagLog "Tag created successfully" "SUCCESS"
            
            # Push tag
            Write-TagLog "Pushing tag to origin..." "INFO"
            & git push origin $tagName
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push tag (exit code: $LASTEXITCODE)"
            }
            
            Write-TagLog "Tag pushed successfully" "SUCCESS"
            
            # Step 7: Confirmation
            Write-Host ""
            Write-Host "✅ Release tag $tagName created successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "🚀 GitHub Actions should now trigger the release workflow" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Monitor build at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
            Write-Host "View release at: https://github.com/wizzense/AitherZero/releases/tag/$tagName" -ForegroundColor Cyan
            
        }
        catch {
            Write-TagLog "Post-merge tagging failed: $_" "ERROR"
            Write-Host ""
            Write-Host "❌ Post-merge tagging failed" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            throw
        }
    }
}

# Export the function
Export-ModuleMember -Function Invoke-PostMergeTagging