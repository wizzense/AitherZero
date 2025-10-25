#Requires -Version 7.0
<#
.SYNOPSIS
    Creates GitHub issues automatically from test failures
.DESCRIPTION
    Parses test results and creates detailed GitHub issues for failures
    Works with both local execution and GitHub Actions
.PARAMETER TestResults
    Path to test results file or object
.PARAMETER IssueType
    Type of issue to create (TestFailure, CodeViolation, Bug)
.PARAMETER AutoCreate
    Automatically create issue without prompting
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$TestResults = "./tests/results/latest-test-results.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet('TestFailure', 'CodeViolation', 'Bug')]
    [string]$IssueType = 'TestFailure',

    [switch]$AutoCreate,

    [switch]$GitHubActions
)

# Script metadata
$scriptInfo = @{
    Stage = 'Testing'
    Number = '0810'
    Name = 'Create-IssueFromTestFailure'
    Description = 'Creates GitHub issues from test failures'
    Dependencies = @('gh', 'git')
    Tags = @('testing', 'github', 'automation', 'ci')
    RequiresAdmin = $false
}

# Import required modules
$modulePath = Join-Path $PSScriptRoot ".." "Initialize-AitherModules.ps1"
if (Test-Path $modulePath) {
    . $modulePath
}

# Helper function to check if running in GitHub Actions
function Test-GitHubActions {
    return [bool]$env:GITHUB_ACTIONS
}

# Helper function to get system context
function Get-SystemContext {
    $context = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        OS = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
        AitherZeroVersion = if (Test-Path "./VERSION") { (Get-Content "./VERSION").Trim() } else { "Unknown" }
        GitBranch = & git branch --show-current 2>$null
        GitCommit = & git rev-parse --short HEAD 2>$null
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    if (Test-GitHubActions) {
        $context.GitHubRun = $env:GITHUB_RUN_ID
        $context.GitHubActor = $env:GITHUB_ACTOR
        $context.GitHubWorkflow = $env:GITHUB_WORKFLOW
    }

    return $context
}

# Parse test results
function Get-TestFailures {
    param([string]$ResultsPath)

    if (-not (Test-Path $ResultsPath)) {
        Write-Warning "Test results not found at: $ResultsPath"
        return @()
    }

    $failures = @()

    # Handle different result formats
    if ($ResultsPath -match '\.json$') {
        $results = Get-Content $ResultsPath | ConvertFrom-Json

        # Parse Pester JSON format
        if ($results.Tests) {
            $failures = $results.Tests | Where-Object { $_.Result -eq 'Failed' }
        }
        # Parse custom format
        elseif ($results.Failures) {
            $failures = $results.Failures
        }
    }
    elseif ($ResultsPath -match '\.xml$') {
        # Parse NUnit XML format
        [xml]$results = Get-Content $ResultsPath
        $failures = $results.SelectNodes("//test-case[@result='Failed']")
    }

    return $failures
}

# Parse PSScriptAnalyzer results
function Get-CodeViolations {
    param([string]$ResultsPath = "./tests/results/psscriptanalyzer-results.json")

    if (-not (Test-Path $ResultsPath)) {
        # Run PSScriptAnalyzer if results don't exist
        $analyzerScript = Join-Path $PSScriptRoot "0404_Run-PSScriptAnalyzer.ps1"
        if (Test-Path $analyzerScript) {
            & $analyzerScript -OutputPath $ResultsPath
        }
    }

    if (Test-Path $ResultsPath) {
        return Get-Content $ResultsPath | ConvertFrom-Json
    }

    return @()
}

# Create issue body from template
function New-IssueBody {
    param(
        [string]$Type,
        [object]$Data,
        [hashtable]$Context
    )

    $body = @()

    switch ($Type) {
        'TestFailure' {
            $body += "## Test Failure Summary"
            $body += "Automated test execution detected failures that need attention."
            $body += ""
            $body += "## Test Execution Context"
            $body += "**Test Type:** $($Data.TestType ?? 'Unit')"
            $body += "**Test Framework:** Pester"
            $body += "**Execution Time:** $($Context.Timestamp)"
            $body += "**Environment:** $($Context.OS) / PowerShell $($Context.PowerShellVersion)"
            $body += ""

            if (Test-GitHubActions) {
                $body += "## GitHub Actions Context"
                $body += "**Workflow:** $($Context.GitHubWorkflow)"
                $body += "**Run ID:** [$($Context.GitHubRun)](https://github.com/$env:GITHUB_REPOSITORY/actions/runs/$($Context.GitHubRun))"
                $body += "**Actor:** @$($Context.GitHubActor)"
                $body += ""
            }

            $body += "## Failed Test Details"
            $body += '```powershell'
            $body += "Test: $($Data.Name)"
            $body += "File: $($Data.ScriptBlock.File):$($Data.ScriptBlock.StartPosition.StartLine)"
            $body += "Duration: $($Data.Duration)"
            $body += ""
            $body += "Error:"
            $body += $Data.ErrorRecord
            $body += '```'
            $body += ""
            $body += "## Stack Trace"
            $body += '```'
            $body += $Data.StackTrace
            $body += '```'
        }

        'CodeViolation' {
            $body += "## Code Quality Violation"
            $body += "PSScriptAnalyzer detected code quality issues."
            $body += ""
            $body += "## Violation Details"
            $body += "**Rule:** $($Data.RuleName)"
            $body += "**Severity:** $($Data.Severity)"
            $body += "**File:** $($Data.ScriptName):$($Data.Line)"
            $body += ""
            $body += "## Message"
            $body += $Data.Message
            $body += ""
            $body += "## Suggested Fix"
            $body += "Review the PSScriptAnalyzer documentation for rule: $($Data.RuleName)"
            $body += "https://github.com/PowerShell/PSScriptAnalyzer/tree/master/docs/Rules/$($Data.RuleName).md"
        }

        'Bug' {
            $body += "## Bug Description"
            $body += $Data.Description
            $body += ""
            $body += "## System Context"
            $body += "**AitherZero Version:** $($Context.AitherZeroVersion)"
            $body += "**PowerShell Version:** $($Context.PowerShellVersion)"
            $body += "**Operating System:** $($Context.OS)"
            $body += ""
            $body += "## Error Output"
            $body += '```powershell'
            $body += $Data.Error
            $body += '```'
        }
    }

    # Add common footer
    $body += ""
    $body += "## Environment Information"
    $body += "**Git Branch:** $($Context.GitBranch)"
    $body += "**Git Commit:** $($Context.GitCommit)"
    $body += "**Generated:** $($Context.Timestamp)"
    $body += ""
    $body += "---"
    $body += "*This issue was automatically created by AitherZero test automation*"

    return $body -join "`n"
}

# Create GitHub issue
function New-GitHubIssue {
    param(
        [string]$Title,
        [string]$Body,
        [string[]]$Labels = @(),
        [string]$Assignee = $null
    )

    # Check if gh CLI is available
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) is not installed. Cannot create issue."
        return $null
    }

    # Build gh command
    $ghArgs = @('issue', 'create')
    $ghArgs += '--title', $Title
    $ghArgs += '--body', $Body

    if ($Labels) {
        $ghArgs += '--label', ($Labels -join ',')
    }

    if ($Assignee) {
        $ghArgs += '--assignee', $Assignee
    }

    # Create issue
    try {
        $issueUrl = & gh @ghArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Issue created successfully: $issueUrl" -ForegroundColor Green
            return $issueUrl
        }
        else {
            Write-Error "Failed to create issue: $issueUrl"
            return $null
        }
    }
    catch {
        Write-Error "Error creating issue: $_"
        return $null
    }
}

# Main execution
try {
    Write-Host "🔍 Analyzing test results and system context..." -ForegroundColor Cyan

    $context = Get-SystemContext
    $issues = @()

    switch ($IssueType) {
        'TestFailure' {
            $failures = Get-TestFailures -ResultsPath $TestResults

            foreach ($failure in $failures) {
                $title = "[TEST] $($failure.Name) failed"
                $body = New-IssueBody -Type 'TestFailure' -Data $failure -Context $context
                $labels = @('test-failure', 'automated')

                if (Test-GitHubActions) {
                    $labels += 'ci-failure'
                }

                $issues += @{
                    Title = $title
                    Body = $body
                    Labels = $labels
                }
            }
        }

        'CodeViolation' {
            $violations = Get-CodeViolations

            # Group violations by rule
            $groupedViolations = $violations | Group-Object RuleName

            foreach ($group in $groupedViolations) {
                $title = "[QUALITY] $($group.Name) - $($group.Count) violations"
                $body = New-IssueBody -Type 'CodeViolation' -Data $group.Group[0] -Context $context
                $labels = @('code-quality', 'psscriptanalyzer', 'automated')

                $issues += @{
                    Title = $title
                    Body = $body
                    Labels = $labels
                }
            }
        }
    }

    if ($issues.Count -eq 0) {
        Write-Host "✅ No issues to create!" -ForegroundColor Green
        exit 0
    }

    Write-Host "📝 Found $($issues.Count) issue(s) to create" -ForegroundColor Yellow

    foreach ($issue in $issues) {
        if (-not $AutoCreate -and -not (Test-GitHubActions)) {
            Write-Host ""
            Write-Host "Title: $($issue.Title)" -ForegroundColor Cyan
            Write-Host "Labels: $($issue.Labels -join ', ')" -ForegroundColor Gray
            Write-Host "Preview:" -ForegroundColor Gray
            Write-Host ($issue.Body | Select-Object -First 10) -ForegroundColor DarkGray
            Write-Host "..."

            $response = Read-Host "Create this issue? (Y/N)"
            if ($response -ne 'Y') {
                continue
            }
        }

        $result = New-GitHubIssue @issue

        if ($result -and (Test-GitHubActions)) {
            # Output for GitHub Actions
            Write-Host "::notice::Created issue: $result"
        }
    }

    Write-Host "✅ Issue creation complete!" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to create issues: $_"
    exit 1
}