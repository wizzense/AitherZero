#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive CI/CD dashboard with real-time status monitoring
.DESCRIPTION
    Creates HTML and Markdown dashboards showing project health, test results,
    security status, CI/CD metrics, and deployment information for effective
    project management and systematic improvement.
    
    Use the -Open parameter to automatically open the HTML dashboard in your 
    default browser after generation.

    Exit Codes:
    0   - Dashboard generated successfully
    1   - Generation failed
    2   - Configuration error

.PARAMETER Open
    Automatically open the HTML dashboard in the default browser after generation

.EXAMPLE
    ./0512_Generate-Dashboard.ps1
    Generate all dashboard formats (HTML, Markdown, JSON)

.EXAMPLE
    ./0512_Generate-Dashboard.ps1 -Format HTML -Open
    Generate HTML dashboard and open it in the browser

.NOTES
    Stage: Reporting
    Order: 0512
    Dependencies: 0510
    Tags: reporting, dashboard, monitoring, html, markdown
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$OutputPath = (Join-Path $ProjectPath "reports"),
    [ValidateSet('HTML', 'Markdown', 'JSON', 'All')]
    [string]$Format = 'All',
    [switch]$IncludeMetrics,
    [switch]$IncludeTrends,
    [switch]$RefreshData,
    [string]$ThemeColor = '#667eea',
    [switch]$Open
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Reporting'
    Order = 0512
    Dependencies = @('0510')
    Tags = @('reporting', 'dashboard', 'monitoring')
    RequiresAdmin = $false
    SupportsWhatIf = $true
}

# Import modules
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
$configModule = Join-Path $ProjectPath "domains/configuration/Configuration.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

if (Test-Path $configModule) {
    Import-Module $configModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0512_Generate-Dashboard" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function Open-HTMLDashboard {
    param(
        [string]$FilePath
    )
    
    Write-ScriptLog -Message "Opening HTML dashboard in browser: $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-ScriptLog -Level Warning -Message "Dashboard file not found: $FilePath"
        return $false
    }
    
    try {
        # Cross-platform browser opening
        if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
            # Windows - use Start-Process with default browser
            Start-Process $FilePath
        }
        elseif ($IsMacOS) {
            # macOS - use open command
            & open $FilePath
        }
        elseif ($IsLinux) {
            # Linux - try xdg-open
            if (Get-Command xdg-open -ErrorAction SilentlyContinue) {
                & xdg-open $FilePath
            }
            else {
                Write-ScriptLog -Level Warning -Message "xdg-open not found. Please open manually: $FilePath"
                return $false
            }
        }
        else {
            Write-ScriptLog -Level Warning -Message "Unable to detect platform. Please open manually: $FilePath"
            return $false
        }
        
        Write-ScriptLog -Message "Dashboard opened successfully in default browser"
        return $true
    }
    catch {
        Write-ScriptLog -Level Error -Message "Failed to open dashboard: $_"
        return $false
    }
}

function Get-ProjectMetrics {
    Write-ScriptLog -Message "Collecting project metrics"

    $metrics = @{
        Files = @{
            PowerShell = @(Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notmatch '(tests|examples|legacy)' }).Count
            Modules = @(Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse).Count
            Data = @(Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse).Count
            Markdown = @(Get-ChildItem -Path $ProjectPath -Filter "*.md" -Recurse | Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }).Count
            YAML = @(Get-ChildItem -Path $ProjectPath -Filter "*.yml" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }).Count
            JSON = @(Get-ChildItem -Path $ProjectPath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }).Count
            Total = 0
        }
        LinesOfCode = 0
        CommentLines = 0
        BlankLines = 0
        Functions = 0
        Classes = 0
        Tests = @{
            Unit = 0
            Integration = 0
            Total = 0
            LastRun = $null
            Passed = 0
            Failed = 0
            Skipped = 0
            SuccessRate = 0
            Duration = "Unknown"
        }
        Coverage = @{
            Percentage = 0
            CoveredLines = 0
            TotalLines = 0
        }
        Git = @{
            Branch = "Unknown"
            LastCommit = "Unknown"
            CommitCount = 0
            Contributors = 0
        }
        Dependencies = @{}
        Platform = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { "Windows" }
        PSVersion = $PSVersionTable.PSVersion.ToString()
        LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Domains = @()
        AutomationScripts = 0
        Workflows = 0
    }

    # Calculate total files
    $metrics.Files.Total = $metrics.Files.PowerShell + $metrics.Files.Modules + $metrics.Files.Data

    # Count lines of code and functions
    $allPSFiles = @(
        Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse
    ) | Where-Object { $_.FullName -notmatch '(tests|examples|legacy)' }

    foreach ($file in $allPSFiles) {
        try {
            $content = Get-Content $file.FullName -ErrorAction Stop
            if ($content) {
                foreach ($line in $content) {
                    $trimmed = $line.Trim()
                    if ($trimmed -eq '') {
                        $metrics.BlankLines++
                    } elseif ($trimmed -match '^#' -or $trimmed -match '^\s*<#') {
                        $metrics.CommentLines++
                    }
                }
                
                $metrics.LinesOfCode += $content.Count

                # Count functions - improved pattern matching
                $functionMatches = $content | Select-String -Pattern '^\s*function\s+' -ErrorAction SilentlyContinue
                if ($functionMatches) {
                    $metrics.Functions += $functionMatches.Count
                }
                
                # Count classes
                $classMatches = $content | Select-String -Pattern '^\s*class\s+' -ErrorAction SilentlyContinue
                if ($classMatches) {
                    $metrics.Classes += $classMatches.Count
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse file for metrics: $($file.Name) - $_"
        }
    }
    
    # Get Git information
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $metrics.Git.Branch = git rev-parse --abbrev-ref HEAD 2>$null
            $metrics.Git.LastCommit = (git log -1 --format="%h - %s (%cr)" 2>$null)
            $metrics.Git.CommitCount = [int](git rev-list --count HEAD 2>$null)
            $metrics.Git.Contributors = @(git log --format='%an' | Sort-Object -Unique).Count
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to get git information"
        }
    }
    
    # Count GitHub Actions workflows
    $workflowsPath = Join-Path $ProjectPath ".github/workflows"
    if (Test-Path $workflowsPath) {
        $metrics.Workflows = @(Get-ChildItem -Path $workflowsPath -Filter "*.yml" -ErrorAction SilentlyContinue).Count
    }

    # Count automation scripts
    $automationPath = Join-Path $ProjectPath "automation-scripts"
    if (Test-Path $automationPath) {
        $metrics.AutomationScripts = @(Get-ChildItem -Path $automationPath -Filter "*.ps1").Count
    }

    # Count domain modules
    $domainsPath = Join-Path $ProjectPath "domains"
    if (Test-Path $domainsPath) {
        $domainDirs = Get-ChildItem -Path $domainsPath -Directory
        foreach ($domain in $domainDirs) {
            $moduleCount = @(Get-ChildItem -Path $domain.FullName -Filter "*.psm1").Count
            if ($moduleCount -gt 0) {
                $metrics.Domains += @{
                    Name = $domain.Name
                    Modules = $moduleCount
                    Path = $domain.FullName
                }
            }
        }
    }

    # Count test files
    $testPath = Join-Path $ProjectPath "tests"
    if (Test-Path $testPath) {
        $metrics.Tests.Unit = @(Get-ChildItem -Path $testPath -Filter "*Tests.ps1" -Recurse | Where-Object { $_.FullName -match 'unit' }).Count
        $metrics.Tests.Integration = @(Get-ChildItem -Path $testPath -Filter "*Tests.ps1" -Recurse | Where-Object { $_.FullName -match 'integration' }).Count
        $metrics.Tests.Total = $metrics.Tests.Unit + $metrics.Tests.Integration
    }

    # Get latest test results - check multiple possible locations
    $testResultsPaths = @(
        (Join-Path $ProjectPath "testResults.xml"),
        (Join-Path $ProjectPath "tests/results/*.xml")
    )
    
    $latestTestResults = $null
    foreach ($testPath in $testResultsPaths) {
        if ($testPath -like "*`**") {
            $latestTestResults = Get-ChildItem -Path (Split-Path $testPath -Parent) -Filter (Split-Path $testPath -Leaf) -ErrorAction SilentlyContinue | 
                               Where-Object { $_.Name -notlike "Coverage*" } |
                               Sort-Object LastWriteTime -Descending | 
                               Select-Object -First 1
        } else {
            if (Test-Path $testPath) {
                $latestTestResults = Get-Item $testPath
            }
        }
        if ($latestTestResults) { break }
    }
    
    if ($latestTestResults) {
        try {
            [xml]$testXml = Get-Content $latestTestResults.FullName
            
            # Parse NUnit format test results
            if ($testXml.'test-results') {
                $results = $testXml.'test-results'
                $totalTests = [int]$results.total
                $failures = [int]$results.failures
                $errors = [int]$results.errors
                $skipped = [int]$results.skipped
                
                $metrics.Tests.Passed = $totalTests - $failures - $errors - $skipped
                $metrics.Tests.Failed = $failures + $errors
                $metrics.Tests.Skipped = $skipped
                
                if ($totalTests -gt 0) {
                    $metrics.Tests.SuccessRate = [math]::Round(($metrics.Tests.Passed / $totalTests) * 100, 1)
                }
                
                $metrics.Tests.LastRun = $latestTestResults.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                
                # Try to extract duration from test suite
                if ($testXml.'test-results'.'test-suite' -and $testXml.'test-results'.'test-suite'.time) {
                    try {
                        $duration = [double]$testXml.'test-results'.'test-suite'.time
                        if ($duration -lt 60) {
                            $metrics.Tests.Duration = "$([math]::Round($duration, 2))s"
                        } else {
                            $minutes = [math]::Floor($duration / 60)
                            $seconds = [math]::Round($duration % 60, 0)
                            $metrics.Tests.Duration = "${minutes}m ${seconds}s"
                        }
                    } catch {
                        $metrics.Tests.Duration = "Unknown"
                    }
                } else {
                    $metrics.Tests.Duration = "Unknown"
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse test results: $_"
        }
    }

    # Get coverage information if available
    $coverageFiles = Get-ChildItem -Path $ProjectPath -Filter "Coverage-*.xml" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($coverageFiles) {
        try {
            [xml]$coverageXml = Get-Content $coverageFiles.FullName
            $coverage = $coverageXml.coverage
            if ($coverage) {
                $metrics.Coverage.Percentage = [math]::Round(($coverage.'line-rate' -as [double]) * 100, 2)
                $metrics.Coverage.CoveredLines = $coverage.'lines-covered' -as [int]
                $metrics.Coverage.TotalLines = $coverage.'lines-valid' -as [int]
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse coverage data"
        }
    }

    return $metrics
}

function Get-QualityMetrics {
    <#
    .SYNOPSIS
        Collect code quality validation metrics from recent reports
    .DESCRIPTION
        Aggregates quality validation data including scores, checks, and trends
    #>
    Write-ScriptLog -Message "Collecting quality validation metrics"
    
    $qualityMetrics = @{
        OverallScore = 0
        AverageScore = 0
        TotalFiles = 0
        PassedFiles = 0
        FailedFiles = 0
        WarningFiles = 0
        Checks = @{
            ErrorHandling = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            Logging = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            TestCoverage = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            PSScriptAnalyzer = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            UIIntegration = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            GitHubActions = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
        }
        RecentReports = @()
        LastValidation = $null
        Trends = @{
            ScoreHistory = @()
            PassRateHistory = @()
        }
    }
    
    # Find quality reports
    $qualityReportsPath = Join-Path $ProjectPath "reports/quality"
    if (-not (Test-Path $qualityReportsPath)) {
        Write-ScriptLog -Level Warning -Message "Quality reports directory not found: $qualityReportsPath"
        return $qualityMetrics
    }
    
    # Get recent summary files
    $summaryFiles = @(Get-ChildItem -Path $qualityReportsPath -Filter "*-summary.json" -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 10)
    
    if ($summaryFiles.Count -eq 0) {
        Write-ScriptLog -Level Warning -Message "No quality summary reports found"
        return $qualityMetrics
    }
    
    # Process most recent summary
    try {
        $latestSummary = Get-Content $summaryFiles[0].FullName | ConvertFrom-Json
        $qualityMetrics.AverageScore = $latestSummary.AverageScore ?? 0
        $qualityMetrics.TotalFiles = $latestSummary.FilesValidated ?? 0
        $qualityMetrics.PassedFiles = $latestSummary.Passed ?? 0
        $qualityMetrics.FailedFiles = $latestSummary.Failed ?? 0
        $qualityMetrics.WarningFiles = $latestSummary.Warnings ?? 0
        $qualityMetrics.LastValidation = $latestSummary.Timestamp
        
        # Calculate overall score
        if ($qualityMetrics.TotalFiles -gt 0) {
            $qualityMetrics.OverallScore = [math]::Round(
                (($qualityMetrics.PassedFiles * 100) + ($qualityMetrics.WarningFiles * 70)) / $qualityMetrics.TotalFiles, 
                1
            )
        }
    } catch {
        Write-ScriptLog -Level Warning -Message "Failed to parse latest quality summary: $_"
    }
    
    # Collect detailed check statistics from individual reports
    $detailedReports = Get-ChildItem -Path $qualityReportsPath -Filter "*.json" -ErrorAction SilentlyContinue | 
                       Where-Object { $_.Name -notlike "*summary*" } |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 20
    
    $checkScores = @{}
    foreach ($reportFile in $detailedReports) {
        try {
            $report = Get-Content $reportFile.FullName | ConvertFrom-Json
            if ($report.Checks) {
                foreach ($check in $report.Checks) {
                    $checkName = $check.CheckName
                    if (-not $checkScores.ContainsKey($checkName)) {
                        $checkScores[$checkName] = @{ 
                            Scores = [System.Collections.ArrayList]::new()
                            Passed = 0
                            Failed = 0
                            Warnings = 0 
                        }
                    }
                    
                    [void]$checkScores[$checkName].Scores.Add($check.Score)
                    
                    switch ($check.Status) {
                        'Passed' { $checkScores[$checkName].Passed++ }
                        'Failed' { $checkScores[$checkName].Failed++ }
                        'Warning' { $checkScores[$checkName].Warnings++ }
                    }
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse quality report: $($reportFile.Name)"
        }
    }
    
    # Calculate average scores for each check type
    foreach ($checkName in $checkScores.Keys) {
        if ($qualityMetrics.Checks.ContainsKey($checkName)) {
            $qualityMetrics.Checks[$checkName].Passed = $checkScores[$checkName].Passed
            $qualityMetrics.Checks[$checkName].Failed = $checkScores[$checkName].Failed
            $qualityMetrics.Checks[$checkName].Warnings = $checkScores[$checkName].Warnings
            
            if ($checkScores[$checkName].Scores.Count -gt 0) {
                $qualityMetrics.Checks[$checkName].AvgScore = [math]::Round(
                    ($checkScores[$checkName].Scores | Measure-Object -Average).Average,
                    1
                )
            }
        }
    }
    
    # Build trends from historical summaries using efficient collections
    $scoreHistoryList = [System.Collections.Generic.List[object]]::new()
    $passRateHistoryList = [System.Collections.Generic.List[object]]::new()
    
    foreach ($summaryFile in $summaryFiles) {
        try {
            $summary = Get-Content $summaryFile.FullName | ConvertFrom-Json
            $scoreHistoryList.Add(@{
                Timestamp = $summary.Timestamp
                Score = $summary.AverageScore
            })
            
            if ($summary.FilesValidated -gt 0) {
                $passRate = [math]::Round(($summary.Passed / $summary.FilesValidated) * 100, 1)
                $passRateHistoryList.Add(@{
                    Timestamp = $summary.Timestamp
                    PassRate = $passRate
                })
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse quality summary: $($summaryFile.Name) - $_"
        }
    }
    
    # Convert to arrays for compatibility
    $qualityMetrics.Trends.ScoreHistory = @($scoreHistoryList)
    $qualityMetrics.Trends.PassRateHistory = @($passRateHistoryList)
    
    return $qualityMetrics
}

function Get-PSScriptAnalyzerMetrics {
    <#
    .SYNOPSIS
        Get PSScriptAnalyzer metrics from latest report
    #>
    Write-ScriptLog -Message "Collecting PSScriptAnalyzer metrics"
    
    $metrics = @{
        TotalIssues = 0
        Errors = 0
        Warnings = 0
        Information = 0
        FilesAnalyzedCount = 0
        FilesAnalyzed = @()
        LastRun = $null
        TopIssues = @()
    }
    
    # Find latest PSScriptAnalyzer results
    $pssaPath = Join-Path $ProjectPath "reports/psscriptanalyzer-fast-results.json"
    if (Test-Path $pssaPath) {
        try {
            $pssaData = Get-Content $pssaPath | ConvertFrom-Json
            $metrics.TotalIssues = $pssaData.Summary.TotalIssues
            $metrics.Errors = $pssaData.Summary.Errors
            $metrics.Warnings = $pssaData.Summary.Warnings
            $metrics.Information = $pssaData.Summary.Information
            $metrics.FilesAnalyzed = $pssaData.FilesAnalyzed
            $metrics.FilesAnalyzedCount = @($pssaData.FilesAnalyzed).Count
            $metrics.LastRun = $pssaData.GeneratedAt
            
            # Get top issues by count
            if ($pssaData.Issues) {
                $issueGroups = $pssaData.Issues | Group-Object -Property RuleName | 
                               Sort-Object Count -Descending | 
                               Select-Object -First 5
                
                $metrics.TopIssues = $issueGroups | ForEach-Object {
                    @{
                        Rule = $_.Name
                        Count = $_.Count
                        Severity = ($_.Group | Select-Object -First 1).Severity
                    }
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse PSScriptAnalyzer results: $_"
        }
    }
    
    return $metrics
}

function Get-BuildStatus {
    Write-ScriptLog -Message "Determining build status"

    $status = @{
        Overall = "Unknown"
        LastBuild = "Unknown"
        LastSuccess = "Unknown"
        Tests = "Unknown"
        Security = "Unknown"
        Coverage = "Unknown"
        Deployment = "Unknown"
        Workflows = @{
            Quality = "Unknown"
            PRValidation = "Unknown"
            GitHubPages = "Unknown"
            DockerPublish = "Unknown"
        }
        Badges = @{
            Build = "https://img.shields.io/github/workflow/status/wizzense/AitherZero/CI"
            Tests = "https://img.shields.io/badge/tests-unknown-lightgrey"
            Coverage = "https://img.shields.io/badge/coverage-unknown-lightgrey"
            Security = "https://img.shields.io/badge/security-unknown-lightgrey"
        }
    }

    # Check recent test results from testResults.xml at project root
    $testResultsPath = Join-Path $ProjectPath "testResults.xml"
    if (Test-Path $testResultsPath) {
        try {
            [xml]$testXml = Get-Content $testResultsPath
            
            # Parse NUnit format test results
            if ($testXml.'test-results') {
                $results = $testXml.'test-results'
                $totalTests = [int]$results.total
                $failures = [int]$results.failures
                $errors = [int]$results.errors
                $skipped = [int]$results.skipped

                if (($failures + $errors) -eq 0 -and $totalTests -gt 0) {
                    $status.Tests = "Passing"
                    $status.Badges.Tests = "https://img.shields.io/badge/tests-passing-brightgreen"
                } elseif (($failures + $errors) -gt 0) {
                    $status.Tests = "Failing"
                    $status.Badges.Tests = "https://img.shields.io/badge/tests-failing-red"
                } else {
                    $status.Tests = "No Tests"
                    $status.Badges.Tests = "https://img.shields.io/badge/tests-none-yellow"
                }
                
                $status.LastBuild = (Get-Item $testResultsPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse test results from testResults.xml: $_"
        }
    }
    
    # Also check tests/results directory for additional test data
    $testResultsDir = Join-Path $ProjectPath "tests/results"
    if (Test-Path $testResultsDir) {
        $latestResults = Get-ChildItem -Path $testResultsDir -Filter "*.xml" -ErrorAction SilentlyContinue | 
                        Sort-Object LastWriteTime -Descending | 
                        Select-Object -First 1
        if ($latestResults) {
            try {
                [xml]$testXml = Get-Content $latestResults.FullName
                if ($testXml.'test-results' -and $status.Tests -eq "Unknown") {
                    $results = $testXml.'test-results'
                    $totalTests = [int]$results.total
                    $failures = [int]$results.failures
                    $errors = [int]$results.errors

                    if (($failures + $errors) -eq 0 -and $totalTests -gt 0) {
                        $status.Tests = "Passing"
                        $status.Badges.Tests = "https://img.shields.io/badge/tests-passing-brightgreen"
                    } elseif (($failures + $errors) -gt 0) {
                        $status.Tests = "Failing"
                        $status.Badges.Tests = "https://img.shields.io/badge/tests-failing-red"
                    }
                }
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to parse test results from tests/results"
            }
        }
    }

    # Check code coverage
    $coverageFiles = Get-ChildItem -Path $ProjectPath -Filter "Coverage-*.xml" -Recurse -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
    if ($coverageFiles) {
        try {
            [xml]$coverageXml = Get-Content $coverageFiles.FullName
            if ($coverageXml.coverage) {
                $coveragePercent = [math]::Round([double]$coverageXml.coverage.'line-rate' * 100, 1)
                $status.Coverage = "${coveragePercent}%"
                
                if ($coveragePercent -ge 80) {
                    $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-brightgreen"
                } elseif ($coveragePercent -ge 50) {
                    $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-yellow"
                } else {
                    $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-red"
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse coverage data"
        }
    }
    
    # Check PSScriptAnalyzer results for security/quality
    $pssaPath = Join-Path $ProjectPath "reports/psscriptanalyzer-fast-results.json"
    if (Test-Path $pssaPath) {
        try {
            $pssaData = Get-Content $pssaPath | ConvertFrom-Json
            $errorCount = $pssaData.Summary.Errors
            
            if ($errorCount -eq 0) {
                $status.Security = "Clean"
                $status.Badges.Security = "https://img.shields.io/badge/security-clean-brightgreen"
            } elseif ($errorCount -lt 5) {
                $status.Security = "Minor Issues"
                $status.Badges.Security = "https://img.shields.io/badge/security-minor_issues-yellow"
            } else {
                $status.Security = "Issues Found"
                $status.Badges.Security = "https://img.shields.io/badge/security-issues-red"
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse PSScriptAnalyzer results for security status"
        }
    }

    # Determine overall status
    if ($status.Tests -eq "Passing" -and $status.Security -eq "Clean") {
        $status.Overall = "Healthy"
    } elseif ($status.Tests -eq "Failing" -or $status.Security -eq "Issues Found") {
        $status.Overall = "Issues"
    } elseif ($status.Tests -eq "Passing" -or $status.Security -eq "Minor Issues") {
        $status.Overall = "Warning"
    } else {
        $status.Overall = "Unknown"
    }
    
    # Check if we're in a CI environment to set deployment status
    if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
        $status.Deployment = "CI/CD Active"
    }

    return $status
}

function Get-RecentActivity {
    Write-ScriptLog -Message "Getting recent activity"

    $activity = @{
        Commits = @()
        Issues = @()
        Releases = @()
        LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    # Get recent commits using git if available
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $gitLog = git log --oneline -10 2>$null
            foreach ($line in $gitLog) {
                if ($line) {
                    $parts = $line -split ' ', 2
                    $activity.Commits += @{
                        Hash = $parts[0]
                        Message = $parts[1]
                        Date = (git show -s --format=%ci $parts[0] 2>$null)
                    }
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to get git history"
        }
    }

    return $activity
}

function Get-FileLevelMetrics {
    <#
    .SYNOPSIS
        Get detailed quality metrics for every file in the project
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Collecting file-level quality metrics"
    
    $fileMetrics = @{
        Files = @()
        Summary = @{
            TotalFiles = 0
            AnalyzedFiles = 0
            AverageScore = 0
            ByDomain = @{}
        }
    }
    
    # Get all PowerShell files
    $psFiles = @(
        Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
    ) | Where-Object { $_.FullName -notmatch '(tests|examples|legacy|node_modules)' }
    
    $fileMetrics.Summary.TotalFiles = $psFiles.Count
    
    foreach ($file in $psFiles) {
        try {
            $relativePath = $file.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
            $domain = if ($relativePath -match '^domains/([^/]+)') { $matches[1] } 
                     elseif ($relativePath -match '^automation-scripts') { 'automation-scripts' }
                     else { 'other' }
            
            $fileData = @{
                Path = $relativePath
                Name = $file.Name
                Domain = $domain
                Lines = 0
                Functions = 0
                Score = 0
                Issues = @()
                HasTests = $false
            }
            
            # Count lines and functions
            $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
            if ($content) {
                $fileData.Lines = $content.Count
                $funcMatches = $content | Select-String -Pattern '^\s*function\s+' -ErrorAction SilentlyContinue
                $fileData.Functions = if ($funcMatches) { $funcMatches.Count } else { 0 }
            }
            
            # Run PSScriptAnalyzer on individual file
            if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
                $rawIssues = Invoke-ScriptAnalyzer -Path $file.FullName -ErrorAction SilentlyContinue
                $issues = if ($rawIssues) { @($rawIssues) } else { @() }
                
                if ($issues.Count -gt 0) {
                    $fileData.Issues = $issues | Select-Object -First 10 | ForEach-Object {
                        @{
                            Rule = $_.RuleName
                            Severity = $_.Severity
                            Line = $_.Line
                            Message = $_.Message
                        }
                    }
                    
                    # Calculate score (100 - issues penalty)
                    $errorCount = @($issues | Where-Object { $_.Severity -eq 'Error' }).Count
                    $warningCount = @($issues | Where-Object { $_.Severity -eq 'Warning' }).Count
                    $infoCount = @($issues | Where-Object { $_.Severity -eq 'Information' }).Count
                    $errorPenalty = $errorCount * 10
                    $warningPenalty = $warningCount * 3
                    $infoPenalty = $infoCount * 1
                    $fileData.Score = [math]::Max(0, 100 - $errorPenalty - $warningPenalty - $infoPenalty)
                } else {
                    $fileData.Score = 100  # No issues
                }
            } else {
                $fileData.Score = 100  # No analyzer, assume clean
            }
            
            # Check if file has tests
            $testPath = $file.FullName -replace '\.ps(m?)1$', '.Tests.ps1'
            $testPath = $testPath -replace '(domains|automation-scripts)', 'tests/unit/$1'
            $fileData.HasTests = Test-Path $testPath
            
            $fileMetrics.Files += $fileData
            $fileMetrics.Summary.AnalyzedFiles++
            
            # Track by domain
            if (-not $fileMetrics.Summary.ByDomain.ContainsKey($domain)) {
                $fileMetrics.Summary.ByDomain[$domain] = @{
                    Files = 0
                    AverageScore = 0
                    TotalScore = 0
                }
            }
            $fileMetrics.Summary.ByDomain[$domain].Files++
            $fileMetrics.Summary.ByDomain[$domain].TotalScore += $fileData.Score
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze file: $($file.Name) - $_"
        }
    }
    
    # Calculate averages
    if ($fileMetrics.Summary.AnalyzedFiles -gt 0) {
        $fileMetrics.Summary.AverageScore = [math]::Round(
            ($fileMetrics.Files | Measure-Object -Property Score -Average).Average,
            1
        )
        
        foreach ($domain in $fileMetrics.Summary.ByDomain.Keys) {
            if ($fileMetrics.Summary.ByDomain[$domain].Files -gt 0) {
                $fileMetrics.Summary.ByDomain[$domain].AverageScore = [math]::Round(
                    $fileMetrics.Summary.ByDomain[$domain].TotalScore / $fileMetrics.Summary.ByDomain[$domain].Files,
                    1
                )
            }
        }
    }
    
    return $fileMetrics
}

function Get-DependencyMapping {
    <#
    .SYNOPSIS
        Extract and map dependencies from config.psd1
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Mapping dependencies from config.psd1"
    
    $dependencies = @{
        Features = @()
        Scripts = @{}
        Modules = @{}
        Total = 0
    }
    
    $configPath = Join-Path $ProjectPath "config.psd1"
    if (Test-Path $configPath) {
        try {
            $config = Import-PowerShellDataFile $configPath -ErrorAction Stop
            
            # Extract feature dependencies
            if ($config.Manifest.FeatureDependencies) {
                foreach ($category in $config.Manifest.FeatureDependencies.Keys) {
                    foreach ($feature in $config.Manifest.FeatureDependencies[$category].Keys) {
                        try {
                            $featureData = $config.Manifest.FeatureDependencies[$category][$feature]
                            $featureDep = @{
                                Category = $category
                                Name = $feature
                                DependsOn = @()
                                Scripts = @()
                                Required = $false
                                Platform = @()
                                Description = ''
                            }
                            
                            # Safely add properties that exist
                            if ($featureData.PSObject.Properties['DependsOn']) { $featureDep.DependsOn = $featureData.DependsOn }
                            if ($featureData.PSObject.Properties['Scripts']) { $featureDep.Scripts = $featureData.Scripts }
                            if ($featureData.PSObject.Properties['Required']) { $featureDep.Required = [bool]$featureData.Required }
                            if ($featureData.PSObject.Properties['PlatformRestrictions']) { $featureDep.Platform = $featureData.PlatformRestrictions }
                            if ($featureData.PSObject.Properties['Description']) { $featureDep.Description = $featureData.Description }
                            
                            $dependencies.Features += $featureDep
                            $dependencies.Total++
                        } catch {
                            Write-ScriptLog -Level Warning -Message "Failed to parse feature $category.$feature : $_"
                        }
                    }
                }
            }
            
            # Extract script inventory
            if ($config.Manifest.ScriptInventory) {
                $dependencies.Scripts = $config.Manifest.ScriptInventory
            }
            
            # Extract domain modules
            if ($config.Manifest.Domains) {
                $dependencies.Modules = $config.Manifest.Domains
            }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse config.psd1: $_"
        }
    }
    
    return $dependencies
}

function Get-DetailedTestResults {
    <#
    .SYNOPSIS
        Get comprehensive test results with descriptions and audit test files
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Collecting detailed test results and auditing test coverage"
    
    $testResults = @{
        Tests = @()
        Summary = @{
            Total = 0
            Passed = 0
            Failed = 0
            Skipped = 0
            Duration = "Unknown"
        }
        ByDomain = @{}
        ByType = @{
            Unit = @{ Total = 0; Passed = 0; Failed = 0 }
            Integration = @{ Total = 0; Passed = 0; Failed = 0 }
        }
        TestFiles = @{
            Total = 0
            Unit = 0
            Integration = 0
            WithResults = 0
            PotentialTests = 0
        }
        Audit = @{
            Message = ''
            FilesWithoutResults = @()
        }
    }
    
    # Count all test files
    $allTestFiles = Get-ChildItem -Path (Join-Path $ProjectPath "tests") -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
    $testResults.TestFiles.Total = $allTestFiles.Count
    $testResults.TestFiles.Unit = @($allTestFiles | Where-Object { $_.FullName -match '/unit/' }).Count
    $testResults.TestFiles.Integration = @($allTestFiles | Where-Object { $_.FullName -match '/integration/' }).Count
    
    # Count potential test cases in all test files
    foreach ($testFile in $allTestFiles) {
        try {
            $content = Get-Content $testFile.FullName -ErrorAction SilentlyContinue
            if ($content) {
                # Count It blocks (actual test cases)
                $itBlocks = $content | Select-String -Pattern '^\s*It\s+[''"]' -AllMatches
                if ($itBlocks) {
                    $testResults.TestFiles.PotentialTests += $itBlocks.Count
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to read test file: $($testFile.Name) - $_"
        }
    }
    
    # Parse testResults.xml for actual execution results
    $testResultsPath = Join-Path $ProjectPath "testResults.xml"
    if (Test-Path $testResultsPath) {
        try {
            [xml]$testXml = Get-Content $testResultsPath
            
            # Get summary from root
            $results = $testXml.'test-results'
            $testResults.Summary.Total = [int]$results.total
            $failures = [int]$results.failures
            $errors = [int]$results.errors
            $testResults.Summary.Skipped = [int]$results.skipped
            $testResults.Summary.Passed = $testResults.Summary.Total - $failures - $errors - $testResults.Summary.Skipped
            $testResults.Summary.Failed = $failures + $errors
            
            # Count how many test files have results
            $testCases = $testXml.SelectNodes("//test-case")
            $filesWithResults = @($testCases | ForEach-Object { 
                if ($_.name -match '/([^/]+\.Tests\.ps1)') { $matches[1] }
            } | Select-Object -Unique)
            $testResults.TestFiles.WithResults = $filesWithResults.Count
            
            # Extract individual test cases
            foreach ($testCase in $testCases) {
                $testPath = $testCase.name
                $domain = if ($testPath -match '/domains/([^/]+)/') { $matches[1] }
                         elseif ($testPath -match '/automation-scripts/') { 'automation-scripts' }
                         else { 'other' }
                
                $testType = if ($testPath -match '/unit/') { 'Unit' }
                           elseif ($testPath -match '/integration/') { 'Integration' }
                           else { 'Other' }
                
                $testData = @{
                    Name = $testCase.name
                    Description = $testCase.description
                    Result = $testCase.result
                    Success = $testCase.success -eq 'True'
                    Time = $testCase.time
                    Domain = $domain
                    Type = $testType
                }
                
                $testResults.Tests += $testData
                
                # Track by domain
                if (-not $testResults.ByDomain.ContainsKey($domain)) {
                    $testResults.ByDomain[$domain] = @{ Total = 0; Passed = 0; Failed = 0 }
                }
                $testResults.ByDomain[$domain].Total++
                if ($testData.Success) {
                    $testResults.ByDomain[$domain].Passed++
                } else {
                    $testResults.ByDomain[$domain].Failed++
                }
                
                # Track by type
                if ($testResults.ByType.ContainsKey($testType)) {
                    $testResults.ByType[$testType].Total++
                    if ($testData.Success) {
                        $testResults.ByType[$testType].Passed++
                    } else {
                        $testResults.ByType[$testType].Failed++
                    }
                }
            }
            
            # Get duration from test suite
            if ($testXml.'test-results'.'test-suite' -and $testXml.'test-results'.'test-suite'.time) {
                $duration = [double]$testXml.'test-results'.'test-suite'.time
                if ($duration -lt 60) {
                    $testResults.Summary.Duration = "$([math]::Round($duration, 2))s"
                } else {
                    $minutes = [math]::Floor($duration / 60)
                    $seconds = [math]::Round($duration % 60, 0)
                    $testResults.Summary.Duration = "${minutes}m ${seconds}s"
                }
            }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse detailed test results: $_"
        }
    }
    
    # Create audit message
    if ($testResults.TestFiles.Total -gt 0) {
        $coveragePercent = if ($testResults.TestFiles.PotentialTests -gt 0) {
            [math]::Round(($testResults.Summary.Total / $testResults.TestFiles.PotentialTests) * 100, 1)
        } else { 0 }
        
        $testResults.Audit.Message = @"
⚠️ TEST AUDIT FINDINGS:
- Total Test Files: $($testResults.TestFiles.Total) ($($testResults.TestFiles.Unit) unit, $($testResults.TestFiles.Integration) integration)
- Potential Test Cases: $($testResults.TestFiles.PotentialTests) (by counting It blocks)
- Actually Run: $($testResults.Summary.Total) ($coveragePercent% of potential)
- Files with Results: $($testResults.TestFiles.WithResults) / $($testResults.TestFiles.Total)

The autogenerated test system has created $($testResults.TestFiles.Total) test files with approximately $($testResults.TestFiles.PotentialTests) test cases.
Only $($testResults.Summary.Total) tests were run in the last execution (from testResults.xml).
Run './az 0402' to execute the full test suite.
"@
    }
    
    return $testResults
}

function Get-CodeCoverageDetails {
    <#
    .SYNOPSIS
        Get detailed code coverage information from JaCoCo or Cobertura format
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Collecting code coverage details"
    
    $coverage = @{
        Overall = @{
            Percentage = 0
            CoveredLines = 0
            TotalLines = 0
            MissedLines = 0
        }
        ByFile = @()
        ByDomain = @{}
        Format = "Unknown"
    }
    
    # Look for latest coverage XML - check both tests/results and tests/coverage
    $searchPaths = @(
        (Join-Path $ProjectPath "tests/results"),
        (Join-Path $ProjectPath "tests/coverage")
    )
    
    $coverageFiles = @()
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $coverageFiles += Get-ChildItem -Path $searchPath -Filter "Coverage-*.xml" -ErrorAction SilentlyContinue |
                             Where-Object { $_.Length -gt 100 }  # Skip empty files
        }
    }
    
    $latestCoverage = $coverageFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestCoverage) {
        try {
            [xml]$coverageXml = Get-Content $latestCoverage.FullName
            
            # Check for JaCoCo format (used by Pester)
            if ($coverageXml.report) {
                Write-ScriptLog -Message "Parsing JaCoCo coverage format"
                $coverage.Format = "JaCoCo"
                
                # Get counters from report root - handle both single and multiple counters
                $counters = @($coverageXml.report.counter)
                $lineCounter = $counters | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1
                
                if ($lineCounter) {
                    $missedLines = [int]$lineCounter.missed
                    $coveredLines = [int]$lineCounter.covered
                    $totalLines = $missedLines + $coveredLines
                    
                    if ($totalLines -gt 0) {
                        $coverage.Overall.Percentage = [math]::Round(($coveredLines / $totalLines) * 100, 1)
                        $coverage.Overall.CoveredLines = $coveredLines
                        $coverage.Overall.TotalLines = $totalLines
                        $coverage.Overall.MissedLines = $missedLines
                        
                        Write-ScriptLog -Message "Coverage: $($coverage.Overall.Percentage)% ($coveredLines/$totalLines lines)"
                    }
                }
                
                # Extract file-level coverage from classes
                $packages = $coverageXml.SelectNodes("//package")
                foreach ($package in $packages) {
                    $classes = $package.SelectNodes(".//class")
                    foreach ($class in $classes) {
                        $filename = $class.sourcefilename
                        if (-not $filename) { continue }
                        
                        # Get line counter for this class
                        $classLineCounter = $class.counter | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1
                        if ($classLineCounter) {
                            $classMissed = [int]$classLineCounter.missed
                            $classCovered = [int]$classLineCounter.covered
                            $classTotal = $classMissed + $classCovered
                            
                            $fileCoverage = if ($classTotal -gt 0) { 
                                [math]::Round(($classCovered / $classTotal) * 100, 1)
                            } else { 0 }
                            
                            $domain = if ($filename -match 'domains[/\\]([^/\\]+)') { $matches[1] }
                                     elseif ($filename -match 'automation-scripts') { 'automation-scripts' }
                                     else { 'other' }
                            
                            $coverage.ByFile += @{
                                File = $filename
                                Coverage = $fileCoverage
                                Domain = $domain
                                CoveredLines = $classCovered
                                TotalLines = $classTotal
                            }
                            
                            # Track by domain
                            if (-not $coverage.ByDomain.ContainsKey($domain)) {
                                $coverage.ByDomain[$domain] = @{ 
                                    Files = 0
                                    TotalCoverage = 0
                                    AverageCoverage = 0
                                    CoveredLines = 0
                                    TotalLines = 0
                                }
                            }
                            $coverage.ByDomain[$domain].Files++
                            $coverage.ByDomain[$domain].TotalCoverage += $fileCoverage
                            $coverage.ByDomain[$domain].CoveredLines += $classCovered
                            $coverage.ByDomain[$domain].TotalLines += $classTotal
                        }
                    }
                }
                
                # Calculate domain averages
                foreach ($domain in $coverage.ByDomain.Keys) {
                    if ($coverage.ByDomain[$domain].Files -gt 0) {
                        $coverage.ByDomain[$domain].AverageCoverage = [math]::Round(
                            $coverage.ByDomain[$domain].TotalCoverage / $coverage.ByDomain[$domain].Files,
                            1
                        )
                    }
                }
            }
            # Check for Cobertura format
            elseif ($coverageXml.coverage) {
                Write-ScriptLog -Message "Parsing Cobertura coverage format"
                $coverage.Format = "Cobertura"
                
                $coverage.Overall.Percentage = [math]::Round([double]$coverageXml.coverage.'line-rate' * 100, 1)
                
                # Extract file-level coverage
                $packages = $coverageXml.SelectNodes("//package")
                foreach ($package in $packages) {
                    $classes = $package.SelectNodes(".//class")
                    foreach ($class in $classes) {
                        $filename = $class.filename
                        $lineRate = [double]$class.'line-rate'
                        
                        $domain = if ($filename -match 'domains[/\\]([^/\\]+)') { $matches[1] }
                                 elseif ($filename -match 'automation-scripts') { 'automation-scripts' }
                                 else { 'other' }
                        
                        $coverage.ByFile += @{
                            File = $filename
                            Coverage = [math]::Round($lineRate * 100, 1)
                            Domain = $domain
                        }
                        
                        # Track by domain
                        if (-not $coverage.ByDomain.ContainsKey($domain)) {
                            $coverage.ByDomain[$domain] = @{ 
                                Files = 0
                                TotalCoverage = 0
                                AverageCoverage = 0
                            }
                        }
                        $coverage.ByDomain[$domain].Files++
                        $coverage.ByDomain[$domain].TotalCoverage += ($lineRate * 100)
                    }
                }
                
                # Calculate domain averages
                foreach ($domain in $coverage.ByDomain.Keys) {
                    if ($coverage.ByDomain[$domain].Files -gt 0) {
                        $coverage.ByDomain[$domain].AverageCoverage = [math]::Round(
                            $coverage.ByDomain[$domain].TotalCoverage / $coverage.ByDomain[$domain].Files,
                            1
                        )
                    }
                }
            }
            else {
                Write-ScriptLog -Level Warning -Message "Unrecognized coverage file format"
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse coverage data: $_"
        }
    } else {
        Write-ScriptLog -Level Warning -Message "No coverage files found in tests/results or tests/coverage"
    }
    
    return $coverage
}

function Get-LifecycleAnalysis {
    <#
    .SYNOPSIS
        Analyze the age and lifecycle of all project components
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Performing lifecycle analysis"
    
    $lifecycle = @{
        Documentation = @{
            Files = @()
            Summary = @{
                Total = 0
                Stale = 0  # > 6 months
                Old = 0    # > 1 year
                Ancient = 0 # > 2 years
                AverageAgeDays = 0
            }
        }
        Code = @{
            Files = @()
            Summary = @{
                Total = 0
                Fresh = 0    # < 1 month
                Recent = 0   # < 3 months  
                Stale = 0    # > 6 months
                Old = 0      # > 1 year
                AverageAgeDays = 0
            }
        }
        LineCountAnalysis = @{
            PowerShellCode = 0
            Documentation = 0
            CommentedCode = 0
            BlankLines = 0
            ActualCode = 0
            DocumentationRatio = 0
        }
        ByDomain = @{}
    }
    
    $now = Get-Date
    
    # Analyze documentation files
    $docFiles = Get-ChildItem -Path $ProjectPath -Filter "*.md" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }
    
    $lifecycle.Documentation.Summary.Total = $docFiles.Count
    
    foreach ($doc in $docFiles) {
        try {
            $lastWrite = $doc.LastWriteTime
            $ageDays = ($now - $lastWrite).TotalDays
            $content = Get-Content $doc.FullName -ErrorAction SilentlyContinue
            $lineCount = if ($content) { $content.Count } else { 0 }
            
            $docData = @{
                Path = $doc.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
                LastModified = $lastWrite.ToString("yyyy-MM-dd")
                AgeDays = [math]::Round($ageDays, 0)
                Lines = $lineCount
                Status = if ($ageDays -gt 730) { 'Ancient' }
                        elseif ($ageDays -gt 365) { 'Old' }
                        elseif ($ageDays -gt 180) { 'Stale' }
                        else { 'Current' }
            }
            
            $lifecycle.Documentation.Files += $docData
            $lifecycle.LineCountAnalysis.Documentation += $lineCount
            
            # Update summary counts
            if ($ageDays -gt 730) { $lifecycle.Documentation.Summary.Ancient++ }
            elseif ($ageDays -gt 365) { $lifecycle.Documentation.Summary.Old++ }
            elseif ($ageDays -gt 180) { $lifecycle.Documentation.Summary.Stale++ }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze doc: $($doc.Name)"
        }
    }
    
    if ($docFiles.Count -gt 0) {
        $lifecycle.Documentation.Summary.AverageAgeDays = [math]::Round(
            ($lifecycle.Documentation.Files | Measure-Object -Property AgeDays -Average).Average,
            0
        )
    }
    
    # Analyze PowerShell code files
    $psFiles = @(
        Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
    ) | Where-Object { $_.FullName -notmatch '(tests|examples|legacy|node_modules)' }
    
    $lifecycle.Code.Summary.Total = $psFiles.Count
    
    foreach ($file in $psFiles) {
        try {
            $lastWrite = $file.LastWriteTime
            $ageDays = ($now - $lastWrite).TotalDays
            $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
            
            if ($content) {
                $totalLines = $content.Count
                $codeLines = 0
                $commentLines = 0
                $blankLines = 0
                $inCommentBlock = $false
                
                foreach ($line in $content) {
                    $trimmed = $line.Trim()
                    
                    if ($trimmed -eq '') {
                        $blankLines++
                    }
                    elseif ($trimmed -match '^<#') {
                        $inCommentBlock = $true
                        $commentLines++
                    }
                    elseif ($trimmed -match '^#>') {
                        $inCommentBlock = $false
                        $commentLines++
                    }
                    elseif ($inCommentBlock -or $trimmed -match '^#') {
                        $commentLines++
                    }
                    else {
                        $codeLines++
                    }
                }
                
                $lifecycle.LineCountAnalysis.PowerShellCode += $totalLines
                $lifecycle.LineCountAnalysis.ActualCode += $codeLines
                $lifecycle.LineCountAnalysis.CommentedCode += $commentLines
                $lifecycle.LineCountAnalysis.BlankLines += $blankLines
                
                $domain = if ($file.FullName -match 'domains[/\\]([^/\\]+)') { $matches[1] }
                         elseif ($file.FullName -match 'automation-scripts') { 'automation-scripts' }
                         else { 'other' }
                
                $fileData = @{
                    Path = $file.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
                    LastModified = $lastWrite.ToString("yyyy-MM-dd")
                    AgeDays = [math]::Round($ageDays, 0)
                    Lines = $totalLines
                    CodeLines = $codeLines
                    CommentLines = $commentLines
                    Domain = $domain
                    Status = if ($ageDays -lt 30) { 'Fresh' }
                            elseif ($ageDays -lt 90) { 'Recent' }
                            elseif ($ageDays -gt 365) { 'Old' }
                            elseif ($ageDays -gt 180) { 'Stale' }
                            else { 'Current' }
                }
                
                $lifecycle.Code.Files += $fileData
                
                # Update summary counts
                if ($ageDays -lt 30) { $lifecycle.Code.Summary.Fresh++ }
                elseif ($ageDays -lt 90) { $lifecycle.Code.Summary.Recent++ }
                elseif ($ageDays -gt 365) { $lifecycle.Code.Summary.Old++ }
                elseif ($ageDays -gt 180) { $lifecycle.Code.Summary.Stale++ }
                
                # Track by domain
                if (-not $lifecycle.ByDomain.ContainsKey($domain)) {
                    $lifecycle.ByDomain[$domain] = @{
                        Files = 0
                        TotalLines = 0
                        CodeLines = 0
                        CommentLines = 0
                        AverageAgeDays = 0
                        TotalAgeDays = 0
                    }
                }
                $lifecycle.ByDomain[$domain].Files++
                $lifecycle.ByDomain[$domain].TotalLines += $totalLines
                $lifecycle.ByDomain[$domain].CodeLines += $codeLines
                $lifecycle.ByDomain[$domain].CommentLines += $commentLines
                $lifecycle.ByDomain[$domain].TotalAgeDays += $ageDays
            }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze code: $($file.Name)"
        }
    }
    
    if ($psFiles.Count -gt 0) {
        $lifecycle.Code.Summary.AverageAgeDays = [math]::Round(
            ($lifecycle.Code.Files | Measure-Object -Property AgeDays -Average).Average,
            0
        )
    }
    
    # Calculate domain averages
    foreach ($domain in $lifecycle.ByDomain.Keys) {
        if ($lifecycle.ByDomain[$domain].Files -gt 0) {
            $lifecycle.ByDomain[$domain].AverageAgeDays = [math]::Round(
                $lifecycle.ByDomain[$domain].TotalAgeDays / $lifecycle.ByDomain[$domain].Files,
                0
            )
        }
    }
    
    # Calculate documentation ratio
    $totalCountedLines = $lifecycle.LineCountAnalysis.PowerShellCode + $lifecycle.LineCountAnalysis.Documentation
    if ($totalCountedLines -gt 0) {
        $lifecycle.LineCountAnalysis.DocumentationRatio = [math]::Round(
            ($lifecycle.LineCountAnalysis.Documentation / $totalCountedLines) * 100,
            1
        )
    }
    
    return $lifecycle
}

function New-HTMLDashboard {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [hashtable]$QualityMetrics,
        [hashtable]$PSScriptAnalyzerMetrics,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating HTML dashboard"

    # Load module manifest data
    $manifestPath = Join-Path $ProjectPath "AitherZero.psd1"
    $manifestData = $null
    $manifestVersion = "Unknown"
    $manifestGUID = "Unknown"
    $manifestAuthor = "Unknown"
    $manifestPSVersion = "Unknown"
    $manifestFunctionsCount = 0
    $manifestAliases = ""
    $manifestDescription = ""
    $manifestTagsHTML = ""
    
    if (Test-Path $manifestPath) {
        try {
            $manifestData = Import-PowerShellDataFile $manifestPath
            $manifestVersion = $manifestData.ModuleVersion
            $manifestGUID = $manifestData.GUID
            $manifestAuthor = $manifestData.Author
            $manifestPSVersion = $manifestData.PowerShellVersion
            $manifestFunctionsCount = @($manifestData.FunctionsToExport).Count
            $manifestAliases = $manifestData.AliasesToExport -join ', '
            $manifestDescription = $manifestData.Description
            
            if ($manifestData.PrivateData -and $manifestData.PrivateData.PSData -and $manifestData.PrivateData.PSData.Tags) {
                $manifestTagsHTML = $manifestData.PrivateData.PSData.Tags | ForEach-Object { "<span class='badge info'>$_</span>" } | Join-String -Separator ' '
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to load manifest data"
        }
    }

    # Get domain module information
    $domainsPath = Join-Path $ProjectPath "domains"
    $domains = @()
    if (Test-Path $domainsPath) {
        $domainDirs = Get-ChildItem -Path $domainsPath -Directory
        foreach ($domainDir in $domainDirs) {
            $moduleFiles = @(Get-ChildItem -Path $domainDir.FullName -Filter "*.psm1")
            $domains += @{
                Name = $domainDir.Name
                ModuleCount = $moduleFiles.Count
                Modules = $moduleFiles.Name
            }
        }
    }
    
    # Pre-build commits HTML
    $commitsHTML = ""
    if (@($Activity.Commits).Count -gt 0) {
        $commitsHTML = $Activity.Commits | Select-Object -First 5 | ForEach-Object {
            @"
                            <li class='commit-item'>
                                <span class='commit-hash'>$($_.Hash)</span>
                                <span class='commit-message'>$($_.Message)</span>
                            </li>
"@
        } | Join-String -Separator "`n"
    } else {
        $commitsHTML = "                            <li class='commit-item'><span class='commit-message'>No recent activity found</span></li>"
    }
    
    # Pre-build domains HTML
    $domainsHTML = ""
    if (@($domains).Count -gt 0) {
        $domainsCount = @($domains).Count
        $domainCardsHTML = foreach($domain in $domains) {
            @"
                    <div class="domain-card">
                        <h4>$($domain.Name)</h4>
                        <div class="module-count">$($domain.ModuleCount) module$(if($domain.ModuleCount -ne 1){'s'})</div>
                    </div>
"@
        }
        $domainCardsJoined = $domainCardsHTML | Join-String -Separator "`n"
        
        $domainsHTML = @"
            <section class="section" id="domains">
                <h2>🗂️ Domain Modules</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Consolidated domain-based module architecture with $domainsCount domains
                </p>
                <div class="domains-list">
$domainCardsJoined
                </div>
            </section>
"@
    }
    
    # Pre-build manifest HTML
    $manifestHTML = ""
    if ($manifestData) {
        $manifestTagsSection = ""
        if ($manifestTagsHTML) {
            $manifestTagsSection = @"
                <div style="margin-top: 15px;">
                    <div class="label" style="margin-bottom: 10px;">Tags</div>
                    <div class="badge-grid">
                        $manifestTagsHTML
                    </div>
                </div>
"@
        }
        
        $manifestHTML = @"
            <section class="section" id="manifest">
                <h2>📦 Module Manifest</h2>
                <div class="manifest-info">
                    <h4>AitherZero.psd1</h4>
                    <div class="manifest-grid">
                        <div class="manifest-item">
                            <div class="label">Version</div>
                            <div class="value">$manifestVersion</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">GUID</div>
                            <div class="value">$manifestGUID</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">Author</div>
                            <div class="value">$manifestAuthor</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">PowerShell Version</div>
                            <div class="value">$manifestPSVersion+</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">Functions Exported</div>
                            <div class="value">$manifestFunctionsCount</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">Aliases</div>
                            <div class="value">$manifestAliases</div>
                        </div>
                    </div>
                    <div style="margin-top: 20px;">
                        <div class="label" style="margin-bottom: 10px;">Description</div>
                        <div class="value" style="color: var(--text-secondary);">$manifestDescription</div>
                    </div>
$manifestTagsSection
                </div>
            </section>
"@
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero - Project Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --primary-color: #667eea;
            --secondary-color: #764ba2;
            --bg-dark: #0d1117;
            --bg-darker: #010409;
            --card-bg: #161b22;
            --card-border: #30363d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --success: #238636;
            --warning: #d29922;
            --error: #da3633;
            --info: #1f6feb;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--bg-darker);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 20px;
            margin-left: 290px;
        }
        
        @media (max-width: 1024px) {
            body {
                margin-left: 0;
                padding: 10px;
            }
        }

        /* Navigation TOC */
        .toc {
            position: fixed;
            top: 80px;
            left: 20px;
            width: 250px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 20px;
            max-height: calc(100vh - 100px);
            overflow-y: auto;
            z-index: 100;
            transition: transform 0.3s ease;
        }

        .toc-toggle {
            position: fixed;
            top: 20px;
            left: 20px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            padding: 10px 15px;
            border-radius: 8px;
            cursor: pointer;
            z-index: 101;
            color: var(--text-primary);
            font-size: 1.2rem;
        }

        .toc h3 {
            color: var(--primary-color);
            margin-bottom: 15px;
            font-size: 1rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .toc ul {
            list-style: none;
        }

        .toc li {
            margin-bottom: 10px;
        }

        .toc a {
            color: var(--text-secondary);
            text-decoration: none;
            transition: color 0.2s;
            font-size: 0.9rem;
        }

        .toc a:hover {
            color: var(--primary-color);
        }

        .toc a.active {
            color: var(--primary-color);
            font-weight: 600;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        .header {
            background: linear-gradient(135deg, var(--primary-color) 0%, var(--secondary-color) 100%);
            border-radius: 16px;
            padding: 40px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }

        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            background: linear-gradient(to right, #fff, #e0e0e0);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .header .subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
            color: rgba(255,255,255,0.9);
        }

        .badges-container {
            display: flex;
            gap: 10px;
            margin-top: 20px;
            flex-wrap: wrap;
            justify-content: center;
        }

        .badges-container img {
            height: 20px;
            transition: transform 0.2s;
        }

        .badges-container img:hover {
            transform: scale(1.05);
        }

        .status-bar {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 25px;
        }

        .status-badge {
            padding: 12px 20px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 0.9rem;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
            text-align: center;
        }

        .status-healthy { 
            background: linear-gradient(135deg, rgba(35, 134, 54, 0.3), rgba(35, 134, 54, 0.1)); 
            border-color: var(--success);
        }
        .status-issues { 
            background: linear-gradient(135deg, rgba(218, 54, 51, 0.3), rgba(218, 54, 51, 0.1)); 
            border-color: var(--error);
        }
        .status-warning { 
            background: linear-gradient(135deg, rgba(210, 153, 34, 0.3), rgba(210, 153, 34, 0.1)); 
            border-color: var(--warning);
        }
        .status-unknown { 
            background: linear-gradient(135deg, rgba(139, 148, 158, 0.3), rgba(139, 148, 158, 0.1)); 
            border-color: var(--text-secondary);
        }

        .content {
            margin-bottom: 30px;
        }

        .section {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            scroll-margin-top: 20px;
        }

        .section h2 {
            color: var(--primary-color);
            margin-bottom: 20px;
            font-size: 1.8rem;
            padding-bottom: 10px;
            border-bottom: 2px solid var(--card-border);
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-top: 25px;
        }

        .metric-card {
            background: linear-gradient(135deg, var(--card-bg) 0%, rgba(22, 27, 34, 0.5) 100%);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 25px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            min-height: 180px;
            display: flex;
            flex-direction: column;
        }

        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: linear-gradient(180deg, var(--primary-color), var(--secondary-color));
        }

        .metric-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.2);
            border-color: var(--primary-color);
        }

        .metric-card h3 {
            color: var(--text-primary);
            margin-bottom: 15px;
            font-size: 1.1rem;
            font-weight: 600;
        }

        .metric-value {
            font-size: 2.5rem;
            font-weight: bold;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
            line-height: 1.2;
        }

        .metric-label {
            color: var(--text-secondary);
            font-size: 0.9rem;
            line-height: 1.5;
            flex-grow: 1;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }

        .info-card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 8px;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .info-card:hover {
            border-color: var(--primary-color);
            box-shadow: 0 4px 20px rgba(102, 126, 234, 0.15);
        }

        .info-card-header {
            background: rgba(102, 126, 234, 0.1);
            padding: 15px 20px;
            font-weight: 600;
            border-bottom: 1px solid var(--card-border);
            color: var(--text-primary);
        }

        .info-card-body {
            padding: 20px;
        }

        .info-card-body p {
            margin-bottom: 12px;
            color: var(--text-secondary);
        }

        .info-card-body strong {
            color: var(--text-primary);
        }

        .info-card-body a {
            color: var(--info);
            text-decoration: none;
            transition: color 0.2s;
        }

        .info-card-body a:hover {
            color: var(--primary-color);
            text-decoration: underline;
        }

        .info-card-body code {
            background: var(--bg-darker);
            padding: 2px 8px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: var(--primary-color);
        }

        .commit-list {
            list-style: none;
        }

        .commit-item {
            display: flex;
            align-items: flex-start;
            padding: 10px 0;
            border-bottom: 1px solid var(--card-border);
        }

        .commit-item:last-child {
            border-bottom: none;
        }

        .commit-hash {
            font-family: 'Courier New', monospace;
            font-size: 0.8rem;
            background: var(--bg-darker);
            padding: 4px 8px;
            border-radius: 4px;
            margin-right: 12px;
            color: var(--primary-color);
            flex-shrink: 0;
        }

        .commit-message {
            color: var(--text-secondary);
            line-height: 1.5;
        }

        .progress-bar {
            background: var(--bg-darker);
            border-radius: 10px;
            height: 24px;
            overflow: hidden;
            margin: 10px 0;
            border: 1px solid var(--card-border);
        }

        .progress-fill {
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
            height: 100%;
            border-radius: 10px;
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 0.8rem;
            font-weight: 600;
        }

        .badge-grid {
            display: flex;
            gap: 10px;
            margin: 20px 0;
            flex-wrap: wrap;
        }

        .badge {
            background: var(--success);
            color: white;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 0.85rem;
            font-weight: 600;
            border: 1px solid transparent;
        }

        .badge.warning { 
            background: var(--warning); 
            color: var(--bg-darker); 
        }
        .badge.error { 
            background: var(--error); 
        }
        .badge.info { 
            background: var(--info); 
        }

        .manifest-info {
            background: var(--bg-darker);
            padding: 20px;
            border-radius: 8px;
            border: 1px solid var(--card-border);
        }

        .manifest-info h4 {
            color: var(--primary-color);
            margin-bottom: 15px;
        }

        .manifest-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .manifest-item {
            padding: 10px;
            background: var(--card-bg);
            border-radius: 6px;
            border: 1px solid var(--card-border);
        }

        .manifest-item .label {
            color: var(--text-secondary);
            font-size: 0.85rem;
            margin-bottom: 5px;
        }

        .manifest-item .value {
            color: var(--text-primary);
            font-weight: 600;
        }

        .domains-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }

        .domain-card {
            background: var(--bg-darker);
            padding: 15px;
            border-radius: 8px;
            border: 1px solid var(--card-border);
            transition: all 0.2s;
        }

        .domain-card:hover {
            border-color: var(--primary-color);
            transform: translateY(-2px);
        }

        .domain-card h4 {
            color: var(--primary-color);
            margin-bottom: 10px;
            text-transform: capitalize;
        }

        .domain-card .module-count {
            color: var(--text-secondary);
            font-size: 0.9rem;
        }

        .footer {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.9rem;
        }

        .footer a {
            color: var(--info);
            text-decoration: none;
        }

        .footer a:hover {
            color: var(--primary-color);
        }

        .refresh-indicator {
            position: fixed;
            top: 20px;
            right: 20px;
            background: var(--card-bg);
            padding: 12px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.3);
            font-size: 0.85rem;
            color: var(--text-secondary);
            border: 1px solid var(--card-border);
            z-index: 100;
        }

        @media (max-width: 1024px) {
            body {
                margin-left: 0;
            }

            .toc {
                transform: translateX(-270px);
            }

            .toc.open {
                transform: translateX(0);
            }

            .metrics-grid {
                grid-template-columns: 1fr;
            }

            .info-grid {
                grid-template-columns: 1fr;
            }

            .status-bar {
                grid-template-columns: 1fr;
            }
        }

        /* Smooth scroll */
        html {
            scroll-behavior: smooth;
        }

        /* Link styling */
        a {
            color: var(--info);
        }

        /* Roadmap Styles */
        .roadmap-container {
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .roadmap-priority {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 8px;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .roadmap-priority:hover {
            border-color: var(--primary-color);
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.1);
        }

        .priority-header {
            padding: 20px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.1), rgba(118, 75, 162, 0.05));
            border-bottom: 1px solid var(--card-border);
            user-select: none;
        }

        .priority-header:hover {
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.15), rgba(118, 75, 162, 0.1));
        }

        .priority-header h3 {
            margin: 0;
            color: var(--text-primary);
            font-size: 1.1rem;
        }

        .toggle-icon {
            font-size: 1rem;
            color: var(--primary-color);
            transition: transform 0.3s ease;
        }

        .priority-header.active .toggle-icon {
            transform: rotate(180deg);
        }

        .priority-content {
            padding: 20px;
            border-top: 1px solid var(--card-border);
        }

        .progress-indicator {
            margin-bottom: 20px;
        }

        .roadmap-list {
            list-style: none;
            padding-left: 0;
            margin: 15px 0;
        }

        .roadmap-item {
            padding: 10px 0;
            display: flex;
            align-items: center;
            gap: 12px;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--card-border);
        }

        .roadmap-item:last-child {
            border-bottom: none;
        }

        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            flex-shrink: 0;
        }

        .roadmap-item.completed .status-dot {
            background: var(--success);
            box-shadow: 0 0 8px var(--success);
        }

        .roadmap-item.in-progress .status-dot {
            background: var(--warning);
            box-shadow: 0 0 8px var(--warning);
            animation: pulse 2s ease-in-out infinite;
        }

        .roadmap-item.pending .status-dot {
            background: var(--text-secondary);
            opacity: 0.3;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .timeline {
            margin-top: 15px;
            padding: 10px;
            background: var(--bg-darker);
            border-radius: 4px;
            font-size: 0.9rem;
            color: var(--text-secondary);
        }

        /* Interactive enhancements */
        .metric-card {
            cursor: pointer;
            transition: all 0.3s ease, transform 0.2s ease;
        }

        .metric-card.expanded {
            grid-column: 1 / -1;
            background: linear-gradient(135deg, var(--card-bg) 0%, rgba(102, 126, 234, 0.05) 100%);
        }

        .metric-details {
            display: none;
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid var(--card-border);
            animation: fadeIn 0.3s ease;
        }

        .metric-card.expanded .metric-details {
            display: block;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* Chart styles */
        .chart-container {
            position: relative;
            height: 200px;
            margin: 20px 0;
        }

        .chart-bar {
            display: flex;
            align-items: flex-end;
            gap: 10px;
            height: 100%;
        }

        .bar {
            flex: 1;
            background: linear-gradient(180deg, var(--primary-color), var(--secondary-color));
            border-radius: 4px 4px 0 0;
            position: relative;
            transition: all 0.3s ease;
            min-height: 20px;
        }

        .bar:hover {
            opacity: 0.8;
            transform: translateY(-5px);
        }

        .bar-label {
            position: absolute;
            bottom: -25px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 0.75rem;
            color: var(--text-secondary);
            white-space: nowrap;
        }

        .bar-value {
            position: absolute;
            top: -25px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 0.8rem;
            color: var(--primary-color);
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="toc-toggle" onclick="toggleToc()">☰</div>
    
    <nav class="toc" id="toc">
        <h3>📑 Contents</h3>
        <ul>
            <li><a href="#overview">Overview</a></li>
            <li><a href="#metrics">Project Metrics</a></li>
            <li><a href="#quality">Code Quality</a></li>
            <li><a href="#pssa">PSScriptAnalyzer</a></li>
            <li><a href="#manifest">Module Manifest</a></li>
            <li><a href="#domains">Domain Modules</a></li>
            <li><a href="#health">Project Health</a></li>
            <li><a href="#git">Git & VCS</a></li>
            <li><a href="#activity">Recent Activity</a></li>
            <li><a href="#actions">Quick Actions</a></li>
            <li><a href="#system">System Info</a></li>
            <li><a href="#resources">Resources</a></li>
            <li><a href="#roadmap">🗺️ Roadmap</a></li>
            <li><a href="#github-activity">🌟 GitHub</a></li>
        </ul>
    </nav>

    <div class="refresh-indicator">
        🔄 Last updated: $($Metrics.LastUpdated)
    </div>

    <div class="container">
        <div class="header" id="overview">
            <h1>🚀 AitherZero</h1>
            <div class="subtitle">Infrastructure Automation Platform</div>

            <div class="badges-container">
                <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/quality-validation.yml?label=Quality&logo=github" alt="Quality Check">
                <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/pr-validation.yml?label=PR%20Validation&logo=github" alt="PR Validation">
                <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/jekyll-gh-pages.yml?label=GitHub%20Pages&logo=github" alt="GitHub Pages">
                <img src="$($Status.Badges.Tests)" alt="Tests Status">
                <img src="https://img.shields.io/badge/PowerShell-7.0+-blue?logo=powershell" alt="PowerShell Version">
                <img src="https://img.shields.io/github/license/wizzense/AitherZero" alt="License">
                <img src="https://img.shields.io/github/last-commit/wizzense/AitherZero" alt="Last Commit">
            </div>

            <div class="status-bar">
                <div class="status-badge status-$(($Status.Overall).ToLower())">
                    🎯 Overall: $($Status.Overall)
                </div>
                <div class="status-badge status-$(if($Status.Tests -eq 'Passing'){'healthy'}elseif($Status.Tests -eq 'Failing'){'issues'}else{'unknown'})">
                    🧪 Tests: $($Status.Tests)
                </div>
                <div class="status-badge status-$(if($Status.Security -eq 'Clean'){'healthy'}elseif($Status.Security -match 'Issues'){'issues'}elseif($Status.Security -match 'Minor'){'warning'}else{'unknown'})">
                    🔒 Security: $($Status.Security)
                </div>
                <div class="status-badge status-$(if($Status.Deployment -match 'Active'){'healthy'}else{'unknown'})">
                    📦 Deployment: $($Status.Deployment)
                </div>
            </div>
        </div>

        <div class="content">
            <section class="section" id="metrics">
                <h2>📊 Project Metrics</h2>
                <div class="metrics-grid">
                    <div class="metric-card">
                        <h3>📁 Project Files</h3>
                        <div class="metric-value">$($Metrics.Files.Total)</div>
                        <div class="metric-label">
                            $($Metrics.Files.PowerShell) Scripts | $($Metrics.Files.Modules) Modules | $($Metrics.Files.Data) Data
                        </div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                        📄 $($Metrics.Files.Markdown) Markdown | 🔧 $($Metrics.Files.YAML) YAML | 📋 $($Metrics.Files.JSON) JSON
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>📝 Lines of Code</h3>
                        <div class="metric-value">$($Metrics.LinesOfCode.ToString('N0'))</div>
                        <div class="metric-label">
                            $($Metrics.Functions) Functions$(if($Metrics.Classes -gt 0){" | $($Metrics.Classes) Classes"})
                        </div>
                        $(if ($Metrics.CommentLines -gt 0) {
                            $commentRatio = [math]::Round(($Metrics.CommentLines / $Metrics.LinesOfCode) * 100, 1)
                            @"
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            💬 $($Metrics.CommentLines.ToString('N0')) Comments ($commentRatio%) | ⚪ $($Metrics.BlankLines.ToString('N0')) Blank Lines
                        </div>
"@
                        })
                    </div>
                    
                    <div class="metric-card">
                        <h3>🤖 Automation Scripts</h3>
                        <div class="metric-value">$($Metrics.AutomationScripts)</div>
                        <div class="metric-label">Number-based orchestration (0000-9999)</div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            ⚡ $($Metrics.Workflows) GitHub Workflows
                        </div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>🗂️ Domain Modules</h3>
                        <div class="metric-value">$(@($Metrics.Domains).Count)</div>
                        <div class="metric-label">
                            $(($Metrics.Domains | ForEach-Object { $_.Modules } | Measure-Object -Sum).Sum) Total Modules
                        </div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            Consolidated architecture
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🧪 Test Files</h3>
                        <div class="metric-value">$($Metrics.Tests.Total)</div>
                        <div class="metric-label">
                            $($Metrics.Tests.Unit) Unit | $($Metrics.Tests.Integration) Integration
                        </div>
                        $(if ($Metrics.Tests.LastRun) {
                            $testStatusColor = if ($Metrics.Tests.SuccessRate -ge 95) { 'var(--success)' } 
                                              elseif ($Metrics.Tests.SuccessRate -ge 80) { 'var(--warning)' } 
                                              else { 'var(--error)' }
                            @"
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-darker); border-radius: 6px; border-left: 3px solid $testStatusColor;">
                            <div style="font-size: 0.85rem; color: var(--text-secondary); font-weight: 600;">
                                Last Test Run Results:
                            </div>
                            <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                                ✅ $($Metrics.Tests.Passed) Passed | ❌ $($Metrics.Tests.Failed) Failed$(if($Metrics.Tests.Skipped -gt 0){" | ⏭️ $($Metrics.Tests.Skipped) Skipped"})
                            </div>
                            <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                                Success Rate: <span style="color: $testStatusColor; font-weight: 600;">$($Metrics.Tests.SuccessRate)%</span> | Duration: $($Metrics.Tests.Duration)
                            </div>
                            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 5px;">
                                Last run: $($Metrics.Tests.LastRun)
                            </div>
                            <div style="font-size: 0.75rem; color: var(--warning); margin-top: 8px; font-style: italic;">
                                ⚠️ Only $($Metrics.Tests.Passed + $Metrics.Tests.Failed) test cases executed. Run <code>./az 0402</code> for full test suite.
                            </div>
                        </div>
"@
                        } else {
                            @"
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-darker); border-radius: 6px; border-left: 3px solid var(--text-secondary);">
                            <div style="font-size: 0.85rem; color: var(--text-secondary);">
                                ⚠️ No test results available. Run <code>./az 0402</code> to execute tests.
                            </div>
                        </div>
"@
                        })
                    </div>

                    <div class="metric-card">
                        <h3>📊 Code Coverage</h3>
                        <div class="metric-value">$($Metrics.Coverage.Percentage)%</div>
                        <div class="metric-label">
                            $(if($Metrics.Coverage.TotalLines -gt 0){"$($Metrics.Coverage.CoveredLines) / $($Metrics.Coverage.TotalLines) Lines Covered"}else{"No coverage data available"})
                        </div>
                        $(if($Metrics.Coverage.Percentage -gt 0) {
                            @"
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($Metrics.Coverage.Percentage)%">
                                $($Metrics.Coverage.Percentage)%
                            </div>
                        </div>
"@
                        })
                    </div>
                    
                    $(if ($Metrics.Git.Branch -ne "Unknown") {
                        @"
                    <div class="metric-card">
                        <h3>🌿 Git Repository</h3>
                        <div class="metric-value" style="font-size: 1.8rem;">$($Metrics.Git.CommitCount)</div>
                        <div class="metric-label">Total Commits</div>
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-darker); border-radius: 6px;">
                            <div style="font-size: 0.85rem; color: var(--text-secondary);">
                                🔀 Branch: <span style="color: var(--primary-color); font-weight: 600;">$($Metrics.Git.Branch)</span>
                            </div>
                            <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                                👥 $($Metrics.Git.Contributors) Contributors
                            </div>
                            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 5px;">
                                Latest: $($Metrics.Git.LastCommit)
                            </div>
                        </div>
                    </div>
"@
                    })
                    
                    <div class="metric-card">
                        <h3>💻 Platform</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($Metrics.Platform)</div>
                        <div class="metric-label">PowerShell $($Metrics.PSVersion)</div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            Environment: $(if($env:AITHERZERO_CI){'CI/CD Pipeline'}else{'Development'})
                        </div>
                    </div>
                </div>
            </section>

            <section class="section" id="quality">
                <h2>✨ Code Quality Validation</h2>
                <div class="metrics-grid">
                    <div class="metric-card $(if($QualityMetrics.AverageScore -ge 90){''}elseif($QualityMetrics.AverageScore -ge 70){'warning'}else{'error'})">
                        <h3>📈 Quality Score</h3>
                        <div class="metric-value">$($QualityMetrics.AverageScore)%</div>
                        <div class="metric-label">
                            Average across $($QualityMetrics.TotalFiles) validated files
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($QualityMetrics.AverageScore)%; background: $(if($QualityMetrics.AverageScore -ge 90){'var(--success)'}elseif($QualityMetrics.AverageScore -ge 70){'var(--warning)'}else{'var(--error)'})">
                                $(if($QualityMetrics.AverageScore -gt 0){ "$($QualityMetrics.AverageScore)%" })
                            </div>
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>✅ Validation Results</h3>
                        <div class="metric-value">$($QualityMetrics.PassedFiles)</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.PassedFiles) Passed | 
                            ⚠️ $($QualityMetrics.WarningFiles) Warnings | 
                            ❌ $($QualityMetrics.FailedFiles) Failed
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🔍 Error Handling</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.ErrorHandling.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.ErrorHandling.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.ErrorHandling.Warnings) | 
                            ❌ $($QualityMetrics.Checks.ErrorHandling.Failed)
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>📝 Logging</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.Logging.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.Logging.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.Logging.Warnings) | 
                            ❌ $($QualityMetrics.Checks.Logging.Failed)
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🧪 Test Coverage</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.TestCoverage.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.TestCoverage.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.TestCoverage.Warnings) | 
                            ❌ $($QualityMetrics.Checks.TestCoverage.Failed)
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🔬 PSScriptAnalyzer</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.PSScriptAnalyzer.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.PSScriptAnalyzer.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.PSScriptAnalyzer.Warnings) | 
                            ❌ $($QualityMetrics.Checks.PSScriptAnalyzer.Failed)
                        </div>
                    </div>
                </div>
                
                $(if ($QualityMetrics.LastValidation) {
                    "<p class='metric-label' style='text-align: center; margin-top: 20px;'>Last validation: $($QualityMetrics.LastValidation)</p>"
                } else {
                    "<p class='metric-label' style='text-align: center; margin-top: 20px;'>⚠️ No quality validation data available. Run <code>./az 0420</code> to generate quality reports.</p>"
                })
            </section>

            <section class="section" id="pssa">
                <h2>🔬 PSScriptAnalyzer Analysis</h2>
                $(if ($PSScriptAnalyzerMetrics.FilesAnalyzedCount -gt 0) {
                    $issuesColor = if ($PSScriptAnalyzerMetrics.Errors -gt 0) { 'var(--error)' } 
                                   elseif ($PSScriptAnalyzerMetrics.Warnings -gt 5) { 'var(--warning)' } 
                                   else { 'var(--success)' }
                    
                    $topIssuesHTML = if ($PSScriptAnalyzerMetrics.TopIssues -and @($PSScriptAnalyzerMetrics.TopIssues).Count -gt 0) {
                        $PSScriptAnalyzerMetrics.TopIssues | ForEach-Object {
                            $severityIcon = switch ([int]$_.Severity) {
                                3 { '❌' }  # Error
                                2 { '⚠️' }  # Warning
                                1 { 'ℹ️' }  # Information
                                default { '📝' }
                            }
                            "<li style='padding: 8px 0; border-bottom: 1px solid var(--card-border);'>$severityIcon <strong>$($_.Rule)</strong> - $($_.Count) instances</li>"
                        } | Join-String -Separator "`n"
                    } else {
                        "<li style='padding: 8px 0;'>No issues found</li>"
                    }
                    
                    @"
                <div class="metrics-grid">
                    <div class="metric-card">
                        <h3>📁 Files Analyzed</h3>
                        <div class="metric-value">$($PSScriptAnalyzerMetrics.FilesAnalyzedCount)</div>
                        <div class="metric-label">Last run: $(if($PSScriptAnalyzerMetrics.LastRun){$PSScriptAnalyzerMetrics.LastRun}else{'Never'})</div>
                    </div>
                    
                    <div class="metric-card" style="border-left-color: $issuesColor;">
                        <h3>⚠️ Total Issues</h3>
                        <div class="metric-value" style="color: $issuesColor;">$($PSScriptAnalyzerMetrics.TotalIssues)</div>
                        <div class="metric-label">
                            ❌ $($PSScriptAnalyzerMetrics.Errors) Errors | 
                            ⚠️ $($PSScriptAnalyzerMetrics.Warnings) Warnings | 
                            ℹ️ $($PSScriptAnalyzerMetrics.Information) Info
                        </div>
                    </div>
                </div>
                
                $(if (@($PSScriptAnalyzerMetrics.TopIssues).Count -gt 0) {
                    @"
                <div style="margin-top: 20px;">
                    <h3 style="color: var(--text-primary); margin-bottom: 15px;">🔝 Top Issues</h3>
                    <div style="background: var(--bg-darker); padding: 20px; border-radius: 8px; border: 1px solid var(--card-border);">
                        <ul style="list-style: none; margin: 0;">
$topIssuesHTML
                        </ul>
                    </div>
                </div>
"@
                })
                
                <p class='metric-label' style='text-align: center; margin-top: 20px;'>Run <code>./az 0404</code> to analyze code quality</p>
"@
                } else {
                    "<p class='metric-label' style='text-align: center;'>⚠️ No PSScriptAnalyzer data available. Run <code>./az 0404</code> to analyze your code.</p>"
                })
            </section>

$manifestHTML

$domainsHTML

            <section class="section" id="health">
                <h2>📈 Project Health</h2>
                <div class="badge-grid">
                    <div class="badge $(if($Status.Overall -eq 'Healthy'){''}elseif($Status.Overall -eq 'Issues'){'error'}else{'warning'})">
                        Build: $(if($Status.Overall -eq 'Healthy'){'Passing'}else{'Unknown'})
                    </div>
                    <div class="badge $(if($Status.Tests -eq 'Passing'){''}elseif($Status.Tests -eq 'Failing'){'error'}else{'warning'})">
                        Tests: $($Status.Tests)
                    </div>
                    <div class="badge info">Coverage: $($Metrics.Coverage.Percentage)%</div>
                    <div class="badge">Security: Scanned</div>
                    <div class="badge">Platform: $($Metrics.Platform)</div>
                    <div class="badge">PowerShell: $($Metrics.PSVersion)</div>
                    $(if($Metrics.Workflows -gt 0){"<div class='badge info'>Workflows: $($Metrics.Workflows)</div>"})
                </div>
            </section>
            
            $(if ($Metrics.Git.Branch -ne "Unknown") {
                @"
            <section class="section" id="git">
                <h2>🌿 Git Repository & Version Control</h2>
                <div class="metrics-grid" style="grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));">
                    <div class="info-card">
                        <div class="info-card-header">📊 Repository Statistics</div>
                        <div class="info-card-body">
                            <p><strong>Branch:</strong> <code>$($Metrics.Git.Branch)</code></p>
                            <p><strong>Total Commits:</strong> $($Metrics.Git.CommitCount.ToString('N0'))</p>
                            <p><strong>Contributors:</strong> $($Metrics.Git.Contributors)</p>
                            <p><strong>Automation Scripts:</strong> $($Metrics.AutomationScripts)</p>
                            <p><strong>GitHub Workflows:</strong> $($Metrics.Workflows)</p>
                        </div>
                    </div>
                    
                    <div class="info-card">
                        <div class="info-card-header">📝 Latest Commit</div>
                        <div class="info-card-body">
                            <p style="color: var(--text-secondary); font-family: monospace; font-size: 0.9rem;">
                                $($Metrics.Git.LastCommit)
                            </p>
                        </div>
                    </div>
                </div>
            </section>
"@
            })

            <div class="info-grid">
                <div class="info-card" id="activity">
                    <div class="info-card-header">🔄 Recent Activity</div>
                    <div class="info-card-body">
                        <ul class="commit-list">
$commitsHTML
                        </ul>
                    </div>
                </div>

                <div class="info-card" id="actions">
                    <div class="info-card-header">🎯 Quick Actions</div>
                    <div class="info-card-body">
                        <p><strong>Run Tests:</strong> <code>./az 0402</code></p>
                        <p><strong>Generate Report:</strong> <code>./az 0510</code></p>
                        <p><strong>View Dashboard:</strong> <code>./az 0511</code></p>
                        <p><strong>Validate Code:</strong> <code>./az 0404</code></p>
                        <p><strong>Update Project:</strong> <code>git pull && ./bootstrap.ps1</code></p>
                    </div>
                </div>

                <div class="info-card" id="system">
                    <div class="info-card-header">📋 System Information</div>
                    <div class="info-card-body">
                        <p><strong>Platform:</strong> $($Metrics.Platform ?? 'Unknown')</p>
                        <p><strong>PowerShell:</strong> $($Metrics.PSVersion)</p>
                        <p><strong>Environment:</strong> $(if($env:AITHERZERO_CI){'CI/CD'}else{'Development'})</p>
                        <p><strong>Last Scan:</strong> $($Metrics.LastUpdated)</p>
                        <p><strong>Working Directory:</strong> <code>$(Split-Path $ProjectPath -Leaf)</code></p>
                    </div>
                </div>

                <div class="info-card" id="resources">
                    <div class="info-card-header">🔗 Resources</div>
                    <div class="info-card-body">
                        <p><a href="https://github.com/wizzense/AitherZero" target="_blank">🏠 GitHub Repository</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/actions" target="_blank">⚡ CI/CD Pipeline</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/releases" target="_blank">📦 Releases</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/issues" target="_blank">🐛 Issues</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/tree/main/docs" target="_blank">📖 Documentation</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/blob/main/README.md" target="_blank">📄 README</a></p>
                    </div>
                </div>
            </div>

            <!-- Strategic Roadmap Section -->
            <section class="section" id="roadmap" style="margin-top: 30px;">
                <h2>🗺️ Strategic Roadmap</h2>
                <p style="color: var(--text-secondary); margin-bottom: 25px;">
                    Current strategic priorities and project direction
                </p>
                
                <div class="roadmap-container">
                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority1')">
                            <h3>🚀 Priority 1: Expand Distribution & Discoverability</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority1" class="priority-content">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 30%">30%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Make AitherZero easily discoverable across all platforms</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Publish to PowerShell Gallery (<code>Install-Module -Name AitherZero</code>)
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Create Windows installer (MSI/EXE) with WinGet integration
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Submit to package managers (Homebrew consideration)
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 2-3 weeks</p>
                        </div>
                    </div>

                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority2')">
                            <h3>📚 Priority 2: Enhance Documentation & Onboarding</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority2" class="priority-content" style="display: none;">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 45%">45%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Reduce time-to-value for new users from hours to minutes</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item completed">
                                    <span class="status-dot"></span>
                                    Comprehensive documentation structure
                                </li>
                                <li class="roadmap-item in-progress">
                                    <span class="status-dot"></span>
                                    Quick start guide for common scenarios
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Video tutorials and interactive demos
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    API reference documentation
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 3-4 weeks</p>
                        </div>
                    </div>

                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority3')">
                            <h3>🎯 Priority 3: Build Community & Ecosystem</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority3" class="priority-content" style="display: none;">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 15%">15%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Foster active community and enable contributions</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Community contribution guidelines (CONTRIBUTING.md)
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Plugin/extension system for community additions
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    User showcase and case studies
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Community Discord or Discussions forum
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 4-6 weeks</p>
                        </div>
                    </div>

                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority4')">
                            <h3>⚡ Priority 4: Advanced Features & Integrations</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority4" class="priority-content" style="display: none;">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 20%">20%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Expand capabilities and integrations</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item completed">
                                    <span class="status-dot"></span>
                                    Cross-platform support (Windows, Linux, macOS)
                                </li>
                                <li class="roadmap-item completed">
                                    <span class="status-dot"></span>
                                    Docker containerization with multi-arch support
                                </li>
                                <li class="roadmap-item in-progress">
                                    <span class="status-dot"></span>
                                    Web-based dashboard and monitoring (this page!)
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Enhanced cloud provider integrations
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Metrics and telemetry for usage insights
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 6-8 weeks</p>
                        </div>
                    </div>
                </div>

                <div style="margin-top: 30px; padding: 20px; background: var(--card-bg); border-radius: 8px; border-left: 4px solid var(--info);">
                    <h4 style="color: var(--info); margin-bottom: 10px;">📊 Overall Progress</h4>
                    <div class="progress-bar" style="height: 30px; margin-bottom: 10px;">
                        <div class="progress-fill" style="width: 28%; font-size: 0.9rem;">28% Complete</div>
                    </div>
                    <p style="color: var(--text-secondary); font-size: 0.9rem; margin: 0;">
                        Based on strategic priorities outlined in <a href="https://github.com/wizzense/AitherZero/blob/main/STRATEGIC-ROADMAP.md" target="_blank" style="color: var(--info);">STRATEGIC-ROADMAP.md</a>
                    </p>
                </div>
            </section>

            <!-- GitHub Activity Section -->
            <section class="section" id="github-activity" style="margin-top: 30px;">
                <h2>🌟 GitHub Activity</h2>
                <div class="metrics-grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
                    <div class="metric-card">
                        <h3>⭐ Stars</h3>
                        <div class="metric-value" style="font-size: 2rem;">--</div>
                        <div class="metric-label">GitHub Stars</div>
                    </div>
                    <div class="metric-card">
                        <h3>🍴 Forks</h3>
                        <div class="metric-value" style="font-size: 2rem;">--</div>
                        <div class="metric-label">Repository Forks</div>
                    </div>
                    <div class="metric-card">
                        <h3>👥 Contributors</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($Metrics.Git.Contributors)</div>
                        <div class="metric-label">Active Contributors</div>
                    </div>
                    <div class="metric-card">
                        <h3>🔀 Pull Requests</h3>
                        <div class="metric-value" style="font-size: 2rem;">--</div>
                        <div class="metric-label">Open PRs</div>
                    </div>
                </div>
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 15px; text-align: center;">
                    💡 <em>GitHub API integration coming soon for real-time stats</em>
                </p>
            </section>
        </div>

        <div class="footer">
            Generated by AitherZero Dashboard | $($Metrics.LastUpdated) |
            <a href="https://github.com/wizzense/AitherZero" target="_blank">View on GitHub</a>
        </div>
    </div>

    <script>
        // TOC toggle for mobile
        function toggleToc() {
            document.getElementById('toc').classList.toggle('open');
        }

        // Roadmap priority toggle
        function togglePriority(id) {
            const content = document.getElementById(id);
            const header = content.previousElementSibling;
            
            if (content.style.display === 'none' || content.style.display === '') {
                content.style.display = 'block';
                header.classList.add('active');
            } else {
                content.style.display = 'none';
                header.classList.remove('active');
            }
        }

        // Highlight active section in TOC
        const sections = document.querySelectorAll('.section, .header');
        const tocLinks = document.querySelectorAll('.toc a');

        function highlightToc() {
            let current = '';
            sections.forEach(section => {
                const sectionTop = section.offsetTop;
                const sectionHeight = section.clientHeight;
                if (pageYOffset >= sectionTop - 100) {
                    current = section.getAttribute('id');
                }
            });

            tocLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === '#' + current) {
                    link.classList.add('active');
                }
            });
        }

        window.addEventListener('scroll', highlightToc);
        highlightToc();

        // Interactive card expansion
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.metric-card');
            cards.forEach(card => {
                // Add click animation
                card.addEventListener('click', function(e) {
                    // Don't expand if clicking on a link
                    if (e.target.tagName === 'A' || e.target.closest('a')) {
                        return;
                    }
                    
                    this.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        this.style.transform = '';
                    }, 150);
                });

                // Add hover effects
                card.addEventListener('mouseenter', function() {
                    this.style.boxShadow = '0 8px 25px rgba(102, 126, 234, 0.25)';
                });

                card.addEventListener('mouseleave', function() {
                    this.style.boxShadow = '';
                });
            });

            // Smooth scroll for TOC links
            document.querySelectorAll('.toc a').forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    const targetId = this.getAttribute('href').substring(1);
                    const targetElement = document.getElementById(targetId);
                    
                    if (targetElement) {
                        targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                        // Close mobile TOC after navigation
                        if (window.innerWidth < 768) {
                            document.getElementById('toc').classList.remove('open');
                        }
                    }
                });
            });

            // Add copy-to-clipboard for code blocks
            document.querySelectorAll('code').forEach(code => {
                code.style.cursor = 'pointer';
                code.title = 'Click to copy';
                code.addEventListener('click', function() {
                    navigator.clipboard.writeText(this.textContent).then(() => {
                        const originalText = this.textContent;
                        this.textContent = '✓ Copied!';
                        setTimeout(() => {
                            this.textContent = originalText;
                        }, 1500);
                    });
                });
            });

            // Animate progress bars on scroll
            const progressBars = document.querySelectorAll('.progress-fill');
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.style.transition = 'width 1.5s ease-out';
                        const width = entry.target.style.width;
                        entry.target.style.width = '0%';
                        setTimeout(() => {
                            entry.target.style.width = width;
                        }, 100);
                    }
                });
            }, { threshold: 0.5 });

            progressBars.forEach(bar => observer.observe(bar));

            // Add keyboard shortcuts
            document.addEventListener('keydown', function(e) {
                // Ctrl/Cmd + K to toggle TOC
                if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                    e.preventDefault();
                    toggleToc();
                }
                // Escape to close TOC
                if (e.key === 'Escape') {
                    document.getElementById('toc').classList.remove('open');
                }
            });

            // Add search functionality hint (for future enhancement)
            console.log('💡 Dashboard Pro Tip: Use Ctrl+F to search this dashboard');
            console.log('🔍 Keyboard shortcuts:');
            console.log('  - Ctrl/Cmd + K: Toggle navigation');
            console.log('  - Escape: Close navigation');
            console.log('  - Click code blocks to copy');
        });

        // Auto-refresh every 5 minutes (optional - can be disabled)
        // setTimeout(() => {
        //     window.location.reload();
        // }, 300000);

        // Add live timestamp update
        function updateTimestamp() {
            const now = new Date();
            const timeString = now.toLocaleString();
            document.title = 'AitherZero Dashboard - Updated ' + timeString;
        }
        setInterval(updateTimestamp, 60000); // Update every minute
                    }, 150);
                });
            });

            // Close TOC when clicking a link on mobile
            tocLinks.forEach(link => {
                link.addEventListener('click', () => {
                    if (window.innerWidth <= 1024) {
                        document.getElementById('toc').classList.remove('open');
                    }
                });
            });
        });
    </script>
</body>
</html>
"@

    $dashboardPath = Join-Path $OutputPath "dashboard.html"
    if ($PSCmdlet.ShouldProcess($dashboardPath, "Create HTML dashboard")) {
        $html | Set-Content -Path $dashboardPath -Encoding UTF8
        Write-ScriptLog -Message "HTML dashboard created: $dashboardPath"
    }
}

function New-MarkdownDashboard {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [hashtable]$QualityMetrics,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating Markdown dashboard"

    $markdown = @"
# 🚀 AitherZero Project Dashboard

**Infrastructure Automation Platform**

*Last updated: $($Metrics.LastUpdated)*

---

## 📊 Project Metrics

### File Statistics
| Metric | Value | Details |
|--------|-------|---------|
| 📁 **Total Files** | **$($Metrics.Files.Total)** | $($Metrics.Files.PowerShell) Scripts, $($Metrics.Files.Modules) Modules, $($Metrics.Files.Data) Data |
| 📄 **Documentation** | **$($Metrics.Files.Markdown)** | Markdown files |
| 🔧 **Configuration** | **$($Metrics.Files.YAML + $Metrics.Files.JSON)** | $($Metrics.Files.YAML) YAML, $($Metrics.Files.JSON) JSON |

### Code Statistics
| Metric | Value | Details |
|--------|-------|---------|
| 📝 **Lines of Code** | **$($Metrics.LinesOfCode.ToString('N0'))** | Total lines across all PowerShell files |
| 🔨 **Functions** | **$($Metrics.Functions)** | Public and private functions |
$(if ($Metrics.Classes -gt 0) { 
    "| 🏗️ **Classes** | **$($Metrics.Classes)** | PowerShell classes |`n"
})$(
    $commentRatio = if($Metrics.LinesOfCode -gt 0){[math]::Round(($Metrics.CommentLines / $Metrics.LinesOfCode) * 100, 1)}else{0}
    "| 💬 **Comments** | **$($Metrics.CommentLines.ToString('N0'))** | $commentRatio% of total code |"
)
| ⚪ **Blank Lines** | **$($Metrics.BlankLines.ToString('N0'))** | Whitespace and formatting |

### Automation & Infrastructure  
| Metric | Value | Details |
|--------|-------|---------|
| 🤖 **Automation Scripts** | **$($Metrics.AutomationScripts)** | Number-based orchestration (0000-9999) |
| ⚡ **GitHub Workflows** | **$($Metrics.Workflows)** | CI/CD automation |
| 🗂️ **Domain Modules** | **$(@($Metrics.Domains).Count)** | $(($Metrics.Domains | ForEach-Object { $_.Modules } | Measure-Object -Sum).Sum) total modules |

### Testing & Quality
| Metric | Value | Details |
|--------|-------|---------|
| 🧪 **Test Files** | **$($Metrics.Tests.Total)** | $($Metrics.Tests.Unit) Unit, $($Metrics.Tests.Integration) Integration |
$(if ($Metrics.Tests.LastRun) {
    $totalTests = $Metrics.Tests.Passed + $Metrics.Tests.Failed
    @"
| ✅ **Last Test Run** | **$($Metrics.Tests.Passed)/$totalTests cases** | Success Rate: $($Metrics.Tests.SuccessRate)%; Duration: $($Metrics.Tests.Duration) |
| 📊 **Test Details** | **$($Metrics.Tests.LastRun)** | ✅ $($Metrics.Tests.Passed) passed, ❌ $($Metrics.Tests.Failed) failed$(if($Metrics.Tests.Skipped -gt 0){", ⏭️ $($Metrics.Tests.Skipped) skipped"}) |
| ⚠️ **Note** | **Partial Run** | Only $totalTests test cases executed from available test files. Run ``./az 0402`` for full suite. |

"@
} else {
"| ⚠️ **Test Results** | **N/A** | No test results available. Run ``./az 0402`` |
"
})| 📈 **Code Coverage** | **$($Metrics.Coverage.Percentage)%** | $(if($Metrics.Coverage.TotalLines -gt 0){"$($Metrics.Coverage.CoveredLines)/$($Metrics.Coverage.TotalLines) lines covered"}else{"No coverage data available"}) |

$(if ($Metrics.Git.Branch -ne "Unknown") {
@"
### Git Repository
| Metric | Value | Details |
|--------|-------|---------|
| 🌿 **Branch** | **``$($Metrics.Git.Branch)``** | Current working branch |
| 📝 **Total Commits** | **$($Metrics.Git.CommitCount.ToString('N0'))** | Repository history |
| 👥 **Contributors** | **$($Metrics.Git.Contributors)** | Unique contributors |
| 🔄 **Latest Commit** | **$($Metrics.Git.LastCommit)** | Most recent change |

"@
})

## ✨ Code Quality Validation

| Metric | Score | Status |
|--------|-------|--------|
| 📈 **Overall Quality** | **$($QualityMetrics.AverageScore)%** | $(if($QualityMetrics.AverageScore -ge 90){'✅ Excellent'}elseif($QualityMetrics.AverageScore -ge 70){'⚠️ Good'}else{'❌ Needs Improvement'}) |
| ✅ **Passed Files** | **$($QualityMetrics.PassedFiles)** | Out of $($QualityMetrics.TotalFiles) validated |
| 🔍 **Error Handling** | **$($QualityMetrics.Checks.ErrorHandling.AvgScore)%** | ✅ $($QualityMetrics.Checks.ErrorHandling.Passed) / ⚠️ $($QualityMetrics.Checks.ErrorHandling.Warnings) / ❌ $($QualityMetrics.Checks.ErrorHandling.Failed) |
| 📝 **Logging** | **$($QualityMetrics.Checks.Logging.AvgScore)%** | ✅ $($QualityMetrics.Checks.Logging.Passed) / ⚠️ $($QualityMetrics.Checks.Logging.Warnings) / ❌ $($QualityMetrics.Checks.Logging.Failed) |
| 🧪 **Test Coverage** | **$($QualityMetrics.Checks.TestCoverage.AvgScore)%** | ✅ $($QualityMetrics.Checks.TestCoverage.Passed) / ⚠️ $($QualityMetrics.Checks.TestCoverage.Warnings) / ❌ $($QualityMetrics.Checks.TestCoverage.Failed) |
| 🔬 **PSScriptAnalyzer** | **$($QualityMetrics.Checks.PSScriptAnalyzer.AvgScore)%** | ✅ $($QualityMetrics.Checks.PSScriptAnalyzer.Passed) / ⚠️ $($QualityMetrics.Checks.PSScriptAnalyzer.Warnings) / ❌ $($QualityMetrics.Checks.PSScriptAnalyzer.Failed) |

$(if ($QualityMetrics.LastValidation) {
    "*Last quality validation: $($QualityMetrics.LastValidation)*"
} else {
    "*⚠️ No quality validation data available. Run ``./az 0420`` to generate quality reports.*"
})

## 🎯 Project Health

$(switch ($Status.Overall) {
    'Healthy' { '✅ **Status: Healthy** - All systems operational' }
    'Issues' { '⚠️ **Status: Issues Detected** - Attention required' }
    default { '❓ **Status: Unknown** - Monitoring in progress' }
})

### Build Status
- **Tests:** $(switch ($Status.Tests) { 'Passing' { '✅ Passing' } 'Failing' { '❌ Failing' } default { '❓ Unknown' } })
- **Security:** 🛡️ Scanned
- **Coverage:** 📊 $($Metrics.Coverage.Percentage)%
- **Platform:** 💻 $($Metrics.Platform)
- **PowerShell:** ⚡ $($Metrics.PSVersion)

## 🔄 Recent Activity

$(if($Activity.Commits.Count -gt 0) {
    $Activity.Commits | Select-Object -First 5 | ForEach-Object {
        "- ``$($_.Hash)`` $($_.Message)"
    } | Join-String -Separator "`n"
} else {
    "No recent activity found"
})

## 🎯 Quick Commands

| Action | Command |
|--------|---------|
| Run Tests | ``./az 0402`` |
| Code Analysis | ``./az 0404`` |
| Generate Reports | ``./az 0510`` |
| View Dashboard | ``./az 0511`` |
| Syntax Check | ``./az 0407`` |

## 📋 System Information

- **Platform:** $($Metrics.Platform ?? 'Unknown')
- **PowerShell:** $($Metrics.PSVersion)
- **Environment:** $(if($env:AITHERZERO_CI){'CI/CD'}else{'Development'})
- **Project Root:** ``$ProjectPath``

## 🔗 Resources

- [🏠 GitHub Repository](https://github.com/wizzense/AitherZero)
- [⚡ CI/CD Pipeline](https://github.com/wizzense/AitherZero/actions)
- [📦 Releases](https://github.com/wizzense/AitherZero/releases)
- [🐛 Issues](https://github.com/wizzense/AitherZero/issues)
- [📖 Documentation](https://github.com/wizzense/AitherZero/tree/main/docs)

---

*Dashboard generated by AitherZero automation pipeline*
"@

    $dashboardPath = Join-Path $OutputPath "dashboard.md"
    if ($PSCmdlet.ShouldProcess($dashboardPath, "Create Markdown dashboard")) {
        $markdown | Set-Content -Path $dashboardPath -Encoding UTF8
        Write-ScriptLog -Message "Markdown dashboard created: $dashboardPath"
    }
}

function New-JSONReport {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [hashtable]$QualityMetrics,
        [hashtable]$PSScriptAnalyzerMetrics,
        [hashtable]$FileMetrics,
        [hashtable]$Dependencies,
        [hashtable]$DetailedTests,
        [hashtable]$CoverageDetails,
        [hashtable]$Lifecycle,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating JSON report"

    $report = @{
        Generated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        Project = @{
            Name = "AitherZero"
            Description = "Infrastructure Automation Platform"
            Repository = "https://github.com/wizzense/AitherZero"
        }
        Metrics = $Metrics
        Status = $Status
        Activity = $Activity
        QualityMetrics = $QualityMetrics
        PSScriptAnalyzerMetrics = $PSScriptAnalyzerMetrics
        FileMetrics = $FileMetrics
        Dependencies = $Dependencies
        DetailedTests = $DetailedTests
        CoverageDetails = $CoverageDetails
        Lifecycle = $Lifecycle
        Environment = @{
            CI = [bool]$env:AITHERZERO_CI
            Platform = $Metrics.Platform
            PowerShell = $Metrics.PSVersion
            WorkingDirectory = $ProjectPath
        }
    }

    $reportPath = Join-Path $OutputPath "dashboard.json"
    if ($PSCmdlet.ShouldProcess($reportPath, "Create JSON report")) {
        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
        Write-ScriptLog -Message "JSON report created: $reportPath"
    }
}

try {
    Write-ScriptLog -Message "Starting comprehensive dashboard generation"

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Collect data
    Write-ScriptLog -Message "Collecting project data..."
    $metrics = Get-ProjectMetrics
    $status = Get-BuildStatus
    $activity = Get-RecentActivity
    $qualityMetrics = Get-QualityMetrics
    $pssaMetrics = Get-PSScriptAnalyzerMetrics
    
    # Collect comprehensive detailed metrics
    Write-ScriptLog -Message "Collecting comprehensive project intelligence..."
    $fileMetrics = Get-FileLevelMetrics -ProjectPath $ProjectPath
    $dependencies = Get-DependencyMapping -ProjectPath $ProjectPath
    $detailedTests = Get-DetailedTestResults -ProjectPath $ProjectPath
    $coverageDetails = Get-CodeCoverageDetails -ProjectPath $ProjectPath
    $lifecycle = Get-LifecycleAnalysis -ProjectPath $ProjectPath
    
    # Update main metrics with detailed coverage
    if ($coverageDetails.Overall.Percentage -gt 0) {
        $metrics.Coverage.Percentage = $coverageDetails.Overall.Percentage
        $metrics.Coverage.CoveredLines = $coverageDetails.Overall.CoveredLines
        $metrics.Coverage.TotalLines = $coverageDetails.Overall.TotalLines
    }
    
    # Update main metrics with actual code lines (excluding docs and comments)
    if ($lifecycle.LineCountAnalysis.ActualCode -gt 0) {
        Write-Host "`n📊 Line Count Analysis:" -ForegroundColor Cyan
        Write-Host "  Actual Code Lines: $($lifecycle.LineCountAnalysis.ActualCode.ToString('N0'))" -ForegroundColor Green
        Write-Host "  PowerShell Files Total: $($lifecycle.LineCountAnalysis.PowerShellCode.ToString('N0'))" -ForegroundColor White
        Write-Host "  Documentation (.md): $($lifecycle.LineCountAnalysis.Documentation.ToString('N0'))" -ForegroundColor White
        Write-Host "  Comments: $($lifecycle.LineCountAnalysis.CommentedCode.ToString('N0'))" -ForegroundColor White
        Write-Host "  Blank Lines: $($lifecycle.LineCountAnalysis.BlankLines.ToString('N0'))" -ForegroundColor White
        Write-Host "  Documentation Ratio: $($lifecycle.LineCountAnalysis.DocumentationRatio)%" -ForegroundColor $(if($lifecycle.LineCountAnalysis.DocumentationRatio -gt 30){'Yellow'}else{'White'})
    }

    # Generate dashboards based on format selection
    switch ($Format) {
        'HTML' {
            New-HTMLDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -OutputPath $OutputPath
        }
        'Markdown' {
            New-MarkdownDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -OutputPath $OutputPath
        }
        'JSON' {
            New-JSONReport -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -FileMetrics $fileMetrics -Dependencies $dependencies -DetailedTests $detailedTests -CoverageDetails $coverageDetails -Lifecycle $lifecycle -OutputPath $OutputPath
        }
        'All' {
            New-HTMLDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -OutputPath $OutputPath
            New-MarkdownDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -OutputPath $OutputPath
            New-JSONReport -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -FileMetrics $fileMetrics -Dependencies $dependencies -DetailedTests $detailedTests -CoverageDetails $coverageDetails -Lifecycle $lifecycle -OutputPath $OutputPath
        }
    }

    # Create index file for easy access
    $indexContent = @"
# AitherZero Dashboard

## Available Reports

- [📊 HTML Dashboard](dashboard.html) - Interactive web dashboard
- [📝 Markdown Dashboard](dashboard.md) - Text-based dashboard
- [📋 JSON Report](dashboard.json) - Machine-readable data

## Generated: $($metrics.LastUpdated)

### Quick Stats
- Files: $($metrics.Files.Total)
- Lines of Code: $($metrics.LinesOfCode.ToString('N0'))
- Tests: $($metrics.Tests.Total)
- Coverage: $($metrics.Coverage.Percentage)%
- Status: $($status.Overall)
"@

    $indexPath = Join-Path $OutputPath "README.md"
    if ($PSCmdlet.ShouldProcess($indexPath, "Create index file")) {
        $indexContent | Set-Content -Path $indexPath -Encoding UTF8
    }

    # Summary
    Write-Host "`n🎉 Dashboard Generation Complete!" -ForegroundColor Green
    Write-Host "📁 Output Directory: $OutputPath" -ForegroundColor Cyan

    if ($Format -eq 'All' -or $Format -eq 'HTML') {
        Write-Host "🌐 HTML Dashboard: $(Join-Path $OutputPath 'dashboard.html')" -ForegroundColor Green
    }
    if ($Format -eq 'All' -or $Format -eq 'Markdown') {
        Write-Host "📝 Markdown Dashboard: $(Join-Path $OutputPath 'dashboard.md')" -ForegroundColor Green
    }
    if ($Format -eq 'All' -or $Format -eq 'JSON') {
        Write-Host "📋 JSON Report: $(Join-Path $OutputPath 'dashboard.json')" -ForegroundColor Green
    }

    Write-Host "`n📊 Project Metrics:" -ForegroundColor Cyan
    Write-Host "  Files: $($metrics.Files.Total) ($($metrics.Files.PowerShell) scripts, $($metrics.Files.Modules) modules)" -ForegroundColor White
    Write-Host "  Lines of Code: $($metrics.LinesOfCode.ToString('N0'))" -ForegroundColor White
    Write-Host "  Functions: $($metrics.Functions)" -ForegroundColor White
    Write-Host "  Tests: $($metrics.Tests.Total) ($($metrics.Tests.Unit) unit, $($metrics.Tests.Integration) integration)" -ForegroundColor White
    Write-Host "  Coverage: $($metrics.Coverage.Percentage)%" -ForegroundColor White
    Write-Host "  Status: $($status.Overall)" -ForegroundColor $(if($status.Overall -eq 'Healthy'){'Green'}elseif($status.Overall -eq 'Issues'){'Yellow'}else{'Gray'})

    Write-ScriptLog -Message "Dashboard generation completed successfully" -Data @{
        OutputPath = $OutputPath
        Format = $Format
        FilesGenerated = $(if($Format -eq 'All'){3}else{1})
        ProjectFiles = $metrics.Files.Total
        LinesOfCode = $metrics.LinesOfCode
        Status = $status.Overall
    }

    # Open HTML dashboard in browser if requested
    if ($Open -and ($Format -eq 'HTML' -or $Format -eq 'All')) {
        $htmlDashboardPath = Join-Path $OutputPath 'dashboard.html'
        if ($PSCmdlet.ShouldProcess($htmlDashboardPath, "Open HTML dashboard in browser")) {
            Write-Host "`n🌐 Opening HTML dashboard in browser..." -ForegroundColor Cyan
            $opened = Open-HTMLDashboard -FilePath $htmlDashboardPath
            if (-not $opened) {
                Write-Host "⚠️  Could not open dashboard automatically. Please open manually: $htmlDashboardPath" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n🌐 [WhatIf] Would open HTML dashboard in browser: $htmlDashboardPath" -ForegroundColor Yellow
        }
    }

    exit 0

} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Dashboard generation failed: $_" -Data @{ Exception = $errorMsg }
    exit 1
}