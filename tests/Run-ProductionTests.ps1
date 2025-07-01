#Requires -Version 7.0
<#
.SYNOPSIS
    Production test runner for AitherZero with comprehensive reporting and GitHub issue integration
.DESCRIPTION
    Executes critical infrastructure tests with automatic GitHub issue creation for failures,
    multi-format reporting (XML, JSON, HTML), and real-time progress tracking.
.PARAMETER TestSuite
    Test suite to run: All, Critical, Unit, Integration, E2E, Performance
.PARAMETER ReportLevel
    Reporting detail level: Minimal, Standard, Detailed, Diagnostic
.PARAMETER CreateIssues
    Automatically create GitHub issues for test failures
.PARAMETER GenerateHTML
    Generate interactive HTML dashboard report
.PARAMETER FailFast
    Stop on first test failure
.PARAMETER CI
    Run in CI/CD mode with optimized settings
.PARAMETER OutputPath
    Directory for test reports (default: ./tests/TestResults)
.PARAMETER IssueRepository
    Target GitHub repository for issues (default: auto-detect)
.PARAMETER DryRun
    Preview issue creation without actually creating them
.EXAMPLE
    ./tests/Run-ProductionTests.ps1 -TestSuite Critical -CreateIssues -GenerateHTML
.EXAMPLE
    ./tests/Run-ProductionTests.ps1 -CI -CreateIssues -ReportLevel Detailed
#>

[CmdletBinding()]
param(
    [ValidateSet('All', 'Critical', 'Unit', 'Integration', 'E2E', 'Performance')]
    [string]$TestSuite = 'Critical',
    
    [ValidateSet('Minimal', 'Standard', 'Detailed', 'Diagnostic')]
    [string]$ReportLevel = 'Standard',
    
    [switch]$CreateIssues,
    [switch]$GenerateHTML,
    [switch]$FailFast,
    [switch]$CI,
    [switch]$ShowCoverage,
    [switch]$UploadArtifacts,
    [switch]$DryRun,
    
    [string]$OutputPath = './tests/TestResults',
    [string]$IssueRepository,
    
    [string[]]$ExcludeTags = @(),
    [string[]]$IncludeTags = @()
)

# Initialize environment
$ErrorActionPreference = 'Stop'
$script:StartTime = Get-Date
$script:TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    Failures = @()
    IssuesCreated = @()
}

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Import required modules
try {
    Import-Module Pester -MinimumVersion 5.0 -Force
    
    # Try to import PatchManager for issue creation
    $patchManagerPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'aither-core/modules/PatchManager'
    if (Test-Path $patchManagerPath) {
        Import-Module $patchManagerPath -Force
        
        # Verify New-PatchIssue function is available
        if (Get-Command New-PatchIssue -ErrorAction SilentlyContinue) {
            $script:PatchManagerAvailable = $true
            Write-Host "✅ PatchManager loaded with New-PatchIssue function available" -ForegroundColor Green
        } else {
            $script:PatchManagerAvailable = $false
            Write-Warning "PatchManager loaded but New-PatchIssue function not available"
            
            # Try to manually import the function
            $patchIssuePath = Join-Path $patchManagerPath 'Public/New-PatchIssue.ps1'
            if (Test-Path $patchIssuePath) {
                . $patchIssuePath
                if (Get-Command New-PatchIssue -ErrorAction SilentlyContinue) {
                    $script:PatchManagerAvailable = $true
                    Write-Host "✅ New-PatchIssue function manually imported" -ForegroundColor Green
                } else {
                    Write-Warning "Failed to manually import New-PatchIssue function"
                }
            }
        }
    } else {
        $script:PatchManagerAvailable = $false
        if ($CreateIssues) {
            Write-Warning "PatchManager not available - GitHub issue creation will be limited"
        }
    }
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# Production logging function
function Write-ProductionLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        [switch]$NoNewline
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
    }
    
    if ($Level -eq 'DEBUG' -and $ReportLevel -notin @('Detailed', 'Diagnostic')) {
        return
    }
    
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color -NoNewline:$NoNewline
    
    # Also log to file
    $logFile = Join-Path $OutputPath "production-test-$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage
}

# Get test paths based on suite
function Get-TestPaths {
    param([string]$Suite)
    
    $basePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'tests'
    
    switch ($Suite) {
        'Critical' { @(Join-Path $basePath 'Critical') }
        'Unit' { @(Join-Path $basePath 'Unit') }
        'Integration' { @(Join-Path $basePath 'Integration') }
        'E2E' { @(Join-Path $basePath 'E2E') }
        'Performance' { @(Join-Path $basePath 'Performance') }
        'All' { @('Critical', 'Unit', 'Integration', 'E2E', 'Performance') | ForEach-Object { Join-Path $basePath $_ } }
    }
}

# Get individual test files for parallel execution
function Get-TestFiles {
    param([string[]]$TestPaths)
    
    $testFiles = @()
    foreach ($path in $TestPaths) {
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -Filter "*.Tests.ps1" -Recurse | Select-Object -ExpandProperty FullName
            $testFiles += $files
        }
    }
    
    return $testFiles
}

# Optimize test file grouping for parallel execution
function Get-OptimalTestGroups {
    param(
        [string[]]$TestFiles,
        [int]$MaxParallel
    )
    
    if ($TestFiles.Count -eq 0) {
        return @()
    }
    
    Write-ProductionLog "Organizing $($TestFiles.Count) test files into optimal groups for $MaxParallel parallel threads" -Level 'INFO'
    
    $groups = @()
    $filesWithSizes = @()
    
    # Analyze file sizes for optimal grouping
    foreach ($file in $TestFiles) {
        $size = if (Test-Path $file) { (Get-Item $file).Length } else { 1KB }
        $filesWithSizes += @{
            Path = $file
            Size = $size
            Name = Split-Path $file -Leaf
        }
    }
    
    # Sort by size (largest first) for better load balancing
    $sortedFiles = $filesWithSizes | Sort-Object Size -Descending
    
    # Group strategy: 
    # - Large files (>50KB) get their own group
    # - Small files are batched together to balance load
    $largeFileThreshold = 50KB
    $groupSizeLimit = 100KB
    
    $currentGroup = @()
    $currentGroupSize = 0
    
    foreach ($fileInfo in $sortedFiles) {
        if ($fileInfo.Size -gt $largeFileThreshold -or ($currentGroupSize + $fileInfo.Size) -gt $groupSizeLimit) {
            # Save current group if it has files
            if ($currentGroup.Count -gt 0) {
                $groups += ,@($currentGroup | ForEach-Object { $_.Path })
                Write-ProductionLog "Created test group with $($currentGroup.Count) files ($(($currentGroup | Measure-Object Size -Sum).Sum / 1KB)KB)" -Level 'DEBUG'
                $currentGroup = @()
                $currentGroupSize = 0
            }
            
            # Large file gets its own group
            if ($fileInfo.Size -gt $largeFileThreshold) {
                $groups += ,@($fileInfo.Path)
                Write-ProductionLog "Large test file in own group: $($fileInfo.Name) ($($fileInfo.Size / 1KB)KB)" -Level 'DEBUG'
            } else {
                $currentGroup += $fileInfo
                $currentGroupSize += $fileInfo.Size
            }
        } else {
            $currentGroup += $fileInfo
            $currentGroupSize += $fileInfo.Size
        }
    }
    
    # Add remaining files
    if ($currentGroup.Count -gt 0) {
        $groups += ,@($currentGroup | ForEach-Object { $_.Path })
        Write-ProductionLog "Final test group with $($currentGroup.Count) files ($(($currentGroup | Measure-Object Size -Sum).Sum / 1KB)KB)" -Level 'DEBUG'
    }
    
    Write-ProductionLog "Created $($groups.Count) test groups for parallel execution" -Level 'SUCCESS'
    return $groups
}

# Detect optimal parallel execution settings
function Get-OptimalParallelSettings {
    param([switch]$CI)
    
    $processorCount = [Environment]::ProcessorCount
    $availableMemoryGB = 8  # Default assumption
    
    try {
        if ($IsWindows) {
            $availableMemoryGB = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
        } elseif ($IsLinux) {
            $memInfo = Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal:' }
            if ($memInfo -match '(\d+)\s+kB') {
                $availableMemoryGB = [math]::Round([int]$matches[1] / 1MB, 1)
            }
        } elseif ($IsMacOS) {
            $memBytes = sysctl -n hw.memsize
            $availableMemoryGB = [math]::Round([long]$memBytes / 1GB, 1)
        }
    } catch {
        Write-ProductionLog "Could not detect system memory, using default (8GB)" -Level 'WARN'
    }
    
    # Calculate optimal settings
    $maxParallel = if ($CI) {
        # CI environments typically have 2-4 cores, be conservative
        [math]::Min($processorCount, 4)
    } else {
        # Local development - more aggressive parallelization
        if ($availableMemoryGB -lt 4) {
            [math]::Max($processorCount / 2, 2)
        } elseif ($availableMemoryGB -lt 8) {
            [math]::Max($processorCount * 0.75, 3)
        } else {
            [math]::Min($processorCount, 8)  # Cap at 8 for diminishing returns
        }
    }
    
    $settings = @{
        MaxParallel = [int]$maxParallel
        ProcessorCount = $processorCount
        AvailableMemoryGB = $availableMemoryGB
        IsCI = $CI.IsPresent
        TimeoutPerGroupSeconds = if ($CI) { 300 } else { 600 }  # 5min CI, 10min local
    }
    
    Write-ProductionLog "Optimal parallel settings: $($settings.MaxParallel) threads (CPU: $($settings.ProcessorCount), RAM: $($settings.AvailableMemoryGB)GB, CI: $($settings.IsCI))" -Level 'INFO'
    return $settings
}

# Import and use dedicated test failure issue creation
function New-TestFailureIssue {
    param(
        [array]$Failures,
        [string]$TestSuite,
        [hashtable]$TestRunInfo
    )
    
    if ($Failures.Count -eq 0) { return }
    
    Write-ProductionLog "Creating GitHub issues for $($Failures.Count) test failures..." -Level 'INFO'
    
    # Import our dedicated test failure issue creation script
    $testFailureIssuePath = Join-Path $PSScriptRoot 'Shared/New-TestFailureIssue.ps1'
    if (Test-Path $testFailureIssuePath) {
        . $testFailureIssuePath
        
        # Prepare test run context
        $testRunContext = @{
            TestSuite = $TestSuite
            TotalTests = $TestRunInfo.TotalCount
            PassedTests = $TestRunInfo.PassedCount
            FailedTests = $TestRunInfo.FailedCount
            PassRate = if ($TestRunInfo.TotalCount -gt 0) { [math]::Round((($TestRunInfo.PassedCount / $TestRunInfo.TotalCount) * 100), 2) } else { 0 }
            Platform = $PSVersionTable.Platform
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            RunId = $TestRunInfo.RunId
            Duration = $TestRunInfo.Duration.TotalSeconds
            ExecutionDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        try {
            # Use our dedicated test failure issue creation with intelligent grouping
            $issueResults = New-TestFailureIssue -TestFailures $Failures -TestSuite $TestSuite -TestRunContext $testRunContext -GroupByFile -DryRun:$DryRun -TargetRepository $IssueRepository
            
            # Add created issues to results
            foreach ($result in $issueResults) {
                if ($result -and $result.Success) {
                    $script:TestResults.IssuesCreated += $result
                    Write-ProductionLog "Created issue: $($result.IssueUrl)" -Level 'SUCCESS'
                }
            }
            
            Write-ProductionLog "Issue creation completed: $($issueResults.Count) issues processed" -Level 'INFO'
        } catch {
            Write-ProductionLog "Error in test failure issue creation: $_" -Level 'ERROR'
        }
    } else {
        Write-ProductionLog "Test failure issue creation script not found: $testFailureIssuePath" -Level 'ERROR'
    }
}

# Generate multi-format reports
function New-TestReports {
    param(
        [object]$TestResult,
        [string]$OutputDirectory,
        [switch]$GenerateHTML
    )
    
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPrefix = "production-test-$TestSuite-$timestamp"
    
    # JSON Report
    Write-ProductionLog "Generating JSON report..." -Level 'INFO'
    $jsonReport = @{
        Summary = @{
            TestSuite = $TestSuite
            ExecutionDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Duration = $TestResult.Duration.TotalSeconds
            TotalTests = $TestResult.TotalCount
            Passed = $TestResult.PassedCount
            Failed = $TestResult.FailedCount
            Skipped = $TestResult.SkippedCount
            PassRate = if ($TestResult.TotalCount -gt 0) { [math]::Round(($TestResult.PassedCount / $TestResult.TotalCount) * 100, 2) } else { 0 }
            Platform = @{
                OS = $PSVersionTable.Platform
                PowerShell = $PSVersionTable.PSVersion.ToString()
                Architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
            }
        }
        Containers = @()
        FailedTests = @()
        IssuesCreated = $script:TestResults.IssuesCreated
    }
    
    # Process containers
    foreach ($container in $TestResult.Containers) {
        if ($container.Type -eq 'File') {
            $containerInfo = @{
                Name = Split-Path $container.Name -Leaf
                Path = $container.Name
                Total = $container.TotalCount
                Passed = $container.PassedCount
                Failed = $container.FailedCount
                Duration = $container.Duration.TotalSeconds
                Result = $container.Result
            }
            $jsonReport.Containers += $containerInfo
        }
    }
    
    # Process failed tests
    foreach ($test in ($TestResult.Tests | Where-Object { $_.Result -eq 'Failed' })) {
        $failureInfo = @{
            Name = $test.Name
            File = $test.ScriptBlock.File
            Line = $test.ScriptBlock.StartPosition.StartLine
            Duration = $test.Duration.TotalMilliseconds
            Error = $test.ErrorRecord.Exception.Message
            StackTrace = $test.ErrorRecord.ScriptStackTrace
            FullError = $test.ErrorRecord.ToString()
        }
        $jsonReport.FailedTests += $failureInfo
    }
    
    $jsonPath = Join-Path $OutputDirectory "$reportPrefix.json"
    $jsonReport | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
    Write-ProductionLog "JSON report saved: $jsonPath" -Level 'SUCCESS'
    
    # HTML Report
    if ($GenerateHTML) {
        Write-ProductionLog "Generating HTML report..." -Level 'INFO'
        $htmlPath = Join-Path $OutputDirectory "$reportPrefix.html"
        New-HtmlTestReport -TestResult $TestResult -JsonReport $jsonReport -OutputPath $htmlPath
        Write-ProductionLog "HTML report saved: $htmlPath" -Level 'SUCCESS'
    }
    
    return @{
        JSON = $jsonPath
        HTML = if ($GenerateHTML) { $htmlPath } else { $null }
    }
}

# Generate detailed code coverage analysis
function New-CoverageAnalysis {
    param(
        [object]$CodeCoverage,
        [string]$OutputPath,
        [string]$Timestamp
    )
    
    $analysisData = @{
        OverallCoverage = [math]::Round(($CodeCoverage.CoveragePercent ?? 0), 2)
        TotalCommands = $CodeCoverage.AnalyzedCommands.Count
        HitCommands = $CodeCoverage.HitCommands.Count
        MissedCommands = $CodeCoverage.MissedCommands.Count
        TopFiles = @()
        LowCoverageFiles = @()
        HtmlReportPath = $null
    }
    
    # Analyze file-level coverage
    $fileAnalysis = @()
    foreach ($file in $CodeCoverage.AnalyzedFiles) {
        $fileCoverage = if ($file.AnalyzedCommands.Count -gt 0) {
            [math]::Round(($file.HitCommands.Count / $file.AnalyzedCommands.Count) * 100, 2)
        } else { 0 }
        
        $fileAnalysis += @{
            Name = Split-Path $file.Path -Leaf
            FullPath = $file.Path
            Coverage = $fileCoverage
            TotalCommands = $file.AnalyzedCommands.Count
            HitCommands = $file.HitCommands.Count
            MissedCommands = $file.MissedCommands.Count
        }
    }
    
    # Get top 5 and low coverage files
    $sortedFiles = $fileAnalysis | Sort-Object Coverage -Descending
    $analysisData.TopFiles = $sortedFiles | Select-Object -First 5
    $analysisData.LowCoverageFiles = $sortedFiles | Where-Object { $_.Coverage -lt 50 } | Select-Object -First 5
    
    # Generate HTML coverage report
    try {
        $htmlPath = Join-Path $OutputPath "coverage-analysis-$Timestamp.html"
        $htmlContent = New-CoverageHtmlReport -AnalysisData $analysisData -FileAnalysis $fileAnalysis
        $htmlContent | Out-File -Path $htmlPath -Encoding UTF8
        $analysisData.HtmlReportPath = $htmlPath
    } catch {
        Write-Warning "Failed to generate HTML coverage report: $_"
    }
    
    return $analysisData
}

# Generate HTML coverage report
function New-CoverageHtmlReport {
    param(
        [hashtable]$AnalysisData,
        [array]$FileAnalysis
    )
    
    $passRateColor = if ($AnalysisData.OverallCoverage -ge 80) { '#28a745' } 
                     elseif ($AnalysisData.OverallCoverage -ge 60) { '#ffc107' } 
                     else { '#dc3545' }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Code Coverage Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; color: #333; line-height: 1.6; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; border-radius: 10px; margin-bottom: 30px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 25px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); text-align: center; }
        .stat-card h3 { font-size: 0.9em; color: #6c757d; margin-bottom: 10px; text-transform: uppercase; }
        .stat-card .value { font-size: 2.5em; font-weight: bold; margin-bottom: 5px; }
        .coverage-circle { width: 120px; height: 120px; margin: 0 auto; background: conic-gradient($passRateColor 0deg, $passRateColor $($AnalysisData.OverallCoverage * 3.6)deg, #e9ecef $($AnalysisData.OverallCoverage * 3.6)deg); border-radius: 50%; display: flex; align-items: center; justify-content: center; }
        .coverage-inner { width: 80px; height: 80px; background: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 1.2em; }
        .section { background: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.05); }
        .section h2 { font-size: 1.8em; margin-bottom: 20px; color: #495057; border-bottom: 2px solid #e9ecef; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px 15px; text-align: left; border-bottom: 1px solid #e9ecef; }
        th { background: #f8f9fa; font-weight: 600; color: #495057; }
        .high-coverage { color: #28a745; } .medium-coverage { color: #ffc107; } .low-coverage { color: #dc3545; }
        .progress-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; transition: width 0.3s ease; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Code Coverage Report</h1>
            <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
        
        <div class="summary-grid">
            <div class="stat-card">
                <h3>Overall Coverage</h3>
                <div class="coverage-circle">
                    <div class="coverage-inner">$($AnalysisData.OverallCoverage)%</div>
                </div>
            </div>
            <div class="stat-card">
                <h3>Total Commands</h3>
                <div class="value" style="color: #17a2b8;">$($AnalysisData.TotalCommands)</div>
            </div>
            <div class="stat-card">
                <h3>Hit Commands</h3>
                <div class="value" style="color: #28a745;">$($AnalysisData.HitCommands)</div>
            </div>
            <div class="stat-card">
                <h3>Missed Commands</h3>
                <div class="value" style="color: #dc3545;">$($AnalysisData.MissedCommands)</div>
            </div>
        </div>
        
        <div class="section">
            <h2>📁 File Coverage Details</h2>
            <table>
                <thead>
                    <tr><th>File</th><th>Coverage</th><th>Hit/Total Commands</th><th>Progress</th></tr>
                </thead>
                <tbody>
"@
    
    foreach ($file in ($FileAnalysis | Sort-Object Coverage -Descending)) {
        $coverageClass = if ($file.Coverage -ge 80) { 'high-coverage' } 
                        elseif ($file.Coverage -ge 60) { 'medium-coverage' } 
                        else { 'low-coverage' }
        $progressColor = if ($file.Coverage -ge 80) { '#28a745' } 
                        elseif ($file.Coverage -ge 60) { '#ffc107' } 
                        else { '#dc3545' }
        
        $html += @"
                    <tr>
                        <td>$($file.Name)</td>
                        <td class="$coverageClass">$($file.Coverage)%</td>
                        <td>$($file.HitCommands)/$($file.TotalCommands)</td>
                        <td>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: $($file.Coverage)%; background: $progressColor;"></div>
                            </div>
                        </td>
                    </tr>
"@
    }
    
    $html += @"
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
"@
    
    return $html
}

# Generate HTML report
function New-HtmlTestReport {
    param(
        $TestResult,
        $JsonReport,
        $OutputPath
    )
    
    $passRate = $JsonReport.Summary.PassRate
    $passRateColor = if ($passRate -ge 95) { '#28a745' } elseif ($passRate -ge 80) { '#ffc107' } else { '#dc3545' }
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Production Test Report - $($JsonReport.Summary.TestSuite)</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f8f9fa;
            color: #333;
            line-height: 1.6;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header .subtitle {
            opacity: 0.9;
            font-size: 1.1em;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            text-align: center;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .stat-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }
        .stat-card h3 {
            font-size: 0.9em;
            color: #6c757d;
            margin-bottom: 10px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
            margin-bottom: 5px;
        }
        .stat-card .label {
            font-size: 0.85em;
            color: #6c757d;
        }
        .passed { color: #28a745; }
        .failed { color: #dc3545; }
        .skipped { color: #ffc107; }
        .info { color: #17a2b8; }
        .section {
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .section h2 {
            font-size: 1.8em;
            margin-bottom: 20px;
            color: #495057;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #e9ecef;
        }
        th {
            background: #f8f9fa;
            font-weight: 600;
            color: #495057;
            text-transform: uppercase;
            font-size: 0.85em;
            letter-spacing: 0.5px;
        }
        tr:hover {
            background-color: #f8f9fa;
        }
        .pass-rate-bar {
            width: 100%;
            height: 30px;
            background: #e9ecef;
            border-radius: 15px;
            overflow: hidden;
            margin: 20px 0;
            position: relative;
        }
        .pass-rate-fill {
            height: 100%;
            background: $passRateColor;
            transition: width 1s ease-out;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
        }
        .failure-item {
            background: #fff5f5;
            border-left: 4px solid #dc3545;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
        }
        .failure-item h4 {
            color: #dc3545;
            margin-bottom: 10px;
        }
        .failure-item pre {
            background: #f8f9fa;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
            font-size: 0.85em;
        }
        .issue-badge {
            display: inline-block;
            background: #007bff;
            color: white;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.85em;
            text-decoration: none;
            margin-left: 10px;
        }
        .issue-badge:hover {
            background: #0056b3;
        }
        .footer {
            text-align: center;
            padding: 30px;
            color: #6c757d;
            font-size: 0.9em;
        }
        .platform-info {
            display: flex;
            gap: 20px;
            flex-wrap: wrap;
            margin-top: 10px;
        }
        .platform-item {
            background: rgba(255,255,255,0.2);
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
        }
        @media (max-width: 768px) {
            .container { padding: 10px; }
            .header { padding: 20px; }
            .header h1 { font-size: 1.8em; }
            .stat-card .value { font-size: 2em; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 AitherZero Production Test Report</h1>
            <div class="subtitle">Test Suite: $($JsonReport.Summary.TestSuite) | Generated: $($JsonReport.Summary.ExecutionDate)</div>
            <div class="platform-info">
                <span class="platform-item">📟 $($JsonReport.Summary.Platform.OS)</span>
                <span class="platform-item">⚡ PowerShell $($JsonReport.Summary.Platform.PowerShell)</span>
                <span class="platform-item">🏗️ $($JsonReport.Summary.Platform.Architecture)</span>
                <span class="platform-item">⏱️ Duration: $([math]::Round($JsonReport.Summary.Duration, 2))s</span>
            </div>
        </div>
        
        <div class="summary-grid">
            <div class="stat-card">
                <h3>Total Tests</h3>
                <div class="value info">$($JsonReport.Summary.TotalTests)</div>
            </div>
            <div class="stat-card">
                <h3>Passed</h3>
                <div class="value passed">$($JsonReport.Summary.Passed)</div>
            </div>
            <div class="stat-card">
                <h3>Failed</h3>
                <div class="value failed">$($JsonReport.Summary.Failed)</div>
            </div>
            <div class="stat-card">
                <h3>Skipped</h3>
                <div class="value skipped">$($JsonReport.Summary.Skipped)</div>
            </div>
            <div class="stat-card">
                <h3>Pass Rate</h3>
                <div class="value" style="color: $passRateColor">$($JsonReport.Summary.PassRate)%</div>
            </div>
            <div class="stat-card">
                <h3>Issues Created</h3>
                <div class="value info">$($JsonReport.IssuesCreated.Count)</div>
            </div>
        </div>
        
        <div class="section">
            <h2>📊 Pass Rate Overview</h2>
            <div class="pass-rate-bar">
                <div class="pass-rate-fill" style="width: $($JsonReport.Summary.PassRate)%">
                    $($JsonReport.Summary.PassRate)%
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>📁 Test File Results</h2>
            <table>
                <thead>
                    <tr>
                        <th>Test File</th>
                        <th>Total</th>
                        <th>Passed</th>
                        <th>Failed</th>
                        <th>Duration</th>
                        <th>Result</th>
                    </tr>
                </thead>
                <tbody>
"@
    
    foreach ($container in $JsonReport.Containers) {
        $resultIcon = if ($container.Failed -eq 0) { "✅" } else { "❌" }
        $htmlContent += @"
                    <tr>
                        <td>$($container.Name)</td>
                        <td>$($container.Total)</td>
                        <td class="passed">$($container.Passed)</td>
                        <td class="failed">$($container.Failed)</td>
                        <td>$([math]::Round($container.Duration, 2))s</td>
                        <td>$resultIcon $($container.Result)</td>
                    </tr>
"@
    }
    
    $htmlContent += @"
                </tbody>
            </table>
        </div>
"@
    
    if ($JsonReport.FailedTests.Count -gt 0) {
        $htmlContent += @"
        <div class="section">
            <h2>❌ Failed Tests Details</h2>
"@
        
        foreach ($failure in $JsonReport.FailedTests) {
            # Find if an issue was created for this failure
            $relatedIssue = $JsonReport.IssuesCreated | Where-Object { $_.Title -match [regex]::Escape($failure.Name) } | Select-Object -First 1
            
            $htmlContent += @"
            <div class="failure-item">
                <h4>$($failure.Name)
                    $(if ($relatedIssue) { "<a href='$($relatedIssue.IssueUrl)' class='issue-badge' target='_blank'>Issue #$($relatedIssue.IssueNumber)</a>" } else { "" })
                </h4>
                <p><strong>File:</strong> $($failure.File):$($failure.Line)</p>
                <p><strong>Duration:</strong> $([math]::Round($failure.Duration, 2))ms</p>
                <p><strong>Error:</strong></p>
                <pre>$([System.Web.HttpUtility]::HtmlEncode($failure.Error))</pre>
                $(if ($ReportLevel -in @('Detailed', 'Diagnostic')) {
                    "<p><strong>Stack Trace:</strong></p><pre>$([System.Web.HttpUtility]::HtmlEncode($failure.StackTrace))</pre>"
                } else { "" })
            </div>
"@
        }
        
        $htmlContent += @"
        </div>
"@
    }
    
    if ($JsonReport.IssuesCreated.Count -gt 0) {
        $htmlContent += @"
        <div class="section">
            <h2>🐛 Created GitHub Issues</h2>
            <table>
                <thead>
                    <tr>
                        <th>Issue</th>
                        <th>Title</th>
                        <th>URL</th>
                    </tr>
                </thead>
                <tbody>
"@
        
        foreach ($issue in $JsonReport.IssuesCreated) {
            $htmlContent += @"
                    <tr>
                        <td>#$($issue.IssueNumber)</td>
                        <td>$($issue.Title)</td>
                        <td><a href="$($issue.IssueUrl)" target="_blank">View Issue</a></td>
                    </tr>
"@
        }
        
        $htmlContent += @"
                </tbody>
            </table>
        </div>
"@
    }
    
    $htmlContent += @"
        <div class="footer">
            <p>AitherZero Production Test Suite | Report generated by Run-ProductionTests.ps1</p>
            <p>© $(Get-Date -Format 'yyyy') Wizzense - Infrastructure Automation Excellence</p>
        </div>
    </div>
    
    <script>
        // Animate pass rate bar on load
        window.addEventListener('load', function() {
            const fillBar = document.querySelector('.pass-rate-fill');
            const targetWidth = fillBar.style.width;
            fillBar.style.width = '0%';
            setTimeout(() => {
                fillBar.style.width = targetWidth;
            }, 100);
        });
    </script>
</body>
</html>
"@
    
    $htmlContent | Out-File -Path $OutputPath -Encoding UTF8
}

# Main execution
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "   🧪 AitherZero Production Test Suite Execution" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

Write-ProductionLog "Starting production test execution..." -Level 'INFO'
Write-ProductionLog "Test Suite: $TestSuite" -Level 'INFO'
Write-ProductionLog "Report Level: $ReportLevel" -Level 'INFO'
Write-ProductionLog "Output Path: $OutputPath" -Level 'INFO'

if ($CreateIssues) {
    Write-ProductionLog "GitHub issue creation: ENABLED$(if ($DryRun) { ' (DRY RUN)' })" -Level 'INFO'
}

if ($CI) {
    Write-ProductionLog "Running in CI/CD mode" -Level 'INFO'
    $FailFast = $true
    $ReportLevel = 'Detailed'
}

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = Get-TestPaths -Suite $TestSuite
$pesterConfig.Run.PassThru = $true
$pesterConfig.Run.Exit = $false
$pesterConfig.Run.SkipRun = $false

# Apply tag filters
if ($ExcludeTags.Count -gt 0) {
    $pesterConfig.Filter.ExcludeTag = $ExcludeTags
}
if ($IncludeTags.Count -gt 0) {
    $pesterConfig.Filter.Tag = $IncludeTags
}

# Configure output
$pesterConfig.Output.Verbosity = switch ($ReportLevel) {
    'Minimal' { 'None' }
    'Standard' { 'Normal' }
    'Detailed' { 'Detailed' }
    'Diagnostic' { 'Diagnostic' }
}

# Configure test results
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "production-test-$TestSuite-$timestamp.xml"
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'

# Configure code coverage if requested
if ($ShowCoverage) {
    Write-ProductionLog "Code coverage analysis: ENABLED" -Level 'INFO'
    $pesterConfig.CodeCoverage.Enabled = $true
    
    # Comprehensive coverage paths
    $pesterConfig.CodeCoverage.Path = @(
        'aither-core/*.ps1',
        'aither-core/modules/*/*.psm1',
        'aither-core/modules/*/Public/*.ps1',
        'aither-core/modules/*/Private/*.ps1',
        'aither-core/shared/*.ps1',
        'Start-AitherZero.ps1'
    )
    
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "coverage-$timestamp.xml"
    $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    $pesterConfig.CodeCoverage.CoveragePercentTarget = 80
    
    # Also create HTML coverage report path for later processing
    $script:CoverageHtmlPath = Join-Path $OutputPath "coverage-$timestamp.html"
}

# Configure error handling
$pesterConfig.Should.ErrorAction = if ($FailFast) { 'Stop' } else { 'Continue' }

# Determine execution strategy (parallel vs sequential)
$parallelSettings = Get-OptimalParallelSettings -CI:$CI
$testPaths = Get-TestPaths -Suite $TestSuite
$testFiles = Get-TestFiles -TestPaths $testPaths

Write-ProductionLog "Test execution strategy analysis:" -Level 'INFO'
Write-ProductionLog "  Test files found: $($testFiles.Count)" -Level 'INFO'
Write-ProductionLog "  Optimal parallel threads: $($parallelSettings.MaxParallel)" -Level 'INFO'
Write-ProductionLog "  System resources: $($parallelSettings.ProcessorCount) cores, $($parallelSettings.AvailableMemoryGB)GB RAM" -Level 'INFO'

# Decide between parallel and sequential execution
$useParallel = $testFiles.Count -gt 1 -and $parallelSettings.MaxParallel -gt 1

if ($useParallel) {
    Write-ProductionLog "⚡ Using PARALLEL execution for optimal performance" -Level 'SUCCESS'
    Write-Host ""
    
    try {
        # Import ParallelExecution module
        $parallelModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'aither-core/modules/ParallelExecution'
        if (-not (Test-Path $parallelModulePath)) {
            throw "ParallelExecution module not found at: $parallelModulePath"
        }
        
        Import-Module $parallelModulePath -Force -ErrorAction Stop
        Write-ProductionLog "ParallelExecution module loaded successfully" -Level 'SUCCESS'
        
        # Group test files for optimal parallel execution
        $testGroups = Get-OptimalTestGroups -TestFiles $testFiles -MaxParallel $parallelSettings.MaxParallel
        
        Write-ProductionLog "Executing $($testGroups.Count) test groups in parallel..." -Level 'INFO'
        Write-Host ""
        
        # Execute tests in parallel using our ParallelExecution module
        $parallelResults = Invoke-ParallelPesterTests -TestPaths $testGroups -ThrottleLimit $parallelSettings.MaxParallel -OutputFormat $pesterConfig.Output.Verbosity
        
        # Merge parallel results into standard Pester result format
        $testResult = Merge-ParallelTestResults -TestResults $parallelResults
        
        # Convert merged results to match expected Pester result structure
        $testResult = [PSCustomObject]@{
            TotalCount = $testResult.TotalTests
            PassedCount = $testResult.Passed
            FailedCount = $testResult.Failed
            SkippedCount = $testResult.Skipped
            Duration = $testResult.TotalTime
            Tests = $testResult.Failures
            Result = if ($testResult.Success) { 'Passed' } else { 'Failed' }
        }
        
        Write-ProductionLog "Parallel test execution completed successfully" -Level 'SUCCESS'
        
    } catch {
        Write-ProductionLog "Parallel execution failed, falling back to sequential: $_" -Level 'WARN'
        $useParallel = $false
    }
}

if (-not $useParallel) {
    Write-ProductionLog "🔄 Using SEQUENTIAL execution (fallback or single file)" -Level 'INFO'
    Write-Host ""
    
    try {
        $testResult = Invoke-Pester -Configuration $pesterConfig
        Write-ProductionLog "Sequential test execution completed" -Level 'SUCCESS'
        
    } catch {
        Write-ProductionLog "Test execution failed: $_" -Level 'ERROR'
        throw
    }
}

# Update global results (compatible with both parallel and sequential)
$script:TestResults.TotalTests = $testResult.TotalCount
$script:TestResults.PassedTests = $testResult.PassedCount
$script:TestResults.FailedTests = $testResult.FailedCount
$script:TestResults.SkippedTests = $testResult.SkippedCount

# Handle test failures from both execution modes
if ($testResult.Tests -and $testResult.Tests.Count -gt 0) {
    # Parallel execution returns failures in Tests property
    $script:TestResults.Failures = $testResult.Tests
} else {
    # Sequential execution - extract failed tests
    $script:TestResults.Failures = if ($testResult.PSObject.Properties['Tests']) {
        $testResult.Tests | Where-Object { $_.Result -eq 'Failed' }
    } else {
        @()
    }
}
    
} catch {
    Write-ProductionLog "Test execution failed: $_" -Level 'ERROR'
    exit 1
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor $(if ($testResult.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "   📊 Test Execution Summary" -ForegroundColor $(if ($testResult.FailedCount -eq 0) { 'Green' } else { 'Red' })
Write-Host "=" * 80 -ForegroundColor $(if ($testResult.FailedCount -eq 0) { 'Green' } else { 'Red' })

# Display summary
$summary = @"
Total Tests:     $($testResult.TotalCount)
Passed:          $($testResult.PassedCount) ✅
Failed:          $($testResult.FailedCount) ❌
Skipped:         $($testResult.SkippedCount) ⏭️
Pass Rate:       $([math]::Round(($testResult.PassedCount / $testResult.TotalCount) * 100, 2))%
Duration:        $([math]::Round($testResult.Duration.TotalSeconds, 2)) seconds
"@

Write-Host $summary

# Generate reports
Write-Host ""
Write-ProductionLog "Generating test reports..." -Level 'INFO'

$reports = New-TestReports -TestResult $testResult -OutputDirectory $OutputPath -GenerateHTML:$GenerateHTML

# Create GitHub issues if requested and there are failures
if ($CreateIssues -and $testResult.FailedCount -gt 0) {
    Write-Host ""
    Write-ProductionLog "Processing test failures for issue creation..." -Level 'INFO'
    
    $runInfo = @{
        RunId = [guid]::NewGuid().ToString()
        TotalCount = $testResult.TotalCount
        PassedCount = $testResult.PassedCount
        FailedCount = $testResult.FailedCount
        Duration = $testResult.Duration
        Output = @($summary)
    }
    
    New-TestFailureIssue -Failures $script:TestResults.Failures -TestSuite $TestSuite -TestRunInfo $runInfo
}

# Display report locations
Write-Host ""
Write-Host "📄 Generated Reports:" -ForegroundColor Green
Write-Host "  • XML Results: $($pesterConfig.TestResult.OutputPath)" -ForegroundColor White
Write-Host "  • JSON Report: $($reports.JSON)" -ForegroundColor White

if ($reports.HTML) {
    Write-Host "  • HTML Report: $($reports.HTML)" -ForegroundColor White
}

if ($ShowCoverage -and $testResult.CodeCoverage) {
    Write-Host "  • Coverage Report: $($pesterConfig.CodeCoverage.OutputPath)" -ForegroundColor White
    
    # Generate detailed coverage analysis
    $coverageData = New-CoverageAnalysis -CodeCoverage $testResult.CodeCoverage -OutputPath $OutputPath -Timestamp $timestamp
    
    if ($coverageData.HtmlReportPath) {
        Write-Host "  • Coverage HTML: $($coverageData.HtmlReportPath)" -ForegroundColor White
    }
    
    # Display coverage summary
    $coveragePercent = [math]::Round(($testResult.CodeCoverage.CoveragePercent ?? 0), 2)
    Write-Host ""
    Write-Host "📈 Code Coverage Analysis:" -ForegroundColor Cyan
    Write-Host "  Overall Coverage: $coveragePercent%" -ForegroundColor $(
        if ($coveragePercent -ge 80) { 'Green' }
        elseif ($coveragePercent -ge 60) { 'Yellow' }
        else { 'Red' }
    )
    
    if ($coverageData.TopFiles) {
        Write-Host "  Top Covered Files:" -ForegroundColor Cyan
        $coverageData.TopFiles | ForEach-Object {
            Write-Host "    • $($_.Name): $($_.Coverage)%" -ForegroundColor White
        }
    }
    
    if ($coverageData.LowCoverageFiles) {
        Write-Host "  Low Coverage Files:" -ForegroundColor Yellow
        $coverageData.LowCoverageFiles | ForEach-Object {
            Write-Host "    • $($_.Name): $($_.Coverage)%" -ForegroundColor Red
        }
    }
}

# Run performance regression analysis
Write-Host ""
Write-ProductionLog "Running performance regression analysis..." -Level 'INFO'

# Import performance testing utilities
$performanceTestPath = Join-Path $PSScriptRoot 'Shared/Test-PerformanceRegression.ps1'
if (Test-Path $performanceTestPath) {
    . $performanceTestPath
    
    try {
        $performanceData = Invoke-PerformanceAnalysis -TestResults $testResult -OutputPath $OutputPath -UpdateBaseline:$CI -GenerateReport:$GenerateHTML
        
        Write-Host "  • Performance Report: $($OutputPath)/performance-baseline-report.html" -ForegroundColor White
        
        # Check for regressions and fail build if critical
        if ($performanceData.OverallStatus -eq 'Regression' -and $CI) {
            $criticalRegressions = $performanceData.Regressions | Where-Object { $_.Change -gt 50 }
            if ($criticalRegressions.Count -gt 0) {
                Write-ProductionLog "Critical performance regressions detected!" -Level 'ERROR'
                foreach ($regression in $criticalRegressions) {
                    Write-ProductionLog "  $($regression.Metric): $($regression.Change)% slower" -Level 'ERROR'
                }
                # Don't fail the build, but log as critical
                Write-ProductionLog "Performance regression detected but not failing build" -Level 'WARN'
            }
        }
    } catch {
        Write-ProductionLog "Performance analysis failed: $_" -Level 'WARN'
    }
} else {
    Write-ProductionLog "Performance testing utilities not found: $performanceTestPath" -Level 'WARN'
}

if ($script:TestResults.IssuesCreated.Count -gt 0) {
    Write-Host ""
    Write-Host "🐛 Created GitHub Issues:" -ForegroundColor Yellow
    foreach ($issue in $script:TestResults.IssuesCreated) {
        Write-Host "  • $($issue.Title) - $($issue.IssueUrl)" -ForegroundColor White
    }
}

# Upload artifacts if in CI mode
if ($CI -and $UploadArtifacts) {
    Write-Host ""
    Write-ProductionLog "Uploading test artifacts..." -Level 'INFO'
    
    # This would be handled by GitHub Actions, but we can prepare the artifacts
    $artifactDir = Join-Path $OutputPath "artifacts-$timestamp"
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
    
    # Copy all reports to artifact directory
    Get-ChildItem $OutputPath -Filter "*$timestamp*" | Copy-Item -Destination $artifactDir
    
    Write-ProductionLog "Artifacts prepared in: $artifactDir" -Level 'SUCCESS'
}

# Final status
Write-Host ""
if ($testResult.FailedCount -eq 0) {
    Write-Host "✅ All tests passed successfully!" -ForegroundColor Green -BackgroundColor DarkGreen
    $exitCode = 0
} else {
    Write-Host "❌ Test failures detected. Review the reports for details." -ForegroundColor Red -BackgroundColor DarkRed
    $exitCode = 1
}

Write-Host ""
Write-ProductionLog "Test execution completed. Total duration: $([math]::Round(((Get-Date) - $script:StartTime).TotalSeconds, 2)) seconds" -Level 'INFO'
Write-Host ""

# Exit with appropriate code
exit $exitCode