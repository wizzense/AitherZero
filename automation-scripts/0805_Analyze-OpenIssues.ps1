#Requires -Version 7.0

<#
.SYNOPSIS
    Analyze open GitHub issues for PR linkage
.DESCRIPTION
    Scans open GitHub issues and matches them with current branch/PR changes
    to automatically link related issues. Uses AI/pattern matching to find
    relevant issues based on code changes, error messages, and file paths.
.NOTES
    Stage: Development
    Category: GitHub
#>

[CmdletBinding()]
param(
    [string]$Branch,
    
    [string]$BaseBranch = 'main',
    
    [switch]$IncludeClosed,
    
    [ValidateSet('All', 'Bug', 'Feature', 'Test', 'Documentation')]
    [string]$IssueType = 'All',
    
    [int]$MaxIssues = 100,
    
    [switch]$UseAI,
    
    [decimal]$MatchThreshold = 0.7,
    
    [switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "GitAutomation.psm1") -Force
Import-Module (Join-Path $devModulePath "IssueTracker.psm1") -Force

Write-Host "Analyzing open issues for PR linkage..." -ForegroundColor Cyan

# Get current branch if not specified
if (-not $Branch) {
    $Branch = git branch --show-current
}

Write-Host "Branch: $Branch" -ForegroundColor Gray

# Get changed files
Write-Host "Getting changed files..." -ForegroundColor Yellow
$changedFiles = git diff $BaseBranch...$Branch --name-only 2>$null
if (-not $changedFiles) {
    $changedFiles = git diff --cached --name-only 2>$null
}

if (-not $changedFiles) {
    Write-Warning "No changed files found"
    $changedFiles = @()
} else {
    $changedFiles = $changedFiles -split "`n" | Where-Object { $_ }
    Write-Host "  Found $($changedFiles.Count) changed files" -ForegroundColor Gray
}

# Get commit messages
Write-Host "Getting commit messages..." -ForegroundColor Yellow
$commits = git log $BaseBranch..$Branch --pretty=format:"%s%n%b" 2>$null
if ($commits) {
    $commits = $commits -split "`n" | Where-Object { $_ }
    Write-Host "  Found $($commits.Count) commit messages" -ForegroundColor Gray
}

# Get diff content for error matching
Write-Host "Analyzing code changes..." -ForegroundColor Yellow
$diffContent = git diff $BaseBranch...$Branch 2>$null
$addedLines = @()
$removedLines = @()

if ($diffContent) {
    foreach ($line in $diffContent -split "`n") {
        if ($line -match '^\+[^+]') {
            $addedLines += $line.Substring(1)
        } elseif ($line -match '^-[^-]') {
            $removedLines += $line.Substring(1)
        }
    }
    Write-Host "  Added lines: $($addedLines.Count)" -ForegroundColor Gray
    Write-Host "  Removed lines: $($removedLines.Count)" -ForegroundColor Gray
}

# Get open issues
Write-Host "`nFetching GitHub issues..." -ForegroundColor Yellow
$issueStates = if ($IncludeClosed) { 'all' } else { 'open' }
$labelFilter = switch ($IssueType) {
    'Bug' { '--label bug' }
    'Feature' { '--label enhancement' }
    'Test' { '--label test' }
    'Documentation' { '--label documentation' }
    default { '' }
}

try {
    $issuesJson = gh issue list --state $issueStates $labelFilter --limit $MaxIssues --json number,title,body,labels,assignees,createdAt,updatedAt
    $issues = $issuesJson | ConvertFrom-Json
    Write-Host "  Found $($issues.Count) issues" -ForegroundColor Gray
} catch {
    Write-Error "Failed to fetch issues: $_"
    exit 1
}

# Match issues to changes
Write-Host "`nMatching issues to changes..." -ForegroundColor Yellow
$matchedIssues = @()

foreach ($issue in $issues) {
    $matchScore = 0
    $matchReasons = @()
    
    # Direct issue number reference in commits
    if ($commits -match "#$($issue.number)\b") {
        $matchScore = 1.0
        $matchReasons += "Direct reference in commit"
    }
    
    # File path matching
    if ($issue.body) {
        foreach ($file in $changedFiles) {
            $fileName = Split-Path $file -Leaf
            $fileBase = [System.IO.Path]::GetFileNameWithoutExtension($file)
            
            if ($issue.body -match [regex]::Escape($fileName) -or 
                $issue.title -match [regex]::Escape($fileBase)) {
                $matchScore += 0.5
                $matchReasons += "File match: $fileName"
            }
        }
    }
    
    # Error message matching
    if ($issue.body -match 'error|exception|failed|failure') {
        # Extract error messages from issue
        $issueErrors = @()
        foreach ($line in $issue.body -split "`n") {
            if ($line -match 'error|Error|ERROR|Exception|Failed') {
                $issueErrors += $line
            }
        }
        
        # Check if we're fixing these errors
        foreach ($error in $issueErrors) {
            # Simple pattern matching for common error patterns
            $errorPattern = $error -replace '[^\w\s]', '.*'
            
            foreach ($line in $removedLines) {
                if ($line -match $errorPattern) {
                    $matchScore += 0.3
                    $matchReasons += "Fixing error: $(($error -split "`n")[0])"
                    break
                }
            }
        }
    }
    
    # Function/class name matching
    $codePatterns = @(
        'function\s+(\w+)',
        'class\s+(\w+)',
        'def\s+(\w+)',
        '\$script:(\w+)',
        'Export-ModuleMember.*-Function\s+(\w+)'
    )
    
    foreach ($pattern in $codePatterns) {
        $matches = [regex]::Matches($issue.body, $pattern)
        foreach ($match in $matches) {
            $name = $match.Groups[1].Value
            if ($diffContent -match "\b$name\b") {
                $matchScore += 0.2
                $matchReasons += "Code reference: $name"
            }
        }
    }
    
    # Keyword matching in commit messages
    $keywords = @('fix', 'fixes', 'resolve', 'resolves', 'close', 'closes', 'address', 'addresses')
    $issueKeywords = ($issue.title -split '\s+') | Where-Object { $_.Length -gt 4 }
    
    foreach ($keyword in $keywords) {
        foreach ($commit in $commits) {
            if ($commit -match "$keyword.*$($issue.number)" -or 
                ($commit -match $keyword -and $issueKeywords | Where-Object { $commit -match $_ })) {
                $matchScore += 0.4
                $matchReasons += "Keyword match in commit"
                break
            }
        }
    }
    
    # AI matching if enabled
    if ($UseAI -and $matchScore -lt $MatchThreshold) {
        # This would call an AI service to analyze the relationship
        # For now, using enhanced pattern matching as placeholder
        
        # Check for similar error patterns
        if ($issue.body -match 'TerminatingError|Write-Error|throw') {
            foreach ($line in $addedLines) {
                if ($line -match 'try|catch|ErrorAction|if.*null') {
                    $matchScore += 0.1
                    $matchReasons += "Error handling added"
                }
            }
        }
    }
    
    # Add to matched issues if above threshold
    if ($matchScore -ge $MatchThreshold) {
        $matchedIssues += [PSCustomObject]@{
            Number = $issue.number
            Title = $issue.title
            Score = [Math]::Min($matchScore, 1.0)
            Reasons = $matchReasons
            Labels = $issue.labels.name
            ShouldClose = $matchScore -ge 0.9
            LinkType = if ($matchScore -ge 0.9) { 'Closes' } elseif ($matchScore -ge 0.7) { 'Fixes' } else { 'Refs' }
        }
    }
}

# Sort by match score
$matchedIssues = $matchedIssues | Sort-Object Score -Descending

# Display results
if ($matchedIssues.Count -eq 0) {
    Write-Host "No matching issues found" -ForegroundColor Gray
} else {
    Write-Host "`nMatched Issues:" -ForegroundColor Cyan
    
    foreach ($match in $matchedIssues) {
        $confidence = switch ([Math]::Round($match.Score, 1)) {
            { $_ -ge 0.9 } { 'High' }
            { $_ -ge 0.7 } { 'Medium' }
            default { 'Low' }
        }
        
        Write-Host "`n  #$($match.Number): $($match.Title)" -ForegroundColor $(
            switch ($confidence) {
                'High' { 'Green' }
                'Medium' { 'Yellow' }
                'Low' { 'Gray' }
            }
        )
        Write-Host "    Confidence: $confidence ($([Math]::Round($match.Score * 100))%)" -ForegroundColor Gray
        Write-Host "    Link Type: $($match.LinkType)" -ForegroundColor Gray
        Write-Host "    Reasons:" -ForegroundColor Gray
        foreach ($reason in $match.Reasons | Select-Object -Unique) {
            Write-Host "      - $reason" -ForegroundColor Gray
        }
    }
    
    # Generate PR body section
    Write-Host "`nPR Body Section:" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Gray
    
    $prBody = @"
## Related Issues

"@
    
    $closingIssues = $matchedIssues | Where-Object { $_.LinkType -eq 'Closes' }
    if ($closingIssues) {
        $prBody += "`n### Closes`n"
        foreach ($issue in $closingIssues) {
            $prBody += "- Closes #$($issue.Number) - $($issue.Title)`n"
        }
    }
    
    $fixingIssues = $matchedIssues | Where-Object { $_.LinkType -eq 'Fixes' }
    if ($fixingIssues) {
        $prBody += "`n### Fixes`n"
        foreach ($issue in $fixingIssues) {
            $prBody += "- Fixes #$($issue.Number) - $($issue.Title)`n"
        }
    }
    
    $referencingIssues = $matchedIssues | Where-Object { $_.LinkType -eq 'Refs' }
    if ($referencingIssues) {
        $prBody += "`n### References`n"
        foreach ($issue in $referencingIssues) {
            $prBody += "- Refs #$($issue.Number) - $($issue.Title)`n"
        }
    }
    
    Write-Host $prBody -ForegroundColor White
}

# Output for pipeline
[PSCustomObject]@{
    MatchedIssues = $matchedIssues
    PRBodySection = if ($matchedIssues) { $prBody } else { $null }
    HighConfidence = @($matchedIssues | Where-Object { $_.Score -ge 0.9 })
    ShouldClose = @($matchedIssues | Where-Object { $_.ShouldClose })
}