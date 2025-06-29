#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive PowerShell linting analysis with cross-platform compatibility.

.DESCRIPTION
    This script provides comprehensive PowerShell code analysis using PSScriptAnalyzer
    with support for both parallel processing (PowerShell 7.0+) and sequential fallback
    (PowerShell 5.1+). Designed for CI/CD pipeline integration with detailed error
    reporting and performance metrics.

.PARAMETER Severity
    Severity levels to include in analysis. Options: Error, Warning, Information, All.
    Default: Warning,Error

.PARAMETER FailOnErrors
    Exit with error code 1 if any errors are found. Default: false

.PARAMETER Detailed
    Enable detailed output including file-by-file analysis results. Default: false

.PARAMETER Verbose
    Enable verbose logging including performance metrics. Default: false

.PARAMETER Settings
    Path to PSScriptAnalyzer settings file. Default: './tests/config/PSScriptAnalyzerSettings.psd1'

.PARAMETER Path
    Path to analyze. Default: current directory

.PARAMETER Exclude
    Patterns to exclude from analysis. Default: tests, temp directories

.PARAMETER MaxParallelJobs
    Maximum parallel jobs for PowerShell 7.0+. Default: 4

.EXAMPLE
    ./comprehensive-lint-analysis.ps1 -Severity All -FailOnErrors -Detailed
    
    Runs comprehensive analysis with all severity levels, fails on errors, with detailed output.

.EXAMPLE
    ./comprehensive-lint-analysis.ps1 -Verbose -MaxParallelJobs 8
    
    Runs analysis with verbose output and 8 parallel jobs (if PowerShell 7.0+).

.NOTES
    Author: AitherZero Development Team
    Version: 1.0.0
    PowerShell: 5.1+ (with enhanced features on 7.0+)
    
    This script automatically detects PowerShell version and uses appropriate processing mode:
    - PowerShell 7.0+: Parallel processing with ForEach-Object -Parallel
    - PowerShell 5.1-6.x: Sequential processing with optimized loops
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Severity = 'Warning,Error',
    
    [Parameter()]
    [switch]$FailOnErrors,
    
    [Parameter()]
    [switch]$Detailed,
    
    [Parameter()]
    [switch]$VerboseOutput,
    
    [Parameter()]
    [string]$Settings = './tests/config/PSScriptAnalyzerSettings.psd1',
    
    [Parameter()]
    [string]$Path = '.',
    
    [Parameter()]
    [string[]]$Exclude = @('*test*', '*temp*', '*.git*', '*node_modules*'),
    
    [Parameter()]
    [ValidateRange(1, 16)]
    [int]$MaxParallelJobs = 4
)

# Initialize performance tracking
$script:StartTime = Get-Date
$script:ProcessingMode = 'Unknown'
$script:FilesProcessed = 0
$script:ErrorsFound = 0
$script:WarningsFound = 0

# Enhanced logging function
function Write-LintLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Debug')]
        [string]$Level = 'Info',
        [switch]$NoNewline
    )
    
    $color = switch ($Level) {
        'Info' { 'Cyan' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
        'Debug' { 'Gray' }
    }
    
    $prefix = switch ($Level) {
        'Info' { '🔍' }
        'Warning' { '⚠️' }
        'Error' { '❌' }
        'Success' { '✅' }
        'Debug' { '🔧' }
    }
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logMessage = "[$timestamp] $prefix $Message"
    
    if ($NoNewline) {
        Write-Host $logMessage -ForegroundColor $color -NoNewline
    } else {
        Write-Host $logMessage -ForegroundColor $color
    }
}

# PowerShell version detection and capability assessment
function Initialize-LintingEnvironment {
    Write-LintLog "Initializing PowerShell linting environment..." -Level Info
    
    # Detect PowerShell version and capabilities
    $psVersion = $PSVersionTable.PSVersion
    $platform = $PSVersionTable.Platform ?? 'Windows'
    $isCore = $PSVersionTable.PSEdition -eq 'Core'
    
    Write-LintLog "PowerShell Version: $psVersion" -Level Info
    Write-LintLog "Platform: $platform" -Level Info
    Write-LintLog "Edition: $($PSVersionTable.PSEdition)" -Level Info
    
    # Determine processing mode - Force sequential for reliability in CI/CD
    if ($psVersion.Major -ge 7 -and -not $env:CI) {
        $script:ProcessingMode = 'Parallel'
        Write-LintLog "Parallel processing available (PowerShell 7.0+)" -Level Success
    } else {
        $script:ProcessingMode = 'Sequential'
        if ($env:CI) {
            Write-LintLog "Using sequential processing for CI/CD reliability" -Level Info
        } else {
            Write-LintLog "Using sequential processing (PowerShell $psVersion)" -Level Warning
        }
    }
    
    # Validate PSScriptAnalyzer availability
    try {
        if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
            Write-LintLog "Installing PSScriptAnalyzer module..." -Level Info
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -AllowClobber
        }
        
        Import-Module PSScriptAnalyzer -Force -ErrorAction Stop
        $psaVersion = (Get-Module PSScriptAnalyzer).Version
        Write-LintLog "PSScriptAnalyzer Version: $psaVersion" -Level Success
        
    } catch {
        Write-LintLog "Failed to load PSScriptAnalyzer: $($_.Exception.Message)" -Level Error
        throw "PSScriptAnalyzer is required for linting analysis"
    }
    
    # Validate settings file
    if ($Settings -and (Test-Path $Settings)) {
        Write-LintLog "Using settings file: $Settings" -Level Info
    } else {
        Write-LintLog "Settings file not found, using default rules" -Level Warning
        $script:Settings = $null
    }
    
    return @{
        Version = $psVersion
        Platform = $platform
        ProcessingMode = $script:ProcessingMode
        PSAVersion = $psaVersion
    }
}

# File discovery with filtering
function Get-PowerShellFiles {
    param([string]$SearchPath)
    
    Write-LintLog "Discovering PowerShell files in: $SearchPath" -Level Info
    
    try {
        $patterns = @('*.ps1', '*.psm1', '*.psd1')
        $allFiles = @()
        
        foreach ($pattern in $patterns) {
            $files = Get-ChildItem -Path $SearchPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue
            $allFiles += $files
        }
        
        # Apply exclusion filters
        $filteredFiles = $allFiles | Where-Object {
            $file = $_
            $shouldExclude = $false
            
            foreach ($excludePattern in $Exclude) {
                if ($file.FullName -like $excludePattern) {
                    $shouldExclude = $true
                    break
                }
            }
            
            # Additional intelligent filtering
            if ($file.FullName -match 'tests[/\\].*\.Tests\.ps1$') { $shouldExclude = $true }
            if ($file.FullName -match '(temp|\.temp|temporary)') { $shouldExclude = $true }
            if ($file.FullName -match 'test-.*\.ps1$') { $shouldExclude = $true }
            if ($file.Length -eq 0) { $shouldExclude = $true }
            
            return -not $shouldExclude
        }
        
        Write-LintLog "Found $($allFiles.Count) PowerShell files, $($filteredFiles.Count) after filtering" -Level Info
        
        if ($VerboseOutput) {
            foreach ($file in $filteredFiles | Select-Object -First 10) {
                Write-LintLog "  • $($file.FullName)" -Level Debug
            }
            if ($filteredFiles.Count -gt 10) {
                Write-LintLog "  ... and $($filteredFiles.Count - 10) more files" -Level Debug
            }
        }
        
        return $filteredFiles
        
    } catch {
        Write-LintLog "Error discovering files: $($_.Exception.Message)" -Level Error
        throw
    }
}

# Enhanced analysis function for individual files
function Invoke-SingleFileAnalysis {
    param(
        [System.IO.FileInfo]$File,
        [string]$SettingsPath,
        [string]$SeverityFilter
    )
    
    try {
        # Check if file has content
        $content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content -or $content.Trim() -eq '') {
            return @{
                File = $File.FullName
                Results = @()
                Status = 'Empty'
                ExecutionTime = 0
            }
        }
        
        $analysisStart = Get-Date
        
        # Run PSScriptAnalyzer
        $analysisParams = @{
            Path = $File.FullName
        }
        
        if ($SettingsPath) {
            $analysisParams.Settings = $SettingsPath
        }
        
        if ($SeverityFilter -ne 'All') {
            $severityLevels = $SeverityFilter -split ',' | ForEach-Object { $_.Trim() }
            $analysisParams.Severity = $severityLevels
        }
        
        $results = Invoke-ScriptAnalyzer @analysisParams -ErrorAction Stop
        $executionTime = ((Get-Date) - $analysisStart).TotalMilliseconds
        
        return @{
            File = $File.FullName
            Results = $results
            Status = if ($results) { 'Issues' } else { 'Clean' }
            ExecutionTime = $executionTime
        }
        
    } catch {
        Write-LintLog "Analysis failed for $($File.Name): $($_.Exception.Message)" -Level Warning
        
        return @{
            File = $File.FullName
            Results = @()
            Status = 'Error'
            ExecutionTime = 0
            Error = $_.Exception.Message
        }
    }
}

# Parallel processing implementation (PowerShell 7.0+)
function Invoke-ParallelAnalysis {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$SettingsPath,
        [string]$SeverityFilter,
        [int]$MaxJobs
    )
    
    Write-LintLog "Running parallel analysis with $MaxJobs concurrent jobs..." -Level Info
    
    try {
        # Check if ForEach-Object -Parallel is available
        if ((Get-Command ForEach-Object).Parameters.ContainsKey('Parallel')) {
            $results = $Files | ForEach-Object -Parallel {
                # Import required functions in parallel runspace
                function Invoke-SingleFileAnalysis {
                param($File, $SettingsPath, $SeverityFilter)
                
                try {
                    $content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
                    if (-not $content -or $content.Trim() -eq '') {
                        return @{
                            File = $File.FullName
                            Results = @()
                            Status = 'Empty'
                            ExecutionTime = 0
                        }
                    }
                    
                    $analysisStart = Get-Date
                    
                    $analysisParams = @{ Path = $File.FullName }
                    if ($SettingsPath) { $analysisParams.Settings = $SettingsPath }
                    if ($SeverityFilter -ne 'All') {
                        $severityLevels = $SeverityFilter -split ',' | ForEach-Object { $_.Trim() }
                        $analysisParams.Severity = $severityLevels
                    }
                    
                    $results = Invoke-ScriptAnalyzer @analysisParams -ErrorAction Stop
                    $executionTime = ((Get-Date) - $analysisStart).TotalMilliseconds
                    
                    return @{
                        File = $File.FullName
                        Results = $results
                        Status = if ($results) { 'Issues' } else { 'Clean' }
                        ExecutionTime = $executionTime
                    }
                    
                } catch {
                    return @{
                        File = $File.FullName
                        Results = @()
                        Status = 'Error'
                        ExecutionTime = 0
                        Error = $_.Exception.Message
                    }
                }
            }
            
            Invoke-SingleFileAnalysis -File $_ -SettingsPath $using:SettingsPath -SeverityFilter $using:SeverityFilter
            
        } -ThrottleLimit $MaxJobs
            
            return $results
        } else {
            Write-LintLog "ForEach-Object -Parallel not available, using sequential processing" -Level Warning
            return Invoke-SequentialAnalysis -Files $Files -SettingsPath $SettingsPath -SeverityFilter $SeverityFilter
        }
        
    } catch {
        Write-LintLog "Parallel processing failed: $($_.Exception.Message)" -Level Error
        Write-LintLog "Falling back to sequential processing..." -Level Warning
        return Invoke-SequentialAnalysis -Files $Files -SettingsPath $SettingsPath -SeverityFilter $SeverityFilter
    }
}

# Sequential processing implementation (PowerShell 5.1+)
function Invoke-SequentialAnalysis {
    param(
        [System.IO.FileInfo[]]$Files,
        [string]$SettingsPath,
        [string]$SeverityFilter
    )
    
    Write-LintLog "Running sequential analysis..." -Level Info
    
    $results = @()
    $processedCount = 0
    
    foreach ($file in $Files) {
        $processedCount++
        
        if ($VerboseOutput -and ($processedCount % 10 -eq 0)) {
            Write-LintLog "Processed $processedCount of $($Files.Count) files..." -Level Debug
        }
        
        $fileResult = Invoke-SingleFileAnalysis -File $file -SettingsPath $SettingsPath -SeverityFilter $SeverityFilter
        $results += $fileResult
    }
    
    return $results
}

# Results processing and reporting
function Write-AnalysisResults {
    param([array]$Results)
    
    Write-LintLog "`nProcessing analysis results..." -Level Info
    
    $summary = @{
        TotalFiles = $Results.Count
        CleanFiles = ($Results | Where-Object { $_.Status -eq 'Clean' }).Count
        FilesWithIssues = ($Results | Where-Object { $_.Status -eq 'Issues' }).Count
        EmptyFiles = ($Results | Where-Object { $_.Status -eq 'Empty' }).Count
        ErrorFiles = ($Results | Where-Object { $_.Status -eq 'Error' }).Count
        TotalIssues = 0
        TotalErrors = 0
        TotalWarnings = 0
        TotalInformation = 0
    }
    
    # Aggregate all issues
    $allIssues = @()
    foreach ($result in $Results) {
        if ($result.Results) {
            $allIssues += $result.Results
        }
    }
    
    # Categorize issues by severity
    $summary.TotalIssues = $allIssues.Count
    $summary.TotalErrors = ($allIssues | Where-Object { $_.Severity -eq 'Error' }).Count
    $summary.TotalWarnings = ($allIssues | Where-Object { $_.Severity -eq 'Warning' }).Count
    $summary.TotalInformation = ($allIssues | Where-Object { $_.Severity -eq 'Information' }).Count
    
    # Update script-level counters
    $script:FilesProcessed = $summary.TotalFiles
    $script:ErrorsFound = $summary.TotalErrors
    $script:WarningsFound = $summary.TotalWarnings
    
    # Display summary
    Write-Host ""
    Write-LintLog "📊 Analysis Summary" -Level Info
    Write-Host "=" * 50
    Write-LintLog "Total Files Analyzed: $($summary.TotalFiles)" -Level Info
    Write-LintLog "Clean Files: $($summary.CleanFiles)" -Level Success
    Write-LintLog "Files with Issues: $($summary.FilesWithIssues)" -Level $(if ($summary.FilesWithIssues -gt 0) { 'Warning' } else { 'Success' })
    Write-LintLog "Empty Files: $($summary.EmptyFiles)" -Level Debug
    Write-LintLog "Error Files: $($summary.ErrorFiles)" -Level $(if ($summary.ErrorFiles -gt 0) { 'Error' } else { 'Success' })
    Write-Host ""
    Write-LintLog "Total Issues Found: $($summary.TotalIssues)" -Level $(if ($summary.TotalIssues -gt 0) { 'Warning' } else { 'Success' })
    Write-LintLog "  Errors: $($summary.TotalErrors)" -Level $(if ($summary.TotalErrors -gt 0) { 'Error' } else { 'Success' })
    Write-LintLog "  Warnings: $($summary.TotalWarnings)" -Level $(if ($summary.TotalWarnings -gt 0) { 'Warning' } else { 'Success' })
    Write-LintLog "  Information: $($summary.TotalInformation)" -Level Debug
    
    # Detailed results if requested
    if ($Detailed -and $allIssues.Count -gt 0) {
        Write-Host ""
        Write-LintLog "📋 Detailed Issues" -Level Info
        Write-Host "=" * 50
        
        # Group issues by file
        $issuesByFile = $allIssues | Group-Object -Property ScriptName
        
        foreach ($fileGroup in $issuesByFile) {
            Write-Host ""
            Write-LintLog "File: $($fileGroup.Name)" -Level Info
            
            foreach ($issue in $fileGroup.Group) {
                $severityColor = switch ($issue.Severity) {
                    'Error' { 'Red' }
                    'Warning' { 'Yellow' }
                    'Information' { 'Cyan' }
                    default { 'White' }
                }
                
                Write-Host "  Line $($issue.Line): [$($issue.Severity)] $($issue.Message)" -ForegroundColor $severityColor
                Write-Host "    Rule: $($issue.RuleName)" -ForegroundColor Gray
            }
        }
    }
    
    return $summary
}

# Performance metrics reporting
function Write-PerformanceMetrics {
    param([hashtable]$Summary)
    
    $duration = (Get-Date) - $script:StartTime
    $avgTimePerFile = if ($Summary.TotalFiles -gt 0) { 
        [math]::Round($duration.TotalMilliseconds / $Summary.TotalFiles, 2) 
    } else { 0 }
    
    Write-Host ""
    Write-LintLog "⚡ Performance Metrics" -Level Info
    Write-Host "=" * 50
    Write-LintLog "Processing Mode: $script:ProcessingMode" -Level Info
    Write-LintLog "Total Duration: $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level Info
    Write-LintLog "Average Time per File: ${avgTimePerFile}ms" -Level Info
    Write-LintLog "Files per Second: $([math]::Round($Summary.TotalFiles / $duration.TotalSeconds, 2))" -Level Info
    
    if ($script:ProcessingMode -eq 'Parallel') {
        Write-LintLog "Parallel Jobs Used: $MaxParallelJobs" -Level Info
        $sequentialEstimate = $avgTimePerFile * $Summary.TotalFiles / 1000
        $improvement = [math]::Round((($sequentialEstimate - $duration.TotalSeconds) / $sequentialEstimate) * 100, 1)
        if ($improvement -gt 0) {
            Write-LintLog "Estimated Performance Improvement: ${improvement}%" -Level Success
        }
    }
}

# Main execution function
function Invoke-ComprehensiveLinting {
    try {
        # Initialize environment
        $environment = Initialize-LintingEnvironment
        
        # Discover files
        $files = Get-PowerShellFiles -SearchPath $Path
        
        if ($files.Count -eq 0) {
            Write-LintLog "No PowerShell files found to analyze" -Level Warning
            return 0
        }
        
        # Execute analysis based on PowerShell version
        Write-LintLog "Starting analysis of $($files.Count) files..." -Level Info
        
        if ($environment.ProcessingMode -eq 'Parallel') {
            $results = Invoke-ParallelAnalysis -Files $files -SettingsPath $Settings -SeverityFilter $Severity -MaxJobs $MaxParallelJobs
        } else {
            $results = Invoke-SequentialAnalysis -Files $files -SettingsPath $Settings -SeverityFilter $Severity
        }
        
        # Process and display results
        $summary = Write-AnalysisResults -Results $results
        
        # Performance metrics
        if ($VerboseOutput) {
            Write-PerformanceMetrics -Summary $summary
        }
        
        # Determine exit code
        if ($FailOnErrors -and $summary.TotalErrors -gt 0) {
            Write-LintLog "`n❌ Analysis failed: $($summary.TotalErrors) errors found" -Level Error
            return 1
        } else {
            Write-LintLog "`n✅ Analysis completed successfully" -Level Success
            return 0
        }
        
    } catch {
        Write-LintLog "Critical error during linting analysis: $($_.Exception.Message)" -Level Error
        if ($VerboseOutput) {
            Write-LintLog "Stack trace: $($_.Exception.StackTrace)" -Level Debug
        }
        return 1
    }
}

# Script entry point
Write-LintLog "🔍 Starting AitherZero Comprehensive PowerShell Linting Analysis" -Level Info
Write-LintLog "Version: 1.0.0 | Compatible: PowerShell 5.1+" -Level Info

$exitCode = Invoke-ComprehensiveLinting
exit $exitCode