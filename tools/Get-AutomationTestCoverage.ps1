#Requires -Version 7.0

<#
.SYNOPSIS
    Analyzes test coverage for automation scripts by comparing existing scripts to available test files.

.DESCRIPTION
    This script provides a comprehensive analysis of test coverage for automation scripts by:
    - Counting total automation scripts in /automation-scripts/
    - Counting existing test files in /tests/unit/automation-scripts/
    - Identifying scripts without tests
    - Categorizing coverage by script ranges (0000-0099, etc.)
    - Generating coverage statistics and recommendations

.PARAMETER OutputFormat
    Output format for results: Console, Json, or Html. Default: Console

.PARAMETER ShowUntested
    Show detailed list of scripts that don't have corresponding test files.

.PARAMETER ShowTested
    Show detailed list of scripts that have corresponding test files.

.PARAMETER Category
    Filter analysis by category ranges (Environment, Infrastructure, Development, etc.)

.PARAMETER OutputPath
    Path to save output files when using Json or Html format.

.EXAMPLE
    ./tools/Get-AutomationTestCoverage.ps1
    Show basic test coverage statistics

.EXAMPLE
    ./tools/Get-AutomationTestCoverage.ps1 -ShowUntested -ShowTested
    Show detailed lists of tested and untested scripts

.EXAMPLE
    ./tools/Get-AutomationTestCoverage.ps1 -Category Development -OutputFormat Html
    Generate HTML report for development scripts (0200-0299)

.EXAMPLE
    ./tools/Get-AutomationTestCoverage.ps1 -OutputFormat Json -OutputPath ./reports/
    Export coverage data as JSON
#>

[CmdletBinding()]
param(
    [ValidateSet('Console', 'Json', 'Html')]
    [string]$OutputFormat = 'Console',
    
    [switch]$ShowUntested,
    
    [switch]$ShowTested,
    
    [ValidateSet('Environment', 'Infrastructure', 'Development', 'Testing', 'Reporting', 'Git', 'Issues', 'Maintenance', 'All')]
    [string[]]$Category = @('All'),
    
    [string]$OutputPath = './tests/results/coverage'
)

# Category mappings to script number ranges
$CategoryRanges = @{
    'Environment'    = @(0, 99)
    'Infrastructure' = @(100, 199) 
    'Development'    = @(200, 299)
    'Testing'        = @(400, 499)
    'Reporting'      = @(500, 599)
    'Git'           = @(700, 799)
    'Issues'        = @(800, 899)
    'Maintenance'   = @(9000, 9999)
}

function Get-CategoryFromScriptNumber {
    param([int]$ScriptNumber)
    
    foreach ($cat in $CategoryRanges.Keys) {
        $range = $CategoryRanges[$cat]
        if ($ScriptNumber -ge $range[0] -and $ScriptNumber -le $range[1]) {
            return $cat
        }
    }
    return 'Unknown'
}

function Get-ScriptCoverageData {
    param([string[]]$Categories)
    
    Write-Host "Analyzing automation scripts and test coverage..." -ForegroundColor Cyan
    
    # Get all automation scripts
    $automationScripts = Get-ChildItem -Path './automation-scripts' -Filter '*.ps1'
    
    if (-not $automationScripts) {
        Write-Warning "No automation scripts found in ./automation-scripts/"
        return $null
    }
    
    # Get all test files
    $testFiles = Get-ChildItem -Path './tests/unit/automation-scripts' -Include '*.Tests.ps1' -Recurse
    
    Write-Host "Found $($automationScripts.Count) automation scripts and $($testFiles.Count) test files" -ForegroundColor Green
    
    # Parse scripts and tests
    $scriptData = @()
    $testedScripts = @{}
    
    # Build lookup of tested scripts
    foreach ($testFile in $testFiles) {
        $testName = $testFile.Name -replace '\.Tests\.ps1$', ''
        $testedScripts[$testName] = $testFile
    }
    
    # Analyze each automation script
    foreach ($script in $automationScripts) {
        $scriptName = $script.BaseName
        $hasTest = $testedScripts.ContainsKey($scriptName)
        
        # Extract script number
        $scriptNumber = $null
        if ($scriptName -match '^(\d{4})_') {
            $scriptNumber = [int]$Matches[1]
        }
        
        $scriptCategory = if ($scriptNumber) { Get-CategoryFromScriptNumber -ScriptNumber $scriptNumber } else { 'Unknown' }
        
        # Filter by category if specified
        if ($Categories -notcontains 'All' -and $Categories -notcontains $scriptCategory) {
            continue
        }
        
        # Get script description from file header
        $description = "No description available"
        try {
            $content = Get-Content $script.FullName -First 20
            foreach ($line in $content) {
                if ($line -match '^\s*#\s*Description:\s*(.+)') {
                    $description = $Matches[1].Trim()
                    break
                } elseif ($line -match '^\s*#\s+(.+)' -and $line -notmatch '^\s*#Requires' -and $line -notmatch '^\s*#\s*Stage:') {
                    $description = $Matches[1].Trim()
                    break
                }
            }
        }
        catch {
            # Ignore errors reading file
        }
        
        $scriptData += @{
            Name = $scriptName
            FullPath = $script.FullName
            Number = $scriptNumber
            Category = $scriptCategory
            HasTest = $hasTest
            TestFile = if ($hasTest) { $testedScripts[$scriptName].FullName } else { $null }
            Description = $description
            Size = $script.Length
            LastModified = $script.LastWriteTime
        }
    }
    
    # Calculate statistics by category
    $categoryStats = @{}
    foreach ($cat in ($scriptData | Select-Object -ExpandProperty Category -Unique | Sort-Object)) {
        $categoryScripts = $scriptData | Where-Object { $_.Category -eq $cat }
        $testedCount = ($categoryScripts | Where-Object { $_.HasTest }).Count
        $totalCount = $categoryScripts.Count
        $coverage = if ($totalCount -gt 0) { [Math]::Round(($testedCount / $totalCount) * 100, 2) } else { 0 }
        
        $categoryStats[$cat] = @{
            Category = $cat
            TotalScripts = $totalCount
            TestedScripts = $testedCount
            UntestedScripts = $totalCount - $testedCount
            CoveragePercent = $coverage
            Scripts = $categoryScripts
        }
    }
    
    # Overall statistics
    $totalScripts = $scriptData.Count
    $totalTested = ($scriptData | Where-Object { $_.HasTest }).Count
    $totalUntested = $totalScripts - $totalTested
    $overallCoverage = if ($totalScripts -gt 0) { [Math]::Round(($totalTested / $totalScripts) * 100, 2) } else { 0 }
    
    return @{
        OverallStats = @{
            TotalScripts = $totalScripts
            TestedScripts = $totalTested
            UntestedScripts = $totalUntested
            CoveragePercent = $overallCoverage
        }
        CategoryStats = $categoryStats
        Scripts = $scriptData
        GeneratedAt = Get-Date
        Categories = $Categories
    }
}

function Write-ConsoleReport {
    param($CoverageData)
    
    $overall = $CoverageData.OverallStats
    
    Write-Host "`n=== Automation Script Test Coverage Analysis ===" -ForegroundColor Yellow
    Write-Host "Generated: $($CoverageData.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "Categories: $($CoverageData.Categories -join ', ')" -ForegroundColor Gray
    
    Write-Host "`n=== Overall Statistics ===" -ForegroundColor Cyan
    Write-Host "Total Scripts:    $($overall.TotalScripts)" -ForegroundColor White
    Write-Host "Tested Scripts:   $($overall.TestedScripts)" -ForegroundColor Green
    Write-Host "Untested Scripts: $($overall.UntestedScripts)" -ForegroundColor Red
    Write-Host "Test Coverage:    $($overall.CoveragePercent)%" -ForegroundColor $(if ($overall.CoveragePercent -ge 80) { 'Green' } elseif ($overall.CoveragePercent -ge 50) { 'Yellow' } else { 'Red' })
    
    Write-Host "`n=== Coverage by Category ===" -ForegroundColor Cyan
    $table = $CoverageData.CategoryStats.Values | Sort-Object Category | ForEach-Object {
        [PSCustomObject]@{
            Category = $_.Category
            'Total Scripts' = $_.TotalScripts
            'Tested' = $_.TestedScripts
            'Untested' = $_.UntestedScripts
            'Coverage %' = "$($_.CoveragePercent)%"
        }
    }
    $table | Format-Table -AutoSize
    
    if ($ShowTested) {
        Write-Host "`n=== Scripts WITH Tests ===" -ForegroundColor Green
        $tested = $CoverageData.Scripts | Where-Object { $_.HasTest } | Sort-Object Number, Name
        if ($tested) {
            foreach ($script in $tested) {
                $categoryPadded = $script.Category.PadRight(12)
                Write-Host "  [$categoryPadded] $($script.Name) - $($script.Description)" -ForegroundColor Green
            }
        } else {
            Write-Host "  No tested scripts found for the specified categories." -ForegroundColor Yellow
        }
    }
    
    if ($ShowUntested) {
        Write-Host "`n=== Scripts WITHOUT Tests ===" -ForegroundColor Red
        $untested = $CoverageData.Scripts | Where-Object { -not $_.HasTest } | Sort-Object Number, Name
        if ($untested) {
            foreach ($script in $untested) {
                $categoryPadded = $script.Category.PadRight(12)
                Write-Host "  [$categoryPadded] $($script.Name) - $($script.Description)" -ForegroundColor Red
            }
            
            Write-Host "`n=== Test Generation Recommendations ===" -ForegroundColor Yellow
            Write-Host "To create test files for untested scripts, run:" -ForegroundColor Yellow
            Write-Host ""
            foreach ($script in $untested | Select-Object -First 5) {
                Write-Host "  New-Item './tests/unit/automation-scripts/$($script.Name).Tests.ps1'" -ForegroundColor Gray
            }
            if ($untested.Count -gt 5) {
                Write-Host "  ... and $($untested.Count - 5) more" -ForegroundColor Gray
            }
        } else {
            Write-Host "  All scripts have corresponding test files\!" -ForegroundColor Green
        }
    }
    
    Write-Host "`n=== Summary ===" -ForegroundColor Yellow
    if ($overall.CoveragePercent -eq 100) {
        Write-Host "Excellent\! All automation scripts have corresponding test files." -ForegroundColor Green
    } elseif ($overall.CoveragePercent -ge 80) {
        Write-Host "Good test coverage. Consider adding tests for the remaining $($overall.UntestedScripts) scripts." -ForegroundColor Green
    } elseif ($overall.CoveragePercent -ge 50) {
        Write-Host "Moderate test coverage. Focus on adding tests for critical scripts first." -ForegroundColor Yellow
    } else {
        Write-Host "Low test coverage. Consider prioritizing test creation for automation scripts." -ForegroundColor Red
    }
    Write-Host ""
}

function Export-JsonReport {
    param($CoverageData, $OutputPath)
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $jsonPath = Join-Path $OutputPath "automation-test-coverage_$timestamp.json"
    
    $CoverageData | ConvertTo-Json -Depth 4 | Out-File -Path $jsonPath -Encoding UTF8
    
    Write-Host "JSON report saved to: $jsonPath" -ForegroundColor Green
    return $jsonPath
}

function Export-HtmlReport {
    param($CoverageData, $OutputPath)
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $htmlPath = Join-Path $OutputPath "automation-test-coverage_$timestamp.html"
    
    $overall = $CoverageData.OverallStats
    $coverageColor = if ($overall.CoveragePercent -ge 80) { '#28a745' } elseif ($overall.CoveragePercent -ge 50) { '#ffc107' } else { '#dc3545' }
    
    # Create HTML content
    $html = @"
<\!DOCTYPE html>
<html>
<head>
    <title>Automation Script Test Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007acc; margin-bottom: 20px; padding-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; border-left: 4px solid #007acc; }
        .stat-value { font-size: 2em; font-weight: bold; color: #007acc; }
        .stat-label { color: #666; margin-top: 5px; }
        .coverage-stat .stat-value { color: $coverageColor; }
        .category-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .category-table th, .category-table td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        .category-table th { background-color: #f8f9fa; font-weight: bold; }
        .script-list { margin: 20px 0; }
        .script-item { padding: 8px; margin: 5px 0; border-radius: 4px; font-family: monospace; font-size: 0.9em; }
        .tested { background-color: #d4edda; border-left: 4px solid #28a745; }
        .untested { background-color: #f8d7da; border-left: 4px solid #dc3545; }
        .category-tag { display: inline-block; padding: 2px 6px; border-radius: 3px; font-size: 0.8em; background-color: #007acc; color: white; margin-right: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Automation Script Test Coverage Report</h1>
            <p>Generated on $($CoverageData.GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss'))</p>
            <p>Categories: $($CoverageData.Categories -join ', ')</p>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($overall.TotalScripts)</div>
                <div class="stat-label">Total Scripts</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" style="color: #28a745;">$($overall.TestedScripts)</div>
                <div class="stat-label">Tested Scripts</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" style="color: #dc3545;">$($overall.UntestedScripts)</div>
                <div class="stat-label">Untested Scripts</div>
            </div>
            <div class="stat-card coverage-stat">
                <div class="stat-value">$($overall.CoveragePercent)%</div>
                <div class="stat-label">Test Coverage</div>
            </div>
        </div>
        
        <h2>Coverage by Category</h2>
        <table class="category-table">
            <thead>
                <tr>
                    <th>Category</th>
                    <th>Total Scripts</th>
                    <th>Tested</th>
                    <th>Untested</th>
                    <th>Coverage %</th>
                </tr>
            </thead>
            <tbody>
"@
    
    foreach ($category in ($CoverageData.CategoryStats.Values | Sort-Object Category)) {
        $html += @"
                <tr>
                    <td>$($category.Category)</td>
                    <td>$($category.TotalScripts)</td>
                    <td style="color: #28a745;">$($category.TestedScripts)</td>
                    <td style="color: #dc3545;">$($category.UntestedScripts)</td>
                    <td><strong>$($category.CoveragePercent)%</strong></td>
                </tr>
"@
    }
    
    $html += @"
            </tbody>
        </table>
"@
    
    # Add tested scripts if requested
    if ($ShowTested) {
        $tested = $CoverageData.Scripts | Where-Object { $_.HasTest } | Sort-Object Number, Name
        if ($tested) {
            $html += @"
        <h2>Scripts WITH Tests ($($tested.Count))</h2>
        <div class="script-list">
"@
            foreach ($script in $tested) {
                $html += @"
            <div class="script-item tested">
                <span class="category-tag">$($script.Category)</span>
                <strong>$($script.Name)</strong> - $($script.Description)
            </div>
"@
            }
            $html += "        </div>`n"
        }
    }
    
    # Add untested scripts if requested
    if ($ShowUntested) {
        $untested = $CoverageData.Scripts | Where-Object { -not $_.HasTest } | Sort-Object Number, Name
        if ($untested) {
            $html += @"
        <h2>Scripts WITHOUT Tests ($($untested.Count))</h2>
        <div class="script-list">
"@
            foreach ($script in $untested) {
                $html += @"
            <div class="script-item untested">
                <span class="category-tag">$($script.Category)</span>
                <strong>$($script.Name)</strong> - $($script.Description)
            </div>
"@
            }
            $html += "        </div>`n"
        }
    }
    
    $html += @"
        <div style="text-align: center; color: #666; margin-top: 30px; font-size: 0.9em;">
            Report generated by Get-AutomationTestCoverage.ps1
        </div>
    </div>
</body>
</html>
"@
    
    $html | Out-File -Path $htmlPath -Encoding UTF8
    
    Write-Host "HTML report saved to: $htmlPath" -ForegroundColor Green
    return $htmlPath
}

# Main execution
try {
    Write-Host "Automation Script Test Coverage Analyzer" -ForegroundColor Yellow
    Write-Host "=========================================`n" -ForegroundColor Yellow
    
    # Get coverage data
    $coverageData = Get-ScriptCoverageData -Categories $Category
    
    if (-not $coverageData) {
        Write-Error "Failed to analyze script coverage. No data available."
        exit 1
    }
    
    # Output results based on format
    switch ($OutputFormat) {
        'Console' {
            Write-ConsoleReport -CoverageData $coverageData
        }
        'Json' {
            $jsonPath = Export-JsonReport -CoverageData $coverageData -OutputPath $OutputPath
            Write-Host "Coverage data exported to JSON: $jsonPath"
        }
        'Html' {
            $htmlPath = Export-HtmlReport -CoverageData $coverageData -OutputPath $OutputPath
            Write-Host "Coverage report exported to HTML: $htmlPath"
        }
    }
    
    # Set exit code based on coverage
    $exitCode = if ($coverageData.OverallStats.CoveragePercent -lt 50) { 1 } else { 0 }
    exit $exitCode
}
catch {
    Write-Error "Error analyzing test coverage: $($_.Exception.Message)"
    Write-Error $_.Exception.StackTrace
    exit 1
}
