#Requires -Version 7.0

<#
.SYNOPSIS
    Generate PR changelog from commits with categorization
.DESCRIPTION
    Analyzes commits between base and head branches, categorizes them (feat/fix/docs),
    and generates a structured changelog
.PARAMETER BaseBranch
    Base branch to compare from (usually main)
.PARAMETER HeadBranch
    Head branch to compare to (PR branch)
.PARAMETER OutputPath
    Path where changelog will be saved
.PARAMETER IncludeIssueLinks
    Auto-link to issues and PRs mentioned
.PARAMETER CategorizeCommits
    Group commits by conventional commit types
.PARAMETER Format
    Output format (Markdown, HTML, JSON)
.EXAMPLE
    ./0513_Generate-Changelog.ps1 -BaseBranch main -HeadBranch feature/xyz -OutputPath ./CHANGELOG.md
.NOTES
    Stage: Reporting
    Category: Documentation
    Order: 0513
    Tags: changelog, commits, documentation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseBranch,
    
    [Parameter(Mandatory)]
    [string]$HeadBranch,
    
    [string]$OutputPath = "library/reports/CHANGELOG-PR.md",
    [switch]$IncludeIssueLinks,
    [switch]$CategorizeCommits,
    [ValidateSet('Markdown', 'HTML', 'JSON')]
    [string]$Format = 'Markdown'
)

$ErrorActionPreference = 'Stop'

# Get commits between branches
try {
    $commits = git log --pretty=format:"%H|%h|%an|%ae|%aI|%s|%b" "$BaseBranch..$HeadBranch" 2>$null
} catch {
    Write-Error "Failed to get git log: $_"
    exit 1
}

if (-not $commits) {
    Write-Warning "No commits found between $BaseBranch and $HeadBranch"
    "# No Changes" | Set-Content $OutputPath
    exit 0
}

# Parse commits
$parsedCommits = $commits | ForEach-Object {
    $parts = $_ -split '\|', 7
    @{
        Hash = $parts[0]
        ShortHash = $parts[1]
        Author = $parts[2]
        Email = $parts[3]
        Date = $parts[4]
        Subject = $parts[5]
        Body = $parts[6]
        Type = 'other'
        Scope = ''
        Breaking = $false
    }
}

# Categorize by conventional commits
if ($CategorizeCommits) {
    foreach ($commit in $parsedCommits) {
        if ($commit.Subject -match '^(\w+)(?:\(([^\)]+)\))?!?:\s*(.+)$') {
            $commit.Type = $matches[1].ToLower()
            $commit.Scope = $matches[2]
            $commit.Breaking = $commit.Subject -match '!:'
            $commit.Subject = $matches[3]
        }
    }
}

# Generate changelog
$changelog = @"
# Changelog - $(Get-Date -Format 'yyyy-MM-dd')

**Changes**: $BaseBranch → $HeadBranch  
**Commits**: $($parsedCommits.Count)

"@

# Group by type
$grouped = $parsedCommits | Group-Object -Property Type | Sort-Object Name

foreach ($group in $grouped) {
    $icon = switch ($group.Name) {
        'feat' { '✨' }
        'fix' { '🐛' }
        'docs' { '📚' }
        'style' { '💎' }
        'refactor' { '♻️' }
        'perf' { '⚡' }
        'test' { '🧪' }
        'build' { '🏗️' }
        'ci' { '👷' }
        'chore' { '🔧' }
        default { '📝' }
    }
    
    $title = switch ($group.Name) {
        'feat' { 'Features' }
        'fix' { 'Bug Fixes' }
        'docs' { 'Documentation' }
        'style' { 'Code Style' }
        'refactor' { 'Refactoring' }
        'perf' { 'Performance' }
        'test' { 'Tests' }
        'build' { 'Build System' }
        'ci' { 'CI/CD' }
        'chore' { 'Maintenance' }
        default { 'Other Changes' }
    }
    
    $changelog += "`n## $icon $title`n`n"
    
    foreach ($commit in $group.Group) {
        $scope = if ($commit.Scope) { "**$($commit.Scope)**: " } else { '' }
        $breaking = if ($commit.Breaking) { '⚠️ **BREAKING** ' } else { '' }
        
        $subject = $commit.Subject
        
        # Link to issues/PRs if requested
        if ($IncludeIssueLinks) {
            $subject = $subject -replace '#(\d+)', "[#`$1](https://github.com/$env:GITHUB_REPOSITORY/issues/`$1)"
        }
        
        $changelog += "- $breaking$scope$subject ([$($commit.ShortHash)](https://github.com/$env:GITHUB_REPOSITORY/commit/$($commit.Hash)))`n"
    }
}

# Add contributors
$contributors = $parsedCommits | Select-Object -Property Author -Unique | Sort-Object Author
$changelog += "`n## 👥 Contributors`n`n"
foreach ($contributor in $contributors) {
    $changelog += "- $($contributor.Author)`n"
}

# Write output
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$changelog | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "✅ Changelog generated: $OutputPath" -ForegroundColor Green
Write-Host "   Commits: $($parsedCommits.Count)" -ForegroundColor Cyan
Write-Host "   Contributors: $($contributors.Count)" -ForegroundColor Cyan
