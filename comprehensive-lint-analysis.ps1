#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Comprehensive PSScriptAnalyzer reporting for CI/CD
.DESCRIPTION
    Provides detailed analysis including errors, warnings, and informational messages
    with proper categorization and reporting for CI/CD pipelines.
#>

param(
    [ValidateSet('Error', 'Warning', 'Information', 'All')]
    [string]$Severity = 'All',
    
    [switch]$FailOnErrors,
    
    [switch]$FailOnWarnings,
    
    [string]$OutputPath,
    
    [switch]$Detailed
)

# Install PSScriptAnalyzer if not available
if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
}

Write-Host "🔍 Comprehensive PSScriptAnalyzer Analysis" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Determine severity levels to analyze
$severityLevels = switch ($Severity) {
    'Error' { @('Error') }
    'Warning' { @('Warning') }
    'Information' { @('Information') }
    'All' { @('Error', 'Warning', 'Information') }
}

Write-Host "📊 Analysis Configuration:" -ForegroundColor Yellow
Write-Host "  Severity Levels: $($severityLevels -join ', ')" -ForegroundColor White
Write-Host "  Fail on Errors: $FailOnErrors" -ForegroundColor White
Write-Host "  Fail on Warnings: $FailOnWarnings" -ForegroundColor White
Write-Host ""

# Run comprehensive analysis
$allResults = @()
$patterns = @('*.ps1', '*.psm1', '*.psd1')
$totalFiles = 0
$analyzedFiles = 0
$skippedFiles = 0

Write-Host "🔎 Scanning for PowerShell files..." -ForegroundColor Yellow

foreach ($pattern in $patterns) {
    $files = Get-ChildItem -Path . -Filter $pattern -Recurse -ErrorAction SilentlyContinue
    $totalFiles += $files.Count
    
    foreach ($file in $files) {
        # Skip test files and temporary files, but NOT configuration files
        if (($file.FullName -match 'tests[/\\].*\.Tests\.ps1$') -or 
            ($file.FullName -match '(temp|\.temp)') -or
            ($file.FullName -match 'test-.*\.ps1$')) {
            $skippedFiles++
            if ($Detailed) {
                Write-Host "  ⏭️  Skipped: $($file.Name) (test/temp file)" -ForegroundColor Gray
            }
            continue
        }

        $analyzedFiles++
        Write-Host "  📄 Analyzing: $($file.Name)" -ForegroundColor Cyan

        try {
            # Check if file has content
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content -or $content.Trim() -eq '') {
                Write-Host "    ⚠️  Empty file, skipping analysis" -ForegroundColor Yellow
                continue
            }

            $analysis = Invoke-ScriptAnalyzer -Path $file.FullName -Settings './tests/config/PSScriptAnalyzerSettings.psd1' -Severity $severityLevels
            if ($analysis) {
                $allResults += $analysis
                
                # Group by severity for this file
                $fileErrors = $analysis | Where-Object { $_.Severity -eq 'Error' }
                $fileWarnings = $analysis | Where-Object { $_.Severity -eq 'Warning' }
                $fileInfo = $analysis | Where-Object { $_.Severity -eq 'Information' }
                
                if ($fileErrors.Count -gt 0) {
                    Write-Host "    ❌ Errors: $($fileErrors.Count)" -ForegroundColor Red
                }
                if ($fileWarnings.Count -gt 0) {
                    Write-Host "    ⚠️  Warnings: $($fileWarnings.Count)" -ForegroundColor Yellow
                }
                if ($fileInfo.Count -gt 0) {
                    Write-Host "    ℹ️  Info: $($fileInfo.Count)" -ForegroundColor Blue
                }
                
                if ($Detailed) {
                    $analysis | ForEach-Object {
                        $icon = switch ($_.Severity) {
                            'Error' { '❌' }
                            'Warning' { '⚠️ ' }
                            'Information' { 'ℹ️ ' }
                        }
                        Write-Host "      $icon Line $($_.Line): $($_.Message)" -ForegroundColor White
                        Write-Host "         Rule: $($_.RuleName)" -ForegroundColor Gray
                    }
                }
            } else {
                Write-Host "    ✅ Clean" -ForegroundColor Green
            }
        } catch {
            Write-Host "    💥 Analysis failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "📈 Analysis Summary" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

# Calculate totals
$totalErrors = ($allResults | Where-Object { $_.Severity -eq 'Error' }).Count
$totalWarnings = ($allResults | Where-Object { $_.Severity -eq 'Warning' }).Count
$totalInfo = ($allResults | Where-Object { $_.Severity -eq 'Information' }).Count
$totalIssues = $allResults.Count

Write-Host "📊 File Statistics:" -ForegroundColor Yellow
Write-Host "  Total files found: $totalFiles" -ForegroundColor White
Write-Host "  Files analyzed: $analyzedFiles" -ForegroundColor White
Write-Host "  Files skipped: $skippedFiles" -ForegroundColor White
Write-Host ""

Write-Host "🔍 Issue Statistics:" -ForegroundColor Yellow
Write-Host "  ❌ Errors: $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { 'Red' } else { 'Green' })
Write-Host "  ⚠️  Warnings: $totalWarnings" -ForegroundColor $(if ($totalWarnings -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "  ℹ️  Information: $totalInfo" -ForegroundColor $(if ($totalInfo -gt 0) { 'Blue' } else { 'Green' })
Write-Host "  📝 Total issues: $totalIssues" -ForegroundColor White
Write-Host ""

# Most common issues
if ($allResults.Count -gt 0) {
    Write-Host "🏆 Top Issues by Rule:" -ForegroundColor Yellow
    $topRules = $allResults | Group-Object RuleName | Sort-Object Count -Descending | Select-Object -First 5
    $topRules | ForEach-Object {
        $ruleName = $_.Name
        $ruleExample = $allResults | Where-Object { $_.RuleName -eq $ruleName } | Select-Object -First 1
        $severityValue = if ($ruleExample) { $ruleExample.Severity.ToString() } else { 'Warning' }
        $icon = switch ($severityValue) {
            'Error' { '❌' }
            'Warning' { '⚠️ ' }
            'Information' { 'ℹ️ ' }
            default { '📝' }
        }
        Write-Host "  $icon $($ruleName): $($_.Count) occurrences" -ForegroundColor White
    }
    Write-Host ""
}

# Files with most issues
if ($allResults.Count -gt 0) {
    Write-Host "📁 Files with Most Issues:" -ForegroundColor Yellow
    $topFiles = $allResults | Group-Object ScriptName | Sort-Object Count -Descending | Select-Object -First 5
    $topFiles | ForEach-Object {
        $fileName = Split-Path $_.Name -Leaf
        Write-Host "  📄 $fileName`: $($_.Count) issues" -ForegroundColor White
    }
    Write-Host ""
}

# Export results if requested
if ($OutputPath) {
    Write-Host "💾 Exporting results to: $OutputPath" -ForegroundColor Yellow
    $exportData = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TotalFiles = $totalFiles
        AnalyzedFiles = $analyzedFiles
        SkippedFiles = $skippedFiles
        TotalErrors = $totalErrors
        TotalWarnings = $totalWarnings
        TotalInformation = $totalInfo
        TotalIssues = $totalIssues
        Results = $allResults
    }
    $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "  ✅ Export completed" -ForegroundColor Green
}

# Final status and exit code
Write-Host "🎯 Final Status:" -ForegroundColor Cyan
if ($totalErrors -eq 0 -and $totalWarnings -eq 0) {
    Write-Host "  🎉 All clean! No issues found." -ForegroundColor Green
    $exitCode = 0
} elseif ($totalErrors -eq 0) {
    Write-Host "  ✅ No errors found, but $totalWarnings warnings present." -ForegroundColor Yellow
    $exitCode = if ($FailOnWarnings) { 1 } else { 0 }
} else {
    Write-Host "  ❌ Found $totalErrors errors and $totalWarnings warnings." -ForegroundColor Red
    $exitCode = if ($FailOnErrors) { 1 } else { 0 }
}

Write-Host ""
Write-Host "Exit Code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } else { 'Red' })

if ($exitCode -ne 0) {
    Write-Error "Analysis completed with issues (exit code $exitCode)"
}

exit $exitCode
