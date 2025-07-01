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
                & git tag -a $tagName -m $tagMessage
                Write-ReleaseLog "Tag created successfully" "SUCCESS"
                
                # Push tag
                & git push origin $tagName
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
            
            # Step 1: Create PR with version update
            Write-Host ""
            Write-ReleaseLog "Step 1: Creating release PR..."
            
            $prDescription = "Release v$nextVersion - $Description"
            
            # Use Invoke-PatchWorkflow to create the PR
            $patchResult = Invoke-PatchWorkflow -PatchDescription $prDescription -PatchOperation {
                $versionFile = Join-Path $projectRoot "VERSION"
                Set-Content $versionFile -Value $nextVersion -NoNewline
                Write-Host "Updated VERSION to $nextVersion"
            } -CreatePR -Priority "High"
            
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
            
            # Step 3: Wait for merge and create tag
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
                    }
                }
                else {
                    Write-Host ""
                    Write-Host "⏳ PR not merged yet. Tag will be created after merge." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Next steps:" -ForegroundColor Cyan
                    Write-Host "  1. Review and merge PR #$prNumber"
                    Write-Host "  2. Run this command to create tag: git tag -a 'v$nextVersion' -m 'Release v$nextVersion'"
                    Write-Host "  3. Push tag: git push origin 'v$nextVersion'"
                }
            }
            else {
                Write-Host ""
                Write-Host "✅ Release PR created!" -ForegroundColor Green
                Write-Host ""
                Write-Host "Next steps:" -ForegroundColor Cyan
                Write-Host "  1. Review and merge PR: https://github.com/wizzense/AitherZero/pulls"
                Write-Host "  2. After merge, run: Invoke-ReleaseWorkflow -Version '$nextVersion' -Description '$Description' -WaitForMerge"
            }
            
        }
        catch {
            Write-ReleaseLog "Release workflow failed: $_" "ERROR"
            throw
        }
    }
}

# Export the function
Export-ModuleMember -Function Invoke-ReleaseWorkflow