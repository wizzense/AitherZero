#Requires -Version 7.0

<#
.SYNOPSIS
    Generate comprehensive project status report including dependencies, tests, coverage, and documentation
#>

[CmdletBinding()]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$OutputPath = (Join-Path $ProjectPath "tests/reports"),
    [ValidateSet('HTML', 'JSON', 'Markdown', 'All')]
    [string]$Format = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import logging module
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
    $script:LoggingAvailable = $true
} else {
    $script:LoggingAvailable = $false
}

function Write-ReportLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "ProjectReport"
    } else {
        Write-Host "[$Level] $Message"
    }
}

Write-ReportLog "Starting comprehensive project report generation"

# Initialize report structure
$projectReport = @{
    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ProjectName = "AitherZero"
    Version = if (Test-Path (Join-Path $ProjectPath "VERSION")) { Get-Content (Join-Path $ProjectPath "VERSION") -Raw } else { "Unknown" }
    Platform = $PSVersionTable.Platform
    PSVersion = $PSVersionTable.PSVersion.ToString()
    Dependencies = @{}
    TestResults = @{}
    Coverage = @{}
    CodeQuality = @{}
    Documentation = @{}
    ModuleStatus = @{}
    FileAnalysis = @{}
}

# 1. Analyze Dependencies
Write-ReportLog "Analyzing project dependencies..."
$moduleFiles = Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse -ErrorAction SilentlyContinue
foreach ($moduleFile in $moduleFiles) {
    try {
        $moduleInfo = Import-PowerShellDataFile $moduleFile.FullName
        $projectReport.Dependencies[$moduleFile.BaseName] = @{
            Path = $moduleFile.FullName.Replace($ProjectPath, '.')
            RequiredModules = $moduleInfo.RequiredModules ?? @()
            Version = $moduleInfo.ModuleVersion ?? "Unknown"
        }
    } catch {
        Write-ReportLog "Failed to parse module: $($moduleFile.Name)" -Level Warning
    }
}

# 2. Collect Test Results
Write-ReportLog "Collecting test results..."
$testResultsPath = Join-Path $OutputPath "*.json"
$testFiles = Get-ChildItem -Path $testResultsPath -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Summary*.json" }
foreach ($testFile in $testFiles) {
    $testData = Get-Content $testFile.FullName | ConvertFrom-Json
    $projectReport.TestResults[$testFile.BaseName] = $testData
}

# Also analyze test files
$testScripts = Get-ChildItem -Path (Join-Path $ProjectPath "tests") -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue
$projectReport.TestResults.TestFileCount = @($testScripts).Count
$projectReport.TestResults.TestFiles = $testScripts | ForEach-Object { $_.FullName.Replace($ProjectPath, '.') }

# 3. Calculate Code Coverage
Write-ReportLog "Calculating code coverage..."
$psFiles = Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse | Where-Object { 
    $_.FullName -notlike "*\tests\*" -and 
    $_.FullName -notlike "*\legacy-to-migrate\*" -and
    $_.FullName -notlike "*\examples\*"
}
$psmFiles = Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse | Where-Object { 
    $_.FullName -notlike "*\tests\*" -and 
    $_.FullName -notlike "*\legacy-to-migrate\*"
}

$totalLines = 0
$codeLines = 0
$commentLines = 0
$functionCount = 0

foreach ($file in ($psFiles + $psmFiles)) {
    $content = Get-Content $file.FullName
    $totalLines += $content.Count
    
    foreach ($line in $content) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^#' -or $trimmed -match '^<#') {
            $commentLines++
        } elseif ($trimmed -ne '') {
            $codeLines++
        }
        if ($trimmed -match '^function\s+\w+') {
            $functionCount++
        }
    }
}

$projectReport.Coverage = @{
    TotalFiles = @($psFiles).Count + @($psmFiles).Count
    TotalLines = $totalLines
    CodeLines = $codeLines
    CommentLines = $commentLines
    BlankLines = $totalLines - $codeLines - $commentLines
    CommentRatio = if ($codeLines -gt 0) { [math]::Round(($commentLines / $codeLines) * 100, 2) } else { 0 }
    FunctionCount = $functionCount
}

# 4. Code Quality Analysis
Write-ReportLog "Analyzing code quality..."
$analysisResultsPath = Join-Path $OutputPath "../analysis"
if (Test-Path $analysisResultsPath) {
    $analysisFiles = Get-ChildItem -Path $analysisResultsPath -Filter "*Summary*.json" -ErrorAction SilentlyContinue
    foreach ($analysisFile in $analysisFiles) {
        $analysisData = Get-Content $analysisFile.FullName | ConvertFrom-Json
        $projectReport.CodeQuality[$analysisFile.BaseName] = $analysisData
    }
}

# 5. Documentation Analysis
Write-ReportLog "Analyzing documentation..."
$docFiles = @(
    Get-ChildItem -Path $ProjectPath -Filter "*.md" -Recurse -ErrorAction SilentlyContinue
    Get-ChildItem -Path $ProjectPath -Filter "README*" -Recurse -ErrorAction SilentlyContinue
)

$helpCoverage = 0
$functionsWithHelp = 0
foreach ($file in ($psFiles + $psmFiles)) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'function\s+(\w+)') {
        $functionName = $Matches[1]
        if ($content -match "<#[\s\S]*?\.SYNOPSIS[\s\S]*?#>[\s\S]*?function\s+$functionName") {
            $functionsWithHelp++
        }
    }
}

$projectReport.Documentation = @{
    MarkdownFiles = @($docFiles).Count
    DocumentationFiles = $docFiles | ForEach-Object { $_.FullName.Replace($ProjectPath, '.') }
    FunctionsWithHelp = $functionsWithHelp
    HelpCoverage = if ($functionCount -gt 0) { [math]::Round(($functionsWithHelp / $functionCount) * 100, 2) } else { 0 }
}

# 6. Module Status
Write-ReportLog "Checking module status..."
$domains = Get-ChildItem -Path (Join-Path $ProjectPath "domains") -Directory -ErrorAction SilentlyContinue
foreach ($domain in $domains) {
    $moduleFiles = Get-ChildItem -Path $domain.FullName -Filter "*.psm1" -ErrorAction SilentlyContinue
    $projectReport.ModuleStatus[$domain.Name] = @{
        ModuleCount = @($moduleFiles).Count
        Modules = $moduleFiles | ForEach-Object { $_.BaseName }
        HasReadme = Test-Path (Join-Path $domain.FullName "README.md")
    }
}

# 7. File Analysis
Write-ReportLog "Performing file analysis..."
$projectReport.FileAnalysis = @{
    TotalFiles = (Get-ChildItem -Path $ProjectPath -File -Recurse -ErrorAction SilentlyContinue).Count
    PowerShellFiles = @($psFiles).Count + @($psmFiles).Count
    TestFiles = @($testScripts).Count
    ConfigFiles = (Get-ChildItem -Path $ProjectPath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue).Count
    LargestFiles = Get-ChildItem -Path $ProjectPath -File -Recurse -ErrorAction SilentlyContinue | 
        Sort-Object Length -Descending | 
        Select-Object -First 10 | 
        ForEach-Object { @{
            Path = $_.FullName.Replace($ProjectPath, '.')
            SizeMB = [math]::Round($_.Length / 1MB, 2)
        }}
}

# Generate Reports
Write-ReportLog "Generating reports in format: $Format"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

if ($Format -eq 'JSON' -or $Format -eq 'All') {
    $jsonPath = Join-Path $OutputPath "ProjectReport-$timestamp.json"
    $projectReport | ConvertTo-Json -Depth 10 | Set-Content $jsonPath
    Write-ReportLog "JSON report saved to: $jsonPath"
}

if ($Format -eq 'HTML' -or $Format -eq 'All') {
    $htmlPath = Join-Path $OutputPath "ProjectReport-$timestamp.html"
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Project Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1, h2, h3 { color: #333; }
        .metric { display: inline-block; margin: 10px; padding: 15px; background-color: #f0f0f0; border-radius: 5px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #0066cc; }
        .metric-label { font-size: 14px; color: #666; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0066cc; color: white; }
        .good { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        .section { margin: 30px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>AitherZero Project Report</h1>
        <p>Generated: $($projectReport.Timestamp) | Platform: $($projectReport.Platform) | PS Version: $($projectReport.PSVersion)</p>
        
        <div class="section">
            <h2>Project Overview</h2>
            <div class="metric">
                <div class="metric-value">$($projectReport.FileAnalysis.TotalFiles)</div>
                <div class="metric-label">Total Files</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($projectReport.Coverage.TotalFiles)</div>
                <div class="metric-label">Code Files</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($projectReport.Coverage.FunctionCount)</div>
                <div class="metric-label">Functions</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($projectReport.Coverage.CodeLines)</div>
                <div class="metric-label">Lines of Code</div>
            </div>
        </div>

        <div class="section">
            <h2>Code Quality</h2>
            <div class="metric">
                <div class="metric-value">$($projectReport.Coverage.CommentRatio)%</div>
                <div class="metric-label">Comment Ratio</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($projectReport.Documentation.HelpCoverage)%</div>
                <div class="metric-label">Help Coverage</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($projectReport.TestResults.TestFileCount)</div>
                <div class="metric-label">Test Files</div>
            </div>
        </div>

        <div class="section">
            <h2>Module Status</h2>
            <table>
                <tr><th>Domain</th><th>Modules</th><th>Has README</th></tr>
"@
    foreach ($domain in $projectReport.ModuleStatus.Keys) {
        $html += "<tr><td>$domain</td><td>$($projectReport.ModuleStatus[$domain].ModuleCount)</td><td>$($projectReport.ModuleStatus[$domain].HasReadme)</td></tr>`n"
    }
    $html += @"
            </table>
        </div>

        <div class="section">
            <h2>Dependencies</h2>
            <table>
                <tr><th>Module</th><th>Version</th><th>Required Modules</th></tr>
"@
    foreach ($dep in $projectReport.Dependencies.Keys) {
        $html += "<tr><td>$dep</td><td>$($projectReport.Dependencies[$dep].Version)</td><td>$($projectReport.Dependencies[$dep].RequiredModules -join ', ')</td></tr>`n"
    }
    $html += @"
            </table>
        </div>
    </div>
</body>
</html>
"@
    $html | Set-Content $htmlPath
    Write-ReportLog "HTML report saved to: $htmlPath"
}

if ($Format -eq 'Markdown' -or $Format -eq 'All') {
    $mdPath = Join-Path $OutputPath "ProjectReport-$timestamp.md"
    $markdown = @"
# AitherZero Project Report

Generated: $($projectReport.Timestamp)  
Platform: $($projectReport.Platform) | PowerShell: $($projectReport.PSVersion)

## Project Metrics

- **Total Files**: $($projectReport.FileAnalysis.TotalFiles)
- **Code Files**: $($projectReport.Coverage.TotalFiles)
- **Functions**: $($projectReport.Coverage.FunctionCount)
- **Lines of Code**: $($projectReport.Coverage.CodeLines)
- **Comment Ratio**: $($projectReport.Coverage.CommentRatio)%
- **Documentation Coverage**: $($projectReport.Documentation.HelpCoverage)%

## Test Coverage

- **Test Files**: $($projectReport.TestResults.TestFileCount)
- **Test Results Available**: $($projectReport.TestResults.Count - 2)

## Module Architecture

| Domain | Modules | Has README |
|--------|---------|------------|
"@
    foreach ($domain in $projectReport.ModuleStatus.Keys) {
        $markdown += "| $domain | $($projectReport.ModuleStatus[$domain].ModuleCount) | $($projectReport.ModuleStatus[$domain].HasReadme) |`n"
    }
    
    $markdown += @"

## Code Quality Issues

"@
    foreach ($analysis in $projectReport.CodeQuality.Keys) {
        $analysisData = $projectReport.CodeQuality[$analysis]
        if ($analysisData -and $analysisData.PSObject.Properties['TotalIssues']) {
            $markdown += "- **$analysis**: $($analysisData.TotalIssues) issues`n"
        }
    }
    
    $markdown | Set-Content $mdPath
    Write-ReportLog "Markdown report saved to: $mdPath"
}

# Display Summary
Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "PROJECT REPORT SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Total Files: $($projectReport.FileAnalysis.TotalFiles)"
Write-Host "Code Files: $($projectReport.Coverage.TotalFiles)"
Write-Host "Functions: $($projectReport.Coverage.FunctionCount)"
Write-Host "Lines of Code: $($projectReport.Coverage.CodeLines)"
Write-Host "Comment Ratio: $($projectReport.Coverage.CommentRatio)%"
Write-Host "Help Coverage: $($projectReport.Documentation.HelpCoverage)%"
Write-Host "Test Files: $($projectReport.TestResults.TestFileCount)"
Write-Host "=" * 60 -ForegroundColor Cyan

return $projectReport