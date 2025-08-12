#Requires -Version 7.0

<#
.SYNOPSIS
    Display comprehensive project dashboard with logs, tests, and metrics
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [switch]$ShowLogs,
    [switch]$ShowTests,
    [switch]$ShowMetrics,
    [switch]$ShowAll,
    [int]$LogTailLines = 50,
    [switch]$Follow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import modules
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

# Clear screen for dashboard
Clear-Host

function Show-Header {
    $width = $Host.UI.RawUI.WindowSize.Width
    $line = "=" * $width
    
    Write-Host $line -ForegroundColor Cyan
    Write-Host " AitherZero Project Dashboard " -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Show-ProjectMetrics {
    Write-Host "PROJECT METRICS" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Gray

    # Get latest report
    $reportPath = Join-Path $ProjectPath "tests/reports"
    $latestReport = Get-ChildItem -Path $reportPath -Filter "ProjectReport-*.json" -ErrorAction SilentlyContinue | 
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($latestReport) {
        $report = Get-Content $latestReport.FullName | ConvertFrom-Json
        
        Write-Host "Total Files: " -NoNewline
        Write-Host "$($report.FileAnalysis.TotalFiles)" -ForegroundColor Green
        
        Write-Host "Code Files: " -NoNewline
        Write-Host "$($report.Coverage.TotalFiles)" -ForegroundColor Green
        
        Write-Host "Functions: " -NoNewline
        Write-Host "$($report.Coverage.FunctionCount)" -ForegroundColor Green
        
        Write-Host "Lines of Code: " -NoNewline
        Write-Host "$($report.Coverage.CodeLines)" -ForegroundColor Green
        
        Write-Host "Comment Ratio: " -NoNewline
        $commentColor = if ($report.Coverage.CommentRatio -ge 20) { "Green" } elseif ($report.Coverage.CommentRatio -ge 10) { "Yellow" } else { "Red" }
        Write-Host "$($report.Coverage.CommentRatio)%" -ForegroundColor $commentColor
        
        Write-Host "Documentation: " -NoNewline
        $docColor = if ($report.Documentation.HelpCoverage -ge 80) { "Green" } elseif ($report.Documentation.HelpCoverage -ge 50) { "Yellow" } else { "Red" }
        Write-Host "$($report.Documentation.HelpCoverage)%" -ForegroundColor $docColor
    } else {
        Write-Host "No project report found. Run 0510_Generate-ProjectReport.ps1" -ForegroundColor Red
    }
    Write-Host ""
}

function Show-TestResults {
    Write-Host "TEST RESULTS" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Gray
    
    $testResultsPath = Join-Path $ProjectPath "tests/results"
    $testSummaries = Get-ChildItem -Path $testResultsPath -Filter "*Summary*.json" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 5

    if ($testSummaries) {
        foreach ($summary in $testSummaries) {
            $data = Get-Content $summary.FullName | ConvertFrom-Json
            $timestamp = $summary.BaseName -replace '.*-(\d{8}-\d{6}).*', '$1'
            
            Write-Host "[$timestamp] " -NoNewline -ForegroundColor Gray

            if ($data.Failed -gt 0) {
                Write-Host "FAILED" -ForegroundColor Red -NoNewline
            } else {
                Write-Host "PASSED" -ForegroundColor Green -NoNewline
            }
            
            Write-Host " - Total: $($data.TotalTests), Passed: $($data.Passed), Failed: $($data.Failed)"
        }
    } else {
        Write-Host "No test results found" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-RecentLogs {
    param([int]$Lines = 20)
    
    Write-Host "RECENT LOGS" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Gray
    
    $logPath = Join-Path $ProjectPath "logs/aitherzero.log"

    if (Test-Path $logPath) {
        $logs = Get-Content $logPath -Tail $Lines -ErrorAction SilentlyContinue
        foreach ($log in $logs) {
            if ($log -match '\[ERROR') {
                Write-Host $log -ForegroundColor Red
            } elseif ($log -match '\[WARNING') {
                Write-Host $log -ForegroundColor Yellow
            } elseif ($log -match '\[DEBUG') {
                Write-Host $log -ForegroundColor Gray
            } else {
                Write-Host $log
            }
        }
    } else {
        Write-Host "Log file not found at: $logPath" -ForegroundColor Yellow
        Write-Host "Creating log file..." -ForegroundColor Gray
        
        # Initialize logging to create the file
        if (Get-Command Initialize-Logging -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess("logging system", "Initialize logging")) {
                Initialize-Logging
                Write-CustomLog -Message "Dashboard initialized logging system" -Level Information
            }
        }
    }
    Write-Host ""
}

function Show-ModuleStatus {
    Write-Host "MODULE STATUS" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Gray
    
    $domains = Get-ChildItem -Path (Join-Path $ProjectPath "domains") -Directory -ErrorAction SilentlyContinue
    
    foreach ($domain in $domains) {
        $modules = Get-ChildItem -Path $domain.FullName -Filter "*.psm1" -ErrorAction SilentlyContinue
        $hasReadme = Test-Path (Join-Path $domain.FullName "README.md")
        
        Write-Host "$($domain.Name): " -NoNewline
        Write-Host "$(@($modules).Count) modules" -ForegroundColor Green -NoNewline
        
        if ($hasReadme) {
            Write-Host " ✓" -ForegroundColor Green -NoNewline
        } else {
            Write-Host " (no README)" -ForegroundColor Yellow -NoNewline
        }
        Write-Host ""
    }
    Write-Host ""
}

function Show-RecentActivity {
    Write-Host "RECENT ACTIVITY" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Gray

    # Get recent git commits
    $gitLog = git log --oneline -5 2>/dev/null
    if ($gitLog) {
        Write-Host "Recent Commits:" -ForegroundColor Cyan
        $gitLog | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }

    # Get recently modified files
    Write-Host "`nRecently Modified:" -ForegroundColor Cyan
    $recentFiles = Get-ChildItem -Path $ProjectPath -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) -and $_.FullName -notlike "*\.git\*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 5
    
    foreach ($file in $recentFiles) {
        $relativePath = $file.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
        $timeAgo = [math]::Round(((Get-Date) - $file.LastWriteTime).TotalMinutes)
        Write-Host "  $relativePath ($timeAgo min ago)" -ForegroundColor Gray
    }
    Write-Host ""
}

# Main Dashboard Display
Show-Header

if ($ShowAll -or (!$ShowLogs -and !$ShowTests -and !$ShowMetrics)) {
    # Show everything by default
    $ShowMetrics = $true
    $ShowTests = $true
    $ShowLogs = $true
}

$col1Width = 60
$col2Width = $Host.UI.RawUI.WindowSize.Width - $col1Width - 2

# Two column layout
$cursorPos = $Host.UI.RawUI.CursorPosition

if ($ShowMetrics) {
    Show-ProjectMetrics
    Show-ModuleStatus
}

if ($ShowTests) {
    Show-TestResults
}

if ($ShowLogs) {
    Show-RecentLogs -Lines $LogTailLines
}

Show-RecentActivity

# Footer
Write-Host ("=" * $Host.UI.RawUI.WindowSize.Width) -ForegroundColor Cyan
Write-Host "Commands: " -NoNewline -ForegroundColor Yellow
Write-Host "0510 " -NoNewline -ForegroundColor Cyan
Write-Host "(Generate Report) | " -NoNewline
Write-Host "0402 " -NoNewline -ForegroundColor Cyan
Write-Host "(Run Tests) | " -NoNewline
Write-Host "0404 " -NoNewline -ForegroundColor Cyan
Write-Host "(Analyze Code)" -NoNewline
Write-Host ""

if ($Follow) {
    Write-Host "Following logs... Press Ctrl+C to exit" -ForegroundColor Yellow
    $logPath = Join-Path $ProjectPath "logs/aitherzero.log"
    if (Test-Path $logPath) {
        Get-Content $logPath -Wait -Tail 1
    }
}