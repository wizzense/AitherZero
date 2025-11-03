<#
.SYNOPSIS
    Get detailed workflow run reports for CI debugging.

.DESCRIPTION
    Fetches and displays detailed GitHub workflow run information including
    check statuses, job logs, and failure reasons. Can be used for debugging
    CI failures and can run as a CI check itself.
    
    Stage: Reporting & Analysis
    Category: CI/CD Debugging

.PARAMETER RunId
    Specific workflow run ID to get detailed report for.

.PARAMETER WorkflowName
    Filter by workflow name (e.g., "pr-validation", "unit-tests").

.PARAMETER Status
    Filter by status: all, success, failure, cancelled, in_progress.

.PARAMETER Branch
    Filter by branch name.

.PARAMETER List
    List recent workflow runs instead of detailed report.

.PARAMETER MaxRuns
    Maximum number of runs to list (default: 10).

.PARAMETER OutputFormat
    Output format: console, json, markdown (default: console).

.PARAMETER ExportPath
    Path to export report to (optional).

.EXAMPLE
    ./automation-scripts/0530_Get-WorkflowRunReport.ps1 -RunId 12345678
    Get detailed report for specific workflow run.

.EXAMPLE
    ./automation-scripts/0530_Get-WorkflowRunReport.ps1 -List -Status failure -MaxRuns 5
    List the 5 most recent failed workflow runs.

.EXAMPLE
    ./automation-scripts/0530_Get-WorkflowRunReport.ps1 -WorkflowName "pr-validation" -Branch dev
    Get report for most recent pr-validation run on dev branch.

.NOTES
    Requires GITHUB_TOKEN environment variable for API access.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$RunId,

    [Parameter(Mandatory = $false)]
    [string]$WorkflowName,

    [Parameter(Mandatory = $false)]
    [ValidateSet('all', 'success', 'failure', 'cancelled', 'in_progress')]
    [string]$Status = 'all',

    [Parameter(Mandatory = $false)]
    [string]$Branch,

    [Parameter(Mandatory = $false)]
    [switch]$List,

    [Parameter(Mandatory = $false)]
    [int]$MaxRuns = 10,

    [Parameter(Mandatory = $false)]
    [ValidateSet('console', 'json', 'markdown')]
    [string]$OutputFormat = 'console',

    [Parameter(Mandatory = $false)]
    [string]$ExportPath
)

# Ensure we're in the repository root
$repoRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PSScriptRoot | Split-Path -Parent }
Set-Location $repoRoot

# Get GitHub token
$githubToken = $env:GITHUB_TOKEN
if (-not $githubToken) {
    Write-Error "GITHUB_TOKEN environment variable is required for API access."
    exit 1
}

# Detect repository from git remote
$gitRemote = git remote get-url origin 2>$null
if (-not $gitRemote) {
    Write-Error "Not in a git repository or no origin remote configured."
    exit 1
}

# Parse owner and repo from remote URL
if ($gitRemote -match 'github\.com[:/](.+)/(.+?)(\.git)?$') {
    $owner = $Matches[1]
    $repo = $Matches[2]
} else {
    Write-Error "Could not parse GitHub owner/repo from remote URL: $gitRemote"
    exit 1
}

Write-Verbose "Repository: $owner/$repo"

# GitHub API base URL
$apiBase = "https://api.github.com"
$headers = @{
    'Authorization' = "Bearer $githubToken"
    'Accept' = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

function Get-WorkflowRuns {
    param(
        [string]$WorkflowFilter,
        [string]$StatusFilter,
        [string]$BranchFilter,
        [int]$PerPage = 10
    )

    $uri = "$apiBase/repos/$owner/$repo/actions/runs?per_page=$PerPage"
    
    if ($WorkflowFilter) {
        # Get workflow ID from name
        $workflowsUri = "$apiBase/repos/$owner/$repo/actions/workflows"
        $workflows = Invoke-RestMethod -Uri $workflowsUri -Headers $headers -Method Get
        $workflow = $workflows.workflows | Where-Object { $_.name -eq $WorkflowFilter -or $_.path -like "*$WorkflowFilter*" } | Select-Object -First 1
        
        if ($workflow) {
            $uri += "&workflow_id=$($workflow.id)"
        }
    }

    if ($StatusFilter -and $StatusFilter -ne 'all') {
        $uri += "&status=$StatusFilter"
    }

    if ($BranchFilter) {
        $uri += "&branch=$BranchFilter"
    }

    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $response.workflow_runs
}

function Get-WorkflowRunDetails {
    param([string]$RunId)

    $runUri = "$apiBase/repos/$owner/$repo/actions/runs/$RunId"
    $run = Invoke-RestMethod -Uri $runUri -Headers $headers -Method Get

    $jobsUri = "$apiBase/repos/$owner/$repo/actions/runs/$RunId/jobs"
    $jobs = Invoke-RestMethod -Uri $jobsUri -Headers $headers -Method Get

    return @{
        Run = $run
        Jobs = $jobs.jobs
    }
}

function Format-ConsoleReport {
    param($Details)

    $run = $Details.Run
    $jobs = $Details.Jobs

    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "     WORKFLOW RUN REPORT" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

    Write-Host "Run ID:        " -NoNewline -ForegroundColor Yellow
    Write-Host $run.id

    Write-Host "Workflow:      " -NoNewline -ForegroundColor Yellow
    Write-Host $run.name

    Write-Host "Status:        " -NoNewline -ForegroundColor Yellow
    $statusColor = switch ($run.conclusion) {
        'success' { 'Green' }
        'failure' { 'Red' }
        'cancelled' { 'Yellow' }
        default { 'Gray' }
    }
    Write-Host $run.conclusion -ForegroundColor $statusColor

    Write-Host "Branch:        " -NoNewline -ForegroundColor Yellow
    Write-Host $run.head_branch

    Write-Host "Commit:        " -NoNewline -ForegroundColor Yellow
    Write-Host "$($run.head_sha.Substring(0,7)) - $($run.head_commit.message.Split("`n")[0])"

    Write-Host "Triggered by:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$($run.triggering_actor.login) ($($run.event))"

    Write-Host "Started:       " -NoNewline -ForegroundColor Yellow
    Write-Host $run.created_at

    Write-Host "Duration:      " -NoNewline -ForegroundColor Yellow
    $duration = [TimeSpan]::FromSeconds((New-TimeSpan -Start $run.created_at -End $run.updated_at).TotalSeconds)
    Write-Host "$([int]$duration.TotalMinutes)m $($duration.Seconds)s"

    Write-Host "`n───────────────────────────────────────────────────────────`n" -ForegroundColor Cyan
    Write-Host "JOBS ($($jobs.Count)):" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────────`n" -ForegroundColor Cyan

    foreach ($job in $jobs) {
        $jobStatusColor = switch ($job.conclusion) {
            'success' { 'Green' }
            'failure' { 'Red' }
            'cancelled' { 'Yellow' }
            'skipped' { 'Gray' }
            default { 'White' }
        }

        $jobIcon = switch ($job.conclusion) {
            'success' { '✓' }
            'failure' { '✗' }
            'cancelled' { '○' }
            'skipped' { '↷' }
            default { '•' }
        }

        Write-Host "  $jobIcon " -NoNewline -ForegroundColor $jobStatusColor
        Write-Host $job.name -NoNewline
        Write-Host " [$($job.conclusion)]" -ForegroundColor $jobStatusColor

        if ($job.conclusion -eq 'failure') {
            Write-Host "    Duration: " -NoNewline -ForegroundColor Gray
            $jobDuration = [TimeSpan]::FromSeconds((New-TimeSpan -Start $job.started_at -End $job.completed_at).TotalSeconds)
            Write-Host "$([int]$jobDuration.TotalMinutes)m $($jobDuration.Seconds)s" -ForegroundColor Gray

            # Get job steps
            foreach ($step in $job.steps | Where-Object { $_.conclusion -eq 'failure' }) {
                Write-Host "      ↳ Failed step: " -NoNewline -ForegroundColor Red
                Write-Host $step.name -ForegroundColor Red
            }
        }
        Write-Host ""
    }

    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}

function Format-JsonReport {
    param($Details)
    return $Details | ConvertTo-Json -Depth 10
}

function Format-MarkdownReport {
    param($Details)

    $run = $Details.Run
    $jobs = $Details.Jobs

    $md = @"
# Workflow Run Report

**Run ID:** $($run.id)  
**Workflow:** $($run.name)  
**Status:** $($run.conclusion)  
**Branch:** $($run.head_branch)  
**Commit:** ``$($run.head_sha.Substring(0,7))`` - $($run.head_commit.message.Split("`n")[0])  
**Triggered by:** $($run.triggering_actor.login) ($($run.event))  
**Started:** $($run.created_at)  

## Jobs

"@

    foreach ($job in $jobs) {
        $jobStatus = switch ($job.conclusion) {
            'success' { '✅' }
            'failure' { '❌' }
            'cancelled' { '⚠️' }
            'skipped' { '⏭️' }
            default { '•' }
        }

        $md += "`n### $jobStatus $($job.name) [$($job.conclusion)]`n"

        if ($job.conclusion -eq 'failure') {
            $md += "`n**Failed Steps:**`n"
            foreach ($step in $job.steps | Where-Object { $_.conclusion -eq 'failure' }) {
                $md += "- ❌ $($step.name)`n"
            }
        }
    }

    return $md
}

# Main execution
try {
    if ($List) {
        Write-Host "`n🔍 Fetching workflow runs..." -ForegroundColor Cyan
        $runs = Get-WorkflowRuns -WorkflowFilter $WorkflowName -StatusFilter $Status -BranchFilter $Branch -PerPage $MaxRuns

        if ($runs.Count -eq 0) {
            Write-Host "No workflow runs found matching the criteria." -ForegroundColor Yellow
            exit 0
        }

        Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "     RECENT WORKFLOW RUNS ($($runs.Count))" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

        foreach ($run in $runs) {
            $statusIcon = switch ($run.conclusion) {
                'success' { '✓' }
                'failure' { '✗' }
                'cancelled' { '○' }
                default { '•' }
            }

            $statusColor = switch ($run.conclusion) {
                'success' { 'Green' }
                'failure' { 'Red' }
                'cancelled' { 'Yellow' }
                default { 'Gray' }
            }

            Write-Host "$statusIcon " -NoNewline -ForegroundColor $statusColor
            Write-Host "$($run.id) - " -NoNewline
            Write-Host "$($run.name) " -NoNewline -ForegroundColor Yellow
            Write-Host "[$($run.conclusion)]" -NoNewline -ForegroundColor $statusColor
            Write-Host " ($($run.head_branch))" -ForegroundColor Gray
        }

        Write-Host "`n═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

    } else {
        # Get detailed report for specific run
        if (-not $RunId) {
            # Get most recent run
            Write-Host "🔍 No RunId specified, getting most recent run..." -ForegroundColor Yellow
            $runs = Get-WorkflowRuns -WorkflowFilter $WorkflowName -StatusFilter $Status -BranchFilter $Branch -PerPage 1
            if ($runs.Count -eq 0) {
                Write-Error "No workflow runs found."
                exit 1
            }
            $RunId = $runs[0].id
        }

        Write-Host "🔍 Fetching detailed report for run $RunId..." -ForegroundColor Cyan
        $details = Get-WorkflowRunDetails -RunId $RunId

        # Format and output report
        $report = switch ($OutputFormat) {
            'json' { Format-JsonReport -Details $details }
            'markdown' { Format-MarkdownReport -Details $details }
            default { Format-ConsoleReport -Details $details; $null }
        }

        # Export if path specified
        if ($ExportPath -and $report) {
            $report | Out-File -FilePath $ExportPath -Encoding UTF8
            Write-Host "✓ Report exported to: $ExportPath" -ForegroundColor Green
        } elseif ($report) {
            Write-Output $report
        }
    }

    Write-Host "✓ Report generation complete" -ForegroundColor Green
    exit 0

} catch {
    Write-Error "Failed to generate workflow run report: $_"
    Write-Error $_.Exception.Message
    exit 1
}
