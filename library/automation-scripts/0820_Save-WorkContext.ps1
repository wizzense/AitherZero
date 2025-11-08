#Requires -Version 7.0
<#
.SYNOPSIS
    Saves current work context for session continuation
.DESCRIPTION
    Captures complete work state including open files, git status, todos, and variables
    Creates a context file that can be used to resume work in a new session
.PARAMETER OutputPath
    Path to save the context file
.PARAMETER IncludeHistory
    Include command history in context
.PARAMETER CompressContext
    Compress context for token efficiency
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./.claude/session-context.json",

    [switch]$IncludeHistory,

    [switch]$CompressContext,

    [int]$HistoryCount = 50
)

# Script metadata
$scriptInfo = @{
    Stage = 'Development'
    Number = '0820'
    Name = 'Save-WorkContext'
    Description = 'Saves current work context for AI session continuation'
    Dependencies = @('git')
    Tags = @('session', 'context', 'ai', 'continuation')
    RequiresAdmin = $false
}

# Import required modules
$modulePath = Join-Path $PSScriptRoot ".." "Initialize-AitherModules.ps1"
if (Test-Path $modulePath) {
    . $modulePath
}

# Ensure output directory exists
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    if ($PSCmdlet.ShouldProcess($outputDir, 'Create Directory')) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
}

# Helper function to get git status
function Get-GitContext {
    $gitContext = @{
        Branch = & git branch --show-current 2>$null
        Status = & git status --short 2>$null
        LastCommit = & git log -1 --oneline 2>$null
        Remotes = & git remote -v 2>$null
        StashList = & git stash list 2>$null
        DiffSummary = & git diff --stat 2>$null
        StagedFiles = & git diff --cached --name-only 2>$null
        UntrackedFiles = & git ls-files --others --exclude-standard 2>$null
    }

    # Get recent commits
    $gitContext.RecentCommits = @(& git log --oneline -10 2>$null)

    # Get modified files with line counts
    $modifiedFiles = @{}
    $gitStatus = & git status --porcelain 2>$null
    foreach ($line in $gitStatus) {
        if ($line -match '^(..) (.+)$') {
            $status = $Matches[1].Trim()
            $file = $Matches[2]

            if (Test-Path $file) {
                if (Test-Path $file -PathType Leaf) {
                    $lineCount = (Get-Content $file | Measure-Object -Line).Lines
                } else {
                    $lineCount = 0
                }
                $modifiedFiles[$file] = @{
                    Status = $status
                    Lines = $lineCount
                }
            }
        }
    }
    $gitContext.ModifiedFiles = $modifiedFiles

    return $gitContext
}

# Helper function to get PowerShell context
function Get-PowerShellContext {
    $psContext = @{
        CurrentDirectory = Get-Location | Select-Object -ExpandProperty Path
        LoadedModules = @(Get-Module | Select-Object Name, Version, Path)
        EnvironmentVariables = @{}
        ErrorCount = $Error.Count
    }

    # Get relevant environment variables
    $relevantVars = @(
        'AITHERZERO_*',
        'PSModulePath',
        'PATH'
    )

    foreach ($pattern in $relevantVars) {
        Get-ChildItem env: | Where-Object Name -like $pattern | ForEach-Object {
            $psContext.EnvironmentVariables[$_.Name] = $_.Value
        }
    }

    # Get command history if requested
    if ($IncludeHistory) {
        $psContext.CommandHistory = @(Get-History -Count $HistoryCount | Select-Object CommandLine, StartExecutionTime, EndExecutionTime)
    }

    # Get recent errors
    if ($Error.Count -gt 0) {
        $psContext.RecentErrors = @($Error | Select-Object -First 5 | ForEach-Object {
            @{
                Message = $_.Exception.Message
                Category = $_.CategoryInfo.Category
                Target = $_.CategoryInfo.TargetName
                Script = $_.InvocationInfo.ScriptName
                Line = $_.InvocationInfo.ScriptLineNumber
            }
        })
    }

    return $psContext
}

# Helper function to get test context
function Get-TestContext {
    $testContext = @{
        LastTestRun = $null
        TestResults = $null
        Coverage = $null
        AnalyzerResults = $null
    }

    # Check for recent test results
    $testResultsPath = "./tests/results"
    if (Test-Path $testResultsPath) {
        $latestResults = Get-ChildItem $testResultsPath -Filter "*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestResults) {
            $testContext.LastTestRun = $latestResults.LastWriteTime
            try {
                $testContext.TestResults = Get-Content $latestResults.FullName | ConvertFrom-Json
            }
            catch {
                $testContext.TestResults = "Failed to parse test results"
            }
        }
    }

    # Check for PSScriptAnalyzer results
    $analyzerPath = "./tests/results/psscriptanalyzer-results.json"
    if (Test-Path $analyzerPath) {
        try {
            $analyzerData = Get-Content $analyzerPath | ConvertFrom-Json
            $testContext.AnalyzerResults = @{
                TotalIssues = $analyzerData.Count
                BySeverity = $analyzerData | Group-Object Severity | ForEach-Object {
                    @{ $_.Name = $_.Count }
                }
            }
        }
        catch {
            $testContext.AnalyzerResults = "Failed to parse analyzer results"
        }
    }

    return $testContext
}

# Helper function to get project context
function Get-ProjectContext {
    $projectContext = @{
        Version = if (Test-Path "./VERSION") { (Get-Content "./VERSION").Trim() } else { "Unknown" }
        LastModified = @{}
        TodoList = @()
        OpenIssues = @()
    }

    # Get recently modified files
    $recentFiles = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1', '.json', '.md' } |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 20

    foreach ($file in $recentFiles) {
        $relativePath = Resolve-Path $file.FullName -Relative
        $projectContext.LastModified[$relativePath] = $file.LastWriteTime
    }

    # Get TODO items from code
    $todoPattern = 'TODO:|FIXME:|HACK:|NOTE:'
    Get-ChildItem -Recurse -Include "*.ps1", "*.psm1" -ErrorAction SilentlyContinue | ForEach-Object {
        $file = $_
        $lineNum = 0
        Get-Content $file.FullName | ForEach-Object {
            $lineNum++
            if ($_ -match $todoPattern) {
                $projectContext.TodoList += @{
                    File = Resolve-Path $file.FullName -Relative
                    Line = $lineNum
                    Text = $_.Trim()
                }
            }
        }
    }

    # Get open GitHub issues if gh CLI is available
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        try {
            $issues = & gh issue list --limit 10 --json number,title,state,labels 2>$null | ConvertFrom-Json
            $projectContext.OpenIssues = $issues
        }
        catch {
            # Ignore if not in a GitHub repo
        }
    }

    return $projectContext
}

# Helper function to compress context
function Compress-Context {
    param([hashtable]$Context)

    # Remove verbose/redundant information
    if ($Context.Git.DiffSummary -and $Context.Git.DiffSummary.Count -gt 20) {
        $Context.Git.DiffSummary = $Context.Git.DiffSummary | Select-Object -First 20
        $Context.Git.DiffSummaryTruncated = $true
    }

    if ($Context.PowerShell.CommandHistory -and $Context.PowerShell.CommandHistory.Count -gt 20) {
        $Context.PowerShell.CommandHistory = $Context.PowerShell.CommandHistory | Select-Object -Last 20
        $Context.PowerShell.CommandHistoryTruncated = $true
    }

    if ($Context.Project.TodoList.Count -gt 10) {
        $Context.Project.TodoList = $Context.Project.TodoList | Select-Object -First 10
        $Context.Project.TodoListTruncated = $true
    }

    return $Context
}

# Main execution
try {
    Write-Host "📸 Capturing work context..." -ForegroundColor Cyan

    $context = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        SessionId = [guid]::NewGuid().ToString()
        Machine = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { $env:HOSTNAME }
        User = if ($IsWindows) { [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } else { $env:USER }
        Platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
    }

    Write-Host "  Getting Git context..." -ForegroundColor Gray
    $context.Git = Get-GitContext

    Write-Host "  Getting PowerShell context..." -ForegroundColor Gray
    $context.PowerShell = Get-PowerShellContext

    Write-Host "  Getting test context..." -ForegroundColor Gray
    $context.Test = Get-TestContext

    Write-Host "  Getting project context..." -ForegroundColor Gray
    $context.Project = Get-ProjectContext

    if ($CompressContext) {
        Write-Host "  Compressing context..." -ForegroundColor Gray
        $context = Compress-Context -Context $context
    }

    # Save context to file
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Save Context File')) {
        $context | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
    }

    # Calculate context size
    $contextSize = (Get-Item $OutputPath).Length
    $contextSizeKB = [math]::Round($contextSize / 1KB, 2)

    Write-Host "✅ Work context saved successfully!" -ForegroundColor Green
    Write-Host "   File: $OutputPath" -ForegroundColor Gray
    Write-Host "   Size: $contextSizeKB KB" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📋 Context Summary:" -ForegroundColor Cyan
    Write-Host "   Git Branch: $($context.Git.Branch)" -ForegroundColor Gray
    Write-Host "   Modified Files: $($context.Git.ModifiedFiles.Count)" -ForegroundColor Gray
    Write-Host "   Loaded Modules: $($context.PowerShell.LoadedModules.Count)" -ForegroundColor Gray
    Write-Host "   TODO Items: $($context.Project.TodoList.Count)" -ForegroundColor Gray
    Write-Host "   Open Issues: $($context.Project.OpenIssues.Count)" -ForegroundColor Gray

    if ($IncludeHistory) {
        Write-Host "   Command History: $($context.PowerShell.CommandHistory.Count) commands" -ForegroundColor Gray
    }

    # Also create a markdown version for easy reading
    $mdPath = $OutputPath -replace '\.json$', '.md'
    $mdContent = @(
        "# AitherZero Work Context"
        ""
        "Generated: $($context.Timestamp)"
        "Session ID: $($context.SessionId)"
        ""
        "## Git Status"
        "- **Branch:** $($context.Git.Branch)"
        "- **Last Commit:** $($context.Git.LastCommit)"
        "- **Modified Files:** $($context.Git.ModifiedFiles.Count)"
        ""
        "### Changed Files:"
        foreach ($file in $context.Git.ModifiedFiles.Keys) {
            "- $file ($($context.Git.ModifiedFiles[$file].Status))"
        }
        ""
        "## Current Work"
        if ($context.Project.TodoList.Count -gt 0) {
            "### TODO Items:"
            foreach ($todo in $context.Project.TodoList | Select-Object -First 5) {
                "- $($todo.File):$($todo.Line) - $($todo.Text)"
            }
        }
        ""
        "## Test Status"
        if ($context.Test.LastTestRun) {
            "Last Test Run: $($context.Test.LastTestRun)"
        }
        if ($context.Test.AnalyzerResults) {
            "PSScriptAnalyzer Issues: $($context.Test.AnalyzerResults.TotalIssues)"
        }
    )

    if ($PSCmdlet.ShouldProcess($mdPath, 'Save Markdown File')) {
        $mdContent -join "`n" | Set-Content $mdPath -Encoding UTF8
    }
    Write-Host "   Markdown version: $mdPath" -ForegroundColor Gray

    exit 0
}
catch {
    Write-Error "Failed to save work context: $_"
    exit 1
}