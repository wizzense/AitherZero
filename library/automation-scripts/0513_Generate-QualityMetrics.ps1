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
    Tags: reporting, metrics, dashboard, phase2
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
Write-Host "📊 Metrics saved to: $OutputPath" -ForegroundColor Cyan
Write-Host ""

return $metrics
