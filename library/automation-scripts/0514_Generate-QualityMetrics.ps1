#Requires -Version 7.0
<#
.SYNOPSIS
    Integrate three-tier validation metrics into dashboard
.DESCRIPTION
    Enhances dashboard generation with three-tier validation metrics:
    - Quality scores (0-100)
    - AST metrics (complexity, nesting depth, anti-patterns)
    - PSScriptAnalyzer findings (errors, warnings, information)
    - Pester test results (passed, failed, coverage)
    
    **Phase 2 Implementation**:
    - Integrates with existing 0512_Generate-Dashboard.ps1
    - Adds three-tier validation section to dashboard
    - Tracks quality trends over time
    - Generates quality score badges
    
.PARAMETER OutputPath
    Path to save dashboard metrics
    
.PARAMETER IncludeHistory
    Include historical trend data
    
.EXAMPLE
    ./library/automation-scripts/0513_Generate-QualityMetrics.ps1
    
.NOTES
    Stage: Reporting
    Dependencies: ThreeTierValidation, 0512_Generate-Dashboard.ps1
    Tags: reporting, metrics, dashboard, phase2, quality-metrics
#>

[CmdletBinding()]
param(
    [string]$OutputPath = './library/reports/quality-metrics.json',
    
    [switch]$IncludeHistory,
    
    [int]$MaxHistoryDays = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import required modules
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ThreeTierPath = Join-Path $ProjectRoot 'aithercore/testing/ThreeTierValidation.psm1'

if (-not (Test-Path $ThreeTierPath)) {
    Write-Warning "ThreeTierValidation module not found at: $ThreeTierPath"
    Write-Warning "Skipping three-tier metrics generation"
    return
}

Import-Module $ThreeTierPath -Force

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        Quality Metrics Dashboard Integration               ║" -ForegroundColor Cyan
Write-Host "║        Three-Tier Validation Metrics                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Collect metrics from all scripts
$scriptsPath = Join-Path $ProjectRoot 'library/automation-scripts'
$scripts = Get-ChildItem -Path $scriptsPath -Filter '*.ps1' | Where-Object { $_.Name -match '^\d{4}_' }

Write-Host "Collecting metrics from $($scripts.Count) scripts...`n" -ForegroundColor Yellow

$metrics = @{
    Timestamp = Get-Date -Format 'o'
    TotalScripts = $scripts.Count
    QualityScores = @()
    ASTMetrics = @{
        TotalFunctions = 0
        TotalParameters = 0
        AvgComplexity = 0
        MaxComplexity = 0
        AvgNestingDepth = 0
        MaxNestingDepth = 0
        AntiPatterns = @()
    }
    PSScriptAnalyzer = @{
        TotalErrors = 0
        TotalWarnings = 0
        TotalInformation = 0
        ByRule = @{}
    }
    Pester = @{
        TotalTests = 0
        PassedTests = 0
        FailedTests = 0
        Coverage = 0
    }
    QualityDistribution = @{
        Excellent = 0  # 90-100
        Good = 0       # 70-89
        Fair = 0       # 50-69
        Poor = 0       # <50
    }
}

# Sample validation on a subset (for performance)
$sampleSize = [Math]::Min(20, $scripts.Count)
$sampleScripts = $scripts | Get-Random -Count $sampleSize

$processed = 0
foreach ($script in $sampleScripts) {
    $processed++
    Write-Host "  [$processed/$sampleSize] Analyzing $($script.Name)..." -NoNewline
    
    try {
        $testPath = Join-Path $ProjectRoot "tests/unit/library/automation-scripts/$($script.BaseName).Tests.ps1"
        
        $result = Invoke-ThreeTierValidation -ScriptPath $script.FullName -TestPath $testPath -ErrorAction SilentlyContinue
        
        if ($result) {
            # Quality score
            $score = $result.Summary.QualityScore
            $metrics.QualityScores += $score
            
            # Distribution
            if ($score -ge 90) { $metrics.QualityDistribution.Excellent++ }
            elseif ($score -ge 70) { $metrics.QualityDistribution.Good++ }
            elseif ($score -ge 50) { $metrics.QualityDistribution.Fair++ }
            else { $metrics.QualityDistribution.Poor++ }
            
            # AST metrics
            if ($result.Tiers.AST) {
                $astMetrics = $result.Tiers.AST.Metrics
                $metrics.ASTMetrics.TotalFunctions += $astMetrics.FunctionCount
                $metrics.ASTMetrics.TotalParameters += $astMetrics.ParameterCount
                $metrics.ASTMetrics.MaxComplexity = [Math]::Max($metrics.ASTMetrics.MaxComplexity, $astMetrics.CyclomaticComplexity)
                $metrics.ASTMetrics.MaxNestingDepth = [Math]::Max($metrics.ASTMetrics.MaxNestingDepth, $astMetrics.NestingDepth)
            }
            
            # PSScriptAnalyzer
            if ($result.Tiers.PSScriptAnalyzer) {
                $metrics.PSScriptAnalyzer.TotalErrors += $result.Tiers.PSScriptAnalyzer.Errors.Count
                $metrics.PSScriptAnalyzer.TotalWarnings += $result.Tiers.PSScriptAnalyzer.Warnings.Count
            }
            
            Write-Host " ✅ Score: $score" -ForegroundColor Green
        } else {
            Write-Host " ⏭️  Skipped" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host " ❌ Error" -ForegroundColor Red
    }
}

# Calculate averages
if ($metrics.QualityScores.Count -gt 0) {
    $metrics.AverageQualityScore = ($metrics.QualityScores | Measure-Object -Average).Average
    $metrics.MedianQualityScore = ($metrics.QualityScores | Sort-Object)[[Math]::Floor($metrics.QualityScores.Count / 2)]
    $metrics.MinQualityScore = ($metrics.QualityScores | Measure-Object -Minimum).Minimum
    $metrics.MaxQualityScore = ($metrics.QualityScores | Measure-Object -Maximum).Maximum
}

if ($sampleSize -gt 0) {
    $metrics.ASTMetrics.AvgComplexity = $metrics.ASTMetrics.TotalFunctions / $sampleSize
}

# Save metrics
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath

# Display summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                 Quality Metrics Summary                     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Average Quality Score: $([Math]::Round($metrics.AverageQualityScore, 1))/100" -ForegroundColor White
Write-Host "Score Range:           $([Math]::Round($metrics.MinQualityScore, 1)) - $([Math]::Round($metrics.MaxQualityScore, 1))" -ForegroundColor Gray
Write-Host ""
Write-Host "Quality Distribution:" -ForegroundColor White
Write-Host "  Excellent (90-100): $($metrics.QualityDistribution.Excellent)" -ForegroundColor Green
Write-Host "  Good (70-89):       $($metrics.QualityDistribution.Good)" -ForegroundColor Cyan
Write-Host "  Fair (50-69):       $($metrics.QualityDistribution.Fair)" -ForegroundColor Yellow
Write-Host "  Poor (<50):         $($metrics.QualityDistribution.Poor)" -ForegroundColor Red
Write-Host ""
Write-Host "AST Metrics:" -ForegroundColor White
Write-Host "  Max Complexity:     $($metrics.ASTMetrics.MaxComplexity)" -ForegroundColor Gray
Write-Host "  Max Nesting Depth:  $($metrics.ASTMetrics.MaxNestingDepth)" -ForegroundColor Gray
Write-Host ""
Write-Host "PSScriptAnalyzer:" -ForegroundColor White
Write-Host "  Errors:             $($metrics.PSScriptAnalyzer.TotalErrors)" -ForegroundColor $(if ($metrics.PSScriptAnalyzer.TotalErrors -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Warnings:           $($metrics.PSScriptAnalyzer.TotalWarnings)" -ForegroundColor Yellow
Write-Host ""
Write-Host "📊 JSON artifacts saved to: $OutputPath" -ForegroundColor Cyan

# Historical tracking
if ($IncludeHistory) {
    $historyDir = Join-Path $ProjectRoot 'library/reports/quality-history'
    if (-not (Test-Path $historyDir)) {
        New-Item -Path $historyDir -ItemType Directory -Force | Out-Null
    }
    
    # Save timestamped history file
    $timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $historyPath = Join-Path $historyDir "quality-metrics-$timestamp.json"
    $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $historyPath
    
    # Clean up old history files (keep last 30 days)
    $cutoffDate = (Get-Date).AddDays(-$MaxHistoryDays)
    Get-ChildItem -Path $historyDir -Filter "quality-metrics-*.json" | 
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force
    
    Write-Host "📈 Historical snapshot saved: $historyPath" -ForegroundColor Green
    
    # Generate trend analysis data (JSON only - HTML created by 0512_Generate-Dashboard)
    $historyFiles = Get-ChildItem -Path $historyDir -Filter "quality-metrics-*.json" | Sort-Object Name
    if ($historyFiles.Count -gt 1) {
        $trendData = @{
            Dates = @()
            AverageScores = @()
            TotalScripts = @()
            Excellent = @()
            Good = @()
            Fair = @()
            Poor = @()
            MaxComplexity = @()
            MaxNesting = @()
            Errors = @()
            Warnings = @()
        }
        
        foreach ($file in $historyFiles) {
            try {
                $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $trendData.Dates += $data.Timestamp
                $trendData.AverageScores += [Math]::Round($data.AverageQualityScore, 1)
                $trendData.TotalScripts += $data.TotalScripts
                $trendData.Excellent += $data.QualityDistribution.Excellent
                $trendData.Good += $data.QualityDistribution.Good
                $trendData.Fair += $data.QualityDistribution.Fair
                $trendData.Poor += $data.QualityDistribution.Poor
                $trendData.MaxComplexity += $data.ASTMetrics.MaxComplexity
                $trendData.MaxNesting += $data.ASTMetrics.MaxNestingDepth
                $trendData.Errors += $data.PSScriptAnalyzer.TotalErrors
                $trendData.Warnings += $data.PSScriptAnalyzer.TotalWarnings
            } catch {
                Write-Warning "Failed to parse history file: $($file.Name)"
            }
        }
        
        # Save trend data as JSON artifact (0512 will create HTML from this)
        $trendPath = Join-Path $ProjectRoot 'library/reports/quality-trends.json'
        $trendData | ConvertTo-Json -Depth 10 | Set-Content -Path $trendPath
        
        Write-Host "📊 Trend data artifact saved: $trendPath" -ForegroundColor Green
        Write-Host "   (HTML visualization will be created by 0512_Generate-Dashboard.ps1)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "✨ Quality metrics artifacts generation complete!" -ForegroundColor Cyan
Write-Host "   Run './library/automation-scripts/0512_Generate-Dashboard.ps1' to create HTML visualizations" -ForegroundColor Gray
Write-Host ""

return $metrics
        .legend { display: flex; gap: 20px; flex-wrap: wrap; margin-top: 10px; }
        .legend-item { display: flex; align-items: center; gap: 8px; }
        .legend-color { width: 20px; height: 20px; border-radius: 3px; }
        .ast-metrics { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; }
        .ast-metric { padding: 10px; background: #0d1117; border-radius: 5px; }
        .ast-metric .label { color: #8b949e; font-size: 0.9em; }
        .ast-metric .value { font-size: 1.5em; font-weight: bold; color: #58a6ff; margin-top: 5px; }
        .footer { text-align: center; margin-top: 40px; color: #8b949e; padding: 20px; border-top: 1px solid #30363d; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 Quality Metrics Dashboard</h1>
            <div class="timestamp">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')</div>
        </div>

        <div class="metrics-grid">
            <div class="metric-card">
                <h3>📊 Average Quality Score</h3>
                <div class="metric-value $(if ($metrics.AverageQualityScore -ge 90) { 'excellent' } elseif ($metrics.AverageQualityScore -ge 70) { 'good' } elseif ($metrics.AverageQualityScore -ge 50) { 'fair' } else { 'poor' })">
                    $([Math]::Round($metrics.AverageQualityScore, 1))/100
                </div>
                <div style="color: #8b949e; margin-top: 10px;">
                    Range: $([Math]::Round($metrics.MinQualityScore, 1)) - $([Math]::Round($metrics.MaxQualityScore, 1))
                </div>
            </div>

            <div class="metric-card">
                <h3>📝 Scripts Analyzed</h3>
                <div class="metric-value" style="color: #58a6ff;">$($metrics.TotalScripts)</div>
                <div style="color: #8b949e; margin-top: 10px;">Automation scripts</div>
            </div>

            <div class="metric-card">
                <h3>🔍 AST Complexity</h3>
                <div class="metric-value $(if ($metrics.ASTMetrics.MaxComplexity -le 10) { 'excellent' } elseif ($metrics.ASTMetrics.MaxComplexity -le 20) { 'good' } else { 'fair' })">
                    $($metrics.ASTMetrics.MaxComplexity)
                </div>
                <div style="color: #8b949e; margin-top: 10px;">Max cyclomatic complexity</div>
            </div>

            <div class="metric-card">
                <h3>📐 Nesting Depth</h3>
                <div class="metric-value $(if ($metrics.ASTMetrics.MaxNestingDepth -le 3) { 'excellent' } elseif ($metrics.ASTMetrics.MaxNestingDepth -le 5) { 'good' } else { 'fair' })">
                    $($metrics.ASTMetrics.MaxNestingDepth)
                </div>
                <div style="color: #8b949e; margin-top: 10px;">Max nesting depth</div>
            </div>
        </div>

        <div class="metric-card">
            <h3>📈 Quality Distribution</h3>
            <div class="distribution">
                <div class="distribution-bar">
$(if ($metrics.QualityDistribution.Excellent -gt 0) { "                    <div class='dist-segment dist-excellent' style='width: $(($metrics.QualityDistribution.Excellent / $sampleSize) * 100)%'>$($metrics.QualityDistribution.Excellent)</div>`n" })
$(if ($metrics.QualityDistribution.Good -gt 0) { "                    <div class='dist-segment dist-good' style='width: $(($metrics.QualityDistribution.Good / $sampleSize) * 100)%'>$($metrics.QualityDistribution.Good)</div>`n" })
$(if ($metrics.QualityDistribution.Fair -gt 0) { "                    <div class='dist-segment dist-fair' style='width: $(($metrics.QualityDistribution.Fair / $sampleSize) * 100)%'>$($metrics.QualityDistribution.Fair)</div>`n" })
$(if ($metrics.QualityDistribution.Poor -gt 0) { "                    <div class='dist-segment dist-poor' style='width: $(($metrics.QualityDistribution.Poor / $sampleSize) * 100)%'>$($metrics.QualityDistribution.Poor)</div>`n" })
                </div>
                <div class="legend">
                    <div class="legend-item"><div class="legend-color dist-excellent"></div><span>Excellent (90-100): $($metrics.QualityDistribution.Excellent)</span></div>
                    <div class="legend-item"><div class="legend-color dist-good"></div><span>Good (70-89): $($metrics.QualityDistribution.Good)</span></div>
                    <div class="legend-item"><div class="legend-color dist-fair"></div><span>Fair (50-69): $($metrics.QualityDistribution.Fair)</span></div>
                    <div class="legend-item"><div class="legend-color dist-poor"></div><span>Poor (&lt;50): $($metrics.QualityDistribution.Poor)</span></div>
                </div>
            </div>
        </div>

        <div class="metric-card">
            <h3>🔬 AST Metrics Details</h3>
            <div class="ast-metrics">
                <div class="ast-metric">
                    <div class="label">Total Functions</div>
                    <div class="value">$($metrics.ASTMetrics.TotalFunctions)</div>
                </div>
                <div class="ast-metric">
                    <div class="label">Total Parameters</div>
                    <div class="value">$($metrics.ASTMetrics.TotalParameters)</div>
                </div>
                <div class="ast-metric">
                    <div class="label">Max Complexity</div>
                    <div class="value">$($metrics.ASTMetrics.MaxComplexity)</div>
                </div>
                <div class="ast-metric">
                    <div class="label">Max Nesting</div>
                    <div class="value">$($metrics.ASTMetrics.MaxNestingDepth)</div>
                </div>
            </div>
        </div>

        <div class="metric-card">
            <h3>⚠️ PSScriptAnalyzer Findings</h3>
            <div class="ast-metrics">
                <div class="ast-metric">
                    <div class="label">Errors</div>
                    <div class="value" style="color: #f85149;">$($metrics.PSScriptAnalyzer.TotalErrors)</div>
                </div>
                <div class="ast-metric">
                    <div class="label">Warnings</div>
                    <div class="value" style="color: #d29922;">$($metrics.PSScriptAnalyzer.TotalWarnings)</div>
                </div>
            </div>
        </div>

        <div class="footer">
            <p>🚀 AitherZero Three-Tier Validation System</p>
            <p style="margin-top: 10px; font-size: 0.9em;">AST → PSScriptAnalyzer → Pester</p>
        </div>
    </div>
</body>
</html>
"@

$htmlContent | Set-Content -Path $htmlPath -Encoding UTF8
Write-Host "📄 HTML report saved to: $htmlPath" -ForegroundColor Green

Write-Host ""

return $metrics
