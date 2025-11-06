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
    Output format: console, json, markdown, both (default: console).
    When 'both' is specified, generates both JSON and text files with names
    workflow-report-{RunId}.json and workflow-report-{RunId}.txt.

.PARAMETER ExportPath
    Path to export report to (optional).
    For OutputFormat='both', this specifies the directory where files are created.
    For other formats, this is the full file path including name.

.EXAMPLE
    ./automation-scripts/0531_Get-WorkflowRunReport.ps1 -RunId 12345678
    Get detailed report for specific workflow run.

.EXAMPLE
    ./automation-scripts/0531_Get-WorkflowRunReport.ps1 -List -Status failure -MaxRuns 5
    List the 5 most recent failed workflow runs.

.EXAMPLE
    ./automation-scripts/0531_Get-WorkflowRunReport.ps1 -WorkflowName "pr-validation" -Branch dev
    Get report for most recent pr-validation run on dev branch.

.NOTES
    GitHub token sources (in order of priority):
    1. GITHUB_TOKEN environment variable
    2. CI environment (GitHub Actions provides token automatically)
    3. config.psd1 file (Development.GitHub.Token)
    4. GitHub CLI authentication (gh auth login)
    5. Interactive prompt (non-CI mode only)
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
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [Alias('Limit')]
    [int]$MaxRuns = 10,

    [Parameter(Mandatory = $false)]
    [ValidateSet('console', 'json', 'markdown', 'both')]
    [string]$OutputFormat = 'console',

    [Parameter(Mandatory = $false)]
    [string]$ExportPath
)

# Ensure we're in the repository root
$repoRoot = if ($env:AITHERZERO_ROOT) { $env:AITHERZERO_ROOT } else { $PSScriptRoot | Split-Path -Parent }
Set-Location $repoRoot

# Detect CI environment
$isCI = $env:CI -eq 'true' -or 
        $env:GITHUB_ACTIONS -eq 'true' -or 
        $env:TF_BUILD -eq 'true' -or 
        $env:JENKINS_URL -or
        $env:GITLAB_CI -eq 'true'

# Function to get GitHub token from various sources
function Get-GitHubToken {
    param(
        [bool]$IsCI = $false
    )
    
    # 1. Try environment variable (primary source)
    if ($env:GITHUB_TOKEN) {
        Write-Verbose "Using GITHUB_TOKEN from environment variable"
        return $env:GITHUB_TOKEN
    }
    
    # 2. In CI mode, assume token will be available via GitHub Actions
    # Don't error - let API calls fail naturally if token is truly missing
    if ($IsCI) {
        Write-Verbose "CI mode: Assuming GitHub token available via Actions context"
        return $null  # Will be handled by GitHub CLI if available
    }
    
    # 3. Try to get from config file
    $configPath = Join-Path $repoRoot "config.psd1"
    if (Test-Path $configPath) {
        try {
            # Use scriptblock evaluation instead of Import-PowerShellDataFile
        # because config.psd1 contains PowerShell expressions ($true/$false) that
        # Import-PowerShellDataFile treats as "dynamic expressions"
        $configContent = Get-Content -Path $configPath -Raw
        $scriptBlock = [scriptblock]::Create($configContent)
        $config = & $scriptBlock
        if (-not $config -or $config -isnot [hashtable]) {
            throw "Config file did not return a valid hashtable"
        }
            if ($config.Development -and $config.Development.GitHub -and $config.Development.GitHub.Token) {
                Write-Verbose "Using GitHub token from config.psd1"
                return $config.Development.GitHub.Token
            }
        }
        catch {
            Write-Verbose "Could not load token from config: $_"
        }
    }
    
    # 4. Try gh CLI authentication status
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $ghStatus = gh auth status 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Verbose "Using GitHub CLI authentication"
                # gh CLI will handle auth automatically
                return $null
            }
        }
        catch {
            Write-Verbose "gh CLI not authenticated"
        }
    }
    
    # 5. In interactive mode, prompt for token
    if ([Environment]::UserInteractive -and -not $IsCI) {
        Write-Host "GitHub token not found. You can:" -ForegroundColor Yellow
        Write-Host "  1. Set GITHUB_TOKEN environment variable" -ForegroundColor Cyan
        Write-Host "  2. Add token to config.psd1 under Development.GitHub.Token" -ForegroundColor Cyan
        Write-Host "  3. Authenticate with: gh auth login" -ForegroundColor Cyan
        Write-Host "  4. Enter token now (input will be hidden)" -ForegroundColor Cyan
        Write-Host ""
        
        $secureToken = Read-Host "Enter GitHub token (or press Enter to skip)" -AsSecureString
        if ($secureToken.Length -gt 0) {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
            try {
                $token = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                if ($token) {
                    Write-Verbose "Using manually entered token"
                    return $token
                }
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }
        }
    }
    
    # 6. Return null and let the script try gh CLI or fail gracefully
    return $null
}

# Get GitHub token using smart detection
$githubToken = Get-GitHubToken -IsCI $isCI

# In non-CI mode without a token, provide helpful guidance
if (-not $githubToken -and -not $isCI) {
    Write-Warning "GitHub token not configured. API rate limits will be restrictive."
    Write-Warning "Configure token via: GITHUB_TOKEN env var, config.psd1, or 'gh auth login'"
    
    # Try to use gh CLI as fallback
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) not found and no token configured. Cannot proceed."
        Write-Host "Install gh: https://cli.github.com/" -ForegroundColor Cyan
        exit 1
    } else {
        Write-Verbose "Will attempt to use GitHub CLI for authentication"
    }
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

# Build headers - only include Authorization if token is available
$headers = @{
    'Accept' = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

if ($githubToken) {
    $headers['Authorization'] = "Bearer $githubToken"
    Write-Verbose "Using token-based authentication for GitHub API"
} else {
    Write-Verbose "No token available - API calls may have limited rate limits"
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

        # Handle "both" output format - generate both JSON and text files
        if ($OutputFormat -eq 'both') {
            # Determine base path - use ExportPath directory if specified, otherwise current directory
            $basePath = if ($ExportPath) {
                $directory = Split-Path $ExportPath -Parent
                if ([string]::IsNullOrEmpty($directory)) { 
                    Get-Location 
                } else { 
                    $directory 
                }
            } else {
                Get-Location
            }
            
            # Generate JSON report
            $jsonReport = Format-JsonReport -Details $details
            $jsonFileName = Join-Path $basePath "workflow-report-$RunId.json"
            $jsonReport | Out-File -FilePath $jsonFileName -Encoding UTF8
            Write-Host "✓ JSON report exported to: $jsonFileName" -ForegroundColor Green
            
            # Generate markdown/text report
            $mdReport = Format-MarkdownReport -Details $details
            $txtFileName = Join-Path $basePath "workflow-report-$RunId.txt"
            $mdReport | Out-File -FilePath $txtFileName -Encoding UTF8
            Write-Host "✓ Text report exported to: $txtFileName" -ForegroundColor Green
            
            # Also display console output for immediate feedback
            Format-ConsoleReport -Details $details
        }
        else {
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
    }

    Write-Host "✓ Report generation complete" -ForegroundColor Green
    exit 0

} catch {
    Write-Error "Failed to generate workflow run report: $_"
    Write-Error $_.Exception.Message
    exit 1
}
