#Requires -Version 7.0
<#
.SYNOPSIS
    Generates comprehensive tech debt report from analysis results
.DESCRIPTION
    Aggregates results from all tech debt analyzers and generates
    consolidated reports in multiple formats (HTML, Markdown, JSON)
#>

# Script metadata
# Stage: Reporting
# Dependencies: 0520,0521,0522,0523
# Description: Tech debt report generation from modular analysis results
# Tags: reporting, tech-debt, aggregation

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$AnalysisPath = "./reports/tech-debt/analysis",
    [string]$OutputPath = "./reports/tech-debt",
    [string[]]$Format = @('HTML', 'Markdown', 'JSON'),
    [switch]$RunAnalysis = $false,
    [switch]$UseLatest = $true,
    [switch]$OpenReport = $false,
    [string[]]$AnalysisTypes = @('ConfigurationUsage', 'DocumentationCoverage', 'CodeQuality', 'SecurityIssues')
)

# Initialize
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path $PSScriptRoot -Parent
$script:StartTime = Get-Date

# Import modules
Import-Module (Join-Path $script:ProjectRoot 'domains/infrastructure/Infrastructure.psm1') -Force
Import-Module (Join-Path $script:ProjectRoot 'domains/core/Logging.psm1') -Force -ErrorAction SilentlyContinue

# Initialize
if ($PSCmdlet.ShouldProcess($AnalysisPath, "Initialize tech debt analysis results directory")) {
    Initialize-SecurityConfiguration -ResultsPath $AnalysisPath
}

function Invoke-AnalysisIfNeeded {
    Write-AnalysisLog "Checking for existing analysis results..." -Component "TechDebtReport"

    $missingAnalysis = @()

    foreach ($type in $AnalysisTypes) {
        $latestFile = Join-Path $AnalysisPath "$type-latest.json"
        if (-not (Test-Path $latestFile)) {
            $missingAnalysis += $type
        } else {
            $fileAge = (Get-Date) - (Get-Item $latestFile).LastWriteTime
            if ($fileAge.TotalHours -gt 24) {
                Write-AnalysisLog "$type results are older than 24 hours" -Component "TechDebtReport" -Level Warning
            }
        }
    }

    if ($missingAnalysis.Count -gt 0) {
        Write-AnalysisLog "Missing analysis results: $($missingAnalysis -join ', ')" -Component "TechDebtReport" -Level Warning

        if ($RunAnalysis) {
            Write-AnalysisLog "Running missing analysis components..." -Component "TechDebtReport"

            $scriptMap = @{
                'ConfigurationUsage' = '0520_Analyze-ConfigurationUsage.ps1'
                'DocumentationCoverage' = '0521_Analyze-DocumentationCoverage.ps1'
                'CodeQuality' = '0522_Analyze-CodeQuality.ps1'
                'SecurityIssues' = '0523_Analyze-SecurityIssues.ps1'
            }

            foreach ($analysis in $missingAnalysis) {
                $scriptName = $scriptMap[$analysis]
                $scriptPath = Join-Path $PSScriptRoot $scriptName

                if (Test-Path $scriptPath) {
                    if ($PSCmdlet.ShouldProcess($analysis, "Run missing analysis component")) {
                        Write-AnalysisLog "Running $analysis analysis..." -Component "TechDebtReport"
                        & $scriptPath -OutputPath $AnalysisPath
                    }
                } else {
                    Write-AnalysisLog "Script not found: $scriptPath" -Component "TechDebtReport" -Level Error
                }
            }
        } else {
            throw "Missing analysis results. Run with -RunAnalysis to generate them or run individual analyzers first."
        }
    }
}

function Get-TechDebtSummary {
    param($Results)

    $summary = @{
        Generated = Get-Date -Format 'o'
        Platform = if ($IsWindows) { "Windows" } elseif ($IsLinux) { "Linux" } elseif ($IsMacOS) { "macOS" } else { "Unknown" }
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        Scores = @{}
        Metrics = @{}
        Recommendations = @()
    }

    # Configuration Usage Score
    if ($Results.Analyses.ConfigurationUsage) {
        $config = $Results.Analyses.ConfigurationUsage
        $summary.Scores.ConfigurationUsage = $config.UsagePercentage
        $summary.Metrics.UnusedSettings = $config.UnusedSettings.Count
        $summary.Metrics.TotalSettings = $config.TotalSettings

        if ($config.UsagePercentage -lt 80) {
            $summary.Recommendations += "Review and implement unused configuration settings or remove them"
        }
    }

    # Documentation Coverage Score
    if ($Results.Analyses.DocumentationCoverage) {
        $docs = $Results.Analyses.DocumentationCoverage
        $summary.Scores.Documentation = $docs.OverallCoveragePercentage
        $summary.Metrics.MissingDocs = $docs.MissingDocs.Count
        $summary.Metrics.OutdatedDocs = $docs.OutdatedDocs.Count

        if ($docs.OverallCoveragePercentage -lt 80) {
            $summary.Recommendations += "Improve documentation coverage, especially for public functions"
        }
    }

    # Code Quality Score
    if ($Results.Analyses.CodeQuality) {
        $quality = $Results.Analyses.CodeQuality
        $summary.Scores.CodeQuality = $quality.Summary.QualityScore
        $summary.Metrics.TODOs = $quality.TODOs.Count
        $summary.Metrics.FIXMEs = $quality.FIXMEs.Count
        $summary.Metrics.TechnicalDebt = ($quality.TODOs.Count + $quality.FIXMEs.Count + $quality.HACKs.Count)

        if ($quality.Summary.QualityScore -lt 70) {
            $summary.Recommendations += "Address outstanding TODOs and FIXMEs to reduce technical debt"
        }
    }

    # Security Score
    if ($Results.Analyses.SecurityIssues) {
        $security = $Results.Analyses.SecurityIssues
        $summary.Scores.Security = $security.SecurityScore
        $summary.Metrics.SecurityIssues = $security.Summary.Critical + $security.Summary.High
        $summary.Metrics.CriticalSecurity = $security.Summary.Critical

        if ($security.Summary.Critical -gt 0) {
            $summary.Recommendations += "ADDRESS CRITICAL SECURITY ISSUES IMMEDIATELY!"
        } elseif ($security.SecurityScore -lt 90) {
            $summary.Recommendations += "Review and fix security issues, especially credential handling"
        }
    }

    # Overall Tech Debt Score
    $weights = @{
        ConfigurationUsage = 0.15
        Documentation = 0.25
        CodeQuality = 0.35
        Security = 0.25
    }

    $overallScore = 0
    $totalWeight = 0

    foreach ($scoreType in $summary.Scores.Keys) {
        $weight = $weights[$scoreType]
        if ($weight) {
            $overallScore += $summary.Scores[$scoreType] * $weight
            $totalWeight += $weight
        }
    }

    $summary.Scores.Overall = if ($totalWeight -gt 0) {
        [Math]::Round($overallScore / $totalWeight, 2)
    } else { 0 }

    # Grade assignment
    $summary.Grade = switch ($summary.Scores.Overall) {
        { $_ -ge 90 } { 'A' }
        { $_ -ge 80 } { 'B' }
        { $_ -ge 70 } { 'C' }
        { $_ -ge 60 } { 'D' }
        default { 'F' }
    }

    return $summary
}

function Export-HTMLReport {
    param($Results, $Summary, $OutputFile)

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Tech Debt Report</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f7fa;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { opacity: 0.9; }

        .grade-badge {
            display: inline-block;
            font-size: 3em;
            font-weight: bold;
            width: 80px;
            height: 80px;
            line-height: 80px;
            text-align: center;
            border-radius: 50%;
            background: white;
            margin-right: 20px;
            box-shadow: 0 3px 10px rgba(0,0,0,0.2);
        }
        .grade-A { color: #10b981; }
        .grade-B { color: #3b82f6; }
        .grade-C { color: #f59e0b; }
        .grade-D { color: #ef4444; }
        .grade-F { color: #991b1b; }

        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }

        .metric-card {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            transition: transform 0.2s;
        }
        .metric-card:hover { transform: translateY(-2px); }
        .metric-label {
            font-size: 0.9em;
            color: #6b7280;
            margin-bottom: 5px;
        }
        .metric-value {
            font-size: 2.5em;
            font-weight: bold;
            color: #1f2937;
        }
        .metric-score {
            font-size: 1.2em;
            color: #6b7280;
        }

        .section {
            background: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        .section h2 {
            color: #1f2937;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #e5e7eb;
        }

        .progress-bar {
            width: 100%;
            height: 20px;
            background-color: #e5e7eb;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            transition: width 0.3s ease;
        }
        .progress-excellent { background: linear-gradient(90deg, #10b981 0%, #059669 100%); }
        .progress-good { background: linear-gradient(90deg, #3b82f6 0%, #2563eb 100%); }
        .progress-fair { background: linear-gradient(90deg, #f59e0b 0%, #d97706 100%); }
        .progress-poor { background: linear-gradient(90deg, #ef4444 0%, #dc2626 100%); }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e5e7eb;
        }
        th {
            background-color: #f9fafb;
            font-weight: 600;
            color: #374151;
        }
        tr:hover { background-color: #f9fafb; }

        .issue-badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: 500;
        }
        .critical { background-color: #fee2e2; color: #991b1b; }
        .high { background-color: #fef3c7; color: #92400e; }
        .medium { background-color: #dbeafe; color: #1e40af; }
        .low { background-color: #d1fae5; color: #065f46; }

        .recommendations {
            background-color: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 20px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .recommendations h3 {
            color: #92400e;
            margin-bottom: 10px;
        }
        .recommendations ul {
            margin-left: 20px;
        }
        .recommendations li {
            margin: 5px 0;
        }

        .footer {
            text-align: center;
            color: #6b7280;
            margin-top: 40px;
            padding: 20px;
        }

        @media (max-width: 768px) {
            .container { padding: 10px; }
            .header { padding: 20px; }
            .section { padding: 20px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div style="display: flex; align-items: center;">
                <div class="grade-badge grade-$($Summary.Grade)">$($Summary.Grade)</div>
                <div>
                    <h1>AitherZero Tech Debt Report</h1>
                    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Platform: $($Summary.Platform) | PowerShell: $($Summary.PowerShellVersion)</p>
                </div>
            </div>
        </div>

        <div class="summary-grid">
            <div class="metric-card">
                <div class="metric-label">Overall Score</div>
                <div class="metric-value">$($Summary.Scores.Overall)%</div>
                <div class="metric-score">Grade: $($Summary.Grade)</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Configuration Usage</div>
                <div class="metric-value">$($Summary.Scores.ConfigurationUsage)%</div>
                <div class="metric-score">$($Summary.Metrics.UnusedSettings) unused</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Documentation</div>
                <div class="metric-value">$($Summary.Scores.Documentation)%</div>
                <div class="metric-score">$($Summary.Metrics.MissingDocs) missing</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Code Quality</div>
                <div class="metric-value">$($Summary.Scores.CodeQuality)</div>
                <div class="metric-score">$($Summary.Metrics.TechnicalDebt) issues</div>
            </div>
            <div class="metric-card">
                <div class="metric-label">Security</div>
                <div class="metric-value">$($Summary.Scores.Security)</div>
                <div class="metric-score">$(if ($Summary.Metrics.CriticalSecurity -gt 0) { "$($Summary.Metrics.CriticalSecurity) critical!" } else { "Secure" })</div>
            </div>
        </div>
"@

    # Add recommendations if any
    if ($Summary.Recommendations.Count -gt 0) {
        $html += @"
        <div class="recommendations">
            <h3>⚠️ Key Recommendations</h3>
            <ul>
"@
        foreach ($rec in $Summary.Recommendations) {
            $html += "                <li>$rec</li>`n"
        }
        $html += @"
            </ul>
        </div>
"@
    }

    # Configuration Usage Section
    if ($Results.Analyses.ConfigurationUsage) {
        $config = $Results.Analyses.ConfigurationUsage
        $progressClass = if ($config.UsagePercentage -ge 80) { 'progress-excellent' }
                        elseif ($config.UsagePercentage -ge 60) { 'progress-good' }
                        elseif ($config.UsagePercentage -ge 40) { 'progress-fair' }
                        else { 'progress-poor' }

        $html += @"
        <div class="section">
            <h2>Configuration Usage Analysis</h2>
            <p>Analyzing how configuration settings are utilized across the codebase.</p>

            <div class="progress-bar">
                <div class="progress-fill $progressClass" style="width: $($config.UsagePercentage)%"></div>
            </div>
            <p>Usage: $($config.UsedSettings) of $($config.TotalSettings) settings ($($config.UsagePercentage)%)</p>
"@

        if ($config.UnusedSettings.Count -gt 0) {
            $html += @"
            <h3>Unused Settings</h3>
            <table>
                <tr><th>Setting Path</th><th>Action</th></tr>
"@
            foreach ($setting in $config.UnusedSettings | Select-Object -First 10) {
                $html += "                <tr><td><code>$setting</code></td><td>Review for removal or implementation</td></tr>`n"
            }
            if ($config.UnusedSettings.Count -gt 10) {
                $html += "                <tr><td colspan='2'><em>... and $($config.UnusedSettings.Count - 10) more</em></td></tr>`n"
            }
            $html += "            </table>`n"
        }

        $html += "        </div>`n"
    }

    # Documentation Coverage Section
    if ($Results.Analyses.DocumentationCoverage) {
        $docs = $Results.Analyses.DocumentationCoverage
        $progressClass = if ($docs.OverallCoveragePercentage -ge 80) { 'progress-excellent' }
                        elseif ($docs.OverallCoveragePercentage -ge 60) { 'progress-good' }
                        elseif ($docs.OverallCoveragePercentage -ge 40) { 'progress-fair' }
                        else { 'progress-poor' }

        $html += @"
        <div class="section">
            <h2>Documentation Coverage</h2>
            <p>Assessing the completeness and currency of code documentation.</p>

            <div class="progress-bar">
                <div class="progress-fill $progressClass" style="width: $($docs.OverallCoveragePercentage)%"></div>
            </div>
            <p>Coverage: $($docs.DocumentedFunctions) of $($docs.TotalFunctions) functions documented ($($docs.FunctionCoveragePercentage)%)</p>

            <table>
                <tr>
                    <th>Metric</th>
                    <th>Count</th>
                    <th>Percentage</th>
                </tr>
                <tr>
                    <td>Documented Files</td>
                    <td>$($docs.DocumentedFiles) / $($docs.TotalFiles)</td>
                    <td>$($docs.FileCoveragePercentage)%</td>
                </tr>
                <tr>
                    <td>Documented Functions</td>
                    <td>$($docs.DocumentedFunctions) / $($docs.TotalFunctions)</td>
                    <td>$($docs.FunctionCoveragePercentage)%</td>
                </tr>
                <tr>
                    <td>Missing Documentation</td>
                    <td>$($docs.MissingDocs.Count)</td>
                    <td>-</td>
                </tr>
                <tr>
                    <td>Outdated Documentation</td>
                    <td>$($docs.OutdatedDocs.Count)</td>
                    <td>-</td>
                </tr>
            </table>
        </div>
"@
    }

    # Code Quality Section
    if ($Results.Analyses.CodeQuality) {
        $quality = $Results.Analyses.CodeQuality

        $html += @"
        <div class="section">
            <h2>Code Quality Analysis</h2>
            <p>Identifying technical debt and code quality issues.</p>

            <table>
                <tr>
                    <th>Issue Type</th>
                    <th>Count</th>
                    <th>Severity</th>
                </tr>
                <tr>
                    <td>TODOs</td>
                    <td>$($quality.TODOs.Count)</td>
                    <td><span class="issue-badge low">Low</span></td>
                </tr>
                <tr>
                    <td>FIXMEs</td>
                    <td>$($quality.FIXMEs.Count)</td>
                    <td><span class="issue-badge high">High</span></td>
                </tr>
                <tr>
                    <td>HACKs</td>
                    <td>$($quality.HACKs.Count)</td>
                    <td><span class="issue-badge high">High</span></td>
                </tr>
                <tr>
                    <td>Deprecated Code</td>
                    <td>$($quality.Deprecated.Count)</td>
                    <td><span class="issue-badge medium">Medium</span></td>
                </tr>
                <tr>
                    <td>Long Functions</td>
                    <td>$($quality.LongFunctions.Count)</td>
                    <td><span class="issue-badge medium">Medium</span></td>
                </tr>
                <tr>
                    <td>Complex Functions</td>
                    <td>$($quality.ComplexFunctions.Count)</td>
                    <td><span class="issue-badge medium">Medium</span></td>
                </tr>
                <tr>
                    <td>Hardcoded Values</td>
                    <td>$($quality.HardcodedValues.Count)</td>
                    <td><span class="issue-badge low">Low</span></td>
                </tr>
            </table>

            <p><strong>Quality Score: $($quality.Summary.QualityScore)/100</strong></p>
        </div>
"@
    }

    # Security Analysis Section
    if ($Results.Analyses.SecurityIssues) {
        $security = $Results.Analyses.SecurityIssues

        $html += @"
        <div class="section">
            <h2>Security Analysis</h2>
            <p>Scanning for potential security vulnerabilities and risks.</p>

            <table>
                <tr>
                    <th>Security Issue</th>
                    <th>Count</th>
                    <th>Severity</th>
                </tr>
                <tr>
                    <td>Plain Text Credentials</td>
                    <td>$($security.PlainTextCredentials.Count)</td>
                    <td><span class="issue-badge critical">Critical</span></td>
                </tr>
                <tr>
                    <td>Insecure Protocols</td>
                    <td>$($security.InsecureProtocols.Count)</td>
                    <td><span class="issue-badge high">High</span></td>
                </tr>
                <tr>
                    <td>Unsafe Commands</td>
                    <td>$($security.UnsafeCommands.Count)</td>
                    <td><span class="issue-badge critical">Critical</span></td>
                </tr>
                <tr>
                    <td>Missing Parameter Validation</td>
                    <td>$($security.MissingParameterValidation.Count)</td>
                    <td><span class="issue-badge medium">Medium</span></td>
                </tr>
                <tr>
                    <td>Cryptographic Issues</td>
                    <td>$($security.CryptographicIssues.Count)</td>
                    <td><span class="issue-badge high">High</span></td>
                </tr>
                <tr>
                    <td>Privilege Escalation</td>
                    <td>$($security.PrivilegeEscalation.Count)</td>
                    <td><span class="issue-badge critical">Critical</span></td>
                </tr>
            </table>

            <p><strong>Security Score: $($security.SecurityScore)/100</strong></p>
"@

        if ($security.Summary.Critical -gt 0) {
            $html += @"
            <div class="recommendations" style="background-color: #fee2e2; border-color: #ef4444;">
                <h3>🚨 Critical Security Issues Detected!</h3>
                <p>$($security.Summary.Critical) critical security issues require immediate attention.</p>
            </div>
"@
        }

        $html += "        </div>`n"
    }

    # Footer
    $html += @"
        <div class="footer">
            <p>Generated by AitherZero Tech Debt Analysis System</p>
            <p>For more information, run individual analyzers or check the detailed JSON reports.</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Set-Content -Path $OutputFile -Encoding UTF8
}

function Export-MarkdownReport {
    param($Results, $Summary, $OutputFile)

    $md = @"
# AitherZero Tech Debt Report

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Platform**: $($Summary.Platform) | **PowerShell**: $($Summary.PowerShellVersion)
**Overall Grade**: **$($Summary.Grade)** ($($Summary.Scores.Overall)%)

## Executive Summary

| Metric | Score | Status |
|--------|-------|--------|
| Configuration Usage | $($Summary.Scores.ConfigurationUsage)% | $(if ($Summary.Scores.ConfigurationUsage -ge 80) { "✅" } else { "⚠️" }) |
| Documentation Coverage | $($Summary.Scores.Documentation)% | $(if ($Summary.Scores.Documentation -ge 80) { "✅" } else { "⚠️" }) |
| Code Quality | $($Summary.Scores.CodeQuality)/100 | $(if ($Summary.Scores.CodeQuality -ge 70) { "✅" } else { "⚠️" }) |
| Security | $($Summary.Scores.Security)/100 | $(if ($Summary.Scores.Security -ge 90) { "✅" } elseif ($Summary.Metrics.CriticalSecurity -gt 0) { "🚨" } else { "⚠️" }) |

"@

    # Add recommendations
    if ($Summary.Recommendations.Count -gt 0) {
        $md += @"
## 📋 Key Recommendations

"@
        foreach ($rec in $Summary.Recommendations) {
            $md += "- $rec`n"
        }
        $md += "`n"
    }

    # Configuration Usage
    if ($Results.Analyses.ConfigurationUsage) {
        $config = $Results.Analyses.ConfigurationUsage
        $md += @"
## Configuration Usage Analysis

- **Total Settings**: $($config.TotalSettings)
- **Used Settings**: $($config.UsedSettings)
- **Unused Settings**: $($config.UnusedSettings.Count)
- **Usage Rate**: $($config.UsagePercentage)%

"@
        if ($config.UnusedSettings.Count -gt 0) {
            $md += "### Top Unused Settings`n`n"
            $config.UnusedSettings | Select-Object -First 10 | ForEach-Object {
                $md += "- `$_`n"
            }
            if ($config.UnusedSettings.Count -gt 10) {
                $md += "- _... and $($config.UnusedSettings.Count - 10) more_`n"
            }
            $md += "`n"
        }
    }

    # Documentation Coverage
    if ($Results.Analyses.DocumentationCoverage) {
        $docs = $Results.Analyses.DocumentationCoverage
        $md += @"
## Documentation Coverage

- **File Coverage**: $($docs.DocumentedFiles)/$($docs.TotalFiles) ($($docs.FileCoveragePercentage)%)
- **Function Coverage**: $($docs.DocumentedFunctions)/$($docs.TotalFunctions) ($($docs.FunctionCoveragePercentage)%)
- **Missing Documentation**: $($docs.MissingDocs.Count) items
- **Outdated Documentation**: $($docs.OutdatedDocs.Count) items

"@
    }

    # Code Quality
    if ($Results.Analyses.CodeQuality) {
        $quality = $Results.Analyses.CodeQuality
        $md += @"
## Code Quality Analysis

| Issue Type | Count | Priority |
|------------|-------|----------|
| TODOs | $($quality.TODOs.Count) | Low |
| FIXMEs | $($quality.FIXMEs.Count) | **High** |
| HACKs | $($quality.HACKs.Count) | **High** |
| Deprecated | $($quality.Deprecated.Count) | Medium |
| Long Functions | $($quality.LongFunctions.Count) | Medium |
| Complex Functions | $($quality.ComplexFunctions.Count) | Medium |
| Hardcoded Values | $($quality.HardcodedValues.Count) | Low |

**Quality Score**: $($quality.Summary.QualityScore)/100

"@
    }

    # Security Analysis
    if ($Results.Analyses.SecurityIssues) {
        $security = $Results.Analyses.SecurityIssues
        $md += @"
## Security Analysis

| Security Issue | Count | Severity |
|----------------|-------|----------|
| Plain Text Credentials | $($security.PlainTextCredentials.Count) | **CRITICAL** |
| Insecure Protocols | $($security.InsecureProtocols.Count) | High |
| Unsafe Commands | $($security.UnsafeCommands.Count) | **CRITICAL** |
| Missing Parameter Validation | $($security.MissingParameterValidation.Count) | Medium |
| Cryptographic Issues | $($security.CryptographicIssues.Count) | High |
| Privilege Escalation | $($security.PrivilegeEscalation.Count) | **CRITICAL** |

**Security Score**: $($security.SecurityScore)/100

"@
        if ($security.Summary.Critical -gt 0) {
            $md += @"
> 🚨 **CRITICAL**: $($security.Summary.Critical) critical security issues detected that require immediate attention!

"@
        }
    }

    $md += @"
---
*Generated by AitherZero Tech Debt Analysis System*
"@

    $md | Set-Content -Path $OutputFile -Encoding UTF8
}

# Main execution
try {
    Write-AnalysisLog "=== Tech Debt Report Generation ===" -Component "TechDebtReport"

    # Check for or run analysis
    Invoke-AnalysisIfNeeded

    # Merge all analysis results
    Write-AnalysisLog "Merging analysis results..." -Component "TechDebtReport"
    $mergedResults = Merge-AnalysisResults -AnalysisTypes $AnalysisTypes -ResultsPath $AnalysisPath

    # Generate summary
    Write-AnalysisLog "Generating summary..." -Component "TechDebtReport"
    $summary = Get-TechDebtSummary -Results $mergedResults

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        if ($PSCmdlet.ShouldProcess($OutputPath, "Create output directory")) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # Generate reports in requested formats
    foreach ($fmt in $Format) {
        Write-AnalysisLog "Generating $fmt report..." -Component "TechDebtReport"

        switch ($fmt.ToUpper()) {
            'HTML' {
                $htmlFile = Join-Path $OutputPath "TechDebtReport-$timestamp.html"
                if ($PSCmdlet.ShouldProcess($htmlFile, "Generate HTML tech debt report")) {
                    Export-HTMLReport -Results $mergedResults -Summary $summary -OutputFile $htmlFile
                    Write-AnalysisLog "HTML report saved: $htmlFile" -Component "TechDebtReport" -Level Success

                    if ($OpenReport -and $IsWindows) {
                        Start-Process $htmlFile
                    }
                }
            }

            'MARKDOWN' {
                $mdFile = Join-Path $OutputPath "TechDebtReport-$timestamp.md"
                if ($PSCmdlet.ShouldProcess($mdFile, "Generate Markdown tech debt report")) {
                    Export-MarkdownReport -Results $mergedResults -Summary $summary -OutputFile $mdFile
                    Write-AnalysisLog "Markdown report saved: $mdFile" -Component "TechDebtReport" -Level Success
                }
            }

            'JSON' {
                $jsonFile = Join-Path $OutputPath "TechDebtReport-$timestamp.json"
                if ($PSCmdlet.ShouldProcess($jsonFile, "Generate JSON tech debt report")) {
                    @{
                        Summary = $summary
                        Results = $mergedResults
                    } | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFile -Encoding UTF8
                    Write-AnalysisLog "JSON report saved: $jsonFile" -Component "TechDebtReport" -Level Success
                }
            }
        }
    }

    # Display summary
    Write-Host "`nTech Debt Report Summary" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host "Overall Grade: $($summary.Grade) ($($summary.Scores.Overall)%)" -ForegroundColor $(
        switch ($summary.Grade) {
            'A' { 'Green' }
            'B' { 'Blue' }
            'C' { 'Yellow' }
            'D' { 'Red' }
            'F' { 'DarkRed' }
        }
    )

    Write-Host "`nScores:" -ForegroundColor Yellow
    Write-Host "  Configuration Usage: $($summary.Scores.ConfigurationUsage)%"
    Write-Host "  Documentation: $($summary.Scores.Documentation)%"
    Write-Host "  Code Quality: $($summary.Scores.CodeQuality)/100"
    Write-Host "  Security: $($summary.Scores.Security)/100"

    if ($summary.Metrics.CriticalSecurity -gt 0) {
        Write-Host "`n🚨 CRITICAL SECURITY ISSUES: $($summary.Metrics.CriticalSecurity)" -ForegroundColor Red
    }

    if ($summary.Recommendations.Count -gt 0) {
        Write-Host "`nKey Recommendations:" -ForegroundColor Yellow
        $summary.Recommendations | ForEach-Object { Write-Host "  • $_" }
    }

    Write-Host "`nReports generated successfully!" -ForegroundColor Green

    exit 0
} catch {
    Write-AnalysisLog "Tech debt report generation failed: $_" -Component "TechDebtReport" -Level Error
    Write-AnalysisLog "Stack trace: $($_.ScriptStackTrace)" -Component "TechDebtReport" -Level Error
    exit 1
}

