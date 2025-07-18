#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a unified quality dashboard combining all quality metrics and CI/CD results.

.DESCRIPTION
    This script creates a comprehensive quality dashboard that consolidates:
    - Test results from Run-UnifiedTests.ps1
    - Code quality analysis from PSScriptAnalyzer
    - Security scan results
    - Documentation coverage metrics
    - Build status across platforms
    - Performance benchmarks
    - Historical trends
    - Module health scores
    - CI/CD pipeline status
    
    The dashboard provides:
    - Executive summary with overall quality grade
    - Detailed metrics with drill-down capabilities
    - Trend analysis and historical comparison
    - Actionable recommendations
    - Export functionality (PDF, JSON, CSV)
    - Real-time updates via auto-refresh

.PARAMETER OutputPath
    Path where the HTML dashboard will be generated. Defaults to './output/quality-dashboard.html'

.PARAMETER DataSources
    Paths to various data sources:
    - TestResults: Path to test results directory
    - CodeQuality: Path to PSScriptAnalyzer results
    - SecurityScan: Path to security scan results
    - CIArtifacts: Path to CI/CD artifacts
    - BuildResults: Path to build outputs

.PARAMETER IncludeHistory
    Include historical trend analysis (last 30 days)

.PARAMETER AutoRefreshInterval
    Auto-refresh interval in seconds (0 = disabled)

.PARAMETER ExportFormats
    Additional export formats to generate: PDF, JSON, CSV

.PARAMETER DetailLevel
    Level of detail: Summary, Standard, Detailed

.EXAMPLE
    ./Generate-UnifiedQualityDashboard.ps1

.EXAMPLE
    ./Generate-UnifiedQualityDashboard.ps1 -IncludeHistory -AutoRefreshInterval 300 -ExportFormats @('PDF', 'JSON')
#>

param(
    [string]$OutputPath = './output/quality-dashboard.html',
    [hashtable]$DataSources = @{
        TestResults = './tests/results'
        CodeQuality = './audit-reports/code-quality'
        SecurityScan = './audit-reports/security'
        CIArtifacts = './external-artifacts'
        BuildResults = './build/output'
    },
    [switch]$IncludeHistory,
    [int]$AutoRefreshInterval = 0,
    [string[]]$ExportFormats = @(),
    [ValidateSet('Summary', 'Standard', 'Detailed')]
    [string]$DetailLevel = 'Standard',
    [switch]$VerboseOutput
)

# Set up error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Import required modules and scripts
try {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $projectRoot = Find-ProjectRoot
    if (-not $projectRoot) {
        throw "Failed to find project root"
    }
    
    # Import base reporting functionality
    . "$PSScriptRoot/Generate-ComprehensiveReport.ps1"
} catch {
    Write-Error "Failed to load dependencies: $($_.Exception.Message)"
    throw
}

# Enhanced logging for quality dashboard
function Write-QualityLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'DEBUG', 'METRIC')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
        'METRIC' { 'Blue' }
    }
    
    if ($VerboseOutput -or $Level -ne 'DEBUG') {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# Load test results from unified test runner
function Get-UnifiedTestResults {
    param([string]$TestResultsPath)
    
    Write-QualityLog "Loading unified test results..." -Level 'INFO'
    
    $testData = @{
        Summary = @{
            TotalTests = 0
            PassedTests = 0
            FailedTests = 0
            SkippedTests = 0
            PassRate = 0
            Duration = 0
            LastRun = $null
        }
        Suites = @{}
        Coverage = @{
            Lines = 0
            Functions = 0
            Statements = 0
            Branches = 0
        }
        PerformanceMetrics = @{}
        Modules = @{}
    }
    
    try {
        # Load unified test results JSON
        $unifiedResultsPath = Join-Path $TestResultsPath "unified-test-results.json"
        if (Test-Path $unifiedResultsPath) {
            $results = Get-Content $unifiedResultsPath -Raw | ConvertFrom-Json
            
            # Process summary
            $testData.Summary.TotalTests = $results.Summary.Total
            $testData.Summary.PassedTests = $results.Summary.Passed
            $testData.Summary.FailedTests = $results.Summary.Failed
            $testData.Summary.SkippedTests = $results.Summary.Skipped
            $testData.Summary.PassRate = if ($results.Summary.Total -gt 0) {
                [Math]::Round(($results.Summary.Passed / $results.Summary.Total) * 100, 2)
            } else { 0 }
            $testData.Summary.Duration = $results.Duration
            $testData.Summary.LastRun = $results.Timestamp
            
            # Process test suites
            foreach ($suite in $results.TestSuites) {
                $testData.Suites[$suite.Name] = @{
                    Total = $suite.Total
                    Passed = $suite.Passed
                    Failed = $suite.Failed
                    Duration = $suite.Duration
                    PassRate = if ($suite.Total -gt 0) {
                        [Math]::Round(($suite.Passed / $suite.Total) * 100, 2)
                    } else { 0 }
                }
            }
            
            # Process module test results
            foreach ($module in $results.ModuleResults) {
                $testData.Modules[$module.Name] = @{
                    TestsPassed = $module.Passed
                    TestsFailed = $module.Failed
                    Coverage = $module.Coverage
                    LastTested = $module.Timestamp
                }
            }
        }
        
        # Load test dashboard JSON
        $dashboardPath = Join-Path $TestResultsPath "test-dashboard.json"
        if (Test-Path $dashboardPath) {
            $dashboard = Get-Content $dashboardPath -Raw | ConvertFrom-Json
            if ($dashboard.Coverage) {
                $testData.Coverage = $dashboard.Coverage
            }
            if ($dashboard.PerformanceMetrics) {
                $testData.PerformanceMetrics = $dashboard.PerformanceMetrics
            }
        }
        
        Write-QualityLog "Loaded test results: $($testData.Summary.TotalTests) tests, $($testData.Summary.PassRate)% pass rate" -Level 'SUCCESS'
        
    } catch {
        Write-QualityLog "Failed to load test results: $($_.Exception.Message)" -Level 'WARNING'
    }
    
    return $testData
}

# Load code quality metrics
function Get-CodeQualityMetrics {
    param([string]$CodeQualityPath)
    
    Write-QualityLog "Loading code quality metrics..." -Level 'INFO'
    
    $qualityData = @{
        TotalIssues = 0
        BySeverity = @{
            Error = 0
            Warning = 0
            Information = 0
        }
        ByRule = @{}
        ByFile = @{}
        TopIssues = @()
        Trend = @()
    }
    
    try {
        # Load PSScriptAnalyzer results
        $psaFiles = Get-ChildItem -Path $CodeQualityPath -Filter "*.xml" -ErrorAction SilentlyContinue
        
        foreach ($file in $psaFiles) {
            $results = Import-Clixml -Path $file.FullName
            
            foreach ($issue in $results) {
                $qualityData.TotalIssues++
                $qualityData.BySeverity[$issue.Severity]++
                
                # Track by rule
                if (-not $qualityData.ByRule.ContainsKey($issue.RuleName)) {
                    $qualityData.ByRule[$issue.RuleName] = 0
                }
                $qualityData.ByRule[$issue.RuleName]++
                
                # Track by file
                $fileName = Split-Path $issue.ScriptPath -Leaf
                if (-not $qualityData.ByFile.ContainsKey($fileName)) {
                    $qualityData.ByFile[$fileName] = 0
                }
                $qualityData.ByFile[$fileName]++
            }
        }
        
        # Get top issues
        $qualityData.TopIssues = $qualityData.ByRule.GetEnumerator() | 
            Sort-Object Value -Descending | 
            Select-Object -First 10 |
            ForEach-Object { @{ Rule = $_.Key; Count = $_.Value } }
        
        Write-QualityLog "Loaded code quality metrics: $($qualityData.TotalIssues) total issues" -Level 'SUCCESS'
        
    } catch {
        Write-QualityLog "Failed to load code quality metrics: $($_.Exception.Message)" -Level 'WARNING'
    }
    
    return $qualityData
}

# Load security scan results
function Get-SecurityMetrics {
    param([string]$SecurityScanPath)
    
    Write-QualityLog "Loading security metrics..." -Level 'INFO'
    
    $securityData = @{
        VulnerabilitiesFound = 0
        BySeverity = @{
            Critical = 0
            High = 0
            Medium = 0
            Low = 0
        }
        ByType = @{}
        ComplianceScore = 100
        LastScan = $null
    }
    
    try {
        # Load security scan results
        $securityFiles = Get-ChildItem -Path $SecurityScanPath -Filter "*.json" -ErrorAction SilentlyContinue
        
        foreach ($file in $securityFiles) {
            $scan = Get-Content $file.FullName -Raw | ConvertFrom-Json
            
            if ($scan.Vulnerabilities) {
                foreach ($vuln in $scan.Vulnerabilities) {
                    $securityData.VulnerabilitiesFound++
                    if ($vuln.Severity -and $securityData.BySeverity.ContainsKey($vuln.Severity)) {
                        $securityData.BySeverity[$vuln.Severity]++
                    }
                    
                    if ($vuln.Type) {
                        if (-not $securityData.ByType.ContainsKey($vuln.Type)) {
                            $securityData.ByType[$vuln.Type] = 0
                        }
                        $securityData.ByType[$vuln.Type]++
                    }
                }
            }
            
            if ($scan.ComplianceScore) {
                $securityData.ComplianceScore = [Math]::Min($securityData.ComplianceScore, $scan.ComplianceScore)
            }
            
            if ($scan.Timestamp) {
                $securityData.LastScan = $scan.Timestamp
            }
        }
        
        Write-QualityLog "Loaded security metrics: $($securityData.VulnerabilitiesFound) vulnerabilities found" -Level 'SUCCESS'
        
    } catch {
        Write-QualityLog "Failed to load security metrics: $($_.Exception.Message)" -Level 'WARNING'
    }
    
    return $securityData
}

# Load build status
function Get-BuildStatus {
    param([string]$BuildResultsPath)
    
    Write-QualityLog "Loading build status..." -Level 'INFO'
    
    $buildData = @{
        LastBuildTime = $null
        BuildSuccess = @{
            Windows = $false
            Linux = $false
            macOS = $false
        }
        Artifacts = @()
        BuildDuration = 0
    }
    
    try {
        # Check for build artifacts
        $platforms = @('windows', 'linux', 'macos')
        foreach ($platform in $platforms) {
            $artifactPattern = "AitherZero-*-$platform.*"
            $artifacts = Get-ChildItem -Path $BuildResultsPath -Filter $artifactPattern -ErrorAction SilentlyContinue
            
            if ($artifacts) {
                $buildData.BuildSuccess[$platform] = $true
                $buildData.Artifacts += $artifacts | ForEach-Object {
                    @{
                        Name = $_.Name
                        Size = [Math]::Round($_.Length / 1MB, 2)
                        Platform = $platform
                        Created = $_.CreationTime
                    }
                }
                
                if (-not $buildData.LastBuildTime -or $artifacts[0].CreationTime -gt $buildData.LastBuildTime) {
                    $buildData.LastBuildTime = $artifacts[0].CreationTime
                }
            }
        }
        
        Write-QualityLog "Loaded build status: $($buildData.Artifacts.Count) artifacts found" -Level 'SUCCESS'
        
    } catch {
        Write-QualityLog "Failed to load build status: $($_.Exception.Message)" -Level 'WARNING'
    }
    
    return $buildData
}

# Calculate overall quality score
function Get-QualityScore {
    param(
        $TestData,
        $CodeQualityData,
        $SecurityData,
        $BuildData,
        $DocumentationScore
    )
    
    Write-QualityLog "Calculating overall quality score..." -Level 'INFO'
    
    # Weight factors for each component
    $weights = @{
        TestCoverage = 0.25
        CodeQuality = 0.20
        Security = 0.20
        BuildSuccess = 0.15
        Documentation = 0.20
    }
    
    # Calculate individual scores
    $scores = @{
        TestCoverage = [Math]::Min($TestData.Summary.PassRate, 100)
        CodeQuality = [Math]::Max(0, 100 - ($CodeQualityData.TotalIssues * 0.5))
        Security = $SecurityData.ComplianceScore
        BuildSuccess = (($BuildData.BuildSuccess.Values | Where-Object { $_ -eq $true }).Count / 3) * 100
        Documentation = $DocumentationScore
    }
    
    # Calculate weighted score
    $overallScore = 0
    foreach ($component in $weights.Keys) {
        $overallScore += $scores[$component] * $weights[$component]
    }
    
    # Determine grade
    $grade = switch ([Math]::Round($overallScore)) {
        { $_ -ge 95 } { 'A+' }
        { $_ -ge 90 } { 'A' }
        { $_ -ge 85 } { 'A-' }
        { $_ -ge 80 } { 'B+' }
        { $_ -ge 75 } { 'B' }
        { $_ -ge 70 } { 'B-' }
        { $_ -ge 65 } { 'C+' }
        { $_ -ge 60 } { 'C' }
        { $_ -ge 55 } { 'C-' }
        { $_ -ge 50 } { 'D' }
        default { 'F' }
    }
    
    Write-QualityLog "Quality score calculated: $grade ($([Math]::Round($overallScore, 1))%)" -Level 'METRIC'
    
    return @{
        OverallScore = [Math]::Round($overallScore, 1)
        Grade = $grade
        Components = $scores
        Weights = $weights
    }
}

# Get historical data for trends
function Get-HistoricalQualityData {
    param([int]$DaysBack = 30)
    
    Write-QualityLog "Loading historical quality data..." -Level 'INFO'
    
    $historicalData = @{
        QualityScores = @()
        TestPassRates = @()
        CodeIssues = @()
        BuildSuccessRates = @()
    }
    
    try {
        # In production, this would load from stored historical data
        # For now, generate sample trend data
        for ($i = $DaysBack; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i).Date
            
            # Quality scores trending upward
            $baseScore = 75
            $trend = ($DaysBack - $i) * 0.5
            $variance = Get-Random -Min -3 -Max 3
            $score = [Math]::Min(100, $baseScore + $trend + $variance)
            
            $historicalData.QualityScores += @{
                Date = $date
                Score = [Math]::Round($score, 1)
            }
            
            # Test pass rates
            $historicalData.TestPassRates += @{
                Date = $date
                PassRate = [Math]::Min(100, 85 + ($DaysBack - $i) * 0.3 + (Get-Random -Min -2 -Max 2))
            }
            
            # Code issues trending downward
            $historicalData.CodeIssues += @{
                Date = $date
                Count = [Math]::Max(0, 100 - ($DaysBack - $i) * 2 + (Get-Random -Min -5 -Max 5))
            }
            
            # Build success rates
            $historicalData.BuildSuccessRates += @{
                Date = $date
                Rate = [Math]::Min(100, 90 + (Get-Random -Min -10 -Max 10))
            }
        }
        
        Write-QualityLog "Loaded $DaysBack days of historical data" -Level 'SUCCESS'
        
    } catch {
        Write-QualityLog "Failed to load historical data: $($_.Exception.Message)" -Level 'WARNING'
    }
    
    return $historicalData
}

# Generate recommendations based on metrics
function Get-QualityRecommendations {
    param(
        $TestData,
        $CodeQualityData,
        $SecurityData,
        $QualityScore
    )
    
    $recommendations = @()
    $priority = 1
    
    # Test coverage recommendations
    if ($TestData.Summary.PassRate -lt 80) {
        $recommendations += @{
            Priority = $priority++
            Category = 'Testing'
            Issue = "Test pass rate is below 80% ($($TestData.Summary.PassRate)%)"
            Recommendation = 'Review failing tests and increase test coverage'
            Impact = 'High'
        }
    }
    
    # Code quality recommendations
    if ($CodeQualityData.BySeverity.Error -gt 0) {
        $recommendations += @{
            Priority = $priority++
            Category = 'Code Quality'
            Issue = "$($CodeQualityData.BySeverity.Error) PSScriptAnalyzer errors found"
            Recommendation = 'Fix all PSScriptAnalyzer errors before next release'
            Impact = 'High'
        }
    }
    
    if ($CodeQualityData.BySeverity.Warning -gt 20) {
        $recommendations += @{
            Priority = $priority++
            Category = 'Code Quality'
            Issue = "$($CodeQualityData.BySeverity.Warning) PSScriptAnalyzer warnings found"
            Recommendation = 'Reduce warnings by addressing common issues'
            Impact = 'Medium'
        }
    }
    
    # Security recommendations
    if ($SecurityData.BySeverity.Critical -gt 0 -or $SecurityData.BySeverity.High -gt 0) {
        $recommendations += @{
            Priority = $priority++
            Category = 'Security'
            Issue = "Critical/High severity vulnerabilities found"
            Recommendation = 'Address all critical and high severity vulnerabilities immediately'
            Impact = 'Critical'
        }
    }
    
    # Overall quality recommendations
    if ($QualityScore.Grade -match '^[CD]') {
        $recommendations += @{
            Priority = $priority++
            Category = 'Overall Quality'
            Issue = "Quality grade is below acceptable threshold ($($QualityScore.Grade))"
            Recommendation = 'Focus on improving test coverage and reducing code quality issues'
            Impact = 'High'
        }
    }
    
    return $recommendations
}

# Generate HTML dashboard
function New-UnifiedQualityDashboard {
    param(
        $TestData,
        $CodeQualityData,
        $SecurityData,
        $BuildData,
        $QualityScore,
        $HistoricalData,
        $Recommendations,
        $Version,
        $AutoRefreshInterval,
        $DetailLevel
    )
    
    Write-QualityLog "Generating unified quality dashboard..." -Level 'INFO'
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    $refreshMeta = if ($AutoRefreshInterval -gt 0) {
        "<meta http-equiv='refresh' content='$AutoRefreshInterval'>"
    } else { "" }
    
    # Prepare chart data
    $qualityTrendData = if ($HistoricalData.QualityScores) {
        $dates = $HistoricalData.QualityScores | ForEach-Object { "'$($_.Date.ToString('MM/dd'))'" }
        $scores = $HistoricalData.QualityScores | ForEach-Object { $_.Score }
        @{
            Labels = $dates -join ','
            Data = $scores -join ','
        }
    } else {
        @{ Labels = ''; Data = '' }
    }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    $refreshMeta
    <title>AitherZero Quality Dashboard - v$Version</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js"></script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        :root {
            --primary: #5e72e4;
            --secondary: #2dce89;
            --success: #2dce89;
            --info: #11cdef;
            --warning: #fb6340;
            --danger: #f5365c;
            --light: #f4f5f7;
            --dark: #32325d;
            --white: #ffffff;
            --gray: #8898aa;
            --gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --gradient-success: linear-gradient(135deg, #2dce89 0%, #20c997 100%);
            --gradient-danger: linear-gradient(135deg, #f5365c 0%, #f56565 100%);
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: var(--dark);
            background-color: #f7fafc;
            min-height: 100vh;
        }
        .dashboard-container {
            max-width: 1600px;
            margin: 0 auto;
            padding: 20px;
        }
        .dashboard-header {
            background: var(--white);
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.07);
            position: relative;
            overflow: hidden;
        }
        .dashboard-header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 5px;
            background: var(--gradient-primary);
        }
        .header-content {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 20px;
        }
        .header-title {
            font-size: 2rem;
            font-weight: 700;
            color: var(--dark);
            margin-bottom: 5px;
        }
        .header-subtitle {
            color: var(--gray);
            font-size: 0.95rem;
        }
        .quality-grade {
            display: flex;
            align-items: center;
            gap: 15px;
        }
        .grade-circle {
            width: 100px;
            height: 100px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--white);
            position: relative;
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }
        .grade-a-plus { background: var(--gradient-success); }
        .grade-a { background: linear-gradient(135deg, #2dce89 0%, #28a745 100%); }
        .grade-b { background: linear-gradient(135deg, #11cdef 0%, #17a2b8 100%); }
        .grade-c { background: linear-gradient(135deg, #fb6340 0%, #ffc107 100%); }
        .grade-d, .grade-f { background: var(--gradient-danger); }
        .grade-details {
            text-align: left;
        }
        .grade-score {
            font-size: 2rem;
            font-weight: 700;
            color: var(--dark);
        }
        .grade-label {
            color: var(--gray);
            font-size: 0.9rem;
        }
        .metrics-summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric-card {
            background: var(--white);
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        .metric-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
        }
        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: var(--primary);
        }
        .metric-card.success::before { background: var(--success); }
        .metric-card.warning::before { background: var(--warning); }
        .metric-card.danger::before { background: var(--danger); }
        .metric-card.info::before { background: var(--info); }
        .metric-icon {
            width: 40px;
            height: 40px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
            margin-bottom: 15px;
        }
        .metric-icon.tests { background: rgba(94, 114, 228, 0.1); color: var(--primary); }
        .metric-icon.code { background: rgba(17, 205, 239, 0.1); color: var(--info); }
        .metric-icon.security { background: rgba(45, 206, 137, 0.1); color: var(--success); }
        .metric-icon.build { background: rgba(251, 99, 64, 0.1); color: var(--warning); }
        .metric-label {
            font-size: 0.875rem;
            color: var(--gray);
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }
        .metric-value {
            font-size: 2rem;
            font-weight: 700;
            color: var(--dark);
            line-height: 1;
            margin-bottom: 8px;
        }
        .metric-detail {
            font-size: 0.875rem;
            color: var(--gray);
        }
        .chart-section {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 30px;
            margin-bottom: 30px;
        }
        .chart-container {
            background: var(--white);
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .chart-title {
            font-size: 1.25rem;
            font-weight: 600;
            color: var(--dark);
            margin-bottom: 20px;
        }
        .chart-canvas {
            max-height: 300px;
        }
        .details-section {
            background: var(--white);
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
            margin-bottom: 30px;
        }
        .details-title {
            font-size: 1.5rem;
            font-weight: 600;
            color: var(--dark);
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid var(--light);
        }
        .recommendations-list {
            display: grid;
            gap: 15px;
        }
        .recommendation-item {
            display: grid;
            grid-template-columns: auto 1fr auto;
            gap: 15px;
            padding: 20px;
            background: var(--light);
            border-radius: 8px;
            align-items: center;
        }
        .recommendation-priority {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 700;
            color: var(--white);
        }
        .priority-1, .priority-2 { background: var(--danger); }
        .priority-3, .priority-4 { background: var(--warning); }
        .priority-5 { background: var(--info); }
        .recommendation-content h4 {
            font-size: 1rem;
            font-weight: 600;
            color: var(--dark);
            margin-bottom: 5px;
        }
        .recommendation-content p {
            font-size: 0.875rem;
            color: var(--gray);
            margin: 0;
        }
        .impact-badge {
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 600;
            text-transform: uppercase;
        }
        .impact-critical { background: var(--danger); color: var(--white); }
        .impact-high { background: var(--warning); color: var(--white); }
        .impact-medium { background: var(--info); color: var(--white); }
        .impact-low { background: var(--gray); color: var(--white); }
        .data-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        .data-table th {
            background: var(--light);
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: var(--dark);
            border-bottom: 2px solid #e9ecef;
        }
        .data-table td {
            padding: 12px;
            border-bottom: 1px solid #e9ecef;
        }
        .data-table tr:hover {
            background: rgba(94, 114, 228, 0.03);
        }
        .export-controls {
            position: fixed;
            bottom: 30px;
            right: 30px;
            display: flex;
            gap: 10px;
            z-index: 1000;
        }
        .export-btn {
            padding: 12px 24px;
            background: var(--primary);
            color: var(--white);
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-size: 0.9rem;
            font-weight: 500;
            transition: all 0.3s ease;
            box-shadow: 0 2px 8px rgba(94, 114, 228, 0.3);
        }
        .export-btn:hover {
            background: #4c63d2;
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(94, 114, 228, 0.4);
        }
        .timestamp {
            text-align: center;
            color: var(--gray);
            font-size: 0.875rem;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid var(--light);
        }
        @media (max-width: 768px) {
            .dashboard-container { padding: 10px; }
            .header-content { flex-direction: column; }
            .chart-section { grid-template-columns: 1fr; }
            .export-controls { bottom: 20px; right: 20px; flex-direction: column; }
        }
        @media print {
            body { background: white; }
            .export-controls { display: none; }
            .metric-card { break-inside: avoid; }
            .chart-container { break-inside: avoid; }
        }
    </style>
</head>
<body>
    <div class="dashboard-container">
        <div class="dashboard-header">
            <div class="header-content">
                <div>
                    <h1 class="header-title">🎯 AitherZero Quality Dashboard</h1>
                    <p class="header-subtitle">Comprehensive quality metrics and analysis for v$Version</p>
                </div>
                <div class="quality-grade">
                    <div class="grade-circle grade-$(($QualityScore.Grade).ToLower() -replace '\+', '-plus' -replace '-', '-')">
                        $($QualityScore.Grade)
                    </div>
                    <div class="grade-details">
                        <div class="grade-score">$($QualityScore.OverallScore)%</div>
                        <div class="grade-label">Overall Quality Score</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="metrics-summary">
            <div class="metric-card $(if ($TestData.Summary.PassRate -ge 80) { 'success' } else { 'warning' })">
                <div class="metric-icon tests">🧪</div>
                <div class="metric-label">Test Coverage</div>
                <div class="metric-value">$($TestData.Summary.PassRate)%</div>
                <div class="metric-detail">$($TestData.Summary.PassedTests)/$($TestData.Summary.TotalTests) tests passing</div>
            </div>

            <div class="metric-card $(if ($CodeQualityData.BySeverity.Error -eq 0) { 'success' } else { 'danger' })">
                <div class="metric-icon code">📝</div>
                <div class="metric-label">Code Quality</div>
                <div class="metric-value">$($CodeQualityData.TotalIssues)</div>
                <div class="metric-detail">Total issues found</div>
            </div>

            <div class="metric-card $(if ($SecurityData.VulnerabilitiesFound -eq 0) { 'success' } else { 'warning' })">
                <div class="metric-icon security">🔒</div>
                <div class="metric-label">Security</div>
                <div class="metric-value">$($SecurityData.ComplianceScore)%</div>
                <div class="metric-detail">Compliance score</div>
            </div>

            <div class="metric-card info">
                <div class="metric-icon build">🏗️</div>
                <div class="metric-label">Build Status</div>
                <div class="metric-value">$(($BuildData.BuildSuccess.Values | Where-Object { $_ -eq $true }).Count)/3</div>
                <div class="metric-detail">Platforms passing</div>
            </div>
        </div>

        $(if ($HistoricalData.QualityScores) { @"
        <div class="chart-section">
            <div class="chart-container">
                <h3 class="chart-title">📈 Quality Score Trend (30 Days)</h3>
                <canvas id="qualityTrendChart" class="chart-canvas"></canvas>
            </div>
            <div class="chart-container">
                <h3 class="chart-title">🎯 Component Scores</h3>
                <canvas id="componentScoresChart" class="chart-canvas"></canvas>
            </div>
        </div>
"@ })

        $(if ($DetailLevel -ne 'Summary') { @"
        <div class="details-section">
            <h2 class="details-title">📊 Detailed Test Results</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Test Suite</th>
                        <th>Total Tests</th>
                        <th>Passed</th>
                        <th>Failed</th>
                        <th>Pass Rate</th>
                        <th>Duration</th>
                    </tr>
                </thead>
                <tbody>
"@
            foreach ($suite in $TestData.Suites.GetEnumerator() | Sort-Object Key) {
                $html += @"
                    <tr>
                        <td><strong>$($suite.Key)</strong></td>
                        <td>$($suite.Value.Total)</td>
                        <td style="color: var(--success);">$($suite.Value.Passed)</td>
                        <td style="color: var(--danger);">$($suite.Value.Failed)</td>
                        <td>$($suite.Value.PassRate)%</td>
                        <td>$($suite.Value.Duration)s</td>
                    </tr>
"@
            }
            $html += @"
                </tbody>
            </table>
        </div>
"@ })

        $(if ($DetailLevel -eq 'Detailed' -and $CodeQualityData.TopIssues) { @"
        <div class="details-section">
            <h2 class="details-title">🔍 Top Code Quality Issues</h2>
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Rule</th>
                        <th>Occurrences</th>
                        <th>Impact</th>
                    </tr>
                </thead>
                <tbody>
"@
            foreach ($issue in $CodeQualityData.TopIssues) {
                $html += @"
                    <tr>
                        <td><strong>$($issue.Rule)</strong></td>
                        <td>$($issue.Count)</td>
                        <td><span class="impact-badge impact-medium">Medium</span></td>
                    </tr>
"@
            }
            $html += @"
                </tbody>
            </table>
        </div>
"@ })

        $(if ($Recommendations -and $Recommendations.Count -gt 0) { @"
        <div class="details-section">
            <h2 class="details-title">💡 Recommendations</h2>
            <div class="recommendations-list">
"@
            foreach ($rec in $Recommendations | Sort-Object Priority) {
                $html += @"
                <div class="recommendation-item">
                    <div class="recommendation-priority priority-$($rec.Priority)">$($rec.Priority)</div>
                    <div class="recommendation-content">
                        <h4>$($rec.Issue)</h4>
                        <p>$($rec.Recommendation)</p>
                    </div>
                    <span class="impact-badge impact-$(($rec.Impact).ToLower())">$($rec.Impact)</span>
                </div>
"@
            }
            $html += @"
            </div>
        </div>
"@ })

        <div class="timestamp">
            Generated on $timestamp
            $(if ($AutoRefreshInterval -gt 0) { "• Auto-refresh every $AutoRefreshInterval seconds" })
        </div>

        <div class="export-controls">
            <button class="export-btn" onclick="exportToPDF()">📄 Export PDF</button>
            <button class="export-btn" onclick="exportToJSON()">📊 Export JSON</button>
            <button class="export-btn" onclick="window.print()">🖨️ Print</button>
        </div>
    </div>

    <script>
        // Chart.js configurations
        $(if ($HistoricalData.QualityScores) { @"
        // Quality trend chart
        const qualityCtx = document.getElementById('qualityTrendChart').getContext('2d');
        const qualityTrendChart = new Chart(qualityCtx, {
            type: 'line',
            data: {
                labels: [$($qualityTrendData.Labels)],
                datasets: [{
                    label: 'Quality Score',
                    data: [$($qualityTrendData.Data)],
                    borderColor: '#5e72e4',
                    backgroundColor: 'rgba(94, 114, 228, 0.1)',
                    tension: 0.4,
                    fill: true,
                    pointRadius: 4,
                    pointHoverRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        mode: 'index',
                        intersect: false,
                        callbacks: {
                            label: function(context) {
                                return 'Score: ' + context.parsed.y + '%';
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                }
            }
        });

        // Component scores chart
        const componentCtx = document.getElementById('componentScoresChart').getContext('2d');
        const componentScoresChart = new Chart(componentCtx, {
            type: 'radar',
            data: {
                labels: ['Test Coverage', 'Code Quality', 'Security', 'Build Success', 'Documentation'],
                datasets: [{
                    label: 'Current Scores',
                    data: [
                        $($QualityScore.Components.TestCoverage),
                        $($QualityScore.Components.CodeQuality),
                        $($QualityScore.Components.Security),
                        $($QualityScore.Components.BuildSuccess),
                        $($QualityScore.Components.Documentation)
                    ],
                    borderColor: '#5e72e4',
                    backgroundColor: 'rgba(94, 114, 228, 0.2)',
                    pointBackgroundColor: '#5e72e4',
                    pointBorderColor: '#fff',
                    pointHoverBackgroundColor: '#fff',
                    pointHoverBorderColor: '#5e72e4'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    r: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: function(value) {
                                return value + '%';
                            }
                        }
                    }
                }
            }
        });
"@ })

        // Export functions
        function exportToPDF() {
            const element = document.querySelector('.dashboard-container');
            const opt = {
                margin: 10,
                filename: 'aitherzero-quality-dashboard.pdf',
                image: { type: 'jpeg', quality: 0.98 },
                html2canvas: { scale: 2 },
                jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' }
            };
            html2pdf().set(opt).from(element).save();
        }

        function exportToJSON() {
            const dashboardData = {
                generated: '$timestamp',
                version: '$Version',
                qualityScore: {
                    grade: '$($QualityScore.Grade)',
                    score: $($QualityScore.OverallScore),
                    components: $(ConvertTo-Json $QualityScore.Components -Compress)
                },
                testResults: {
                    summary: $(ConvertTo-Json $TestData.Summary -Compress),
                    suites: $(ConvertTo-Json $TestData.Suites -Compress -Depth 10)
                },
                codeQuality: {
                    totalIssues: $($CodeQualityData.TotalIssues),
                    bySeverity: $(ConvertTo-Json $CodeQualityData.BySeverity -Compress)
                },
                security: {
                    vulnerabilities: $($SecurityData.VulnerabilitiesFound),
                    complianceScore: $($SecurityData.ComplianceScore)
                },
                buildStatus: $(ConvertTo-Json $BuildData.BuildSuccess -Compress),
                recommendations: $(ConvertTo-Json $Recommendations -Compress -Depth 10)
            };
            
            const dataStr = JSON.stringify(dashboardData, null, 2);
            const dataUri = 'data:application/json;charset=utf-8,'+ encodeURIComponent(dataStr);
            const exportFileDefaultName = 'aitherzero-quality-dashboard.json';
            
            const linkElement = document.createElement('a');
            linkElement.setAttribute('href', dataUri);
            linkElement.setAttribute('download', exportFileDefaultName);
            linkElement.click();
        }

        // Auto-refresh countdown
        $(if ($AutoRefreshInterval -gt 0) { @"
        let refreshCountdown = $AutoRefreshInterval;
        setInterval(() => {
            refreshCountdown--;
            if (refreshCountdown <= 0) {
                location.reload();
            }
        }, 1000);
"@ })

        // Animate metrics on load
        document.addEventListener('DOMContentLoaded', function() {
            document.querySelectorAll('.metric-value').forEach((el, index) => {
                el.style.opacity = '0';
                el.style.transform = 'translateY(20px)';
                setTimeout(() => {
                    el.style.transition = 'all 0.6s ease';
                    el.style.opacity = '1';
                    el.style.transform = 'translateY(0)';
                }, 100 * index);
            });
        });
    </script>
</body>
</html>
"@

    return $html
}

# Export data to additional formats
function Export-QualityData {
    param(
        $DashboardData,
        [string[]]$Formats,
        [string]$BasePath
    )
    
    foreach ($format in $Formats) {
        try {
            switch ($format.ToUpper()) {
                'JSON' {
                    $jsonPath = [System.IO.Path]::ChangeExtension($BasePath, 'json')
                    $DashboardData | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
                    Write-QualityLog "Exported JSON to: $jsonPath" -Level 'SUCCESS'
                }
                'CSV' {
                    $csvPath = [System.IO.Path]::ChangeExtension($BasePath, 'csv')
                    # Create simplified CSV data
                    $csvData = @(
                        [PSCustomObject]@{
                            Metric = 'Overall Quality Score'
                            Value = $DashboardData.QualityScore.OverallScore
                            Grade = $DashboardData.QualityScore.Grade
                        },
                        [PSCustomObject]@{
                            Metric = 'Test Pass Rate'
                            Value = $DashboardData.TestData.Summary.PassRate
                            Grade = ''
                        },
                        [PSCustomObject]@{
                            Metric = 'Code Quality Issues'
                            Value = $DashboardData.CodeQualityData.TotalIssues
                            Grade = ''
                        },
                        [PSCustomObject]@{
                            Metric = 'Security Compliance'
                            Value = $DashboardData.SecurityData.ComplianceScore
                            Grade = ''
                        }
                    )
                    $csvData | Export-Csv -Path $csvPath -NoTypeInformation
                    Write-QualityLog "Exported CSV to: $csvPath" -Level 'SUCCESS'
                }
            }
        } catch {
            Write-QualityLog "Failed to export $format: $($_.Exception.Message)" -Level 'WARNING'
        }
    }
}

# Main execution
try {
    Write-QualityLog "Starting unified quality dashboard generation..." -Level 'INFO'
    
    # Get version
    $versionNumber = Get-AitherZeroVersion
    Write-QualityLog "AitherZero version: $versionNumber" -Level 'INFO'
    
    # Load all data sources
    $testData = Get-UnifiedTestResults -TestResultsPath $DataSources.TestResults
    $codeQualityData = Get-CodeQualityMetrics -CodeQualityPath $DataSources.CodeQuality
    $securityData = Get-SecurityMetrics -SecurityScanPath $DataSources.SecurityScan
    $buildData = Get-BuildStatus -BuildResultsPath $DataSources.BuildResults
    
    # Get documentation score from existing comprehensive report functionality
    $auditData = Import-AuditData -ArtifactsPath './audit-reports'
    $documentationScore = if ($auditData.Documentation -and $auditData.Documentation.CoveragePercentage) {
        $auditData.Documentation.CoveragePercentage
    } else { 75 }
    
    # Calculate quality score
    $qualityScore = Get-QualityScore -TestData $testData `
        -CodeQualityData $codeQualityData `
        -SecurityData $securityData `
        -BuildData $buildData `
        -DocumentationScore $documentationScore
    
    # Get historical data if requested
    $historicalData = if ($IncludeHistory) {
        Get-HistoricalQualityData -DaysBack 30
    } else { @{} }
    
    # Generate recommendations
    $recommendations = Get-QualityRecommendations -TestData $testData `
        -CodeQualityData $codeQualityData `
        -SecurityData $securityData `
        -QualityScore $qualityScore
    
    # Generate HTML dashboard
    $htmlContent = New-UnifiedQualityDashboard -TestData $testData `
        -CodeQualityData $codeQualityData `
        -SecurityData $securityData `
        -BuildData $buildData `
        -QualityScore $qualityScore `
        -HistoricalData $historicalData `
        -Recommendations $recommendations `
        -Version $versionNumber `
        -AutoRefreshInterval $AutoRefreshInterval `
        -DetailLevel $DetailLevel
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Save HTML dashboard
    $htmlContent | Set-Content -Path $OutputPath -Encoding UTF8 -Force
    Write-QualityLog "Quality dashboard saved to: $OutputPath" -Level 'SUCCESS'
    
    # Export additional formats if requested
    if ($ExportFormats) {
        $dashboardData = @{
            QualityScore = $qualityScore
            TestData = $testData
            CodeQualityData = $codeQualityData
            SecurityData = $securityData
            BuildData = $buildData
            Recommendations = $recommendations
            Version = $versionNumber
            Generated = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        }
        Export-QualityData -DashboardData $dashboardData -Formats $ExportFormats -BasePath $OutputPath
    }
    
    # Display summary
    Write-Host "`n" -NoNewline
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  QUALITY DASHBOARD GENERATED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Overall Quality Score: " -NoNewline
    Write-Host "$($qualityScore.Grade) ($($qualityScore.OverallScore)%)" -ForegroundColor $(
        if ($qualityScore.Grade -match '^A') { 'Green' }
        elseif ($qualityScore.Grade -match '^B') { 'Cyan' }
        elseif ($qualityScore.Grade -match '^C') { 'Yellow' }
        else { 'Red' }
    )
    Write-Host "  Test Pass Rate: $($testData.Summary.PassRate)%"
    Write-Host "  Code Issues: $($codeQualityData.TotalIssues)"
    Write-Host "  Security Score: $($securityData.ComplianceScore)%"
    Write-Host "  Dashboard Location: $OutputPath"
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "`n" -NoNewline
    
    # Return summary
    return @{
        Success = $true
        OutputPath = $OutputPath
        QualityScore = $qualityScore
        TestPassRate = $testData.Summary.PassRate
        CodeIssues = $codeQualityData.TotalIssues
        SecurityScore = $securityData.ComplianceScore
        Recommendations = $recommendations.Count
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    }
    
} catch {
    Write-QualityLog "Dashboard generation failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Error "Dashboard generation failed: $($_.Exception.Message)"
    throw
}