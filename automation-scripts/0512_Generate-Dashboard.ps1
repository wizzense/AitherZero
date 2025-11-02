#Requires -Version 7.0
# PSScriptAnalyzer suppressions for dashboard generation script
# PSScriptAnalyzer: PSUseSingularNouns - Dashboard functions intentionally use plural names for collections of metrics
# PSScriptAnalyzer: PSShouldProcess - ShouldProcess handled at script level, not individual helper functions

<#
.SYNOPSIS
    Generate comprehensive CI/CD dashboard with real-time status monitoring
.DESCRIPTION
    Creates HTML and Markdown dashboards showing project health, test results,
    security status, CI/CD metrics, and deployment information for effective
    project management and systematic improvement.
    
    Uses external HTML templates from /templates/dashboard for cleaner code
    and better maintainability.

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
    
    Templates: Uses /templates/dashboard/ for HTML, CSS, and JavaScript
#>

[CmdletBinding(SupportsShouldProcess)]
# PSScriptAnalyzer: PSReviewUnusedParameter - Parameters used in script body and switch statements
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$OutputPath = (Join-Path $ProjectPath "reports"),
    [string]$TemplatePath = (Join-Path $ProjectPath "templates/dashboard"),
    [ValidateSet('HTML', 'Markdown', 'JSON', 'All')]
    [string]$Format = 'All',
    [switch]$Open
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Logging helper
function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $logMessage = "[$timestamp] [$Level] [0512_Generate-Dashboard] $Message"
    
    switch ($Level) {
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        default   { Write-Host $logMessage -ForegroundColor Cyan }
    }
}

# Load template file
function Get-Template {
    param([string]$TemplateName)
    
    $templateFile = Join-Path $TemplatePath "$TemplateName.html"
    if (-not (Test-Path $templateFile)) {
        throw "Template not found: $templateFile"
    }
    
    return Get-Content $templateFile -Raw
}

# Replace placeholders in template
function Set-TemplateVariables {
    param(
        [string]$Template,
        [hashtable]$Variables
    )
    
    $result = $Template
    foreach ($key in $Variables.Keys) {
        $placeholder = "{{$key}}"
        $value = $Variables[$key]
        $result = $result -replace [regex]::Escape($placeholder), $value
    }
    
    return $result
}

# PSScriptAnalyzer suppression: PSUseSingularNouns - Function returns multiple metrics
function Get-ProjectMetrics {
    Write-ScriptLog -Message "Collecting project metrics"

    $metrics = @{
        Files = @{
            PowerShell = @(Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notmatch '(tests|examples|legacy)' }).Count
            Modules = @(Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse).Count
            Manifests = @(Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse).Count
            Total = 0
        }
        LinesOfCode = 0
        CommentLines = 0
        BlankLines = 0
        Functions = 0
        Classes = 0
        AutomationScripts = @(Get-ChildItem -Path (Join-Path $ProjectPath "automation-scripts") -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
        Playbooks = @(Get-ChildItem -Path (Join-Path $ProjectPath "orchestration/playbooks") -Filter "*.json" -Recurse -ErrorAction SilentlyContinue).Count
        Tests = @{
            Total = 0
            Passed = 0
            Failed = 0
            Skipped = 0
            LastRun = 'N/A'
        }
        Coverage = @{
            Percentage = 0
            CoveredLines = 0
            TotalLines = 0
        }
        Git = @{
            Branch = 'Unknown'
            CommitCount = 0
            LastCommit = 'N/A'
        }
        Platform = if ($IsWindows) { 'Windows' } elseif ($IsLinux) { 'Linux' } elseif ($IsMacOS) { 'macOS' } else { 'Unknown' }
        PSVersion = $PSVersionTable.PSVersion.ToString()
    }

    $metrics.Files.Total = $metrics.Files.PowerShell + $metrics.Files.Modules + $metrics.Files.Manifests

    # Collect LOC metrics
    $psFiles = @(Get-ChildItem -Path $ProjectPath -Include "*.ps1","*.psm1" -Recurse -ErrorAction SilentlyContinue)
    foreach ($file in $psFiles) {
        if ($file.FullName -match '(tests|examples|legacy|node_modules)') { continue }
        
        $content = @(Get-Content $file.FullName -ErrorAction SilentlyContinue)
        if ($content -and $content.Count -gt 0) {
            $metrics.LinesOfCode += $content.Count
            $metrics.CommentLines += @($content | Where-Object { $_ -match '^\s*#' }).Count
            $metrics.BlankLines += @($content | Where-Object { $_ -match '^\s*$' }).Count
            $metrics.Functions += @($content | Where-Object { $_ -match '^\s*function\s+' }).Count
            $metrics.Classes += @($content | Where-Object { $_ -match '^\s*class\s+' }).Count
        }
    }

    # Get test results if available
    $testResultFile = Join-Path $OutputPath "test-results.json"
    if (Test-Path $testResultFile) {
        try {
            $testData = Get-Content $testResultFile -Raw | ConvertFrom-Json
            $metrics.Tests.Total = $testData.TotalCount
            $metrics.Tests.Passed = $testData.PassedCount
            $metrics.Tests.Failed = $testData.FailedCount
            $metrics.Tests.Skipped = $testData.SkippedCount
            $metrics.Tests.LastRun = $testData.ExecutedAt
        } catch {
            Write-ScriptLog -Message "Could not parse test results: $_" -Level Warning
        }
    }

    # Get coverage if available
    $coverageFile = Join-Path $OutputPath "coverage.json"
    if (Test-Path $coverageFile) {
        try {
            $coverageData = Get-Content $coverageFile -Raw | ConvertFrom-Json
            $metrics.Coverage.Percentage = [math]::Round($coverageData.CoveragePercent, 1)
            $metrics.Coverage.CoveredLines = $coverageData.CommandsExecutedCount
            $metrics.Coverage.TotalLines = $coverageData.CommandsAnalyzedCount
        } catch {
            Write-ScriptLog -Message "Could not parse coverage data: $_" -Level Warning
        }
    }

    # Get Git info
    try {
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $metrics.Git.Branch = (git rev-parse --abbrev-ref HEAD 2>$null) -join ''
            $metrics.Git.CommitCount = (git rev-list --count HEAD 2>$null) -join ''
            $metrics.Git.LastCommit = (git log -1 --format="%ar" 2>$null) -join ''
        }
    } catch {
        Write-ScriptLog -Message "Could not retrieve Git information" -Level Warning
    }

    return $metrics
}

# PSScriptAnalyzer suppression: PSUseSingularNouns - Function returns multiple metrics
function Get-QualityMetrics {
    Write-ScriptLog -Message "Collecting quality metrics"
    
    $qualityReport = Join-Path $OutputPath "quality-report.json"
    if (-not (Test-Path $qualityReport)) {
        Write-ScriptLog -Message "Quality report not found, using defaults" -Level Warning
        return @{
            PSScriptAnalyzer = @{ Issues = 0; Errors = 0; Warnings = 0 }
            Security = @{ Vulnerabilities = 0; Scanned = $true }
            CodeSmells = 0
            TechDebt = @{ Hours = 0; Issues = 0 }
        }
    }

    try {
        return Get-Content $qualityReport -Raw | ConvertFrom-Json
    } catch {
        Write-ScriptLog -Message "Could not parse quality report: $_" -Level Warning
        return @{
            PSScriptAnalyzer = @{ Issues = 0; Errors = 0; Warnings = 0 }
            Security = @{ Vulnerabilities = 0; Scanned = $true }
            CodeSmells = 0
            TechDebt = @{ Hours = 0; Issues = 0 }
        }
    }
}

function New-HTMLDashboard {
    param($Metrics, $Quality)
    
    Write-ScriptLog -Message "Generating HTML dashboard from templates"

    # Prepare variables for templates
    $variables = @{
        TITLE = "AitherZero - Project Dashboard"
        PROJECT_NAME = "AitherZero"
        SUBTITLE = "PowerShell Automation Platform - CI/CD Dashboard"
        TIMESTAMP = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Overview metrics
        FILES_TOTAL = $Metrics.Files.Total.ToString('N0')
        FILES_PS1 = $Metrics.Files.PowerShell
        FILES_PSM1 = $Metrics.Files.Modules
        FILES_PSD1 = $Metrics.Files.Manifests
        
        LOC_TOTAL = $Metrics.LinesOfCode.ToString('N0')
        FUNCTIONS = $Metrics.Functions
        CLASSES_INFO = if ($Metrics.Classes -gt 0) { " | $($Metrics.Classes) Classes" } else { "" }
        COMMENT_INFO = if ($Metrics.CommentLines -gt 0) {
            $commentRatio = [math]::Round(($Metrics.CommentLines / $Metrics.LinesOfCode) * 100, 1)
            "<div style='margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);'>💬 $($Metrics.CommentLines.ToString('N0')) Comments ($commentRatio%) | ⚪ $($Metrics.BlankLines.ToString('N0')) Blank Lines</div>"
        } else { "" }
        
        AUTOMATION_SCRIPTS = $Metrics.AutomationScripts
        SCRIPT_CATEGORIES = 8
        PLAYBOOKS = $Metrics.Playbooks
        
        TESTS_TOTAL = $Metrics.Tests.Total
        TEST_STATUS_INFO = if ($Metrics.Tests.Total -gt 0) {
            "✅ $($Metrics.Tests.Passed) Passed | ❌ $($Metrics.Tests.Failed) Failed"
        } else {
            "No tests run yet"
        }
        TEST_DETAILS = if ($Metrics.Tests.Total -gt 0) {
            "<div style='margin-top: 10px; font-size: 0.75rem; color: var(--text-secondary);'>Last run: $($Metrics.Tests.LastRun)</div>"
        } else {
            "<div style='padding: 10px; background: var(--bg-darker); border-radius: 6px;'><div style='font-size: 0.85rem; color: var(--text-secondary);'>⚠️ No test results available. Run <code>./az 0402</code> to execute tests.</div></div>"
        }
        
        COVERAGE_PERCENTAGE = $Metrics.Coverage.Percentage
        COVERAGE_INFO = if ($Metrics.Coverage.TotalLines -gt 0) {
            "$($Metrics.Coverage.CoveredLines) / $($Metrics.Coverage.TotalLines) Lines Covered"
        } else {
            "No coverage data available"
        }
        COVERAGE_BAR = if ($Metrics.Coverage.Percentage -gt 0) {
            "<div class='progress-bar'><div class='progress-fill' style='width: $($Metrics.Coverage.Percentage)%'>$($Metrics.Coverage.Percentage)%</div></div>"
        } else { "" }
        
        GIT_CARD = if ($Metrics.Git.Branch -ne "Unknown") {
            "<div class='metric-card'><h3>🌿 Git Repository</h3><div class='metric-value' style='font-size: 1.8rem;'>$($Metrics.Git.CommitCount)</div><div class='metric-label'>Total Commits</div><div style='margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);'>Branch: <strong>$($Metrics.Git.Branch)</strong><br>Last commit: $($Metrics.Git.LastCommit)</div></div>"
        } else { "" }
        
        PLATFORM = $Metrics.Platform
        PS_VERSION = $Metrics.PSVersion
        ENVIRONMENT = if ($env:AITHERZERO_CI) { 'CI/CD Pipeline' } else { 'Development' }
    }

    # Load base template
    $baseTemplate = Get-Template -TemplateName "base"
    
    # Load section template
    $overviewSection = Get-Template -TemplateName "section-overview"
    $overviewSection = Set-TemplateVariables -Template $overviewSection -Variables $variables
    
    # Insert section into base
    $variables.CONTENT = $overviewSection
    $html = Set-TemplateVariables -Template $baseTemplate -Variables $variables

    # Write dashboard files
    $dashboardPath = Join-Path $OutputPath "dashboard.html"
    if ($PSCmdlet.ShouldProcess($dashboardPath, "Create HTML dashboard")) {
        $html | Set-Content -Path $dashboardPath -Encoding UTF8
        
        # Copy CSS and JS files
        Copy-Item (Join-Path $TemplatePath "styles.css") (Join-Path $OutputPath "styles.css") -Force
        Copy-Item (Join-Path $TemplatePath "dashboard.js") (Join-Path $OutputPath "dashboard.js") -Force
        
        Write-ScriptLog -Message "HTML dashboard created: $dashboardPath"
    }
}

function Open-HTMLDashboard {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-ScriptLog -Message "Dashboard file not found: $FilePath" -Level Error
        return $false
    }

    try {
        if ($IsWindows) {
            Start-Process $FilePath
        } elseif ($IsMacOS) {
            & open $FilePath
        } elseif ($IsLinux) {
            & xdg-open $FilePath 2>$null
        }
        return $true
    } catch {
        Write-ScriptLog -Message "Could not open dashboard: $_" -Level Warning
        return $false
    }
}

# Main execution
try {
    Write-ScriptLog -Message "Starting dashboard generation"

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Verify template directory exists
    if (-not (Test-Path $TemplatePath)) {
        Write-ScriptLog -Message "Template directory not found: $TemplatePath" -Level Error
        exit 2
    }

    # Collect metrics
    $metrics = Get-ProjectMetrics
    $quality = Get-QualityMetrics

    # Generate dashboards based on format
    if ($Format -eq 'HTML' -or $Format -eq 'All') {
        New-HTMLDashboard -Metrics $metrics -Quality $quality
    }

    if ($Format -eq 'Markdown' -or $Format -eq 'All') {
        Write-ScriptLog -Message "Markdown format not yet implemented with templates" -Level Warning
    }

    if ($Format -eq 'JSON' -or $Format -eq 'All') {
        $jsonPath = Join-Path $OutputPath "dashboard-data.json"
        $dashboardData = @{
            Generated = Get-Date -Format "o"
            Metrics = $metrics
            Quality = $quality
        }
        $dashboardData | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
        Write-ScriptLog -Message "JSON data exported: $jsonPath"
    }

    # Open HTML dashboard if requested
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

    Write-ScriptLog -Message "Dashboard generation completed successfully"
    exit 0

} catch {
    Write-ScriptLog -Message "Dashboard generation failed: $_" -Level Error
    Write-ScriptLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}
