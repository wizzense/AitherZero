#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive PR status monitoring hook for AitherZero
    
.DESCRIPTION
    Provides detailed PR status information including:
    - PR state and review status
    - CI check results with failure analysis
    - Test failures and error details
    - Security scan results
    - Time to merge estimates
    - Actionable recommendations
    
.PARAMETER PRNumber
    The PR number to check status for. If not specified, detects from current branch.
    
.PARAMETER ShowDetails
    Show detailed information including test failures and check logs
    
.PARAMETER OutputFormat
    Output format: Console (default), JSON, Markdown
    
.EXAMPLE
    ./hooks/Get-PRStatus.ps1
    
.EXAMPLE
    ./hooks/Get-PRStatus.ps1 -PRNumber 557 -ShowDetails
    
.EXAMPLE
    ./hooks/Get-PRStatus.ps1 -OutputFormat JSON > pr-status.json
#>

[CmdletBinding()]
param(
    [int]$PRNumber,
    [switch]$ShowDetails,
    [ValidateSet('Console', 'JSON', 'Markdown')]
    [string]$OutputFormat = 'Console'
)

# Import required modules
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Find project root
$scriptPath = $PSScriptRoot
$projectRoot = Split-Path $scriptPath -Parent
. "$projectRoot/aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Import logging
Import-Module "$projectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue

function Get-CurrentPRNumber {
    <#
    .SYNOPSIS
        Detects PR number from current branch
    #>
    try {
        # Check if we're on a PR branch
        $currentBranch = git branch --show-current
        
        # Try to get PR from gh
        $prList = gh pr list --head "$currentBranch" --json number,state --jq '.[0]' 2>$null | ConvertFrom-Json
        if ($prList -and $prList.number) {
            return $prList.number
        }
        
        # Try to extract from branch name (patch/YYYYMMDD-HHMMSS-description)
        if ($currentBranch -match 'patch/\d{8}-\d{6}') {
            # Search for PR with this branch
            $searchResult = gh pr list --search "head:$currentBranch" --json number --jq '.[0].number' 2>$null
            if ($searchResult) {
                return [int]$searchResult
            }
        }
        
        throw "Could not detect PR number from current branch: $currentBranch"
    }
    catch {
        throw "Failed to detect current PR number: $_"
    }
}

function Get-PRDetails {
    <#
    .SYNOPSIS
        Gets comprehensive PR details from GitHub
    #>
    param([int]$Number)
    
    Write-Information "Fetching PR #$Number details..." -InformationAction Continue
    
    $pr = gh pr view $Number --json state,title,author,createdAt,updatedAt,mergeable,mergeStateStatus,reviews,statusCheckRollup,labels,milestone,assignees,comments,reactionGroups,isDraft,headRefName,baseRefName,additions,deletions,changedFiles
    return $pr | ConvertFrom-Json
}

function Get-CheckStatus {
    <#
    .SYNOPSIS
        Analyzes CI check status
    #>
    param($StatusCheckRollup)
    
    $summary = @{
        Total = 0
        Success = 0
        Failure = 0
        Pending = 0
        Skipped = 0
        FailedChecks = @()
        Categories = @{
            Quality = @()
            Tests = @()
            Security = @()
            Build = @()
            Other = @()
        }
    }
    
    foreach ($check in $StatusCheckRollup) {
        $summary.Total++
        
        $checkInfo = @{
            Name = $check.name
            Status = $check.status
            Conclusion = $check.conclusion
            Workflow = $check.workflowName
            StartedAt = $check.startedAt
            CompletedAt = $check.completedAt
            Url = $check.detailsUrl
        }
        
        # Categorize check
        switch -Regex ($check.name) {
            'Quality|Analyze' { $summary.Categories.Quality += $checkInfo }
            'Test' { $summary.Categories.Tests += $checkInfo }
            'Security|Scan|CodeQL' { $summary.Categories.Security += $checkInfo }
            'Build' { $summary.Categories.Build += $checkInfo }
            default { $summary.Categories.Other += $checkInfo }
        }
        
        # Count by status
        switch ($check.conclusion) {
            'SUCCESS' { $summary.Success++ }
            'FAILURE' { 
                $summary.Failure++
                $summary.FailedChecks += $checkInfo
            }
            'SKIPPED' { $summary.Skipped++ }
            $null { 
                if ($check.status -eq 'IN_PROGRESS' -or $check.status -eq 'QUEUED') {
                    $summary.Pending++
                }
            }
        }
    }
    
    return $summary
}

function Get-TestFailureDetails {
    <#
    .SYNOPSIS
        Gets detailed test failure information
    #>
    param([int]$PRNumber)
    
    Write-Information "Analyzing test failures..." -InformationAction Continue
    
    # Get latest CI run
    $runs = gh run list --workflow=ci.yml --branch "$(gh pr view $PRNumber --json headRefName --jq '.headRefName')" --limit 1 --json databaseId,status,conclusion
    $latestRun = ($runs | ConvertFrom-Json)[0]
    
    if (-not $latestRun) {
        return @{ Message = "No CI runs found" }
    }
    
    $failures = @{
        RunId = $latestRun.databaseId
        TestFailures = @()
        QualityIssues = @()
        BuildErrors = @()
    }
    
    # Get failed job logs
    $failedJobs = gh run view $latestRun.databaseId --json jobs --jq '.jobs[] | select(.conclusion == "failure")'
    
    foreach ($job in ($failedJobs | ConvertFrom-Json)) {
        $logContent = gh run view $latestRun.databaseId --job $job.databaseId --log 2>$null
        
        # Extract test failures
        if ($job.name -match 'Test') {
            $testErrors = $logContent | Select-String -Pattern '(FAILED|Failed:|Error:)' -Context 2,2
            $failures.TestFailures += @{
                Platform = $job.name
                Errors = $testErrors | ForEach-Object { $_.Line }
            }
        }
        
        # Extract quality issues
        if ($job.name -match 'Quality') {
            $qualityErrors = $logContent | Select-String -Pattern '::error file=' 
            $errorCount = ($logContent | Select-String -Pattern 'Too many errors \((\d+)\)').Matches.Groups[1].Value
            $failures.QualityIssues = @{
                ErrorCount = $errorCount
                Threshold = 10
                Issues = $qualityErrors | ForEach-Object { $_.Line }
            }
        }
    }
    
    return $failures
}

function Get-Recommendations {
    <#
    .SYNOPSIS
        Generates actionable recommendations based on PR status
    #>
    param($PRDetails, $CheckSummary, $TestDetails)
    
    $recommendations = @()
    
    # Check failures
    if ($CheckSummary.Failure -gt 0) {
        if ($CheckSummary.Categories.Quality.Count -gt 0) {
            $recommendations += "🔧 Fix PSScriptAnalyzer errors to pass quality checks"
        }
        if ($CheckSummary.Categories.Tests.Count -gt 0) {
            $recommendations += "🧪 Fix failing tests on affected platforms"
        }
        if ($CheckSummary.Categories.Security.Count -gt 0) {
            $recommendations += "🔒 Address security scan findings"
        }
    }
    
    # PR state checks
    if ($PRDetails.isDraft) {
        $recommendations += "📝 Mark PR as ready for review when complete"
    }
    
    if ($PRDetails.reviews.Count -eq 0 -and -not $PRDetails.isDraft) {
        $recommendations += "👀 Request code review from maintainers"
    }
    
    # Merge readiness
    if ($PRDetails.mergeable -eq $false) {
        $recommendations += "🔄 Resolve merge conflicts with base branch"
    }
    
    if ($CheckSummary.Pending -gt 0) {
        $recommendations += "⏳ Wait for ${CheckSummary.Pending} pending checks to complete"
    }
    
    # Quality specific
    if ($TestDetails.QualityIssues.ErrorCount -gt $TestDetails.QualityIssues.Threshold) {
        $overThreshold = $TestDetails.QualityIssues.ErrorCount - $TestDetails.QualityIssues.Threshold
        $recommendations += "📉 Reduce PSScriptAnalyzer errors by $overThreshold to meet threshold"
    }
    
    return $recommendations
}

function Format-Console {
    <#
    .SYNOPSIS
        Formats output for console display
    #>
    param($PRDetails, $CheckSummary, $TestDetails, $Recommendations)
    
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    PR #$($PRDetails.number) Status Report                    " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Basic Info
    Write-Host "`n📋 BASIC INFORMATION" -ForegroundColor Yellow
    Write-Host "   Title: $($PRDetails.title)"
    Write-Host "   Author: $($PRDetails.author.login)"
    Write-Host "   Branch: $($PRDetails.headRefName) → $($PRDetails.baseRefName)"
    Write-Host "   State: " -NoNewline
    
    $stateColor = switch ($PRDetails.state) {
        'OPEN' { 'Green' }
        'CLOSED' { 'Red' }
        'MERGED' { 'Blue' }
    }
    Write-Host $PRDetails.state -ForegroundColor $stateColor
    
    if ($PRDetails.isDraft) {
        Write-Host "   Status: DRAFT" -ForegroundColor DarkGray
    }
    
    Write-Host "   Changes: +$($PRDetails.additions) -$($PRDetails.deletions) in $($PRDetails.changedFiles) files"
    Write-Host "   Created: $($PRDetails.createdAt)"
    Write-Host "   Updated: $($PRDetails.updatedAt)"
    
    # CI Status
    Write-Host "`n🔄 CI/CD STATUS" -ForegroundColor Yellow
    Write-Host "   Total Checks: $($CheckSummary.Total)"
    Write-Host "   ✅ Passed: $($CheckSummary.Success)" -ForegroundColor Green
    Write-Host "   ❌ Failed: $($CheckSummary.Failure)" -ForegroundColor Red
    Write-Host "   ⏭️  Skipped: $($CheckSummary.Skipped)" -ForegroundColor DarkGray
    Write-Host "   ⏳ Pending: $($CheckSummary.Pending)" -ForegroundColor Yellow
    
    if ($CheckSummary.FailedChecks.Count -gt 0) {
        Write-Host "`n   Failed Checks:" -ForegroundColor Red
        foreach ($check in $CheckSummary.FailedChecks) {
            Write-Host "   - $($check.Name) ($($check.Workflow))" -ForegroundColor Red
        }
    }
    
    # Quality Issues
    if ($TestDetails.QualityIssues.ErrorCount) {
        Write-Host "`n📊 CODE QUALITY" -ForegroundColor Yellow
        Write-Host "   PSScriptAnalyzer Errors: $($TestDetails.QualityIssues.ErrorCount)/$($TestDetails.QualityIssues.Threshold)" -ForegroundColor $(if ($TestDetails.QualityIssues.ErrorCount -gt $TestDetails.QualityIssues.Threshold) { 'Red' } else { 'Green' })
    }
    
    # Reviews
    Write-Host "`n👥 REVIEWS" -ForegroundColor Yellow
    if ($PRDetails.reviews.Count -eq 0) {
        Write-Host "   No reviews yet" -ForegroundColor DarkGray
    } else {
        foreach ($review in $PRDetails.reviews) {
            $icon = switch ($review.state) {
                'APPROVED' { '✅' }
                'CHANGES_REQUESTED' { '🔄' }
                'COMMENTED' { '💬' }
                default { '👀' }
            }
            Write-Host "   $icon $($review.author.login): $($review.state)"
        }
    }
    
    # Merge Status
    Write-Host "`n🚀 MERGE READINESS" -ForegroundColor Yellow
    Write-Host "   Mergeable: " -NoNewline
    if ($PRDetails.mergeable -eq $true) {
        Write-Host "YES" -ForegroundColor Green
    } elseif ($PRDetails.mergeable -eq $false) {
        Write-Host "NO (conflicts)" -ForegroundColor Red
    } else {
        Write-Host "CHECKING..." -ForegroundColor Yellow
    }
    Write-Host "   Merge State: $($PRDetails.mergeStateStatus)"
    
    # Recommendations
    if ($Recommendations.Count -gt 0) {
        Write-Host "`n💡 RECOMMENDATIONS" -ForegroundColor Yellow
        foreach ($rec in $Recommendations) {
            Write-Host "   $rec"
        }
    }
    
    # Time Estimate
    Write-Host "`n⏱️  ESTIMATED TIME TO MERGE" -ForegroundColor Yellow
    if ($CheckSummary.Failure -gt 0) {
        Write-Host "   Fix required issues first (est. 30-60 minutes)" -ForegroundColor Red
    } elseif ($CheckSummary.Pending -gt 0) {
        Write-Host "   Waiting for checks (est. 5-10 minutes)" -ForegroundColor Yellow
    } elseif ($PRDetails.reviews.Count -eq 0) {
        Write-Host "   Awaiting review (est. 1-24 hours)" -ForegroundColor Yellow
    } else {
        Write-Host "   Ready to merge! 🎉" -ForegroundColor Green
    }
    
    Write-Host "`n═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Format-JSON {
    <#
    .SYNOPSIS
        Formats output as JSON
    #>
    param($PRDetails, $CheckSummary, $TestDetails, $Recommendations)
    
    @{
        prNumber = $PRNumber
        timestamp = Get-Date -Format 'o'
        pr = $PRDetails
        checks = $CheckSummary
        testDetails = $TestDetails
        recommendations = $Recommendations
        summary = @{
            isReady = ($CheckSummary.Failure -eq 0 -and $CheckSummary.Pending -eq 0 -and $PRDetails.mergeable -eq $true)
            blockers = @(
                if ($CheckSummary.Failure -gt 0) { "CI checks failing" }
                if ($CheckSummary.Pending -gt 0) { "Checks pending" }
                if ($PRDetails.mergeable -eq $false) { "Merge conflicts" }
                if ($PRDetails.isDraft) { "PR is draft" }
            )
        }
    } | ConvertTo-Json -Depth 10
}

function Format-Markdown {
    <#
    .SYNOPSIS
        Formats output as Markdown
    #>
    param($PRDetails, $CheckSummary, $TestDetails, $Recommendations)
    
    $md = @"
# PR #$($PRDetails.number) Status Report

## 📋 Basic Information
- **Title:** $($PRDetails.title)
- **Author:** $($PRDetails.author.login)
- **Branch:** $($PRDetails.headRefName) → $($PRDetails.baseRefName)
- **State:** $($PRDetails.state)$(if ($PRDetails.isDraft) { ' (DRAFT)' })
- **Changes:** +$($PRDetails.additions) -$($PRDetails.deletions) in $($PRDetails.changedFiles) files

## 🔄 CI/CD Status
| Status | Count |
|--------|-------|
| ✅ Passed | $($CheckSummary.Success) |
| ❌ Failed | $($CheckSummary.Failure) |
| ⏭️ Skipped | $($CheckSummary.Skipped) |
| ⏳ Pending | $($CheckSummary.Pending) |
| **Total** | **$($CheckSummary.Total)** |

"@

    if ($CheckSummary.FailedChecks.Count -gt 0) {
        $md += @"
### Failed Checks
$($CheckSummary.FailedChecks | ForEach-Object { "- $($_.Name) ($($_.Workflow))" } | Out-String)

"@
    }
    
    if ($Recommendations.Count -gt 0) {
        $md += @"
## 💡 Recommendations
$($Recommendations | ForEach-Object { "- $_" } | Out-String)

"@
    }
    
    $md
}

# Main execution
try {
    # Get PR number
    if (-not $PRNumber) {
        $PRNumber = Get-CurrentPRNumber
    }
    
    # Fetch all data
    $prDetails = Get-PRDetails -Number $PRNumber
    $checkSummary = Get-CheckStatus -StatusCheckRollup $prDetails.statusCheckRollup
    
    $testDetails = @{}
    if ($ShowDetails -and $checkSummary.Failure -gt 0) {
        $testDetails = Get-TestFailureDetails -PRNumber $PRNumber
    }
    
    $recommendations = Get-Recommendations -PRDetails $prDetails -CheckSummary $checkSummary -TestDetails $testDetails
    
    # Format output
    switch ($OutputFormat) {
        'Console' {
            Format-Console -PRDetails $prDetails -CheckSummary $checkSummary -TestDetails $testDetails -Recommendations $recommendations
        }
        'JSON' {
            Format-JSON -PRDetails $prDetails -CheckSummary $checkSummary -TestDetails $testDetails -Recommendations $recommendations
        }
        'Markdown' {
            Format-Markdown -PRDetails $prDetails -CheckSummary $checkSummary -TestDetails $testDetails -Recommendations $recommendations
        }
    }
}
catch {
    Write-Error "Failed to get PR status: $_"
    exit 1
}