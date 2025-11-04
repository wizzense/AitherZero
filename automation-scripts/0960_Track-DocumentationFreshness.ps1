<#
.SYNOPSIS
    Track documentation freshness relative to code changes.

.DESCRIPTION
    Analyzes when documentation files were last modified compared to the code they document.
    Identifies stale documentation that hasn't been updated when code has changed.
    Generates reports showing documentation health across the repository.

.PARAMETER ReportOnly
    Generate a comprehensive report without taking action.

.PARAMETER CheckStale
    Check for documentation files that haven't been updated recently.

.PARAMETER StaleDays
    Number of days after which documentation is considered stale (default: 90).

.PARAMETER CreateIssues
    Create GitHub issues for stale documentation (requires gh CLI).

.EXAMPLE
    ./automation-scripts/0960_Track-DocumentationFreshness.ps1 -ReportOnly
    Generate a full documentation tracking report.

.EXAMPLE
    ./automation-scripts/0960_Track-DocumentationFreshness.ps1 -CheckStale -StaleDays 60
    Check for documentation not updated in 60+ days.

.NOTES
    Stage: 0960 (Documentation Tracking)
    Dependencies: Git
    Tags: documentation, tracking, maintenance
#>

[CmdletBinding()]
param(
    [switch]$ReportOnly,
    [switch]$CheckStale,
    [int]$StaleDays = 90,
    [switch]$CreateIssues
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Initialize
$reportDir = Join-Path $PSScriptRoot ".." "reports"
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

Write-Host "📚 Documentation Freshness Tracker" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Get repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
}

Write-Host "📁 Repository: $repoRoot" -ForegroundColor Gray
Write-Host ""

# Track documentation files and their last modification dates
$docFiles = @()
$codeFiles = @()

# Find all documentation files
Write-Host "🔍 Finding documentation files..." -ForegroundColor Yellow
$docExtensions = @('*.md', '*.txt', '*.rst')
foreach ($ext in $docExtensions) {
    $found = Get-ChildItem -Path $repoRoot -Filter $ext -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch 'node_modules' }
    $docFiles += $found
}

Write-Host "   Found $($docFiles.Count) documentation files" -ForegroundColor Green

# Find all code files
Write-Host "🔍 Finding code files..." -ForegroundColor Yellow
$codeExtensions = @('*.ps1', '*.psm1', '*.psd1', '*.py', '*.js', '*.ts', '*.json', '*.yml', '*.yaml')
foreach ($ext in $codeExtensions) {
    $found = Get-ChildItem -Path $repoRoot -Filter $ext -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.FullName -notmatch 'node_modules' }
    $codeFiles += $found
}

Write-Host "   Found $($codeFiles.Count) code files" -ForegroundColor Green
Write-Host ""

# Analyze documentation freshness
$trackingData = @()
$staleDocs = @()
$currentDate = Get-Date

foreach ($doc in $docFiles) {
    try {
        $relativePath = $doc.FullName.Replace($repoRoot, '').TrimStart('\', '/')
        
        # Get git last modified date if available
        $lastModified = $null
        try {
            $gitDate = git log -1 --format="%ai" -- $doc.FullName 2>$null
            if ($gitDate) {
                $lastModified = [DateTime]::Parse($gitDate)
            } else {
                $lastModified = $doc.LastWriteTime
            }
        } catch {
            $lastModified = $doc.LastWriteTime
        }
        
        $daysOld = ($currentDate - $lastModified).Days
        
        # Find related code files in same directory
        $docDir = $doc.DirectoryName
        $relatedCode = $codeFiles | Where-Object { $_.DirectoryName -eq $docDir }
        
        # Get most recent code modification in same directory
        $mostRecentCodeChange = $null
        if ($relatedCode) {
            foreach ($code in $relatedCode) {
                try {
                    $codeDate = git log -1 --format="%ai" -- $code.FullName 2>$null
                    if ($codeDate) {
                        $codeDateParsed = [DateTime]::Parse($codeDate)
                        if (-not $mostRecentCodeChange -or $codeDateParsed -gt $mostRecentCodeChange) {
                            $mostRecentCodeChange = $codeDateParsed
                        }
                    }
                } catch {
                    # Ignore errors
                }
            }
        }
        
        $codeNewerThanDoc = $false
        if ($mostRecentCodeChange -and $mostRecentCodeChange -gt $lastModified) {
            $codeNewerThanDoc = $true
        }
        
        $entry = [PSCustomObject]@{
            Path = $relativePath
            LastModified = $lastModified.ToString('yyyy-MM-dd')
            DaysOld = $daysOld
            IsStale = $daysOld -gt $StaleDays
            RelatedCodeFiles = $relatedCode.Count
            CodeNewerThanDoc = $codeNewerThanDoc
            MostRecentCodeChange = if ($mostRecentCodeChange) { $mostRecentCodeChange.ToString('yyyy-MM-dd') } else { 'N/A' }
        }
        
        $trackingData += $entry
        
        if ($entry.IsStale) {
            $staleDocs += $entry
        }
    } catch {
        Write-Warning "Failed to process $($doc.FullName): $_"
    }
}

# Generate reports
Write-Host "📊 Generating Reports" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

# Overall statistics
$avgAge = ($trackingData | Measure-Object -Property DaysOld -Average).Average
$staleCount = $staleDocs.Count
$totalDocs = $trackingData.Count
$stalePercent = if ($totalDocs -gt 0) { [math]::Round(($staleCount / $totalDocs) * 100, 1) } else { 0 }
$outdatedDocs = $trackingData | Where-Object { $_.CodeNewerThanDoc }

Write-Host "📈 Statistics:" -ForegroundColor Yellow
Write-Host "   Total documentation files: $totalDocs" -ForegroundColor White
Write-Host "   Average age: $([math]::Round($avgAge, 0)) days" -ForegroundColor White
Write-Host "   Stale (>$StaleDays days): $staleCount ($stalePercent%)" -ForegroundColor $(if ($staleCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "   Potentially outdated (code newer): $($outdatedDocs.Count)" -ForegroundColor $(if ($outdatedDocs.Count -gt 0) { 'Yellow' } else { 'Green' })
Write-Host ""

# Save full tracking report
$trackingReportPath = Join-Path $reportDir "documentation-tracking.json"
$trackingData | ConvertTo-Json -Depth 10 | Set-Content $trackingReportPath
Write-Host "✅ Saved tracking report: $trackingReportPath" -ForegroundColor Green

# Save stale docs report
if ($staleDocs.Count -gt 0) {
    $staleReportPath = Join-Path $reportDir "stale-documentation.json"
    @{ staleDocs = $staleDocs; totalStale = $staleDocs.Count } | ConvertTo-Json -Depth 10 | Set-Content $staleReportPath
    Write-Host "⚠️  Saved stale documentation report: $staleReportPath" -ForegroundColor Yellow
}

# Generate markdown report
$mdReport = @"
# Documentation Tracking Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Summary
- **Total Documentation Files**: $totalDocs
- **Average Age**: $([math]::Round($avgAge, 0)) days
- **Stale (>$StaleDays days)**: $staleCount ($stalePercent%)
- **Potentially Outdated**: $($outdatedDocs.Count)

## Top 10 Oldest Documentation Files
| File | Days Old | Last Modified | Code Newer? |
|------|----------|---------------|-------------|
"@

$topOldest = $trackingData | Sort-Object -Property DaysOld -Descending | Select-Object -First 10
foreach ($doc in $topOldest) {
    $codeIcon = if ($doc.CodeNewerThanDoc) { '⚠️' } else { '✅' }
    $mdReport += "`n| ``$($doc.Path)`` | $($doc.DaysOld) | $($doc.LastModified) | $codeIcon |"
}

if ($staleDocs.Count -gt 0) {
    $mdReport += @"

## Stale Documentation (>$StaleDays days)
| File | Days Old | Last Modified | Related Code Files |
|------|----------|---------------|-------------------|
"@
    foreach ($doc in $staleDocs | Select-Object -First 20) {
        $mdReport += "`n| ``$($doc.Path)`` | $($doc.DaysOld) | $($doc.LastModified) | $($doc.RelatedCodeFiles) |"
    }
    
    if ($staleDocs.Count -gt 20) {
        $mdReport += "`n`n_...and $($staleDocs.Count - 20) more stale files_"
    }
}

$mdReportPath = Join-Path $reportDir "documentation-tracking.md"
$mdReport | Set-Content $mdReportPath
Write-Host "📝 Saved markdown report: $mdReportPath" -ForegroundColor Green
Write-Host ""

# Display warnings for stale docs
if ($CheckStale -and $staleDocs.Count -gt 0) {
    Write-Host "⚠️  STALE DOCUMENTATION DETECTED" -ForegroundColor Yellow
    Write-Host "===============================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The following documentation files haven't been updated in >$StaleDays days:" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($doc in $staleDocs | Select-Object -First 10) {
        $codeWarning = if ($doc.CodeNewerThanDoc) { " [CODE CHANGED SINCE]" } else { "" }
        Write-Host "   • $($doc.Path) ($($doc.DaysOld) days)$codeWarning" -ForegroundColor White
    }
    
    if ($staleDocs.Count -gt 10) {
        Write-Host "   ... and $($staleDocs.Count - 10) more" -ForegroundColor Gray
    }
    Write-Host ""
}

# Exit with appropriate code
if ($CheckStale -and $staleDocs.Count -gt 0) {
    Write-Host "❌ Found $($staleDocs.Count) stale documentation file(s)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Documentation tracking complete" -ForegroundColor Green
    exit 0
}
