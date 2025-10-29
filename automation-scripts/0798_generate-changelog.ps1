#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate changelog from git history.

.DESCRIPTION
    Creates a formatted changelog from git commit history between two tags or commits.
    Supports conventional commit format and categorizes changes.

.PARAMETER FromTag
    Starting tag/commit for the changelog.

.PARAMETER ToTag
    Ending tag/commit for the changelog. Defaults to HEAD.

.PARAMETER Output
    Output file path. If not specified, prints to console.

.PARAMETER Format
    Output format: Markdown, HTML, or JSON.

.EXAMPLE
    ./0798_generate-changelog.ps1 -FromTag v1.0.0 -ToTag v1.1.0

.EXAMPLE
    ./0798_generate-changelog.ps1 -FromTag v1.0.7 -Output CHANGELOG.md

.NOTES
    Script Number: 0798
    Category: Git Automation & Documentation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$FromTag,

    [Parameter()]
    [string]$ToTag = 'HEAD',

    [Parameter()]
    [string]$Output,

    [Parameter()]
    [ValidateSet('Markdown', 'HTML', 'JSON')]
    [string]$Format = 'Markdown'
)

$ErrorActionPreference = 'Stop'

Write-Host "`n📝 AitherZero Changelog Generator" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════════`n" -ForegroundColor Magenta

# Verify we're in a git repository
if (-not (Test-Path .git)) {
    Write-Host "❌ Error: Not in a git repository" -ForegroundColor Red
    exit 1
}

# Verify tags exist
try {
    $null = git rev-parse "$FromTag" 2>&1
} catch {
    Write-Host "❌ Error: Tag '$FromTag' not found" -ForegroundColor Red
    exit 1
}

try {
    $null = git rev-parse "$ToTag" 2>&1
} catch {
    Write-Host "❌ Error: Tag '$ToTag' not found" -ForegroundColor Red
    exit 1
}

Write-Host "📊 Generating changelog from $FromTag to $ToTag..." -ForegroundColor Cyan

# Get commit messages using a simple format
$commits = @()
$commitList = git log --pretty=format:"%H" "$FromTag..$ToTag"

foreach ($hash in $commitList) {
    $subject = git log --format=%s -n 1 $hash
    $body = git log --format=%b -n 1 $hash
    $author = git log --format=%an -n 1 $hash
    $email = git log --format=%ae -n 1 $hash
    $date = git log --format=%ai -n 1 $hash
    
    $commits += [PSCustomObject]@{
        Hash = $hash
        Subject = $subject
        Body = $body
        Author = $author
        Email = $email
        Date = $date
    }
}

if ($commits.Count -eq 0) {
    Write-Host "⚠️  No commits found between $FromTag and $ToTag" -ForegroundColor Yellow
    exit 0
}

Write-Host "   Found $($commits.Count) commits`n" -ForegroundColor White

# Categorize commits based on conventional commit format
$categories = @{
    'feat'     = @{ Title = '✨ New Features'; Commits = @() }
    'fix'      = @{ Title = '🐛 Bug Fixes'; Commits = @() }
    'docs'     = @{ Title = '📚 Documentation'; Commits = @() }
    'style'    = @{ Title = '💎 Style'; Commits = @() }
    'refactor' = @{ Title = '♻️ Code Refactoring'; Commits = @() }
    'perf'     = @{ Title = '⚡ Performance'; Commits = @() }
    'test'     = @{ Title = '✅ Tests'; Commits = @() }
    'build'    = @{ Title = '🔨 Build System'; Commits = @() }
    'ci'       = @{ Title = '👷 CI/CD'; Commits = @() }
    'chore'    = @{ Title = '🔧 Chores'; Commits = @() }
    'revert'   = @{ Title = '⏪ Reverts'; Commits = @() }
    'security' = @{ Title = '🔒 Security'; Commits = @() }
    'other'    = @{ Title = '📦 Other Changes'; Commits = @() }
}

# Parse and categorize commits
foreach ($commit in $commits) {
    $type = 'other'
    $message = $commit.Subject
    
    # Parse conventional commit format
    if ($message -match '^(\w+)(\(.+?\))?:\s*(.+)$') {
        $commitType = $matches[1].ToLower()
        $commitMessage = $matches[3]
        
        if ($categories.ContainsKey($commitType)) {
            $type = $commitType
            $message = $commitMessage
        }
    }
    
    # Check for breaking changes
    $isBreaking = $commit.Body -match 'BREAKING CHANGE' -or $commit.Subject -match '!'
    
    $categories[$type].Commits += @{
        Hash      = if ($commit.Hash.Length -ge 8) { $commit.Hash.Substring(0, 8) } else { $commit.Hash }
        Message   = $message
        Author    = $commit.Author
        Date      = $commit.Date
        Breaking  = $isBreaking
    }
}

# Generate changelog content
$changelogContent = @()

# Header
$versionNumber = $ToTag -replace '^v', ''
$date = Get-Date -Format 'yyyy-MM-dd'
$changelogContent += "# Changelog"
$changelogContent += ""
$changelogContent += "## [$versionNumber] - $date"
$changelogContent += ""
$changelogContent += "### Summary"
$changelogContent += "Changes from $FromTag to $ToTag"
$changelogContent += ""

# Breaking changes section if any
$breakingChanges = $categories.Values.Commits | Where-Object { $_.Breaking }
if ($breakingChanges) {
    $changelogContent += "### ⚠️ BREAKING CHANGES"
    $changelogContent += ""
    foreach ($change in $breakingChanges) {
        $changelogContent += "- **$($change.Message)** ([$($change.Hash)](../../commit/$($change.Hash)))"
    }
    $changelogContent += ""
}

# Add categorized commits
foreach ($category in $categories.Keys | Sort-Object) {
    $categoryData = $categories[$category]
    if ($categoryData.Commits.Count -gt 0) {
        $changelogContent += "### $($categoryData.Title)"
        $changelogContent += ""
        
        foreach ($commit in $categoryData.Commits) {
            $breaking = if ($commit.Breaking) { " ⚠️" } else { "" }
            $changelogContent += "- $($commit.Message)$breaking ([$($commit.Hash)](../../commit/$($commit.Hash)))"
        }
        $changelogContent += ""
    }
}

# Contributors
$contributors = $commits | Select-Object -ExpandProperty Author -Unique | Sort-Object
if ($contributors.Count -gt 0) {
    $changelogContent += "### 👥 Contributors"
    $changelogContent += ""
    foreach ($contributor in $contributors) {
        $changelogContent += "- $contributor"
    }
    $changelogContent += ""
}

# Statistics
$changelogContent += "### 📊 Statistics"
$changelogContent += ""
$changelogContent += "- **Total Commits:** $($commits.Count)"
$changelogContent += "- **Contributors:** $($contributors.Count)"

# Get file changes statistics
try {
    $diffStat = git diff --shortstat "$FromTag" "$ToTag" 2>&1
    if ($LASTEXITCODE -eq 0 -and $diffStat) {
        $changelogContent += "- **Changes:** $diffStat"
    }
} catch {
    # Skip if diff fails
}

$changelogContent += ""

# Full changelog link
$changelogContent += "**Full Changelog:** [${FromTag}...${ToTag}](../../compare/${FromTag}...${ToTag})"
$changelogContent += ""

# Output
$changelog = $changelogContent -join "`n"

if ($Output) {
    $changelog | Set-Content -Path $Output -Encoding UTF8
    Write-Host "✅ Changelog written to: $Output" -ForegroundColor Green
} else {
    Write-Host $changelog
}

Write-Host "`n📝 Changelog generation completed!`n" -ForegroundColor Green
