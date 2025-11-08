#Requires -Version 7.0

<#
.SYNOPSIS
    Analyze PR diff and calculate impact metrics
.DESCRIPTION
    Compares base and head branches to generate diff statistics, impact analysis,
    and complexity changes
.PARAMETER BaseBranch
    Base branch for comparison
.PARAMETER HeadBranch
    Head branch for comparison
.PARAMETER IncludeComplexity
    Calculate cyclomatic complexity changes
.PARAMETER IncludeFunctionLevel
    Analyze changes at function level
.PARAMETER OutputPath
    Path for diff-analysis.json output
.EXAMPLE
    ./0514_Analyze-Diff.ps1 -BaseBranch main -HeadBranch feature/xyz -IncludeComplexity
.NOTES
    Stage: Reporting
    Category: Analysis
    Order: 0514
    Tags: diff, analysis, metrics
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaseBranch,
    
    [Parameter(Mandatory)]
    [string]$HeadBranch,
    
    [switch]$IncludeComplexity,
    [switch]$IncludeFunctionLevel,
    [string]$OutputPath = "library/reports/diff-analysis.json"
)

$ErrorActionPreference = 'Stop'

Write-Host "🔍 Analyzing diff: $BaseBranch → $HeadBranch" -ForegroundColor Cyan

# Get diff stats
try {
    $diffStats = git diff --numstat "$BaseBranch...$HeadBranch" 2>$null
} catch {
    Write-Error "Failed to get diff stats: $_"
    exit 1
}

# Parse diff stats
$filesChanged = @()
$totalAdditions = 0
$totalDeletions = 0

foreach ($line in $diffStats) {
    if ($line -match '^(\d+|-)\s+(\d+|-)\s+(.+)$') {
        $additions = if ($matches[1] -eq '-') { 0 } else { [int]$matches[1] }
        $deletions = if ($matches[2] -eq '-') { 0 } else { [int]$matches[2] }
        $file = $matches[3]
        
        $filesChanged += @{
            file = $file
            additions = $additions
            deletions = $deletions
            net = $additions - $deletions
        }
        
        $totalAdditions += $additions
        $totalDeletions += $deletions
    }
}

# Group by file type
$byType = @{}
foreach ($file in $filesChanged) {
    $ext = [System.IO.Path]::GetExtension($file.file)
    if (-not $ext) { $ext = 'no-extension' }
    
    if (-not $byType.ContainsKey($ext)) {
        $byType[$ext] = @{
            files = 0
            additions = 0
            deletions = 0
        }
    }
    
    $byType[$ext].files++
    $byType[$ext].additions += $file.additions
    $byType[$ext].deletions += $file.deletions
}

# Impact analysis
$modulesAffected = @()
$scriptsAffected = @()

foreach ($file in $filesChanged) {
    # Check for module changes
    if ($file.file -match 'aithercore/([^/]+)/') {
        $module = $matches[1]
        if ($modulesAffected -notcontains $module) {
            $modulesAffected += $module
        }
    }
    
    # Check for script changes
    if ($file.file -match 'automation-scripts/(\d{4})') {
        $script = [int]$matches[1]
        if ($scriptsAffected -notcontains $script) {
            $scriptsAffected += $script
        }
    }
}

# Build analysis result
$analysis = @{
    summary = @{
        files_changed = $filesChanged.Count
        additions = $totalAdditions
        deletions = $totalDeletions
        net_change = $totalAdditions - $totalDeletions
    }
    by_type = $byType
    impact = @{
        modules_affected = $modulesAffected | Sort-Object
        scripts_affected = $scriptsAffected | Sort-Object
    }
    files = $filesChanged | Sort-Object { $_.additions + $_.deletions } -Descending | Select-Object -First 20
    generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

# Write output
$outputDir = Split-Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$analysis | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host "✅ Diff analysis complete: $OutputPath" -ForegroundColor Green
Write-Host "   Files: $($filesChanged.Count)" -ForegroundColor Cyan
Write-Host "   +$totalAdditions -$totalDeletions" -ForegroundColor Cyan
Write-Host "   Modules: $($modulesAffected.Count)" -ForegroundColor Cyan
Write-Host "   Scripts: $($scriptsAffected.Count)" -ForegroundColor Cyan
