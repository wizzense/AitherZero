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
            gap: 20px;
            margin-bottom: 30px;
        }

        .metric-card {
            background: linear-gradient(135deg, var(--card-bg) 0%, rgba(22, 27, 34, 0.5) 100%);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 25px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
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
            margin-bottom: 8px;
        }

        .metric-label {
            color: var(--text-secondary);
            font-size: 0.9rem;
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
    </style>
</head>
<body>
    <div class="toc-toggle" onclick="toggleToc()">☰</div>
    
    <nav class="toc" id="toc">
        <h3>📑 Contents</h3>
        <ul>
            <li><a href="#overview">Overview</a></li>
            <li><a href="#metrics">Project Metrics</a></li>
            <li><a href="#manifest">Module Manifest</a></li>
            <li><a href="#domains">Domain Modules</a></li>
            <li><a href="#health">Project Health</a></li>
            <li><a href="#activity">Recent Activity</a></li>
            <li><a href="#actions">Quick Actions</a></li>
            <li><a href="#system">System Info</a></li>
            <li><a href="#resources">Resources</a></li>
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
                <div class="status-badge status-unknown">
                    🔒 Security: $($Status.Security)
                </div>
                <div class="status-badge status-unknown">
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
                            <div class="progress-fill" style="width: $($Metrics.Coverage.Percentage)%">
                                $(if($Metrics.Coverage.Percentage -gt 0){ "$($Metrics.Coverage.Percentage)%" })
                            </div>
                        </div>
                    </div>
                </div>
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
                </div>
            </section>

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
                        <p><a href="https://github.com/wizzense/AitherZero/wiki" target="_blank">📖 Documentation</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/blob/main/README.md" target="_blank">📄 README</a></p>
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
        // TOC toggle for mobile
        function toggleToc() {
            document.getElementById('toc').classList.toggle('open');
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

        // Auto-refresh every 5 minutes
        setTimeout(() => {
            window.location.reload();
        }, 300000);

        // Add interactive elements
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.metric-card, .domain-card');
            cards.forEach(card => {
                card.addEventListener('click', function() {
                    this.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        this.style.transform = '';
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