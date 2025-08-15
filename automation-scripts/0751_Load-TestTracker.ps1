#Requires -Version 7.0

<#
.SYNOPSIS
    Load or create test failure tracker file
.DESCRIPTION
    Manages a persistent JSON tracker file that tracks test failures, fix attempts,
    and GitHub issue associations for automated bug fixing workflows.
    
    Exit Codes:
    0   - Tracker loaded/created successfully
    1   - Error loading/creating tracker
    
.NOTES
    Stage: Testing
    Order: 0751
    Dependencies: None
    Tags: testing, tracking, automation, github
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TrackerPath = './test-fix-tracker.json',
    [string]$BranchPrefix = 'fix/auto-test-fixes',
    [string]$TestResultsPath = './tests/reports',
    [int]$TestResultsMaxAgeHours = 24,
    [switch]$CreateBranch,
    [switch]$Reset,
    [switch]$CheckTestResults,  # Check if test results need updating
    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Testing'
    Order = 0751
    Dependencies = @()
    Tags = @('testing', 'tracking', 'automation', 'github')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = @{
        'Error' = 'Red'
        'Warning' = 'Yellow'
        'Information' = 'White'
        'Debug' = 'Gray'
    }[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

try {
    Write-ScriptLog -Message "Loading test tracker from: $TrackerPath"
    
    if ($Reset -and (Test-Path $TrackerPath)) {
        Write-ScriptLog -Level Warning -Message "Resetting tracker file"
        if ($PSCmdlet.ShouldProcess($TrackerPath, "Reset tracker file")) {
            Remove-Item $TrackerPath -Force
        }
    }
    
    # Check for recent test results if requested
    $needNewTests = $false
    if ($CheckTestResults) {
        Write-ScriptLog -Message "Checking test results age..."
        
        # Look for most recent test results
        $latestResults = Get-ChildItem "$TestResultsPath/TestReport-*.json" -ErrorAction SilentlyContinue | 
            Sort-Object LastWriteTime -Descending | 
            Select-Object -First 1
        
        if ($latestResults) {
            $resultAge = (Get-Date) - $latestResults.LastWriteTime
            if ($resultAge.TotalHours -gt $TestResultsMaxAgeHours) {
                Write-ScriptLog -Level Warning -Message "Test results are $([int]$resultAge.TotalHours) hours old (max: $TestResultsMaxAgeHours)"
                $needNewTests = $true
            } else {
                Write-ScriptLog -Message "Found recent test results: $($latestResults.Name) (age: $([int]$resultAge.TotalHours) hours)"
            }
        } else {
            Write-ScriptLog -Level Warning -Message "No test results found in $TestResultsPath"
            $needNewTests = $true
        }
        
        if ($needNewTests) {
            Write-ScriptLog -Message "Running tests to get fresh results..."
            $testScript = Join-Path (Split-Path $PSScriptRoot -Parent) "automation-scripts/0402_Run-UnitTests.ps1"
            if (Test-Path $testScript) {
                & $testScript
                Start-Sleep -Seconds 2  # Wait for results to be written
            }
        }
    }
    
    $tracker = if (Test-Path $TrackerPath) {
        Write-ScriptLog -Message "Loading existing tracker"
        $content = Get-Content $TrackerPath -Raw | ConvertFrom-Json
        
        # Convert to hashtable for easier manipulation
        $trackerData = @{
            lastProcessedResults = $content.lastProcessedResults
            currentBranch = $content.currentBranch
            issues = @($content.issues)
            createdAt = $content.createdAt
            updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            lastTestRun = if ($content.lastTestRun) { $content.lastTestRun } else { $null }
            currentIssueIndex = if ($content.currentIssueIndex) { $content.currentIssueIndex } else { 0 }
        }
        
        # Check if we should select the next issue
        if ($trackerData.issues.Count -gt 0) {
            $openIssues = @($trackerData.issues | Where-Object { $_.status -eq 'open' })
            if ($openIssues.Count -gt 0) {
                # Find the next issue that hasn't been attempted recently
                $nextIssue = $null
                for ($i = $trackerData.currentIssueIndex; $i -lt $trackerData.issues.Count; $i++) {
                    $issue = $trackerData.issues[$i]
                    if ($issue.status -eq 'open' -and $issue.attempts -lt 3) {
                        $nextIssue = $issue
                        $trackerData.currentIssueIndex = $i + 1
                        break
                    }
                }
                
                # Wrap around if needed
                if (-not $nextIssue -and $trackerData.currentIssueIndex -gt 0) {
                    for ($i = 0; $i -lt $trackerData.currentIssueIndex; $i++) {
                        $issue = $trackerData.issues[$i]
                        if ($issue.status -eq 'open' -and $issue.attempts -lt 3) {
                            $nextIssue = $issue
                            $trackerData.currentIssueIndex = $i + 1
                            break
                        }
                    }
                }
                
                if ($nextIssue) {
                    Write-ScriptLog -Message "Next issue to process: $($nextIssue.id) - $($nextIssue.testName)"
                }
            }
        }
        
        $trackerData
    } else {
        Write-ScriptLog -Message "Creating new tracker"
        $branchDate = Get-Date -Format 'yyyyMMdd-HHmmss'
        $branchName = "$BranchPrefix-$branchDate"
        
        @{
            lastProcessedResults = $null
            currentBranch = $branchName
            issues = @()
            createdAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            updatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            lastTestRun = $null
            currentIssueIndex = 0
        }
    }
    
    # Create branch if requested and we have a branch name
    if ($CreateBranch -and $tracker.currentBranch -and -not $Reset) {
        $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
        
        if ($currentBranch -ne $tracker.currentBranch) {
            Write-ScriptLog -Message "Creating branch: $($tracker.currentBranch)"
            
            if ($PSCmdlet.ShouldProcess($tracker.currentBranch, "Create and checkout branch")) {
                # Check if branch exists
                $branchExists = git show-ref --verify --quiet "refs/heads/$($tracker.currentBranch)" 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ScriptLog -Message "Branch already exists, checking out"
                    git checkout $tracker.currentBranch 2>&1 | Out-Null
                } else {
                    Write-ScriptLog -Message "Creating new branch"
                    git checkout -b $tracker.currentBranch 2>&1 | Out-Null
                }
                
                if ($LASTEXITCODE -ne 0) {
                    Write-ScriptLog -Level Warning -Message "Failed to create/checkout branch"
                }
            }
        }
    }
    
    # Save tracker
    if ($PSCmdlet.ShouldProcess($TrackerPath, "Save tracker file")) {
        $tracker | ConvertTo-Json -Depth 10 | Set-Content $TrackerPath
        Write-ScriptLog -Message "Tracker saved to: $TrackerPath"
    }
    
    # Display summary
    Write-Host "`n📋 Tracker Summary:" -ForegroundColor Cyan
    Write-Host "  Branch: $($tracker.currentBranch)" -ForegroundColor Gray
    Write-Host "  Issues: $($tracker.issues.Count)" -ForegroundColor Gray
    Write-Host "  Last Results: $($tracker.lastProcessedResults ?? 'None')" -ForegroundColor Gray
    Write-Host "  Last Test Run: $($tracker.lastTestRun ?? 'Never')" -ForegroundColor Gray
    Write-Host "  Current Index: $($tracker.currentIssueIndex)" -ForegroundColor Gray
    Write-Host "  Updated: $($tracker.updatedAt)" -ForegroundColor Gray
    
    if ($tracker.issues.Count -gt 0) {
        $open = @($tracker.issues | Where-Object { $_.status -eq 'open' }).Count
        $resolved = @($tracker.issues | Where-Object { $_.status -eq 'resolved' }).Count
        $failed = @($tracker.issues | Where-Object { $_.status -eq 'failed' }).Count
        
        Write-Host "`n  Status Breakdown:" -ForegroundColor Cyan
        Write-Host "    Open: $open" -ForegroundColor Yellow
        Write-Host "    Resolved: $resolved" -ForegroundColor Green
        Write-Host "    Failed: $failed" -ForegroundColor Red
    }
    
    if ($PassThru) {
        return $tracker
    }
    
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Failed to load/create tracker: $_"
    exit 1
}