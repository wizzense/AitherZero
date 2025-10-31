#Requires -Version 7.0

<#
.SYNOPSIS
    Post or update PR comment with test results
.DESCRIPTION
    Posts test results as a comment on GitHub PR
#>

[CmdletBinding()]
param(
    [string]$TestResultsPath = "./test-results/results.json",
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$RunId = $env:GITHUB_RUN_ID,
    [int]$PRNumber,
    [string]$Token = $env:GITHUB_TOKEN,
    [switch]$CI
)

$ErrorActionPreference = 'Stop'

# Get PR number from environment if not provided
if (-not $PRNumber -and $env:GITHUB_EVENT_NAME -eq 'pull_request') {
    $EventName = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
    $PRNumber = $EventName.pull_request.number
}

if (-not $PRNumber) {
    Write-Host "Not a PR, skipping comment" -ForegroundColor Yellow
    exit 0
}

# Read test results
$testsPassed = $false
$testsRun = 0
$testsFailed = 0

if (Test-Path $TestResultsPath) {
    $results = Get-Content $TestResultsPath | ConvertFrom-Json
    $testsPassed = $results.FailedCount -eq 0
    $testsRun = $results.TotalCount
    $testsFailed = $results.FailedCount
}

$emoji = if ($testsPassed) { '✅' } else { '❌' }
$status = if ($testsPassed) { 'Ready for review' } else { 'Issues found' }

# Create comment body
$comment = @"
## $emoji AitherZero PR Validation

**Status**: $status
**Tests**: $testsRun run, $testsFailed failed
**Artifacts**: [Download Results](https://github.com/$Repository/actions/runs/$RunId)

### 💡 Test Locally
``````powershell
# Quick validation
./az 0407  # Syntax
./az 0404  # Linting
./az 0402  # Tests

# Or use orchestration
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick
``````
"@

# Post comment using GitHub API
$headers = @{
    Authorization = "Bearer $Token"
    Accept = "application/vnd.github.v3+json"
}

$apiUrl = "https://api.github.com/repos/$Repository/issues/$PRNumber/comments"

# Check for existing comment
$existingComments = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
$botComment = $existingComments | Where-Object {
    $_.body -like "*AitherZero PR Validation*"
} | Select-Object -First 1

if ($botComment) {
    # Update existing comment
    $updateUrl = "https://api.github.com/repos/$Repository/issues/comments/$($botComment.id)"
    Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Patch -Body (@{ body = $comment } | ConvertTo-Json)
    Write-Host "✅ Updated PR comment" -ForegroundColor Green
} else {
    # Create new comment
    Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Post -Body (@{ body = $comment } | ConvertTo-Json)
    Write-Host "✅ Posted PR comment" -ForegroundColor Green
}