#Requires -Version 7.0

<#
.SYNOPSIS
    Create GitHub issues from test failures
.DESCRIPTION
    Parses test results and creates GitHub issues for failures,
    violations, and other issues found during testing.
.NOTES
    Stage: Testing
    Category: GitHub
    Dependencies: 0402, 0404
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Pester', 'PSScriptAnalyzer', 'All')]
    [string]$Source = 'All',

    [string]$ResultsPath = './tests/results',

    [string[]]$Labels = @('bug', 'automated'),

    [ValidateSet('P0', 'P1', 'P2', 'P3')]
    [string]$DefaultPriority = 'P2',

    [switch]$DryRun,

    [switch]$GroupByFile,

    [int]$MaxIssues = 20,

    [switch]$UpdateExisting,

    [string]$Milestone,

    [string[]]$Assignees,

    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$devModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) "domains/development"
Import-Module (Join-Path $devModulePath "IssueTracker.psm1") -Force

Write-Host "Creating GitHub issues from test failures..." -ForegroundColor Cyan

# Collect failures
$failures = @()

# Parse Pester results
if ($Source -in @('Pester', 'All')) {
    Write-Host "Parsing Pester results..." -ForegroundColor Yellow

    $pesterFiles = Get-ChildItem -Path $ResultsPath -Filter "*Pester*.xml" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1

    if ($pesterFiles) {
        foreach ($file in $pesterFiles) {
            Write-Host "  Processing: $($file.Name)" -ForegroundColor Gray

            try {
                $xml = [xml](Get-Content $file.FullName)

                # Parse test failures
                $testCases = $xml.SelectNodes("//test-case[@result='Failed']")

                foreach ($testCase in $testCases) {
                    $failures += [PSCustomObject]@{
                        Type = 'TestFailure'
                        Source = 'Pester'
                        File = $testCase.GetAttribute('classname')
                        Test = $testCase.GetAttribute('name')
                        Message = $testCase.SelectSingleNode('failure').GetAttribute('message')
                        StackTrace = $testCase.SelectSingleNode('failure').InnerText
                        Severity = 'High'
                    }
                }

                Write-Host "  Found $($testCases.Count) test failures" -ForegroundColor Yellow

            } catch {
                Write-Warning "Failed to parse Pester results: $_"
            }
        }
    } else {
        Write-Host "  No Pester results found" -ForegroundColor Gray
    }
}

# Parse PSScriptAnalyzer results
if ($Source -in @('PSScriptAnalyzer', 'All')) {
    Write-Host "Parsing PSScriptAnalyzer results..." -ForegroundColor Yellow

    $analyzerFiles = Get-ChildItem -Path $ResultsPath -Filter "*Analyzer*.json" -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1

    if ($analyzerFiles) {
        foreach ($file in $analyzerFiles) {
            Write-Host "  Processing: $($file.Name)" -ForegroundColor Gray

            try {
                $results = Get-Content $file.FullName | ConvertFrom-Json

                foreach ($violation in $results) {
                    # Skip informational messages
                    if ($violation.Severity -eq 'Information') { continue }

                    $failures += [PSCustomObject]@{
                        Type = 'CodeViolation'
                        Source = 'PSScriptAnalyzer'
                        File = $violation.ScriptPath
                        Rule = $violation.RuleName
                        Message = $violation.Message
                        Line = $violation.Line
                        Column = $violation.Column
                        Severity = $violation.Severity
                    }
                }

                Write-Host "  Found $($results.Count) violations" -ForegroundColor Yellow

            } catch {
                Write-Warning "Failed to parse PSScriptAnalyzer results: $_"
            }
        }
    } else {
        Write-Host "  No PSScriptAnalyzer results found" -ForegroundColor Gray
    }
}

if ($failures.Count -eq 0) {
    Write-Host "✓ No failures found to create issues for" -ForegroundColor Green
    exit 0
}

Write-Host "`nFound $($failures.Count) total failures" -ForegroundColor Yellow

# Group failures if requested
if ($GroupByFile) {
    $grouped = $failures | Group-Object File
    Write-Host "Grouped into $($grouped.Count) files" -ForegroundColor Gray
} else {
    $grouped = @([PSCustomObject]@{
        Name = 'All Failures'
        Group = $failures
    })
}

# Limit number of issues
if ($grouped.Count -gt $MaxIssues) {
    Write-Warning "Limiting to $MaxIssues issues (found $($grouped.Count))"
    $grouped = $grouped | Select-Object -First $MaxIssues
}

# Create issues
$createdIssues = @()

foreach ($group in $grouped) {
    # Build issue title
    if ($GroupByFile) {
        $title = "Test failures in $(Split-Path $group.Name -Leaf)"
    } else {
        $title = "Test failures found - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }

    # Build issue body
    $body = @"
## Test Failures Report

This issue was automatically created from test failures.

### Summary
- **Total Failures**: $($group.Group.Count)
- **Source**: $(($group.Group.Source | Select-Object -Unique) -join ', ')
- **Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

### Details
"@

    foreach ($failure in $group.Group | Select-Object -First 10) {
        $body += "`n`n#### $(if ($failure.Type -eq 'TestFailure') { '❌ Test Failure' } else { '⚠️ Code Violation' })`n"

        if ($failure.Type -eq 'TestFailure') {
            $body += @"
- **Test**: ``$($failure.Test)``
- **File**: ``$($failure.File)``
- **Message**: $($failure.Message)
"@
            if ($failure.StackTrace -and $failure.StackTrace.Length -lt 500) {
                $body += @"

<details>
<summary>Stack Trace</summary>

``````
$($failure.StackTrace)
``````

</details>
"@
            }
        } else {
            $body += @"
- **Rule**: ``$($failure.Rule)``
- **File**: ``$($failure.File)``
- **Location**: Line $($failure.Line), Column $($failure.Column)
- **Severity**: $($failure.Severity)
- **Message**: $($failure.Message)
"@
        }
    }

    if ($group.Group.Count -gt 10) {
        $body += "`n`n*... and $($group.Group.Count - 10) more failures*"
    }

    # Add action items
    $body += @"

### Action Items
- [ ] Review failures
- [ ] Fix root causes
- [ ] Update tests if needed
- [ ] Verify fixes

### Automation
This issue was created by AitherZero automation.
Script: ``0800_Create-TestIssues.ps1``
"@

    # Determine priority based on severity
    $priority = $DefaultPriority
    if ($group.Group | Where-Object { $_.Severity -eq 'Error' }) {
        $priority = 'P1'
    } elseif ($group.Group | Where-Object { $_.Severity -eq 'Warning' }) {
        $priority = 'P2'
    }

    # Build labels
    $issueLabels = $Labels + @("priority:$priority")
    if ($GroupByFile) {
        $extension = [System.IO.Path]::GetExtension($group.Name)
        if ($extension) {
            $issueLabels += "lang:$($extension.TrimStart('.'))"
        }
    }

    # Check for existing issue if updating
    $existingIssue = $null
    if ($UpdateExisting) {
        try {
            $searchQuery = "is:issue is:open in:title `"$title`""
            $existing = gh issue list --search $searchQuery --json number,title --limit 1 | ConvertFrom-Json
            if ($existing) {
                $existingIssue = $existing[0].number
                Write-Host "Found existing issue #$existingIssue" -ForegroundColor Gray
            }
        } catch {
            Write-Warning "Failed to search for existing issues: $_"
        }
    }

    if ($DryRun) {
        Write-Host "`n[DRY RUN] Would create issue:" -ForegroundColor Magenta
        Write-Host "  Title: $title" -ForegroundColor Gray
        Write-Host "  Labels: $($issueLabels -join ', ')" -ForegroundColor Gray
        Write-Host "  Priority: $priority" -ForegroundColor Gray
        Write-Host "  Failures: $($group.Group.Count)" -ForegroundColor Gray
    } else {
        try {
            if ($existingIssue) {
                # Update existing issue
                Write-Host "Updating issue #$existingIssue..." -ForegroundColor Yellow

                # Add comment with new failures
                $comment = "## Updated Test Results`n`n$body"
                gh issue comment $existingIssue --body $comment

                $createdIssues += [PSCustomObject]@{
                    Number = $existingIssue
                    Title = $title
                    Updated = $true
                }

                Write-Host "✓ Updated issue #$existingIssue" -ForegroundColor Green
            } else {
                # Create new issue
                Write-Host "Creating new issue..." -ForegroundColor Yellow

                $issueParams = @{
                    Title = $title
                    Body = $body
                    Labels = $issueLabels
                }

                if ($Assignees) {
                    $issueParams.Assignees = $Assignees
                }

                if ($Milestone) {
                    $issueParams.Milestone = $Milestone
                }

                $issue = New-GitHubIssue @issueParams

                $createdIssues += [PSCustomObject]@{
                    Number = $issue.Number
                    Title = $title
                    Url = $issue.Url
                    Updated = $false
                }

                Write-Host "✓ Created issue #$($issue.Number)" -ForegroundColor Green
                Write-Host "  URL: $($issue.Url)" -ForegroundColor Gray
            }
        } catch {
            Write-Error "Failed to create/update issue: $_"
        }
    }
}

# Summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Total failures: $($failures.Count)" -ForegroundColor Gray
Write-Host "  Issues created: $($createdIssues | Where-Object { -not $_.Updated }).Count" -ForegroundColor Gray
Write-Host "  Issues updated: $($createdIssues | Where-Object { $_.Updated }).Count" -ForegroundColor Gray

# Output for pipeline
$createdIssues