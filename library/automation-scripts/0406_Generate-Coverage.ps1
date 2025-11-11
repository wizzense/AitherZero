#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive code coverage reports for AitherZero
.DESCRIPTION
    Creates accurate, detailed code coverage reports using Pester 5.0+
    Supports multiple output formats and provides detailed file-level metrics
    
    Exit Codes:
    0   - Report generated successfully, coverage meets threshold
    1   - Coverage below threshold (warning)
    2   - Report generation error

.PARAMETER SourcePath
    Path to source code to analyze (default: aithercore)
.PARAMETER TestPath
    Path to test files (default: tests)
.PARAMETER OutputPath
    Path to save coverage reports (default: library/tests/coverage)
.PARAMETER RunTests
    Run tests to generate fresh coverage data (default: use existing if available)
.PARAMETER MinimumPercent
    Minimum coverage threshold percentage (default: 70)
.PARAMETER Format
    Output format(s): JaCoCo, Cobertura, HTML, JSON, All (default: All)

.EXAMPLE
    ./0406_Generate-Coverage.ps1 -RunTests -MinimumPercent 80
    
.NOTES
    Stage: Testing
    Order: 0406
    Dependencies: 0400, 0402, 0403
    Tags: testing, coverage, reporting, quality
    RequiresAdmin: No
    SupportsWhatIf: Yes
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SourcePath,
    [string]$TestPath,
    [string]$OutputPath,
    [switch]$RunTests,
    [int]$MinimumPercent = 70,
    [ValidateSet('JaCoCo', 'Cobertura', 'HTML', 'JSON', 'All')]
    [string]$Format = 'All',
    [switch]$IncludeBootstrap
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Determine project root
$projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Import ScriptUtilities
$scriptUtilsPath = Join-Path $projectRoot "aithercore/automation/ScriptUtilities.psm1"
if (Test-Path $scriptUtilsPath) {
    Import-Module $scriptUtilsPath -Force
}

# Set default paths
if (-not $SourcePath) {
    $SourcePath = Join-Path $projectRoot "aithercore"
}
if (-not $TestPath) {
    $TestPath = Join-Path $projectRoot "library/tests"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRoot "library/tests/coverage"
}

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

Write-ScriptLog "🔍 Starting code coverage analysis" -Source "0406_Generate-Coverage"
Write-ScriptLog "  Source: $SourcePath" -Source "0406_Generate-Coverage"
Write-ScriptLog "  Tests: $TestPath" -Source "0406_Generate-Coverage"
Write-ScriptLog "  Output: $OutputPath" -Source "0406_Generate-Coverage"

try {
    # Check for Pester 5.0+
    $pesterModule = Get-Module -ListAvailable -Name Pester | 
        Where-Object { $_.Version -ge [Version]'5.0.0' } | 
        Select-Object -First 1
    
    if (-not $pesterModule) {
        Write-ScriptLog "❌ Pester 5.0.0+ is required. Installing..." -Level Warning -Source "0406_Generate-Coverage"
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
    }
    
    Import-Module Pester -MinimumVersion 5.0.0 -Force
    
    # Build list of files to analyze for coverage
    $coveragePaths = @()
    
    # Add all PowerShell module files in aithercore
    if (Test-Path $SourcePath) {
        $coveragePaths += Get-ChildItem -Path $SourcePath -Recurse -Include "*.psm1", "*.ps1" | 
            Where-Object { $_.FullName -notmatch "\.tests\.ps1$" } |
            Select-Object -ExpandProperty FullName
    }
    
    # Add root module files
    $rootModuleFile = Join-Path $projectRoot "AitherZero.psm1"
    if (Test-Path $rootModuleFile) {
        $coveragePaths += $rootModuleFile
    }
    
    # Add Start script if requested
    if ($IncludeBootstrap) {
        $startScript = Join-Path $projectRoot "Start-AitherZero.ps1"
        if (Test-Path $startScript) {
            $coveragePaths += $startScript
        }
    }
    
    Write-ScriptLog "📊 Analyzing $($coveragePaths.Count) source files" -Source "0406_Generate-Coverage"
    
    # Configure Pester
    $pesterConfig = New-PesterConfiguration
    
    # Run configuration
    $pesterConfig.Run.Path = $TestPath
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Run.Exit = $false
    
    # Output configuration
    $pesterConfig.Output.Verbosity = 'Normal'
    
    # Test Result configuration
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$timestamp.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
    
    # Code Coverage configuration
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = $coveragePaths
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-$timestamp.xml"
    $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    $pesterConfig.CodeCoverage.OutputEncoding = 'UTF8'
    
    # Run tests with coverage
    Write-ScriptLog "🧪 Running tests with coverage analysis..." -Source "0406_Generate-Coverage"
    $result = Invoke-Pester -Configuration $pesterConfig
    
    # Extract coverage data
    $coverage = $result.CodeCoverage
    
    if (-not $coverage) {
        throw "No coverage data generated. Tests may have failed to run."
    }
    
    # Calculate overall metrics
    $totalCommands = $coverage.NumberOfCommandsAnalyzed
    $coveredCommands = $coverage.NumberOfCommandsExecuted
    $missedCommands = $coverage.NumberOfCommandsMissed
    $coveragePercent = if ($totalCommands -gt 0) {
        [Math]::Round(($coveredCommands / $totalCommands) * 100, 2)
    } else {
        0
    }
    
    Write-ScriptLog "📈 Coverage: $coveragePercent% ($coveredCommands/$totalCommands commands)" -Source "0406_Generate-Coverage"
    
    # Build detailed file coverage
    $fileCoverage = @()
    
    foreach ($analyzedFile in $coverage.AnalyzedFiles) {
        # Get commands for this file
        $fileCommands = @($coverage.CommandsCovered + $coverage.CommandsMissed) | 
            Where-Object { $_.File -eq $analyzedFile }
        
        $fileTotalCommands = $fileCommands.Count
        $fileCoveredCommands = @($coverage.CommandsCovered | Where-Object { $_.File -eq $analyzedFile }).Count
        $fileMissedCommands = @($coverage.CommandsMissed | Where-Object { $_.File -eq $analyzedFile }).Count
        
        $fileCoveragePercent = if ($fileTotalCommands -gt 0) {
            [Math]::Round(($fileCoveredCommands / $fileTotalCommands) * 100, 2)
        } else {
            0
        }
        
        $relativePath = $analyzedFile -replace [regex]::Escape($projectRoot), ''
        $relativePath = $relativePath.TrimStart('\', '/')
        
        $fileCoverage += [PSCustomObject]@{
            File = $relativePath
            FullPath = $analyzedFile
            Coverage = $fileCoveragePercent
            TotalCommands = $fileTotalCommands
            CoveredCommands = $fileCoveredCommands
            MissedCommands = $fileMissedCommands
            MissedLines = @($coverage.CommandsMissed | Where-Object { $_.File -eq $analyzedFile } | Select-Object -ExpandProperty Line)
        }
    }
    
    # Create comprehensive summary
    $summary = @{
        Timestamp = Get-Date -Format "o"
        OverallCoverage = $coveragePercent
        TotalCommands = $totalCommands
        CoveredCommands = $coveredCommands
        MissedCommands = $missedCommands
        FilesAnalyzed = $coverage.AnalyzedFiles.Count
        TestResults = @{
            TotalTests = $result.TotalCount
            PassedTests = $result.PassedCount
            FailedTests = $result.FailedCount
            SkippedTests = $result.SkippedCount
            Duration = $result.Duration.TotalSeconds
        }
        Files = $fileCoverage | ForEach-Object {
            @{
                File = $_.File
                Coverage = $_.Coverage
                TotalCommands = $_.TotalCommands
                CoveredCommands = $_.CoveredCommands
                MissedCommands = $_.MissedCommands
            }
        }
        Thresholds = @{
            Minimum = $MinimumPercent
            MetThreshold = ($coveragePercent -ge $MinimumPercent)
        }
    }
    
    # Generate reports based on format
    $reports = @()
    
    # JaCoCo XML (already generated by Pester)
    if ($Format -in @('JaCoCo', 'All')) {
        $reports += @{
            Format = 'JaCoCo'
            Path = $pesterConfig.CodeCoverage.OutputPath.Value
        }
        Write-ScriptLog "✅ JaCoCo report: $($pesterConfig.CodeCoverage.OutputPath.Value)" -Source "0406_Generate-Coverage"
    }
    
    # JSON Summary
    if ($Format -in @('JSON', 'All')) {
        $jsonPath = Join-Path $OutputPath "coverage-summary.json"
        $summary | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
        $reports += @{
            Format = 'JSON'
            Path = $jsonPath
        }
        Write-ScriptLog "✅ JSON summary: $jsonPath" -Source "0406_Generate-Coverage"
    }
    
    # HTML Report
    if ($Format -in @('HTML', 'All')) {
        $htmlPath = Join-Path $OutputPath "coverage-report.html"
        
        # Generate modern HTML report
        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero Code Coverage Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            background: white; 
            border-radius: 12px; 
            padding: 30px; 
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        h1 { 
            color: #2d3748; 
            border-bottom: 3px solid #667eea; 
            padding-bottom: 15px; 
            margin-bottom: 20px;
            font-size: 32px;
        }
        .timestamp { 
            color: #718096; 
            font-size: 14px; 
            margin-bottom: 30px;
        }
        .summary-grid { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
            gap: 20px; 
            margin-bottom: 40px;
        }
        .metric-card { 
            background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%);
            padding: 25px; 
            border-radius: 10px; 
            text-align: center;
            border: 1px solid #e2e8f0;
            transition: transform 0.2s;
        }
        .metric-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        .metric-card h3 { 
            color: #4a5568; 
            font-size: 14px; 
            text-transform: uppercase; 
            letter-spacing: 1px; 
            margin-bottom: 12px;
            font-weight: 600;
        }
        .metric-value { 
            font-size: 42px; 
            font-weight: 700; 
            line-height: 1;
        }
        .metric-label {
            font-size: 12px;
            color: #718096;
            margin-top: 8px;
        }
        .good { color: #48bb78; }
        .warning { color: #ed8936; }
        .danger { color: #f56565; }
        .threshold-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            margin-top: 15px;
        }
        .threshold-met {
            background: #c6f6d5;
            color: #22543d;
        }
        .threshold-not-met {
            background: #fed7d7;
            color: #742a2a;
        }
        table { 
            width: 100%; 
            border-collapse: collapse; 
            margin-top: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        thead {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        th { 
            padding: 15px; 
            text-align: left; 
            font-weight: 600;
            text-transform: uppercase;
            font-size: 12px;
            letter-spacing: 1px;
        }
        td { 
            padding: 12px 15px; 
            border-bottom: 1px solid #e2e8f0;
        }
        tr:hover { 
            background-color: #f7fafc;
        }
        tr:last-child td {
            border-bottom: none;
        }
        .coverage-bar { 
            width: 150px; 
            height: 24px; 
            background-color: #e2e8f0; 
            border-radius: 12px; 
            overflow: hidden;
            position: relative;
        }
        .coverage-fill { 
            height: 100%; 
            border-radius: 12px;
            transition: width 0.5s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 11px;
            font-weight: 600;
        }
        .file-path {
            font-family: 'Courier New', monospace;
            font-size: 13px;
            color: #2d3748;
        }
        .stats {
            font-size: 12px;
            color: #718096;
        }
        h2 {
            color: #2d3748;
            margin: 40px 0 20px 0;
            font-size: 24px;
            border-left: 4px solid #667eea;
            padding-left: 15px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #e2e8f0;
            text-align: center;
            color: #718096;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 AitherZero Code Coverage Report</h1>
        <div class="timestamp">Generated: $(Get-Date -Format "MMMM d, yyyy 'at' h:mm:ss tt")</div>
        
        <div class="summary-grid">
            <div class="metric-card">
                <h3>Overall Coverage</h3>
                <div class="metric-value $( if ($coveragePercent -ge 80) { 'good' } elseif ($coveragePercent -ge 60) { 'warning' } else { 'danger' })">
                    $($coveragePercent)%
                </div>
                <div class="threshold-badge $( if ($coveragePercent -ge $MinimumPercent) { 'threshold-met' } else { 'threshold-not-met' })">
                    $( if ($coveragePercent -ge $MinimumPercent) { "✓ Meets threshold ($MinimumPercent%)" } else { "⚠ Below threshold ($MinimumPercent%)" })
                </div>
            </div>
            <div class="metric-card">
                <h3>Commands Covered</h3>
                <div class="metric-value good">$coveredCommands</div>
                <div class="metric-label">of $totalCommands total</div>
            </div>
            <div class="metric-card">
                <h3>Commands Missed</h3>
                <div class="metric-value $( if ($missedCommands -gt 100) { 'danger' } elseif ($missedCommands -gt 50) { 'warning' } else { 'good' })">
                    $missedCommands
                </div>
                <div class="metric-label">need coverage</div>
            </div>
            <div class="metric-card">
                <h3>Files Analyzed</h3>
                <div class="metric-value">$($coverage.AnalyzedFiles.Count)</div>
                <div class="metric-label">source files</div>
            </div>
            <div class="metric-card">
                <h3>Tests Executed</h3>
                <div class="metric-value $( if ($result.FailedCount -gt 0) { 'danger' } else { 'good' })">
                    $($result.PassedCount)/$($result.TotalCount)
                </div>
                <div class="metric-label">passed in $([Math]::Round($result.Duration.TotalSeconds, 1))s</div>
            </div>
        </div>
        
        <h2>📁 Coverage by File</h2>
        <table>
            <thead>
                <tr>
                    <th>File</th>
                    <th>Coverage</th>
                    <th>Commands</th>
                    <th>Visual</th>
                </tr>
            </thead>
            <tbody>
"@
        
        # Add file rows sorted by coverage (lowest first to highlight problem areas)
        foreach ($file in ($fileCoverage | Sort-Object Coverage)) {
            $coverageClass = if ($file.Coverage -ge 80) { 'good' } elseif ($file.Coverage -ge 60) { 'warning' } else { 'danger' }
            $fillColor = if ($file.Coverage -ge 80) { '#48bb78' } elseif ($file.Coverage -ge 60) { '#ed8936' } else { '#f56565' }
            
            $html += @"
                <tr>
                    <td class="file-path">$($file.File)</td>
                    <td class="$coverageClass" style="font-weight: 600;">$($file.Coverage)%</td>
                    <td class="stats">$($file.CoveredCommands)/$($file.TotalCommands)</td>
                    <td>
                        <div class="coverage-bar">
                            <div class="coverage-fill" style="width: $($file.Coverage)%; background: $fillColor;">
                                $($file.Coverage)%
                            </div>
                        </div>
                    </td>
                </tr>
"@
        }
        
        $html += @"
            </tbody>
        </table>
        
        <div class="footer">
            <p><strong>AitherZero Testing Framework</strong></p>
            <p>Coverage analysis powered by Pester $($pesterModule.Version)</p>
            <p>Minimum threshold: $MinimumPercent% | Analyzed: $($coverage.AnalyzedFiles.Count) files | Commands: $totalCommands</p>
        </div>
    </div>
</body>
</html>
"@
        
        $html | Set-Content -Path $htmlPath -Encoding UTF8
        $reports += @{
            Format = 'HTML'
            Path = $htmlPath
        }
        Write-ScriptLog "✅ HTML report: $htmlPath" -Source "0406_Generate-Coverage"
    }
    
    # Display summary
    Write-Host "`n╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        CODE COVERAGE ANALYSIS COMPLETE           ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $coverageColor = if ($coveragePercent -ge $MinimumPercent) { 'Green' } else { 'Yellow' }
    Write-Host "📊 Overall Coverage: " -NoNewline
    Write-Host "$coveragePercent%" -ForegroundColor $coverageColor -NoNewline
    Write-Host " ($coveredCommands/$totalCommands commands)"
    
    Write-Host "📁 Files Analyzed: $($coverage.AnalyzedFiles.Count)"
    Write-Host "🎯 Threshold: $MinimumPercent% - " -NoNewline
    if ($coveragePercent -ge $MinimumPercent) {
        Write-Host "✅ MET" -ForegroundColor Green
    } else {
        Write-Host "⚠️  NOT MET (need +$([Math]::Round($MinimumPercent - $coveragePercent, 2))%)" -ForegroundColor Yellow
    }
    
    Write-Host "`n📄 Generated Reports:" -ForegroundColor Cyan
    foreach ($report in $reports) {
        Write-Host "   ✓ $($report.Format): " -ForegroundColor Green -NoNewline
        Write-Host $report.Path -ForegroundColor Gray
    }
    
    # Show files needing attention
    $lowCoverageFiles = $fileCoverage | Where-Object { $_.Coverage -lt $MinimumPercent } | Sort-Object Coverage | Select-Object -First 5
    if ($lowCoverageFiles) {
        Write-Host "`n⚠️  Files Below Threshold:" -ForegroundColor Yellow
        foreach ($file in $lowCoverageFiles) {
            Write-Host "   📄 $($file.File): " -NoNewline
            Write-Host "$($file.Coverage)% " -ForegroundColor Red -NoNewline
            Write-Host "($($file.CoveredCommands)/$($file.TotalCommands) commands)" -ForegroundColor Gray
        }
    }
    
    # Exit with appropriate code
    if ($coveragePercent -lt $MinimumPercent) {
        Write-ScriptLog "⚠️  Coverage below threshold: $coveragePercent% < $MinimumPercent%" -Level Warning -Source "0406_Generate-Coverage"
        exit 1
    } else {
        Write-ScriptLog "✅ Coverage meets threshold: $coveragePercent% >= $MinimumPercent%" -Source "0406_Generate-Coverage"
        exit 0
    }
}
catch {
    Write-ScriptLog "❌ Coverage generation failed: $_" -Level Error -Source "0406_Generate-Coverage"
    Write-Host "`n❌ ERROR: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    exit 2
}
