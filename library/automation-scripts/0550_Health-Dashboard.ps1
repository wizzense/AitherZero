#Requires -Version 7.0
# Stage: Reporting
# Dependencies: LogViewer, Testing
# Description: Consolidated health and status dashboard for AitherZero with HTML export
# Tags: health, dashboard, monitoring, reporting, html

<#
.SYNOPSIS
    Real-time operational health dashboard for local development and troubleshooting

.DESCRIPTION
    Displays immediate system health metrics for active development sessions, including:
    - PowerShell environment and module status
    - Recent errors and warnings from current session
    - Disk space and resource availability
    - Local test execution results
    - Code quality from latest analysis
    
    COMPLEMENTARY TO 0512: This dashboard provides real-time operational status for
    developers working locally, while script 0512 generates comprehensive CI/CD metrics
    and project-wide statistics deployed to GitHub Pages for strategic oversight.
    
    Use Cases:
    - 0550 (this script): "Is my dev environment healthy right now?"
    - 0512: "How is the overall project performing over time?"

.PARAMETER Configuration
    Configuration hashtable

.PARAMETER NonInteractive
    Run without user prompts

.PARAMETER ShowAll
    Show all details including full error lists

.PARAMETER Format
    Output format: Text (default), HTML, JSON, Markdown

.PARAMETER OutputFile
    Save output to file (HTML format automatically saved)

.PARAMETER Open
    Automatically open HTML report in browser

.PARAMETER Detailed
    Show detailed metrics and historical data

.EXAMPLE
    ./0550_Health-Dashboard.ps1
    Quick health check - shows immediate operational status

.EXAMPLE
    ./0550_Health-Dashboard.ps1 -Format HTML -Open
    Generate local HTML health report and open in browser

.EXAMPLE
    ./0550_Health-Dashboard.ps1 -Detailed -ShowAll
    Comprehensive health check with all error details

.EXAMPLE
    ./0550_Health-Dashboard.ps1 -Format JSON -OutputFile health.json
    Export health data for integration with monitoring tools

.NOTES
    Part of Phase 0 QoL enhancements - User-requested feature
    Enhanced with HTML output and comprehensive metrics
    
    Relationship to 0512 Project Dashboard:
    - 0550: Real-time operational health (local, immediate)
    - 0512: Strategic project metrics (CI/CD, trends, GitHub Pages)
    
    Both dashboards provide value:
    - Use 0550 before starting work or when troubleshooting
    - Use 0512 (GitHub Pages) for project overview and stakeholder communication
#>

[CmdletBinding()]
param(
    [Parameter()]
    [hashtable]$Configuration,

    [Parameter()]
    [switch]$NonInteractive,

    [Parameter()]
    [switch]$ShowAll,
    
    [Parameter()]
    [ValidateSet('Text', 'HTML', 'JSON', 'Markdown')]
    [string]$Format = 'Text',
    
    [Parameter()]
    [string]$OutputFile,
    
    [Parameter()]
    [switch]$Open,
    
    [Parameter()]
    [switch]$Detailed
)

# Initialize environment
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Configuration constants
$script:CoreModules = @('Logging', 'LogViewer', 'Configuration')
$script:TestResultsPath = 'library/tests/test-results.json'

# Import required modules
$modulesToImport = @(
    "domains/utilities/LogViewer.psm1",
    "aithercore/utilities/Logging.psm1"
)

foreach ($modulePath in $modulesToImport) {
    $fullPath = Join-Path $ProjectRoot $modulePath
    if (Test-Path $fullPath) {
        Import-Module $fullPath -Force -ErrorAction SilentlyContinue
    }
}

function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    }
}

function Get-SystemHealth {
    <#
    .SYNOPSIS
        Gets overall system health status
    #>
    $health = @{
        Status = 'Healthy'
        Issues = @()
        Checks = @{
            PowerShell = $false
            Modules = $false
            Logging = $false
            Tests = $false
        }
    }

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $health.Checks.PowerShell = $true
    } else {
        $health.Status = 'Warning'
        $health.Issues += "PowerShell 7+ required (Current: $($PSVersionTable.PSVersion))"
    }

    # Check core modules (using script-level constant)
    $loadedModules = Get-Module | Select-Object -ExpandProperty Name
    $missingModules = $script:CoreModules | Where-Object { $_ -notin $loadedModules }
    
    if ($missingModules.Count -eq 0) {
        $health.Checks.Modules = $true
    } else {
        $health.Status = 'Warning'
        $health.Issues += "Missing modules: $($missingModules -join ', ')"
    }

    # Check logging system
    if (Test-Path (Join-Path $ProjectRoot "logs")) {
        $health.Checks.Logging = $true
    } else {
        $health.Status = 'Warning'
        $health.Issues += "Logs directory not found"
    }

    # Check test infrastructure
    if (Test-Path (Join-Path $ProjectRoot "tests")) {
        $health.Checks.Tests = $true
    }

    # Determine overall status
    $healthyChecks = ($health.Checks.Values | Where-Object { $_ -eq $true }).Count
    $totalChecks = $health.Checks.Count
    
    if ($healthyChecks -lt $totalChecks * 0.5) {
        $health.Status = 'Critical'
    } elseif ($health.Issues.Count -gt 0) {
        $health.Status = 'Warning'
    }

    return [PSCustomObject]$health
}

function Get-RecentErrors {
    <#
    .SYNOPSIS
        Gets recent errors and warnings from logs
    #>
    $logFiles = Get-LogFile -Type Application -ErrorAction SilentlyContinue
    if (-not $logFiles) {
        return @()
    }

    $latest = $logFiles[0]
    $content = Get-Content $latest.FullName -Tail 200 -ErrorAction SilentlyContinue
    
    $errors = @{
        Errors = @()
        Warnings = @()
    }

    foreach ($line in $content) {
        if ($line -match '\[ERROR\s*\]') {
            $errors.Errors += $line
        } elseif ($line -match '\[WARNING\s*\]') {
            $errors.Warnings += $line
        }
    }

    return [PSCustomObject]$errors
}

function Get-TestResults {
    <#
    .SYNOPSIS
        Gets latest test execution results if available
    #>
    $testResults = @{
        Available = $false
        LastRun = $null
        Passed = 0
        Failed = 0
        Skipped = 0
        Total = 0
    }

    # Check for test results file (using script-level constant)
    $resultsPath = Join-Path $ProjectRoot $script:TestResultsPath
    if (Test-Path $resultsPath) {
        try {
            $data = Get-Content $resultsPath -Raw | ConvertFrom-Json
            $testResults.Available = $true
            $testResults.LastRun = $data.Timestamp
            $testResults.Passed = $data.Passed
            $testResults.Failed = $data.Failed
            $testResults.Skipped = $data.Skipped
            $testResults.Total = $data.Total
        } catch {
            Write-ScriptLog "Failed to read test results: $_" -Level 'Warning'
        }
    }

    return [PSCustomObject]$testResults
}

function Get-DiskSpace {
    <#
    .SYNOPSIS
        Gets disk space information
    #>
    $diskInfo = @{
        Available = $false
        FreeGB = 0
        TotalGB = 0
        UsedPercent = 0
        Status = 'Unknown'
    }
    
    try {
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            $drive = Get-PSDrive -Name ($ProjectRoot[0]) -ErrorAction SilentlyContinue
            if ($drive) {
                $diskInfo.Available = $true
                $diskInfo.FreeGB = [Math]::Round($drive.Free / 1GB, 2)
                $diskInfo.TotalGB = [Math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
                $diskInfo.UsedPercent = [Math]::Round(($drive.Used / ($drive.Free + $drive.Used)) * 100, 1)
            }
        } else {
            # Linux/macOS
            $df = df -BG $ProjectRoot 2>$null | Select-Object -Skip 1
            if ($df) {
                $parts = $df -split '\s+'
                $diskInfo.Available = $true
                $diskInfo.TotalGB = [int]($parts[1] -replace 'G', '')
                $diskInfo.FreeGB = [int]($parts[3] -replace 'G', '')
                $diskInfo.UsedPercent = [int]($parts[4] -replace '%', '')
            }
        }
        
        # Determine status
        if ($diskInfo.FreeGB -lt 5) {
            $diskInfo.Status = 'Critical'
        } elseif ($diskInfo.FreeGB -lt 10) {
            $diskInfo.Status = 'Warning'
        } else {
            $diskInfo.Status = 'Healthy'
        }
    } catch {
        Write-ScriptLog "Failed to get disk space: $_" -Level 'Warning'
    }
    
    return [PSCustomObject]$diskInfo
}

function Get-CodeQualityMetrics {
    <#
    .SYNOPSIS
        Gets code quality metrics from PSScriptAnalyzer results
    #>
    $quality = @{
        Available = $false
        Errors = 0
        Warnings = 0
        Information = 0
        TotalIssues = 0
        Status = 'Unknown'
        LastAnalysis = $null
    }
    
    # Check for PSScriptAnalyzer results
    $analysisPath = Join-Path $ProjectRoot "library/library/tests/analysis"
    if (Test-Path $analysisPath) {
        $latestCSV = Get-ChildItem -Path $analysisPath -Filter "*.csv" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($latestCSV) {
            try {
                $results = Import-Csv $latestCSV.FullName
                $quality.Available = $true
                $quality.LastAnalysis = $latestCSV.LastWriteTime
                $quality.Errors = ($results | Where-Object { $_.Severity -eq 'Error' }).Count
                $quality.Warnings = ($results | Where-Object { $_.Severity -eq 'Warning' }).Count
                $quality.Information = ($results | Where-Object { $_.Severity -eq 'Information' }).Count
                $quality.TotalIssues = $results.Count
                
                # Determine status
                if ($quality.Errors -gt 10) {
                    $quality.Status = 'Critical'
                } elseif ($quality.Errors -gt 0 -or $quality.Warnings -gt 50) {
                    $quality.Status = 'Warning'
                } else {
                    $quality.Status = 'Healthy'
                }
            } catch {
                Write-ScriptLog "Failed to read analysis results: $_" -Level 'Warning'
            }
        }
    }
    
    return [PSCustomObject]$quality
}

function Get-SecurityStatus {
    <#
    .SYNOPSIS
        Gets security-related status information
    #>
    $security = @{
        CertificateChecks = $false
        CredentialStorage = $false
        Status = 'Unknown'
        Issues = @()
    }
    
    # Check if security module is loaded
    $securityModule = Get-Module -Name Security -ErrorAction SilentlyContinue
    if ($securityModule) {
        $security.CredentialStorage = $true
    }
    
    # Check for certificate management
    $certPath = Join-Path $ProjectRoot "certificates"
    if (Test-Path $certPath) {
        $security.CertificateChecks = $true
    }
    
    # Determine overall status
    if ($security.CredentialStorage -and $security.CertificateChecks) {
        $security.Status = 'Healthy'
    } elseif ($security.CredentialStorage -or $security.CertificateChecks) {
        $security.Status = 'Warning'
        $security.Issues += "Some security features not configured"
    } else {
        $security.Status = 'Warning'
        $security.Issues += "Security features not initialized"
    }
    
    return [PSCustomObject]$security
}

function Get-ComprehensiveHealth {
    <#
    .SYNOPSIS
        Gets comprehensive health metrics across all categories
    #>
    $health = @{
        Timestamp = Get-Date -Format 'o'
        OverallStatus = 'Healthy'
        System = Get-SystemHealth
        DiskSpace = Get-DiskSpace
        TestResults = Get-TestResults
        CodeQuality = Get-CodeQualityMetrics
        Security = Get-SecurityStatus
        RecentErrors = Get-RecentErrors
        LogStats = $null
    }
    
    # Get log statistics
    $logFiles = Get-LogFile -Type Application -ErrorAction SilentlyContinue
    if ($logFiles) {
        $latest = $logFiles[0]
        $health.LogStats = Get-LogStatistic -Path $latest.FullName -ErrorAction SilentlyContinue
    }
    
    # Determine overall status based on all checks
    $criticalCount = 0
    $warningCount = 0
    
    foreach ($category in @('System', 'DiskSpace', 'CodeQuality', 'Security')) {
        $status = $health[$category].Status
        if ($status -eq 'Critical') { $criticalCount++ }
        elseif ($status -eq 'Warning') { $warningCount++ }
    }
    
    if ($criticalCount -gt 0) {
        $health.OverallStatus = 'Critical'
    } elseif ($warningCount -gt 1) {
        $health.OverallStatus = 'Warning'
    } else {
        $health.OverallStatus = 'Healthy'
    }
    
    return [PSCustomObject]$health
}

function New-HTMLHealthReport {
    <#
    .SYNOPSIS
        Generates HTML health dashboard report
    #>
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$HealthData
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $statusColor = switch ($HealthData.OverallStatus) {
        'Healthy' { '#28a745' }
        'Warning' { '#ffc107' }
        'Critical' { '#dc3545' }
        default { '#6c757d' }
    }
    
    $statusIcon = switch ($HealthData.OverallStatus) {
        'Healthy' { '✅' }
        'Warning' { '⚠️' }
        'Critical' { '❌' }
        default { '❓' }
    }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Health Dashboard - $timestamp</title>
    <style>
        :root {
            --healthy: #28a745;
            --warning: #ffc107;
            --critical: #dc3545;
            --info: #17a2b8;
            --dark: #343a40;
            --light: #f8f9fa;
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 15px;
        }
        
        .header .subtitle {
            font-size: 0.9em;
            opacity: 0.9;
            margin-top: 5px;
        }
        
        .header .timestamp {
            font-size: 0.85em;
            opacity: 0.8;
            margin-top: 10px;
        }
        
        .relationship-note {
            background: #e3f2fd;
            border-left: 4px solid #2196f3;
            padding: 15px 20px;
            margin: 20px;
            border-radius: 4px;
            font-size: 0.9em;
            line-height: 1.6;
        }
        
        .relationship-note strong {
            color: #1976d2;
        }
        
        .overall-status {
            text-align: center;
            padding: 40px;
            background: var(--light);
            border-bottom: 3px solid $statusColor;
        }
        
        .overall-status .status-badge {
            display: inline-block;
            font-size: 3em;
            margin-bottom: 10px;
        }
        
        .overall-status h2 {
            font-size: 2em;
            color: $statusColor;
            margin-bottom: 10px;
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        
        .metric-card {
            background: white;
            border-radius: 8px;
            padding: 20px;
            border-left: 4px solid;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            transition: transform 0.2s, box-shadow 0.2s;
        }
        
        .metric-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        }
        
        .metric-card.healthy { border-color: var(--healthy); }
        .metric-card.warning { border-color: var(--warning); }
        .metric-card.critical { border-color: var(--critical); }
        .metric-card.unknown { border-color: var(--dark); }
        
        .metric-card h3 {
            font-size: 1.3em;
            margin-bottom: 15px;
            color: var(--dark);
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .metric-card .status-indicator {
            font-size: 1.5em;
        }
        
        .metric-item {
            padding: 8px 0;
            border-bottom: 1px solid var(--light);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .metric-item:last-child {
            border-bottom: none;
        }
        
        .metric-label {
            font-weight: 500;
            color: #666;
        }
        
        .metric-value {
            font-weight: 600;
            color: var(--dark);
        }
        
        .metric-value.success { color: var(--healthy); }
        .metric-value.warning { color: var(--warning); }
        .metric-value.error { color: var(--critical); }
        
        .issues-list {
            background: #fff3cd;
            border-left: 4px solid var(--warning);
            padding: 15px;
            margin-top: 15px;
            border-radius: 4px;
        }
        
        .issues-list ul {
            list-style: none;
            padding-left: 0;
        }
        
        .issues-list li {
            padding: 5px 0;
            padding-left: 25px;
            position: relative;
        }
        
        .issues-list li:before {
            content: '⚠️';
            position: absolute;
            left: 0;
        }
        
        .footer {
            background: var(--light);
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
            border-top: 1px solid #dee2e6;
        }
        
        .footer a {
            color: #667eea;
            text-decoration: none;
        }
        
        .footer a:hover {
            text-decoration: underline;
        }
        
        .quick-actions {
            background: var(--light);
            padding: 20px;
            margin: 20px;
            border-radius: 8px;
        }
        
        .quick-actions h3 {
            margin-bottom: 15px;
            color: var(--dark);
        }
        
        .quick-actions ul {
            list-style: none;
            padding-left: 0;
        }
        
        .quick-actions li {
            padding: 8px 0;
            color: #666;
        }
        
        .quick-actions li:before {
            content: '💡';
            margin-right: 10px;
        }
        
        @media (max-width: 768px) {
            .metrics-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 1.8em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>
                <span>🏥</span>
                <span>AitherZero Health Dashboard</span>
            </h1>
            <div class="subtitle">Real-Time Operational Status</div>
            <div class="timestamp">Generated: $timestamp</div>
        </div>
        
        <!-- Relationship Note -->
        <div class="relationship-note">
            <strong>ℹ️ Dashboard Purpose:</strong> This health dashboard provides <strong>real-time operational status</strong> for local development and troubleshooting.
            For comprehensive <strong>CI/CD metrics and project-wide statistics</strong>, see the 
            <a href="https://wizzense.github.io/AitherZero/" target="_blank">Project Dashboard (Script 0512)</a> deployed on GitHub Pages.
            <br><br>
            <strong>Use this dashboard (0550) when:</strong> Starting work, troubleshooting issues, checking immediate system health
            <br>
            <strong>Use Project Dashboard (0512) for:</strong> Strategic overview, trends over time, stakeholder communication
        </div>
        
        <!-- Overall Status -->
        <div class="overall-status">
            <div class="status-badge">$statusIcon</div>
            <h2>Overall Status: $($HealthData.OverallStatus)</h2>
            <p>All system checks evaluated at $(Get-Date -Format 'HH:mm:ss')</p>
        </div>
        
        <!-- Metrics Grid -->
        <div class="metrics-grid">
"@

    # System Health Card
    $sysStatus = $HealthData.System.Status.ToLower()
    $html += @"
            <div class="metric-card $sysStatus">
                <h3><span class="status-indicator">💻</span> System Health</h3>
                <div class="metric-item">
                    <span class="metric-label">PowerShell Version</span>
                    <span class="metric-value success">$($PSVersionTable.PSVersion)</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Modules Loaded</span>
                    <span class="metric-value">$((Get-Module).Count) modules</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Logging System</span>
                    <span class="metric-value $(if ($HealthData.System.Checks.Logging) { 'success' } else { 'error' })">
                        $(if ($HealthData.System.Checks.Logging) { '✅ Active' } else { '❌ Inactive' })
                    </span>
                </div>
"@
    if ($HealthData.System.Issues.Count -gt 0) {
        $html += @"
                <div class="issues-list">
                    <strong>Issues:</strong>
                    <ul>
"@
        foreach ($issue in $HealthData.System.Issues) {
            $html += "                        <li>$issue</li>`n"
        }
        $html += @"
                    </ul>
                </div>
"@
    }
    $html += "            </div>`n"
    
    # Disk Space Card
    $diskStatus = $HealthData.DiskSpace.Status.ToLower()
    $html += @"
            <div class="metric-card $diskStatus">
                <h3><span class="status-indicator">💾</span> Disk Space</h3>
                <div class="metric-item">
                    <span class="metric-label">Free Space</span>
                    <span class="metric-value $(if ($HealthData.DiskSpace.FreeGB -gt 10) { 'success' } elseif ($HealthData.DiskSpace.FreeGB -gt 5) { 'warning' } else { 'error' })">
                        $($HealthData.DiskSpace.FreeGB) GB
                    </span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Total Space</span>
                    <span class="metric-value">$($HealthData.DiskSpace.TotalGB) GB</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Used</span>
                    <span class="metric-value">$($HealthData.DiskSpace.UsedPercent)%</span>
                </div>
            </div>
"@

    # Test Results Card
    if ($HealthData.TestResults.Available) {
        $testStatus = if ($HealthData.TestResults.Failed -gt 0) { 'warning' } else { 'healthy' }
        $passRate = if ($HealthData.TestResults.Total -gt 0) {
            [Math]::Round(($HealthData.TestResults.Passed / $HealthData.TestResults.Total) * 100, 1)
        } else { 0 }
        
        $html += @"
            <div class="metric-card $testStatus">
                <h3><span class="status-indicator">🧪</span> Test Results</h3>
                <div class="metric-item">
                    <span class="metric-label">Total Tests</span>
                    <span class="metric-value">$($HealthData.TestResults.Total)</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Passed</span>
                    <span class="metric-value success">✅ $($HealthData.TestResults.Passed)</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Failed</span>
                    <span class="metric-value $(if ($HealthData.TestResults.Failed -gt 0) { 'error' } else { 'success' })">
                        $(if ($HealthData.TestResults.Failed -gt 0) { "❌ $($HealthData.TestResults.Failed)" } else { '0' })
                    </span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Pass Rate</span>
                    <span class="metric-value $(if ($passRate -ge 90) { 'success' } elseif ($passRate -ge 70) { 'warning' } else { 'error' })">
                        $passRate%
                    </span>
                </div>
            </div>
"@
    }
    
    # Code Quality Card
    if ($HealthData.CodeQuality.Available) {
        $qualStatus = $HealthData.CodeQuality.Status.ToLower()
        $html += @"
            <div class="metric-card $qualStatus">
                <h3><span class="status-indicator">📊</span> Code Quality</h3>
                <div class="metric-item">
                    <span class="metric-label">PSScriptAnalyzer</span>
                    <span class="metric-value">Last: $($HealthData.CodeQuality.LastAnalysis.ToString('yyyy-MM-dd HH:mm'))</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Errors</span>
                    <span class="metric-value $(if ($HealthData.CodeQuality.Errors -gt 0) { 'error' } else { 'success' })">
                        $($HealthData.CodeQuality.Errors)
                    </span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Warnings</span>
                    <span class="metric-value $(if ($HealthData.CodeQuality.Warnings -gt 10) { 'warning' } else { 'success' })">
                        $($HealthData.CodeQuality.Warnings)
                    </span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Total Issues</span>
                    <span class="metric-value">$($HealthData.CodeQuality.TotalIssues)</span>
                </div>
            </div>
"@
    }
    
    # Recent Errors Card
    if ($HealthData.RecentErrors.Errors.Count -gt 0 -or $HealthData.RecentErrors.Warnings.Count -gt 0) {
        $errorStatus = if ($HealthData.RecentErrors.Errors.Count -gt 5) { 'critical' } elseif ($HealthData.RecentErrors.Errors.Count -gt 0) { 'warning' } else { 'healthy' }
        $html += @"
            <div class="metric-card $errorStatus">
                <h3><span class="status-indicator">🔍</span> Recent Issues</h3>
                <div class="metric-item">
                    <span class="metric-label">Errors (Last 200 lines)</span>
                    <span class="metric-value $(if ($HealthData.RecentErrors.Errors.Count -gt 0) { 'error' } else { 'success' })">
                        $($HealthData.RecentErrors.Errors.Count)
                    </span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Warnings (Last 200 lines)</span>
                    <span class="metric-value $(if ($HealthData.RecentErrors.Warnings.Count -gt 0) { 'warning' } else { 'success' })">
                        $($HealthData.RecentErrors.Warnings.Count)
                    </span>
                </div>
            </div>
"@
    }
    
    # Log Statistics Card
    if ($HealthData.LogStats) {
        $html += @"
            <div class="metric-card healthy">
                <h3><span class="status-indicator">📋</span> Log Statistics</h3>
                <div class="metric-item">
                    <span class="metric-label">Current Log File</span>
                    <span class="metric-value">$($HealthData.LogStats.FileName)</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Size</span>
                    <span class="metric-value">$($HealthData.LogStats.SizeKB) KB</span>
                </div>
                <div class="metric-item">
                    <span class="metric-label">Total Entries</span>
                    <span class="metric-value">$($HealthData.LogStats.TotalLines)</span>
                </div>
            </div>
"@
    }
    
    $html += @"
        </div>
        
        <!-- Quick Actions -->
        <div class="quick-actions">
            <h3>💡 Quick Actions</h3>
            <ul>
                <li>Search logs: <code>./automation-scripts/0830_Search-AllLogs.ps1 -Pattern "error"</code></li>
                <li>Run tests: <code>./automation-scripts/0402_Run-UnitTests.ps1</code></li>
                <li>Check code quality: <code>./automation-scripts/0404_Run-PSScriptAnalyzer.ps1</code></li>
                <li>View project dashboard: Visit <a href="https://wizzense.github.io/AitherZero/" target="_blank">GitHub Pages</a></li>
            </ul>
        </div>
        
        <!-- Footer -->
        <div class="footer">
            <p>
                <strong>AitherZero Health Dashboard</strong> | 
                Generated by Script 0550 | 
                <a href="https://github.com/wizzense/AitherZero" target="_blank">GitHub Repository</a>
            </p>
            <p style="margin-top: 10px; font-size: 0.85em;">
                For comprehensive project metrics and CI/CD status, visit the 
                <a href="https://wizzense.github.io/AitherZero/" target="_blank">Project Dashboard (Script 0512)</a>
            </p>
        </div>
    </div>
</body>
</html>
"@
    
    return $html
}

function Show-HealthDashboard {
    <#
    .SYNOPSIS
        Displays the consolidated health dashboard
    #>
    param([switch]$ShowAll)

    Write-Host "`n╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           AitherZero Health Dashboard                    ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    # System Health
    Write-Host "`n📊 System Health" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $health = Get-SystemHealth
    
    $statusColor = switch ($health.Status) {
        'Healthy' { 'Green' }
        'Warning' { 'Yellow' }
        'Critical' { 'Red' }
        default { 'Gray' }
    }
    
    $statusIcon = switch ($health.Status) {
        'Healthy' { '✅' }
        'Warning' { '⚠️ ' }
        'Critical' { '❌' }
        default { '❓' }
    }
    
    Write-Host "  Overall Status: " -NoNewline
    Write-Host "$statusIcon $($health.Status)" -ForegroundColor $statusColor

    Write-Host "`n  Component Checks:" -ForegroundColor Gray
    foreach ($check in $health.Checks.GetEnumerator()) {
        $icon = if ($check.Value) { '✅' } else { '❌' }
        $color = if ($check.Value) { 'Green' } else { 'Red' }
        Write-Host "    $icon $($check.Key)" -ForegroundColor $color
    }

    if ($health.Issues.Count -gt 0) {
        Write-Host "`n  Issues Detected:" -ForegroundColor Yellow
        foreach ($issue in $health.Issues) {
            Write-Host "    • $issue" -ForegroundColor Yellow
        }
    }

    # Recent Errors & Warnings
    Write-Host "`n🔍 Recent Errors & Warnings" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $recent = Get-RecentErrors
    
    if ($recent.Errors.Count -eq 0 -and $recent.Warnings.Count -eq 0) {
        Write-Host "  ✅ No recent errors or warnings" -ForegroundColor Green
    } else {
        if ($recent.Errors.Count -gt 0) {
            Write-Host "  ❌ Errors: $($recent.Errors.Count)" -ForegroundColor Red
            if ($ShowAll) {
                $recent.Errors | Select-Object -First 5 | ForEach-Object {
                    Write-Host "     $_" -ForegroundColor Red
                }
                if ($recent.Errors.Count -gt 5) {
                    Write-Host "     ... and $($recent.Errors.Count - 5) more" -ForegroundColor DarkRed
                }
            }
        }
        
        if ($recent.Warnings.Count -gt 0) {
            Write-Host "  ⚠️  Warnings: $($recent.Warnings.Count)" -ForegroundColor Yellow
            if ($ShowAll) {
                $recent.Warnings | Select-Object -First 5 | ForEach-Object {
                    Write-Host "     $_" -ForegroundColor Yellow
                }
                if ($recent.Warnings.Count -gt 5) {
                    Write-Host "     ... and $($recent.Warnings.Count - 5) more" -ForegroundColor DarkYellow
                }
            }
        }
    }

    # Test Results
    Write-Host "`n🧪 Test Results" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $testResults = Get-TestResults
    
    if ($testResults.Available) {
        Write-Host "  Last Run: $($testResults.LastRun)" -ForegroundColor Gray
        Write-Host "  Total Tests: $($testResults.Total)" -ForegroundColor White
        
        if ($testResults.Passed -gt 0) {
            Write-Host "  ✅ Passed: $($testResults.Passed)" -ForegroundColor Green
        }
        if ($testResults.Failed -gt 0) {
            Write-Host "  ❌ Failed: $($testResults.Failed)" -ForegroundColor Red
        }
        if ($testResults.Skipped -gt 0) {
            Write-Host "  ⏭️  Skipped: $($testResults.Skipped)" -ForegroundColor Yellow
        }
        
        $passRate = if ($testResults.Total -gt 0) {
            [Math]::Round(($testResults.Passed / $testResults.Total) * 100, 1)
        } else { 0 }
        
        Write-Host "  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { 'Green' } elseif ($passRate -ge 70) { 'Yellow' } else { 'Red' })
    } else {
        Write-Host "  ℹ️  No test results available" -ForegroundColor Gray
        Write-Host "  Run tests from the Testing menu to generate results" -ForegroundColor DarkGray
    }

    # Log Statistics
    Write-Host "`n📋 Log Statistics" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    
    $logFiles = Get-LogFile -Type Application -ErrorAction SilentlyContinue
    if ($logFiles) {
        $latest = $logFiles[0]
        $stats = Get-LogStatistic -Path $latest.FullName -ErrorAction SilentlyContinue
        
        if ($stats) {
            Write-Host "  Current Log: $($stats.FileName)" -ForegroundColor Gray
            Write-Host "  Size: $($stats.SizeKB) KB" -ForegroundColor Gray
            Write-Host "  Total Entries: $($stats.TotalLines)" -ForegroundColor White
            
            if ($stats.LogLevels.Critical -gt 0) {
                Write-Host "  🔴 Critical: $($stats.LogLevels.Critical)" -ForegroundColor Magenta
            }
            if ($stats.LogLevels.Error -gt 0) {
                Write-Host "  ❌ Errors: $($stats.LogLevels.Error)" -ForegroundColor Red
            }
            if ($stats.LogLevels.Warning -gt 0) {
                Write-Host "  ⚠️  Warnings: $($stats.LogLevels.Warning)" -ForegroundColor Yellow
            }
            Write-Host "  ℹ️  Info: $($stats.LogLevels.Information)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  ⚠️  No log files found" -ForegroundColor Yellow
    }

    # Quick Actions
    Write-Host "`n💡 Quick Actions" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  • Search logs: ./automation-scripts/0830_Search-AllLogs.ps1 -Pattern 'error'" -ForegroundColor Gray
    Write-Host "  • Run tests: Testing > Run Unit Tests" -ForegroundColor Gray
    Write-Host "  • View full logs: Reports & Logs > Log Dashboard" -ForegroundColor Gray
    Write-Host "  • Check system: Testing > Validate Environment" -ForegroundColor Gray
    
    # Relationship with 0512
    Write-Host "`n📊 Related Dashboards" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "  This is your " -NoNewline -ForegroundColor Gray
    Write-Host "OPERATIONAL HEALTH" -NoNewline -ForegroundColor Cyan
    Write-Host " dashboard (real-time, local)" -ForegroundColor Gray
    Write-Host "  For " -NoNewline -ForegroundColor Gray
    Write-Host "PROJECT METRICS" -NoNewline -ForegroundColor Green
    Write-Host " see: https://wizzense.github.io/AitherZero/" -ForegroundColor Gray
    Write-Host "  (Generated by Script 0512 - CI/CD stats, trends, GitHub Pages)" -ForegroundColor DarkGray

    Write-Host ""
}

# Main execution
Write-ScriptLog "Starting Health Dashboard (Format: $Format)"

try {
    # Get comprehensive health data
    $healthData = Get-ComprehensiveHealth
    
    switch ($Format) {
        'Text' {
            Show-HealthDashboard -ShowAll:$ShowAll
        }
        
        'HTML' {
            $htmlContent = New-HTMLHealthReport -HealthData $healthData
            
            if ($OutputFile) {
                $htmlPath = $OutputFile
            } else {
                $reportsDir = Join-Path $ProjectRoot "reports"
                if (-not (Test-Path $reportsDir)) {
                    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
                }
                $htmlPath = Join-Path $reportsDir "health-dashboard-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            }
            
            $htmlContent | Out-File -FilePath $htmlPath -Encoding UTF8
            Write-Host "`n✅ HTML dashboard generated: $htmlPath" -ForegroundColor Green
            
            if ($Open) {
                Write-Host "Opening in browser..." -ForegroundColor Cyan
                if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                    Start-Process $htmlPath
                } elseif ($IsMacOS) {
                    & open $htmlPath
                } else {
                    & xdg-open $htmlPath 2>$null
                }
            }
        }
        
        'JSON' {
            $jsonContent = $healthData | ConvertTo-Json -Depth 10
            
            if ($OutputFile) {
                $jsonContent | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Host "`n✅ JSON exported: $OutputFile" -ForegroundColor Green
            } else {
                $jsonContent
            }
        }
        
        'Markdown' {
            $mdContent = @"
# AitherZero Health Dashboard

**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Overall Status:** $($healthData.OverallStatus)

## Dashboard Purpose

This health dashboard provides **real-time operational status** for local development and troubleshooting.

For comprehensive **CI/CD metrics and project-wide statistics**, see the [Project Dashboard (Script 0512)](https://wizzense.github.io/AitherZero/) deployed on GitHub Pages.

## System Health

- **PowerShell Version:** $($PSVersionTable.PSVersion)
- **Status:** $($healthData.System.Status)
- **Modules Loaded:** $((Get-Module).Count)
- **Logging:** $(if ($healthData.System.Checks.Logging) { '✅ Active' } else { '❌ Inactive' })

## Disk Space

- **Free Space:** $($healthData.DiskSpace.FreeGB) GB
- **Total Space:** $($healthData.DiskSpace.TotalGB) GB
- **Used:** $($healthData.DiskSpace.UsedPercent)%
- **Status:** $($healthData.DiskSpace.Status)

## Test Results

$(if ($healthData.TestResults.Available) {
    @"
- **Total Tests:** $($healthData.TestResults.Total)
- **Passed:** $($healthData.TestResults.Passed)
- **Failed:** $($healthData.TestResults.Failed)
- **Skipped:** $($healthData.TestResults.Skipped)
"@
} else {
    "No test results available"
})

## Code Quality

$(if ($healthData.CodeQuality.Available) {
    @"
- **Errors:** $($healthData.CodeQuality.Errors)
- **Warnings:** $($healthData.CodeQuality.Warnings)
- **Total Issues:** $($healthData.CodeQuality.TotalIssues)
- **Status:** $($healthData.CodeQuality.Status)
"@
} else {
    "No code quality metrics available"
})

## Recent Issues

- **Errors (Last 200 lines):** $($healthData.RecentErrors.Errors.Count)
- **Warnings (Last 200 lines):** $($healthData.RecentErrors.Warnings.Count)

---

*Generated by AitherZero Health Dashboard (Script 0550)*  
*For project metrics: [Visit Project Dashboard](https://wizzense.github.io/AitherZero/)*
"@
            
            if ($OutputFile) {
                $mdContent | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Host "`n✅ Markdown exported: $OutputFile" -ForegroundColor Green
            } else {
                $mdContent
            }
        }
    }
    
    Write-ScriptLog "Health Dashboard completed successfully (Format: $Format)"
} catch {
    Write-ScriptLog "Health Dashboard error: $_" -Level 'Error'
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    exit 1
}
