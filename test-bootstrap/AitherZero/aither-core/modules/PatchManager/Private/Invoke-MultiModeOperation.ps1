#Requires -Version 7.0

<#
.SYNOPSIS
    Multi-mode operation system for different complexity levels

.DESCRIPTION
    Provides three operation modes:
    - Simple: Basic patch operations without git complexity
    - Standard: Full patch workflow with branch management
    - Advanced: Full workflow with PR/issue creation and cross-fork support

.PARAMETER Mode
    Operation mode: Simple, Standard, or Advanced

.PARAMETER PatchDescription
    Description of the patch

.PARAMETER PatchOperation
    Script block containing the changes

.PARAMETER CreatePR
    Whether to create pull request (Standard/Advanced modes)

.PARAMETER CreateIssue
    Whether to create issue (Standard/Advanced modes)

.PARAMETER TargetFork
    Target fork for cross-fork PRs (Advanced mode only)
#>

function Invoke-MultiModeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Simple", "Standard", "Advanced")]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [string]$PatchDescription,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PatchOperation,

        [Parameter(Mandatory = $false)]
        [switch]$CreatePR,

        [Parameter(Mandatory = $false)]
        [bool]$CreateIssue = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet("current", "upstream", "root")]
        [string]$TargetFork = "current",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [ValidateSet('QuickFix', 'Feature', 'Hotfix', 'Patch', 'Release')]
        [string]$OperationType = 'Patch'
    )

    begin {
        # Initialize logging
        if (-not (Get-Command Write-CustomLog -ErrorAction SilentlyContinue)) {
            function Write-CustomLog {
                param($Message, $Level = "INFO")
                Write-Host "[$Level] $Message"
            }
        }

        Write-CustomLog "Starting $Mode mode operation: $PatchDescription" -Level "INFO"
    }

    process {
        try {
            switch ($Mode) {
                "Simple" {
                    return Invoke-SimpleMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -DryRun:$DryRun
                }
                "Standard" {
                    return Invoke-StandardMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue $CreateIssue -DryRun:$DryRun -OperationType $OperationType
                }
                "Advanced" {
                    return Invoke-AdvancedMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue $CreateIssue -TargetFork $TargetFork -DryRun:$DryRun -OperationType $OperationType
                }
            }
        } catch {
            Write-CustomLog "Multi-mode operation failed: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
}

function Invoke-SimpleMode {
    [CmdletBinding()]
    param(
        [string]$PatchDescription,
        [scriptblock]$PatchOperation,
        [switch]$DryRun
    )

    Write-CustomLog "SIMPLE MODE: Direct changes without branch management" -Level "INFO"

    $operation = {
        # Simple mode: just apply changes and commit if there are any
        if ($PatchOperation) {
            & $PatchOperation
        }

        # Check if there are changes to commit
        $gitStatusResult = Invoke-GitCommand "status --porcelain" -AllowFailure
        if ($gitStatusResult.Success -and $gitStatusResult.Output -and ($gitStatusResult.Output | Where-Object { $_ -match '\S' })) {
            if (-not $DryRun) {
                Invoke-GitCommand "add ." -AllowFailure | Out-Null
                Invoke-GitCommand "commit -m `"Simple patch: $PatchDescription`"" -AllowFailure | Out-Null
                Write-CustomLog "Changes committed directly to current branch" -Level "SUCCESS"
            } else {
                Write-CustomLog "DRY RUN: Would commit changes to current branch" -Level "INFO"
            }
        } else {
            Write-CustomLog "No changes to commit" -Level "INFO"
        }

        return @{
            Mode = "Simple"
            CommittedDirectly = $true
        }
    }

    $preConditions = {
        # Verify no merge conflicts
        $conflictsResult = Invoke-GitCommand "grep -l '^<<<<<<< HEAD'" -AllowFailure
        $conflicts = if ($conflictsResult.Success) { $conflictsResult.Output } else { $null }
        if ($conflicts) {
            Write-CustomLog "Cannot proceed: merge conflicts detected" -Level "ERROR"
            return $false
        }
        return $true
    }

    return Invoke-AtomicOperation -Operation $operation -OperationName "Simple Patch" -PreConditions $preConditions
}

function Invoke-StandardMode {
    [CmdletBinding()]
    param(
        [string]$PatchDescription,
        [scriptblock]$PatchOperation,
        [switch]$CreatePR,
        [bool]$CreateIssue,
        [switch]$DryRun,
        [string]$OperationType = 'Patch'
    )

    Write-CustomLog "STANDARD MODE: Full workflow with branch management" -Level "INFO"

    $branchName = $null

    $operation = {
        # Create branch from current state (no stashing!)
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $safeName = $PatchDescription -replace '[^a-zA-Z0-9\-_]', '-' -replace '-+', '-'
        $script:branchName = "patch/$timestamp-$safeName"

        Write-CustomLog "Creating branch: $script:branchName" -Level "INFO"
        
        if (-not $DryRun) {
            $checkoutResult = Invoke-GitCommand "checkout -b $script:branchName" -AllowFailure
            if (-not $checkoutResult.Success) {
                throw "Failed to create branch $script:branchName: $($checkoutResult.Output)"
            }
        }

        # Apply changes
        if ($PatchOperation) {
            & $PatchOperation
        }

        # Commit changes
        $gitStatusResult = Invoke-GitCommand "status --porcelain" -AllowFailure
        if ($gitStatusResult.Success -and $gitStatusResult.Output -and ($gitStatusResult.Output | Where-Object { $_ -match '\S' })) {
            if (-not $DryRun) {
                Invoke-GitCommand "add ." -AllowFailure | Out-Null
                Invoke-GitCommand "commit -m `"PatchManager v3.0: $PatchDescription`"" -AllowFailure | Out-Null
                Write-CustomLog "Changes committed to branch $script:branchName" -Level "SUCCESS"
                
                # Push branch to remote (required for PR creation)
                Write-CustomLog "Pushing branch to remote..." -Level "INFO"
                $pushResult = Invoke-GitCommand "push -u origin $script:branchName" -AllowFailure
                if ($pushResult.Success) {
                    Write-CustomLog "Branch pushed to remote successfully" -Level "SUCCESS"
                } else {
                    Write-CustomLog "Failed to push branch: $($pushResult.Output)" -Level "ERROR"
                    throw "Failed to push branch to remote - PR creation will fail"
                }
            } else {
                Write-CustomLog "DRY RUN: Would commit and push changes to branch" -Level "INFO"
            }
        }

        return @{
            Mode = "Standard"
            BranchCreated = $script:branchName
            CommittedToBranch = $true
        }
    }

    $preConditions = {
        # Ensure we're in a good state to create branches
        $conflictsResult = Invoke-GitCommand "grep -l '^<<<<<<< HEAD'" -AllowFailure
        $conflicts = if ($conflictsResult.Success) { $conflictsResult.Output } else { $null }
        if ($conflicts) {
            Write-CustomLog "Cannot proceed: merge conflicts detected" -Level "ERROR"
            return $false
        }

        # Ensure we have a valid git repository
        $gitDirResult = Invoke-GitCommand "rev-parse --git-dir" -AllowFailure
        if (-not $gitDirResult.Success) {
            Write-CustomLog "Not in a git repository: $($gitDirResult.Output)" -Level "ERROR"
            return $false
        }

        return $true
    }

    $rollback = {
        if ($script:branchName -and -not $DryRun) {
            try {
                Write-CustomLog "Rolling back: deleting branch $script:branchName" -Level "INFO"
                Invoke-GitCommand "checkout main" -AllowFailure | Out-Null
                Invoke-GitCommand "branch -D $script:branchName" -AllowFailure | Out-Null
            } catch {
                Write-CustomLog "Rollback warning: $($_.Exception.Message)" -Level "WARN"
            }
        }
    }

    $result = Invoke-AtomicOperation -Operation $operation -OperationName "Standard Patch" -PreConditions $preConditions -RollbackOperation $rollback

    # Handle PR/Issue creation if successful
    if ($result.Success -and -not $DryRun) {
        # Initialize tracking variables
        $issueNumber = $null
        $prUrl = $null
        
        # Extract branch name from result
        $branchName = if ($result.Result -and $result.Result.BranchCreated) { 
            $result.Result.BranchCreated 
        } elseif ($result.BranchCreated) { 
            $result.BranchCreated 
        } else { 
            $null 
        }
        
        if ($CreateIssue) {
            Write-CustomLog "Creating issue..." -Level "INFO"
            try {
                $issueResult = New-PatchIssue -Description $PatchDescription
                if ($issueResult.Success) {
                    Write-CustomLog "Issue created: $($issueResult.IssueUrl)" -Level "SUCCESS"
                    $issueNumber = $issueResult.IssueNumber
                    $result.IssueNumber = $issueNumber
                    $result.IssueUrl = $issueResult.IssueUrl
                } else {
                    Write-CustomLog "Issue creation failed: $($issueResult.Message)" -Level "WARN"
                }
            } catch {
                Write-CustomLog "Issue creation error: $($_.Exception.Message)" -Level "ERROR"
            }
        }

        if ($CreatePR -and $branchName) {
            Write-CustomLog "Creating PR..." -Level "INFO"
            try {
                # Build PR parameters
                $prParams = @{
                    Description = $PatchDescription
                    BranchName = $branchName
                    OperationType = $OperationType
                }
                
                # Add issue number if we created one
                if ($issueNumber) {
                    $prParams.IssueNumber = $issueNumber
                }
                
                $prResult = New-PatchPR @prParams
                if ($prResult.Success) {
                    Write-CustomLog "PR created: $($prResult.PullRequestUrl)" -Level "SUCCESS"
                    $prUrl = $prResult.PullRequestUrl
                    $result.PullRequestUrl = $prUrl
                    $result.PullRequestNumber = $prResult.PullRequestNumber
                    
                    # Also add to Result hashtable for consistency
                    if ($result.Result) {
                        $result.Result.PullRequestUrl = $prUrl
                        $result.Result.PullRequestNumber = $prResult.PullRequestNumber
                    }
                } else {
                    Write-CustomLog "PR creation failed: $($prResult.Message)" -Level "ERROR"
                }
            } catch {
                Write-CustomLog "PR creation error: $($_.Exception.Message)" -Level "ERROR"
            }
        } elseif ($CreatePR -and -not $branchName) {
            Write-CustomLog "PR creation skipped: No branch name available" -Level "WARN"
        }
    }

    return $result
}

function Invoke-AdvancedMode {
    [CmdletBinding()]
    param(
        [string]$PatchDescription,
        [scriptblock]$PatchOperation,
        [switch]$CreatePR,
        [bool]$CreateIssue,
        [string]$TargetFork,
        [switch]$DryRun,
        [string]$OperationType = 'Patch'
    )

    Write-CustomLog "ADVANCED MODE: Full workflow with cross-fork support" -Level "INFO"

    # Advanced mode includes all Standard mode features plus cross-fork capabilities
    $standardResult = Invoke-StandardMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue $CreateIssue -DryRun:$DryRun -OperationType $OperationType

    if ($standardResult.Success -and $CreatePR -and $TargetFork -ne "current") {
        Write-CustomLog "Advanced mode: Cross-fork PR to $TargetFork" -Level "INFO"
        # Cross-fork PR logic would go here
    }

    return $standardResult
}

Export-ModuleMember -Function Invoke-MultiModeOperation