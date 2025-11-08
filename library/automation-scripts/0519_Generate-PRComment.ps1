#Requires -Version 7.0

<#
.SYNOPSIS
    Generate consolidated PR comment with all ecosystem information
.DESCRIPTION
    Creates a comprehensive, single PR comment with build info, test results,
    quality metrics, and actionable recommendations
.PARAMETER BuildMetadataPath
    Path to build-metadata.json
.PARAMETER AnalysisSummaryPath
    Path to analysis-summary.json
.PARAMETER DashboardPath
    Path to generated dashboard.html
.PARAMETER ChangelogPath
    Path to PR changelog
.PARAMETER RecommendationsPath
    Path to recommendations.json
.PARAMETER OutputPath
    Path for generated pr-comment.md
.PARAMETER IncludeDeploymentInstructions
    Include Docker deployment commands
.PARAMETER IncludeQuickActions
    Include quick action buttons/links
.EXAMPLE
    ./0519_Generate-PRComment.ps1 -IncludeDeploymentInstructions -IncludeQuickActions
.NOTES
    Stage: Reporting
    Category: GitHub
    Order: 0519
    Tags: pr, comment, github, ecosystem
#>

[CmdletBinding()]
param(
    [string]$BuildMetadataPath = "library/reports/build-metadata.json",
    [string]$AnalysisSummaryPath = "library/reports/analysis-summary.json",
    [string]$DashboardPath = "library/reports/dashboard.html",
    [string]$ChangelogPath = "library/reports/CHANGELOG-PR*.md",
    [string]$RecommendationsPath = "library/reports/recommendations.json",
    [string]$OutputPath = "library/reports/pr-comment.md",
    [switch]$IncludeDeploymentInstructions,
    [switch]$IncludeQuickActions
)

$ErrorActionPreference = 'Stop'

Write-Host "💬 Generating PR comment" -ForegroundColor Cyan

# Load data
$buildInfo = if (Test-Path $BuildMetadataPath) {
    Get-Content $BuildMetadataPath -Raw | ConvertFrom-Json
} else { $null }

$analysis = if (Test-Path $AnalysisSummaryPath) {
    Get-Content $AnalysisSummaryPath -Raw | ConvertFrom-Json
} else { $null }

$recommendations = if (Test-Path $RecommendationsPath) {
    Get-Content $RecommendationsPath -Raw | ConvertFrom-Json
} else { $null }

# Start building comment
$comment = @"
## 🚀 PR Ecosystem Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')  
**PR**: #$($buildInfo.pr.number) - $($buildInfo.pr.title)  
**Commit**: [$($buildInfo.git.commit_short)]($($buildInfo.git.url))

---

"@

# Status Overview
if ($analysis) {
    $statusIcon = switch ($analysis.status) {
        'pass' { '✅' }
        'fail' { '❌' }
        'warning' { '⚠️' }
        default { '❓' }
    }
    
    $comment += @"
### $statusIcon Overall Status: $($analysis.status.ToUpper())

"@
}

# Quick Stats
$comment += @"
### 📊 Quick Stats

| Metric | Value |
|--------|-------|
| 🧪 Tests | $($analysis.tests.passed)/$($analysis.tests.total) passed |
| 📝 Quality | $($analysis.quality.score)/100 |
| 📦 Files Changed | $($analysis.diff.summary.files_changed) |
| ➕ Additions | +$($analysis.diff.summary.additions) |
| ➖ Deletions | -$($analysis.diff.summary.deletions) |

---

"@

# Container Deployment
if ($IncludeDeploymentInstructions) {
    $containerImage = "$($buildInfo.artifacts.container_image_base):pr-$($buildInfo.pr.number)-latest"
    $dynamicPort = 8080 + ($buildInfo.pr.number % 100)
    
    $comment += @"
### 🐳 Docker Container

**Image**: ``$containerImage``  
**Port**: $dynamicPort (formula: 8080 + PR# % 100)

``````bash
# Pull the latest PR container
docker pull $containerImage

# Run interactively
docker run -it --rm \
  -p ${dynamicPort}:8080 \
  -e PR_NUMBER=$($buildInfo.pr.number) \
  $containerImage

# Run in background
docker run -d \
  --name aitherzero-pr-$($buildInfo.pr.number) \
  -p ${dynamicPort}:8080 \
  $containerImage
``````

---

"@
}

# Dashboard and Reports
$comment += @"
### 📊 Dashboard & Reports

- **[📊 Full Dashboard]($($buildInfo.pages.pr_dashboard))** - Comprehensive metrics and analysis
- **[📈 Test Results]($($buildInfo.pages.pr_reports)tests.html)** - Detailed test execution data
- **[📋 Coverage Report]($($buildInfo.pages.pr_reports)coverage/)** - Code coverage visualization
- **[📝 Changelog]($($buildInfo.pages.pr_reports)CHANGELOG-PR$($buildInfo.pr.number).md)** - Commit history with categorization

---

"@

# Recommendations
if ($recommendations -and $recommendations.items.Count -gt 0) {
    $comment += @"
### 💡 Actionable Recommendations

"@
    
    foreach ($rec in $recommendations.items | Select-Object -First 5) {
        $icon = switch ($rec.priority) {
            'critical' { '🔴' }
            'high' { '🟠' }
            'medium' { '🟡' }
            'low' { '🟢' }
            default { '⚪' }
        }
        
        $comment += @"

#### $icon **$($rec.title)** ($($rec.priority))
$($rec.description)

**Actions**:
"@
        
        foreach ($action in $rec.actions) {
            $comment += "`n- $action"
        }
        
        $comment += "`n"
    }
    
    if ($recommendations.items.Count -gt 5) {
        $comment += "`n*See [full dashboard]($($buildInfo.pages.pr_dashboard)) for all $($recommendations.items.Count) recommendations*`n"
    }
    
    $comment += "`n---`n"
}

# Quick Actions
if ($IncludeQuickActions) {
    $comment += @"
### ⚡ Quick Actions

- 🔍 [View Full Dashboard]($($buildInfo.pages.pr_dashboard))
- 🐳 [Container Registry](https://github.com/$($env:GITHUB_REPOSITORY)/pkgs/container/aitherzero)
- 📦 [Download Artifacts](https://github.com/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID))
- 🔄 [Workflow Run](https://github.com/$($env:GITHUB_REPOSITORY)/actions/runs/$($env:GITHUB_RUN_ID))
- 📚 [Documentation](https://github.com/$($env:GITHUB_REPOSITORY)#readme)

---

"@
}

# Footer
$comment += @"
*🤖 Automated by [AitherZero PR Ecosystem](https://github.com/$($env:GITHUB_REPOSITORY)) • Powered by native orchestration*
"@

# Write output
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$comment | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "✅ PR comment generated: $OutputPath" -ForegroundColor Green
Write-Host "   Length: $($comment.Length) characters" -ForegroundColor Cyan
Write-Host "   Recommendations: $($recommendations.items.Count)" -ForegroundColor Cyan
