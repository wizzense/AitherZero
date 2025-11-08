#Requires -Version 7.0
# Stage: Issue Management
# Dependencies: LogViewer
# Description: Comprehensive log search across all log sources with advanced filtering
# Tags: logs, search, troubleshooting, diagnostics

<#
.SYNOPSIS
    Advanced log search utility for comprehensive log analysis

.DESCRIPTION
    Searches across all log sources including application logs, transcripts,
    orchestration logs, test results, and analysis output. Supports regex,
    context lines, date filtering, and multiple export formats.

.PARAMETER Pattern
    Search pattern (supports regex if -Regex is specified)

.PARAMETER LogType
    Type of logs to search: All, Application, Transcript, Orchestration, Test, Analysis, Archived

.PARAMETER Regex
    Treat pattern as regular expression

.PARAMETER CaseSensitive
    Perform case-sensitive search

.PARAMETER Context
    Number of context lines to show before and after each match

.PARAMETER MaxResults
    Maximum number of results to return (default: 100)

.PARAMETER After
    Search only logs created after this date

.PARAMETER Before
    Search only logs created before this date

.PARAMETER Severity
    Filter by log severity level

.PARAMETER Format
    Output format: Text, JSON, CSV, HTML

.PARAMETER OutputFile
    Save results to file

.PARAMETER Interactive
    Interactive search mode with menu

.EXAMPLE
    ./0830_Search-AllLogs.ps1 -Pattern "error"
    Search for "error" in all logs

.EXAMPLE
    ./0830_Search-AllLogs.ps1 -Pattern "failed" -Context 3 -LogType Test
    Search test logs for "failed" with 3 lines of context

.EXAMPLE
    ./0830_Search-AllLogs.ps1 -Pattern "ERROR|FATAL" -Regex -Format JSON
    Regex search and export to JSON

.EXAMPLE
    ./0830_Search-AllLogs.ps1 -Pattern "deploy" -After "2025-11-01" -Severity Error
    Search for deployment errors after Nov 1st

.NOTES
    Part of Phase 0 QoL enhancements - User-requested feature
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Pattern,
    
    [Parameter()]
    [ValidateSet('All', 'Application', 'Transcript', 'Orchestration', 'Test', 'Analysis', 'Archived')]
    [string]$LogType = 'All',
    
    [Parameter()]
    [switch]$Regex,
    
    [Parameter()]
    [switch]$CaseSensitive,
    
    [Parameter()]
    [ValidateRange(0, 10)]
    [int]$Context = 0,
    
    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$MaxResults = 100,
    
    [Parameter()]
    [datetime]$After,
    
    [Parameter()]
    [datetime]$Before,
    
    [Parameter()]
    [ValidateSet('Error', 'Warning', 'Information', 'Debug', 'Trace', 'Critical')]
    [string]$Severity,
    
    [Parameter()]
    [ValidateSet('Text', 'JSON', 'CSV', 'HTML')]
    [string]$Format = 'Text',
    
    [Parameter()]
    [string]$OutputFile,
    
    [Parameter()]
    [switch]$Interactive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Initialize environment
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Import required modules
$modulesToImport = @(
    "domains/utilities/LogViewer.psm1",
    "aithercore/utilities/Logging.psm1"
)

foreach ($modulePath in $modulesToImport) {
    $fullPath = Join-Path $ProjectRoot $modulePath
    if (Test-Path $fullPath) {
        Import-Module $fullPath -Force -ErrorAction SilentlyContinue
    }
}

function Write-ScriptLog {
    param([string]$Message, [string]$Level = 'Information')
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message "[0830] $Message" -Level $Level
    }
}

function Get-AllLogFiles {
    <#
    .SYNOPSIS
        Discovers all log files across different sources
    #>
    param(
        [string]$Type = 'All',
        [datetime]$After,
        [datetime]$Before
    )
    
    $allFiles = @()
    $logsPath = Join-Path $ProjectRoot "logs"
    $testsPath = Join-Path $ProjectRoot "tests"
    
    # Application logs
    if ($Type -in @('All', 'Application')) {
        if (Test-Path $logsPath) {
            $appLogs = Get-ChildItem -Path $logsPath -Filter "aitherzero-*.log" -ErrorAction SilentlyContinue
            $allFiles += $appLogs | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    Name = $_.Name
                    Type = 'Application'
                    LastWriteTime = $_.LastWriteTime
                    SizeKB = [Math]::Round($_.Length / 1KB, 2)
                }
            }
        }
    }
    
    # Transcript logs
    if ($Type -in @('All', 'Transcript')) {
        if (Test-Path $logsPath) {
            $transcripts = Get-ChildItem -Path $logsPath -Filter "transcript-*.log" -ErrorAction SilentlyContinue
            $allFiles += $transcripts | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    Name = $_.Name
                    Type = 'Transcript'
                    LastWriteTime = $_.LastWriteTime
                    SizeKB = [Math]::Round($_.Length / 1KB, 2)
                }
            }
        }
    }
    
    # Test result logs
    if ($Type -in @('All', 'Test')) {
        $testResultsPath = Join-Path $testsPath "results"
        if (Test-Path $testResultsPath) {
            $testLogs = Get-ChildItem -Path $testResultsPath -Include "*.xml", "*.json", "*.log" -Recurse -ErrorAction SilentlyContinue
            $allFiles += $testLogs | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    Name = $_.Name
                    Type = 'Test'
                    LastWriteTime = $_.LastWriteTime
                    SizeKB = [Math]::Round($_.Length / 1KB, 2)
                }
            }
        }
    }
    
    # Analysis logs (PSScriptAnalyzer, etc.)
    if ($Type -in @('All', 'Analysis')) {
        $analysisPath = Join-Path $testsPath "analysis"
        if (Test-Path $analysisPath) {
            $analysisLogs = Get-ChildItem -Path $analysisPath -Include "*.csv", "*.json", "*.log" -Recurse -ErrorAction SilentlyContinue
            $allFiles += $analysisLogs | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    Name = $_.Name
                    Type = 'Analysis'
                    LastWriteTime = $_.LastWriteTime
                    SizeKB = [Math]::Round($_.Length / 1KB, 2)
                }
            }
        }
    }
    
    # Orchestration logs (if they exist in reports)
    if ($Type -in @('All', 'Orchestration')) {
        $reportsPath = Join-Path $ProjectRoot "reports"
        if (Test-Path $reportsPath) {
            $orchLogs = Get-ChildItem -Path $reportsPath -Filter "*.log" -Recurse -ErrorAction SilentlyContinue
            $allFiles += $orchLogs | ForEach-Object {
                [PSCustomObject]@{
                    FullName = $_.FullName
                    Name = $_.Name
                    Type = 'Orchestration'
                    LastWriteTime = $_.LastWriteTime
                    SizeKB = [Math]::Round($_.Length / 1KB, 2)
                }
            }
        }
    }
    
    # Filter by date
    if ($After) {
        $allFiles = $allFiles | Where-Object { $_.LastWriteTime -ge $After }
    }
    if ($Before) {
        $allFiles = $allFiles | Where-Object { $_.LastWriteTime -le $Before }
    }
    
    return $allFiles | Sort-Object LastWriteTime -Descending
}

function Search-LogFile {
    <#
    .SYNOPSIS
        Searches a single log file with advanced options
    #>
    param(
        [string]$Path,
        [string]$Pattern,
        [switch]$Regex,
        [switch]$CaseSensitive,
        [int]$Context,
        [string]$Severity
    )
    
    if (-not (Test-Path $Path)) {
        return @()
    }
    
    $searchParams = @{
        Path = $Path
        Pattern = $Pattern
    }
    
    if ($Context -gt 0) {
        $searchParams['Context'] = $Context, $Context
    }
    
    if ($CaseSensitive) {
        $searchParams['CaseSensitive'] = $true
    }
    
    try {
        $matches = Select-String @searchParams -ErrorAction SilentlyContinue
        
        # Filter by severity if specified
        if ($Severity -and $matches) {
            $matches = $matches | Where-Object { $_.Line -match "\[$Severity\s*\]" }
        }
        
        return $matches
    } catch {
        Write-ScriptLog "Error searching file ${Path}: $_" -Level 'Warning'
        return @()
    }
}

function Format-SearchResults {
    <#
    .SYNOPSIS
        Formats search results for output
    #>
    param(
        [array]$Results,
        [string]$Pattern,
        [string]$Format
    )
    
    switch ($Format) {
        'Text' {
            Write-Host "`n🔍 LOG SEARCH RESULTS" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "Pattern: '$Pattern'" -ForegroundColor White
            Write-Host "Results: $($Results.TotalMatches) matches across $($Results.FilesWithMatches) files" -ForegroundColor White
            Write-Host ""
            
            foreach ($fileResult in $Results.FileResults) {
                $icon = switch ($fileResult.Type) {
                    'Application' { '📋' }
                    'Transcript' { '📜' }
                    'Test' { '✅' }
                    'Analysis' { '📊' }
                    'Orchestration' { '⚙️' }
                    default { '📄' }
                }
                
                Write-Host "$icon $($fileResult.FileName) ($($fileResult.MatchCount) matches)" -ForegroundColor Yellow
                Write-Host "───────────────────────────────────────────" -ForegroundColor DarkGray
                
                foreach ($match in $fileResult.Matches | Select-Object -First 10) {
                    $timestamp = if ($match.Line -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})') {
                        $matches[1]
                    } else {
                        "Line $($match.LineNumber)"
                    }
                    
                    Write-Host "  $timestamp" -ForegroundColor DarkGray
                    Write-Host "  > $($match.Line.Trim())" -ForegroundColor Gray
                    
                    if ($match.Context) {
                        foreach ($contextLine in $match.Context.PreContext) {
                            Write-Host "    $contextLine" -ForegroundColor DarkGray
                        }
                        foreach ($contextLine in $match.Context.PostContext) {
                            Write-Host "    $contextLine" -ForegroundColor DarkGray
                        }
                    }
                    Write-Host ""
                }
                
                if ($fileResult.MatchCount -gt 10) {
                    Write-Host "  ... and $($fileResult.MatchCount - 10) more matches" -ForegroundColor DarkGray
                }
                Write-Host ""
            }
        }
        
        'JSON' {
            $Results | ConvertTo-Json -Depth 10
        }
        
        'CSV' {
            $flatResults = @()
            foreach ($fileResult in $Results.FileResults) {
                foreach ($match in $fileResult.Matches) {
                    $flatResults += [PSCustomObject]@{
                        File = $fileResult.FileName
                        Type = $fileResult.Type
                        LineNumber = $match.LineNumber
                        Line = $match.Line
                        Timestamp = if ($match.Line -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})') { $matches[1] } else { '' }
                    }
                }
            }
            $flatResults | ConvertTo-Csv -NoTypeInformation
        }
        
        'HTML' {
            $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Log Search Results - $Pattern</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        .summary { background: #e3f2fd; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .file-result { margin: 20px 0; border-left: 4px solid #0078d4; padding-left: 15px; }
        .file-header { font-weight: bold; color: #0078d4; font-size: 1.1em; margin-bottom: 10px; }
        .match { background: #f9f9f9; padding: 10px; margin: 10px 0; border-radius: 4px; border-left: 3px solid #28a745; }
        .line-number { color: #666; font-size: 0.9em; }
        .match-line { font-family: 'Courier New', monospace; color: #333; }
        .context { color: #999; font-size: 0.9em; margin-left: 20px; }
        .highlight { background: #ffeb3b; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Log Search Results</h1>
        <div class="summary">
            <p><strong>Pattern:</strong> $Pattern</p>
            <p><strong>Total Matches:</strong> $($Results.TotalMatches)</p>
            <p><strong>Files Searched:</strong> $($Results.FilesSearched)</p>
            <p><strong>Files with Matches:</strong> $($Results.FilesWithMatches)</p>
            <p><strong>Search Date:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
"@
            foreach ($fileResult in $Results.FileResults) {
                $html += @"
        <div class="file-result">
            <div class="file-header">📄 $($fileResult.FileName) ($($fileResult.MatchCount) matches)</div>
"@
                foreach ($match in $fileResult.Matches | Select-Object -First 10) {
                    $highlightedLine = $match.Line -replace "($Pattern)", '<span class="highlight">$1</span>'
                    $html += @"
            <div class="match">
                <div class="line-number">Line $($match.LineNumber)</div>
                <div class="match-line">$highlightedLine</div>
            </div>
"@
                }
                $html += @"
        </div>
"@
            }
            
            $html += @"
    </div>
</body>
</html>
"@
            return $html
        }
    }
}

# Main execution
try {
    Write-ScriptLog "Starting comprehensive log search for pattern: $Pattern"
    
    # Get all relevant log files
    $getLogParams = @{
        Type = $LogType
    }
    if ($After) { $getLogParams['After'] = $After }
    if ($Before) { $getLogParams['Before'] = $Before }
    
    $logFiles = Get-AllLogFiles @getLogParams
    
    if ($logFiles.Count -eq 0) {
        Write-Host "`n⚠️  No log files found matching criteria" -ForegroundColor Yellow
        exit 0
    }
    
    Write-ScriptLog "Searching $($logFiles.Count) log files..."
    
    # Search each file
    $allMatches = @()
    $filesWithMatches = 0
    $totalMatches = 0
    
    foreach ($logFile in $logFiles) {
        $matches = Search-LogFile -Path $logFile.FullName -Pattern $Pattern -Regex:$Regex -CaseSensitive:$CaseSensitive -Context $Context -Severity $Severity
        
        if ($matches) {
            $filesWithMatches++
            $matchCount = $matches.Count
            $totalMatches += $matchCount
            
            $allMatches += [PSCustomObject]@{
                FileName = $logFile.Name
                FilePath = $logFile.FullName
                Type = $logFile.Type
                MatchCount = $matchCount
                Matches = $matches | Select-Object -First ([Math]::Min($MaxResults, $matchCount))
            }
        }
        
        if ($totalMatches -ge $MaxResults) {
            break
        }
    }
    
    # Prepare results
    $results = [PSCustomObject]@{
        Pattern = $Pattern
        LogType = $LogType
        FilesSearched = $logFiles.Count
        FilesWithMatches = $filesWithMatches
        TotalMatches = $totalMatches
        SearchTimestamp = Get-Date -Format 'o'
        FileResults = $allMatches
    }
    
    # Output results
    if ($Format -eq 'Text' -and -not $OutputFile) {
        Format-SearchResults -Results $results -Pattern $Pattern -Format 'Text'
    } else {
        $output = Format-SearchResults -Results $results -Pattern $Pattern -Format $Format
        
        if ($OutputFile) {
            $output | Out-File -FilePath $OutputFile -Encoding UTF8
            Write-Host "`n✅ Results saved to: $OutputFile" -ForegroundColor Green
        } else {
            $output
        }
    }
    
    Write-ScriptLog "Search completed: $totalMatches matches found across $filesWithMatches files"
    
} catch {
    Write-ScriptLog "Error during log search: $_" -Level 'Error'
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    exit 1
}
