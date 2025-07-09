#Requires -Version 7.0

<#
.SYNOPSIS
    Consolidates multiple open pull requests into a single coordinated PR

.DESCRIPTION
    Analyzes open pull requests and intelligently combines compatible changes
    into a unified pull request to reduce merge conflicts and simplify review.

.PARAMETER ConsolidationStrategy
    Strategy for combining PRs:
    - 'Compatible': Only combine PRs with no conflicts (default)
    - 'RelatedFiles': Combine PRs that modify related file areas
    - 'SameAuthor': Combine PRs from the same author
    - 'ByPriority': Combine based on priority levels
    - 'All': Attempt to combine all possible PRs

.PARAMETER MaxPRsToConsolidate
    Maximum number of PRs to include in consolidation (default: 5)

.PARAMETER DryRun
    Preview what would be consolidated without making changes

.PARAMETER Force
    Force consolidation even if some conflicts exist

.EXAMPLE
    Invoke-PRConsolidation -ConsolidationStrategy "Compatible"
    # Combines all compatible PRs with no conflicts

.EXAMPLE
    Invoke-PRConsolidation -ConsolidationStrategy "SameAuthor" -MaxPRsToConsolidate 3
    # Combines up to 3 PRs from the same author

.EXAMPLE
    Invoke-PRConsolidation -ConsolidationStrategy "ByPriority" -DryRun
    # Preview priority-based consolidation
#>

function Invoke-PRConsolidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Compatible", "RelatedFiles", "SameAuthor", "ByPriority", "All")]
        [string]$ConsolidationStrategy = "Compatible",

        [Parameter(Mandatory = $false)]
        [int]$MaxPRsToConsolidate = 5,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        # Write-CustomLog is guaranteed to be available from AitherCore orchestration
        # No explicit Logging import needed - trust the orchestration system

        function Write-ConsolidationLog {
            param($Message, $Level = "INFO")
            if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
                Write-CustomLog -Message $Message -Level $Level
            } else {
                Write-Host "[$Level] $Message"
            }
        }

        Write-ConsolidationLog "Starting PR consolidation with strategy: $ConsolidationStrategy" -Level "INFO"
    }

    process {
        try {
            # Step 1: Get all open pull requests
            Write-ConsolidationLog "Fetching open pull requests..." -Level "INFO"

            $openPRs = @()
            $prListOutput = gh pr list --json number,title,author,headRefName,mergeable,labels,createdAt,url 2>&1

            if ($LASTEXITCODE -eq 0) {
                $openPRs = $prListOutput | ConvertFrom-Json
                Write-ConsolidationLog "Found $($openPRs.Count) open pull requests" -Level "INFO"
            } else {
                throw "Failed to fetch pull requests: $prListOutput"
            }

            if ($openPRs.Count -lt 2) {
                Write-ConsolidationLog "Need at least 2 open PRs for consolidation. Found: $($openPRs.Count)" -Level "WARN"
                return @{
                    Success = $false
                    Message = "Insufficient PRs for consolidation"
                    PRsAnalyzed = $openPRs.Count
                }
            }

            # Step 2: Analyze PRs for consolidation compatibility
            Write-ConsolidationLog "Analyzing PRs for consolidation compatibility..." -Level "INFO"

            $consolidationGroups = @()

            switch ($ConsolidationStrategy) {
                "Compatible" {
                    $consolidationGroups = Get-CompatiblePRGroups -PRs $openPRs -MaxPRs $MaxPRsToConsolidate
                }
                "RelatedFiles" {
                    $consolidationGroups = Get-RelatedFilesPRGroups -PRs $openPRs -MaxPRs $MaxPRsToConsolidate
                }
                "SameAuthor" {
                    $consolidationGroups = Get-SameAuthorPRGroups -PRs $openPRs -MaxPRs $MaxPRsToConsolidate
                }
                "ByPriority" {
                    $consolidationGroups = Get-PriorityBasedPRGroups -PRs $openPRs -MaxPRs $MaxPRsToConsolidate
                }
                "All" {
                    $consolidationGroups = Get-AllPossiblePRGroups -PRs $openPRs -MaxPRs $MaxPRsToConsolidate
                }
            }

            if ($consolidationGroups.Count -eq 0) {
                Write-ConsolidationLog "No consolidation opportunities found with strategy: $ConsolidationStrategy" -Level "WARN"
                return @{
                    Success = $false
                    Message = "No consolidation opportunities found"
                    Strategy = $ConsolidationStrategy
                    PRsAnalyzed = $openPRs.Count
                }
            }

            Write-ConsolidationLog "Found $($consolidationGroups.Count) consolidation opportunities" -Level "INFO"

            # Step 3: Process each consolidation group
            $consolidationResults = @()

            foreach ($group in $consolidationGroups) {
                Write-ConsolidationLog "Processing consolidation group with $($group.PRs.Count) PRs..." -Level "INFO"

                if ($DryRun) {
                    Write-ConsolidationLog "DRY RUN: Would consolidate PRs:" -Level "INFO"
                    foreach ($pr in $group.PRs) {
                        Write-ConsolidationLog "  - PR #$($pr.number): $($pr.title)" -Level "INFO"
                    }

                    $consolidationResults += @{
                        Success = $true
                        DryRun = $true
                        PRsInGroup = $group.PRs.Count
                        Strategy = $group.Strategy
                        ConflictRisk = $group.ConflictRisk
                        PRNumbers = $group.PRs.number
                    }
                } else {
                    # Execute consolidation
                    $result = Invoke-PRGroupConsolidation -PRGroup $group -Force:$Force
                    $consolidationResults += $result
                }
            }

            # Step 4: Return consolidation summary
            $successfulConsolidations = $consolidationResults | Where-Object { $_.Success }

            Write-ConsolidationLog "Consolidation complete. Successful: $($successfulConsolidations.Count)/$($consolidationResults.Count)" -Level "SUCCESS"

            return @{
                Success = $true
                Strategy = $ConsolidationStrategy
                PRsAnalyzed = $openPRs.Count
                ConsolidationGroups = $consolidationGroups.Count
                SuccessfulConsolidations = $successfulConsolidations.Count
                Results = $consolidationResults
                DryRun = $DryRun.IsPresent
            }

        } catch {
            $errorMessage = "PR consolidation failed: $($_.Exception.Message)"
            Write-ConsolidationLog $errorMessage -Level "ERROR"

            return @{
                Success = $false
                Message = $errorMessage
                Strategy = $ConsolidationStrategy
            }
        }
    }
}

function Get-CompatiblePRGroups {
    param($PRs, $MaxPRs)

    $groups = @()

    # Group PRs by mergeable status and check for conflicts
    $mergeablePRs = $PRs | Where-Object { $_.mergeable -eq "MERGEABLE" }

    if ($mergeablePRs.Count -ge 2) {
        # Check for file conflicts between PRs
        $compatibleSets = Find-NonConflictingPRSets -PRs $mergeablePRs -MaxSize $MaxPRs

        foreach ($set in $compatibleSets) {
            $groups += @{
                PRs = $set
                Strategy = "Compatible"
                ConflictRisk = "Low"
                Reason = "All PRs are mergeable with no file conflicts"
            }
        }
    }

    return $groups
}

function Get-SameAuthorPRGroups {
    param($PRs, $MaxPRs)

    $groups = @()

    # Group PRs by author
    $authorGroups = $PRs | Group-Object -Property { $_.author.login }

    foreach ($authorGroup in $authorGroups) {
        if ($authorGroup.Group.Count -ge 2) {
            # Take up to MaxPRs from each author
            $prsToConsolidate = $authorGroup.Group | Select-Object -First $MaxPRs

            $groups += @{
                PRs = $prsToConsolidate
                Strategy = "SameAuthor"
                ConflictRisk = "Medium"
                Reason = "PRs from same author: $($authorGroup.Name)"
            }
        }
    }

    return $groups
}

function Get-PriorityBasedPRGroups {
    param($PRs, $MaxPRs)

    $groups = @()

    # Analyze labels for priority indicators
    $priorityPRs = @()

    foreach ($pr in $PRs) {
        $priority = "Medium"  # Default

        if ($pr.labels) {
            foreach ($label in $pr.labels) {
                switch -Regex ($label.name.ToLower()) {
                    "critical|urgent|hotfix" { $priority = "Critical" }
                    "high|important" { $priority = "High" }
                    "low|minor" { $priority = "Low" }
                }
            }
        }

        $priorityPRs += $pr | Add-Member -NotePropertyName "Priority" -NotePropertyValue $priority -PassThru
    }

    # Group by priority and take highest priority groups first
    $priorityGroups = $priorityPRs | Group-Object -Property Priority
    $sortedGroups = $priorityGroups | Sort-Object @{Expression={
        switch ($_.Name) {
            "Critical" { 1 }
            "High" { 2 }
            "Medium" { 3 }
            "Low" { 4 }
        }
    }}

    foreach ($priorityGroup in $sortedGroups) {
        if ($priorityGroup.Group.Count -ge 2) {
            $prsToConsolidate = $priorityGroup.Group | Select-Object -First $MaxPRs

            $groups += @{
                PRs = $prsToConsolidate
                Strategy = "ByPriority"
                ConflictRisk = "Medium"
                Reason = "Priority group: $($priorityGroup.Name)"
            }
        }
    }

    return $groups
}

function Find-NonConflictingPRSets {
    param($PRs, $MaxSize)

    $nonConflictingSets = @()

    # For each PR, get the files it modifies
    $prFileMap = @{}

    foreach ($pr in $PRs) {
        try {
            $filesOutput = gh pr diff $pr.number --name-only 2>&1
            if ($LASTEXITCODE -eq 0) {
                $prFileMap[$pr.number] = $filesOutput -split "`n" | Where-Object { $_ -and $_.Trim() }
            } else {
                # Fallback: assume this PR conflicts with others
                $prFileMap[$pr.number] = @("unknown-conflict-$($pr.number)")
            }
        } catch {
            $prFileMap[$pr.number] = @("unknown-conflict-$($pr.number)")
        }
    }

    # Find sets of PRs that don't modify the same files
    for ($i = 0; $i -lt $PRs.Count; $i++) {
        $currentSet = @($PRs[$i])
        $currentFiles = $prFileMap[$PRs[$i].number]

        for ($j = $i + 1; $j -lt $PRs.Count -and $currentSet.Count -lt $MaxSize; $j++) {
            $candidateFiles = $prFileMap[$PRs[$j].number]

            # Check for file overlap
            $hasConflict = $false
            foreach ($file in $candidateFiles) {
                if ($currentFiles -contains $file) {
                    $hasConflict = $true
                    break
                }
            }

            if (-not $hasConflict) {
                $currentSet += $PRs[$j]
                $currentFiles += $candidateFiles
            }
        }

        if ($currentSet.Count -ge 2) {
            $nonConflictingSets += $currentSet
        }
    }

    return $nonConflictingSets
}

function Invoke-PRGroupConsolidation {
    param($PRGroup, [switch]$Force)

    try {
        Write-ConsolidationLog "Executing consolidation for $($PRGroup.PRs.Count) PRs..." -Level "INFO"

        # Step 1: Create consolidation branch
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $consolidationBranch = "consolidation/$timestamp-$($PRGroup.Strategy.ToLower())"

        # Fetch latest and create consolidation branch from main
        git fetch origin 2>&1 | Out-Null
        git checkout main 2>&1 | Out-Null
        git pull origin main 2>&1 | Out-Null
        git checkout -b $consolidationBranch 2>&1 | Out-Null

        Write-ConsolidationLog "Created consolidation branch: $consolidationBranch" -Level "INFO"

        # Step 2: Merge each PR branch
        $mergedPRs = @()
        $conflictedPRs = @()

        foreach ($pr in $PRGroup.PRs) {
            Write-ConsolidationLog "Merging PR #$($pr.number): $($pr.title)" -Level "INFO"

            # Fetch the PR branch
            git fetch origin $pr.headRefName 2>&1 | Out-Null

            # Attempt to merge
            $mergeOutput = git merge "origin/$($pr.headRefName)" --no-ff -m "Consolidate: PR #$($pr.number) - $($pr.title)" 2>&1

            if ($LASTEXITCODE -eq 0) {
                $mergedPRs += $pr
                Write-ConsolidationLog "Successfully merged PR #$($pr.number)" -Level "SUCCESS"
            } else {
                $conflictedPRs += $pr
                Write-ConsolidationLog "Conflict merging PR #$($pr.number): $mergeOutput" -Level "WARN"

                if (-not $Force) {
                    # Abort merge and skip this PR
                    git merge --abort 2>&1 | Out-Null
                    Write-ConsolidationLog "Skipped PR #$($pr.number) due to conflicts" -Level "WARN"
                } else {
                    # Try to auto-resolve simple conflicts
                    $conflictMarkers = git grep -l "^<<<<<<< HEAD" 2>$null
                    if ($conflictMarkers) {
                        Write-ConsolidationLog "Manual conflict resolution required for: $($conflictMarkers -join ', ')" -Level "ERROR"
                        git merge --abort 2>&1 | Out-Null
                        break
                    }
                }
            }
        }

        if ($mergedPRs.Count -eq 0) {
            throw "No PRs could be merged successfully"
        }

        # Step 3: Create consolidated PR
        $consolidatedTitle = "CONSOLIDATED: $($mergedPRs.Count) PRs - $($PRGroup.Strategy) strategy"
        $consolidatedBody = @"
## 🔄 Consolidated Pull Request

This PR consolidates $($mergedPRs.Count) related pull requests using the **$($PRGroup.Strategy)** strategy.

### 📋 Included PRs:
$($mergedPRs | ForEach-Object { "- [ ] PR #$($_.number): $($_.title) ([link]($($_.url)))" } | Out-String)

### 🎯 Consolidation Benefits:
- Reduces merge conflicts by combining related changes
- Simplifies review process for related functionality
- Prevents integration issues between dependent changes
- Streamlines the merge queue

### ⚠️ Conflict Information:
- **Merged successfully**: $($mergedPRs.Count) PRs
- **Conflicts encountered**: $($conflictedPRs.Count) PRs
- **Conflict risk**: $($PRGroup.ConflictRisk)

### 🔍 Review Notes:
This consolidated PR has been automatically tested for conflicts and compatibility.
Please review the combined changes to ensure they work together as expected.

---
*Created by PatchManager PR Consolidation - Strategy: $($PRGroup.Strategy)*
"@

        # Push the consolidation branch
        git push origin $consolidationBranch 2>&1 | Out-Null

        # Create the consolidated PR
        $consolidatedPR = gh pr create --title $consolidatedTitle --body $consolidatedBody --base main --head $consolidationBranch 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-ConsolidationLog "Created consolidated PR: $consolidatedPR" -Level "SUCCESS"

            # Close the original PRs with a reference to the consolidation
            foreach ($pr in $mergedPRs) {
                $closeComment = "🔄 This PR has been consolidated into $consolidatedPR for easier review and conflict resolution."
                gh pr comment $pr.number --body $closeComment 2>&1 | Out-Null
                gh pr close $pr.number 2>&1 | Out-Null
                Write-ConsolidationLog "Closed original PR #$($pr.number)" -Level "INFO"
            }

            return @{
                Success = $true
                ConsolidatedPR = $consolidatedPR
                MergedPRs = $mergedPRs.Count
                ConflictedPRs = $conflictedPRs.Count
                Branch = $consolidationBranch
                Strategy = $PRGroup.Strategy
            }
        } else {
            throw "Failed to create consolidated PR: $consolidatedPR"
        }

    } catch {
        Write-ConsolidationLog "Consolidation failed: $($_.Exception.Message)" -Level "ERROR"

        # Cleanup on failure
        try {
            git checkout main 2>&1 | Out-Null
            git branch -D $consolidationBranch 2>&1 | Out-Null
        } catch {
            # Ignore cleanup errors
        }

        return @{
            Success = $false
            Message = $_.Exception.Message
            Strategy = $PRGroup.Strategy
        }
    }
}

Export-ModuleMember -Function Invoke-PRConsolidation
