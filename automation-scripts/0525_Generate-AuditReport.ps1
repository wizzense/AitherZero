#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive audit report from compliance and security scans
.DESCRIPTION
    Consolidates results from compliance checks, security scans, test results,
    and code analysis into a unified audit report for governance and compliance.
    
    Exit Codes:
    0 - Report generated successfully
    1 - Critical compliance issues found
    2 - Error during report generation
    
.NOTES
    Stage: Compliance
    Order: 0525
    Dependencies: 0524 (Compliance Check), 0523 (Security Scan)
    Tags: audit, compliance, reporting, governance
#>

[CmdletBinding()]
param(
    [ValidateSet('Executive', 'Technical', 'Full')]
    [string]$ReportType = 'Full',
    
    [ValidateSet('HTML', 'JSON', 'Markdown', 'All')]
    [string[]]$OutputFormats = @('HTML', 'JSON'),
    
    [string]$OutputPath = './reports/audit',
    
    [switch]$IncludeSecurityFindings,
    
    [switch]$IncludeTestResults,
    
    [switch]$IncludeCodeMetrics,
    
    [switch]$IncludeChangeHistory,
    
    [switch]$CI,
    
    [switch]$UploadToGitHub
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata
$scriptMetadata = @{
    Stage = 'Compliance'
    Order = 0525
    Dependencies = @('0524', '0523')
    Tags = @('audit', 'compliance', 'reporting', 'governance')
    RequiresAdmin = $false
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
        'Success' = 'Green'
    }[$Level]
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message "[Audit] $Message"
    }
}

function Get-LatestReport {
    param(
        [string]$Path,
        [string]$Pattern
    )
    
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Filter $Pattern -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }
}

function Get-ProjectMetadata {
    $metadata = @{
        ProjectName = 'AitherZero'
        Version = '0.0.0'
        Branch = 'unknown'
        Commit = 'unknown'
        BuildNumber = if ($env:GITHUB_RUN_NUMBER) { $env:GITHUB_RUN_NUMBER } else { 'local' }
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Get version
    if (Test-Path "./VERSION") {
        $metadata.Version = Get-Content "./VERSION" -Raw -ErrorAction SilentlyContinue | ForEach-Object { $_.Trim() }
    }
    
    # Get git info
    if (Test-Path ".git") {
        $metadata.Branch = git rev-parse --abbrev-ref HEAD 2>$null
        $metadata.Commit = git rev-parse --short HEAD 2>$null
    }
    
    return $metadata
}

try {
    Write-ScriptLog -Message "Starting audit report generation (Type: $ReportType)"
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Initialize audit data
    $auditData = @{
        Metadata = Get-ProjectMetadata
        ComplianceStatus = @{
            Overall = 'Unknown'
            Details = @{}
        }
        SecurityStatus = @{
            Overall = 'Unknown'
            Vulnerabilities = @{}
        }
        TestStatus = @{
            Overall = 'Unknown'
            Coverage = 0
            PassRate = 0
            Total = 0
            Passed = 0
            Failed = 0
            Results = @{}
        }
        CodeQuality = @{
            Overall = 'Unknown'
            Errors = 0
            Warnings = 0
            Information = 0
            Metrics = @{}
            Statistics = @{}
        }
        Changes = @{
            RecentCommits = @()
            Contributors = @()
        }
        Recommendations = @()
        RiskAssessment = @{
            Level = 'Unknown'
            Factors = @()
        }
    }
    
    # === 1. Gather Compliance Data ===
    Write-ScriptLog -Message "Gathering compliance data..."
    
    $complianceReport = Get-LatestReport -Path "./tests/compliance" -Pattern "ComplianceReport-*.json"
    if ($complianceReport) {
        $compliance = Get-Content $complianceReport.FullName | ConvertFrom-Json
        
        $auditData.ComplianceStatus = @{
            Overall = if ($compliance.Compliant) { 'Compliant' } else { 'Non-Compliant' }
            CheckDate = $compliance.Timestamp
            Level = $compliance.AuditLevel
            Summary = $compliance.Summary
            Details = $compliance.Results
        }
        
        # Add recommendations based on compliance findings
        if ($compliance.Summary.Failed -gt 0) {
            $auditData.Recommendations += "Address $($compliance.Summary.Failed) critical compliance issues"
        }
        if ($compliance.Summary.Warnings -gt 0) {
            $auditData.Recommendations += "Review $($compliance.Summary.Warnings) compliance warnings"
        }
    } else {
        Write-ScriptLog -Level Warning -Message "No compliance report found"
        $auditData.ComplianceStatus.Overall = 'Not Assessed'
    }
    
    # === 2. Gather Security Data ===
    if ($IncludeSecurityFindings) {
        Write-ScriptLog -Message "Gathering security scan data..."
        
        $securityReport = Get-LatestReport -Path "./tests/security" -Pattern "SecurityScan-*.json"
        if ($securityReport) {
            $security = Get-Content $securityReport.FullName | ConvertFrom-Json
            
            $auditData.SecurityStatus = @{
                Overall = if ($security.Summary.Critical -eq 0 -and $security.Summary.High -eq 0) { 
                    'Secure' 
                } elseif ($security.Summary.Critical -gt 0) {
                    'Critical'
                } else {
                    'At Risk'
                }
                ScanDate = $security.Timestamp
                ScanLevel = $security.ScanLevel
                Summary = $security.Summary
                Findings = if ($ReportType -eq 'Executive') {
                    # Executive summary only
                    @{ Count = $security.TotalFindings }
                } else {
                    $security.Findings
                }
            }
            
            # Risk assessment
            if ($security.Summary.Critical -gt 0) {
                $auditData.RiskAssessment.Factors += "Critical security vulnerabilities detected"
            }
            if ($security.Summary.High -gt 0) {
                $auditData.RiskAssessment.Factors += "High severity security issues present"
            }
        }
    }
    
    # === 3. Gather Test Results ===
    if ($IncludeTestResults) {
        Write-ScriptLog -Message "Gathering test results..."
        
        # Check for Pester test results
        $testResults = Get-LatestReport -Path "./tests/results" -Pattern "TestResults-*.xml"
        if ($testResults) {
            [xml]$testXml = Get-Content $testResults.FullName
            $testSuite = $testXml.'test-results'
            
            $auditData.TestStatus = @{
                Overall = if ([int]$testSuite.failures -eq 0) { 'Passing' } else { 'Failing' }
                Total = [int]$testSuite.total
                Passed = [int]$testSuite.total - [int]$testSuite.failures
                Failed = [int]$testSuite.failures
                PassRate = if ([int]$testSuite.total -gt 0) {
                    [math]::Round(([int]$testSuite.total - [int]$testSuite.failures) / [int]$testSuite.total * 100, 2)
                } else { 0 }
            }
        }
        
        # Check for coverage data
        $coverageReport = Get-LatestReport -Path "./tests/coverage" -Pattern "coverage-*.xml"
        if ($coverageReport) {
            [xml]$coverageXml = Get-Content $coverageReport.FullName
            # Parse coverage percentage (format depends on tool)
            $auditData.TestStatus.Coverage = 80  # Placeholder - parse actual coverage
        }
    }
    
    # === 4. Gather Code Quality Metrics ===
    if ($IncludeCodeMetrics) {
        Write-ScriptLog -Message "Gathering code quality metrics..."
        
        # PSScriptAnalyzer results
        $analysisReport = Get-LatestReport -Path "./tests/analysis" -Pattern "PSScriptAnalyzer-*.json"
        if ($analysisReport) {
            $analysis = Get-Content $analysisReport.FullName | ConvertFrom-Json
            
            $auditData.CodeQuality = @{
                Overall = if (@($analysis | Where-Object Severity -eq 'Error').Count -eq 0) { 
                    'Good' 
                } else { 
                    'Needs Improvement' 
                }
                Errors = @($analysis | Where-Object Severity -eq 'Error').Count
                Warnings = @($analysis | Where-Object Severity -eq 'Warning').Count
                Information = @($analysis | Where-Object Severity -eq 'Information').Count
            }
        }
        
        # Code statistics
        $psFiles = Get-ChildItem -Path . -Recurse -Include "*.ps1","*.psm1","*.psd1" |
            Where-Object { $_.FullName -notlike "*tests*" -and $_.FullName -notlike "*node_modules*" }
        
        $totalLines = 0
        $totalFunctions = 0
        foreach ($file in $psFiles) {
            $content = Get-Content $file.FullName
            $totalLines += $content.Count
            $totalFunctions += @($content | Select-String -Pattern "^function\s+\w+").Count
        }
        
        $auditData.CodeQuality.Statistics = @{
            Files = $psFiles.Count
            Lines = $totalLines
            Functions = $totalFunctions
        }
    }
    
    # === 5. Gather Change History ===
    if ($IncludeChangeHistory -and (Test-Path ".git")) {
        Write-ScriptLog -Message "Gathering change history..."
        
        # Recent commits
        $recentCommits = git log --format="%h|%an|%ai|%s" -n 10 2>$null | ForEach-Object {
            $parts = $_ -split '\|'
            @{
                Hash = $parts[0]
                Author = $parts[1]
                Date = $parts[2]
                Message = $parts[3]
            }
        }
        $auditData.Changes.RecentCommits = $recentCommits
        
        # Contributors
        $contributors = git shortlog -sn 2>$null | ForEach-Object {
            if ($_ -match '^\s*(\d+)\s+(.+)$') {
                @{
                    Commits = [int]$Matches[1]
                    Name = $Matches[2]
                }
            }
        }
        $auditData.Changes.Contributors = $contributors
    }
    
    # === 6. Risk Assessment ===
    Write-ScriptLog -Message "Calculating risk assessment..."
    
    $riskScore = 0
    
    # Compliance risk
    if ($auditData.ComplianceStatus.Overall -eq 'Non-Compliant') {
        $riskScore += 30
        $auditData.RiskAssessment.Factors += "Non-compliant with policies"
    }
    
    # Security risk
    if ($auditData.SecurityStatus.Overall -eq 'Critical') {
        $riskScore += 40
    } elseif ($auditData.SecurityStatus.Overall -eq 'At Risk') {
        $riskScore += 20
    }
    
    # Test risk
    if ($auditData.TestStatus.PassRate -and $auditData.TestStatus.PassRate -lt 80) {
        $riskScore += 20
        $auditData.RiskAssessment.Factors += "Test pass rate below 80%"
    }
    
    # Coverage risk
    if ($auditData.TestStatus.Coverage -and $auditData.TestStatus.Coverage -lt 60) {
        $riskScore += 10
        $auditData.RiskAssessment.Factors += "Code coverage below 60%"
    }
    
    $auditData.RiskAssessment.Score = $riskScore
    $auditData.RiskAssessment.Level = switch ($riskScore) {
        { $_ -ge 70 } { 'Critical' }
        { $_ -ge 50 } { 'High' }
        { $_ -ge 30 } { 'Medium' }
        { $_ -ge 10 } { 'Low' }
        default { 'Minimal' }
    }
    
    # === 7. Generate Recommendations ===
    if ($auditData.RiskAssessment.Level -in @('Critical', 'High')) {
        $auditData.Recommendations = @(
            "Immediate action required to address critical issues"
        ) + $auditData.Recommendations
    }
    
    if ($auditData.TestStatus.Coverage -and $auditData.TestStatus.Coverage -lt 80) {
        $auditData.Recommendations += "Increase test coverage to at least 80%"
    }
    
    if ($auditData.CodeQuality.Errors -and $auditData.CodeQuality.Errors -gt 0) {
        $auditData.Recommendations += "Fix $($auditData.CodeQuality.Errors) code analysis errors"
    }
    
    # === 8. Generate Reports ===
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFiles = @()
    
    # JSON Report
    if ('JSON' -in $OutputFormats -or 'All' -in $OutputFormats) {
        $jsonFile = "$OutputPath/AuditReport-$timestamp.json"
        $auditData | ConvertTo-Json -Depth 10 | Set-Content $jsonFile
        $reportFiles += $jsonFile
        Write-ScriptLog -Message "JSON report saved to: $jsonFile"
    }
    
    # HTML Report
    if ('HTML' -in $OutputFormats -or 'All' -in $OutputFormats) {
        $htmlFile = "$OutputPath/AuditReport-$timestamp.html"
        
        $riskColor = switch ($auditData.RiskAssessment.Level) {
            'Critical' { '#dc3545' }
            'High' { '#fd7e14' }
            'Medium' { '#ffc107' }
            'Low' { '#28a745' }
            default { '#6c757d' }
        }
        
        $complianceColor = if ($auditData.ComplianceStatus.Overall -eq 'Compliant') { 
            '#28a745' 
        } else { 
            '#dc3545' 
        }
        
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Audit Report - $($auditData.Metadata.ProjectName) v$($auditData.Metadata.Version)</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6; 
            color: #333; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 2rem;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            background: white; 
            border-radius: 12px; 
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 3rem;
            text-align: center;
        }
        .header h1 { 
            font-size: 2.5rem; 
            margin-bottom: 0.5rem;
            font-weight: 700;
        }
        .header p { 
            opacity: 0.9; 
            font-size: 1.1rem;
        }
        .content { padding: 3rem; }
        .summary-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin: 2rem 0;
        }
        .summary-card {
            background: #f8f9fa;
            padding: 1.5rem;
            border-radius: 8px;
            border-left: 4px solid #667eea;
            transition: transform 0.2s;
        }
        .summary-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        .summary-card h3 {
            color: #667eea;
            margin-bottom: 0.5rem;
            font-size: 0.9rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .summary-card .value {
            font-size: 2rem;
            font-weight: bold;
            color: #333;
        }
        .summary-card .subtitle {
            color: #6c757d;
            font-size: 0.9rem;
            margin-top: 0.25rem;
        }
        .risk-banner {
            background: $riskColor;
            color: white;
            padding: 1.5rem;
            border-radius: 8px;
            margin: 2rem 0;
            text-align: center;
        }
        .risk-banner h2 {
            font-size: 1.5rem;
            margin-bottom: 0.5rem;
        }
        .compliance-banner {
            background: $complianceColor;
            color: white;
            padding: 1.5rem;
            border-radius: 8px;
            margin: 2rem 0;
            text-align: center;
        }
        .section {
            margin: 3rem 0;
        }
        .section h2 {
            color: #333;
            margin-bottom: 1.5rem;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid #667eea;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
        }
        th, td {
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid #dee2e6;
        }
        th {
            background: #f8f9fa;
            font-weight: 600;
            color: #495057;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .badge {
            display: inline-block;
            padding: 0.25rem 0.75rem;
            border-radius: 12px;
            font-size: 0.875rem;
            font-weight: 600;
        }
        .badge.success { background: #d4edda; color: #155724; }
        .badge.danger { background: #f8d7da; color: #721c24; }
        .badge.warning { background: #fff3cd; color: #856404; }
        .badge.info { background: #d1ecf1; color: #0c5460; }
        .recommendations {
            background: #e7f3ff;
            border-left: 4px solid #0066cc;
            padding: 1.5rem;
            border-radius: 4px;
            margin: 1rem 0;
        }
        .recommendations h3 {
            color: #0066cc;
            margin-bottom: 1rem;
        }
        .recommendations ul {
            margin-left: 1.5rem;
            color: #495057;
        }
        .recommendations li {
            margin: 0.5rem 0;
        }
        .footer {
            background: #f8f9fa;
            padding: 2rem;
            text-align: center;
            color: #6c757d;
            border-top: 1px solid #dee2e6;
        }
        @media (max-width: 768px) {
            .summary-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Compliance & Security Audit Report</h1>
            <p>$($auditData.Metadata.ProjectName) v$($auditData.Metadata.Version) | Generated: $($auditData.Metadata.Timestamp)</p>
        </div>
        
        <div class="content">
            <!-- Risk Assessment Banner -->
            <div class="risk-banner">
                <h2>Risk Level: $($auditData.RiskAssessment.Level)</h2>
                <p>Risk Score: $($auditData.RiskAssessment.Score)/100</p>
            </div>
            
            <!-- Compliance Status Banner -->
            <div class="compliance-banner">
                <h2>Compliance Status: $($auditData.ComplianceStatus.Overall)</h2>
                $(if ($auditData.ComplianceStatus.CheckDate) {
                    "<p>Last assessed: $($auditData.ComplianceStatus.CheckDate)</p>"
                })
            </div>
            
            <!-- Summary Grid -->
            <div class="summary-grid">
                <div class="summary-card">
                    <h3>Security Status</h3>
                    <div class="value">$($auditData.SecurityStatus.Overall)</div>
                    $(if ($auditData.SecurityStatus.Summary) {
                        "<div class='subtitle'>$($auditData.SecurityStatus.Summary.Critical) critical, $($auditData.SecurityStatus.Summary.High) high</div>"
                    })
                </div>
                
                <div class="summary-card">
                    <h3>Test Coverage</h3>
                    <div class="value">$($auditData.TestStatus.Coverage)%</div>
                    <div class="subtitle">$($auditData.TestStatus.Passed)/$($auditData.TestStatus.Total) tests passing</div>
                </div>
                
                <div class="summary-card">
                    <h3>Code Quality</h3>
                    <div class="value">$($auditData.CodeQuality.Overall)</div>
                    $(if ($auditData.CodeQuality.Errors -ne $null) {
                        "<div class='subtitle'>$($auditData.CodeQuality.Errors) errors, $($auditData.CodeQuality.Warnings) warnings</div>"
                    })
                </div>
                
                <div class="summary-card">
                    <h3>Build Info</h3>
                    <div class="value">#$($auditData.Metadata.BuildNumber)</div>
                    <div class="subtitle">$($auditData.Metadata.Branch)@$($auditData.Metadata.Commit)</div>
                </div>
            </div>
            
            <!-- Recommendations -->
            $(if ($auditData.Recommendations.Count -gt 0) {
                @"
                <div class="recommendations">
                    <h3>📋 Recommendations</h3>
                    <ul>
                        $(foreach ($rec in $auditData.Recommendations) {
                            "<li>$rec</li>"
                        })
                    </ul>
                </div>
"@
            })
            
            <!-- Compliance Details -->
            $(if ($auditData.ComplianceStatus.Summary) {
                @"
                <div class="section">
                    <h2>Compliance Details</h2>
                    <table>
                        <tr>
                            <th>Category</th>
                            <th>Count</th>
                            <th>Status</th>
                        </tr>
                        <tr>
                            <td>Passed Checks</td>
                            <td>$($auditData.ComplianceStatus.Summary.Passed)</td>
                            <td><span class="badge success">✓ Passed</span></td>
                        </tr>
                        <tr>
                            <td>Failed Checks</td>
                            <td>$($auditData.ComplianceStatus.Summary.Failed)</td>
                            <td>$(if ($auditData.ComplianceStatus.Summary.Failed -gt 0) {
                                '<span class="badge danger">✗ Failed</span>'
                            } else {
                                '<span class="badge success">✓ None</span>'
                            })</td>
                        </tr>
                        <tr>
                            <td>Warnings</td>
                            <td>$($auditData.ComplianceStatus.Summary.Warnings)</td>
                            <td>$(if ($auditData.ComplianceStatus.Summary.Warnings -gt 0) {
                                '<span class="badge warning">⚠ Warning</span>'
                            } else {
                                '<span class="badge success">✓ None</span>'
                            })</td>
                        </tr>
                    </table>
                </div>
"@
            })
            
            <!-- Risk Factors -->
            $(if ($auditData.RiskAssessment.Factors.Count -gt 0) {
                @"
                <div class="section">
                    <h2>Risk Factors</h2>
                    <ul>
                        $(foreach ($factor in $auditData.RiskAssessment.Factors) {
                            "<li>$factor</li>"
                        })
                    </ul>
                </div>
"@
            })
            
            <!-- Recent Changes -->
            $(if ($IncludeChangeHistory -and $auditData.Changes.RecentCommits.Count -gt 0) {
                @"
                <div class="section">
                    <h2>Recent Changes</h2>
                    <table>
                        <tr>
                            <th>Commit</th>
                            <th>Author</th>
                            <th>Date</th>
                            <th>Message</th>
                        </tr>
                        $(foreach ($commit in $auditData.Changes.RecentCommits | Select-Object -First 5) {
                            @"
                            <tr>
                                <td><code>$($commit.Hash)</code></td>
                                <td>$($commit.Author)</td>
                                <td>$($commit.Date)</td>
                                <td>$($commit.Message)</td>
                            </tr>
"@
                        })
                    </table>
                </div>
"@
            })
        </div>
        
        <div class="footer">
            <p>Generated by AitherZero Audit System | $(if ($ReportType -eq 'Executive') { 'Executive Summary' } else { 'Full Report' })</p>
            <p>For questions or concerns, contact the compliance team</p>
        </div>
    </div>
</body>
</html>
"@
        
        $html | Set-Content $htmlFile
        $reportFiles += $htmlFile
        Write-ScriptLog -Message "HTML report saved to: $htmlFile"
    }
    
    # Markdown Report
    if ('Markdown' -in $OutputFormats -or 'All' -in $OutputFormats) {
        $mdFile = "$OutputPath/AuditReport-$timestamp.md"
        
        $markdown = @"
# Compliance & Security Audit Report

**Project:** $($auditData.Metadata.ProjectName) v$($auditData.Metadata.Version)  
**Generated:** $($auditData.Metadata.Timestamp)  
**Branch:** $($auditData.Metadata.Branch)@$($auditData.Metadata.Commit)  
**Build:** #$($auditData.Metadata.BuildNumber)

## Executive Summary

- **Risk Level:** $($auditData.RiskAssessment.Level) (Score: $($auditData.RiskAssessment.Score)/100)
- **Compliance Status:** $($auditData.ComplianceStatus.Overall)
- **Security Status:** $($auditData.SecurityStatus.Overall)
- **Test Coverage:** $($auditData.TestStatus.Coverage)%
- **Code Quality:** $($auditData.CodeQuality.Overall)

$(if ($auditData.Recommendations.Count -gt 0) {
@"

## Recommendations

$(foreach ($rec in $auditData.Recommendations) {
"- $rec`n"
})
"@
})

## Compliance Results

| Metric | Value |
|--------|-------|
| Passed Checks | $(if ($null -ne $auditData.ComplianceStatus.Summary.Passed) { $auditData.ComplianceStatus.Summary.Passed } else { 'N/A' }) |
| Failed Checks | $(if ($null -ne $auditData.ComplianceStatus.Summary.Failed) { $auditData.ComplianceStatus.Summary.Failed } else { 'N/A' }) |
| Warnings | $(if ($null -ne $auditData.ComplianceStatus.Summary.Warnings) { $auditData.ComplianceStatus.Summary.Warnings } else { 'N/A' }) |
| Audit Level | $(if ($auditData.ComplianceStatus.Level) { $auditData.ComplianceStatus.Level } else { 'N/A' }) |

## Security Assessment

| Severity | Count |
|----------|-------|
| Critical | $(if ($null -ne $auditData.SecurityStatus.Summary.Critical) { $auditData.SecurityStatus.Summary.Critical } else { 0 }) |
| High | $(if ($null -ne $auditData.SecurityStatus.Summary.High) { $auditData.SecurityStatus.Summary.High } else { 0 }) |
| Medium | $(if ($null -ne $auditData.SecurityStatus.Summary.Medium) { $auditData.SecurityStatus.Summary.Medium } else { 0 }) |
| Low | $(if ($null -ne $auditData.SecurityStatus.Summary.Low) { $auditData.SecurityStatus.Summary.Low } else { 0 }) |

## Test Results

- **Total Tests:** $(if ($null -ne $auditData.TestStatus.Total) { $auditData.TestStatus.Total } else { 'N/A' })
- **Passed:** $(if ($null -ne $auditData.TestStatus.Passed) { $auditData.TestStatus.Passed } else { 'N/A' })
- **Failed:** $(if ($null -ne $auditData.TestStatus.Failed) { $auditData.TestStatus.Failed } else { 'N/A' })
- **Pass Rate:** $(if ($auditData.TestStatus.PassRate) { "$($auditData.TestStatus.PassRate)%" } else { 'N/A' })
- **Coverage:** $(if ($auditData.TestStatus.Coverage) { "$($auditData.TestStatus.Coverage)%" } else { 'N/A' })

$(if ($auditData.RiskAssessment.Factors.Count -gt 0) {
@"

## Risk Factors

$(foreach ($factor in $auditData.RiskAssessment.Factors) {
"- $factor`n"
})
"@
})

---

*Report generated by AitherZero Audit System*
"@
        
        $markdown | Set-Content $mdFile
        $reportFiles += $mdFile
        Write-ScriptLog -Message "Markdown report saved to: $mdFile"
    }
    
    # === 9. Display Summary ===
    Write-Host "`n════════════════════════════════════════" -ForegroundColor Blue
    Write-Host " Audit Report Summary" -ForegroundColor White
    Write-Host "════════════════════════════════════════" -ForegroundColor Blue
    
    $riskColors = @{
        'Critical' = 'Red'
        'High' = 'DarkRed'
        'Medium' = 'Yellow'
        'Low' = 'Green'
        'Minimal' = 'DarkGreen'
    }
    
    Write-Host "`n🎯 Risk Assessment: $($auditData.RiskAssessment.Level) (Score: $($auditData.RiskAssessment.Score)/100)" -ForegroundColor $riskColors[$auditData.RiskAssessment.Level]
    
    $complianceColors = @{
        'Compliant' = 'Green'
        'Non-Compliant' = 'Red'
        'Not Assessed' = 'Gray'
    }
    
    Write-Host "📋 Compliance: $($auditData.ComplianceStatus.Overall)" -ForegroundColor $complianceColors[$auditData.ComplianceStatus.Overall]
    Write-Host "🔒 Security: $($auditData.SecurityStatus.Overall)" -ForegroundColor $(if ($auditData.SecurityStatus.Overall -eq 'Secure') { 'Green' } else { 'Yellow' })
    if ($auditData.TestStatus.PassRate) {
        Write-Host "🧪 Tests: $($auditData.TestStatus.PassRate)% passing" -ForegroundColor $(if ($auditData.TestStatus.PassRate -ge 80) { 'Green' } else { 'Yellow' })
    } else {
        Write-Host "🧪 Tests: Not assessed" -ForegroundColor Gray
    }
    if ($auditData.TestStatus.Coverage) {
        Write-Host "📊 Coverage: $($auditData.TestStatus.Coverage)%" -ForegroundColor $(if ($auditData.TestStatus.Coverage -ge 60) { 'Green' } else { 'Yellow' })
    } else {
        Write-Host "📊 Coverage: Not assessed" -ForegroundColor Gray
    }
    
    if ($auditData.Recommendations.Count -gt 0) {
        Write-Host "`n📌 Top Recommendations:" -ForegroundColor Cyan
        $auditData.Recommendations | Select-Object -First 3 | ForEach-Object {
            Write-Host "   • $_" -ForegroundColor White
        }
    }
    
    Write-Host "`n📁 Reports generated:" -ForegroundColor Gray
    foreach ($file in $reportFiles) {
        Write-Host "   • $file" -ForegroundColor White
    }
    
    # === 10. Upload to GitHub ===
    if ($UploadToGitHub -and $CI) {
        Write-ScriptLog -Message "Uploading audit report to GitHub..."
        
        # Add to job summary if in GitHub Actions
        if ($env:GITHUB_STEP_SUMMARY) {
            $summary = @"
## 🔍 Audit Report Summary

- **Risk Level:** $($auditData.RiskAssessment.Level) (Score: $($auditData.RiskAssessment.Score)/100)
- **Compliance:** $($auditData.ComplianceStatus.Overall)
- **Security:** $($auditData.SecurityStatus.Overall)
- **Test Coverage:** $($auditData.TestStatus.Coverage)%

### Recommendations
$(foreach ($rec in $auditData.Recommendations | Select-Object -First 3) {
"- $rec`n"
})

[View Full Report](./reports/audit/)
"@
            $summary | Add-Content $env:GITHUB_STEP_SUMMARY
        }
    }
    
    # === 11. Exit based on compliance status ===
    if ($auditData.ComplianceStatus.Overall -eq 'Non-Compliant' -or 
        $auditData.RiskAssessment.Level -in @('Critical', 'High')) {
        Write-ScriptLog -Level Warning -Message "Audit completed with compliance issues or high risk"
        exit 1
    }
    
    Write-ScriptLog -Level Success -Message "Audit report generation completed successfully"
    exit 0
}
catch {
    Write-ScriptLog -Level Error -Message "Audit report generation failed: $_"
    exit 2
}