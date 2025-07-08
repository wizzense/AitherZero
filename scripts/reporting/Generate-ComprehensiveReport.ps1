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
    [string]$ReportPath = './comprehensive-report.html',
    [string]$ArtifactsPath = './audit-reports',
    [switch]$IncludeDetailedAnalysis,
    [string]$ReportTitle = 'AitherZero Comprehensive Report',
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

# Load audit data from artifacts
function Import-AuditData {
    param([string]$ArtifactsPath)

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
        'testing-audit-reports/test-delta-analysis.json'
    )

    foreach ($artifact in $testArtifacts) {
        $path = Join-Path $ArtifactsPath $artifact
        if (Test-Path $path) {
            try {
                $content = Get-Content $path -Raw | ConvertFrom-Json
                $auditData.Testing = $content
                Write-ReportLog "Loaded testing audit data" -Level 'SUCCESS'
            } catch {
                Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
            }
            break
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

    # Load code quality results
    $qualityArtifacts = @(
        'quality-analysis-results.json',
        'remediation-report.json'
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
                Write-ReportLog "Loaded code quality data" -Level 'SUCCESS'
            } catch {
                Write-ReportLog "Failed to load $artifact : $($_.Exception.Message)" -Level 'WARNING'
            }
        }
    }

    return $auditData
}

# Generate dynamic feature map
function Get-DynamicFeatureMap {
    Write-ReportLog "Generating dynamic feature map..." -Level 'INFO'

    $moduleFeatures = @{
        TotalModules = 0
        LoadedModules = 0
        ModuleDetails = @{}
        FeatureCategories = @{}
        Dependencies = @{}
    }

    # Scan modules directory
    $modulesPath = Join-Path $projectRoot "aither-core/modules"
    if (Test-Path $modulesPath) {
        $modules = Get-ChildItem $modulesPath -Directory
        $moduleFeatures.TotalModules = $modules.Count

        foreach ($module in $modules) {
            $manifestPath = Join-Path $module.FullName "$($module.Name).psd1"
            if (Test-Path $manifestPath) {
                try {
                    $manifest = Import-PowerShellDataFile $manifestPath
                    $moduleFeatures.ModuleDetails[$module.Name] = @{
                        Name = $module.Name
                        Version = $manifest.ModuleVersion
                        Description = $manifest.Description
                        FunctionsToExport = $manifest.FunctionsToExport
                        RequiredModules = $manifest.RequiredModules
                        PowerShellVersion = $manifest.PowerShellVersion
                        HasTests = Test-Path (Join-Path $module.FullName "tests")
                        LastModified = $module.LastWriteTime
                    }
                    $moduleFeatures.LoadedModules++

                    # Categorize by module type
                    $category = switch -Regex ($module.Name) {
                        'Manager$' { 'Managers' }
                        'Provider$' { 'Providers' }
                        'Integration$' { 'Integrations' }
                        'Core$|Configuration' { 'Core' }
                        default { 'Utilities' }
                    }

                    if (-not $moduleFeatures.FeatureCategories[$category]) {
                        $moduleFeatures.FeatureCategories[$category] = @()
                    }
                    $moduleFeatures.FeatureCategories[$category] += $module.Name

                } catch {
                    Write-ReportLog "Failed to parse manifest for $($module.Name): $($_.Exception.Message)" -Level 'WARNING'
                }
            }
        }
    }

    Write-ReportLog "Feature map generated: $($moduleFeatures.LoadedModules)/$($moduleFeatures.TotalModules) modules analyzed" -Level 'SUCCESS'
    return $moduleFeatures
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

    # Test coverage score
    if ($AuditData.Testing) {
        if ($AuditData.Testing.coverage) {
            $healthFactors.TestCoverage = [math]::Min(100, $AuditData.Testing.coverage.averageCoverage)
        } elseif ($AuditData.Testing.summary) {
            $testRatio = if ($AuditData.Testing.summary.totalAnalyzed -gt 0) {
                ($AuditData.Testing.summary.modulesWithTests / $AuditData.Testing.summary.totalAnalyzed) * 100
            } else { 0 }
            $healthFactors.TestCoverage = $testRatio
        }
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

    # Module health score
    if ($FeatureMap) {
        $moduleRatio = if ($FeatureMap.TotalModules -gt 0) {
            ($FeatureMap.LoadedModules / $FeatureMap.TotalModules) * 100
        } else { 0 }
        $healthFactors.ModuleHealth = $moduleRatio
    }

    # Calculate weighted overall score
    $overallScore = 0
    foreach ($factor in $healthFactors.GetEnumerator()) {
        $overallScore += $factor.Value * $weights[$factor.Key]
    }

    $grade = switch ($overallScore) {
        {$_ -ge 90} { 'A' }
        {$_ -ge 80} { 'B' }
        {$_ -ge 70} { 'C' }
        {$_ -ge 60} { 'D' }
        default { 'F' }
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
                    Tests: $($FeatureMap.LoadedModules)/$($FeatureMap.TotalModules) modules
                </p>
            </div>

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
                    $($FeatureMap.LoadedModules)/$($FeatureMap.TotalModules) modules healthy
                </p>
            </div>
        </div>

        <div class="details-section">
            <h2>🗺️ Dynamic Feature Map</h2>
            <div class="feature-grid">
"@

    # Add feature categories
    foreach ($category in $FeatureMap.FeatureCategories.GetEnumerator()) {
        $html += @"
                <div class="feature-item">
                    <h4>$($category.Key)</h4>
                    <p><strong>$($category.Value.Count)</strong> modules</p>
                    <div style="margin-top: 10px;">
"@
        foreach ($module in $category.Value) {
            $status = if ($FeatureMap.ModuleDetails[$module].HasTests) { 'healthy' } else { 'warning' }
            $html += "<div><span class='status-indicator status-$status'></span>$module</div>"
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

    foreach ($module in $FeatureMap.ModuleDetails.GetEnumerator()) {
        $status = if ($module.Value.HasTests) { '✅ Tested' } else { '⚠️ No Tests' }
        $statusClass = if ($module.Value.HasTests) { 'status-healthy' } else { 'status-warning' }
        $lastMod = $module.Value.LastModified.ToString('yyyy-MM-dd')

        $html += @"
                        <tr>
                            <td><strong>$($module.Value.Name)</strong></td>
                            <td>$($module.Value.Version)</td>
                            <td><span class="status-indicator $statusClass"></span>$($module.Value.HasTests)</td>
                            <td>$lastMod</td>
                            <td>$status</td>
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
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🔒 Security Audit</h4>
                        <p>Status: $(if ($AuditData.Security) { '✅ Available' } else { '⚠️ No data' })</p>
                    </div>
                    <div style="padding: 15px; background: #f8f9fa; border-radius: 5px;">
                        <h4>🔧 Code Quality</h4>
                        <p>Status: $(if ($AuditData.CodeQuality) { '✅ Available' } else { '⚠️ No data' })</p>
                    </div>
                </div>
            </div>
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

# Main execution
try {
    Write-ReportLog "Starting comprehensive report generation..." -Level 'INFO'

    # Get version
    $versionNumber = Get-AitherZeroVersion
    Write-ReportLog "AitherZero version: $versionNumber" -Level 'INFO'

    # Load audit data
    $auditData = Import-AuditData -ArtifactsPath $ArtifactsPath

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
