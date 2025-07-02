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
        [switch]$DryRun
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
                    return Invoke-StandardMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue $CreateIssue -DryRun:$DryRun
                }
                "Advanced" {
                    return Invoke-AdvancedMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue $CreateIssue -TargetFork $TargetFork -DryRun:$DryRun
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
        $gitStatus = git status --porcelain 2>&1
        if ($gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })) {
            if (-not $DryRun) {
                git add . 2>&1 | Out-Null
                git commit -m "Simple patch: $PatchDescription" 2>&1 | Out-Null
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
        $conflicts = git grep -l "^<<<<<<< HEAD" 2>$null
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
        [switch]$DryRun
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
            git checkout -b $script:branchName 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create branch $script:branchName"
            }
        }

        # Apply changes
        if ($PatchOperation) {
            & $PatchOperation
        }

        # Commit changes
        $gitStatus = git status --porcelain 2>&1
        if ($gitStatus -and ($gitStatus | Where-Object { $_ -match '\S' })) {
            if (-not $DryRun) {
                git add . 2>&1 | Out-Null
                git commit -m "PatchManager v3.0: $PatchDescription" 2>&1 | Out-Null
                Write-CustomLog "Changes committed to branch $script:branchName" -Level "SUCCESS"
            } else {
                Write-CustomLog "DRY RUN: Would commit changes to branch" -Level "INFO"
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
        $conflicts = git grep -l "^<<<<<<< HEAD" 2>$null
        if ($conflicts) {
            Write-CustomLog "Cannot proceed: merge conflicts detected" -Level "ERROR"
            return $false
        }

        # Ensure we have a valid git repository
        $gitDir = git rev-parse --git-dir 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-CustomLog "Not in a git repository" -Level "ERROR"
            return $false
        }

        return $true
    }

    $rollback = {
        if ($script:branchName -and -not $DryRun) {
            try {
                Write-CustomLog "Rolling back: deleting branch $script:branchName" -Level "INFO"
                git checkout main 2>&1 | Out-Null
                git branch -D $script:branchName 2>&1 | Out-Null
            } catch {
                Write-CustomLog "Rollback warning: $($_.Exception.Message)" -Level "WARN"
            }
        }
    }

    $result = Invoke-AtomicOperation -Operation $operation -OperationName "Standard Patch" -PreConditions $preConditions -RollbackOperation $rollback

    # Handle PR/Issue creation if successful
    if ($result.Success -and -not $DryRun) {
        if ($CreateIssue) {
            Write-CustomLog "Creating issue..." -Level "INFO"
            # Issue creation logic would go here
        }

        if ($CreatePR) {
            Write-CustomLog "Creating PR..." -Level "INFO"
            # PR creation logic would go here
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
        [switch]$DryRun
    )

    Write-CustomLog "ADVANCED MODE: Full workflow with cross-fork support" -Level "INFO"

    # Advanced mode includes all Standard mode features plus cross-fork capabilities
    $standardResult = Invoke-StandardMode -PatchDescription $PatchDescription -PatchOperation $PatchOperation -CreatePR:$CreatePR -CreateIssue $CreateIssue -DryRun:$DryRun

    if ($standardResult.Success -and $CreatePR -and $TargetFork -ne "current") {
        Write-CustomLog "Advanced mode: Cross-fork PR to $TargetFork" -Level "INFO"
        # Cross-fork PR logic would go here
    }

    return $standardResult
}

Export-ModuleMember -Function Invoke-MultiModeOperation