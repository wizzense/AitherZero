# Flag-DocumentationReviews.ps1 - Documentation Review Flagging System
# Part of AitherZero Smart Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/documentation-state.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateIssues,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory = $false)]
    [string]$Repository = $env:GITHUB_REPOSITORY,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "review-flags.json"
)

# Find project root if not specified
if (-not (Test-Path $ProjectRoot)) {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
}

# Import required modules
if (Test-Path "$ProjectRoot/aither-core/modules/Logging") {
    Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARN"){"Yellow"} else{"Green"})
    }
}

function Get-DocumentationReviewFlags {
    <#
    .SYNOPSIS
    Analyzes documentation state and generates review flags
    
    .DESCRIPTION
    Examines the current documentation state to identify directories that
    require human review based on various criteria and thresholds
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )
    
    $reviewFlags = @{
        flagTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        totalDirectories = $State.directories.Count
        flaggedCount = 0
        categories = @{
            missing = @()
            stale = @()
            outdated = @()
            significant_changes = @()
            new_directories = @()
        }
        priorities = @{
            high = @()
            medium = @()
            low = @()
        }
        summary = @{}
    }
    
    $config = $State.configuration
    $currentTime = Get-Date
    
    Write-Log "Analyzing $($State.directories.Count) directories for review flags..." -Level "INFO"
    
    foreach ($dirPath in $State.directories.Keys) {
        $dirState = $State.directories[$dirPath]
        $shouldFlag = $false
        $flagReasons = @()
        $flagCategory = ""
        $priority = "low"
        
        # Check for missing README
        if (-not $dirState.readmeExists) {
            $shouldFlag = $true
            $flagReasons += "README file is missing"
            $flagCategory = "missing"
            $priority = "high"
            $reviewFlags.categories.missing += $dirPath
        }
        
        # Check for stale documentation
        if ($dirState.readmeExists -and $dirState.readmeLastModified) {
            try {
                $readmeDate = [DateTime]::Parse($dirState.readmeLastModified)
                $daysSinceUpdate = ($currentTime - $readmeDate).Days
                
                if ($daysSinceUpdate -gt $config.changeThresholds.staleDays) {
                    $shouldFlag = $true
                    $flagReasons += "README is stale ($daysSinceUpdate days old, threshold: $($config.changeThresholds.staleDays))"
                    $flagCategory = "stale"
                    $priority = if ($daysSinceUpdate -gt ($config.changeThresholds.staleDays * 2)) { "high" } else { "medium" }
                    $reviewFlags.categories.stale += $dirPath
                }
                
                # Check for code changes since README update
                if ($dirState.mostRecentFileChange) {
                    try {
                        $lastChangeDate = [DateTime]::Parse($dirState.mostRecentFileChange)
                        $changesSinceReadme = $lastChangeDate -gt $readmeDate
                        $daysSinceChange = ($readmeDate - $lastChangeDate).Days
                        
                        if ($changesSinceReadme -and $daysSinceChange -gt $config.changeThresholds.codeChangeReviewDays) {
                            $shouldFlag = $true
                            $flagReasons += "Code changes detected since README last updated"
                            if ($flagCategory -eq "") { $flagCategory = "outdated" }
                            $priority = if ($priority -eq "low") { "medium" } else { $priority }
                            $reviewFlags.categories.outdated += $dirPath
                        }
                    } catch {
                        Write-Log "Could not parse file change date for $dirPath : $_" -Level "WARN"
                    }
                }
            } catch {
                Write-Log "Could not parse README date for $dirPath : $_" -Level "WARN"
            }
        }
        
        # Check for significant content changes
        if ($dirState.changesSinceLastReadme -and $dirState.contentDeltaPercent -gt $config.changeThresholds.characterDeltaPercent) {
            $shouldFlag = $true
            $flagReasons += "Significant content changes detected ($([Math]::Round($dirState.contentDeltaPercent, 1))% change)"
            if ($flagCategory -eq "") { $flagCategory = "significant_changes" }
            $priority = if ($dirState.contentDeltaPercent -gt 50) { "high" } elseif ($priority -eq "low") { "medium" } else { $priority }
            $reviewFlags.categories.significant_changes += $dirPath
        }
        
        # Check for new directories (recently added to tracking)
        if ($dirState.directoryType -ne "unknown" -and -not $dirState.readmeExists -and $dirState.fileCount -gt 0) {
            $isNewDirectory = $true  # Could be enhanced with git history analysis
            if ($isNewDirectory) {
                $reviewFlags.categories.new_directories += $dirPath
                if (-not $shouldFlag) {
                    $shouldFlag = $true
                    $flagReasons += "New directory without documentation"
                    $flagCategory = "missing"
                    $priority = "medium"
                }
            }
        }
        
        # Update directory state with flag information
        if ($shouldFlag) {
            $State.directories[$dirPath].flaggedForReview = $true
            $State.directories[$dirPath].reviewReasons = $flagReasons
            $State.directories[$dirPath].reviewPriority = $priority
            $State.directories[$dirPath].reviewCategory = $flagCategory
            $State.directories[$dirPath].flaggedDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
            
            $reviewFlags.flaggedCount++
            
            # Add to priority lists
            switch ($priority) {
                "high" { $reviewFlags.priorities.high += $dirPath }
                "medium" { $reviewFlags.priorities.medium += $dirPath }
                "low" { $reviewFlags.priorities.low += $dirPath }
            }
            
            Write-Log "Flagged $dirPath for review: $($flagReasons -join '; ') [Priority: $priority]" -Level "WARN"
        } else {
            $State.directories[$dirPath].flaggedForReview = $false
            $State.directories[$dirPath].reviewReasons = @()
        }
    }
    
    # Generate summary statistics
    $reviewFlags.summary = @{
        totalFlagged = $reviewFlags.flaggedCount
        coveragePercent = [Math]::Round((($State.directories.Count - $reviewFlags.categories.missing.Count) / $State.directories.Count) * 100, 1)
        categoryBreakdown = @{
            missing = $reviewFlags.categories.missing.Count
            stale = $reviewFlags.categories.stale.Count
            outdated = $reviewFlags.categories.outdated.Count
            significant_changes = $reviewFlags.categories.significant_changes.Count
            new_directories = $reviewFlags.categories.new_directories.Count
        }
        priorityBreakdown = @{
            high = $reviewFlags.priorities.high.Count
            medium = $reviewFlags.priorities.medium.Count
            low = $reviewFlags.priorities.low.Count
        }
    }
    
    Write-Log "Review flag analysis complete: $($reviewFlags.flaggedCount) directories flagged for review" -Level "SUCCESS"
    
    return $reviewFlags
}

function Format-ReviewIssueBody {
    <#
    .SYNOPSIS
    Formats a GitHub issue body for documentation review
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ReviewFlags,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )
    
    $body = @"
# 📝 Documentation Review Required

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
**Flagged Directories:** $($ReviewFlags.flaggedCount)
**Coverage:** $($ReviewFlags.summary.coveragePercent)%

## 📊 Summary

| Category | Count | Priority Distribution |
|----------|-------|---------------------|
| Missing READMEs | $($ReviewFlags.summary.categoryBreakdown.missing) | High priority |
| Stale Documentation | $($ReviewFlags.summary.categoryBreakdown.stale) | Medium/High priority |
| Outdated Content | $($ReviewFlags.summary.categoryBreakdown.outdated) | Medium priority |
| Significant Changes | $($ReviewFlags.summary.categoryBreakdown.significant_changes) | Medium/High priority |
| New Directories | $($ReviewFlags.summary.categoryBreakdown.new_directories) | Medium priority |

**Priority Breakdown:** $($ReviewFlags.summary.priorityBreakdown.high) high, $($ReviewFlags.summary.priorityBreakdown.medium) medium, $($ReviewFlags.summary.priorityBreakdown.low) low

"@

    # Add high priority items first
    if ($ReviewFlags.priorities.high.Count -gt 0) {
        $body += @"

## 🚨 High Priority Reviews

"@
        foreach ($dirPath in $ReviewFlags.priorities.high) {
            $dirState = $State.directories[$dirPath]
            $body += "### ``$dirPath``"
            $body += "`n- **Category:** $($dirState.reviewCategory)"
            $body += "`n- **Type:** $($dirState.directoryType)"
            $body += "`n- **Reasons:** $($dirState.reviewReasons -join ', ')"
            if ($dirState.contentDeltaPercent -gt 0) {
                $body += "`n- **Content Change:** $([Math]::Round($dirState.contentDeltaPercent, 1))%"
            }
            $body += "`n"
        }
    }

    # Add medium priority items
    if ($ReviewFlags.priorities.medium.Count -gt 0) {
        $body += @"

## ⚠️ Medium Priority Reviews

"@
        foreach ($dirPath in $ReviewFlags.priorities.medium) {
            $dirState = $State.directories[$dirPath]
            $body += "- **``$dirPath``** ($($dirState.directoryType)) - $($dirState.reviewReasons -join ', ')"
            $body += "`n"
        }
    }

    # Add low priority items (collapsed)
    if ($ReviewFlags.priorities.low.Count -gt 0) {
        $body += @"

<details>
<summary>📋 Low Priority Reviews ($($ReviewFlags.priorities.low.Count) items)</summary>

"@
        foreach ($dirPath in $ReviewFlags.priorities.low) {
            $dirState = $State.directories[$dirPath]
            $body += "- **``$dirPath``** - $($dirState.reviewReasons -join ', ')"
            $body += "`n"
        }
        $body += "`n</details>"
    }

    # Add action checklist
    $body += @"

## ✅ Review Checklist

### High Priority Actions
"@
    foreach ($dirPath in $ReviewFlags.priorities.high) {
        $body += "`n- [ ] Review and update ``$dirPath/README.md``"
    }

    if ($ReviewFlags.priorities.medium.Count -gt 0) {
        $body += "`n`n### Medium Priority Actions"
        foreach ($dirPath in ($ReviewFlags.priorities.medium | Select-Object -First 10)) {
            $body += "`n- [ ] Review ``$dirPath/README.md``"
        }
        if ($ReviewFlags.priorities.medium.Count -gt 10) {
            $body += "`n- [ ] Review remaining $($ReviewFlags.priorities.medium.Count - 10) medium priority directories"
        }
    }

    # Add configuration and automation info
    $body += @"

## ⚙️ Configuration

**Current Thresholds:**
- Stale documentation: $($State.configuration.changeThresholds.staleDays) days
- Content change trigger: $($State.configuration.changeThresholds.characterDeltaPercent)%
- Code change review: $($State.configuration.changeThresholds.codeChangeReviewDays) days

**Auto-Generation:** $($State.configuration.autoGeneration.enabled)

## 🤖 Automation Info

This issue was automatically created by the Smart Documentation Sync workflow.

- **State File:** ``$($StateFilePath)``
- **Last Analysis:** $($ReviewFlags.flagTime)
- **Total Directories Tracked:** $($ReviewFlags.totalDirectories)

When documentation is updated, this issue will be automatically updated or closed.

"@

    return $body
}

function Export-ReviewFlags {
    <#
    .SYNOPSIS
    Exports review flags to a structured file for external processing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ReviewFlags,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$State,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    $exportData = @{
        metadata = @{
            generatedAt = $ReviewFlags.flagTime
            totalDirectories = $ReviewFlags.totalDirectories
            flaggedCount = $ReviewFlags.flaggedCount
            coveragePercent = $ReviewFlags.summary.coveragePercent
        }
        configuration = $State.configuration
        summary = $ReviewFlags.summary
        categories = $ReviewFlags.categories
        priorities = $ReviewFlags.priorities
        detailedFlags = @{}
    }
    
    # Add detailed information for each flagged directory
    foreach ($dirPath in $State.directories.Keys) {
        $dirState = $State.directories[$dirPath]
        if ($dirState.flaggedForReview) {
            $exportData.detailedFlags[$dirPath] = @{
                directoryType = $dirState.directoryType
                reviewCategory = $dirState.reviewCategory
                reviewPriority = $dirState.reviewPriority
                reviewReasons = $dirState.reviewReasons
                readmeExists = $dirState.readmeExists
                readmeLastModified = $dirState.readmeLastModified
                contentDeltaPercent = $dirState.contentDeltaPercent
                fileCount = $dirState.fileCount
                totalCharCount = $dirState.totalCharCount
                flaggedDate = $dirState.flaggedDate
            }
        }
    }
    
    try {
        $exportData | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Log "Review flags exported to: $OutputPath" -Level "SUCCESS"
    } catch {
        Write-Log "Error exporting review flags: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Create-GitHubReviewIssue {
    <#
    .SYNOPSIS
    Creates or updates a GitHub issue for documentation review
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ReviewFlags,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$State,
        
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        
        [Parameter(Mandatory = $true)]
        [string]$GitHubToken,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    if ($ReviewFlags.flaggedCount -eq 0) {
        Write-Log "No directories flagged for review - no issue needed" -Level "INFO"
        return $null
    }
    
    $title = "📝 Documentation Review Required - $(Get-Date -Format 'yyyy-MM-dd')"
    $body = Format-ReviewIssueBody -ReviewFlags $ReviewFlags -State $State
    $labels = @("documentation", "review-needed", "auto-flagged")
    
    if ($DryRun) {
        Write-Log "DRY RUN: Would create/update GitHub issue with title: $title" -Level "INFO"
        Write-Log "Issue body length: $($body.Length) characters" -Level "INFO"
        Write-Log "Labels: $($labels -join ', ')" -Level "INFO"
        return @{
            title = $title
            body = $body
            labels = $labels
            action = "dry_run"
        }
    }
    
    try {
        # This would integrate with GitHub API
        # For now, we'll prepare the issue data structure
        $issueData = @{
            title = $title
            body = $body
            labels = $labels
            repository = $Repository
            flaggedCount = $ReviewFlags.flaggedCount
            priorities = $ReviewFlags.summary.priorityBreakdown
        }
        
        Write-Log "Prepared GitHub issue for documentation review: $($ReviewFlags.flaggedCount) directories flagged" -Level "SUCCESS"
        return $issueData
        
    } catch {
        Write-Log "Error preparing GitHub issue: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath
    
    # Load current state
    if (-not (Test-Path $stateFilePath)) {
        Write-Log "State file not found: $stateFilePath" -Level "ERROR"
        Write-Log "Run Track-DocumentationState.ps1 -Initialize first" -Level "ERROR"
        exit 1
    }
    
    $content = Get-Content -Path $stateFilePath -Raw -Encoding UTF8
    $state = $content | ConvertFrom-Json -AsHashtable
    
    Write-Log "Analyzing documentation state for review flags..." -Level "INFO"
    
    # Generate review flags
    $reviewFlags = Get-DocumentationReviewFlags -State $state
    
    # Export review flags
    $outputFilePath = Join-Path $ProjectRoot $OutputPath
    Export-ReviewFlags -ReviewFlags $reviewFlags -State $state -OutputPath $outputFilePath
    
    # Create GitHub issue if requested and directories are flagged
    $issueResult = $null
    if ($CreateIssues -and $reviewFlags.flaggedCount -gt 0) {
        if (-not $GitHubToken -or -not $Repository) {
            Write-Log "GitHub token or repository not provided - cannot create issues" -Level "WARN"
        } else {
            $issueResult = Create-GitHubReviewIssue -ReviewFlags $reviewFlags -State $state -Repository $Repository -GitHubToken $GitHubToken -DryRun:$DryRun
        }
    }
    
    # Save updated state
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFilePath -Encoding UTF8
    
    # Output summary
    Write-Host "`n📋 Documentation Review Flag Summary:" -ForegroundColor Cyan
    Write-Host "  Total Directories: $($reviewFlags.totalDirectories)" -ForegroundColor White
    Write-Host "  Flagged for Review: $($reviewFlags.flaggedCount)" -ForegroundColor $(if($reviewFlags.flaggedCount -gt 0){"Yellow"}else{"Green"})
    Write-Host "  Documentation Coverage: $($reviewFlags.summary.coveragePercent)%" -ForegroundColor $(if($reviewFlags.summary.coveragePercent -lt 80){"Red"}elseif($reviewFlags.summary.coveragePercent -lt 95){"Yellow"}else{"Green"})
    
    if ($reviewFlags.flaggedCount -gt 0) {
        Write-Host "`n🚨 Priority Breakdown:" -ForegroundColor Red
        Write-Host "  High Priority: $($reviewFlags.summary.priorityBreakdown.high)" -ForegroundColor Red
        Write-Host "  Medium Priority: $($reviewFlags.summary.priorityBreakdown.medium)" -ForegroundColor Yellow
        Write-Host "  Low Priority: $($reviewFlags.summary.priorityBreakdown.low)" -ForegroundColor Gray
        
        Write-Host "`n📂 Category Breakdown:" -ForegroundColor Yellow
        Write-Host "  Missing READMEs: $($reviewFlags.summary.categoryBreakdown.missing)" -ForegroundColor Red
        Write-Host "  Stale Documentation: $($reviewFlags.summary.categoryBreakdown.stale)" -ForegroundColor Yellow
        Write-Host "  Outdated Content: $($reviewFlags.summary.categoryBreakdown.outdated)" -ForegroundColor Orange
        Write-Host "  Significant Changes: $($reviewFlags.summary.categoryBreakdown.significant_changes)" -ForegroundColor Magenta
        Write-Host "  New Directories: $($reviewFlags.summary.categoryBreakdown.new_directories)" -ForegroundColor Blue
    }
    
    if ($issueResult) {
        Write-Host "`n🎫 GitHub Issue:" -ForegroundColor Green
        Write-Host "  Action: $($issueResult.action ?? 'prepared')" -ForegroundColor White
        Write-Host "  Flagged Count: $($issueResult.flaggedCount)" -ForegroundColor White
    }
    
    Write-Log "Documentation review flagging completed successfully" -Level "SUCCESS"
    
} catch {
    Write-Log "Documentation review flagging failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}