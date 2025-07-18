#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Run PSScriptAnalyzer across the AitherZero project
    
.DESCRIPTION
    Analyzes all PowerShell files in the project using PSScriptAnalyzer
    and generates a report of issues found
    
.PARAMETER Fix
    Attempt to auto-fix issues where possible
    
.PARAMETER Severity
    Filter by severity level (Error, Warning, Information)
    
.PARAMETER OutputFormat
    Output format: Console, JSON, or CSV
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [ValidateSet('Error', 'Warning', 'Information', 'All')]
    [string]$Severity = 'All',
    [ValidateSet('Console', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Console'
)

$ErrorActionPreference = 'Stop'

# Get project root
$projectRoot = Split-Path $PSScriptRoot -Parent
$settingsPath = Join-Path $projectRoot 'PSScriptAnalyzerSettings.psd1'

Write-Host "🔍 Running PSScriptAnalyzer on AitherZero project" -ForegroundColor Cyan
Write-Host "Project Root: $projectRoot" -ForegroundColor Gray
Write-Host "Settings: $settingsPath" -ForegroundColor Gray

# Ensure PSScriptAnalyzer is installed
if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -SkipPublisherCheck
}

# Import the module
Import-Module PSScriptAnalyzer -Force

# Get all PowerShell files
$files = Get-ChildItem -Path $projectRoot -Recurse -Include '*.ps1', '*.psm1', '*.psd1' | Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and
    $_.FullName -notmatch '/\.git/' -and
    $_.FullName -notmatch 'backup-' -and
    $_.FullName -notmatch 'test-results-'
}

Write-Host "`nFound $($files.Count) PowerShell files to analyze" -ForegroundColor Gray

# Run analysis
$results = @()
$fileCount = 0
$issueCount = 0

foreach ($file in $files) {
    $fileCount++
    $relativePath = $file.FullName.Replace($projectRoot, '').TrimStart('\', '/')
    
    Write-Progress -Activity "Analyzing PowerShell Files" -Status $relativePath -PercentComplete (($fileCount / $files.Count) * 100)
    
    try {
        $fileResults = Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath
        
        if ($Severity -ne 'All') {
            $fileResults = $fileResults | Where-Object Severity -eq $Severity
        }
        
        if ($fileResults) {
            $results += $fileResults
            $issueCount += $fileResults.Count
        }
    } catch {
        Write-Warning "Failed to analyze $relativePath : $_"
    }
}

Write-Progress -Activity "Analyzing PowerShell Files" -Completed

# Group results by severity
$resultsBySeverity = $results | Group-Object Severity

# Output results
Write-Host "`n📊 Analysis Results" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Gray

if ($results.Count -eq 0) {
    Write-Host "✅ No issues found!" -ForegroundColor Green
} else {
    foreach ($severityGroup in $resultsBySeverity) {
        $color = switch ($severityGroup.Name) {
            'Error' { 'Red' }
            'Warning' { 'Yellow' }
            'Information' { 'Gray' }
            default { 'White' }
        }
        
        Write-Host "$($severityGroup.Name): $($severityGroup.Count) issues" -ForegroundColor $color
    }
    
    Write-Host "`nTop 10 Most Common Issues:" -ForegroundColor Yellow
    $results | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  - $($_.Name): $($_.Count) occurrences" -ForegroundColor Gray
    }
}

# Output detailed results based on format
switch ($OutputFormat) {
    'Console' {
        if ($results.Count -gt 0) {
            Write-Host "`nDetailed Issues:" -ForegroundColor Yellow
            
            $results | Group-Object { Split-Path $_.ScriptPath -Leaf } | ForEach-Object {
                Write-Host "`n📄 $($_.Name)" -ForegroundColor Cyan
                
                $_.Group | Sort-Object Line | ForEach-Object {
                    $color = switch ($_.Severity) {
                        'Error' { 'Red' }
                        'Warning' { 'Yellow' }
                        'Information' { 'Gray' }
                        default { 'White' }
                    }
                    
                    Write-Host "  Line $($_.Line): [$($_.Severity)] $($_.RuleName)" -ForegroundColor $color
                    Write-Host "    $($_.Message)" -ForegroundColor Gray
                }
            }
        }
    }
    'JSON' {
        $outputFile = Join-Path $projectRoot "PSScriptAnalyzer-Report.json"
        $results | ConvertTo-Json -Depth 5 | Set-Content $outputFile
        Write-Host "`nReport saved to: $outputFile" -ForegroundColor Green
    }
    'CSV' {
        $outputFile = Join-Path $projectRoot "PSScriptAnalyzer-Report.csv"
        $results | Select-Object RuleName, Severity, ScriptName, Line, Column, Message | Export-Csv $outputFile -NoTypeInformation
        Write-Host "`nReport saved to: $outputFile" -ForegroundColor Green
    }
}

# Summary
Write-Host "`n📈 Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Gray
Write-Host "Files analyzed: $($files.Count)" -ForegroundColor White
Write-Host "Total issues: $($results.Count)" -ForegroundColor White

if ($results.Count -gt 0) {
    Write-Host "`n💡 To fix issues automatically (where possible), run:" -ForegroundColor Yellow
    Write-Host "  ./scripts/Run-PSScriptAnalyzer.ps1 -Fix" -ForegroundColor White
}