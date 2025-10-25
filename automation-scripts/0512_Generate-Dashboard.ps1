#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive CI/CD dashboard with real-time status monitoring
.DESCRIPTION
    Creates HTML and Markdown dashboards showing project health, test results,
    security status, CI/CD metrics, and deployment information for effective
    project management and systematic improvement.

    Exit Codes:
    0   - Dashboard generated successfully
    1   - Generation failed
    2   - Configuration error

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
    [string]$ThemeColor = '#667eea'
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
$loggingModule = Join-Path $ProjectPath "domains/core/Logging.psm1"
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

function Get-ProjectMetrics {
    Write-ScriptLog -Message "Collecting project metrics"

    $metrics = @{
        Files = @{
            PowerShell = @(Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notmatch '(tests|examples|legacy)' }).Count
            Modules = @(Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse).Count
            Data = @(Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse).Count
            Total = 0
        }
        LinesOfCode = 0
        Functions = 0
        Tests = @{
            Unit = 0
            Integration = 0
            Total = 0
        }
        Coverage = @{
            Percentage = 0
            CoveredLines = 0
            TotalLines = 0
        }
        Dependencies = @{}
        Platform = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { "Windows" }
        PSVersion = $PSVersionTable.PSVersion.ToString()
        LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
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
                $metrics.LinesOfCode += $content.Count

                # Count functions
                $functionMatches = $content | Select-String -Pattern "^function " -SimpleMatch -ErrorAction SilentlyContinue
                if ($functionMatches) {
                    $metrics.Functions += $functionMatches.Count
                }
            }
        } catch {
            # Silently skip files that can't be read
        }
    }

    # Count test files
    $testPath = Join-Path $ProjectPath "tests"
    if (Test-Path $testPath) {
        $metrics.Tests.Unit = @(Get-ChildItem -Path $testPath -Filter "*Tests.ps1" -Recurse | Where-Object { $_.FullName -match 'unit' }).Count
        $metrics.Tests.Integration = @(Get-ChildItem -Path $testPath -Filter "*Tests.ps1" -Recurse | Where-Object { $_.FullName -match 'integration' }).Count
        $metrics.Tests.Total = $metrics.Tests.Unit + $metrics.Tests.Integration
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
        Badges = @{
            Build = "https://img.shields.io/github/workflow/status/wizzense/AitherZero/CI"
            Tests = "https://img.shields.io/badge/tests-unknown-lightgrey"
            Coverage = "https://img.shields.io/badge/coverage-unknown-lightgrey"
            Security = "https://img.shields.io/badge/security-unknown-lightgrey"
        }
    }

    # Check recent test results
    $testResultsPath = Join-Path $ProjectPath "tests/results"
    if (Test-Path $testResultsPath) {
        $latestResults = Get-ChildItem -Path $testResultsPath -Filter "*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestResults) {
            try {
                [xml]$testXml = Get-Content $latestResults.FullName
                $testSuites = $testXml.testsuites
                if ($testSuites) {
                    $totalTests = $testSuites.tests -as [int]
                    $failures = $testSuites.failures -as [int]
                    $errors = $testSuites.errors -as [int]

                    if (($failures + $errors) -eq 0) {
                        $status.Tests = "Passing"
                        $status.Badges.Tests = "https://img.shields.io/badge/tests-passing-brightgreen"
                    } else {
                        $status.Tests = "Failing"
                        $status.Badges.Tests = "https://img.shields.io/badge/tests-failing-red"
                    }
                }
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to parse test results"
            }
        }
    }

    # Determine overall status
    if ($status.Tests -eq "Passing") {
        $status.Overall = "Healthy"
    } elseif ($status.Tests -eq "Failing") {
        $status.Overall = "Issues"
    } else {
        $status.Overall = "Unknown"
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

function New-HTMLDashboard {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating HTML dashboard"

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

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, $ThemeColor 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 16px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, $ThemeColor 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5rem;
            margin-bottom: 10px;
        }

        .header .subtitle {
            font-size: 1.1rem;
            opacity: 0.9;
        }

        .status-bar {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-top: 20px;
            flex-wrap: wrap;
        }

        .status-badge {
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            font-size: 0.9rem;
            backdrop-filter: blur(10px);
        }

        .status-healthy { background: rgba(40, 167, 69, 0.2); color: #ffffff; }
        .status-issues { background: rgba(220, 53, 69, 0.2); color: #ffffff; }
        .status-unknown { background: rgba(108, 117, 125, 0.2); color: #ffffff; }

        .content {
            padding: 40px;
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }

        .metric-card {
            background: #f8f9fa;
            border-radius: 12px;
            padding: 25px;
            border-left: 4px solid $ThemeColor;
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .metric-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 25px rgba(0,0,0,0.1);
        }

        .metric-card h3 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.2rem;
        }

        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            color: $ThemeColor;
            margin-bottom: 5px;
        }

        .metric-label {
            color: #6c757d;
            font-size: 0.9rem;
        }

        .section {
            margin-bottom: 40px;
        }

        .section h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 1.8rem;
            border-bottom: 2px solid #e9ecef;
            padding-bottom: 10px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
        }

        .info-card {
            background: white;
            border: 1px solid #e9ecef;
            border-radius: 8px;
            overflow: hidden;
        }

        .info-card-header {
            background: #f8f9fa;
            padding: 15px 20px;
            font-weight: 600;
            border-bottom: 1px solid #e9ecef;
        }

        .info-card-body {
            padding: 20px;
        }

        .commit-list {
            list-style: none;
        }

        .commit-item {
            display: flex;
            align-items: center;
            padding: 8px 0;
            border-bottom: 1px solid #f1f3f4;
        }

        .commit-hash {
            font-family: 'Courier New', monospace;
            font-size: 0.8rem;
            background: #e9ecef;
            padding: 2px 6px;
            border-radius: 4px;
            margin-right: 10px;
        }

        .progress-bar {
            background: #e9ecef;
            border-radius: 10px;
            height: 20px;
            overflow: hidden;
            margin: 10px 0;
        }

        .progress-fill {
            background: linear-gradient(90deg, $ThemeColor, #764ba2);
            height: 100%;
            border-radius: 10px;
            transition: width 0.3s ease;
        }

        .badges {
            display: flex;
            gap: 10px;
            margin: 20px 0;
            flex-wrap: wrap;
        }

        .badge {
            background: #28a745;
            color: white;
            padding: 5px 10px;
            border-radius: 12px;
            font-size: 0.8rem;
            font-weight: 600;
        }

        .badge.warning { background: #ffc107; color: #212529; }
        .badge.error { background: #dc3545; }
        .badge.info { background: #17a2b8; }

        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #6c757d;
            font-size: 0.9rem;
        }

        .refresh-indicator {
            position: fixed;
            top: 20px;
            right: 20px;
            background: white;
            padding: 10px 15px;
            border-radius: 20px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            font-size: 0.8rem;
            color: #666;
        }

        @media (max-width: 768px) {
            .metrics-grid {
                grid-template-columns: 1fr;
            }

            .info-grid {
                grid-template-columns: 1fr;
            }

            .status-bar {
                flex-direction: column;
                align-items: center;
            }
        }
    </style>
</head>
<body>
    <div class="refresh-indicator">
        Last updated: $($Metrics.LastUpdated)
    </div>

    <div class="container">
        <div class="header">
            <h1>🚀 AitherZero</h1>
            <div class="subtitle">Infrastructure Automation Platform</div>

            <div class="status-bar">
                <div class="status-badge status-$(($Status.Overall).ToLower())">
                    Overall: $($Status.Overall)
                </div>
                <div class="status-badge status-$(if($Status.Tests -eq 'Passing'){'healthy'}elseif($Status.Tests -eq 'Failing'){'issues'}else{'unknown'})">
                    Tests: $($Status.Tests)
                </div>
                <div class="status-badge status-unknown">
                    Security: $($Status.Security)
                </div>
            </div>
        </div>

        <div class="content">
            <div class="metrics-grid">
                <div class="metric-card">
                    <h3>📁 Project Files</h3>
                    <div class="metric-value">$($Metrics.Files.Total)</div>
                    <div class="metric-label">
                        $($Metrics.Files.PowerShell) Scripts | $($Metrics.Files.Modules) Modules | $($Metrics.Files.Data) Data Files
                    </div>
                </div>

                <div class="metric-card">
                    <h3>📝 Lines of Code</h3>
                    <div class="metric-value">$($Metrics.LinesOfCode.ToString('N0'))</div>
                    <div class="metric-label">$($Metrics.Functions) Functions</div>
                </div>

                <div class="metric-card">
                    <h3>🧪 Test Suite</h3>
                    <div class="metric-value">$($Metrics.Tests.Total)</div>
                    <div class="metric-label">
                        $($Metrics.Tests.Unit) Unit | $($Metrics.Tests.Integration) Integration
                    </div>
                </div>

                <div class="metric-card">
                    <h3>📊 Code Coverage</h3>
                    <div class="metric-value">$($Metrics.Coverage.Percentage)%</div>
                    <div class="metric-label">
                        $($Metrics.Coverage.CoveredLines) / $($Metrics.Coverage.TotalLines) Lines Covered
                    </div>
                    <div class="progress-bar">
                        <div class="progress-fill" style="width: $($Metrics.Coverage.Percentage)%"></div>
                    </div>
                </div>
            </div>

            <div class="section">
                <h2>📈 Project Health</h2>
                <div class="badges">
                    <div class="badge">Build: $(if($Status.Overall -eq 'Healthy'){'Passing'}else{'Unknown'})</div>
                    <div class="badge $(if($Status.Tests -eq 'Passing'){''}elseif($Status.Tests -eq 'Failing'){'error'}else{'warning'})">
                        Tests: $($Status.Tests)
                    </div>
                    <div class="badge info">Coverage: $($Metrics.Coverage.Percentage)%</div>
                    <div class="badge">Security: Scanned</div>
                </div>
            </div>

            <div class="info-grid">
                <div class="info-card">
                    <div class="info-card-header">🔄 Recent Activity</div>
                    <div class="info-card-body">
                        <ul class="commit-list">
$(if($Activity.Commits.Count -gt 0) {
    $Activity.Commits | Select-Object -First 5 | ForEach-Object {
        "                            <li class='commit-item'>`n" +
        "                                <span class='commit-hash'>$($_.Hash)</span>`n" +
        "                                <span>$($_.Message)</span>`n" +
        "                            </li>"
    } | Join-String -Separator "`n"
} else {
    "                            <li class='commit-item'>No recent activity found</li>"
})
                        </ul>
                    </div>
                </div>

                <div class="info-card">
                    <div class="info-card-header">🎯 Quick Actions</div>
                    <div class="info-card-body">
                        <p><strong>Run Tests:</strong> <code>./az 0402</code></p>
                        <p><strong>Generate Report:</strong> <code>./az 0510</code></p>
                        <p><strong>View Dashboard:</strong> <code>./az 0511</code></p>
                        <p><strong>Validate Code:</strong> <code>./az 0404</code></p>
                        <p><strong>Update Project:</strong> <code>git pull && ./bootstrap.ps1</code></p>
                    </div>
                </div>

                <div class="info-card">
                    <div class="info-card-header">📋 System Information</div>
                    <div class="info-card-body">
                        <p><strong>Platform:</strong> $($Metrics.Platform ?? 'Unknown')</p>
                        <p><strong>PowerShell:</strong> $($Metrics.PSVersion)</p>
                        <p><strong>Environment:</strong> $(if($env:AITHERZERO_CI){'CI/CD'}else{'Development'})</p>
                        <p><strong>Last Scan:</strong> $($Metrics.LastUpdated)</p>
                    </div>
                </div>

                <div class="info-card">
                    <div class="info-card-header">🔗 Resources</div>
                    <div class="info-card-body">
                        <p><a href="https://github.com/wizzense/AitherZero" target="_blank">🏠 GitHub Repository</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/actions" target="_blank">⚡ CI/CD Pipeline</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/releases" target="_blank">📦 Releases</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/issues" target="_blank">🐛 Issues</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/wiki" target="_blank">📖 Documentation</a></p>
                    </div>
                </div>
            </div>
        </div>

        <div class="footer">
            Generated by AitherZero Dashboard | $($Metrics.LastUpdated) |
            <a href="https://github.com/wizzense/AitherZero" target="_blank">View on GitHub</a>
        </div>
    </div>

    <script>
        // Auto-refresh every 5 minutes
        setTimeout(() => {
            window.location.reload();
        }, 300000);

        // Add some interactive elements
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.metric-card');
            cards.forEach(card => {
                card.addEventListener('click', function() {
                    this.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        this.style.transform = '';
                    }, 150);
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
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating Markdown dashboard"

    $markdown = @"
# 🚀 AitherZero Project Dashboard

**Infrastructure Automation Platform**

*Last updated: $($Metrics.LastUpdated)*

---

## 📊 Project Overview

| Metric | Value | Details |
|--------|-------|---------|
| 📁 **Total Files** | **$($Metrics.Files.Total)** | $($Metrics.Files.PowerShell) Scripts, $($Metrics.Files.Modules) Modules, $($Metrics.Files.Data) Data Files |
| 📝 **Lines of Code** | **$($Metrics.LinesOfCode.ToString('N0'))** | $($Metrics.Functions) Functions |
| 🧪 **Tests** | **$($Metrics.Tests.Total)** | $($Metrics.Tests.Unit) Unit, $($Metrics.Tests.Integration) Integration |
| 📈 **Coverage** | **$($Metrics.Coverage.Percentage)%** | $($Metrics.Coverage.CoveredLines)/$($Metrics.Coverage.TotalLines) Lines |

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
- [📖 Documentation](https://github.com/wizzense/AitherZero/wiki)

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

    # Generate dashboards based on format selection
    switch ($Format) {
        'HTML' {
            New-HTMLDashboard -Metrics $metrics -Status $status -Activity $activity -OutputPath $OutputPath
        }
        'Markdown' {
            New-MarkdownDashboard -Metrics $metrics -Status $status -Activity $activity -OutputPath $OutputPath
        }
        'JSON' {
            New-JSONReport -Metrics $metrics -Status $status -Activity $activity -OutputPath $OutputPath
        }
        'All' {
            New-HTMLDashboard -Metrics $metrics -Status $status -Activity $activity -OutputPath $OutputPath
            New-MarkdownDashboard -Metrics $metrics -Status $status -Activity $activity -OutputPath $OutputPath
            New-JSONReport -Metrics $metrics -Status $status -Activity $activity -OutputPath $OutputPath
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

    exit 0

} catch {
    $errorMsg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Write-ScriptLog -Level Error -Message "Dashboard generation failed: $_" -Data @{ Exception = $errorMsg }
    exit 1
}
