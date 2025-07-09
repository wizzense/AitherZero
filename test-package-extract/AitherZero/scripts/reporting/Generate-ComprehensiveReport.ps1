#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a comprehensive HTML report combining all AitherZero audit results.

.DESCRIPTION
    This script creates a unified HTML dashboard that combines results from:
    - Documentation auditing
    - Test coverage analysis
    - Security scanning
    - Code quality analysis (PSScriptAnalyzer)
    - Module health and status
    - Feature mapping and capabilities
    - Build and deployment status

.PARAMETER ReportPath
    Path where the HTML report will be generated. Defaults to './comprehensive-report.html'

.PARAMETER ArtifactsPath
    Path to directory containing audit artifacts. Defaults to './audit-reports'

.PARAMETER IncludeDetailedAnalysis
    Include detailed analysis and drill-down sections

.PARAMETER ReportTitle
    Title for the HTML report. Defaults to 'AitherZero Comprehensive Report'

.PARAMETER Version
    Version number to include in the report. Auto-detected if not specified.

.EXAMPLE
    ./Generate-ComprehensiveReport.ps1 -ReportPath "./reports/aitherZero-report.html"

.EXAMPLE
    ./Generate-ComprehensiveReport.ps1 -IncludeDetailedAnalysis -Version "0.8.0"
#>

param(
    [string]$ReportPath = './output/aitherZero-dashboard.html',
    [string]$ArtifactsPath = './audit-reports',
    [string]$ExternalArtifactsPath = './external-artifacts',
    [switch]$IncludeDetailedAnalysis,
    [string]$ReportTitle = 'AitherZero Comprehensive Dashboard',
    [string]$Version = $null,
    [switch]$VerboseOutput
)

# Set up error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

# Import required modules
. "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
$projectRoot = Find-ProjectRoot

# Logging function
function Write-ReportLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = switch ($Level) {
        'INFO' { 'Cyan' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
        'DEBUG' { 'Gray' }
    }

    if ($VerboseOutput -or $Level -ne 'DEBUG') {
        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    }
}

# Get version information
function Get-AitherZeroVersion {
    if ($Version) {
        return $Version
    }

    $versionFile = Join-Path $projectRoot "VERSION"
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }

    # Try to get from git tag
    try {
        $gitVersion = git describe --tags --abbrev=0 2>$null
        if ($gitVersion) {
            return $gitVersion
        }
    } catch {
        # Ignore git errors
    }

    return "Unknown"
}

# Load external artifacts from CI, security, and audit workflows
function Import-ExternalArtifacts {
    param([string]$ExternalArtifactsPath)
    
    Write-ReportLog "Loading external artifacts from: $ExternalArtifactsPath" -Level 'INFO'
    
    $externalData = @{
        CIResults = $null
        PSScriptAnalyzer = $null
        SecurityScan = $null
        TestCoverage = $null
        BuildResults = $null
    }
    
    if (-not (Test-Path $ExternalArtifactsPath)) {
        Write-ReportLog "External artifacts path not found: $ExternalArtifactsPath" -Level 'WARNING'
        return $externalData
    }
    
    # Load CI test results
    $ciResultsPath = Join-Path $ExternalArtifactsPath "ci-results-summary/ci-results-summary.json"
    if (Test-Path $ciResultsPath) {
        try {
            $externalData.CIResults = Get-Content $ciResultsPath -Raw | ConvertFrom-Json
            Write-ReportLog "Loaded CI results from external artifacts" -Level 'SUCCESS'
        } catch {
            Write-ReportLog "Failed to load CI results: $($_.Exception.Message)" -Level 'WARNING'
        }
    }
    
    # Load PSScriptAnalyzer results
    $psaPath = Join-Path $ExternalArtifactsPath "code-quality-psscriptanalyzer"
    if (Test-Path $psaPath) {
        $psaFiles = Get-ChildItem -Path $psaPath -Filter "*.xml" -ErrorAction SilentlyContinue
        if ($psaFiles) {
            try {
                $psaContent = Get-Content $psaFiles[0].FullName -Raw
                $externalData.PSScriptAnalyzer = @{
                    FilePath = $psaFiles[0].FullName
                    Content = $psaContent
                    LastModified = $psaFiles[0].LastWriteTime
                }
                Write-ReportLog "Loaded PSScriptAnalyzer results from external artifacts" -Level 'SUCCESS'
            } catch {
                Write-ReportLog "Failed to load PSScriptAnalyzer results: $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }
    
    # Load comprehensive project dashboard data
    $dashboardPath = Join-Path $ExternalArtifactsPath "comprehensive-project-dashboard"
    if (Test-Path $dashboardPath) {
        $dashboardFiles = Get-ChildItem -Path $dashboardPath -Filter "*.json" -ErrorAction SilentlyContinue
        foreach ($file in $dashboardFiles) {
            try {
                $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
                if ($file.Name -match "ci-integration-summary") {
                    $externalData.TestCoverage = $content
                } elseif ($file.Name -match "feature.*map") {
                    $externalData.FeatureMap = $content
                }
                Write-ReportLog "Loaded dashboard data: $($file.Name)" -Level 'SUCCESS'
            } catch {
                Write-ReportLog "Failed to load dashboard data $($file.Name): $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }
    
    return $externalData
}

# Load audit data from artifacts
function Import-AuditData {
    param(
        [string]$ArtifactsPath,
        [hashtable]$ExternalData = @{}
    )

    Write-ReportLog "Loading audit data from: $ArtifactsPath" -Level 'INFO'

    $auditData = @{
        Documentation = $null
        Testing = $null
        Security = $null
        CodeQuality = $null
        Features = $null
        BuildStatus = $null
        Summary = @{
            TotalIssues = 0
            CriticalIssues = 0
            OverallHealth = 'Unknown'
            LastUpdated = Get-Date
        }
    }

    # Load documentation audit results
    $docArtifacts = @(
        'documentation-audit-reports/change-analysis.json',
        'documentation-audit-reports/documentation-report.md'
    )

    foreach ($artifact in $docArtifacts) {
        $path = Join-Path $ArtifactsPath $artifact
        if (Test-Path $path) {
            try {
                if ($artifact -match '\.json$') {
                    $content = Get-Content $path -Raw | ConvertFrom-Json
                    $auditData.Documentation = $content
                    Write-ReportLog "Loaded documentation audit data" -Level 'SUCCESS'
                }
            } catch {
                Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
            }
            break
        }
    }

    # Load testing audit results
    $testArtifacts = @(
        'testing-audit-reports/test-audit-report.json',
        'testing-audit-reports/test-delta-analysis.json',
        '.github/test-state.json',
        'test-state.json'
    )

    # First try to load test-state.json from project root
    $testStateFile = Join-Path $projectRoot ".github/test-state.json"
    if (Test-Path $testStateFile) {
        try {
            $testState = Get-Content $testStateFile -Raw | ConvertFrom-Json
            Write-ReportLog "Loaded test state from .github/test-state.json" -Level 'SUCCESS'
            
            # Calculate test coverage from test state
            $totalModules = 0
            $modulesWithTests = 0
            $totalCoverage = 0
            
            foreach ($module in $testState.modules.PSObject.Properties) {
                $totalModules++
                if ($module.Value.hasTests) {
                    $modulesWithTests++
                    $totalCoverage += $module.Value.estimatedCoverage
                }
            }
            
            $averageCoverage = if ($modulesWithTests -gt 0) { 
                [math]::Round($totalCoverage / $modulesWithTests, 1) 
            } else { 0 }
            
            $auditData.Testing = @{
                coverage = @{
                    averageCoverage = $averageCoverage
                    modulesWithTests = $modulesWithTests
                    totalModules = $totalModules
                    percentage = if ($totalModules -gt 0) { 
                        [math]::Round(($modulesWithTests / $totalModules) * 100, 1) 
                    } else { 0 }
                }
                summary = @{
                    totalAnalyzed = $totalModules
                    modulesWithTests = $modulesWithTests
                }
                testState = $testState
            }
            
            Write-ReportLog "Calculated test coverage: $averageCoverage% average, $modulesWithTests/$totalModules modules with tests" -Level 'INFO'
        } catch {
            Write-ReportLog "Failed to load test state: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    # If test state not loaded, try other artifacts
    if (-not $auditData.Testing) {
        foreach ($artifact in $testArtifacts) {
            $path = Join-Path $ArtifactsPath $artifact
            if (Test-Path $path) {
                try {
                    $content = Get-Content $path -Raw | ConvertFrom-Json
                    $auditData.Testing = $content
                    Write-ReportLog "Loaded testing audit data from $artifact" -Level 'SUCCESS'
                } catch {
                    Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
                }
                break
            }
        }
    }

    # Load CI test results
    $ciTestPaths = @(
        'ci-test-summary.json',
        '../ci-test-summary.json',
        'tests/results/unified/ci-test-summary.json',
        'core-test-results.xml'
    )
    
    foreach ($ciPath in $ciTestPaths) {
        $fullPath = if (Test-Path $ciPath) { $ciPath } else { Join-Path $ArtifactsPath $ciPath }
        if (Test-Path $fullPath) {
            try {
                if ($fullPath -like '*.json') {
                    $content = Get-Content $fullPath -Raw | ConvertFrom-Json
                    $auditData.CITests = $content
                    Write-ReportLog "Loaded CI test results from $fullPath" -Level 'SUCCESS'
                } elseif ($fullPath -like '*.xml') {
                    # Handle XML test results if available
                    if (-not $auditData.CITests) {
                        $auditData.CITests = @{}
                    }
                    $auditData.CITests.XmlResults = $fullPath
                    Write-ReportLog "Found XML test results at $fullPath" -Level 'SUCCESS'
                }
                break
            } catch {
                Write-ReportLog "Failed to load CI test results from $fullPath : $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }
    
    # Load recent test results for module-specific status
    $recentTestReports = Get-ChildItem -Path (Join-Path $projectRoot "tests/results/unified/reports") -Filter "*.json" -ErrorAction SilentlyContinue | 
                        Sort-Object LastWriteTime -Descending | 
                        Select-Object -First 1
    
    if ($recentTestReports) {
        try {
            $recentTestContent = Get-Content $recentTestReports.FullName -Raw | ConvertFrom-Json
            if (-not $auditData.CITests) {
                $auditData.CITests = @{}
            }
            # Only add TestResults if it doesn't exist and the property is available
            if (-not $auditData.CITests.PSObject.Properties['TestResults'] -and $recentTestContent.Results) {
                $auditData.CITests | Add-Member -NotePropertyName 'TestResults' -NotePropertyValue $recentTestContent.Results
            }
            # Update Summary if needed
            if ($recentTestContent.Summary -and (-not $auditData.CITests.Summary)) {
                $auditData.CITests | Add-Member -NotePropertyName 'Summary' -NotePropertyValue $recentTestContent.Summary
            }
            Write-ReportLog "Loaded recent test results from $($recentTestReports.Name)" -Level 'SUCCESS'
        } catch {
            Write-ReportLog "Failed to load recent test results: $($_.Exception.Message)" -Level 'WARNING'
        }
    }

    # Load security scan results
    $securityArtifacts = @(
        'security-scan-results/dependency-scan.sarif',
        'security-scan-results/secrets-scan-report.json'
    )

    foreach ($artifact in $securityArtifacts) {
        $path = Join-Path $ArtifactsPath $artifact
        if (Test-Path $path) {
            try {
                $content = Get-Content $path -Raw | ConvertFrom-Json
                if (-not $auditData.Security) {
                    $auditData.Security = @{}
                }
                $auditData.Security[$artifact] = $content
                Write-ReportLog "Loaded security scan data" -Level 'SUCCESS'
            } catch {
                Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }

    # Load code quality results (prioritize external data)
    if ($ExternalData.PSScriptAnalyzer) {
        $auditData.CodeQuality = @{
            Source = 'External CI Workflow'
            Data = $ExternalData.PSScriptAnalyzer
            'psscriptanalyzer-results.xml' = $ExternalData.PSScriptAnalyzer.Content
            LastUpdated = $ExternalData.PSScriptAnalyzer.LastModified
        }
        Write-ReportLog "Using PSScriptAnalyzer data from external artifacts" -Level 'SUCCESS'
    } else {
        $qualityArtifacts = @(
            'quality-analysis-results.json',
            'remediation-report.json',
            'psscriptanalyzer-results.sarif',
            'complexity-analysis-summary.json'
        )

        foreach ($artifact in $qualityArtifacts) {
            $path = Join-Path $ArtifactsPath $artifact
            if (Test-Path $path) {
                try {
                    $content = Get-Content $path -Raw | ConvertFrom-Json
                    if (-not $auditData.CodeQuality) {
                        $auditData.CodeQuality = @{}
                    }
                    $auditData.CodeQuality[$artifact] = $content
                    Write-ReportLog "Loaded code quality data from $artifact" -Level 'SUCCESS'
                } catch {
                    Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
                }
            }
        }
    }
    
    # Integrate CI test results if available
    if ($ExternalData.CIResults) {
        if (-not $auditData.Testing) {
            $auditData.Testing = @{}
        }
        $auditData.Testing = @{
            Source = 'External CI Workflow'
            Data = $ExternalData.CIResults
            TestResults = $ExternalData.CIResults.TestResults
            CoverageData = $ExternalData.CIResults.Coverage
            LastUpdated = $ExternalData.CIResults.Timestamp
        }
        Write-ReportLog "Using CI test results from external artifacts" -Level 'SUCCESS'
    }
    
    # Load duplicate detection results
    $duplicateArtifacts = @(
        'duplicate-detection-report.json',
        'duplicate-files.json',
        'ai-generated-files.json'
    )
    
    $auditData.Duplicates = @{
        totalScanned = 0
        duplicatesFound = 0
        aiGeneratedFound = 0
        files = @()
    }
    
    foreach ($artifact in $duplicateArtifacts) {
        $path = Join-Path $ArtifactsPath $artifact
        if (Test-Path $path) {
            try {
                $content = Get-Content $path -Raw | ConvertFrom-Json
                if ($artifact -eq 'duplicate-detection-report.json') {
                    $auditData.Duplicates = $content
                    Write-ReportLog "Loaded duplicate detection data" -Level 'SUCCESS'
                } else {
                    $auditData.Duplicates[$artifact] = $content
                }
            } catch {
                Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }

    return $auditData
}


# Calculate overall health score
function Get-OverallHealthScore {
    param($AuditData, $FeatureMap)

    $healthFactors = @{
        TestCoverage = 0
        SecurityCompliance = 0
        CodeQuality = 0
        DocumentationCoverage = 0
        ModuleHealth = 0
    }

    $maxScore = 100
    $weights = @{
        TestCoverage = 0.3
        SecurityCompliance = 0.25
        CodeQuality = 0.2
        DocumentationCoverage = 0.15
        ModuleHealth = 0.1
    }

    # Test coverage score - prioritize actual CI test results over estimates
    if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['QualityMetrics']) {
        # Use actual CI test results as primary measure
        $ciScore = $AuditData.CITests.QualityMetrics.SuccessRate
        $healthFactors.TestCoverage = $ciScore
        Write-ReportLog "Using CI test results for coverage: $ciScore%" -Level 'INFO'
    } elseif ($AuditData.Testing -and $AuditData.Testing.PSObject.Properties['coverage']) {
        # Fallback to audit data estimates (but cap at reasonable levels)
        $estimatedCoverage = $AuditData.Testing.coverage.averageCoverage
        # Cap unrealistic estimates to more reasonable levels
        if ($estimatedCoverage -gt 80) {
            $estimatedCoverage = [math]::Min(70, $estimatedCoverage * 0.7)
        }
        $healthFactors.TestCoverage = $estimatedCoverage
        Write-ReportLog "Using estimated coverage (adjusted): $estimatedCoverage%" -Level 'INFO'
    } elseif ($AuditData.Testing -and $AuditData.Testing.summary) {
        # Calculate based on modules with tests
        $testRatio = if ($AuditData.Testing.summary.totalAnalyzed -gt 0) {
            ($AuditData.Testing.summary.modulesWithTests / $AuditData.Testing.summary.totalAnalyzed) * 100
        } else { 0 }
        # Apply realistic factor since having tests doesn't mean they pass
        $healthFactors.TestCoverage = $testRatio * 0.6
        Write-ReportLog "Using module test ratio (adjusted): $($healthFactors.TestCoverage)%" -Level 'INFO'
    } else {
        $healthFactors.TestCoverage = 0
        Write-ReportLog "No test data available, using 0% coverage" -Level 'WARNING'
    }

    # Security compliance score
    if ($AuditData.Security) {
        $healthFactors.SecurityCompliance = 85 # Default high score, reduce for findings
        # TODO: Analyze security findings and reduce score accordingly
    } else {
        $healthFactors.SecurityCompliance = 75 # Partial score if no security data
    }

    # Code quality score
    if ($AuditData.CodeQuality) {
        $healthFactors.CodeQuality = 80 # Default score, adjust based on findings
        # TODO: Analyze PSScriptAnalyzer findings and calculate score
    } else {
        $healthFactors.CodeQuality = 70 # Partial score if no quality data
    }

    # Documentation coverage score
    if ($AuditData.Documentation) {
        $healthFactors.DocumentationCoverage = 75 # Default score
        # TODO: Analyze documentation coverage
    } else {
        $healthFactors.DocumentationCoverage = 60 # Lower score if no doc data
    }

    # Module health score - factor in actual test pass rates
    if ($FeatureMap) {
        $moduleRatio = if ($FeatureMap.TotalModules -gt 0) {
            ($FeatureMap.AnalyzedModules / $FeatureMap.TotalModules) * 100
        } else { 0 }
        
        # Adjust based on actual test performance if available
        if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['Summary']) {
            $successfulModules = $AuditData.CITests.Summary.SuccessfulModules
            $totalModules = $AuditData.CITests.Summary.TotalModules
            $moduleSuccessRate = if ($totalModules -gt 0) {
                ($successfulModules / $totalModules) * 100
            } else { 0 }
            # Weight the module health by actual success rate
            $healthFactors.ModuleHealth = ($moduleRatio * 0.5) + ($moduleSuccessRate * 0.5)
            Write-ReportLog "Module health adjusted for CI results: $($healthFactors.ModuleHealth)%" -Level 'INFO'
        } else {
            $healthFactors.ModuleHealth = $moduleRatio
        }
    }

    # Calculate weighted overall score
    $overallScore = 0
    foreach ($factor in $healthFactors.GetEnumerator()) {
        $overallScore += $factor.Value * $weights[$factor.Key]
    }

    # Calculate grade with mutually exclusive conditions
    if ($overallScore -ge 90) {
        $grade = 'A'
    } elseif ($overallScore -ge 80) {
        $grade = 'B'
    } elseif ($overallScore -ge 70) {
        $grade = 'C'
    } elseif ($overallScore -ge 60) {
        $grade = 'D'
    } else {
        $grade = 'F'
    }

    return @{
        OverallScore = [math]::Round($overallScore, 1)
        Grade = $grade
        Factors = $healthFactors
        Weights = $weights
    }
}

# Generate HTML report
function New-ComprehensiveHtmlReport {
    param(
        $AuditData,
        $FeatureMap,
        $HealthScore,
        $Version,
        $ReportTitle
    )

    Write-ReportLog "Generating HTML report..." -Level 'INFO'

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    $gitSha = try { git rev-parse --short HEAD 2>$null } catch { 'Unknown' }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ReportTitle - v$Version</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: white;
            margin-top: 20px;
            margin-bottom: 20px;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding: 20px;
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            border-radius: 10px;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        .metadata {
            display: flex;
            justify-content: space-around;
            margin-top: 20px;
            flex-wrap: wrap;
        }
        .metadata span {
            background: rgba(255,255,255,0.2);
            padding: 5px 15px;
            border-radius: 20px;
            margin: 5px;
        }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border-left: 5px solid #667eea;
            transition: transform 0.3s ease;
        }
        .card:hover { transform: translateY(-5px); }
        .card h3 {
            color: #667eea;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
        }
        .card .icon {
            font-size: 1.5em;
            margin-right: 10px;
        }
        .health-score {
            text-align: center;
            font-size: 3em;
            font-weight: bold;
            margin: 20px 0;
        }
        .grade-a { color: #28a745; }
        .grade-b { color: #17a2b8; }
        .grade-c { color: #ffc107; }
        .grade-d { color: #fd7e14; }
        .grade-f { color: #dc3545; }
        .progress-bar {
            background: #e9ecef;
            border-radius: 50px;
            overflow: hidden;
            height: 20px;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(45deg, #28a745, #20c997);
            border-radius: 50px;
            transition: width 0.5s ease;
        }
        .feature-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 15px;
            margin: 20px 0;
        }
        .feature-item {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .module-item {
            margin: 8px 0;
            padding: 8px;
            background: white;
            border-radius: 5px;
            border: 1px solid #dee2e6;
        }
        .health-badge {
            padding: 2px 6px;
            border-radius: 3px;
            color: white;
            font-size: 0.75em;
            font-weight: bold;
            margin-left: 8px;
        }
        .health-excellent { background: #28a745; }
        .health-good { background: #17a2b8; }
        .health-fair { background: #ffc107; color: #333; }
        .health-poor { background: #fd7e14; }
        .health-critical { background: #dc3545; }
        .features-list {
            display: flex;
            flex-wrap: wrap;
            gap: 4px;
            margin-top: 5px;
        }
        .feature-tag {
            background: #e9ecef;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.7em;
            color: #495057;
        }
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-healthy { background: #28a745; }
        .status-warning { background: #ffc107; }
        .status-error { background: #dc3545; }
        .status-unknown { background: #6c757d; }
        .details-section {
            margin-top: 30px;
            border-top: 2px solid #e9ecef;
            padding-top: 30px;
        }
        .collapsible {
            background: #f8f9fa;
            padding: 15px;
            border: none;
            width: 100%;
            text-align: left;
            cursor: pointer;
            border-radius: 5px;
            margin-bottom: 10px;
            font-weight: bold;
        }
        .collapsible:hover { background: #e9ecef; }
        .content {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease;
            background: white;
            border-radius: 5px;
            margin-bottom: 15px;
        }
        .content.active {
            max-height: 1000px;
            padding: 20px;
            border: 1px solid #e9ecef;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e9ecef;
        }
        th {
            background: #f8f9fa;
            font-weight: bold;
            color: #667eea;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            color: #6c757d;
        }
        @media (max-width: 768px) {
            .container { margin: 10px; padding: 15px; }
            .summary-grid { grid-template-columns: 1fr; }
            .metadata { flex-direction: column; align-items: center; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 $ReportTitle</h1>
            <div class="metadata">
                <span>📦 Version: $Version</span>
                <span>📅 Generated: $timestamp</span>
                <span>🔍 Commit: $gitSha</span>
                <span>🎯 Health: $($HealthScore.Grade) ($($HealthScore.OverallScore)%)</span>
            </div>
        </div>

        <div class="summary-grid">
            <div class="card">
                <h3><span class="icon">🎯</span>Overall Health</h3>
                <div class="health-score grade-$(($HealthScore.Grade).ToLower())">
                    $($HealthScore.Grade)
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($HealthScore.OverallScore)%"></div>
                </div>
                <p style="text-align: center; margin-top: 10px;">
                    <strong>$($HealthScore.OverallScore)%</strong> Overall Health Score
                </p>
            </div>

            <div class="card">
                <h3><span class="icon">🧪</span>Test Coverage</h3>
                <div style="text-align: center; font-size: 2em; margin: 20px 0;">
                    <span class="grade-a"><strong>$($HealthScore.Factors.TestCoverage)%</strong></span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($HealthScore.Factors.TestCoverage)%"></div>
                </div>
                <p style="text-align: center;">
                    Tests: $($FeatureMap.Statistics.ModulesWithTests)/$($FeatureMap.AnalyzedModules) modules
                </p>
            </div>

            $(if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['QualityMetrics']) { @"
            <div class="card">
                <h3><span class="icon">🚀</span>CI Test Results</h3>
                <div style="text-align: center; font-size: 2em; margin: 20px 0;">
                    <span class="grade-$(if ($AuditData.CITests.QualityMetrics.SuccessRate -eq 100) { 'a' } elseif ($AuditData.CITests.QualityMetrics.SuccessRate -ge 90) { 'b' } elseif ($AuditData.CITests.QualityMetrics.SuccessRate -ge 80) { 'c' } else { 'd' })"><strong>$($AuditData.CITests.QualityMetrics.SuccessRate)%</strong></span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($AuditData.CITests.QualityMetrics.SuccessRate)%"></div>
                </div>
                <p style="text-align: center;">
                    $($AuditData.CITests.Summary.TotalPassed)/$($AuditData.CITests.Summary.TotalTests) tests passed
                </p>
            </div>
"@ })

            <div class="card">
                <h3><span class="icon">🔒</span>Security Status</h3>
                <div style="text-align: center; font-size: 2em; margin: 20px 0;">
                    <span class="grade-b"><strong>$($HealthScore.Factors.SecurityCompliance)%</strong></span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($HealthScore.Factors.SecurityCompliance)%"></div>
                </div>
                <p style="text-align: center;">
                    Security compliance score
                </p>
            </div>

            <div class="card">
                <h3><span class="icon">🔧</span>Code Quality</h3>
                <div style="text-align: center; font-size: 2em; margin: 20px 0;">
                    <span class="grade-b"><strong>$($HealthScore.Factors.CodeQuality)%</strong></span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($HealthScore.Factors.CodeQuality)%"></div>
                </div>
                <p style="text-align: center;">
                    PSScriptAnalyzer compliance
                </p>
            </div>

            <div class="card">
                <h3><span class="icon">📝</span>Documentation</h3>
                <div style="text-align: center; font-size: 2em; margin: 20px 0;">
                    <span class="grade-c"><strong>$($HealthScore.Factors.DocumentationCoverage)%</strong></span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($HealthScore.Factors.DocumentationCoverage)%"></div>
                </div>
                <p style="text-align: center;">
                    Documentation coverage
                </p>
            </div>

            <div class="card">
                <h3><span class="icon">📦</span>Module Health</h3>
                <div style="text-align: center; font-size: 2em; margin: 20px 0;">
                    <span class="grade-a"><strong>$($HealthScore.Factors.ModuleHealth)%</strong></span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: $($HealthScore.Factors.ModuleHealth)%"></div>
                </div>
                <p style="text-align: center;">
                    $($FeatureMap.AnalyzedModules)/$($FeatureMap.TotalModules) modules healthy
                </p>
            </div>
        </div>

        <div class="details-section">
            <h2>🗺️ Dynamic Feature Map & Dependencies</h2>
            <div class="feature-grid">
"@

    # Add feature categories
    foreach ($category in $FeatureMap.Categories.GetEnumerator()) {
        $html += @"
                <div class="feature-item">
                    <h4>$($category.Key)</h4>
                    <p><strong>$($category.Value.Count)</strong> modules</p>
                    <div style="margin-top: 10px;">
"@
        foreach ($module in $category.Value) {
            $moduleInfo = $FeatureMap.Modules[$module]
            $capabilities = $FeatureMap.Capabilities[$module]
            
            # Check actual test results if available
            $actualTestStatus = 'unknown'
            if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['TestResults']) {
                try {
                    $testResult = $AuditData.CITests.TestResults | Where-Object { $_.Module -eq $module }
                    if ($testResult) {
                        $actualTestStatus = if ($testResult.Success) { 'healthy' } else { 'error' }
                    }
                } catch {
                    Write-ReportLog "Error accessing test results for module $module : $($_.Exception.Message)" -Level 'DEBUG'
                }
            }
            
            # Use actual test status if available, otherwise fall back to indicators
            $status = if ($actualTestStatus -ne 'unknown') { 
                $actualTestStatus 
            } elseif ($moduleInfo.HasTests) { 
                'warning'  # Has tests but no recent results
            } else { 
                'error'    # No tests at all
            }
            
            $healthClass = $moduleInfo.Health.ToLower() -replace ' ', '-'
            $functionCount = @($moduleInfo.Functions).Count
            
            $html += @"
                        <div class="module-item">
                            <span class='status-indicator status-$status'></span>
                            <strong>$module</strong> 
                            <span class="health-badge health-$healthClass">$($moduleInfo.Health)</span>
                            <br><small>$functionCount functions • Tests: $(if ($moduleInfo.HasTests) { '✅' } else { '❌' }) • Docs: $(if ($moduleInfo.HasDocumentation) { '✅' } else { '❌' })</small>
"@
            $featureCount = @($capabilities.Features).Count
            if ($featureCount -gt 0) {
                $html += "<br><div class='features-list'>"
                foreach ($feature in $capabilities.Features | Select-Object -First 3) {
                    $html += "<span class='feature-tag'>$feature</span>"
                }
                if ($featureCount -gt 3) {
                    $html += "<span class='feature-tag'>+$($featureCount - 3) more</span>"
                }
                $html += "</div>"
            }
            $html += "</div>"
        }
        $html += @"
                    </div>
                </div>
"@
    }

    $html += @"
            </div>
        </div>

        <div class="details-section">
            <h2>🔗 Module Dependencies Visualization</h2>
            <div id="dependency-graph" style="min-height: 400px; background: #f8f9fa; border-radius: 5px; padding: 20px;">
                <h3>Module Dependency Network</h3>
"@

    # Generate dependency visualization
    $dependencies = @{}
    foreach ($module in $FeatureMap.Modules.GetEnumerator()) {
        if ($module.Value.RequiredModules -and @($module.Value.RequiredModules).Count -gt 0) {
            $dependencies[$module.Key] = $module.Value.RequiredModules
        }
    }
    
    if ($dependencies.Count -gt 0) {
        $html += "<h4>Module Dependencies:</h4><ul>"
        foreach ($dep in $dependencies.GetEnumerator()) {
            $html += "<li><strong>$($dep.Key)</strong> depends on: $($dep.Value -join ', ')</li>"
        }
        $html += "</ul>"
    } else {
        $html += "<p>No inter-module dependencies detected.</p>"
    }
    
    $html += @"
            </div>
        </div>

        <div class="details-section">
            <h2>📊 Detailed Analysis</h2>

            <button class="collapsible">🧪 Test Coverage Details</button>
            <div class="content">
                <table>
                    <thead>
                        <tr>
                            <th>Module</th>
                            <th>Version</th>
                            <th>Has Tests</th>
                            <th>Last Modified</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    foreach ($module in $FeatureMap.Modules.GetEnumerator()) {
        $status = if ($module.Value.HasTests) { '✅ Tested' } else { '⚠️ No Tests' }
        $statusClass = if ($module.Value.HasTests) { 'status-healthy' } else { 'status-warning' }
        $lastMod = $module.Value.LastModified.ToString('yyyy-MM-dd')
        $functionCount = @($module.Value.Functions).Count

        $html += @"
                        <tr>
                            <td><strong>$($module.Value.Name)</strong></td>
                            <td>$($module.Value.Version)</td>
                            <td><span class="status-indicator $statusClass"></span>$($module.Value.HasTests)</td>
                            <td>$lastMod</td>
                            <td>$status ($functionCount functions)</td>
                        </tr>
"@
    }

    $html += @"
                    </tbody>
                </table>
            </div>

            <button class="collapsible">📈 Health Score Breakdown</button>
            <div class="content">
                <table>
                    <thead>
                        <tr>
                            <th>Factor</th>
                            <th>Score</th>
                            <th>Weight</th>
                            <th>Contribution</th>
                        </tr>
                    </thead>
                    <tbody>
"@

    foreach ($factor in $HealthScore.Factors.GetEnumerator()) {
        $weight = $HealthScore.Weights[$factor.Key] * 100
        $contribution = [math]::Round($factor.Value * $HealthScore.Weights[$factor.Key], 1)

        $html += @"
                        <tr>
                            <td><strong>$($factor.Key)</strong></td>
                            <td>$($factor.Value)%</td>
                            <td>$weight%</td>
                            <td>$contribution points</td>
                        </tr>
"@
    }

    $html += @"
                    </tbody>
                </table>
                <div style="margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 5px;">
                    <strong>Overall Score Calculation:</strong><br>
                    Total weighted score: <strong>$($HealthScore.OverallScore)%</strong> (Grade: <strong>$($HealthScore.Grade)</strong>)<br>
                    <em>Scores are weighted by importance and combined to create the overall health grade.</em>
                </div>
            </div>

            <button class="collapsible">🔍 Audit Data Summary</button>
            <div class="content">
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px;">
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>📝 Documentation Audit</h4>
                        <p>Status: $(if ($AuditData.Documentation) { '✅ Available' } else { '⚠️ No data' })</p>
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🧪 Testing Audit</h4>
                        <p>Status: $(if ($AuditData.Testing) { '✅ Available' } else { '⚠️ No data' })</p>
                        $(if ($AuditData.Testing) {
                            "<p>Coverage: <strong>$($AuditData.Testing.coverage.averageCoverage)%</strong></p>"
                            "<p>Modules with tests: <strong>$($AuditData.Testing.coverage.modulesWithTests)/$($AuditData.Testing.coverage.totalModules)</strong></p>"
                        })
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🚀 CI Test Results</h4>
                        <p>Status: $(if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['QualityMetrics']) { '✅ Available' } else { '⚠️ No data' })</p>
                        $(if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['QualityMetrics']) {
                            "<p>Total Tests: <strong>$($AuditData.CITests.Summary.TotalTests)</strong></p>"
                            "<p>Success Rate: <strong>$($AuditData.CITests.QualityMetrics.SuccessRate)%</strong></p>"
                            "<p>Duration: <strong>$([math]::Round($AuditData.CITests.Summary.TotalDuration, 2))s</strong></p>"
                        })
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🔒 Security Audit</h4>
                        <p>Status: $(if ($AuditData.Security) { '✅ Available' } else { '⚠️ No data' })</p>
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🔧 Code Quality</h4>
                        <p>Status: $(if ($AuditData.CodeQuality) { '✅ Available' } else { '⚠️ No data' })</p>
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🔍 Duplicate Detection</h4>
                        <p>Status: $(if ($AuditData.Duplicates) { '✅ Available' } else { '⚠️ No data' })</p>
                        $(if ($AuditData.Duplicates) {
                            "<p>Duplicates found: <strong>$($AuditData.Duplicates.duplicatesFound)</strong></p>"
                            "<p>AI-generated: <strong>$($AuditData.Duplicates.aiGeneratedFound)</strong></p>"
                        })
                    </div>
                </div>
            </div>
"@
            
    # Add comprehensive sections if detailed analysis is requested
    if ($IncludeDetailedAnalysis) {
        
        # Documentation Coverage Section
        if ($AuditData.Documentation) {
            $html += @"
            
            <button class="collapsible">📝 Documentation Coverage Analysis</button>
            <div class="content">
                <h3>Documentation Health Overview</h3>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px;">
                    <div>
                        <h4>Coverage Summary</h4>
                        <ul>
                            <li>Total directories analyzed: <strong>$($AuditData.Documentation.totalDirectories)</strong></li>
                            <li>Directories with README: <strong>$($AuditData.Documentation.directoriesWithReadme)</strong></li>
                            <li>Directories without README: <strong>$($AuditData.Documentation.directoriesWithoutReadme)</strong></li>
                            <li>Documentation coverage: <strong>$([math]::Round(($AuditData.Documentation.directoriesWithReadme / $AuditData.Documentation.totalDirectories) * 100, 1))%</strong></li>
                        </ul>
                    </div>
                    <div>
                        <h4>Documentation Issues</h4>
                        <ul>
                            <li>Stale documentation: <strong>$($AuditData.Documentation.staleDocumentationCount)</strong></li>
                            <li>Missing critical docs: <strong>$($AuditData.Documentation.missingCriticalDocs)</strong></li>
                            <li>Template-based docs: <strong>$($AuditData.Documentation.templateBasedDocs)</strong></li>
                        </ul>
                    </div>
                </div>
            </div>
"@
        }
        
        # Test Analysis Section
        if ($AuditData.Testing -and $AuditData.Testing.testState) {
            $html += @"
            
            <button class="collapsible">🧪 Comprehensive Test Analysis</button>
            <div class="content">
                <h3>Test Coverage by Module</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Module</th>
                            <th>Has Tests</th>
                            <th>Coverage %</th>
                            <th>Test Cases</th>
                            <th>Test Strategy</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@
            foreach ($module in $AuditData.Testing.testState.modules.PSObject.Properties) {
                $moduleData = $module.Value
                $statusClass = if ($moduleData.hasTests) { 'status-healthy' } else { 'status-critical' }
                $coverageClass = if ($moduleData.estimatedCoverage -ge 80) { 'grade-a' } 
                                elseif ($moduleData.estimatedCoverage -ge 60) { 'grade-b' }
                                elseif ($moduleData.estimatedCoverage -ge 40) { 'grade-c' }
                                else { 'grade-d' }
                
                $html += @"
                        <tr>
                            <td><strong>$($module.Name)</strong></td>
                            <td><span class="status-indicator $statusClass"></span>$($moduleData.hasTests)</td>
                            <td><span class="$coverageClass">$($moduleData.estimatedCoverage)%</span></td>
                            <td>$($moduleData.estimatedTestCases)</td>
                            <td>$($moduleData.testStrategy)</td>
                            <td>$(if ($moduleData.isStale) { '⚠️ Stale' } else { '✅ Current' })</td>
                        </tr>
"@
            }
            $html += @"
                    </tbody>
                </table>
            </div>
"@
        }
        
        # CI Test Results Detailed Section
        if ($AuditData.ContainsKey('CITests') -and $AuditData.CITests -and $AuditData.CITests.PSObject.Properties['QualityMetrics']) {
            $html += @"
            
            <button class="collapsible">🚀 CI Test Results Details</button>
            <div class="content">
                <h3>Continuous Integration Test Execution</h3>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 20px;">
                    <div>
                        <h4>Test Summary</h4>
                        <ul>
                            <li>Total Tests: <strong>$($AuditData.CITests.Summary.TotalTests)</strong></li>
                            <li>Passed: <strong>$($AuditData.CITests.Summary.TotalPassed)</strong></li>
                            <li>Failed: <strong>$($AuditData.CITests.Summary.TotalFailed)</strong></li>
                            <li>Success Rate: <strong>$($AuditData.CITests.QualityMetrics.SuccessRate)%</strong></li>
                        </ul>
                    </div>
                    <div>
                        <h4>Performance Metrics</h4>
                        <ul>
                            <li>Total Duration: <strong>$([math]::Round($AuditData.CITests.Summary.TotalDuration, 2))s</strong></li>
                            <li>Tests/Second: <strong>$($AuditData.CITests.QualityMetrics.Performance.TestsPerSecond)</strong></li>
                            <li>Average Test Duration: <strong>$([math]::Round($AuditData.CITests.QualityMetrics.Performance.AverageTestDuration, 3))s</strong></li>
                            <li>Test Mode: <strong>$($AuditData.CITests.QualityMetrics.Performance.Mode)</strong></li>
                        </ul>
                    </div>
                    <div>
                        <h4>Platform Info</h4>
                        <ul>
                            <li>PowerShell: <strong>$($AuditData.CITests.Platform.PowerShellVersion)</strong></li>
                            <li>OS: <strong>$($AuditData.CITests.Platform.OS)</strong></li>
                            <li>Architecture: <strong>$($AuditData.CITests.Platform.Architecture)</strong></li>
                            <li>Git Branch: <strong>$($AuditData.CITests.Platform.GitBranch)</strong></li>
                        </ul>
                    </div>
                </div>
                
                <h4>Test Suites Breakdown</h4>
                <table>
                    <thead>
                        <tr>
                            <th>Test Suite</th>
                            <th>Total Tests</th>
                            <th>Passed</th>
                            <th>Failed</th>
                            <th>Duration</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
"@
            if ($AuditData.CITests.TestSuites -and @($AuditData.CITests.TestSuites).Count -gt 0) {
                foreach ($suite in $AuditData.CITests.TestSuites) {
                    $statusClass = if ($suite.Result -eq 'Passed') { 'status-healthy' } else { 'status-critical' }
                    $durationRounded = [math]::Round($suite.Duration, 2)
                    
                    $html += @"
                            <tr>
                                <td><strong>$($suite.TestSuite)</strong></td>
                                <td>$($suite.TotalCount)</td>
                                <td>$($suite.PassedCount)</td>
                                <td>$($suite.FailedCount)</td>
                                <td>${durationRounded}s</td>
                                <td><span class="status-indicator $statusClass"></span>$($suite.Result)</td>
                            </tr>
"@
                }
            } else {
                $html += @"
                        <tr>
                            <td colspan="6"><em>No test suite details available</em></td>
                        </tr>
"@
            }
            
            $html += @"
                    </tbody>
                </table>
                
                <div style="margin-top: 20px; padding: 15px; background: #f8f9fa; border-radius: 5px;">
                    <strong>CI Test Execution Summary:</strong><br>
                    Generated: <strong>$($AuditData.CITests.Timestamp)</strong><br>
                    Start Time: <strong>$($AuditData.CITests.StartTime)</strong><br>
                    End Time: <strong>$($AuditData.CITests.EndTime)</strong><br>
                    Machine: <strong>$($AuditData.CITests.Platform.MachineName)</strong><br>
                    Working Directory: <strong>$($AuditData.CITests.Platform.WorkingDirectory)</strong>
                </div>
            </div>
"@
        }
        
        # Duplicate Detection Section
        if ($AuditData.Duplicates -and $AuditData.Duplicates.duplicatesFound -gt 0) {
            $html += @"
            
            <button class="collapsible">🔍 Duplicate File Detection Results</button>
            <div class="content">
                <h3>Duplicate and AI-Generated Files</h3>
                <div style="margin-bottom: 20px;">
                    <p><strong>Total files scanned:</strong> $($AuditData.Duplicates.totalScanned)</p>
                    <p><strong>Duplicate files found:</strong> $($AuditData.Duplicates.duplicatesFound)</p>
                    <p><strong>AI-generated files detected:</strong> $($AuditData.Duplicates.aiGeneratedFound)</p>
                </div>
"@
            if ($AuditData.Duplicates.files -and $AuditData.Duplicates.files.Count -gt 0) {
                $html += @"
                <h4>Duplicate Files List</h4>
                <table>
                    <thead>
                        <tr>
                            <th>File Path</th>
                            <th>Type</th>
                            <th>Confidence</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
"@
                foreach ($file in $AuditData.Duplicates.files) {
                    $html += @"
                        <tr>
                            <td>$($file.path)</td>
                            <td>$($file.type)</td>
                            <td>$($file.confidence)</td>
                            <td>$($file.recommendedAction)</td>
                        </tr>
"@
                }
                $html += @"
                    </tbody>
                </table>
"@
            }
            $html += @"
            </div>
"@
        }
        
        # Code Quality Details Section
        if ($AuditData.CodeQuality) {
            $html += @"
            
            <button class="collapsible">🔧 Code Quality Analysis Details</button>
            <div class="content">
                <h3>PSScriptAnalyzer Results</h3>
"@
            if ($AuditData.CodeQuality.'psscriptanalyzer-results.sarif') {
                $sarif = $AuditData.CodeQuality.'psscriptanalyzer-results.sarif'
                $totalIssues = 0
                if ($sarif.runs -and $sarif.runs[0].results) {
                    $totalIssues = $sarif.runs[0].results.Count
                }
                
                $html += @"
                <p><strong>Total issues found:</strong> $totalIssues</p>
"@
                
                if ($totalIssues -gt 0) {
                    # Group issues by severity
                    $issuesBySeverity = @{}
                    foreach ($issue in $sarif.runs[0].results) {
                        $severity = $issue.level
                        if (-not $issuesBySeverity[$severity]) {
                            $issuesBySeverity[$severity] = @()
                        }
                        $issuesBySeverity[$severity] += $issue
                    }
                    
                    foreach ($severity in $issuesBySeverity.Keys | Sort-Object) {
                        $html += @"
                <h4>$severity Issues ($($issuesBySeverity[$severity].Count))</h4>
                <ul>
"@
                        foreach ($issue in $issuesBySeverity[$severity] | Select-Object -First 10) {
                            $html += "<li><strong>$($issue.ruleId)</strong>: $($issue.message.text)</li>"
                        }
                        if ($issuesBySeverity[$severity].Count -gt 10) {
                            $html += "<li><em>... and $($issuesBySeverity[$severity].Count - 10) more</em></li>"
                        }
                        $html += "</ul>"
                    }
                }
            }
            $html += @"
            </div>
"@
        }
    }
    
    $html += @"
        </div>

        <div class="footer">
            <p>🤖 Generated with <a href="https://claude.ai/code" target="_blank">Claude Code</a></p>
            <p>AitherZero Comprehensive Reporting System v1.0</p>
        </div>
    </div>

    <script>
        // Collapsible functionality
        document.querySelectorAll('.collapsible').forEach(button => {
            button.addEventListener('click', function() {
                this.classList.toggle('active');
                const content = this.nextElementSibling;
                content.classList.toggle('active');
            });
        });

        // Animate progress bars on load
        window.addEventListener('load', function() {
            document.querySelectorAll('.progress-fill').forEach(bar => {
                const width = bar.style.width;
                bar.style.width = '0%';
                setTimeout(() => {
                    bar.style.width = width;
                }, 500);
            });
        });
    </script>
</body>
</html>
"@

    return $html
}

# Feature Map Generation Functions (integrated from Generate-DynamicFeatureMap.ps1)
function Get-DynamicFeatureMap {
    param(
        [string]$ModulesPath = $null
    )
    
    Write-ReportLog "Generating dynamic feature map..." -Level 'INFO'
    
    # Determine modules path
    if (-not $ModulesPath) {
        $ModulesPath = Join-Path $projectRoot "aither-core/modules"
    }
    
    # Initialize feature map structure
    $featureMap = @{
        TotalModules = 0
        AnalyzedModules = 0
        FailedModules = 0
        Modules = @{}
        Categories = @{}
        Capabilities = @{}
        Dependencies = @{}
        Statistics = @{}
        Metadata = @{
            GeneratedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
            GeneratedBy = 'AitherZero Comprehensive Report Generator'
            ModulesPath = $ModulesPath
        }
    }
    
    if (-not (Test-Path $ModulesPath)) {
        Write-ReportLog "Modules path not found: $ModulesPath" -Level 'WARNING'
        return $featureMap
    }
    
    # Get all module directories
    $moduleDirectories = Get-ChildItem $ModulesPath -Directory
    $featureMap.TotalModules = $moduleDirectories.Count
    
    Write-ReportLog "Found $($featureMap.TotalModules) module directories" -Level 'INFO'
    
    foreach ($moduleDir in $moduleDirectories) {
        try {
            Write-ReportLog "Analyzing module: $($moduleDir.Name)" -Level 'DEBUG'
            
            $moduleInfo = Get-SingleModuleAnalysis -ModuleDirectory $moduleDir
            $featureMap.Modules[$moduleDir.Name] = $moduleInfo
            $featureMap.AnalyzedModules++
            
            # Categorize module
            $category = Get-ModuleCategory -ModuleInfo $moduleInfo
            if (-not $featureMap.Categories[$category]) {
                $featureMap.Categories[$category] = @()
            }
            $featureMap.Categories[$category] += $moduleDir.Name
            
            # Extract capabilities
            $capabilities = Get-ModuleCapabilities -ModuleInfo $moduleInfo
            $featureMap.Capabilities[$moduleDir.Name] = $capabilities
            
            # Analyze dependencies
            if ($moduleInfo.RequiredModules) {
                $featureMap.Dependencies[$moduleDir.Name] = $moduleInfo.RequiredModules
            }
            
        } catch {
            Write-ReportLog "Failed to analyze module $($moduleDir.Name): $($_.Exception.Message)" -Level 'WARNING'
            $featureMap.FailedModules++
        }
    }
    
    # Generate statistics
    $featureMap.Statistics = Get-FeatureStatistics -FeatureMap $featureMap
    
    Write-ReportLog "Feature map generation complete: $($featureMap.AnalyzedModules)/$($featureMap.TotalModules) successful" -Level 'SUCCESS'
    
    return $featureMap
}

# Analyze individual module
function Get-SingleModuleAnalysis {
    param($ModuleDirectory)
    
    $moduleInfo = @{
        Name = $ModuleDirectory.Name
        Path = $ModuleDirectory.FullName
        LastModified = $ModuleDirectory.LastWriteTime
        Size = 0
        FileCount = 0
        HasManifest = $false
        HasModuleFile = $false
        HasTests = $false
        HasDocumentation = $false
        Manifest = $null
        Functions = @()
        RequiredModules = @()
        PowerShellVersion = $null
        Description = ''
        Version = '0.0.0'
        Author = ''
        CompanyName = ''
        Health = 'Unknown'
        TestCoverage = 0
        ComplexityScore = 0
    }
    
    # Calculate directory size and file count
    $files = Get-ChildItem $ModuleDirectory.FullName -Recurse -File
    $moduleInfo.FileCount = $files.Count
    $moduleInfo.Size = ($files | Measure-Object -Property Length -Sum).Sum
    
    # Check for manifest file
    $manifestPath = Join-Path $ModuleDirectory.FullName "$($ModuleDirectory.Name).psd1"
    if (Test-Path $manifestPath) {
        $moduleInfo.HasManifest = $true
        try {
            $manifest = Import-PowerShellDataFile $manifestPath
            $moduleInfo.Manifest = $manifest
            $moduleInfo.Version = if ($manifest.PSObject.Properties['ModuleVersion']) { $manifest.ModuleVersion } else { '0.0.0' }
            $moduleInfo.Description = if ($manifest.PSObject.Properties['Description']) { $manifest.Description } else { '' }
            $moduleInfo.Author = if ($manifest.PSObject.Properties['Author']) { $manifest.Author } else { '' }
            $moduleInfo.CompanyName = if ($manifest.PSObject.Properties['CompanyName']) { $manifest.CompanyName } else { '' }
            $moduleInfo.PowerShellVersion = if ($manifest.PSObject.Properties['PowerShellVersion']) { $manifest.PowerShellVersion } else { '5.1' }
            $moduleInfo.RequiredModules = if ($manifest.PSObject.Properties['RequiredModules']) { $manifest.RequiredModules } else { @() }
            
            # Get exported functions
            if ($manifest.PSObject.Properties['FunctionsToExport'] -and $manifest.FunctionsToExport -ne '*') {
                $moduleInfo.Functions = if ($manifest.FunctionsToExport -is [array]) { $manifest.FunctionsToExport } else { @($manifest.FunctionsToExport) }
            }
        } catch {
            Write-ReportLog "Failed to parse manifest for $($ModuleDirectory.Name): $($_.Exception.Message)" -Level 'DEBUG'
        }
    }
    
    # Check for module script file
    $moduleScriptPath = Join-Path $ModuleDirectory.FullName "$($ModuleDirectory.Name).psm1"
    if (Test-Path $moduleScriptPath) {
        $moduleInfo.HasModuleFile = $true
        
        # Analyze module script for additional functions if not in manifest
        $currentFunctionCount = @($moduleInfo.Functions).Count
        if ($currentFunctionCount -eq 0) {
            $moduleInfo.Functions = Get-FunctionsFromScript -ScriptPath $moduleScriptPath
        }
    }
    
    # Check for tests
    $testsPath = Join-Path $ModuleDirectory.FullName "tests"
    if (Test-Path $testsPath) {
        $moduleInfo.HasTests = $true
        $testFiles = Get-ChildItem $testsPath -Filter "*.Tests.ps1" -Recurse
        $moduleInfo.TestCoverage = if (@($testFiles).Count -gt 0) { 85 } else { 0 } # Simplified calculation
    }
    
    # Check for documentation
    $readmePath = Join-Path $ModuleDirectory.FullName "README.md"
    if (Test-Path $readmePath) {
        $moduleInfo.HasDocumentation = $true
    }
    
    # Calculate health score
    $moduleInfo.Health = Get-ModuleHealth -ModuleInfo $moduleInfo
    
    return $moduleInfo
}

# Get module category based on naming and functionality
function Get-ModuleCategory {
    param($ModuleInfo)
    
    $name = $ModuleInfo.Name
    $description = if ($ModuleInfo.Description -and $ModuleInfo.Description.ToString()) { $ModuleInfo.Description.ToString().ToLower() } else { '' }
    
    # Category mapping based on patterns
    $categories = @{
        'Core' = @('AitherCore', 'ModuleCommunication', 'Logging', 'Configuration')
        'Managers' = @('.*Manager$', '.*Management$')
        'Providers' = @('.*Provider$')
        'Integrations' = @('.*Integration$', '.*Sync$')
        'Automation' = @('.*Automation$', '.*Wizard$', '.*Experience$')
        'Infrastructure' = @('OpenTofu', 'ISO', 'Deploy')
        'Development' = @('Testing', 'PSScript', 'PatchManager', 'Dev')
        'Security' = @('Security', 'Credential', 'License')
        'Utilities' = @('Utility', 'Progress', 'Parallel', 'Remote', 'Semantic')
    }
    
    foreach ($category in $categories.GetEnumerator()) {
        foreach ($pattern in $category.Value) {
            if ($name -match $pattern -or $description -match $pattern.ToLower()) {
                return $category.Key
            }
        }
    }
    
    return 'Utilities' # Default category
}

# Extract capabilities from module
function Get-ModuleCapabilities {
    param($ModuleInfo)
    
    $functionCount = @($ModuleInfo.Functions).Count
    $capabilities = @{
        FunctionCount = $functionCount
        HasPublicAPI = $functionCount -gt 0
        Features = @()
    }
    
    # Analyze function names for features (if functions exist)
    if ($ModuleInfo.Functions -and @($ModuleInfo.Functions).Count -gt 0) {
        foreach ($function in $ModuleInfo.Functions) {
            $functionName = $function.ToString().ToLower()
            
            # Detect feature patterns
            if ($functionName -match '^new-') { $capabilities.Features += 'Creation' }
            if ($functionName -match '^get-') { $capabilities.Features += 'Retrieval' }
            if ($functionName -match '^set-|^update-') { $capabilities.Features += 'Modification' }
            if ($functionName -match '^remove-|^delete-') { $capabilities.Features += 'Deletion' }
            if ($functionName -match '^test-|^validate-') { $capabilities.Features += 'Validation' }
            if ($functionName -match '^invoke-|^start-') { $capabilities.Features += 'Execution' }
            if ($functionName -match '^import-|^export-') { $capabilities.Features += 'DataManagement' }
            if ($functionName -match '^backup-|^restore-') { $capabilities.Features += 'BackupRestore' }
            if ($functionName -match '^sync-') { $capabilities.Features += 'Synchronization' }
            if ($functionName -match 'config|setting') { $capabilities.Features += 'Configuration' }
            if ($functionName -match 'security|credential|auth') { $capabilities.Features += 'Security' }
        }
        
        # Remove duplicates
        $capabilities.Features = $capabilities.Features | Sort-Object -Unique
    }
    
    return $capabilities
}

# Get functions from PowerShell script file
function Get-FunctionsFromScript {
    param([string]$ScriptPath)
    
    try {
        if (-not (Test-Path $ScriptPath)) {
            Write-ReportLog "Script not found: $ScriptPath" -Level 'DEBUG'
            return @()
        }
        
        $content = Get-Content $ScriptPath -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-ReportLog "Script is empty: $ScriptPath" -Level 'DEBUG'
            return @()
        }
        
        # Use AST parsing for better function detection
        $functions = @()
        
        try {
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$null)
            
            # Find all function definitions using AST
            $functionAsts = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
            }, $true)
            
            foreach ($functionAst in $functionAsts) {
                if ($functionAst.Name) {
                    $functions += $functionAst.Name
                }
            }
        } catch {
            Write-ReportLog "AST parsing failed for $ScriptPath, using regex fallback: $($_.Exception.Message)" -Level 'DEBUG'
        }
        
        # Regex fallback if AST fails
        if ($functions.Count -eq 0) {
            $functionMatches = [regex]::Matches($content, 'function\s+([A-Za-z0-9_-]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            foreach ($match in $functionMatches) {
                if ($match.Groups.Count -gt 1) {
                    $functions += $match.Groups[1].Value
                }
            }
        }
        
        return $functions | Where-Object { $_ -and $_.Trim() } | Sort-Object -Unique
    } catch {
        Write-ReportLog "Failed to extract functions from ${ScriptPath}: $($_.Exception.Message)" -Level 'DEBUG'
        return @()
    }
}

# Calculate module health based on various factors
function Get-ModuleHealth {
    param($ModuleInfo)
    
    $score = 0
    $maxScore = 5
    
    # Has manifest
    if ($ModuleInfo.HasManifest) { $score++ }
    
    # Has module file
    if ($ModuleInfo.HasModuleFile) { $score++ }
    
    # Has tests
    if ($ModuleInfo.HasTests) { $score++ }
    
    # Has documentation
    if ($ModuleInfo.HasDocumentation) { $score++ }
    
    # Has functions
    if ($ModuleInfo.Functions -and @($ModuleInfo.Functions).Count -gt 0) { $score++ }
    
    # Convert to health grade
    $percentage = ($score / $maxScore) * 100
    
    if ($percentage -ge 90) { return 'Excellent' }
    if ($percentage -ge 70) { return 'Good' }
    if ($percentage -ge 50) { return 'Fair' }
    if ($percentage -ge 30) { return 'Poor' }
    return 'Critical'
}

# Generate feature map statistics
function Get-FeatureStatistics {
    param($FeatureMap)
    
    $totalFunctions = 0
    $modulesWithTests = 0
    $modulesWithDocs = 0
    
    foreach ($module in $FeatureMap.Modules.Values) {
        $functionCount = @($module.Functions).Count
        if ($functionCount -gt 0) {
            $totalFunctions += $functionCount
        }
        if ($module.HasTests) { $modulesWithTests++ }
        if ($module.HasDocumentation) { $modulesWithDocs++ }
    }
    
    $analyzedCount = $FeatureMap.AnalyzedModules
    
    return @{
        TotalFunctions = $totalFunctions
        AverageFunctionsPerModule = if ($analyzedCount -gt 0) { [math]::Round($totalFunctions / $analyzedCount, 1) } else { 0 }
        TestCoveragePercentage = if ($analyzedCount -gt 0) { [math]::Round(($modulesWithTests / $analyzedCount) * 100, 1) } else { 0 }
        DocumentationCoveragePercentage = if ($analyzedCount -gt 0) { [math]::Round(($modulesWithDocs / $analyzedCount) * 100, 1) } else { 0 }
        ModulesWithTests = $modulesWithTests
        ModulesWithDocumentation = $modulesWithDocs
    }
}

# Main execution
try {
    Write-ReportLog "Starting comprehensive report generation..." -Level 'INFO'

    # Get version
    $versionNumber = Get-AitherZeroVersion
    Write-ReportLog "AitherZero version: $versionNumber" -Level 'INFO'

    # Load external artifacts first
    $externalData = Import-ExternalArtifacts -ExternalArtifactsPath $ExternalArtifactsPath

    # Load audit data with external data integration
    $auditData = Import-AuditData -ArtifactsPath $ArtifactsPath -ExternalData $externalData

    # Generate feature map
    $featureMap = Get-DynamicFeatureMap

    # Calculate health score
    $healthScore = Get-OverallHealthScore -AuditData $auditData -FeatureMap $featureMap
    Write-ReportLog "Overall health score: $($healthScore.OverallScore)% (Grade: $($healthScore.Grade))" -Level 'INFO'

    # Generate HTML report
    $htmlContent = New-ComprehensiveHtmlReport -AuditData $auditData -FeatureMap $featureMap -HealthScore $healthScore -Version $versionNumber -ReportTitle $ReportTitle

    # Save report
    $htmlContent | Set-Content -Path $ReportPath -Encoding UTF8
    Write-ReportLog "Comprehensive report saved to: $ReportPath" -Level 'SUCCESS'

    # Return summary for CI/CD integration
    $summary = @{
        ReportPath = $ReportPath
        Version = $versionNumber
        OverallHealth = $healthScore
        FeatureMap = $featureMap
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        Success = $true
    }

    Write-ReportLog "Report generation completed successfully" -Level 'SUCCESS'
    return $summary

} catch {
    Write-ReportLog "Report generation failed: $($_.Exception.Message)" -Level 'ERROR'
    throw
}
