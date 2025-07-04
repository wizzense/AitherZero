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
                    Start-Sleep -Seconds 60
                }
            }
            
            Write-ReleaseLog "Timeout waiting for PR merge" "WARNING"
            return $false
        }
        
        # Helper to create and push tag with comprehensive error handling
        function New-ReleaseTag {
            param(
                [string]$Version,
                [string]$Message
            )
            
            Write-ReleaseLog "Creating release tag v$Version with enhanced error handling..."
            
            try {
                # Step 1: Ensure we're on main and up to date
                $currentBranch = git branch --show-current 2>&1 | Out-String | ForEach-Object Trim
                if ($LASTEXITCODE -ne 0) {
                    Write-ReleaseLog "Failed to get current branch" "ERROR"
                    return $false
                }
                
                if ($currentBranch -ne "main") {
                    Write-ReleaseLog "Switching from '$currentBranch' to main branch..."
                    git checkout main 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-ReleaseLog "Failed to checkout main branch" "ERROR"
                        return $false
                    }
                }
                
                # Step 2: Fetch and sync with remote
                Write-ReleaseLog "Fetching latest changes from remote..."
                git fetch origin main 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-ReleaseLog "Failed to fetch from remote" "ERROR"
                    return $false
                }
                
                # Check if we're behind remote
                $behindCommits = git rev-list --count main..origin/main 2>&1 | Out-String | ForEach-Object Trim
                if ($LASTEXITCODE -eq 0 -and $behindCommits -gt 0) {
                    Write-ReleaseLog "Pulling $behindCommits commits from remote..."
                    git pull --ff-only origin main 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Write-ReleaseLog "Failed to pull changes from remote" "ERROR"
                        return $false
                    }
                }
                
                # Step 3: Verify VERSION file matches expected version
                $actualVersion = Get-CurrentVersion
                if ($actualVersion -ne $Version) {
                    Write-ReleaseLog "VERSION file mismatch: found '$actualVersion', expected '$Version'" "ERROR"
                    Write-ReleaseLog "This may indicate the PR was not merged or VERSION was modified" "WARNING"
                    return $false
                }
                
                # Step 4: Check if tag already exists
                $tagName = "v$Version"
                $existingTag = git tag -l $tagName 2>&1 | Out-String | ForEach-Object Trim
                if ($LASTEXITCODE -eq 0 -and $existingTag) {
                    Write-ReleaseLog "Tag $tagName already exists locally" "WARNING"
                    
                    # Check if it exists on remote
                    $remoteTag = git ls-remote --tags origin $tagName 2>&1 | Out-String | ForEach-Object Trim
                    if ($LASTEXITCODE -eq 0 -and $remoteTag) {
                        Write-ReleaseLog "Tag $tagName already exists on remote - release complete" "SUCCESS"
                        return $true
                    } else {
                        Write-ReleaseLog "Tag exists locally but not on remote - pushing existing tag..."
                        git push origin $tagName 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-ReleaseLog "Existing tag pushed successfully" "SUCCESS"
                            return $true
                        } else {
                            Write-ReleaseLog "Failed to push existing tag" "ERROR"
                            return $false
                        }
                    }
                }
                
                # Step 5: Create annotated tag
                $tagMessage = @"
Release $tagName - $Message

$Message

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
"@
                
                Write-ReleaseLog "Creating annotated tag $tagName..."
                git tag -a $tagName -m $tagMessage 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-ReleaseLog "Failed to create tag $tagName" "ERROR"
                    return $false
                }
                Write-ReleaseLog "Tag created successfully" "SUCCESS"
                
                # Step 6: Push tag to remote
                Write-ReleaseLog "Pushing tag $tagName to remote..."
                git push origin $tagName 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-ReleaseLog "Failed to push tag to remote" "ERROR"
                    Write-ReleaseLog "Tag exists locally but could not be pushed" "WARNING"
                    Write-ReleaseLog "You can manually push with: git push origin $tagName" "INFO"
                    return $false
                }
                Write-ReleaseLog "Tag pushed successfully" "SUCCESS"
                
                # Step 7: Verify tag was pushed successfully
                Start-Sleep -Seconds 2  # Give remote time to process
                $remoteTagVerify = git ls-remote --tags origin $tagName 2>&1 | Out-String | ForEach-Object Trim
                if ($LASTEXITCODE -eq 0 -and $remoteTagVerify) {
                    Write-ReleaseLog "✅ Tag $tagName verified on remote" "SUCCESS"
                    return $true
                } else {
                    Write-ReleaseLog "⚠️ Could not verify tag on remote (may still be processing)" "WARNING"
                    return $true  # Still consider success since push didn't error
                }
                
            }
            catch {
                Write-ReleaseLog "Unexpected error in tag creation: $($_.Exception.Message)" "ERROR"
                Write-ReleaseLog "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
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
            
            # Step 1: Create PR with version update
            Write-Host ""
            Write-ReleaseLog "Step 1: Creating release PR..."
            
            $prDescription = "Release v$nextVersion - $Description"
            
            # Use Invoke-PatchWorkflow to create the PR (without tag creation)
            $patchResult = Invoke-PatchWorkflow -PatchDescription $prDescription -PatchOperation {
                # Update VERSION file only
                $versionFile = Join-Path $projectRoot "VERSION"
                Set-Content $versionFile -Value $nextVersion -NoNewline
                Write-Host "Updated VERSION to $nextVersion"
                Write-Host "Tag will be created after PR merge to trigger build pipeline properly"
            } -CreatePR
            
            # Extract PR number from output
            $prNumber = $null
            if ($patchResult -match "PR #(\d+)") {
                $prNumber = $Matches[1]
                Write-ReleaseLog "Created PR #$prNumber" "SUCCESS"
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
            
            # Step 3: Prepare for tag creation after merge
            Write-Host ""
            Write-ReleaseLog "✅ Release PR created successfully!" "SUCCESS"
            Write-ReleaseLog "Next steps:" "INFO"
            Write-ReleaseLog "  1. Review and merge PR #$prNumber" "INFO" 
            Write-ReleaseLog "  2. Tag v$nextVersion will be created after merge" "INFO"
            Write-ReleaseLog "  3. Build pipeline will trigger automatically" "INFO"
            
            if ($WaitForMerge -and $prNumber) {
                Write-Host ""
                Write-ReleaseLog "Step 3: Monitoring PR merge status..."
                
                $merged = Wait-ForPRMerge -PRNumber $prNumber -MaxMinutes $MaxWaitMinutes
                
                if ($merged) {
                    Write-Host ""
                    Write-ReleaseLog "✅ PR merged successfully!" "SUCCESS"
                    
                    Write-Host ""
                    Write-ReleaseLog "Step 4: Creating release tag..."
                    
                    # Now create and push the tag after successful merge
                    $tagCreated = New-ReleaseTag -Version $nextVersion -Message $Description
                    
                    if ($tagCreated) {
                        Write-Host ""
                        Write-Host "✅ Release v$nextVersion created successfully!" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "Monitor build at: https://github.com/wizzense/AitherZero/actions" -ForegroundColor Cyan
                        Write-Host "View release at: https://github.com/wizzense/AitherZero/releases/tag/v$nextVersion" -ForegroundColor Cyan
                    } else {
                        Write-Host ""
                        Write-Host "⚠️ PR merged but tag creation failed!" -ForegroundColor Yellow
                        Write-Host "You can manually create the tag with:" -ForegroundColor Cyan
                        Write-Host "  git tag -a v$nextVersion -m 'Release v$nextVersion - $Description'" -ForegroundColor Gray
                        Write-Host "  git push origin v$nextVersion" -ForegroundColor Gray
                    }
                }
                else {
                    Write-Host ""
                    Write-Host "⏳ PR not merged within timeout. Tag will be created after merge." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Next steps:" -ForegroundColor Cyan
                    Write-Host "  1. Review and merge PR #$prNumber"
                    Write-Host "  2. Run this command again to create tag and trigger build:"
                    Write-Host "     Invoke-ReleaseWorkflow -Version '$nextVersion' -Description '$Description' -WaitForMerge"
                    Write-Host "  3. Or manually create tag after merge:"
                    Write-Host "     git tag -a v$nextVersion -m 'Release v$nextVersion - $Description'"
                    Write-Host "     git push origin v$nextVersion"
                }
            }
            else {
                Write-Host ""
                Write-Host "✅ Release PR created!" -ForegroundColor Green
                Write-Host ""
                Write-Host "Next steps:" -ForegroundColor Cyan
                Write-Host "  1. Review and merge PR: https://github.com/wizzense/AitherZero/pulls"
                Write-Host "  2. After merge, create tag to trigger build:"
                Write-Host "     Invoke-ReleaseWorkflow -Version '$nextVersion' -Description '$Description' -WaitForMerge"
                Write-Host "  3. Or manually create tag after merge:"
                Write-Host "     git tag -a v$nextVersion -m 'Release v$nextVersion - $Description'"
                Write-Host "     git push origin v$nextVersion"
            }
            
        }
        catch {
            Write-ReleaseLog "Release workflow failed: $($_.Exception.Message)" "ERROR"
            Write-ReleaseLog "Error occurred at: $($_.InvocationInfo.ScriptLineNumber)" "DEBUG"
            
            # Provide recovery guidance based on error type
            $errorMessage = $_.Exception.Message
            Write-Host ""
            Write-Host "🛠️ Error Recovery Guidance:" -ForegroundColor Yellow
            
            if ($errorMessage -like "*git*" -or $errorMessage -like "*fetch*" -or $errorMessage -like "*pull*") {
                Write-Host "  Git Operation Error detected:" -ForegroundColor Cyan
                Write-Host "  1. Check network connectivity and git remote settings" -ForegroundColor Gray
                Write-Host "  2. Verify you have push permissions to the repository" -ForegroundColor Gray
                Write-Host "  3. Try running: git fetch origin && git status" -ForegroundColor Gray
                Write-Host "  4. If diverged, run: ./scripts/Fix-GitDivergence.ps1" -ForegroundColor Gray
            }
            elseif ($errorMessage -like "*VERSION*" -or $errorMessage -like "*file*") {
                Write-Host "  VERSION File Error detected:" -ForegroundColor Cyan
                Write-Host "  1. Check if VERSION file exists and is accessible" -ForegroundColor Gray
                Write-Host "  2. Verify current directory is the project root" -ForegroundColor Gray
                Write-Host "  3. Ensure no other process is using the VERSION file" -ForegroundColor Gray
            }
            elseif ($errorMessage -like "*PR*" -or $errorMessage -like "*GitHub*") {
                Write-Host "  GitHub API Error detected:" -ForegroundColor Cyan
                Write-Host "  1. Check if GitHub CLI (gh) is installed and authenticated" -ForegroundColor Gray
                Write-Host "  2. Verify repository permissions and network access" -ForegroundColor Gray
                Write-Host "  3. Try running: gh auth status" -ForegroundColor Gray
            }
            else {
                Write-Host "  General Error Recovery:" -ForegroundColor Cyan
                Write-Host "  1. Check error details above for specific guidance" -ForegroundColor Gray
                Write-Host "  2. Ensure all prerequisites are met (git, gh cli, permissions)" -ForegroundColor Gray
                Write-Host "  3. Try running the command again with -DryRun first" -ForegroundColor Gray
            }
            
            Write-Host ""
            Write-Host "📋 Manual Recovery Commands:" -ForegroundColor Yellow
            Write-Host "  # If you need to create the tag manually:" -ForegroundColor Gray
            Write-Host "  git tag -a v$nextVersion -m 'Release v$nextVersion - $Description'" -ForegroundColor Gray
            Write-Host "  git push origin v$nextVersion" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  # If you need to retry the release workflow:" -ForegroundColor Gray
            Write-Host "  Invoke-ReleaseWorkflow -ReleaseType '$ReleaseType' -Description '$Description'" -ForegroundColor Gray
            
            throw "Release workflow failed. See recovery guidance above."
        }
    }
}

# Export the function
Export-ModuleMember -Function Invoke-ReleaseWorkflow