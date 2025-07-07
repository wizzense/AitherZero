#Requires -Version 7.0

<#
.SYNOPSIS
    Complete release automation for AitherZero - handles version, PR, merge, and tagging
    
.DESCRIPTION
    This function provides true one-command release automation:
    1. Updates VERSION file based on release type
    2. Creates PR using PatchManager standards
    3. Monitors PR for merge (with timeout)
    4. Automatically creates and pushes release tag after merge
    5. Monitors build pipeline
    
    No manual steps required - just run and wait!
    
.PARAMETER ReleaseType
    Type of release: patch, minor, major
    
.PARAMETER Version
    Specific version to release (overrides ReleaseType)
    
.PARAMETER Description
    Release description for PR and tag
    
.PARAMETER AutoMerge
    Attempt to auto-merge PR if all checks pass (requires permissions)
    
.PARAMETER WaitForMerge
    Wait for PR to be merged before creating tag (default: true)
    
.PARAMETER MaxWaitMinutes
    Maximum minutes to wait for PR merge (default: 30)
    
.PARAMETER DryRun
    Preview what would be done without making changes
    
.EXAMPLE
    Invoke-ReleaseWorkflow -ReleaseType "patch" -Description "Bug fixes and improvements"
    # Creates v1.2.4 from v1.2.3, handles everything automatically
    
.EXAMPLE
    Invoke-ReleaseWorkflow -Version "2.0.0" -Description "Major rewrite" -AutoMerge
    # Creates v2.0.0, attempts auto-merge, creates tag after merge
    
.EXAMPLE
    Invoke-ReleaseWorkflow -ReleaseType "minor" -Description "New features" -WaitForMerge:$false
    # Creates PR but doesn't wait for merge or create tag
#>

function Invoke-ReleaseWorkflow {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ReleaseType')]
        [ValidateSet("patch", "minor", "major")]
        [string]$ReleaseType,
        
        [Parameter(Mandatory, ParameterSetName = 'Version')]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$Version,
        
        [Parameter(Mandatory)]
        [string]$Description,
        
        [switch]$AutoMerge,
        
        [bool]$WaitForMerge = $true,
        
        [int]$MaxWaitMinutes = 30,
        
        [switch]$DryRun
    )
    
    begin {
        # Import required functions
        $ErrorActionPreference = 'Stop'
        
        # Find project root
        $projectRoot = Find-ProjectRoot -StartPath $PSScriptRoot
        if (-not $projectRoot) {
            throw "Could not find project root"
        }
        
        # Helper function for logging
        function Write-ReleaseLog {
            param([string]$Message, [string]$Level = "INFO")
            
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Level $Level -Message "ReleaseWorkflow: $Message"
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
        
        # Helper to get current version
        function Get-CurrentVersion {
            $versionFile = Join-Path $projectRoot "VERSION"
            if (-not (Test-Path $versionFile)) {
                throw "VERSION file not found at: $versionFile"
            }
            return (Get-Content $versionFile -Raw).Trim()
        }
        
        # Helper to calculate next version
        function Get-NextVersion {
            param(
                [string]$Current,
                [string]$Type,
                [string]$Override
            )
            
            if ($Override) {
                return $Override
            }
            
            $parts = $Current -split '\.'
            
            switch ($Type) {
                "patch" { 
                    $parts[2] = [int]$parts[2] + 1 
                }
                "minor" { 
                    $parts[1] = [int]$parts[1] + 1
                    $parts[2] = "0"
                }
                "major" { 
                    $parts[0] = [int]$parts[0] + 1
                    $parts[1] = "0"
                    $parts[2] = "0"
                }
            }
            
            return $parts -join '.'
        }
        
        # Helper to wait for PR merge
        function Wait-ForPRMerge {
            param(
                [string]$PRNumber,
                [int]$MaxMinutes
            )
            
            $startTime = Get-Date
            $timeout = $startTime.AddMinutes($MaxMinutes)
            
            Write-ReleaseLog "Waiting for PR #$PRNumber to be merged (timeout: $MaxMinutes minutes)..."
            
            # Check if gh CLI is available
            $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
            
            if (-not $ghAvailable) {
                Write-ReleaseLog "GitHub CLI not available. Please merge PR manually and the tag will be created on next run." "WARNING"
                return $false
            }
            
            # First, check if PR is already merged (common case)
            try {
                $prStatus = & gh pr view $PRNumber --json state,mergedAt | ConvertFrom-Json
                if ($prStatus.state -eq "MERGED") {
                    Write-ReleaseLog "PR #$PRNumber is already merged!" "SUCCESS"
                    return $true
                }
            }
            catch {
                Write-ReleaseLog "Error checking initial PR status: $_" "WARNING"
            }
            
            while ((Get-Date) -lt $timeout) {
                try {
                    $prStatus = & gh pr view $PRNumber --json state,mergedAt | ConvertFrom-Json
                    
                    if ($prStatus.state -eq "MERGED") {
                        Write-ReleaseLog "PR #$PRNumber has been merged!" "SUCCESS"
                        return $true
                    }
                    elseif ($prStatus.state -eq "CLOSED") {
                        Write-ReleaseLog "PR #$PRNumber was closed without merging" "ERROR"
                        return $false
                    }
                    
                    # Show progress
                    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalMinutes, 1)
                    Write-Host "`rWaiting for merge... ($elapsed/$MaxMinutes minutes)" -NoNewline
                    
                    Start-Sleep -Seconds 30
                }
                catch {
                    Write-ReleaseLog "Error checking PR status: $_" "WARNING"
                    # Don't sleep as long on errors to retry faster
                    Start-Sleep -Seconds 15
                }
            }
            
            Write-ReleaseLog "Timeout waiting for PR merge after $MaxMinutes minutes" "WARNING"
            Write-ReleaseLog "You can manually create the tag after merge with: Invoke-ReleaseWorkflow -Version [version] -WaitForMerge:`$false" "INFO"
            return $false
        }
        
        # Helper to check if release branch already exists
        function Test-ReleaseBranch {
            param(
                [string]$Version,
                [string]$ProjectRoot
            )
            
            # Generate expected branch name (same pattern as PatchManager)
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $branchPattern = "patch/*-Release-v$($Version -replace '\.', '-')-Release"
            
            # Check for existing branches matching this release
            $existingBranches = & git branch -a | Where-Object { $_ -match "Release-v$($Version -replace '\.', '-')" }
            
            if ($existingBranches) {
                # Extract the actual branch name
                $branchName = ($existingBranches[0] -replace '\s*remotes/origin/', '' -replace '\s*', '').Trim()
                
                Write-ReleaseLog "Found existing release branch: $branchName"
                
                # Check if it has the correct VERSION file content
                $currentBranch = & git branch --show-current
                try {
                    & git checkout $branchName 2>$null
                    $branchVersion = Get-CurrentVersion
                    
                    if ($branchVersion -eq $Version) {
                        Write-ReleaseLog "Branch has correct version: $branchVersion" "SUCCESS"
                        return @{
                            Exists = $true
                            BranchName = $branchName
                            HasCorrectVersion = $true
                        }
                    } else {
                        Write-ReleaseLog "Branch has wrong version: $branchVersion (expected: $Version)" "WARNING"
                        return @{
                            Exists = $true
                            BranchName = $branchName
                            HasCorrectVersion = $false
                        }
                    }
                } finally {
                    # Return to original branch
                    if ($currentBranch) {
                        & git checkout $currentBranch 2>$null
                    }
                }
            }
            
            return @{
                Exists = $false
                BranchName = $null
                HasCorrectVersion = $false
            }
        }
        
        # Helper to create PR for existing branch
        function New-ExistingBranchPR {
            param(
                [string]$BranchName,
                [string]$Version,
                [string]$Description
            )
            
            Write-ReleaseLog "Creating PR for existing branch: $BranchName"
            
            # Check if gh CLI is available
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                Write-ReleaseLog "GitHub CLI not available for PR creation" "ERROR"
                return $null
            }
            
            # Check if PR already exists
            try {
                $existingPR = & gh pr list --head $BranchName --json number,url | ConvertFrom-Json
                if ($existingPR) {
                    Write-ReleaseLog "PR already exists: $($existingPR.url)" "SUCCESS"
                    return $existingPR.number
                }
            } catch {
                Write-ReleaseLog "Error checking for existing PR: $_" "WARNING"
            }
            
            # Create new PR
            try {
                $prTitle = "Release v$Version - $Description"
                $prBody = @"
## Release v$Version

$Description

### Changes
- Updated VERSION to $Version
- Ready for merge and release

### Post-merge actions
After merging this PR:
1. Tag will be created automatically: ``v$Version``
2. Build artifacts will be generated for all platforms
3. GitHub release will be published

---
🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
                
                $prResult = & gh pr create --title $prTitle --body $prBody --head $BranchName --base main
                
                # Extract PR number
                if ($prResult -match '#(\d+)') {
                    $prNumber = $Matches[1]
                    Write-ReleaseLog "Created PR #$prNumber" "SUCCESS"
                    return $prNumber
                } else {
                    Write-ReleaseLog "PR created but couldn't extract number" "WARNING"
                    return $null
                }
            } catch {
                Write-ReleaseLog "Failed to create PR: $_" "ERROR"
                return $null
            }
        }
        
        # Helper to create and push tag
        function New-ReleaseTag {
            param(
                [string]$Version,
                [string]$Message
            )
            
            Write-ReleaseLog "Creating release tag v$Version..."
            
            # Ensure we're on main and up to date
            $currentBranch = & git branch --show-current
            if ($currentBranch -ne "main") {
                Write-ReleaseLog "Switching to main branch..."
                & git checkout main
            }
            
            Write-ReleaseLog "Pulling latest changes..."
            & git pull origin main
            
            # Verify VERSION file matches expected version
            $actualVersion = Get-CurrentVersion
            if ($actualVersion -ne $Version) {
                Write-ReleaseLog "VERSION file shows $actualVersion but expected $Version" "WARNING"
                Write-ReleaseLog "PR may not have been merged yet or VERSION was changed" "WARNING"
                return $false
            }
            
            # Create annotated tag
            $tagName = "v$Version"
            $tagMessage = @"
Release $tagName - $Message

$Message

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
            
            try {
                # Check if tag already exists
                $existingTag = & git tag -l $tagName
                if ($existingTag) {
                    Write-ReleaseLog "Tag $tagName already exists" "WARNING"
                    return $true
                }
                
                # Create tag with explicit error checking
                Write-ReleaseLog "Creating annotated tag: $tagName" "INFO"
                & git tag -a $tagName -m $tagMessage
                
                if ($LASTEXITCODE -ne 0) {
                    Write-ReleaseLog "Failed to create tag (exit code: $LASTEXITCODE)" "ERROR"
                    return $false
                }
                
                Write-ReleaseLog "Tag created successfully" "SUCCESS"
                
                # Push tag with explicit error checking
                Write-ReleaseLog "Pushing tag to origin..." "INFO"
                & git push origin $tagName
                
                if ($LASTEXITCODE -ne 0) {
                    Write-ReleaseLog "Failed to push tag (exit code: $LASTEXITCODE)" "ERROR"
                    return $false
                }
                
                Write-ReleaseLog "Tag pushed successfully" "SUCCESS"
                
                return $true
            }
            catch {
                Write-ReleaseLog "Failed to create/push tag: $_" "ERROR"
                return $false
            }
        }
    }
    
    process {
        try {
            Write-Host ""
            Write-Host "🚀 AitherZero Release Workflow" -ForegroundColor Magenta
            Write-Host ("=" * 50) -ForegroundColor Magenta
            
            # Get current and next version
            $currentVersion = Get-CurrentVersion
            $nextVersion = Get-NextVersion -Current $currentVersion -Type $ReleaseType -Override $Version
            
            Write-ReleaseLog "Current version: $currentVersion"
            Write-ReleaseLog "Next version: $nextVersion" "SUCCESS"
            Write-ReleaseLog "Description: $Description"
            
            if ($DryRun) {
                Write-Host ""
                Write-Host "DRY RUN - No changes will be made" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Would perform:" -ForegroundColor Cyan
                Write-Host "  1. Update VERSION to $nextVersion"
                Write-Host "  2. Create PR: 'Release v$nextVersion - $Description'"
                Write-Host "  3. Wait for PR merge"
                Write-Host "  4. Create and push tag v$nextVersion"
                Write-Host "  5. Monitor build pipeline"
                return
            }
            
            # Step 1: Check for existing release branch or create new one
            Write-Host ""
            Write-ReleaseLog "Step 1: Checking for existing release branch..."
            
            $prDescription = "Release v$nextVersion - $Description"
            $branchCheck = Test-ReleaseBranch -Version $nextVersion -ProjectRoot $projectRoot
            $prNumber = $null
            
            if ($branchCheck.Exists -and $branchCheck.HasCorrectVersion) {
                Write-ReleaseLog "Found existing release branch with correct version" "SUCCESS"
                Write-ReleaseLog "Skipping patch creation, proceeding to PR creation..."
                
                # Try to create PR for existing branch
                $prNumber = New-ExistingBranchPR -BranchName $branchCheck.BranchName -Version $nextVersion -Description $Description
                
                if ($prNumber) {
                    Write-ReleaseLog "PR created/found for existing branch: #$prNumber" "SUCCESS"
                } else {
                    Write-ReleaseLog "Failed to create PR for existing branch" "ERROR"
                    Write-Host ""
                    Write-Host "⚠️  Manual action required:" -ForegroundColor Yellow
                    Write-Host "  Branch exists: $($branchCheck.BranchName)"
                    Write-Host "  Create PR manually: https://github.com/wizzense/AitherZero/compare/$($branchCheck.BranchName)"
                }
            } else {
                if ($branchCheck.Exists) {
                    Write-ReleaseLog "Found existing branch but with wrong version, creating new patch..." "WARNING"
                } else {
                    Write-ReleaseLog "No existing release branch found, creating new patch..." "INFO"
                }
                
                # Use Invoke-PatchWorkflow to create the PR
                $patchResult = Invoke-PatchWorkflow -PatchDescription $prDescription -PatchOperation {
                    $versionFile = Join-Path $projectRoot "VERSION"
                    Set-Content $versionFile -Value $nextVersion -NoNewline
                    Write-Host "Updated VERSION to $nextVersion"
                } -CreatePR
                
                # Extract PR number from output
                if ($patchResult -match "PR #(\d+)") {
                    $prNumber = $Matches[1]
                    Write-ReleaseLog "Created PR #$prNumber via patch workflow" "SUCCESS"
                } elseif ($patchResult -match "Issue created: .*/issues/(\d+)") {
                    # Sometimes only issue is created, not PR
                    $issueNumber = $Matches[1]
                    Write-ReleaseLog "Patch created issue #$issueNumber, checking for PR..." "INFO"
                    
                    # Try to find the PR manually
                    if ($branchCheck.Exists) {
                        $prNumber = New-ExistingBranchPR -BranchName $branchCheck.BranchName -Version $nextVersion -Description $Description
                    }
                }
            }
            
            # Step 2: Auto-merge if requested
            if ($AutoMerge -and $prNumber) {
                Write-Host ""
                Write-ReleaseLog "Step 2: Attempting auto-merge..."
                
                if (Get-Command gh -ErrorAction SilentlyContinue) {
                    try {
                        & gh pr merge $prNumber --auto --merge
                        Write-ReleaseLog "Auto-merge enabled for PR #$prNumber" "SUCCESS"
                    }
                    catch {
                        Write-ReleaseLog "Could not enable auto-merge: $_" "WARNING"
                    }
                }
            }
            
            # Step 3: Wait for merge and create tag
            if ($WaitForMerge) {
                # If no PR number but we have a branch, try to find the PR
                if (-not $prNumber -and $branchCheck.Exists) {
                    Write-ReleaseLog "No PR number available, checking for existing PR..."
                    try {
                        $prList = & gh pr list --head $branchCheck.BranchName --json number,state,url | ConvertFrom-Json
                        if ($prList -and $prList.Count -gt 0) {
                            $prNumber = $prList[0].number
                            $prState = $prList[0].state
                            Write-ReleaseLog "Found existing PR #$prNumber (state: $prState)" "SUCCESS"
                        }
                    } catch {
                        Write-ReleaseLog "Could not check for existing PR: $_" "WARNING"
                    }
                }
                
                # If still no PR number, check manually
                if (-not $prNumber) {
                    Write-Host ""
                    Write-Host "⚠️  No PR found. Checking if VERSION is already updated in main..." -ForegroundColor Yellow
                    
                    # Check if VERSION in main already matches
                    $mainVersion = & git show origin/main:VERSION 2>$null
                    if ($mainVersion -eq $nextVersion) {
                        Write-ReleaseLog "VERSION already updated to $nextVersion in main!" "SUCCESS"
                        
                        # Check if tag exists
                        $tagExists = & git tag -l "v$nextVersion"
                        if (-not $tagExists) {
                            Write-Host ""
                            Write-ReleaseLog "Creating missing tag for already-merged release..."
                            
                            # Create tag directly
                            $tagCreated = New-ReleaseTag -Version $nextVersion -Message $Description
                            
                            if ($tagCreated) {
                                Write-Host ""
                                Write-Host "✅ Release v$nextVersion tagged successfully!" -ForegroundColor Green
                                Write-Host ""
                                Write-Host "The release workflow will now build artifacts automatically." -ForegroundColor Cyan
                                Write-Host "Monitor at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
                            }
                        } else {
                            Write-Host "✅ Tag v$nextVersion already exists!" -ForegroundColor Green
                        }
                        return
                    }
                    
                    Write-Host ""
                    Write-Host "Next steps:" -ForegroundColor Cyan
                    Write-Host "  1. Create PR manually from branch: $($branchCheck.BranchName)"
                    Write-Host "  2. After merge, tag will be created automatically"
                    return
                }
            
            if ($WaitForMerge -and $prNumber) {
                Write-Host ""
                Write-ReleaseLog "Step 3: Waiting for PR merge..."
                
                $merged = Wait-ForPRMerge -PRNumber $prNumber -MaxMinutes $MaxWaitMinutes
                
                if ($merged) {
                    Write-Host ""
                    Write-ReleaseLog "Step 4: Creating release tag..."
                    
                    # Give GitHub a moment to update
                    Start-Sleep -Seconds 5
                    
                    $tagCreated = New-ReleaseTag -Version $nextVersion -Message $Description
                    
                    if ($tagCreated) {
                        Write-Host ""
                        Write-ReleaseLog "Step 5: Monitoring build pipeline..."
                        
                        Write-Host ""
                        Write-Host "✅ Release v$nextVersion created successfully!" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Monitor build at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
                        Write-Host "View release at: https://github.com/wizzense/AitherZero/releases/tag/v$nextVersion" -ForegroundColor Cyan
                    }
                    else {
                        Write-ReleaseLog "Tag creation failed - you may need to create it manually" "ERROR"
                        Write-Host ""
                        Write-Host "⚠️  Manual tag creation required:" -ForegroundColor Yellow
                        Write-Host "  git tag -a 'v$nextVersion' -m 'Release v$nextVersion - $Description'"
                        Write-Host "  git push origin 'v$nextVersion'"
                    }
                }
                else {
                    Write-Host ""
                    Write-Host "⏳ PR not merged yet. Tag will be created after merge." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Next steps:" -ForegroundColor Cyan
                    Write-Host "  1. Review and merge PR #$prNumber"
                    Write-Host "  2. Run this command to create tag: Invoke-ReleaseWorkflow -Version '$nextVersion' -Description '$Description' -WaitForMerge:`$false"
                    Write-Host "  3. Or manually: git tag -a 'v$nextVersion' -m 'Release v$nextVersion - $Description' && git push origin 'v$nextVersion'"
                }
            } else {
                # Check if this is a recovery run for an already merged PR
                if ($prNumber -and (-not $WaitForMerge)) {
                    Write-Host ""
                    Write-ReleaseLog "Step 3: Checking if PR is already merged (recovery mode)..."
                    
                    try {
                        $prStatus = & gh pr view $prNumber --json state,mergedAt | ConvertFrom-Json
                        if ($prStatus.state -eq "MERGED") {
                            Write-ReleaseLog "PR #$prNumber is already merged - creating tag now" "SUCCESS"
                            
                            # Give GitHub a moment to update
                            Start-Sleep -Seconds 3
                            
                            $tagCreated = New-ReleaseTag -Version $nextVersion -Message $Description
                            
                            if ($tagCreated) {
                                Write-Host ""
                                Write-Host "✅ Release v$nextVersion tag created successfully!" -ForegroundColor Green
                                Write-Host ""
                                Write-Host "Monitor build at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
                                Write-Host "View release at: https://github.com/wizzense/AitherZero/releases/tag/v$nextVersion" -ForegroundColor Cyan
                            }
                            else {
                                Write-ReleaseLog "Tag creation failed in recovery mode" "ERROR"
                            }
                        }
                        else {
                            Write-ReleaseLog "PR #$prNumber is not merged yet (state: $($prStatus.state))" "WARNING"
                        }
                    }
                    catch {
                        Write-ReleaseLog "Could not check PR status in recovery mode: $_" "WARNING"
                    }
                }
            }
            
        }
        
        Write-Host ""
        if ($prNumber) {
            Write-Host "✅ Release PR ready!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "  1. Review and merge PR #$prNumber`: https://github.com/wizzense/AitherZero/pulls/$prNumber"
            Write-Host "  2. After merge, tag v$nextVersion will be created automatically"
            Write-Host "  3. Build artifacts will be generated automatically"
        } else {
            Write-Host "⚠️  Release preparation completed but PR creation failed" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Cyan
            Write-Host "  1. Check for existing PR: https://github.com/wizzense/AitherZero/pulls"
            Write-Host "  2. If no PR exists, create one manually from the release branch"
            Write-Host "  3. After merge, run: Invoke-ReleaseWorkflow -Version '$nextVersion' -Description '$Description' -WaitForMerge:$false"
        }
            
        } catch {
            # Enhanced error handling for common scenarios
            $errorMessage = $_.Exception.Message
            
            if ($errorMessage -match "No commits between .* and .*") {
                Write-Host ""
                Write-Host "🔍 No commits detected between branches" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "This usually means:" -ForegroundColor Cyan
                Write-Host "  • The release branch already exists with the changes"
                Write-Host "  • The VERSION file is already updated"
                Write-Host "  • A PR may already exist for this release"
                Write-Host ""
                Write-Host "Check:" -ForegroundColor Green
                Write-Host "  1. Existing PRs: https://github.com/wizzense/AitherZero/pulls"
                Write-Host "  2. Release branches: git branch -a | grep Release"
                Write-Host "  3. Re-run the release script - it should handle existing branches"
                
                Write-ReleaseLog "No commits error - this is often recoverable" "WARNING"
            } elseif ($errorMessage -match "pull request create failed") {
                Write-Host ""
                Write-Host "🔍 PR creation failed" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Possible reasons:" -ForegroundColor Cyan
                Write-Host "  • A PR for this release already exists"
                Write-Host "  • Branch permissions or GitHub CLI issues"
                Write-Host "  • Network connectivity problems"
                Write-Host ""
                Write-Host "Next steps:" -ForegroundColor Green
                Write-Host "  1. Check existing PRs: https://github.com/wizzense/AitherZero/pulls"
                Write-Host "  2. Verify GitHub CLI: gh auth status"
                Write-Host "  3. Create PR manually if needed"
                
                Write-ReleaseLog "PR creation failed - may be recoverable" "WARNING"
            } else {
                Write-ReleaseLog "Release workflow failed: $errorMessage" "ERROR"
                Write-Host ""
                Write-Host "❌ Release workflow failed" -ForegroundColor Red
                Write-Host "Error: $errorMessage" -ForegroundColor Red
                throw
            }
        }
    }
    
    end {
        # No cleanup needed for release workflow
    }
}

# Export the function
Export-ModuleMember -Function Invoke-ReleaseWorkflow