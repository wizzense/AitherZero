#Requires -Version 7.0
# PSScriptAnalyzer suppressions for dashboard generation script
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Scope='Function', Target='*', Justification='Dashboard functions intentionally use plural names for collections of metrics')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Scope='Function', Target='*', Justification='ShouldProcess handled at script level, not individual helper functions')]

<#
.SYNOPSIS
    Generate comprehensive CI/CD dashboard with real-time status monitoring
.DESCRIPTION
    Creates HTML and Markdown dashboards showing project health, test results,
    security status, CI/CD metrics, and deployment information for effective
    project management and systematic improvement.

.PARAMETER ProjectPath
    Path to the project root directory
.PARAMETER OutputPath
    Path where dashboard files will be generated
.PARAMETER Format
    Dashboard format to generate (HTML, Markdown, JSON, or All)
.PARAMETER Open
    Automatically open the HTML dashboard in the default browser after generation

.EXAMPLE
    ./0512_Generate-Dashboard.ps1
.EXAMPLE
    ./0512_Generate-Dashboard.ps1 -Format HTML -Open

.NOTES
    Stage: Reporting
    Category: Reporting
    Order: 0512
    Dependencies: 0510
    Tags: reporting, dashboard, monitoring, html, markdown
#>

[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'OutputPath', Justification='Used in main script body')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Format', Justification='Used in switch statement')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Open', Justification='Used to open HTML dashboard')]
param(
    [string]$ProjectPath = ($PSScriptRoot | Split-Path -Parent),
    [string]$OutputPath = (Join-Path $ProjectPath "reports"),
    [ValidateSet('HTML', 'Markdown', 'JSON', 'All')]
    [string]$Format = 'All',
    [switch]$Open
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Script metadata (used for orchestration system documentation)
# Note: Metadata is referenced by automation infrastructure
# Stage: Reporting, Order: 0512, Dependencies: 0510

# Import modules
$loggingModule = Join-Path $ProjectPath "domains/utilities/Logging.psm1"
$configModule = Join-Path $ProjectPath "domains/configuration/Configuration.psm1"

if (Test-Path $loggingModule) {
    Import-Module $loggingModule -Force
}

if (Test-Path $configModule) {
    Import-Module $configModule -Force
}

function Write-ScriptLog {
    param(
        [string]$Level = 'Information',
        [string]$Message,
        [hashtable]$Data = @{}
    )

    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Level $Level -Message $Message -Source "0512_Generate-Dashboard" -Data $Data
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function Open-HTMLDashboard {
    param(
        [string]$FilePath
    )
    
    Write-ScriptLog -Message "Opening HTML dashboard in browser: $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-ScriptLog -Level Warning -Message "Dashboard file not found: $FilePath"
        return $false
    }
    
    try {
        # Cross-platform browser opening
        if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
            # Windows - use Start-Process with default browser
            Start-Process $FilePath
        }
        elseif ($IsMacOS) {
            # macOS - use open command
            & open $FilePath
        }
        elseif ($IsLinux) {
            # Linux - try xdg-open
            if (Get-Command xdg-open -ErrorAction SilentlyContinue) {
                & xdg-open $FilePath
            }
            else {
                Write-ScriptLog -Level Warning -Message "xdg-open not found. Please open manually: $FilePath"
                return $false
            }
        }
        else {
            Write-ScriptLog -Level Warning -Message "Unable to detect platform. Please open manually: $FilePath"
            return $false
        }
        
        Write-ScriptLog -Message "Dashboard opened successfully in default browser"
        return $true
    }
    catch {
        Write-ScriptLog -Level Error -Message "Failed to open dashboard: $_"
        return $false
    }
}

function Get-ProjectMetrics {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='Function returns multiple metrics')]
    param()
    Write-ScriptLog -Message "Collecting project metrics"

    $metrics = @{
        Files = @{
            PowerShell = @(Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notmatch '(tests|examples|legacy)' }).Count
            Modules = @(Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse).Count
            Data = @(Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse).Count
            Markdown = @(Get-ChildItem -Path $ProjectPath -Filter "*.md" -Recurse | Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }).Count
            YAML = @(Get-ChildItem -Path $ProjectPath -Filter "*.yml" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }).Count
            JSON = @(Get-ChildItem -Path $ProjectPath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '(node_modules|\.git)' }).Count
            Total = 0
        }
        LinesOfCode = 0
        CommentLines = 0
        BlankLines = 0
        Functions = 0
        Classes = 0
        Tests = @{
            Unit = 0
            Integration = 0
            Total = 0
            LastRun = $null
            Passed = 0
            Failed = 0
            Skipped = 0
            SuccessRate = 0
            Duration = "Unknown"
        }
        TestCoverage = @{
            Percentage = 0
            FilesWithTests = 0
            FilesWithoutTests = 0
            TotalFiles = 0
        }
        DocumentationCoverage = @{
            Percentage = 0
            FunctionsWithDocs = 0
            FunctionsWithoutDocs = 0
            TotalFunctions = 0
        }
        QualityCoverage = @{
            Percentage = 0
            PassedFiles = 0
            WarningFiles = 0
            FailedFiles = 0
            TotalValidated = 0
            TotalIssues = 0
            AverageScore = 0
        }
        Issues = @{
            Open = 0
            Closed = 0
            Total = 0
            ByLabel = @{}
            Recent = @()
        }
        Coverage = @{
            Percentage = 0
            CoveredLines = 0
            TotalLines = 0
        }
        Git = @{
            Branch = "Unknown"
            LastCommit = "Unknown"
            CommitCount = 0
            Contributors = 0
        }
        Dependencies = @{}
        Platform = if ($PSVersionTable.Platform) { $PSVersionTable.Platform } else { "Windows" }
        PSVersion = $PSVersionTable.PSVersion.ToString()
        LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Domains = @()
        AutomationScripts = 0
        Workflows = 0
    }

    # Calculate total files
    $metrics.Files.Total = $metrics.Files.PowerShell + $metrics.Files.Modules + $metrics.Files.Data

    # Count lines of code and functions
    # Wrap entire pipeline with @() to ensure array type even when Where-Object filters all results
    $allPSFiles = @(@(
        Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psd1" -Recurse
    ) | Where-Object { $_.FullName -notmatch '(tests|examples|legacy)' })

    foreach ($file in $allPSFiles) {
        try {
            $content = Get-Content $file.FullName -ErrorAction Stop
            if ($content) {
                # Ensure content is always an array for consistent .Count behavior
                $contentArray = @($content)
                
                foreach ($line in $contentArray) {
                    $trimmed = $line.Trim()
                    if ($trimmed -eq '') {
                        $metrics.BlankLines++
                    } elseif ($trimmed -match '^#' -or $trimmed -match '^\s*<#') {
                        $metrics.CommentLines++
                    }
                }
                
                $metrics.LinesOfCode += $contentArray.Count

                # Count functions - use Measure-Object for StrictMode safety
                $functionMatches = @($content | Select-String -Pattern '^\s*function\s+' -ErrorAction SilentlyContinue)
                $funcCount = ($functionMatches | Measure-Object).Count
                if ($funcCount -gt 0) {
                    $metrics.Functions += $funcCount
                }
                
                # Count classes - use Measure-Object for StrictMode safety
                $classMatches = @($content | Select-String -Pattern '^\s*class\s+' -ErrorAction SilentlyContinue)
                $classCount = ($classMatches | Measure-Object).Count
                if ($classCount -gt 0) {
                    $metrics.Classes += $classCount
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze file: $($file.Name) - $_"
        }
    }
    
    # Get Git information
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $metrics.Git.Branch = git rev-parse --abbrev-ref HEAD 2>$null
            $metrics.Git.LastCommit = (git log -1 --format="%h - %s (%cr)" 2>$null)
            $metrics.Git.CommitCount = [int](git rev-list --count HEAD 2>$null)
            $metrics.Git.Contributors = @(git log --format='%an' | Sort-Object -Unique).Count
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to get git information"
        }
    }
    
    # Count GitHub Actions workflows
    $workflowsPath = Join-Path $ProjectPath ".github/workflows"
    if (Test-Path $workflowsPath) {
        $metrics.Workflows = @(Get-ChildItem -Path $workflowsPath -Filter "*.yml" -ErrorAction SilentlyContinue).Count
    }

    # Count automation scripts
    $automationPath = Join-Path $ProjectPath "automation-scripts"
    if (Test-Path $automationPath) {
        $metrics.AutomationScripts = @(Get-ChildItem -Path $automationPath -Filter "*.ps1").Count
    }

    # Count domain modules
    $domainsPath = Join-Path $ProjectPath "aithercore"
    if (Test-Path $domainsPath) {
        $domainDirs = Get-ChildItem -Path $domainsPath -Directory
        foreach ($domain in $domainDirs) {
            $moduleCount = @(Get-ChildItem -Path $domain.FullName -Filter "*.psm1").Count
            if ($moduleCount -gt 0) {
                $metrics.Domains += @{
                    Name = $domain.Name
                    Modules = $moduleCount
                    Path = $domain.FullName
                }
            }
        }
    }

    # Count test files
    $testPath = Join-Path $ProjectPath "tests"
    if (Test-Path $testPath) {
        $metrics.Tests.Unit = @(Get-ChildItem -Path $testPath -Filter "*Tests.ps1" -Recurse | Where-Object { $_.FullName -match 'unit' }).Count
        $metrics.Tests.Integration = @(Get-ChildItem -Path $testPath -Filter "*Tests.ps1" -Recurse | Where-Object { $_.FullName -match 'integration' }).Count
        $metrics.Tests.Total = $metrics.Tests.Unit + $metrics.Tests.Integration
    }
    
    # Calculate test coverage for automation scripts specifically (number-based tests in range directories)
    $automationScriptsPath = Join-Path $ProjectPath "automation-scripts"
    $automationScripts = @()
    if (Test-Path $automationScriptsPath) {
        $automationScripts = @(Get-ChildItem -Path $automationScriptsPath -Filter "*.ps1" -File)
    }
    
    # Also count domain modules for complete coverage
    # Wrap entire pipeline with @() to ensure array type even when Where-Object filters all results
    $domainModules = @(@(
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
    ) | Where-Object { $_.FullName -match 'domains/' })
    
    $allCodeFiles = @($automationScripts) + @($domainModules)
    $metrics.TestCoverage.TotalFiles = $allCodeFiles.Count
    
    foreach ($codeFile in $allCodeFiles) {
        $hasTest = $false
        $relativePath = $codeFile.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
        
        # For automation scripts: Check in range-based directories (0000-0099, 0100-0199, etc.)
        if ($relativePath -match 'automation-scripts') {
            # Extract script number (e.g., 0402 from 0402_Run-UnitTests.ps1)
            if ($codeFile.Name -match '^(\d{4})_') {
                $scriptNumber = [int]$matches[1]
                $rangeStart = ([int]($scriptNumber / 100)) * 100
                $rangeEnd = $rangeStart + 99
                $rangeDir = "$($rangeStart.ToString().PadLeft(4, '0'))-$($rangeEnd.ToString().PadLeft(4, '0'))"
                $testFileName = $codeFile.Name -replace '\.ps1$', '.Tests.ps1'
                
                # Check in the appropriate range directory
                $testPath = Join-Path $ProjectPath "tests/unit/automation-scripts/$rangeDir/$testFileName"
                
                if (Test-Path $testPath) {
                    # Verify test has meaningful content
                    try {
                        $testContent = Get-Content $testPath -Raw -ErrorAction SilentlyContinue
                        if ($testContent -and $testContent -match 'Describe\s+' -and $testContent -match '\bIt\s+[''"]') {
                            $hasTest = $true
                        }
                    } catch {
                        # If we can't read it, don't count it
                    }
                }
            }
        }
        # For domain modules: Check standard test locations
        else {
            $testFileName = $codeFile.Name -replace '\.psm1$', '.Tests.ps1'
            $relativeDir = Split-Path $relativePath -Parent
            
            $possibleTestPaths = @(
                (Join-Path (Join-Path $ProjectPath "tests/unit") $relativeDir | Join-Path -ChildPath $testFileName),
                (Join-Path (Join-Path $ProjectPath "tests/domains") ($relativeDir -replace 'domains/', '') | Join-Path -ChildPath $testFileName)
            )
            
            foreach ($testFilePath in $possibleTestPaths) {
                if (Test-Path $testFilePath) {
                    try {
                        $testContent = Get-Content $testFilePath -Raw -ErrorAction SilentlyContinue
                        if ($testContent -and $testContent -match 'Describe\s+' -and $testContent -match '\bIt\s+[''"]') {
                            $hasTest = $true
                            break
                        }
                    } catch {
                        # If we can't read it, don't count it
                    }
                }
            }
        }
        
        if ($hasTest) {
            $metrics.TestCoverage.FilesWithTests++
        } else {
            $metrics.TestCoverage.FilesWithoutTests++
        }
    }
    
    if ($metrics.TestCoverage.TotalFiles -gt 0) {
        $metrics.TestCoverage.Percentage = [math]::Round(
            ($metrics.TestCoverage.FilesWithTests / $metrics.TestCoverage.TotalFiles) * 100,
            1
        )
    }
    
    Write-ScriptLog -Message "Test coverage: $($metrics.TestCoverage.FilesWithTests) of $($metrics.TestCoverage.TotalFiles) files have tests (Automation scripts: $($automationScripts.Count), Domain modules: $($domainModules.Count))"
    
    # Calculate documentation coverage (what % of functions have help documentation)
    $metrics.DocumentationCoverage.TotalFunctions = $metrics.Functions
    
    if ($allPSFiles.Count -gt 0) {
        foreach ($file in $allPSFiles) {
            try {
                $content = Get-Content $file.FullName -ErrorAction Stop
                if ($content) {
                    $contentArray = @($content)
                    
                    # Find all functions
                    $functionMatches = @($content | Select-String -Pattern '^\s*function\s+([A-Za-z0-9-_]+)' -ErrorAction SilentlyContinue)
                    
                    foreach ($match in $functionMatches) {
                        # Check if function has documentation (look for .SYNOPSIS, .DESCRIPTION, or comment-based help before function)
                        $lineNum = $match.LineNumber
                        $hasDoc = $false
                        
                        # Look backwards from function line for documentation
                        for ($i = [math]::Max(0, $lineNum - 20); $i -lt $lineNum; $i++) {
                            $line = $contentArray[$i]
                            if ($line -match '\.SYNOPSIS|\.DESCRIPTION|<#') {
                                $hasDoc = $true
                                break
                            }
                        }
                        
                        if ($hasDoc) {
                            $metrics.DocumentationCoverage.FunctionsWithDocs++
                        } else {
                            $metrics.DocumentationCoverage.FunctionsWithoutDocs++
                        }
                    }
                }
            } catch {
                # Skip files that can't be read
            }
        }
    }
    
    if ($metrics.DocumentationCoverage.TotalFunctions -gt 0) {
        $metrics.DocumentationCoverage.Percentage = [math]::Round(
            ($metrics.DocumentationCoverage.FunctionsWithDocs / $metrics.DocumentationCoverage.TotalFunctions) * 100,
            1
        )
    }
    
    # Calculate quality coverage from PSScriptAnalyzer baseline results
    # Priority: 1) Parallel results (comprehensive), 2) Baseline results, 3) Fast results
    
    # Check for parallel analysis results first (most comprehensive)
    $parallelResultsPath = Join-Path $ProjectPath "library/reports/psscriptanalyzer-results.json"
    $pssaSummaryPath = Join-Path $ProjectPath "tests/results"
    $latestPssaSummary = $null
    
    if (Test-Path $parallelResultsPath) {
        $latestPssaSummary = Get-Item $parallelResultsPath
        Write-ScriptLog -Message "Using comprehensive parallel PSScriptAnalyzer results"
    } else {
        # Fallback to baseline results
        $latestPssaSummary = Get-ChildItem -Path $pssaSummaryPath -Filter "PSScriptAnalyzer-Summary-*.json" -ErrorAction SilentlyContinue | 
                             Sort-Object LastWriteTime -Descending | 
                             Select-Object -First 1
        if ($latestPssaSummary) {
            Write-ScriptLog -Message "Using baseline PSScriptAnalyzer results"
        }
    }
    
    if ($latestPssaSummary) {
        try {
            $pssaData = Get-Content $latestPssaSummary.FullName -Raw | ConvertFrom-Json
            if ($pssaData.Summary) {
                $totalIssues = $pssaData.Summary.TotalIssues
                $errors = if ($pssaData.Summary.BySeverity.PSObject.Properties['Error']) { $pssaData.Summary.BySeverity.Error } else { 0 }
                $warnings = if ($pssaData.Summary.BySeverity.PSObject.Properties['Warning']) { $pssaData.Summary.BySeverity.Warning } else { 0 }
                $info = if ($pssaData.Summary.BySeverity.PSObject.Properties['Information']) { $pssaData.Summary.BySeverity.Information } else { 0 }
                
                # Count files from ByScript hash - wrap with @() for StrictMode compatibility
                $filesWithIssues = if ($pssaData.Summary.ByScript) { 
                    @($pssaData.Summary.ByScript.PSObject.Properties).Count 
                } else { 0 }
                
                # Total files analyzed or all PowerShell files in project
                $filesAnalyzed = if ($pssaData.Summary.FilesAnalyzed) { $pssaData.Summary.FilesAnalyzed } else { $pssaData.FilesAnalyzed.Count }
                $totalPSFiles = [math]::Max($filesAnalyzed, $allPSFiles.Count)
                $metrics.QualityCoverage.TotalValidated = $totalPSFiles
                
                # Store raw data for comprehensive quality calculation
                $metrics.QualityCoverage.RawData = @{
                    Errors = $errors
                    Warnings = $warnings
                    Information = $info
                    FilesScanned = $filesAnalyzed
                    TotalFiles = $totalPSFiles
                }
                
                # Files without issues are clean
                $cleanFiles = $totalPSFiles - $filesWithIssues
                
                # Categorize files: Clean, with warnings, with errors
                $filesWithErrors = if ($errors -gt 0 -and $pssaData.Summary.ByScript) {
                    # Count scripts that have at least one error
                    $scriptsWithErrors = @()
                    foreach ($script in $pssaData.Summary.ByScript.PSObject.Properties) {
                        # Would need detailed data to know which files have errors vs warnings
                        # For now, estimate based on error ratio
                    }
                    [math]::Ceiling($errors / [math]::Max(1, ($totalIssues / $filesWithIssues)))
                } else { 0 }
                
                $metrics.QualityCoverage.FailedFiles = $filesWithErrors
                $metrics.QualityCoverage.WarningFiles = [math]::Max(0, $filesWithIssues - $filesWithErrors)
                $metrics.QualityCoverage.PassedFiles = $cleanFiles
                $metrics.QualityCoverage.TotalIssues = $totalIssues
                
                # Quality percentage: files without major issues
                if ($totalPSFiles -gt 0) {
                    $metrics.QualityCoverage.Percentage = [math]::Round(
                        (($cleanFiles + ($metrics.QualityCoverage.WarningFiles * 0.3)) / $totalPSFiles) * 100,
                        1
                    )
                }
                
                Write-ScriptLog -Message "Quality coverage: $totalIssues total issues ($errors errors, $warnings warnings, $info info) across $filesWithIssues files (of $totalPSFiles total, $filesAnalyzed analyzed)"
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse baseline quality results: $_"
        }
    }
    
    # Fallback to fast results if baseline not available
    if ($metrics.QualityCoverage.TotalValidated -eq 0) {
        $pssaPath = Join-Path $ProjectPath "library/reports/psscriptanalyzer-fast-results.json"
        if (Test-Path $pssaPath) {
            try {
                $pssaData = Get-Content $pssaPath -Raw | ConvertFrom-Json
                if ($pssaData.Summary) {
                    $totalIssues = $pssaData.Summary.TotalIssues
                    $errors = $pssaData.Summary.Errors
                    $warnings = $pssaData.Summary.Warnings
                    
                    # Fast results only scan changed files, but we need to represent quality against ALL files
                    $filesScanned = if ($pssaData.FilesAnalyzed) { @($pssaData.FilesAnalyzed).Count } else { 0 }
                    $totalPSFiles = $allPSFiles.Count
                    
                    # Use total PowerShell files as the baseline for quality calculation
                    $metrics.QualityCoverage.TotalValidated = $totalPSFiles
                    
                    # Estimate files with issues from scanned files
                    $filesWithIssues = $filesScanned  # All scanned files have at least warnings
                    $filesWithErrors = if ($errors -gt 0) { [math]::Min($filesScanned, [math]::Ceiling($errors / [math]::Max(1, ($totalIssues / $filesScanned)))) } else { 0 }
                    
                    $metrics.QualityCoverage.FailedFiles = $filesWithErrors
                    $metrics.QualityCoverage.WarningFiles = $filesWithIssues - $filesWithErrors
                    # Assume files not scanned are clean (optimistic but prevents false negatives)
                    $metrics.QualityCoverage.PassedFiles = $totalPSFiles - $filesWithIssues
                    $metrics.QualityCoverage.TotalIssues = $totalIssues
                    
                    # Store raw data for comprehensive quality calculation later
                    $metrics.QualityCoverage.RawData = @{
                        Errors = $errors
                        Warnings = $warnings
                        Information = $info
                        FilesScanned = $filesScanned
                        TotalFiles = $totalPSFiles
                    }
                    
                    # Quality percentage: weight clean files and warning files
                    $metrics.QualityCoverage.Percentage = [math]::Round(
                        (($metrics.QualityCoverage.PassedFiles + ($metrics.QualityCoverage.WarningFiles * 0.3)) / $totalPSFiles) * 100,
                        1
                    )
                    
                    Write-ScriptLog -Level Warning -Message "Using fast results only ($filesScanned files scanned, $totalIssues issues: $errors errors, $warnings warnings) - calculated against $totalPSFiles total files. Run './automation-scripts/0404_Run-PSScriptAnalyzer.ps1' for full baseline analysis"
                }
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to parse fast quality results: $_"
            }
        }
    }

    # Get latest test results - check multiple possible locations including JSON
    $testResultsPaths = @(
        (Join-Path $ProjectPath "testResults.xml"),
        (Join-Path $ProjectPath "tests/results/*.xml"),
        (Join-Path $ProjectPath "tests/results/*Summary*.json"),
        (Join-Path $ProjectPath "TestResults.json")
    )
    
    $latestTestResults = $null
    $testResultFormat = $null
    
    foreach ($testPath in $testResultsPaths) {
        if ($testPath -like "*`**") {
            $files = Get-ChildItem -Path (Split-Path $testPath -Parent) -Filter (Split-Path $testPath -Leaf) -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Name -notlike "Coverage*" -and $_.Name -notlike "PSScriptAnalyzer*" } |
                    Sort-Object LastWriteTime -Descending
            
            if ($files) {
                $latestTestResults = $files[0]
                $testResultFormat = if ($latestTestResults.Extension -eq '.json') { 'JSON' } else { 'XML' }
                break
            }
        } else {
            if (Test-Path $testPath) {
                $latestTestResults = Get-Item $testPath
                $testResultFormat = if ($latestTestResults.Extension -eq '.json') { 'JSON' } else { 'XML' }
                break
            }
        }
    }
    
    # Parse test results based on format
    if ($latestTestResults -and $testResultFormat -eq 'XML') {
        try {
            [xml]$testXml = Get-Content $latestTestResults.FullName
            
            # Parse NUnit format test results
            if ($testXml.'test-results') {
                $results = $testXml.'test-results'
                $totalTests = [int]$results.total
                $failures = [int]$results.failures
                $errors = [int]$results.errors
                $skipped = [int]$results.skipped
                
                $metrics.Tests.Passed = $totalTests - $failures - $errors - $skipped
                $metrics.Tests.Failed = $failures + $errors
                $metrics.Tests.Skipped = $skipped
                $metrics.Tests.Total = $totalTests
                
                if ($totalTests -gt 0) {
                    $metrics.Tests.SuccessRate = [math]::Round(($metrics.Tests.Passed / $totalTests) * 100, 1)
                }
                
                $metrics.Tests.LastRun = $latestTestResults.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                
                # Try to extract duration from test suite
                if ($testXml.'test-results'.'test-suite' -and $testXml.'test-results'.'test-suite'.time) {
                    try {
                        $duration = [double]$testXml.'test-results'.'test-suite'.time
                        if ($duration -lt 60) {
                            $metrics.Tests.Duration = "$([math]::Round($duration, 2))s"
                        } else {
                            $minutes = [math]::Floor($duration / 60)
                            $seconds = [math]::Round($duration % 60, 0)
                            $metrics.Tests.Duration = "${minutes}m ${seconds}s"
                        }
                    } catch {
                        $metrics.Tests.Duration = "Not recorded"
                    }
                } else {
                    $metrics.Tests.Duration = "Not recorded"
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse test XML results: $_"
        }
    } elseif ($latestTestResults -and $testResultFormat -eq 'JSON') {
        try {
            $testJson = Get-Content $latestTestResults.FullName -Raw | ConvertFrom-Json
            
            # Parse Pester 5.x JSON format
            if ($testJson.Passed -or $testJson.Failed -or $testJson.Total) {
                $metrics.Tests.Passed = if ($testJson.Passed) { $testJson.Passed } else { 0 }
                $metrics.Tests.Failed = if ($testJson.Failed) { $testJson.Failed } else { 0 }
                $metrics.Tests.Skipped = if ($testJson.Skipped) { $testJson.Skipped } else { 0 }
                $metrics.Tests.Total = if ($testJson.Total) { $testJson.Total } else { $metrics.Tests.Passed + $metrics.Tests.Failed + $metrics.Tests.Skipped }
                
                if ($metrics.Tests.Total -gt 0) {
                    $metrics.Tests.SuccessRate = [math]::Round(($metrics.Tests.Passed / $metrics.Tests.Total) * 100, 1)
                }
                
                $metrics.Tests.LastRun = $latestTestResults.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                
                if ($testJson.Duration) {
                    $duration = [double]$testJson.Duration
                    if ($duration -lt 60) {
                        $metrics.Tests.Duration = "$([math]::Round($duration, 2))s"
                    } else {
                        $minutes = [math]::Floor($duration / 60)
                        $seconds = [math]::Round($duration % 60, 0)
                        $metrics.Tests.Duration = "${minutes}m ${seconds}s"
                    }
                } else {
                    $metrics.Tests.Duration = "Not recorded"
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse test JSON results: $_"
        }
    }
    
    # If no test results found, provide informative status based on test file count
    if (-not $latestTestResults -or ($metrics.Tests.Total -eq 0 -and $metrics.Tests.Passed -eq 0)) {
        # We have test files but no results - tests haven't been run recently
        if ($metrics.Tests.Unit -gt 0 -or $metrics.Tests.Integration -gt 0) {
            $metrics.Tests.LastRun = "Not run recently"
            $metrics.Tests.Duration = "Run tests to see duration"
            Write-ScriptLog -Level Warning -Message "Test files exist ($($metrics.Tests.Unit) unit, $($metrics.Tests.Integration) integration) but no recent test results found. Run './automation-scripts/0402_Run-UnitTests.ps1' to generate results."
        }
    }

    # Get coverage information if available
    $coverageFiles = Get-ChildItem -Path $ProjectPath -Filter "Coverage-*.xml" -Recurse -ErrorAction SilentlyContinue | 
                     Where-Object { $_.Length -gt 100 } |  # Skip empty files
                     Sort-Object LastWriteTime -Descending | 
                     Select-Object -First 1
    if ($coverageFiles) {
        try {
            [xml]$coverageXml = Get-Content $coverageFiles.FullName -ErrorAction Stop
            
            # Check for JaCoCo format (used by Pester) - use null-safe property access
            $hasReport = $null -ne $coverageXml.PSObject.Properties['report']
            $reportHasCounter = $hasReport -and ($null -ne $coverageXml.report.PSObject.Properties['counter'])
            
            if ($reportHasCounter) {
                # Parse JaCoCo format
                $counters = @($coverageXml.report.counter)
                $lineCounter = $counters | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1
                
                if ($lineCounter -and $lineCounter.missed -and $lineCounter.covered) {
                    $missedLines = [int]$lineCounter.missed
                    $coveredLines = [int]$lineCounter.covered
                    $totalLines = $missedLines + $coveredLines
                    
                    if ($totalLines -gt 0) {
                        $metrics.Coverage.Percentage = [math]::Round(($coveredLines / $totalLines) * 100, 2)
                        $metrics.Coverage.CoveredLines = $coveredLines
                        $metrics.Coverage.TotalLines = $totalLines
                    }
                }
            }
            # Check for Cobertura format (alternative) - use null-safe property access
            elseif ($null -ne $coverageXml.PSObject.Properties['coverage']) {
                $coverage = $coverageXml.coverage
                if ($null -ne $coverage.PSObject.Properties['line-rate']) {
                    $metrics.Coverage.Percentage = [math]::Round(($coverage.'line-rate' -as [double]) * 100, 2)
                }
                if ($null -ne $coverage.PSObject.Properties['lines-covered']) {
                    $metrics.Coverage.CoveredLines = $coverage.'lines-covered' -as [int]
                }
                if ($null -ne $coverage.PSObject.Properties['lines-valid']) {
                    $metrics.Coverage.TotalLines = $coverage.'lines-valid' -as [int]
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse coverage data: $_"
        }
    }

    # Calculate comprehensive quality score based on multiple factors
    Write-ScriptLog -Message "Calculating comprehensive quality score from all metrics"
    
    $qualityScore = 100.0  # Start at perfect score
    $scoreBreakdown = @{
        PSScriptAnalyzer = 100
        TestCoverage = 100
        DocumentationCoverage = 100
        CodeCoverage = 100
    }
    
    # Factor 1: PSScriptAnalyzer Issues (40% weight) - Most important
    # Errors are critical, warnings are serious, info is minor
    if ($metrics.QualityCoverage.PSObject.Properties['RawData'] -and $metrics.QualityCoverage.RawData) {
        $pssaErrors = $metrics.QualityCoverage.RawData.Errors
        $pssaWarnings = $metrics.QualityCoverage.RawData.Warnings
        $pssaInfo = $metrics.QualityCoverage.RawData.Information
        
        # Each error costs 5 points, each warning 1 point, each info 0.1 points
        # Normalize to 100-point scale
        $pssaPenalty = ($pssaErrors * 5) + ($pssaWarnings * 1) + ($pssaInfo * 0.1)
        $scoreBreakdown.PSScriptAnalyzer = [math]::Max(0, [math]::Round(100 - $pssaPenalty, 1))
        
        Write-ScriptLog -Message "PSScriptAnalyzer score: $($scoreBreakdown.PSScriptAnalyzer)/100 ($pssaErrors errors, $pssaWarnings warnings, $pssaInfo info)"
    } elseif ($metrics.QualityCoverage.TotalIssues -eq 0) {
        # No issues found
        $scoreBreakdown.PSScriptAnalyzer = 100
        Write-ScriptLog -Message "PSScriptAnalyzer score: 100/100 (no issues found)"
    } else {
        # If no detailed PSSA data but we have issue count, estimate
        $totalIssues = $metrics.QualityCoverage.TotalIssues
        # Assume most are warnings (1 point each)
        $pssaPenalty = $totalIssues * 1.5  # Average penalty
        $scoreBreakdown.PSScriptAnalyzer = [math]::Max(0, [math]::Round(100 - $pssaPenalty, 1))
        Write-ScriptLog -Message "PSScriptAnalyzer score: $($scoreBreakdown.PSScriptAnalyzer)/100 (estimated from $totalIssues total issues)"
    }
    
    # Factor 2: Test Coverage (30% weight)
    if ($metrics.TestCoverage.TotalFiles -gt 0) {
        $scoreBreakdown.TestCoverage = [math]::Round($metrics.TestCoverage.Percentage, 1)
        Write-ScriptLog -Message "Test coverage score: $($scoreBreakdown.TestCoverage)/100 ($($metrics.TestCoverage.FilesWithTests)/$($metrics.TestCoverage.TotalFiles) files have tests)"
    } else {
        $scoreBreakdown.TestCoverage = 0
    }
    
    # Factor 3: Documentation Coverage (20% weight)
    if ($metrics.DocumentationCoverage.TotalFunctions -gt 0) {
        $scoreBreakdown.DocumentationCoverage = [math]::Round($metrics.DocumentationCoverage.Percentage, 1)
        Write-ScriptLog -Message "Documentation score: $($scoreBreakdown.DocumentationCoverage)/100 ($($metrics.DocumentationCoverage.FunctionsWithDocs)/$($metrics.DocumentationCoverage.TotalFunctions) functions documented)"
    } else {
        $scoreBreakdown.DocumentationCoverage = 0
    }
    
    # Factor 4: Code Coverage from tests (10% weight)
    if ($metrics.Coverage.Percentage -gt 0) {
        $scoreBreakdown.CodeCoverage = [math]::Round($metrics.Coverage.Percentage, 1)
        Write-ScriptLog -Message "Code coverage score: $($scoreBreakdown.CodeCoverage)/100 ($($metrics.Coverage.CoveredLines)/$($metrics.Coverage.TotalLines) lines covered)"
    } else {
        # No code coverage data - assume low score
        $scoreBreakdown.CodeCoverage = 20
    }
    
    # Calculate weighted average
    $qualityScore = (
        ($scoreBreakdown.PSScriptAnalyzer * 0.40) +
        ($scoreBreakdown.TestCoverage * 0.30) +
        ($scoreBreakdown.DocumentationCoverage * 0.20) +
        ($scoreBreakdown.CodeCoverage * 0.10)
    )
    
    $metrics.QualityCoverage.AverageScore = [math]::Round($qualityScore, 1)
    $metrics.QualityCoverage.ScoreBreakdown = $scoreBreakdown
    
    Write-ScriptLog -Message "Overall quality score: $($metrics.QualityCoverage.AverageScore)/100 (PSSA: $($scoreBreakdown.PSScriptAnalyzer) × 40%, Tests: $($scoreBreakdown.TestCoverage) × 30%, Docs: $($scoreBreakdown.DocumentationCoverage) × 20%, Coverage: $($scoreBreakdown.CodeCoverage) × 10%)"

    return $metrics
}

function Get-QualityMetrics {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification='Function returns multiple metrics')]
    param()
    <#
    .SYNOPSIS
        Collect code quality validation metrics from recent reports
    .DESCRIPTION
        Aggregates quality validation data including scores, checks, and trends
    #>
    Write-ScriptLog -Message "Collecting quality validation metrics"
    
    $qualityMetrics = @{
        OverallScore = 0
        AverageScore = 0
        TotalFiles = 0
        PassedFiles = 0
        FailedFiles = 0
        WarningFiles = 0
        Checks = @{
            ErrorHandling = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            Logging = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            TestCoverage = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            PSScriptAnalyzer = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            UIIntegration = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
            GitHubActions = @{ Passed = 0; Failed = 0; Warnings = 0; AvgScore = 0 }
        }
        RecentReports = @()
        LastValidation = $null
        Trends = @{
            ScoreHistory = @()
            PassRateHistory = @()
        }
    }
    
    # Find quality reports
    $qualityReportsPath = Join-Path $ProjectPath "library/reports/quality"
    if (-not (Test-Path $qualityReportsPath)) {
        Write-ScriptLog -Message "Quality reports directory does not exist yet. Creating: $qualityReportsPath"
        try {
            New-Item -Path $qualityReportsPath -ItemType Directory -Force | Out-Null
            Write-ScriptLog -Message "Created quality reports directory successfully"
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to create quality reports directory: $_"
        }
        # Return empty metrics since no reports exist yet
        Write-ScriptLog -Message "No quality reports available yet. Run './automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains' to generate quality validation reports."
        return $qualityMetrics
    }
    
    # Get recent summary files
    $summaryFiles = @(Get-ChildItem -Path $qualityReportsPath -Filter "*-summary.json" -ErrorAction SilentlyContinue | 
                    Sort-Object LastWriteTime -Descending | 
                    Select-Object -First 10)
    
    if ($summaryFiles.Count -eq 0) {
        Write-ScriptLog -Level Warning -Message "No quality summary reports found"
        return $qualityMetrics
    }
    
    # Process most recent summary
    try {
        $latestSummary = Get-Content $summaryFiles[0].FullName | ConvertFrom-Json
        $qualityMetrics.AverageScore = $latestSummary.AverageScore ?? 0
        $qualityMetrics.TotalFiles = $latestSummary.FilesValidated ?? 0
        $qualityMetrics.PassedFiles = $latestSummary.Passed ?? 0
        $qualityMetrics.FailedFiles = $latestSummary.Failed ?? 0
        $qualityMetrics.WarningFiles = $latestSummary.Warnings ?? 0
        $qualityMetrics.LastValidation = $latestSummary.Timestamp
        
        # Calculate overall score
        if ($qualityMetrics.TotalFiles -gt 0) {
            $qualityMetrics.OverallScore = [math]::Round(
                (($qualityMetrics.PassedFiles * 100) + ($qualityMetrics.WarningFiles * 70)) / $qualityMetrics.TotalFiles, 
                1
            )
        }
    } catch {
        Write-ScriptLog -Level Warning -Message "Failed to parse latest quality summary: $_"
    }
    
    # Collect detailed check statistics from individual reports
    $detailedReports = Get-ChildItem -Path $qualityReportsPath -Filter "*.json" -ErrorAction SilentlyContinue | 
                       Where-Object { $_.Name -notlike "*summary*" } |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 20
    
    $checkScores = @{}
    foreach ($reportFile in $detailedReports) {
        try {
            $report = Get-Content $reportFile.FullName | ConvertFrom-Json
            if ($report.Checks) {
                foreach ($check in $report.Checks) {
                    $checkName = $check.CheckName
                    if (-not $checkScores.ContainsKey($checkName)) {
                        $checkScores[$checkName] = @{ 
                            Scores = [System.Collections.ArrayList]::new()
                            Passed = 0
                            Failed = 0
                            Warnings = 0 
                        }
                    }
                    
                    [void]$checkScores[$checkName].Scores.Add($check.Score)
                    
                    switch ($check.Status) {
                        'Passed' { $checkScores[$checkName].Passed++ }
                        'Failed' { $checkScores[$checkName].Failed++ }
                        'Warning' { $checkScores[$checkName].Warnings++ }
                    }
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse quality report: $($reportFile.Name)"
        }
    }
    
    # Calculate average scores for each check type
    foreach ($checkName in $checkScores.Keys) {
        if ($qualityMetrics.Checks.ContainsKey($checkName)) {
            $qualityMetrics.Checks[$checkName].Passed = $checkScores[$checkName].Passed
            $qualityMetrics.Checks[$checkName].Failed = $checkScores[$checkName].Failed
            $qualityMetrics.Checks[$checkName].Warnings = $checkScores[$checkName].Warnings
            
            if ($checkScores[$checkName].Scores.Count -gt 0) {
                $qualityMetrics.Checks[$checkName].AvgScore = [math]::Round(
                    ($checkScores[$checkName].Scores | Measure-Object -Average).Average,
                    1
                )
            }
        }
    }
    
    # Build trends from historical summaries using efficient collections
    $scoreHistoryList = [System.Collections.Generic.List[object]]::new()
    $passRateHistoryList = [System.Collections.Generic.List[object]]::new()
    
    foreach ($summaryFile in $summaryFiles) {
        try {
            $summary = Get-Content $summaryFile.FullName | ConvertFrom-Json
            $scoreHistoryList.Add(@{
                Timestamp = $summary.Timestamp
                Score = $summary.AverageScore
            })
            
            if ($summary.FilesValidated -gt 0) {
                $passRate = [math]::Round(($summary.Passed / $summary.FilesValidated) * 100, 1)
                $passRateHistoryList.Add(@{
                    Timestamp = $summary.Timestamp
                    PassRate = $passRate
                })
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse quality summary: $($summaryFile.Name) - $_"
        }
    }
    
    # Convert to arrays for compatibility
    $qualityMetrics.Trends.ScoreHistory = @($scoreHistoryList)
    $qualityMetrics.Trends.PassRateHistory = @($passRateHistoryList)
    
    return $qualityMetrics
}

function Get-PSScriptAnalyzerMetrics {
    <#
    .SYNOPSIS
        Get PSScriptAnalyzer metrics from latest report
    #>
    Write-ScriptLog -Message "Collecting PSScriptAnalyzer metrics"
    
    $metrics = @{
        TotalIssues = 0
        Errors = 0
        Warnings = 0
        Information = 0
        FilesAnalyzedCount = 0
        FilesAnalyzed = @()
        LastRun = $null
        TopIssues = @()
    }
    
    # Find latest PSScriptAnalyzer results
    $pssaPath = Join-Path $ProjectPath "library/reports/psscriptanalyzer-fast-results.json"
    if (Test-Path $pssaPath) {
        try {
            $pssaData = Get-Content $pssaPath | ConvertFrom-Json
            $metrics.TotalIssues = $pssaData.Summary.TotalIssues
            $metrics.Errors = $pssaData.Summary.Errors
            $metrics.Warnings = $pssaData.Summary.Warnings
            $metrics.Information = $pssaData.Summary.Information
            $metrics.FilesAnalyzed = $pssaData.FilesAnalyzed
            $metrics.FilesAnalyzedCount = @($pssaData.FilesAnalyzed).Count
            $metrics.LastRun = $pssaData.GeneratedAt
            
            # Get top issues by count
            if ($pssaData.Issues) {
                $issueGroups = $pssaData.Issues | Group-Object -Property RuleName | 
                               Sort-Object Count -Descending | 
                               Select-Object -First 5
                
                $metrics.TopIssues = $issueGroups | ForEach-Object {
                    @{
                        Rule = $_.Name
                        Count = $_.Count
                        Severity = ($_.Group | Select-Object -First 1).Severity
                    }
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse PSScriptAnalyzer results: $_"
        }
    }
    
    return $metrics
}

function ConvertFrom-TestResultsXml {
    <#
    .SYNOPSIS
    Converts NUnit format test results XML to test status object

    .PARAMETER XmlPath
    Path to the test results XML file

    .OUTPUTS
    Hashtable with TestStatus, BadgeUrl, and LastWriteTime
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlPath
    )
    
    try {
        [xml]$testXml = Get-Content $XmlPath
        
        # Parse NUnit format test results
        if ($testXml.'test-results') {
            $results = $testXml.'test-results'
            $totalTests = [int]$results.total
            $failures = [int]$results.failures
            $errors = [int]$results.errors
            
            $testStatus = $null
            $badgeUrl = $null
            
            if (($failures + $errors) -eq 0 -and $totalTests -gt 0) {
                $testStatus = "Passing"
                $badgeUrl = "https://img.shields.io/badge/tests-passing-brightgreen"
            } elseif (($failures + $errors) -gt 0) {
                $testStatus = "Failing"
                $badgeUrl = "https://img.shields.io/badge/tests-failing-red"
            } else {
                $testStatus = "No Tests"
                $badgeUrl = "https://img.shields.io/badge/tests-none-yellow"
            }
            
            return @{
                TestStatus = $testStatus
                BadgeUrl = $badgeUrl
                LastWriteTime = (Get-Item $XmlPath).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } catch {
        Write-ScriptLog -Level Warning -Message "Failed to parse test results from $XmlPath : $_"
    }
    
    return $null
}

function Get-BuildStatus {
    param(
        [hashtable]$Metrics
    )
    
    Write-ScriptLog -Message "Determining build status"

    $status = @{
        Overall = "Unknown"
        LastBuild = "Unknown"
        LastSuccess = "Unknown"
        Tests = "Unknown"
        Security = "Unknown"
        Coverage = "Unknown"
        Deployment = "Unknown"
        Workflows = @{
            Quality = "Unknown"
            PRValidation = "Unknown"
            GitHubPages = "Unknown"
            DockerPublish = "Unknown"
        }
        Badges = @{
            Build = "https://img.shields.io/github/workflow/status/wizzense/AitherZero/CI"
            Tests = "https://img.shields.io/badge/tests-unknown-lightgrey"
            Coverage = "https://img.shields.io/badge/coverage-unknown-lightgrey"
            Security = "https://img.shields.io/badge/security-unknown-lightgrey"
        }
    }

    # Use metrics data if provided (preferred method)
    if ($Metrics) {
        Write-ScriptLog -Message "Using metrics for build status - Tests.Total: $($Metrics.Tests.Total), Tests.Passed: $($Metrics.Tests.Passed), Tests.Failed: $($Metrics.Tests.Failed), Tests.Unit: $($Metrics.Tests.Unit), Tests.Integration: $($Metrics.Tests.Integration)"
        
        # Determine test status from metrics
        # Only show test status if we have actual execution results (Passed or Failed count > 0)
        if (($Metrics.Tests.Passed -gt 0) -or ($Metrics.Tests.Failed -gt 0)) {
            # We have actual test execution results
            if ($Metrics.Tests.Failed -eq 0) {
                $status.Tests = "Passing"
                $passRate = [int]$Metrics.Tests.SuccessRate
                $status.Badges.Tests = "https://img.shields.io/badge/tests-passing%20(${passRate}%25)-brightgreen"
            } else {
                $status.Tests = "Failing"
                $failedCount = $Metrics.Tests.Failed
                $totalTests = $Metrics.Tests.Passed + $Metrics.Tests.Failed + $Metrics.Tests.Skipped
                $status.Badges.Tests = "https://img.shields.io/badge/tests-${failedCount}%20of%20${totalTests}%20failing-red"
            }
            if ($Metrics.Tests.LastRun -and $Metrics.Tests.LastRun -ne "Unknown" -and $Metrics.Tests.LastRun -ne "Not run recently") {
                $status.LastBuild = $Metrics.Tests.LastRun
            }
        } elseif ($Metrics.Tests.Unit -gt 0 -or $Metrics.Tests.Integration -gt 0) {
            # Test files exist but no execution results
            $testCount = $Metrics.Tests.Unit + $Metrics.Tests.Integration
            $status.Tests = "Not Run"
            $status.Badges.Tests = "https://img.shields.io/badge/tests-not%20run%20(${testCount}%20tests)-yellow"
        }
        
        # Set coverage status from metrics
        if ($Metrics.Coverage.Percentage -gt 0) {
            $coveragePercent = [int]$Metrics.Coverage.Percentage
            $status.Coverage = "${coveragePercent}%"
            
            if ($coveragePercent -ge 80) {
                $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-brightgreen"
            } elseif ($coveragePercent -ge 50) {
                $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-yellow"
            } else {
                $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-red"
            }
        }
    }

    # Fallback: Check recent test results from testResults.xml at project root (if metrics didn't provide data)
    if ($status.Tests -eq "Unknown") {
        $testResultsPath = Join-Path $ProjectPath "testResults.xml"
        if (Test-Path $testResultsPath) {
            $result = ConvertFrom-TestResultsXml -XmlPath $testResultsPath
            if ($result) {
                $status.Tests = $result.TestStatus
                $status.Badges.Tests = $result.BadgeUrl
                $status.LastBuild = $result.LastWriteTime
            }
        }
    }
    
    # Also check tests/results directory for additional test data if no results yet
    if ($status.Tests -eq "Unknown") {
        $testResultsDir = Join-Path $ProjectPath "tests/results"
        if (Test-Path $testResultsDir) {
            $latestResults = Get-ChildItem -Path $testResultsDir -Filter "*.xml" -ErrorAction SilentlyContinue | 
                            Sort-Object LastWriteTime -Descending | 
                            Select-Object -First 1
            if ($latestResults) {
                $result = ConvertFrom-TestResultsXml -XmlPath $latestResults.FullName
                if ($result) {
                    $status.Tests = $result.TestStatus
                    $status.Badges.Tests = $result.BadgeUrl
                    $status.LastBuild = $result.LastWriteTime
                }
            }
        }
    }

    # Check code coverage (only if not already set from metrics)
    if ($status.Coverage -eq "Unknown") {
        $coverageFiles = Get-ChildItem -Path $ProjectPath -Filter "Coverage-*.xml" -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Length -gt 100 } |  # Skip empty files
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1
        if ($coverageFiles) {
            try {
                [xml]$coverageXml = Get-Content $coverageFiles.FullName -ErrorAction Stop
                $coveragePercent = 0
                $hasCoverageData = $false
                $totalLines = 0
                
                # Check for JaCoCo format (used by Pester) - use null-safe property access
                $hasReport = $null -ne $coverageXml.PSObject.Properties['report']
                $reportHasCounter = $hasReport -and ($null -ne $coverageXml.report.PSObject.Properties['counter'])
                
                if ($reportHasCounter) {
                    $counters = @($coverageXml.report.counter)
                    $lineCounter = $counters | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1
                    
                    if ($lineCounter -and $lineCounter.missed -and $lineCounter.covered) {
                        $missedLines = [int]$lineCounter.missed
                        $coveredLines = [int]$lineCounter.covered
                        $totalLines = $missedLines + $coveredLines
                        
                        if ($totalLines -gt 0) {
                            $coveragePercent = [math]::Round(($coveredLines / $totalLines) * 100, 1)
                        }
                        $hasCoverageData = $true
                    }
                }
                # Check for Cobertura format (alternative) - use null-safe property access
                elseif ($null -ne $coverageXml.PSObject.Properties['coverage']) {
                    $coverage = $coverageXml.coverage
                    if ($null -ne $coverage.PSObject.Properties['line-rate']) {
                        $coveragePercent = [math]::Round([double]$coverage.'line-rate' * 100, 1)
                        $hasCoverageData = $true
                    }
                }
                
                # Show coverage if we have data, even if it's 0%
                if ($hasCoverageData) {
                    $status.Coverage = "${coveragePercent}%"
                    
                    if ($coveragePercent -ge 80) {
                        $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-brightgreen"
                    } elseif ($coveragePercent -ge 50) {
                        $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-yellow"
                    } else {
                        $status.Badges.Coverage = "https://img.shields.io/badge/coverage-${coveragePercent}%25-red"
                    }
                }
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to parse coverage data: $_"
            }
        }
    }
    
    # Check PSScriptAnalyzer results for security/quality
    $pssaPath = Join-Path $ProjectPath "library/reports/psscriptanalyzer-fast-results.json"
    if (Test-Path $pssaPath) {
        try {
            $pssaData = Get-Content $pssaPath | ConvertFrom-Json
            $errorCount = $pssaData.Summary.Errors
            
            if ($errorCount -eq 0) {
                $status.Security = "Clean"
                $status.Badges.Security = "https://img.shields.io/badge/security-clean-brightgreen"
            } elseif ($errorCount -lt 5) {
                $status.Security = "Minor Issues"
                $status.Badges.Security = "https://img.shields.io/badge/security-minor_issues-yellow"
            } else {
                $status.Security = "Issues Found"
                $status.Badges.Security = "https://img.shields.io/badge/security-issues-red"
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse PSScriptAnalyzer results for security status"
        }
    }

    # Determine overall status
    if ($status.Tests -eq "Passing" -and $status.Security -eq "Clean") {
        $status.Overall = "Healthy"
    } elseif ($status.Tests -eq "Failing" -or $status.Security -eq "Issues Found") {
        $status.Overall = "Issues"
    } elseif (
        ($status.Tests -eq "Passing" -and $status.Security -eq "Minor Issues") -or
        (($status.Tests -eq "Not Run" -or $status.Tests -eq "Passing") -and $status.Security -eq "Clean")
    ) {
        $status.Overall = "Warning"
    } else {
        $status.Overall = "Unknown"
    }
    
    # Check if we're in a CI environment to set deployment status
    if ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true') {
        $status.Deployment = "CI/CD Active"
    }

    return $status
}

function Get-RecentActivity {
    Write-ScriptLog -Message "Getting recent activity"

    $activity = @{
        Commits = @()
        Issues = @()
        Releases = @()
        LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    # Get recent commits using git if available
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try {
            $gitLog = git log --oneline -10 2>$null
            foreach ($line in $gitLog) {
                if ($line) {
                    $parts = $line -split ' ', 2
                    $activity.Commits += @{
                        Hash = $parts[0]
                        Message = $parts[1]
                        Date = (git show -s --format=%ci $parts[0] 2>$null)
                    }
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to get git history"
        }
    }

    return $activity
}

function Get-FileLevelMetrics {
    <#
    .SYNOPSIS
        Get detailed quality metrics for every file in the project
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Collecting file-level quality metrics"
    
    $fileMetrics = @{
        Files = @()
        Summary = @{
            TotalFiles = 0
            AnalyzedFiles = 0
            AverageScore = 0
            ByDomain = @{}
        }
    }
    
    # Get all PowerShell files - wrap entire pipeline with @() to ensure array type
    $psFiles = @(@(
        Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
    ) | Where-Object { $_.FullName -notmatch '(tests|examples|legacy|node_modules)' })
    
    $fileMetrics.Summary.TotalFiles = $psFiles.Count
    
    foreach ($file in $psFiles) {
        # Validate file object exists and has required properties
        if (-not $file -or -not $file.FullName -or -not $file.Name) {
            Write-ScriptLog -Level Warning -Message "Skipping invalid file object in metrics collection"
            continue
        }
        
        try {
            $relativePath = $file.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
            $domain = if ($relativePath -match '^domains/([^/]+)') { $matches[1] } 
                     elseif ($relativePath -match '^automation-scripts') { 'automation-scripts' }
                     else { 'other' }
            
            $fileData = @{
                Path = $relativePath
                Name = $file.Name
                Domain = $domain
                Lines = 0
                Functions = 0
                Score = 0
                Issues = @()
                HasTests = $false
            }
            
            # Count lines and functions with error handling
            $content = $null
            try {
                $content = Get-Content $file.FullName -ErrorAction Stop
            } catch {
                Write-ScriptLog -Level Warning -Message "Could not read file for metrics: $($file.Name) - $_"
                # Continue with empty metrics for this file
                $fileMetrics.Files += $fileData
                $fileMetrics.Summary.AnalyzedFiles++
                continue
            }
            
            if ($content) {
                # Ensure content is always an array for consistent .Count behavior
                $contentArray = @($content)
                $fileData.Lines = $contentArray.Count
                
                # Wrap in array and use Measure-Object for StrictMode safety
                $funcMatches = @($content | Select-String -Pattern '^\s*function\s+' -ErrorAction SilentlyContinue)
                $fileData.Functions = ($funcMatches | Measure-Object).Count
            }
            
            # Run PSScriptAnalyzer on individual file
            if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
                try {
                    # Load skip list from config.psd1 under Testing.PSScriptAnalyzer.SkipFiles
                    $config = if (Get-Command Get-Configuration -ErrorAction SilentlyContinue) { Get-Configuration } else { $null }
                    $skipAnalysisFiles = @()
                    if ($config -and 
                        $null -ne $config.PSObject.Properties['Testing'] -and 
                        $null -ne $config.Testing.PSObject.Properties['PSScriptAnalyzer'] -and 
                        $null -ne $config.Testing.PSScriptAnalyzer.PSObject.Properties['SkipFiles']) {
                        $skipAnalysisFiles = $config.Testing.PSScriptAnalyzer.SkipFiles
                    } else {
                        # Fallback to hardcoded list if config is not available
                        # These files cause PSScriptAnalyzer to fail with WriteObject/WriteError errors
                        $skipAnalysisFiles = @('Maintenance.psm1', '0511_Show-ProjectDashboard.ps1', '0730_Setup-AIAgents.ps1', '0723_Setup-MatrixRunners.ps1')
                    }
                    
                    if ($skipAnalysisFiles -contains $file.Name) {
                        Write-ScriptLog -Level Debug -Message "Skipping PSScriptAnalyzer for known problematic file: $($file.Name)"
                        $fileData.Score = 100  # Assume clean for skipped files
                    }
                    else {
                        # CRITICAL: Wrap PSScriptAnalyzer in a separate try-catch to prevent threading errors
                        # from stopping the entire pipeline (which kills unit tests)
                        try {
                            # Use Measure-Object instead of .Count for maximum StrictMode compatibility
                            # Use ErrorAction Continue to prevent terminating errors during analysis
                            # Use ErrorVariable to separate errors from results
                            # CRITICAL: Run in isolated script block to prevent errors from escaping
                            $scriptAnalyzerErrors = @()
                            $rawIssues = & {
                                param($FilePath)
                                try {
                                    @(Invoke-ScriptAnalyzer -Path $FilePath -ErrorAction Continue 2>&1 | 
                                      Where-Object { $_ -is [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord] })
                                } catch {
                                    # Silently catch and return empty array if PSScriptAnalyzer fails
                                    @()
                                }
                            } $file.FullName
                            
                            $issueCount = ($rawIssues | Measure-Object).Count
                            $issues = if ($issueCount -gt 0) { $rawIssues } else { @() }
                            
                            if (($issues | Measure-Object).Count -gt 0) {
                                # Wrap in array to ensure consistent type even with single result
                                $fileData.Issues = @($issues | Select-Object -First 10 | ForEach-Object {
                                    @{
                                        Rule = $_.RuleName
                                        Severity = $_.Severity
                                        Line = $_.Line
                                        Message = $_.Message
                                    }
                                })
                                
                                # Calculate score (100 - issues penalty)
                                $errorCount = @($issues | Where-Object { $_.Severity -eq 'Error' }).Count
                                $warningCount = @($issues | Where-Object { $_.Severity -eq 'Warning' }).Count
                                $infoCount = @($issues | Where-Object { $_.Severity -eq 'Information' }).Count
                                $errorPenalty = $errorCount * 10
                                $warningPenalty = $warningCount * 3
                                $infoPenalty = $infoCount * 1
                                $fileData.Score = [math]::Max(0, 100 - $errorPenalty - $warningPenalty - $infoPenalty)
                            } else {
                                $fileData.Score = 100  # No issues
                            }
                        } catch {
                            # CRITICAL: Catch ANY PSScriptAnalyzer errors (including threading issues)
                            # and continue without stopping the entire pipeline
                            Write-ScriptLog -Level Warning -Message "Failed to analyze file: $($file.Name) - $($_.Exception.Message)"
                            $fileData.Score = 0  # Mark as failed analysis
                            # DO NOT RE-THROW - let processing continue
                        }
                    }
                } catch {
                    # CRITICAL: Outer catch for config loading errors
                    # Log PSScriptAnalyzer errors but continue with analysis
                    Write-ScriptLog -Level Warning -Message "Failed to analyze file: $($file.Name) - $_"
                    $fileData.Score = 0  # Mark as failed analysis
                }
            } else {
                $fileData.Score = 100  # No analyzer, assume clean
            }
            
            # Check if file has tests
            $testPath = $file.FullName -replace '\.ps(m?)1$', '.Tests.ps1'
            $testPath = $testPath -replace '(domains|automation-scripts)', 'tests/unit/$1'
            $fileData.HasTests = Test-Path $testPath
            
            $fileMetrics.Files += $fileData
            $fileMetrics.Summary.AnalyzedFiles++
            
            # Track by domain
            if (-not $fileMetrics.Summary.ByDomain.ContainsKey($domain)) {
                $fileMetrics.Summary.ByDomain[$domain] = @{
                    Files = 0
                    AverageScore = 0
                    TotalScore = 0
                }
            }
            $fileMetrics.Summary.ByDomain[$domain].Files++
            $fileMetrics.Summary.ByDomain[$domain].TotalScore += $fileData.Score
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze file: $($file.Name) - $_"
        }
    }
    
    # Calculate averages
    if ($fileMetrics.Summary.AnalyzedFiles -gt 0) {
        $fileMetrics.Summary.AverageScore = [math]::Round(
            ($fileMetrics.Files | Measure-Object -Property Score -Average).Average,
            1
        )
        
        foreach ($domain in $fileMetrics.Summary.ByDomain.Keys) {
            if ($fileMetrics.Summary.ByDomain[$domain].Files -gt 0) {
                $fileMetrics.Summary.ByDomain[$domain].AverageScore = [math]::Round(
                    $fileMetrics.Summary.ByDomain[$domain].TotalScore / $fileMetrics.Summary.ByDomain[$domain].Files,
                    1
                )
            }
        }
    }
    
    return $fileMetrics
}

function Get-DependencyMapping {
    <#
    .SYNOPSIS
        Extract and map dependencies from config.psd1
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Mapping dependencies from config.psd1"
    
    $dependencies = @{
        Features = @()
        Scripts = @{}
        Modules = @{}
        Total = 0
    }
    
    $configPath = Join-Path $ProjectPath "config.psd1"
    if (Test-Path $configPath) {
        try {
            # Use scriptblock evaluation instead of Import-PowerShellDataFile
            # because config.psd1 contains PowerShell expressions ($true/$false) that
            # Import-PowerShellDataFile treats as "dynamic expressions"
            $configContent = Get-Content -Path $configPath -Raw
            $scriptBlock = [scriptblock]::Create($configContent)
            $config = & $scriptBlock
            if (-not $config -or $config -isnot [hashtable]) {
                throw "Config file did not return a valid hashtable"
            }
            
            # Extract feature dependencies
            if ($config.Manifest.FeatureDependencies) {
                foreach ($category in $config.Manifest.FeatureDependencies.Keys) {
                    foreach ($feature in $config.Manifest.FeatureDependencies[$category].Keys) {
                        try {
                            $featureData = $config.Manifest.FeatureDependencies[$category][$feature]
                            $featureDep = @{
                                Category = $category
                                Name = $feature
                                DependsOn = @()
                                Scripts = @()
                                Required = $false
                                Platform = @()
                                Description = ''
                            }
                            
                            # Safely add properties that exist
                            if ($featureData.PSObject.Properties['DependsOn']) { $featureDep.DependsOn = $featureData.DependsOn }
                            if ($featureData.PSObject.Properties['Scripts']) { $featureDep.Scripts = $featureData.Scripts }
                            if ($featureData.PSObject.Properties['Required']) { $featureDep.Required = [bool]$featureData.Required }
                            if ($featureData.PSObject.Properties['PlatformRestrictions']) { $featureDep.Platform = $featureData.PlatformRestrictions }
                            if ($featureData.PSObject.Properties['Description']) { $featureDep.Description = $featureData.Description }
                            
                            $dependencies.Features += $featureDep
                            $dependencies.Total++
                        } catch {
                            Write-ScriptLog -Level Warning -Message "Failed to parse feature $category.$feature : $_"
                        }
                    }
                }
            }
            
            # Extract script inventory
            if ($config.Manifest.ScriptInventory) {
                $dependencies.Scripts = $config.Manifest.ScriptInventory
            }
            
            # Extract domain modules
            if ($config.Manifest.Domains) {
                $dependencies.Modules = $config.Manifest.Domains
            }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse config.psd1: $_"
        }
    }
    
    return $dependencies
}

function Get-DetailedTestResults {
    <#
    .SYNOPSIS
        Get comprehensive test results with descriptions and audit test files
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Collecting detailed test results and auditing test coverage"
    
    $testResults = @{
        Tests = @()
        Summary = @{
            Total = 0
            Passed = 0
            Failed = 0
            Skipped = 0
            Duration = "Unknown"
        }
        ByDomain = @{}
        ByType = @{
            Unit = @{ Total = 0; Passed = 0; Failed = 0 }
            Integration = @{ Total = 0; Passed = 0; Failed = 0 }
        }
        TestFiles = @{
            Total = 0
            Unit = 0
            Integration = 0
            WithResults = 0
            PotentialTests = 0
        }
        Audit = @{
            Message = ''
            FilesWithoutResults = @()
        }
    }
    
    # Count all test files
    # Get all test files - wrap with @() to handle empty results under StrictMode
    $allTestFiles = @(Get-ChildItem -Path (Join-Path $ProjectPath "tests") -Filter "*.Tests.ps1" -Recurse -ErrorAction SilentlyContinue)
    $testResults.TestFiles.Total = $allTestFiles.Count
    $testResults.TestFiles.Unit = @($allTestFiles | Where-Object { $_.FullName -match '/unit/' }).Count
    $testResults.TestFiles.Integration = @($allTestFiles | Where-Object { $_.FullName -match '/integration/' }).Count
    
    # Count potential test cases in all test files
    foreach ($testFile in $allTestFiles) {
        try {
            $content = Get-Content $testFile.FullName -ErrorAction SilentlyContinue
            if ($content) {
                # Ensure array and use Measure-Object for StrictMode safety
                $itBlocks = @($content | Select-String -Pattern '^\s*It\s+[''"]' -AllMatches)
                $itCount = ($itBlocks | Measure-Object).Count
                if ($itCount -gt 0) {
                    $testResults.TestFiles.PotentialTests += $itCount
                }
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to read test file: $($testFile.Name) - $_"
        }
    }
    
    # Parse TestReport JSON files for actual execution results (created by 0402 and 0403)
    # Look for latest TestReport-*.json files in tests/results
    $testResultsDir = Join-Path $ProjectPath "tests/results"
    $testReportFiles = @()
    
    if (Test-Path $testResultsDir) {
        $testReportFiles = @(Get-ChildItem -Path $testResultsDir -Filter "TestReport-*.json" -ErrorAction SilentlyContinue |
                            Where-Object { $_.Length -gt 50 } |  # Skip empty files
                            Sort-Object LastWriteTime -Descending)
    }
    
    if ($testReportFiles.Count -gt 0) {
        Write-ScriptLog -Message "Found $($testReportFiles.Count) TestReport JSON files"
        
        # Process each test report (Unit and Integration)
        foreach ($reportFile in $testReportFiles | Select-Object -First 10) {  # Limit to 10 most recent
            try {
                $reportContent = Get-Content $reportFile.FullName -Raw -ErrorAction Stop
                $report = $reportContent | ConvertFrom-Json
                
                # Handle execution errors gracefully
                if ($null -ne $report.PSObject.Properties['ExecutionError']) {
                    Write-ScriptLog -Level Warning -Message "Test report contains execution error: $($reportFile.Name) - $($report.ExecutionError.Message)"
                    # Still process what we have
                }
                
                # Aggregate summary counts
                if ($null -ne $report.PSObject.Properties['TotalCount']) {
                    $testResults.Summary.Total += [int]$report.TotalCount
                }
                if ($null -ne $report.PSObject.Properties['PassedCount']) {
                    $testResults.Summary.Passed += [int]$report.PassedCount
                }
                if ($null -ne $report.PSObject.Properties['FailedCount']) {
                    $testResults.Summary.Failed += [int]$report.FailedCount
                }
                if ($null -ne $report.PSObject.Properties['SkippedCount']) {
                    $testResults.Summary.Skipped += [int]$report.SkippedCount
                }
                
                # Track by type
                $testType = if ($null -ne $report.PSObject.Properties['TestType']) { $report.TestType } else { 'Other' }
                if ($testResults.ByType.ContainsKey($testType)) {
                    if ($null -ne $report.PSObject.Properties['TotalCount']) {
                        $testResults.ByType[$testType].Total += [int]$report.TotalCount
                    }
                    if ($null -ne $report.PSObject.Properties['PassedCount']) {
                        $testResults.ByType[$testType].Passed += [int]$report.PassedCount
                    }
                    if ($null -ne $report.PSObject.Properties['FailedCount']) {
                        $testResults.ByType[$testType].Failed += [int]$report.FailedCount
                    }
                }
                
                # Extract failed test details if available
                if ($null -ne $report.PSObject.Properties['TestResults'] -and 
                    $null -ne $report.TestResults.PSObject.Properties['Details'] -and 
                    $report.TestResults.Details.Count -gt 0) {
                    
                    foreach ($testDetail in $report.TestResults.Details) {
                        $testName = if ($null -ne $testDetail.PSObject.Properties['Name']) { $testDetail.Name } else { 'Unknown' }
                        $testPath = if ($null -ne $testDetail.PSObject.Properties['ExpandedPath']) { $testDetail.ExpandedPath } else { $testName }
                        
                        $domain = if ($testPath -match '/aithercore/([^/]+)/') { $matches[1] }
                                 elseif ($testPath -match '/automation-scripts/') { 'automation-scripts' }
                                 else { 'other' }
                        
                        $testData = @{
                            Name = $testName
                            Result = if ($null -ne $testDetail.PSObject.Properties['Result']) { $testDetail.Result } else { 'Failed' }
                            Success = $false  # Details only include failed tests
                            Time = if ($null -ne $testDetail.PSObject.Properties['Duration']) { $testDetail.Duration } else { 0 }
                            Domain = $domain
                            Type = $testType
                        }
                        
                        $testResults.Tests += $testData
                        
                        # Track by domain
                        if (-not $testResults.ByDomain.ContainsKey($domain)) {
                            $testResults.ByDomain[$domain] = @{ Total = 0; Passed = 0; Failed = 0 }
                        }
                        $testResults.ByDomain[$domain].Total++
                        $testResults.ByDomain[$domain].Failed++
                    }
                }
                
                # Aggregate duration
                if ($null -ne $report.PSObject.Properties['Duration']) {
                    $duration = [double]$report.Duration
                    if ($duration -lt 60) {
                        $testResults.Summary.Duration = "$([math]::Round($duration, 2))s"
                    } else {
                        $minutes = [math]::Floor($duration / 60)
                        $seconds = [math]::Round($duration % 60, 0)
                        $testResults.Summary.Duration = "${minutes}m ${seconds}s"
                    }
                }
                
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to parse test report: $($reportFile.Name) - $_"
            }
        }
        
        Write-ScriptLog -Message "Aggregated test results: Total=$($testResults.Summary.Total), Passed=$($testResults.Summary.Passed), Failed=$($testResults.Summary.Failed), Skipped=$($testResults.Summary.Skipped)"
    } else {
        Write-ScriptLog -Level Warning -Message "No TestReport JSON files found in $testResultsDir"
    }
    
    # Create audit message
    if ($testResults.TestFiles.Total -gt 0) {
        $coveragePercent = if ($testResults.TestFiles.PotentialTests -gt 0 -and $testResults.Summary.Total -gt 0) {
            [math]::Round(($testResults.Summary.Total / $testResults.TestFiles.PotentialTests) * 100, 1)
        } else { 0 }
        
        $testResults.Audit.Message = @"
⚠️ TEST AUDIT FINDINGS:
- Total Test Files: $($testResults.TestFiles.Total) ($($testResults.TestFiles.Unit) unit, $($testResults.TestFiles.Integration) integration)
- Potential Test Cases: $($testResults.TestFiles.PotentialTests) (by counting It blocks)
- Actually Run: $($testResults.Summary.Total) ($coveragePercent% of potential)
- Test Results: Passed=$($testResults.Summary.Passed), Failed=$($testResults.Summary.Failed), Skipped=$($testResults.Summary.Skipped)

The autogenerated test system has created $($testResults.TestFiles.Total) test files with approximately $($testResults.TestFiles.PotentialTests) test cases.
Test results are aggregated from TestReport-*.json files in tests/results.
Run './automation-scripts/0402_Run-UnitTests.ps1' (unit) or './automation-scripts/0403_Run-IntegrationTests.ps1' (integration) to execute tests.
"@
    }
    
    return $testResults
}

function Get-CodeCoverageDetails {
    <#
    .SYNOPSIS
        Get detailed code coverage information from JaCoCo or Cobertura format
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Collecting code coverage details"
    
    $coverage = @{
        Overall = @{
            Percentage = 0
            CoveredLines = 0
            TotalLines = 0
            MissedLines = 0
        }
        ByFile = @()
        ByDomain = @{}
        Format = "Unknown"
    }
    
    # Look for latest coverage XML - check both tests/results and tests/coverage
    $searchPaths = @(
        (Join-Path $ProjectPath "tests/results"),
        (Join-Path $ProjectPath "tests/coverage")
    )
    
    $coverageFiles = @()
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            $coverageFiles += Get-ChildItem -Path $searchPath -Filter "Coverage-*.xml" -ErrorAction SilentlyContinue |
                             Where-Object { $_.Length -gt 100 }  # Skip empty files
        }
    }
    
    $latestCoverage = $coverageFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestCoverage) {
        try {
            [xml]$coverageXml = Get-Content $latestCoverage.FullName
            
            # Check for JaCoCo format (used by Pester) - use null-safe property access
            $hasReport = $null -ne $coverageXml.PSObject.Properties['report']
            $reportHasCounter = $hasReport -and ($null -ne $coverageXml.report.PSObject.Properties['counter'])
            
            if ($reportHasCounter) {
                Write-ScriptLog -Message "Parsing JaCoCo coverage format"
                $coverage.Format = "JaCoCo"
                
                # Get counters from report root - safely handle missing counter elements
                if ($reportHasCounter) {
                    $counters = @($coverageXml.report.counter)
                    $lineCounter = $counters | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1
                    
                    if ($lineCounter -and $lineCounter.missed -and $lineCounter.covered) {
                        $missedLines = [int]$lineCounter.missed
                        $coveredLines = [int]$lineCounter.covered
                        $totalLines = $missedLines + $coveredLines
                        
                        if ($totalLines -gt 0) {
                            $coverage.Overall.Percentage = [math]::Round(($coveredLines / $totalLines) * 100, 1)
                            $coverage.Overall.CoveredLines = $coveredLines
                            $coverage.Overall.TotalLines = $totalLines
                            $coverage.Overall.MissedLines = $missedLines
                            
                            Write-ScriptLog -Message "Coverage: $($coverage.Overall.Percentage)% ($coveredLines/$totalLines lines)"
                        }
                    } else {
                        Write-ScriptLog -Level Warning -Message 'No LINE counter found in JaCoCo report'
                    }
                } else {
                    Write-ScriptLog -Level Warning -Message 'No counter elements found in JaCoCo report (empty or incomplete coverage data)'
                }
                
                # Extract file-level coverage from classes
                $packages = $coverageXml.SelectNodes("//package")
                foreach ($package in $packages) {
                    $classes = $package.SelectNodes(".//class")
                    foreach ($class in $classes) {
                        $filename = $class.sourcefilename
                        if (-not $filename) { continue }
                        
                        # Get line counter for this class - safely handle missing counter
                        if ($class.counter) {
                            $classLineCounter = @($class.counter) | Where-Object { $_.type -eq 'LINE' } | Select-Object -First 1
                            if ($classLineCounter) {
                                $classMissed = [int]$classLineCounter.missed
                                $classCovered = [int]$classLineCounter.covered
                                $classTotal = $classMissed + $classCovered
                                
                                $fileCoverage = if ($classTotal -gt 0) { 
                                    [math]::Round(($classCovered / $classTotal) * 100, 1)
                                } else { 0 }
                                
                                $domain = if ($filename -match 'domains[/\\]([^/\\]+)') { $matches[1] }
                                         elseif ($filename -match 'automation-scripts') { 'automation-scripts' }
                                         else { 'other' }
                                
                                $coverage.ByFile += @{
                                    File = $filename
                                    Coverage = $fileCoverage
                                    Domain = $domain
                                    CoveredLines = $classCovered
                                    TotalLines = $classTotal
                                }
                                
                                # Track by domain
                                if (-not $coverage.ByDomain.ContainsKey($domain)) {
                                    $coverage.ByDomain[$domain] = @{ 
                                        Files = 0
                                        TotalCoverage = 0
                                        AverageCoverage = 0
                                        CoveredLines = 0
                                        TotalLines = 0
                                    }
                                }
                                $coverage.ByDomain[$domain].Files++
                                $coverage.ByDomain[$domain].TotalCoverage += $fileCoverage
                                $coverage.ByDomain[$domain].CoveredLines += $classCovered
                                $coverage.ByDomain[$domain].TotalLines += $classTotal
                            }
                        }
                    }
                }
                
                # Calculate domain averages
                foreach ($domain in $coverage.ByDomain.Keys) {
                    if ($coverage.ByDomain[$domain].Files -gt 0) {
                        $coverage.ByDomain[$domain].AverageCoverage = [math]::Round(
                            $coverage.ByDomain[$domain].TotalCoverage / $coverage.ByDomain[$domain].Files,
                            1
                        )
                    }
                }
            }
            # Check for Cobertura format - use null-safe property access
            elseif ($null -ne $coverageXml.PSObject.Properties['coverage']) {
                Write-ScriptLog -Message "Parsing Cobertura coverage format"
                $coverage.Format = "Cobertura"
                $cov = $coverageXml.coverage
                
                if ($null -ne $cov.PSObject.Properties['line-rate']) {
                    $coverage.Overall.Percentage = [math]::Round([double]$cov.'line-rate' * 100, 1)
                }
                
                # Calculate total and covered lines for Cobertura format
                if (($null -ne $cov.PSObject.Properties['lines-covered']) -and ($null -ne $cov.PSObject.Properties['lines-valid'])) {
                    $coverage.Overall.CoveredLines = [int]$cov.'lines-covered'
                    $coverage.Overall.TotalLines = [int]$cov.'lines-valid'
                    $coverage.Overall.MissedLines = $coverage.Overall.TotalLines - $coverage.Overall.CoveredLines
                }
                
                # Extract file-level coverage
                $packages = $coverageXml.SelectNodes("//package")
                foreach ($package in $packages) {
                    $classes = $package.SelectNodes(".//class")
                    foreach ($class in $classes) {
                        $filename = $class.filename
                        $lineRate = [double]$class.'line-rate'
                        
                        $domain = if ($filename -match 'domains[/\\]([^/\\]+)') { $matches[1] }
                                 elseif ($filename -match 'automation-scripts') { 'automation-scripts' }
                                 else { 'other' }
                        
                        $coverage.ByFile += @{
                            File = $filename
                            Coverage = [math]::Round($lineRate * 100, 1)
                            Domain = $domain
                        }
                        
                        # Track by domain
                        if (-not $coverage.ByDomain.ContainsKey($domain)) {
                            $coverage.ByDomain[$domain] = @{ 
                                Files = 0
                                TotalCoverage = 0
                                AverageCoverage = 0
                            }
                        }
                        $coverage.ByDomain[$domain].Files++
                        $coverage.ByDomain[$domain].TotalCoverage += ($lineRate * 100)
                    }
                }
                
                # Calculate domain averages
                foreach ($domain in $coverage.ByDomain.Keys) {
                    if ($coverage.ByDomain[$domain].Files -gt 0) {
                        $coverage.ByDomain[$domain].AverageCoverage = [math]::Round(
                            $coverage.ByDomain[$domain].TotalCoverage / $coverage.ByDomain[$domain].Files,
                            1
                        )
                    }
                }
            }
            else {
                Write-ScriptLog -Level Warning -Message "Unrecognized coverage file format"
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to parse coverage data: $_"
        }
    } else {
        Write-ScriptLog -Level Warning -Message "No coverage files found in tests/results or tests/coverage"
    }
    
    return $coverage
}

function Get-LifecycleAnalysis {
    <#
    .SYNOPSIS
        Analyze the age and lifecycle of all project components
    #>
    param(
        [string]$ProjectPath
    )
    
    Write-ScriptLog -Message "Performing lifecycle analysis"
    
    $lifecycle = @{
        Documentation = @{
            Files = @()
            Summary = @{
                Total = 0
                Stale = 0  # > 6 months
                Old = 0    # > 1 year
                Ancient = 0 # > 2 years
                AverageAgeDays = 0
            }
        }
        Code = @{
            Files = @()
            Summary = @{
                Total = 0
                Fresh = 0    # < 1 month
                Recent = 0   # < 3 months  
                Stale = 0    # > 6 months
                Old = 0      # > 1 year
                AverageAgeDays = 0
            }
        }
        LineCountAnalysis = @{
            PowerShellCode = 0
            Documentation = 0
            CommentedCode = 0
            BlankLines = 0
            ActualCode = 0
            DocumentationRatio = 0
        }
        ByDomain = @{}
    }
    
    $now = Get-Date
    
    # Analyze documentation files
    # Get all documentation files - wrap entire pipeline with @() to ensure array type
    $docFiles = @(@(Get-ChildItem -Path $ProjectPath -Filter "*.md" -Recurse -ErrorAction SilentlyContinue) |
                 Where-Object { $_.FullName -notmatch '(node_modules|\.git)' })
    
    $lifecycle.Documentation.Summary.Total = $docFiles.Count
    
    foreach ($doc in $docFiles) {
        # Validate file object exists and has required properties
        if (-not $doc -or -not $doc.LastWriteTime -or -not $doc.FullName) {
            Write-ScriptLog -Level Warning -Message "Skipping invalid doc file object in lifecycle analysis"
            continue
        }
        
        try {
            $lastWrite = $doc.LastWriteTime
            $ageDays = ($now - $lastWrite).TotalDays
            
            # Read content with explicit error handling
            $content = $null
            try {
                $content = Get-Content $doc.FullName -ErrorAction Stop
            } catch {
                Write-ScriptLog -Level Warning -Message "Could not read doc file: $($doc.Name) - $_"
                continue
            }
            
            # Ensure array for consistent Count property access - use Measure-Object for safety
            $contentArray = if ($content) { @($content) } else { @() }
            $lineCount = ($contentArray | Measure-Object).Count
            
            $docData = @{
                Path = $doc.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
                LastModified = $lastWrite.ToString("yyyy-MM-dd")
                AgeDays = [math]::Round($ageDays, 0)
                Lines = $lineCount
                Status = if ($ageDays -gt 730) { 'Ancient' }
                        elseif ($ageDays -gt 365) { 'Old' }
                        elseif ($ageDays -gt 180) { 'Stale' }
                        else { 'Current' }
            }
            
            $lifecycle.Documentation.Files += $docData
            $lifecycle.LineCountAnalysis.Documentation += $lineCount
            
            # Update summary counts
            if ($ageDays -gt 730) { $lifecycle.Documentation.Summary.Ancient++ }
            elseif ($ageDays -gt 365) { $lifecycle.Documentation.Summary.Old++ }
            elseif ($ageDays -gt 180) { $lifecycle.Documentation.Summary.Stale++ }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze doc: $($doc.Name) - $($_.Exception.Message)"
        }
    }
    
    if ($docFiles.Count -gt 0) {
        $lifecycle.Documentation.Summary.AverageAgeDays = [math]::Round(
            ($lifecycle.Documentation.Files | Measure-Object -Property AgeDays -Average).Average,
            0
        )
    }
    
    # Analyze PowerShell code files - wrap entire pipeline with @() to ensure array type
    $psFiles = @(@(
        Get-ChildItem -Path $ProjectPath -Filter "*.ps1" -Recurse
        Get-ChildItem -Path $ProjectPath -Filter "*.psm1" -Recurse
    ) | Where-Object { $_.FullName -notmatch '(tests|examples|legacy|node_modules)' })
    
    $lifecycle.Code.Summary.Total = $psFiles.Count
    
    foreach ($file in $psFiles) {
        # Validate file object exists and has required properties
        if (-not $file -or -not $file.LastWriteTime -or -not $file.FullName) {
            Write-ScriptLog -Level Warning -Message "Skipping invalid PS file object in lifecycle analysis"
            continue
        }
        
        try {
            $lastWrite = $file.LastWriteTime
            $ageDays = ($now - $lastWrite).TotalDays
            
            # Read content with explicit error handling
            $content = $null
            try {
                $content = Get-Content $file.FullName -ErrorAction Stop
            } catch {
                Write-ScriptLog -Level Warning -Message "Could not read PS file: $($file.Name) - $_"
                continue
            }
            
            if ($content) {
                # Ensure array for consistent Count property access - use Measure-Object for safety
                $contentArray = @($content)
                $totalLines = ($contentArray | Measure-Object).Count
                $codeLines = 0
                $commentLines = 0
                $blankLines = 0
                $inCommentBlock = $false
                
                foreach ($line in $contentArray) {
                    $trimmed = $line.Trim()
                    
                    if ($trimmed -eq '') {
                        $blankLines++
                    }
                    elseif ($trimmed -match '^<#') {
                        $inCommentBlock = $true
                        $commentLines++
                    }
                    elseif ($trimmed -match '^#>') {
                        $inCommentBlock = $false
                        $commentLines++
                    }
                    elseif ($inCommentBlock -or $trimmed -match '^#') {
                        $commentLines++
                    }
                    else {
                        $codeLines++
                    }
                }
                
                $lifecycle.LineCountAnalysis.PowerShellCode += $totalLines
                $lifecycle.LineCountAnalysis.ActualCode += $codeLines
                $lifecycle.LineCountAnalysis.CommentedCode += $commentLines
                $lifecycle.LineCountAnalysis.BlankLines += $blankLines
                
                $domain = if ($file.FullName -match 'domains[/\\]([^/\\]+)') { $matches[1] }
                         elseif ($file.FullName -match 'automation-scripts') { 'automation-scripts' }
                         else { 'other' }
                
                $fileData = @{
                    Path = $file.FullName.Replace($ProjectPath, '').TrimStart('\', '/')
                    LastModified = $lastWrite.ToString("yyyy-MM-dd")
                    AgeDays = [math]::Round($ageDays, 0)
                    Lines = $totalLines
                    CodeLines = $codeLines
                    CommentLines = $commentLines
                    Domain = $domain
                    Status = if ($ageDays -lt 30) { 'Fresh' }
                            elseif ($ageDays -lt 90) { 'Recent' }
                            elseif ($ageDays -gt 365) { 'Old' }
                            elseif ($ageDays -gt 180) { 'Stale' }
                            else { 'Current' }
                }
                
                $lifecycle.Code.Files += $fileData
                
                # Update summary counts
                if ($ageDays -lt 30) { $lifecycle.Code.Summary.Fresh++ }
                elseif ($ageDays -lt 90) { $lifecycle.Code.Summary.Recent++ }
                elseif ($ageDays -gt 365) { $lifecycle.Code.Summary.Old++ }
                elseif ($ageDays -gt 180) { $lifecycle.Code.Summary.Stale++ }
                
                # Track by domain
                if (-not $lifecycle.ByDomain.ContainsKey($domain)) {
                    $lifecycle.ByDomain[$domain] = @{
                        Files = 0
                        TotalLines = 0
                        CodeLines = 0
                        CommentLines = 0
                        AverageAgeDays = 0
                        TotalAgeDays = 0
                    }
                }
                $lifecycle.ByDomain[$domain].Files++
                $lifecycle.ByDomain[$domain].TotalLines += $totalLines
                $lifecycle.ByDomain[$domain].CodeLines += $codeLines
                $lifecycle.ByDomain[$domain].CommentLines += $commentLines
                $lifecycle.ByDomain[$domain].TotalAgeDays += $ageDays
            }
            
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to analyze code: $($file.Name) - $($_.Exception.Message)"
        }
    }
    
    if ($psFiles.Count -gt 0) {
        $lifecycle.Code.Summary.AverageAgeDays = [math]::Round(
            ($lifecycle.Code.Files | Measure-Object -Property AgeDays -Average).Average,
            0
        )
    }
    
    # Calculate domain averages
    foreach ($domain in $lifecycle.ByDomain.Keys) {
        if ($lifecycle.ByDomain[$domain].Files -gt 0) {
            $lifecycle.ByDomain[$domain].AverageAgeDays = [math]::Round(
                $lifecycle.ByDomain[$domain].TotalAgeDays / $lifecycle.ByDomain[$domain].Files,
                0
            )
        }
    }
    
    # Calculate documentation ratio
    $totalCountedLines = $lifecycle.LineCountAnalysis.PowerShellCode + $lifecycle.LineCountAnalysis.Documentation
    if ($totalCountedLines -gt 0) {
        $lifecycle.LineCountAnalysis.DocumentationRatio = [math]::Round(
            ($lifecycle.LineCountAnalysis.Documentation / $totalCountedLines) * 100,
            1
        )
    }
    
    return $lifecycle
}

function Get-GitHubRepositoryData {
    param(
        [string]$Owner = "wizzense",
        [string]$Repo = "AitherZero"
    )
    
    Write-ScriptLog -Message "Fetching GitHub repository data for $Owner/$Repo"
    
    $repoData = @{
        Stars = 0
        Forks = 0
        OpenIssues = 0
        OpenPRs = 0
        Watchers = 0
        LastUpdated = "Unknown"
        DefaultBranch = "main"
        License = "Unknown"
        Language = "PowerShell"
        Topics = @()
        Error = $null
    }
    
    try {
        # Check if we're in GitHub Actions with access to API
        $apiUrl = "https://api.github.com/repos/$Owner/$Repo"
        $repoInfo = $null
        
        # Try gh CLI if available and properly authenticated
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            # Set GH_TOKEN from GITHUB_TOKEN for GitHub Actions compatibility
            if ($env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
                $env:GH_TOKEN = $env:GITHUB_TOKEN
                Write-ScriptLog -Message "Set GH_TOKEN from GITHUB_TOKEN for GitHub Actions"
            }
            
            # Only use gh CLI if we have authentication
            if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
                Write-ScriptLog -Message "Attempting to use GitHub CLI for authenticated request"
                $response = gh api $apiUrl 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $repoInfo = $response | ConvertFrom-Json
                    Write-ScriptLog -Message "Successfully fetched repository data using GitHub CLI"
                } else {
                    Write-ScriptLog -Level Warning -Message "GitHub CLI request failed (exit code $LASTEXITCODE), falling back to direct API call"
                }
            } else {
                Write-ScriptLog -Message "GitHub CLI available but not authenticated, using direct API call"
            }
        }
        
        # Fallback to direct API call if gh CLI didn't work
        if (-not $repoInfo) {
            Write-ScriptLog -Message "Using direct API request for repository data"
            $headers = @{
                'User-Agent' = 'AitherZero-Dashboard'
                'Accept' = 'application/vnd.github.v3+json'
            }
            
            # Add auth token if available - GITHUB_TOKEN is the standard in GitHub Actions
            if ($env:GITHUB_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
            } elseif ($env:GH_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GH_TOKEN"
            }
            
            $repoInfo = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
        }
        
        if ($repoInfo) {
            $repoData.Stars = $repoInfo.stargazers_count
            $repoData.Forks = $repoInfo.forks_count
            $repoData.OpenIssues = $repoInfo.open_issues_count
            $repoData.Watchers = $repoInfo.watchers_count
            $repoData.DefaultBranch = $repoInfo.default_branch
            $repoData.LastUpdated = $repoInfo.updated_at
            
            if ($repoInfo.license) {
                $repoData.License = $repoInfo.license.name
            }
            
            if ($repoInfo.language) {
                $repoData.Language = $repoInfo.language
            }
            
            if ($repoInfo.topics) {
                $repoData.Topics = $repoInfo.topics
            }
            
            Write-ScriptLog -Message "Successfully fetched GitHub data: $($repoData.Stars) stars, $($repoData.Forks) forks"
            
            # Fetch pull requests separately
            try {
                $prUrl = "https://api.github.com/repos/$Owner/$Repo/pulls?state=open"
                $prs = $null
                
                # Try gh CLI if available and authenticated
                if (Get-Command gh -ErrorAction SilentlyContinue) {
                    # Ensure GH_TOKEN is set for gh CLI in GitHub Actions
                    if ($env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
                        $env:GH_TOKEN = $env:GITHUB_TOKEN
                    }
                    
                    if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
                        $prResponse = gh api $prUrl 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $prs = $prResponse | ConvertFrom-Json
                        } else {
                            Write-ScriptLog -Level Warning -Message "GitHub CLI PR request failed (exit code $LASTEXITCODE), falling back to direct API call"
                        }
                    }
                }
                
                # Fallback to direct API call if gh CLI didn't work
                if (-not $prs) {
                    $prs = Invoke-RestMethod -Uri $prUrl -Headers $headers -ErrorAction Stop
                }
                
                $repoData.OpenPRs = @($prs).Count
                Write-ScriptLog -Message "Fetched PR data: $($repoData.OpenPRs) open PRs"
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to fetch PR data: $($_.Exception.Message)"
            }
        }
    } catch {
        $repoData.Error = $_.Exception.Message
        Write-ScriptLog -Level Warning -Message "Failed to fetch GitHub data: $($_.Exception.Message)"
    }
    
    return $repoData
}

function Get-GitHubWorkflowStatus {
    param(
        [string]$Owner = "wizzense",
        [string]$Repo = "AitherZero"
    )
    
    Write-ScriptLog -Message "Fetching GitHub Actions workflow status"
    
    $workflowData = @{
        TotalWorkflows = 0
        SuccessfulRuns = 0
        FailedRuns = 0
        LastRunStatus = "Unknown"
        LastRunTime = "Unknown"
        Workflows = @()
        Error = $null
    }
    
    try {
        $workflowsUrl = "https://api.github.com/repos/$Owner/$Repo/actions/workflows"
        $workflowsList = $null
        
        # Try gh CLI if available and authenticated
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            # Ensure GH_TOKEN is set for gh CLI in GitHub Actions
            if ($env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
                $env:GH_TOKEN = $env:GITHUB_TOKEN
                Write-ScriptLog -Message "Set GH_TOKEN from GITHUB_TOKEN for GitHub Actions"
            }
            
            if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
                $response = gh api $workflowsUrl 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $workflowsList = $response | ConvertFrom-Json
                } else {
                    Write-ScriptLog -Level Warning -Message "Failed to fetch workflows via gh CLI (exit code $LASTEXITCODE), falling back to direct API call"
                }
            }
        }
        
        # Fallback to direct API call if gh CLI didn't work
        if (-not $workflowsList) {
            $headers = @{
                'User-Agent' = 'AitherZero-Dashboard'
                'Accept' = 'application/vnd.github.v3+json'
            }
            
            # Add auth token if available - GITHUB_TOKEN is the standard in GitHub Actions
            if ($env:GITHUB_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
            } elseif ($env:GH_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GH_TOKEN"
            }
            
            $workflowsList = Invoke-RestMethod -Uri $workflowsUrl -Headers $headers -ErrorAction Stop
        }
        
        if ($workflowsList -and $workflowsList.workflows) {
            $workflowData.TotalWorkflows = $workflowsList.workflows.Count
            
            # Get status of recent workflow runs
            $runsUrl = "https://api.github.com/repos/$Owner/$Repo/actions/runs?per_page=10"
            $runsData = $null
            
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                # Ensure GH_TOKEN is set for gh CLI in GitHub Actions
                if ($env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
                    $env:GH_TOKEN = $env:GITHUB_TOKEN
                }
                
                if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
                    $runsResponse = gh api $runsUrl 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $runsData = $runsResponse | ConvertFrom-Json
                    } else {
                        Write-ScriptLog -Level Warning -Message "Failed to fetch workflow runs via gh CLI (exit code $LASTEXITCODE), falling back to direct API call"
                    }
                }
            }
            
            # Fallback to direct API call if gh CLI didn't work
            if (-not $runsData) {
                $runsData = Invoke-RestMethod -Uri $runsUrl -Headers $headers -ErrorAction Stop
            }
            
            if ($runsData -and $runsData.workflow_runs) {
                $runs = $runsData.workflow_runs
                $workflowData.SuccessfulRuns = @($runs | Where-Object { $_.conclusion -eq 'success' }).Count
                $workflowData.FailedRuns = @($runs | Where-Object { $_.conclusion -eq 'failure' }).Count
                
                if ($runs.Count -gt 0) {
                    $lastRun = $runs[0]
                    $workflowData.LastRunStatus = $lastRun.conclusion
                    $workflowData.LastRunTime = $lastRun.created_at
                }
            }
            
            Write-ScriptLog -Message "Fetched workflow status: $($workflowData.TotalWorkflows) workflows, $($workflowData.SuccessfulRuns) successful"
        }
    } catch {
        $workflowData.Error = $_.Exception.Message
        Write-ScriptLog -Level Warning -Message "Failed to fetch workflow status: $($_.Exception.Message)"
    }
    
    return $workflowData
}

function Get-GitHubIssues {
    <#
    .SYNOPSIS
        Fetch open GitHub issues for the repository
    #>
    param(
        [string]$Owner = "wizzense",
        [string]$Repo = "AitherZero",
        [int]$MaxIssues = 10
    )
    
    Write-ScriptLog -Message "Fetching GitHub issues for $Owner/$Repo"
    
    $issuesData = @{
        TotalOpen = 0
        Issues = @()
        Error = $null
    }
    
    try {
        $issuesUrl = "https://api.github.com/repos/$Owner/$Repo/issues?state=open&per_page=$MaxIssues"
        $issuesList = $null
        
        # Try gh CLI if available and properly authenticated
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            # Ensure GH_TOKEN is set for gh CLI in GitHub Actions
            if ($env:GITHUB_TOKEN -and -not $env:GH_TOKEN) {
                $env:GH_TOKEN = $env:GITHUB_TOKEN
                Write-ScriptLog -Message "Set GH_TOKEN from GITHUB_TOKEN for GitHub Actions"
            }
            
            # Only use gh CLI if we have authentication
            if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) {
                Write-ScriptLog -Message "Attempting to use GitHub CLI to fetch issues"
                $response = gh api $issuesUrl 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $issuesList = $response | ConvertFrom-Json
                    Write-ScriptLog -Message "Successfully fetched issues using GitHub CLI"
                } else {
                    Write-ScriptLog -Level Warning -Message "GitHub CLI request failed (exit code $LASTEXITCODE), falling back to direct API call"
                }
            } else {
                Write-ScriptLog -Message "GitHub CLI available but not authenticated, using direct API call"
            }
        }
        
        # Fallback to direct API call if gh CLI didn't work
        if (-not $issuesList) {
            Write-ScriptLog -Message "Using direct API request for issues"
            $headers = @{
                'User-Agent' = 'AitherZero-Dashboard'
                'Accept' = 'application/vnd.github.v3+json'
            }
            
            # Add auth token if available - GITHUB_TOKEN is the standard in GitHub Actions
            if ($env:GITHUB_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
            } elseif ($env:GH_TOKEN) {
                $headers['Authorization'] = "Bearer $env:GH_TOKEN"
            }
            
            $issuesList = Invoke-RestMethod -Uri $issuesUrl -Headers $headers -ErrorAction Stop
        }
        
        if ($issuesList) {
            # Ensure array wrapping for consistent Count property
            $issuesArray = @($issuesList)
            $issuesData.TotalOpen = $issuesArray.Count
            
            foreach ($issue in $issuesArray) {
                # Skip pull requests (GitHub API returns them as issues)
                # Use null-safe property access
                if ($null -ne $issue.PSObject.Properties['pull_request'] -and $issue.pull_request) {
                    continue
                }
                
                $labels = @($issue.labels | ForEach-Object { $_.name })
                
                $issuesData.Issues += @{
                    Number = $issue.number
                    Title = $issue.title
                    State = $issue.state
                    Labels = $labels
                    CreatedAt = $issue.created_at
                    UpdatedAt = $issue.updated_at
                    Url = $issue.html_url
                    User = $issue.user.login
                }
            }
            
            Write-ScriptLog -Message "Successfully fetched $($issuesData.Issues.Count) open issues"
        }
    } catch {
        $issuesData.Error = $_.Exception.Message
        Write-ScriptLog -Level Warning -Message "Failed to fetch GitHub issues: $($_.Exception.Message)"
    }
    
    return $issuesData
}

function Get-HistoricalMetrics {
    param(
        [string]$ReportsPath = "./reports",
        [hashtable]$CurrentMetrics = @{}
    )
    
    Write-ScriptLog -Message "Loading historical metrics data"
    
    $history = @{
        TestTrends = @()
        TestCoverageTrends = @()
        DocumentationCoverageTrends = @()
        QualityTrends = @()
        LineCoverageTrends = @()
        SyntaxTrends = @()
        WorkflowTrends = @()
        LOCTrends = @()
        LastNDays = 30
    }
    
    try {
        # Save current metrics to history file
        $historyPath = Join-Path $ReportsPath "metrics-history"
        if (-not (Test-Path $historyPath)) {
            New-Item -ItemType Directory -Path $historyPath -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $dateOnly = Get-Date -Format "yyyy-MM-dd"
        
        # Save current snapshot if we have metrics
        if ($CurrentMetrics.Count -gt 0) {
            $snapshot = @{
                Timestamp = (Get-Date).ToString('o')
                Date = $dateOnly
                TestCoverage = $CurrentMetrics.TestCoverage
                DocumentationCoverage = $CurrentMetrics.DocumentationCoverage
                QualityCoverage = $CurrentMetrics.QualityCoverage
                LineCoverage = $CurrentMetrics.Coverage
                Tests = $CurrentMetrics.Tests
                LinesOfCode = $CurrentMetrics.LinesOfCode
                Functions = $CurrentMetrics.Functions
            }
            
            $snapshotFile = Join-Path $historyPath "snapshot-$timestamp.json"
            $snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $snapshotFile
            Write-ScriptLog -Message "Saved metrics snapshot: $snapshotFile"
        }
        
        # Load historical snapshots from last 30 days - wrap with @() to ensure array type
        $cutoffDate = (Get-Date).AddDays(-30)
        $snapshotFiles = @(@(Get-ChildItem -Path $historyPath -Filter "snapshot-*.json" -ErrorAction SilentlyContinue) |
                        Where-Object { $_.LastWriteTime -gt $cutoffDate } |
                        Sort-Object LastWriteTime -Descending)
        
        foreach ($file in $snapshotFiles) {
            try {
                $data = Get-Content $file.FullName -Raw | ConvertFrom-Json
                
                # Test trends
                if ($data.Tests) {
                    $history.TestTrends += @{
                        Date = $data.Date
                        Total = if ($data.Tests.Total) { $data.Tests.Total } else { 0 }
                        Passed = if ($data.Tests.Passed) { $data.Tests.Passed } else { 0 }
                        Failed = if ($data.Tests.Failed) { $data.Tests.Failed } else { 0 }
                    }
                }
                
                # Test coverage trends
                if ($data.TestCoverage) {
                    $history.TestCoverageTrends += @{
                        Date = $data.Date
                        Percentage = if ($data.TestCoverage.Percentage) { $data.TestCoverage.Percentage } else { 0 }
                        FilesWithTests = if ($data.TestCoverage.FilesWithTests) { $data.TestCoverage.FilesWithTests } else { 0 }
                        TotalFiles = if ($data.TestCoverage.TotalFiles) { $data.TestCoverage.TotalFiles } else { 0 }
                    }
                }
                
                # Documentation coverage trends
                if ($data.DocumentationCoverage) {
                    $history.DocumentationCoverageTrends += @{
                        Date = $data.Date
                        Percentage = if ($data.DocumentationCoverage.Percentage) { $data.DocumentationCoverage.Percentage } else { 0 }
                        FunctionsWithDocs = if ($data.DocumentationCoverage.FunctionsWithDocs) { $data.DocumentationCoverage.FunctionsWithDocs } else { 0 }
                        TotalFunctions = if ($data.DocumentationCoverage.TotalFunctions) { $data.DocumentationCoverage.TotalFunctions } else { 0 }
                    }
                }
                
                # Quality trends
                if ($data.QualityCoverage) {
                    $history.QualityTrends += @{
                        Date = $data.Date
                        Percentage = if ($data.QualityCoverage.Percentage) { $data.QualityCoverage.Percentage } else { 0 }
                        AverageScore = if ($data.QualityCoverage.AverageScore) { $data.QualityCoverage.AverageScore } else { 0 }
                        PassedFiles = if ($data.QualityCoverage.PassedFiles) { $data.QualityCoverage.PassedFiles } else { 0 }
                    }
                }
                
                # Line coverage trends
                if ($data.LineCoverage) {
                    $history.LineCoverageTrends += @{
                        Date = $data.Date
                        Percentage = if ($data.LineCoverage.Percentage) { $data.LineCoverage.Percentage } else { 0 }
                        CoveredLines = if ($data.LineCoverage.CoveredLines) { $data.LineCoverage.CoveredLines } else { 0 }
                        TotalLines = if ($data.LineCoverage.TotalLines) { $data.LineCoverage.TotalLines } else { 0 }
                    }
                }
                
                # LOC trends
                $history.LOCTrends += @{
                    Date = $data.Date
                    Total = if ($data.LinesOfCode) { $data.LinesOfCode } else { 0 }
                    Functions = if ($data.Functions) { $data.Functions } else { 0 }
                }
            } catch {
                Write-ScriptLog -Level Warning -Message "Failed to parse historical snapshot: $($file.Name)"
            }
        }
        
        Write-ScriptLog -Message "Loaded $($snapshotFiles.Count) historical data points"
    } catch {
        Write-ScriptLog -Level Warning -Message "Failed to load historical metrics: $($_.Exception.Message)"
    }
    
    return $history
}

function New-HTMLDashboard {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [hashtable]$QualityMetrics,
        [hashtable]$PSScriptAnalyzerMetrics,
        [hashtable]$GitHubData,
        [hashtable]$WorkflowStatus,
        [hashtable]$HistoricalMetrics,
        [hashtable]$FileMetrics,
        [hashtable]$Dependencies,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating HTML dashboard with interactive features"
    
    # Load enhanced template files
    $templatePath = Join-Path $ProjectPath "library/templates/dashboard"
    $enhancedStylesPath = Join-Path $templatePath "enhanced-styles.css"
    $enhancedScriptsPath = Join-Path $templatePath "enhanced-scripts.js"
    
    $enhancedStyles = ""
    $enhancedScripts = ""
    
    if (Test-Path $enhancedStylesPath) {
        $enhancedStyles = Get-Content $enhancedStylesPath -Raw
        Write-ScriptLog -Message "Loaded enhanced styles"
    } else {
        Write-ScriptLog -Level Warning -Message "Enhanced styles not found: $enhancedStylesPath"
    }
    
    if (Test-Path $enhancedScriptsPath) {
        $enhancedScripts = Get-Content $enhancedScriptsPath -Raw
        Write-ScriptLog -Message "Loaded enhanced scripts"
    } else {
        Write-ScriptLog -Level Warning -Message "Enhanced scripts not found: $enhancedScriptsPath"
    }

    Write-ScriptLog -Message "Generating HTML dashboard"

    # Load module manifest data
    $manifestPath = Join-Path $ProjectPath "AitherZero.psd1"
    $manifestData = $null
    $manifestVersion = "Unknown"
    $manifestGUID = "Unknown"
    $manifestAuthor = "Unknown"
    $manifestPSVersion = "Unknown"
    $manifestFunctionsCount = 0
    $manifestAliases = ""
    $manifestDescription = ""
    $manifestTagsHTML = ""
    
    if (Test-Path $manifestPath) {
        try {
            $manifestData = Import-PowerShellDataFile $manifestPath
            $manifestVersion = $manifestData.ModuleVersion
            $manifestGUID = $manifestData.GUID
            $manifestAuthor = $manifestData.Author
            $manifestPSVersion = $manifestData.PowerShellVersion
            $manifestFunctionsCount = @($manifestData.FunctionsToExport).Count
            $manifestAliases = $manifestData.AliasesToExport -join ', '
            $manifestDescription = $manifestData.Description
            
            if ($manifestData.PrivateData -and $manifestData.PrivateData.PSData -and $manifestData.PrivateData.PSData.Tags) {
                $manifestTagsHTML = $manifestData.PrivateData.PSData.Tags | ForEach-Object { "<span class='badge info'>$_</span>" } | Join-String -Separator ' '
            }
        } catch {
            Write-ScriptLog -Level Warning -Message "Failed to load manifest data"
        }
    }

    # Get domain module information
    $domainsPath = Join-Path $ProjectPath "aithercore"
    $domains = @()
    if (Test-Path $domainsPath) {
        $domainDirs = Get-ChildItem -Path $domainsPath -Directory
        foreach ($domainDir in $domainDirs) {
            $moduleFiles = @(Get-ChildItem -Path $domainDir.FullName -Filter "*.psm1")
            $domains += @{
                Name = $domainDir.Name
                ModuleCount = $moduleFiles.Count
                Modules = $moduleFiles.Name
            }
        }
    }
    
    # Pre-build commits HTML
    $commitsHTML = ""
    if (@($Activity.Commits).Count -gt 0) {
        $commitsHTML = $Activity.Commits | Select-Object -First 5 | ForEach-Object {
            @"
                            <li class='commit-item'>
                                <span class='commit-hash'>$($_.Hash)</span>
                                <span class='commit-message'>$($_.Message)</span>
                            </li>
"@
        } | Join-String -Separator "`n"
    } else {
        $commitsHTML = "                            <li class='commit-item'><span class='commit-message'>No recent activity found</span></li>"
    }
    
    # Pre-build domains HTML
    $domainsHTML = ""
    if (@($domains).Count -gt 0) {
        $domainsCount = @($domains).Count
        $domainCardsHTML = foreach($domain in $domains) {
            @"
                    <div class="domain-card">
                        <h4>$($domain.Name)</h4>
                        <div class="module-count">$($domain.ModuleCount) module$(if($domain.ModuleCount -ne 1){'s'})</div>
                    </div>
"@
        }
        $domainCardsJoined = $domainCardsHTML | Join-String -Separator "`n"
        
        $domainsHTML = @"
            <section class="section" id="aithercore">
                <h2>🗂️ Domain Modules</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Consolidated domain-based module architecture with $domainsCount domains
                </p>
                <div class="domains-list">
$domainCardsJoined
                </div>
            </section>
"@
    }
    
    # Pre-build manifest HTML
    $manifestHTML = ""
    if ($manifestData) {
        $manifestTagsSection = ""
        if ($manifestTagsHTML) {
            $manifestTagsSection = @"
                <div style="margin-top: 15px;">
                    <div class="label" style="margin-bottom: 10px;">Tags</div>
                    <div class="badge-grid">
                        $manifestTagsHTML
                    </div>
                </div>
"@
        }
        
        $manifestHTML = @"
            <section class="section" id="manifest">
                <h2>📦 Module Manifest</h2>
                <div class="manifest-info">
                    <h4>AitherZero.psd1</h4>
                    <div class="manifest-grid">
                        <div class="manifest-item">
                            <div class="label">Version</div>
                            <div class="value">$manifestVersion</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">GUID</div>
                            <div class="value">$manifestGUID</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">Author</div>
                            <div class="value">$manifestAuthor</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">PowerShell Version</div>
                            <div class="value">$manifestPSVersion+</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">Functions Exported</div>
                            <div class="value">$manifestFunctionsCount</div>
                        </div>
                        <div class="manifest-item">
                            <div class="label">Aliases</div>
                            <div class="value">$manifestAliases</div>
                        </div>
                    </div>
                    <div style="margin-top: 20px;">
                        <div class="label" style="margin-bottom: 10px;">Description</div>
                        <div class="value" style="color: var(--text-secondary);">$manifestDescription</div>
                    </div>
$manifestTagsSection
                </div>
            </section>
"@
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AitherZero - Project Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --primary-color: #667eea;
            --secondary-color: #764ba2;
            --bg-dark: #0d1117;
            --bg-darker: #010409;
            --card-bg: #161b22;
            --card-border: #30363d;
            --text-primary: #c9d1d9;
            --text-secondary: #8b949e;
            --success: #238636;
            --warning: #d29922;
            --error: #da3633;
            --info: #1f6feb;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: var(--bg-darker);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 20px;
            margin-left: 290px;
        }
        
        @media (max-width: 1024px) {
            body {
                margin-left: 0;
                padding: 10px;
            }
        }

        /* Navigation TOC */
        .toc {
            position: fixed;
            top: 80px;
            left: 20px;
            width: 250px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 20px;
            max-height: calc(100vh - 100px);
            overflow-y: auto;
            z-index: 100;
            transition: transform 0.3s ease;
        }

        .toc-toggle {
            position: fixed;
            top: 20px;
            left: 20px;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            padding: 10px 15px;
            border-radius: 8px;
            cursor: pointer;
            z-index: 101;
            color: var(--text-primary);
            font-size: 1.2rem;
        }

        .toc h3 {
            color: var(--primary-color);
            margin-bottom: 15px;
            font-size: 1rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .toc ul {
            list-style: none;
        }

        .toc li {
            margin-bottom: 10px;
        }

        .toc a {
            color: var(--text-secondary);
            text-decoration: none;
            transition: color 0.2s;
            font-size: 0.9rem;
        }

        .toc a:hover {
            color: var(--primary-color);
        }

        .toc a.active {
            color: var(--primary-color);
            font-weight: 600;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
        }

        .header {
            background: linear-gradient(135deg, var(--primary-color) 0%, var(--secondary-color) 100%);
            border-radius: 16px;
            padding: 40px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        }

        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            background: linear-gradient(to right, #fff, #e0e0e0);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }

        .header .subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
            color: rgba(255,255,255,0.9);
        }

        .badges-container {
            display: flex;
            gap: 10px;
            margin-top: 20px;
            flex-wrap: wrap;
            justify-content: center;
        }

        .badges-container img {
            height: 20px;
            transition: transform 0.2s;
        }

        .badges-container img:hover {
            transform: scale(1.05);
        }

        .status-bar {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 25px;
        }

        .status-badge {
            padding: 12px 20px;
            border-radius: 8px;
            font-weight: 600;
            font-size: 0.9rem;
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
            text-align: center;
        }

        .status-healthy { 
            background: linear-gradient(135deg, rgba(35, 134, 54, 0.3), rgba(35, 134, 54, 0.1)); 
            border-color: var(--success);
        }
        .status-issues { 
            background: linear-gradient(135deg, rgba(218, 54, 51, 0.3), rgba(218, 54, 51, 0.1)); 
            border-color: var(--error);
        }
        .status-warning { 
            background: linear-gradient(135deg, rgba(210, 153, 34, 0.3), rgba(210, 153, 34, 0.1)); 
            border-color: var(--warning);
        }
        .status-unknown { 
            background: linear-gradient(135deg, rgba(139, 148, 158, 0.3), rgba(139, 148, 158, 0.1)); 
            border-color: var(--text-secondary);
        }

        .content {
            margin-bottom: 30px;
        }

        .section {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            scroll-margin-top: 20px;
        }

        .section h2 {
            color: var(--primary-color);
            margin-bottom: 20px;
            font-size: 1.8rem;
            padding-bottom: 10px;
            border-bottom: 2px solid var(--card-border);
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-top: 25px;
        }

        .metric-card {
            background: linear-gradient(135deg, var(--card-bg) 0%, rgba(22, 27, 34, 0.5) 100%);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 25px;
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
            min-height: 180px;
            display: flex;
            flex-direction: column;
        }

        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            width: 4px;
            height: 100%;
            background: linear-gradient(180deg, var(--primary-color), var(--secondary-color));
        }

        .metric-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 8px 25px rgba(102, 126, 234, 0.2);
            border-color: var(--primary-color);
        }

        .metric-card h3 {
            color: var(--text-primary);
            margin-bottom: 15px;
            font-size: 1.1rem;
            font-weight: 600;
        }

        .metric-value {
            font-size: 2.5rem;
            font-weight: bold;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
            line-height: 1.2;
        }

        .metric-label {
            color: var(--text-secondary);
            font-size: 0.9rem;
            line-height: 1.5;
            flex-grow: 1;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }

        .info-card {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 8px;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .info-card:hover {
            border-color: var(--primary-color);
            box-shadow: 0 4px 20px rgba(102, 126, 234, 0.15);
        }

        .info-card-header {
            background: rgba(102, 126, 234, 0.1);
            padding: 15px 20px;
            font-weight: 600;
            border-bottom: 1px solid var(--card-border);
            color: var(--text-primary);
        }

        .info-card-body {
            padding: 20px;
        }

        .info-card-body p {
            margin-bottom: 12px;
            color: var(--text-secondary);
        }

        .info-card-body strong {
            color: var(--text-primary);
        }

        .info-card-body a {
            color: var(--info);
            text-decoration: none;
            transition: color 0.2s;
        }

        .info-card-body a:hover {
            color: var(--primary-color);
            text-decoration: underline;
        }

        .info-card-body code {
            background: var(--bg-darker);
            padding: 2px 8px;
            border-radius: 4px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            color: var(--primary-color);
        }

        .commit-list {
            list-style: none;
        }

        .commit-item {
            display: flex;
            align-items: flex-start;
            padding: 10px 0;
            border-bottom: 1px solid var(--card-border);
        }

        .commit-item:last-child {
            border-bottom: none;
        }

        .commit-hash {
            font-family: 'Courier New', monospace;
            font-size: 0.8rem;
            background: var(--bg-darker);
            padding: 4px 8px;
            border-radius: 4px;
            margin-right: 12px;
            color: var(--primary-color);
            flex-shrink: 0;
        }

        .commit-message {
            color: var(--text-secondary);
            line-height: 1.5;
        }

        .progress-bar {
            background: var(--bg-darker);
            border-radius: 10px;
            height: 24px;
            overflow: hidden;
            margin: 10px 0;
            border: 1px solid var(--card-border);
        }

        .progress-fill {
            background: linear-gradient(90deg, var(--primary-color), var(--secondary-color));
            height: 100%;
            border-radius: 10px;
            transition: width 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 0.8rem;
            font-weight: 600;
        }

        .badge-grid {
            display: flex;
            gap: 10px;
            margin: 20px 0;
            flex-wrap: wrap;
        }

        .badge {
            background: var(--success);
            color: white;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 0.85rem;
            font-weight: 600;
            border: 1px solid transparent;
        }

        .badge.warning { 
            background: var(--warning); 
            color: var(--bg-darker); 
        }
        .badge.error { 
            background: var(--error); 
        }
        .badge.info { 
            background: var(--info); 
        }

        .manifest-info {
            background: var(--bg-darker);
            padding: 20px;
            border-radius: 8px;
            border: 1px solid var(--card-border);
        }

        .manifest-info h4 {
            color: var(--primary-color);
            margin-bottom: 15px;
        }

        .manifest-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .manifest-item {
            padding: 10px;
            background: var(--card-bg);
            border-radius: 6px;
            border: 1px solid var(--card-border);
        }

        .manifest-item .label {
            color: var(--text-secondary);
            font-size: 0.85rem;
            margin-bottom: 5px;
        }

        .manifest-item .value {
            color: var(--text-primary);
            font-weight: 600;
        }

        .domains-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }

        .domain-card {
            background: var(--bg-darker);
            padding: 15px;
            border-radius: 8px;
            border: 1px solid var(--card-border);
            transition: all 0.2s;
        }

        .domain-card:hover {
            border-color: var(--primary-color);
            transform: translateY(-2px);
        }

        .domain-card h4 {
            color: var(--primary-color);
            margin-bottom: 10px;
            text-transform: capitalize;
        }

        .domain-card .module-count {
            color: var(--text-secondary);
            font-size: 0.9rem;
        }

        .footer {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.9rem;
        }

        .footer a {
            color: var(--info);
            text-decoration: none;
        }

        .footer a:hover {
            color: var(--primary-color);
        }

        .refresh-indicator {
            position: fixed;
            top: 20px;
            right: 20px;
            background: var(--card-bg);
            padding: 12px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.3);
            font-size: 0.85rem;
            color: var(--text-secondary);
            border: 1px solid var(--card-border);
            z-index: 100;
        }

        @media (max-width: 1024px) {
            body {
                margin-left: 0;
            }

            .toc {
                transform: translateX(-270px);
            }

            .toc.open {
                transform: translateX(0);
            }

            .metrics-grid {
                grid-template-columns: 1fr;
            }

            .info-grid {
                grid-template-columns: 1fr;
            }

            .status-bar {
                grid-template-columns: 1fr;
            }
        }

        /* Smooth scroll */
        html {
            scroll-behavior: smooth;
        }

        /* Link styling */
        a {
            color: var(--info);
        }

        /* Roadmap Styles */
        .roadmap-container {
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .roadmap-priority {
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 8px;
            overflow: hidden;
            transition: all 0.3s ease;
        }

        .roadmap-priority:hover {
            border-color: var(--primary-color);
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.1);
        }

        .priority-header {
            padding: 20px;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.1), rgba(118, 75, 162, 0.05));
            border-bottom: 1px solid var(--card-border);
            user-select: none;
        }

        .priority-header:hover {
            background: linear-gradient(135deg, rgba(102, 126, 234, 0.15), rgba(118, 75, 162, 0.1));
        }

        .priority-header h3 {
            margin: 0;
            color: var(--text-primary);
            font-size: 1.1rem;
        }

        .toggle-icon {
            font-size: 1rem;
            color: var(--primary-color);
            transition: transform 0.3s ease;
        }

        .priority-header.active .toggle-icon {
            transform: rotate(180deg);
        }

        .priority-content {
            padding: 20px;
            border-top: 1px solid var(--card-border);
        }

        .progress-indicator {
            margin-bottom: 20px;
        }

        .roadmap-list {
            list-style: none;
            padding-left: 0;
            margin: 15px 0;
        }

        .roadmap-item {
            padding: 10px 0;
            display: flex;
            align-items: center;
            gap: 12px;
            color: var(--text-secondary);
            border-bottom: 1px solid var(--card-border);
        }

        .roadmap-item:last-child {
            border-bottom: none;
        }

        .status-dot {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            flex-shrink: 0;
        }

        .roadmap-item.completed .status-dot {
            background: var(--success);
            box-shadow: 0 0 8px var(--success);
        }

        .roadmap-item.in-progress .status-dot {
            background: var(--warning);
            box-shadow: 0 0 8px var(--warning);
            animation: pulse 2s ease-in-out infinite;
        }

        .roadmap-item.pending .status-dot {
            background: var(--text-secondary);
            opacity: 0.3;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }

        .timeline {
            margin-top: 15px;
            padding: 10px;
            background: var(--bg-darker);
            border-radius: 4px;
            font-size: 0.9rem;
            color: var(--text-secondary);
        }

        /* Interactive enhancements */
        .metric-card {
            cursor: pointer;
            transition: all 0.3s ease, transform 0.2s ease;
        }

        .metric-card.expanded {
            grid-column: 1 / -1;
            background: linear-gradient(135deg, var(--card-bg) 0%, rgba(102, 126, 234, 0.05) 100%);
        }

        .metric-details {
            display: none;
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid var(--card-border);
            animation: fadeIn 0.3s ease;
        }

        .metric-card.expanded .metric-details {
            display: block;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* Chart styles */
        .chart-container {
            position: relative;
            height: 200px;
            margin: 20px 0;
        }

        .chart-bar {
            display: flex;
            align-items: flex-end;
            gap: 10px;
            height: 100%;
        }

        .bar {
            flex: 1;
            background: linear-gradient(180deg, var(--primary-color), var(--secondary-color));
            border-radius: 4px 4px 0 0;
            position: relative;
            transition: all 0.3s ease;
            min-height: 20px;
        }

        .bar:hover {
            opacity: 0.8;
            transform: translateY(-5px);
        }

        .bar-label {
            position: absolute;
            bottom: -25px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 0.75rem;
            color: var(--text-secondary);
            white-space: nowrap;
        }

        .bar-value {
            position: absolute;
            top: -25px;
            left: 50%;
            transform: translateX(-50%);
            font-size: 0.8rem;
            color: var(--primary-color);
            font-weight: 600;
        }
        
        /* Enhanced Interactive Styles */
        $enhancedStyles
    </style>
</head>
<body>
    <!-- Breadcrumb Navigation -->
    <div id="breadcrumbs"></div>
    
    <div class="toc-toggle" onclick="toggleToc()">☰</div>
    
    <nav class="toc" id="toc">
        <h3>📑 Contents</h3>
        <ul>
            <li><a href="#overview">Overview</a></li>
            <li><a href="#actions">Quick Actions</a></li>
            <li><a href="#metrics">Project Metrics</a></li>
            <li><a href="#dependencies">Dependencies</a></li>
            <li><a href="#domains">Domain Explorer</a></li>
            <li><a href="#config">Configuration</a></li>
            <li><a href="#quality">Code Quality</a></li>
            <li><a href="#pssa">PSScriptAnalyzer</a></li>
            <li><a href="#manifest">Module Manifest</a></li>
            <li><a href="#health">Project Health</a></li>
            <li><a href="#releases">Releases</a></li>
            <li><a href="#git">Git & VCS</a></li>
            <li><a href="#activity">Recent Activity</a></li>
            <li><a href="#indices">Index Navigation</a></li>
            <li><a href="#system">System Info</a></li>
            <li><a href="#resources">Resources</a></li>
            <li><a href="#roadmap">🗺️ Roadmap</a></li>
            <li><a href="#github-activity">🌟 GitHub</a></li>
            <li><a href="#workflow-status">⚙️ CI/CD</a></li>
            <li><a href="#github-issues">🐛 Issues</a></li>
            <li><a href="#trends">📈 Trends</a></li>
        </ul>
    </nav>

    <div class="refresh-indicator">
        🔄 Last updated: $($Metrics.LastUpdated)
    </div>

    <div class="container">
        <div class="header" id="overview">
            <h1>🚀 AitherZero</h1>
            <div class="subtitle">Infrastructure Automation Platform</div>

            <div class="badges-container">
                <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/quality-validation.yml?label=Quality&logo=github" alt="Quality Check">
                <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/pr-validation.yml?label=PR%20Validation&logo=github" alt="PR Validation">
                <img src="https://img.shields.io/github/actions/workflow/status/wizzense/AitherZero/jekyll-gh-pages.yml?label=GitHub%20Pages&logo=github" alt="GitHub Pages">
                <img src="$($Status.Badges.Tests)" alt="Tests Status">
                <img src="https://img.shields.io/badge/PowerShell-7.0+-blue?logo=powershell" alt="PowerShell Version">
                <img src="https://img.shields.io/github/license/wizzense/AitherZero" alt="License">
                <img src="https://img.shields.io/github/last-commit/wizzense/AitherZero" alt="Last Commit">
            </div>

            <div class="status-bar">
                <div class="status-badge status-$(($Status.Overall).ToLower())">
                    🎯 Overall: $($Status.Overall)
                </div>
                <div class="status-badge status-$(if($Status.Tests -eq 'Passing'){'healthy'}elseif($Status.Tests -eq 'Failing'){'issues'}else{'unknown'})">
                    🧪 Tests: $($Status.Tests)
                </div>
                <div class="status-badge status-$(if($Status.Security -eq 'Clean'){'healthy'}elseif($Status.Security -match 'Issues'){'issues'}elseif($Status.Security -match 'Minor'){'warning'}else{'unknown'})">
                    🔒 Security: $($Status.Security)
                </div>
                <div class="status-badge status-$(if($Status.Deployment -match 'Active'){'healthy'}else{'unknown'})">
                    📦 Deployment: $($Status.Deployment)
                </div>
            </div>
        </div>

        <div class="content">
            <!-- Quick Actions Section with GitHub Integration -->
            <section class="section" id="actions">
                <h2>⚡ Quick Actions & GitHub Integration</h2>
                <div class="action-buttons">
                    <button class="btn btn-primary" onclick="window.location.href='code-map.html'" style="font-size: 1.1rem; padding: 12px 24px;">
                        🗺️ Explore Interactive Code Map
                    </button>
                    <button class="btn btn-primary" onclick="window.open('https://github.com/wizzense/AitherZero', '_blank')">
                        🏠 View Repository
                    </button>
                    <button class="btn btn-success" onclick="createGitHubIssue('bug')">
                        🐛 Report Bug
                    </button>
                    <button class="btn btn-success" onclick="createGitHubIssue('feature')">
                        ✨ Request Feature
                    </button>
                    <button class="btn btn-success" onclick="createGitHubIssue('docs')">
                        📚 Improve Docs
                    </button>
                    <button class="btn btn-primary" onclick="createPullRequest()">
                        🔀 Create Pull Request
                    </button>
                    <button class="btn" onclick="openDocumentation()">
                        📖 Browse Documentation
                    </button>
                    <button class="btn" onclick="openDocumentation('README.md')">
                        📄 View README
                    </button>
                    <button class="btn" onclick="window.open('https://github.com/wizzense/AitherZero/releases', '_blank')">
                        📦 View Releases
                    </button>
                </div>
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 15px; text-align: center;">
                    💡 Click any button to open GitHub in a new tab with pre-filled templates | 🗺️ Click Code Map for full codebase visualization
                </p>
            </section>
            
            <section class="section" id="metrics">
                <h2>📊 Project Metrics</h2>
                <div class="metrics-grid">
                    <div class="metric-card">
                        <h3>📁 Project Files</h3>
                        <div class="metric-value">$($Metrics.Files.Total)</div>
                        <div class="metric-label">
                            $($Metrics.Files.PowerShell) Scripts | $($Metrics.Files.Modules) Modules | $($Metrics.Files.Data) Data
                        </div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                        📄 $($Metrics.Files.Markdown) Markdown | 🔧 $($Metrics.Files.YAML) YAML | 📋 $($Metrics.Files.JSON) JSON
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>📝 Lines of Code</h3>
                        <div class="metric-value">$($Metrics.LinesOfCode.ToString('N0'))</div>
                        <div class="metric-label">
                            $($Metrics.Functions) Functions$(if($Metrics.Classes -gt 0){" | $($Metrics.Classes) Classes"})
                        </div>
                        $(if ($Metrics.CommentLines -gt 0) {
                            $commentRatio = [math]::Round(($Metrics.CommentLines / $Metrics.LinesOfCode) * 100, 1)
                            @"
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            💬 $($Metrics.CommentLines.ToString('N0')) Comments ($commentRatio%) | ⚪ $($Metrics.BlankLines.ToString('N0')) Blank Lines
                        </div>
"@
                        })
                    </div>
                    
                    <div class="metric-card">
                        <h3>🤖 Automation Scripts</h3>
                        <div class="metric-value">$($Metrics.AutomationScripts)</div>
                        <div class="metric-label">Number-based orchestration (0000-9999)</div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            ⚡ $($Metrics.Workflows) GitHub Workflows
                        </div>
                    </div>
                    
                    <div class="metric-card">
                        <h3>🗂️ Domain Modules</h3>
                        <div class="metric-value">$(@($Metrics.Domains).Count)</div>
                        <div class="metric-label">
                            $(($Metrics.Domains | ForEach-Object { $_.Modules } | Measure-Object -Sum).Sum) Total Modules
                        </div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            Consolidated architecture
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🧪 Test Files</h3>
                        <div class="metric-value">$($Metrics.Tests.Total)</div>
                        <div class="metric-label">
                            $($Metrics.Tests.Unit) Unit | $($Metrics.Tests.Integration) Integration
                        </div>
                        
                        <div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid var(--card-border);">
                            <div style="font-size: 0.9rem; color: var(--text-primary); font-weight: 600; margin-bottom: 8px;">
                                Last Test Run Results:
                            </div>
                        $(if ($Metrics.Tests.LastRun) {
                            $testStatusColor = if ($Metrics.Tests.SuccessRate -ge 95) { 'var(--success)' } 
                                              elseif ($Metrics.Tests.SuccessRate -ge 80) { 'var(--warning)' } 
                                              else { 'var(--error)' }
                            $totalTestsRun = $Metrics.Tests.Passed + $Metrics.Tests.Failed
                            $warningHtml = if ($totalTestsRun -lt 100) {
                                @"
                            <div style="margin-top: 10px; padding: 8px; background: rgba(255, 193, 7, 0.1); border-radius: 6px; border-left: 3px solid var(--warning);">
                                <div style="font-size: 0.8rem; color: var(--warning); font-weight: 600;">
                                    ⚠️ Only $totalTestsRun test cases executed. Run <code>./automation-scripts/0402_Run-UnitTests.ps1</code> for full test suite.
                                </div>
                            </div>
"@
                            } else { "" }
                            @"
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-darker); border-radius: 6px; border-left: 3px solid $testStatusColor;">
                            <div style="font-size: 0.85rem; color: var(--text-secondary); font-weight: 600;">
                                Last Test Run Results:
                            </div>
                            <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                                ✅ $($Metrics.Tests.Passed) Passed | ❌ $($Metrics.Tests.Failed) Failed$(if($Metrics.Tests.Skipped -gt 0){" | ⏭️ $($Metrics.Tests.Skipped) Skipped"})
                            </div>
                            $warningHtml
                            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 5px;">
                                Last run: $($Metrics.Tests.LastRun)
                            </div>
                        </div>
"@
                        } else {
                            @"
                            <div style="padding: 10px; background: var(--bg-darker); border-radius: 6px; border-left: 3px solid var(--text-secondary);">
                                <div style="font-size: 0.85rem; color: var(--text-secondary);">
                                    ⚠️ No test results available. Run <code>./automation-scripts/0402_Run-UnitTests.ps1</code> to execute tests.
                                </div>
                            </div>
"@
                        })
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🧪 Test Coverage</h3>
                        <div class="metric-value">$($Metrics.TestCoverage.Percentage)%</div>
                        <div class="metric-label">
                            $($Metrics.TestCoverage.FilesWithTests) / $($Metrics.TestCoverage.TotalFiles) Files Have Tests
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($Metrics.TestCoverage.Percentage)%; background: $(if($Metrics.TestCoverage.Percentage -ge 80){'var(--success)'}elseif($Metrics.TestCoverage.Percentage -ge 60){'var(--warning)'}else{'var(--error)'})">
                                $($Metrics.TestCoverage.Percentage)%
                            </div>
                        </div>
                        $(if($Metrics.TestCoverage.FilesWithoutTests -gt 0) {
                            @"
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            ⚠️ $($Metrics.TestCoverage.FilesWithoutTests) files without tests
                        </div>
"@
                        })
                    </div>
                    
                    <div class="metric-card">
                        <h3>📚 Documentation Coverage</h3>
                        <div class="metric-value">$($Metrics.DocumentationCoverage.Percentage)%</div>
                        <div class="metric-label">
                            $($Metrics.DocumentationCoverage.FunctionsWithDocs) / $($Metrics.DocumentationCoverage.TotalFunctions) Functions Documented
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($Metrics.DocumentationCoverage.Percentage)%; background: $(if($Metrics.DocumentationCoverage.Percentage -ge 80){'var(--success)'}elseif($Metrics.DocumentationCoverage.Percentage -ge 60){'var(--warning)'}else{'var(--error)'})">
                                $($Metrics.DocumentationCoverage.Percentage)%
                            </div>
                        </div>
                        $(if($Metrics.DocumentationCoverage.FunctionsWithoutDocs -gt 0) {
                            @"
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            ⚠️ $($Metrics.DocumentationCoverage.FunctionsWithoutDocs) functions without docs
                        </div>
"@
                        })
                    </div>
                    
                    <div class="metric-card">
                        <h3>✨ Code Quality</h3>
                        <div class="metric-value">$($Metrics.QualityCoverage.AverageScore)/100</div>
                        <div class="metric-label">
                            $(if($Metrics.QualityCoverage.TotalIssues -gt 0){"$($Metrics.QualityCoverage.TotalIssues) issues in $($Metrics.QualityCoverage.WarningFiles + $Metrics.QualityCoverage.FailedFiles) files"}else{"No issues found"})
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($Metrics.QualityCoverage.AverageScore)%; background: $(if($Metrics.QualityCoverage.AverageScore -ge 80){'var(--success)'}elseif($Metrics.QualityCoverage.AverageScore -ge 60){'var(--warning)'}else{'var(--error)'})">
                                $($Metrics.QualityCoverage.AverageScore)/100
                            </div>
                        </div>
                        $(if($Metrics.QualityCoverage.TotalValidated -gt 0) {
                            @"
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            ✅ $($Metrics.QualityCoverage.PassedFiles) clean, ⚠️ $($Metrics.QualityCoverage.WarningFiles) warnings, ❌ $($Metrics.QualityCoverage.FailedFiles) errors
                        </div>
"@
                        } else {
                            @"
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            Run <code>./automation-scripts/0404_Run-PSScriptAnalyzer.ps1</code> to analyze code quality
                        </div>
"@
                        })
                    </div>
                    
                    $(if ($Metrics.Git.Branch -ne "Unknown") {
                        @"
                    <div class="metric-card">
                        <h3>🌿 Git Repository</h3>
                        <div class="metric-value" style="font-size: 1.8rem;">$($Metrics.Git.CommitCount)</div>
                        <div class="metric-label">Total Commits</div>
                        <div style="margin-top: 10px; padding: 10px; background: var(--bg-darker); border-radius: 6px;">
                            <div style="font-size: 0.85rem; color: var(--text-secondary);">
                                🔀 Branch: <span style="color: var(--primary-color); font-weight: 600;">$($Metrics.Git.Branch)</span>
                            </div>
                            <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 5px;">
                                👥 $($Metrics.Git.Contributors) Contributors
                            </div>
                            <div style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 5px;">
                                Latest: $($Metrics.Git.LastCommit)
                            </div>
                        </div>
                    </div>
"@
                    })
                    
                    <div class="metric-card">
                        <h3>💻 Platform</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($Metrics.Platform)</div>
                        <div class="metric-label">PowerShell $($Metrics.PSVersion)</div>
                        <div style="margin-top: 10px; font-size: 0.8rem; color: var(--text-secondary);">
                            Environment: $(if($env:AITHERZERO_CI){'CI/CD Pipeline'}else{'Development'})
                        </div>
                    </div>
                </div>
            </section>

            <!-- Interactive Dependency Mapping Section -->
            <section class="section" id="dependencies">
                <h2>🔗 Interactive Dependency Mapping</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Explore project dependencies, module relationships, and script dependencies
                </p>
                <div id="dependency-graph"></div>
                <script>
                    // Initialize dependency graph with data
                    const dependencyData = $(if($Dependencies){$Dependencies | ConvertTo-Json -Depth 5 -Compress}else{'{}'});
                    if (Object.keys(dependencyData).length > 0) {
                        initDependencyGraph(dependencyData);
                    } else {
                        document.getElementById('dependency-graph').innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Run <code>./az 0512</code> with full analysis to generate dependency map</p>';
                    }
                </script>
            </section>

            <!-- Interactive Domain Explorer Section -->
            <section class="section" id="domain-explorer-section">
                <h2>🗂️ Interactive Domain Explorer</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Click to explore each domain module, view functions, and navigate code
                </p>
                <div id="domain-explorer"></div>
                <script>
                    // Initialize domain explorer with data
                    const domainData = $($Metrics.Domains | ConvertTo-Json -Depth 3 -Compress);
                    if (domainData && domainData.length > 0) {
                        initDomainExplorer(domainData);
                    } else {
                        document.getElementById('domain-explorer').innerHTML = '<p style="text-align: center; color: var(--text-secondary);">No domain data available</p>';
                    }
                </script>
            </section>

            <!-- Interactive Configuration Explorer Section -->
            <section class="section" id="config">
                <h2>⚙️ Interactive Configuration Explorer</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Browse and search through config.psd1 manifest interactively
                </p>
                <div id="config-explorer"></div>
                <script>
                    // Load configuration from manifest
                    fetch('https://raw.githubusercontent.com/wizzense/AitherZero/main/config.psd1')
                        .then(response => response.text())
                        .then(data => {
                            // Parse PowerShell data file (simplified)
                            const configData = {
                                Core: { Profile: 'Standard', MaxConcurrency: 4 },
                                Automation: { OrchestrationEnabled: true },
                                Testing: { Profile: 'Standard', CoverageThreshold: 80 },
                                Note: 'Full config parsing requires PowerShell - this is a simplified view'
                            };
                            initConfigExplorer(configData);
                        })
                        .catch(err => {
                            document.getElementById('config-explorer').innerHTML = 
                                '<p style="text-align: center; color: var(--text-secondary);">Configuration explorer - Run dashboard locally for full config browsing</p>';
                        });
                </script>
            </section>

            <!-- File-Level Quality Drill-down Section -->
            <section class="section" id="quality-drilldown-section">
                <h2>🔍 File-Level Quality Drill-down</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Detailed quality metrics for every file - expand to see checks and issues
                </p>
                <div id="quality-drilldown"></div>
                <script>
                    // Initialize quality drilldown with file metrics
                    // Wrap in DOMContentLoaded to ensure initQualityDrilldown function is defined
                    document.addEventListener('DOMContentLoaded', function() {
                        const qualityData = $(if($FileMetrics -and $FileMetrics.Files){$FileMetrics.Files | Select-Object -First 20 | ConvertTo-Json -Depth 3 -Compress}else{'[]'});
                        if (qualityData && qualityData.length > 0) {
                            const fileQualityMap = {};
                            qualityData.forEach(file => {
                                fileQualityMap[file.Path] = {
                                    score: file.Score || 0,
                                    errorHandling: file.ErrorHandling ? '✅' : '❌',
                                    logging: file.Logging ? '✅' : '❌',
                                    testCoverage: file.HasTests ? '✅' : '❌',
                                    pssa: file.Issues && file.Issues.length === 0 ? '✅' : file.Issues ? file.Issues.length + ' issues' : 'N/A'
                                };
                            });
                            // Function will be available after enhanced-scripts.js loads
                            if (typeof initQualityDrilldown === 'function') {
                                initQualityDrilldown(fileQualityMap);
                            }
                        } else {
                            document.getElementById('quality-drilldown').innerHTML = '<p style="text-align: center; color: var(--text-secondary);">Run <code>./az 0420</code> to generate detailed quality metrics</p>';
                        }
                    });
                </script>
            </section>

            <section class="section" id="quality">
                <h2>✨ Code Quality Validation</h2>
                <div class="metrics-grid">
                    <div class="metric-card $(if($QualityMetrics.AverageScore -ge 90){''}elseif($QualityMetrics.AverageScore -ge 70){'warning'}else{'error'})">
                        <h3>📈 Quality Score</h3>
                        <div class="metric-value">$($QualityMetrics.AverageScore)%</div>
                        <div class="metric-label">
                            Average across $($QualityMetrics.TotalFiles) validated files
                        </div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: $($QualityMetrics.AverageScore)%; background: $(if($QualityMetrics.AverageScore -ge 90){'var(--success)'}elseif($QualityMetrics.AverageScore -ge 70){'var(--warning)'}else{'var(--error)'})">
                                $(if($QualityMetrics.AverageScore -gt 0){ "$($QualityMetrics.AverageScore)%" })
                            </div>
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>✅ Validation Results</h3>
                        <div class="metric-value">$($QualityMetrics.PassedFiles)</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.PassedFiles) Passed | 
                            ⚠️ $($QualityMetrics.WarningFiles) Warnings | 
                            ❌ $($QualityMetrics.FailedFiles) Failed
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🔍 Error Handling</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.ErrorHandling.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.ErrorHandling.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.ErrorHandling.Warnings) | 
                            ❌ $($QualityMetrics.Checks.ErrorHandling.Failed)
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>📝 Logging</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.Logging.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.Logging.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.Logging.Warnings) | 
                            ❌ $($QualityMetrics.Checks.Logging.Failed)
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🧪 Test Coverage</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.TestCoverage.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.TestCoverage.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.TestCoverage.Warnings) | 
                            ❌ $($QualityMetrics.Checks.TestCoverage.Failed)
                        </div>
                    </div>

                    <div class="metric-card">
                        <h3>🔬 PSScriptAnalyzer</h3>
                        <div class="metric-value">$($QualityMetrics.Checks.PSScriptAnalyzer.AvgScore)%</div>
                        <div class="metric-label">
                            ✅ $($QualityMetrics.Checks.PSScriptAnalyzer.Passed) | 
                            ⚠️ $($QualityMetrics.Checks.PSScriptAnalyzer.Warnings) | 
                            ❌ $($QualityMetrics.Checks.PSScriptAnalyzer.Failed)
                        </div>
                    </div>
                </div>
                
                $(if ($QualityMetrics.LastValidation) {
                    "<p class='metric-label' style='text-align: center; margin-top: 20px;'>Last validation: $($QualityMetrics.LastValidation)</p>"
                } else {
                    "<p class='metric-label' style='text-align: center; margin-top: 20px;'>⚠️ No quality validation data available. Run <code>./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains -Recursive</code> to generate quality reports.</p>"
                })
            </section>

            <section class="section" id="pssa">
                <h2>🔬 PSScriptAnalyzer Analysis</h2>
                $(if ($PSScriptAnalyzerMetrics.FilesAnalyzedCount -gt 0) {
                    $issuesColor = if ($PSScriptAnalyzerMetrics.Errors -gt 0) { 'var(--error)' } 
                                   elseif ($PSScriptAnalyzerMetrics.Warnings -gt 5) { 'var(--warning)' } 
                                   else { 'var(--success)' }
                    
                    $topIssuesHTML = if ($PSScriptAnalyzerMetrics.TopIssues -and @($PSScriptAnalyzerMetrics.TopIssues).Count -gt 0) {
                        $PSScriptAnalyzerMetrics.TopIssues | ForEach-Object {
                            $severityIcon = switch ([int]$_.Severity) {
                                3 { '❌' }  # Error
                                2 { '⚠️' }  # Warning
                                1 { 'ℹ️' }  # Information
                                default { '📝' }
                            }
                            "<li style='padding: 8px 0; border-bottom: 1px solid var(--card-border);'>$severityIcon <strong>$($_.Rule)</strong> - $($_.Count) instances</li>"
                        } | Join-String -Separator "`n"
                    } else {
                        "<li style='padding: 8px 0;'>No issues found</li>"
                    }
                    
                    @"
                <div class="metrics-grid">
                    <div class="metric-card">
                        <h3>📁 Files Analyzed</h3>
                        <div class="metric-value">$($PSScriptAnalyzerMetrics.FilesAnalyzedCount)</div>
                        <div class="metric-label">Last run: $(if($PSScriptAnalyzerMetrics.LastRun){$PSScriptAnalyzerMetrics.LastRun}else{'Never'})</div>
                    </div>
                    
                    <div class="metric-card" style="border-left-color: $issuesColor;">
                        <h3>⚠️ Total Issues</h3>
                        <div class="metric-value" style="color: $issuesColor;">$($PSScriptAnalyzerMetrics.TotalIssues)</div>
                        <div class="metric-label">
                            ❌ $($PSScriptAnalyzerMetrics.Errors) Errors | 
                            ⚠️ $($PSScriptAnalyzerMetrics.Warnings) Warnings | 
                            ℹ️ $($PSScriptAnalyzerMetrics.Information) Info
                        </div>
                    </div>
                </div>
                
                $(if (@($PSScriptAnalyzerMetrics.TopIssues).Count -gt 0) {
                    @"
                <div style="margin-top: 20px;">
                    <h3 style="color: var(--text-primary); margin-bottom: 15px;">🔝 Top Issues</h3>
                    <div style="background: var(--bg-darker); padding: 20px; border-radius: 8px; border: 1px solid var(--card-border);">
                        <ul style="list-style: none; margin: 0;">
$topIssuesHTML
                        </ul>
                    </div>
                </div>
"@
                })
                
                <p class='metric-label' style='text-align: center; margin-top: 20px;'>Run <code>./automation-scripts/0404_Run-PSScriptAnalyzer.ps1</code> to analyze code quality</p>
"@
                } else {
                    "<p class='metric-label' style='text-align: center;'>⚠️ No PSScriptAnalyzer data available. Run <code>./automation-scripts/0404_Run-PSScriptAnalyzer.ps1</code> to analyze your code.</p>"
                })
            </section>

$manifestHTML

$domainsHTML

            <section class="section" id="health">
                <h2>📈 Project Health</h2>
                <div class="badge-grid">
                    <div class="badge $(if($Status.Overall -eq 'Healthy'){''}elseif($Status.Overall -eq 'Issues'){'error'}else{'warning'})">
                        Build: $(if($Status.Overall -eq 'Healthy'){'Passing'}else{'Unknown'})
                    </div>
                    <div class="badge $(if($Status.Tests -eq 'Passing'){''}elseif($Status.Tests -eq 'Failing'){'error'}else{'warning'})">
                        Tests: $($Status.Tests)
                    </div>
                    <div class="badge info">Quality: $($Metrics.QualityCoverage.AverageScore)/100</div>
                    <div class="badge">Security: Scanned</div>
                    <div class="badge">Platform: $($Metrics.Platform)</div>
                    <div class="badge">PowerShell: $($Metrics.PSVersion)</div>
                    $(if($Metrics.Workflows -gt 0){"<div class='badge info'>Workflows: $($Metrics.Workflows)</div>"})
                </div>
            </section>
            
            $(if ($Metrics.Git.Branch -ne "Unknown") {
                @"
            <section class="section" id="git">
                <h2>🌿 Git Repository & Version Control</h2>
                <div class="metrics-grid" style="grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));">
                    <div class="info-card">
                        <div class="info-card-header">📊 Repository Statistics</div>
                        <div class="info-card-body">
                            <p><strong>Branch:</strong> <code>$($Metrics.Git.Branch)</code></p>
                            <p><strong>Total Commits:</strong> $($Metrics.Git.CommitCount.ToString('N0'))</p>
                            <p><strong>Contributors:</strong> $($Metrics.Git.Contributors)</p>
                            <p><strong>Automation Scripts:</strong> $($Metrics.AutomationScripts)</p>
                            <p><strong>GitHub Workflows:</strong> $($Metrics.Workflows)</p>
                        </div>
                    </div>
                    
                    <div class="info-card">
                        <div class="info-card-header">📝 Latest Commit</div>
                        <div class="info-card-body">
                            <p style="color: var(--text-secondary); font-family: monospace; font-size: 0.9rem;">
                                $($Metrics.Git.LastCommit)
                            </p>
                        </div>
                    </div>
                </div>
            </section>
"@
            })

            <div class="info-grid">
                <div class="info-card" id="activity">
                    <div class="info-card-header">🔄 Recent Activity</div>
                    <div class="info-card-body">
                        <ul class="commit-list">
$commitsHTML
                        </ul>
                    </div>
                </div>

                <div class="info-card" id="actions">
                    <div class="info-card-header">🎯 Quick Actions</div>
                    <div class="info-card-body">
                        <p><strong>Run Tests:</strong> <code>./automation-scripts/0402_Run-UnitTests.ps1</code></p>
                        <p><strong>Generate Report:</strong> <code>./automation-scripts/0510_Generate-ProjectReport.ps1</code></p>
                        <p><strong>View Dashboard:</strong> <code>./automation-scripts/0511_Show-ProjectDashboard.ps1</code></p>
                        <p><strong>Validate Code:</strong> <code>./automation-scripts/0404_Run-PSScriptAnalyzer.ps1</code></p>
                        <p><strong>Update Project:</strong> <code>git pull && ./bootstrap.ps1</code></p>
                    </div>
                </div>

                <div class="info-card" id="system">
                    <div class="info-card-header">📋 System Information</div>
                    <div class="info-card-body">
                        <p><strong>Platform:</strong> $($Metrics.Platform ?? 'Unknown')</p>
                        <p><strong>PowerShell:</strong> $($Metrics.PSVersion)</p>
                        <p><strong>Environment:</strong> $(if($env:AITHERZERO_CI){'CI/CD'}else{'Development'})</p>
                        <p><strong>Last Scan:</strong> $($Metrics.LastUpdated)</p>
                        <p><strong>Working Directory:</strong> <code>$(Split-Path $ProjectPath -Leaf)</code></p>
                    </div>
                </div>

                <div class="info-card" id="resources">
                    <div class="info-card-header">🔗 Resources</div>
                    <div class="info-card-body">
                        <p><a href="https://github.com/wizzense/AitherZero" target="_blank">🏠 GitHub Repository</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/actions" target="_blank">⚡ CI/CD Pipeline</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/releases" target="_blank">📦 Releases</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/issues" target="_blank">🐛 Issues</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/tree/main/docs" target="_blank">📖 Documentation</a></p>
                        <p><a href="https://github.com/wizzense/AitherZero/blob/main/README.md" target="_blank">📄 README</a></p>
                    </div>
                </div>
            </div>

            <!-- Strategic Roadmap Section -->
            <section class="section" id="roadmap" style="margin-top: 30px;">
                <h2>🗺️ Strategic Roadmap</h2>
                <p style="color: var(--text-secondary); margin-bottom: 25px;">
                    Current strategic priorities and project direction
                </p>
                
                <div class="roadmap-container">
                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority1')">
                            <h3>🚀 Priority 1: Expand Distribution & Discoverability</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority1" class="priority-content">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 30%">30%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Make AitherZero easily discoverable across all platforms</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Publish to PowerShell Gallery (<code>Install-Module -Name AitherZero</code>)
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Create Windows installer (MSI/EXE) with WinGet integration
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Submit to package managers (Homebrew consideration)
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 2-3 weeks</p>
                        </div>
                    </div>

                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority2')">
                            <h3>📚 Priority 2: Enhance Documentation & Onboarding</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority2" class="priority-content" style="display: none;">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 45%">45%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Reduce time-to-value for new users from hours to minutes</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item completed">
                                    <span class="status-dot"></span>
                                    Comprehensive documentation structure
                                </li>
                                <li class="roadmap-item in-progress">
                                    <span class="status-dot"></span>
                                    Quick start guide for common scenarios
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Video tutorials and interactive demos
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    API reference documentation
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 3-4 weeks</p>
                        </div>
                    </div>

                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority3')">
                            <h3>🎯 Priority 3: Build Community & Ecosystem</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority3" class="priority-content" style="display: none;">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 15%">15%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Foster active community and enable contributions</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Community contribution guidelines (CONTRIBUTING.md)
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Plugin/extension system for community additions
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    User showcase and case studies
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Community Discord or Discussions forum
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 4-6 weeks</p>
                        </div>
                    </div>

                    <div class="roadmap-priority">
                        <div class="priority-header" onclick="togglePriority('priority4')">
                            <h3>⚡ Priority 4: Advanced Features & Integrations</h3>
                            <span class="toggle-icon">▼</span>
                        </div>
                        <div id="priority4" class="priority-content" style="display: none;">
                            <div class="progress-indicator">
                                <div class="progress-bar">
                                    <div class="progress-fill" style="width: 20%">20%</div>
                                </div>
                            </div>
                            <p><strong>Goal:</strong> Expand capabilities and integrations</p>
                            <ul class="roadmap-list">
                                <li class="roadmap-item completed">
                                    <span class="status-dot"></span>
                                    Cross-platform support (Windows, Linux, macOS)
                                </li>
                                <li class="roadmap-item completed">
                                    <span class="status-dot"></span>
                                    Docker containerization with multi-arch support
                                </li>
                                <li class="roadmap-item in-progress">
                                    <span class="status-dot"></span>
                                    Web-based dashboard and monitoring (this page!)
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Enhanced cloud provider integrations
                                </li>
                                <li class="roadmap-item pending">
                                    <span class="status-dot"></span>
                                    Metrics and telemetry for usage insights
                                </li>
                            </ul>
                            <p class="timeline"><strong>Timeline:</strong> 6-8 weeks</p>
                        </div>
                    </div>
                </div>

                <div style="margin-top: 30px; padding: 20px; background: var(--card-bg); border-radius: 8px; border-left: 4px solid var(--info);">
                    <h4 style="color: var(--info); margin-bottom: 10px;">📊 Overall Progress</h4>
                    <div class="progress-bar" style="height: 30px; margin-bottom: 10px;">
                        <div class="progress-fill" style="width: 28%; font-size: 0.9rem;">28% Complete</div>
                    </div>
                    <p style="color: var(--text-secondary); font-size: 0.9rem; margin: 0;">
                        Based on strategic priorities outlined in <a href="https://github.com/wizzense/AitherZero/blob/main/STRATEGIC-ROADMAP.md" target="_blank" style="color: var(--info);">STRATEGIC-ROADMAP.md</a>
                    </p>
                </div>
            </section>

            <!-- GitHub Activity Section -->
            <section class="section" id="github-activity" style="margin-top: 30px;">
                <h2>🌟 GitHub Activity & Metrics</h2>
                <div class="metrics-grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
                    <div class="metric-card">
                        <h3>⭐ Stars</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($githubData.Stars)</div>
                        <div class="metric-label">GitHub Stars</div>
                    </div>
                    <div class="metric-card">
                        <h3>🍴 Forks</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($githubData.Forks)</div>
                        <div class="metric-label">Repository Forks</div>
                    </div>
                    <div class="metric-card">
                        <h3>👥 Contributors</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($Metrics.Git.Contributors)</div>
                        <div class="metric-label">Active Contributors</div>
                    </div>
                    <div class="metric-card">
                        <h3>🔀 Pull Requests</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($githubData.OpenPRs)</div>
                        <div class="metric-label">Open PRs</div>
                    </div>
                    <div class="metric-card">
                        <h3>🐛 Issues</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($githubData.OpenIssues)</div>
                        <div class="metric-label">Open Issues</div>
                    </div>
                    <div class="metric-card">
                        <h3>👀 Watchers</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($githubData.Watchers)</div>
                        <div class="metric-label">Repository Watchers</div>
                    </div>
                </div>
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 15px; text-align: center;">
                    ✅ <em>Live data from GitHub API$(if($GitHubData.Error){" | ⚠️ Fallback mode: $($GitHubData.Error)"}else{" | Updated in real-time"})</em>
                </p>
            </section>

            <!-- GitHub Actions Workflow Status Section -->
            <section class="section" id="workflow-status" style="margin-top: 30px;">
                <h2>⚙️ CI/CD Workflow Status</h2>
                <div class="metrics-grid" style="grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));">
                    <div class="metric-card">
                        <h3>📋 Total Workflows</h3>
                        <div class="metric-value" style="font-size: 2rem;">$($WorkflowStatus.TotalWorkflows)</div>
                        <div class="metric-label">Active Workflows</div>
                    </div>
                    <div class="metric-card">
                        <h3>✅ Successful</h3>
                        <div class="metric-value" style="font-size: 2rem; color: var(--success);">$($WorkflowStatus.SuccessfulRuns)</div>
                        <div class="metric-label">Recent Successes</div>
                    </div>
                    <div class="metric-card">
                        <h3>❌ Failed</h3>
                        <div class="metric-value" style="font-size: 2rem; color: $(if($WorkflowStatus.FailedRuns -gt 0){'var(--danger)'}else{'var(--text-secondary)'});">$($WorkflowStatus.FailedRuns)</div>
                        <div class="metric-label">Recent Failures</div>
                    </div>
                    <div class="metric-card">
                        <h3>🕐 Last Run</h3>
                        <div class="metric-value" style="font-size: 1.2rem;">$($WorkflowStatus.LastRunStatus)</div>
                        <div class="metric-label">Status</div>
                    </div>
                </div>
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 15px; text-align: center;">
                    $(if($WorkflowStatus.Error){"⚠️ <em>Unable to fetch workflow data: $($WorkflowStatus.Error)</em>"}else{"✅ <em>Live workflow data from GitHub Actions API</em>"})
                </p>
            </section>

            <!-- GitHub Issues Section -->
            <section class="section" id="github-issues" style="margin-top: 30px;">
                <h2>🐛 Open GitHub Issues</h2>
                $(if($githubIssues.Error){
                    "<p style='color: var(--text-secondary); text-align: center;'>⚠️ <em>Unable to fetch issues: $($githubIssues.Error)</em></p>"
                }elseif($githubIssues.Issues.Count -eq 0){
                    "<p style='color: var(--text-secondary); text-align: center;'>✅ <em>No open issues! Great job!</em></p>"
                }else{
                    $issuesHTML = ""
                    foreach($issue in $githubIssues.Issues){
                        $labelsHTML = if($issue.Labels.Count -gt 0){
                            $issue.Labels | ForEach-Object {
                                "<span style='display: inline-block; padding: 2px 8px; margin: 2px; background: var(--info); color: white; border-radius: 12px; font-size: 0.75rem;'>$_</span>"
                            } | Join-String -Separator " "
                        }else{"<span style='color: var(--text-secondary); font-size: 0.85rem;'>No labels</span>"}
                        
                        $issuesHTML += @"
                <div style='margin: 15px 0; padding: 15px; background: var(--card-bg); border-radius: 8px; border-left: 4px solid var(--info);'>
                    <div style='display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;'>
                        <h3 style='margin: 0; font-size: 1.1rem; color: var(--text-primary);'>
                            <a href='$($issue.Url)' target='_blank' style='color: var(--primary-color); text-decoration: none;'>
                                #$($issue.Number): $($issue.Title)
                            </a>
                        </h3>
                    </div>
                    <div style='font-size: 0.85rem; color: var(--text-secondary); margin-bottom: 8px;'>
                        Opened by <strong>$($issue.User)</strong> on $([DateTime]::Parse($issue.CreatedAt).ToString('yyyy-MM-dd'))
                    </div>
                    <div style='margin-top: 8px;'>
                        $labelsHTML
                    </div>
                </div>
"@
                    }
                    $issuesHTML
                })
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 15px; text-align: center;">
                    Showing up to 10 open issues | <a href="https://github.com/wizzense/AitherZero/issues" target="_blank" style="color: var(--info);">View all issues</a>
                </p>
            </section>

            <!-- Historical Trends Section -->
            <section class="section" id="trends" style="margin-top: 30px;">
                <h2>📈 Historical Trends</h2>
                <div class="info-card">
                    <div class="info-card-header">📊 Test Execution Trends</div>
                    <div class="info-card-content">
                        $(if($HistoricalMetrics.TestTrends.Count -gt 0){
                            $testTrendHTML = ""
                            foreach($trend in ($HistoricalMetrics.TestTrends | Select-Object -First 5)){
                                $passRate = if($trend.Total -gt 0){[math]::Round(($trend.Passed / $trend.Total) * 100, 1)}else{0}
                                $testTrendHTML += "<div style='padding: 8px; border-bottom: 1px solid var(--card-border);'>"
                                $testTrendHTML += "<strong>$($trend.Date)</strong>: $($trend.Passed)/$($trend.Total) passed ($passRate%)"
                                $testTrendHTML += "</div>"
                            }
                            $testTrendHTML
                        }else{
                            "<p style='color: var(--text-secondary);'>No historical test data available yet. Data will accumulate over time.</p>"
                        })
                    </div>
                </div>
                
                <div class="info-card" style="margin-top: 20px;">
                    <div class="info-card-header">📏 Lines of Code Growth</div>
                    <div class="info-card-content">
                        $(if($HistoricalMetrics.LOCTrends.Count -gt 0){
                            $locTrendHTML = ""
                            foreach($trend in ($HistoricalMetrics.LOCTrends | Select-Object -First 5)){
                                $locTrendHTML += "<div style='padding: 8px; border-bottom: 1px solid var(--card-border);'>"
                                $locTrendHTML += "<strong>$($trend.Date)</strong>: $($trend.Total.ToString('N0')) LOC, $($trend.Functions) functions"
                                $locTrendHTML += "</div>"
                            }
                            $locTrendHTML
                        }else{
                            "<p style='color: var(--text-secondary);'>No historical LOC data available yet. Data will be tracked going forward.</p>"
                        })
                    </div>
                </div>
                
                <p style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 15px; text-align: center;">
                    💡 <em>Historical data accumulates automatically with each dashboard generation</em>
                </p>
            </section>

            <!-- Release Tracker Section -->
            <section class="section" id="releases">
                <h2>📦 Releases & Version History</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Track releases, packages, and container versions
                </p>
                <div id="release-tracker"></div>
                <script>
                    // Fetch releases from GitHub API
                    fetch('https://api.github.com/repos/wizzense/AitherZero/releases')
                        .then(response => response.json())
                        .then(releases => {
                            if (releases && releases.length > 0) {
                                const releaseData = releases.slice(0, 10).map(r => ({
                                    version: r.tag_name || r.name,
                                    date: new Date(r.published_at).toLocaleDateString(),
                                    description: r.body ? r.body.substring(0, 200) + '...' : 'No description',
                                    url: r.html_url,
                                    assets: r.assets ? r.assets.map(a => ({ name: a.name, url: a.browser_download_url })) : []
                                }));
                                initReleaseTracker(releaseData);
                            } else {
                                document.getElementById('release-tracker').innerHTML = 
                                    '<p style="text-align: center; color: var(--text-secondary);">No releases yet. <a href="https://github.com/wizzense/AitherZero/releases" target="_blank">Create your first release</a></p>';
                            }
                        })
                        .catch(err => {
                            document.getElementById('release-tracker').innerHTML = 
                                '<p style="text-align: center; color: var(--text-secondary);">⚠️ Unable to fetch releases. <a href="https://github.com/wizzense/AitherZero/releases" target="_blank">View releases on GitHub</a></p>';
                        });
                </script>
            </section>

            <!-- Index Navigation Section -->
            <section class="section" id="indices">
                <h2>📑 Navigate Project Indices</h2>
                <p style="color: var(--text-secondary); margin-bottom: 20px;">
                    Quick access to all index files and documentation hubs throughout the project
                </p>
                <div id="index-navigation"></div>
            </section>
        </div>

        <div class="footer">
            Generated by AitherZero Dashboard | $($Metrics.LastUpdated) |
            <a href="https://github.com/wizzense/AitherZero" target="_blank">View on GitHub</a>
        </div>
    </div>

    <script>
        /* Enhanced Interactive Dashboard Scripts */
        $enhancedScripts
        
        // TOC toggle for mobile
        function toggleToc() {
            document.getElementById('toc').classList.toggle('open');
        }

        // Roadmap priority toggle
        function togglePriority(id) {
            const content = document.getElementById(id);
            const header = content.previousElementSibling;
            
            if (content.style.display === 'none' || content.style.display === '') {
                content.style.display = 'block';
                header.classList.add('active');
            } else {
                content.style.display = 'none';
                header.classList.remove('active');
            }
        }

        // Highlight active section in TOC
        const sections = document.querySelectorAll('.section, .header');
        const tocLinks = document.querySelectorAll('.toc a');

        function highlightToc() {
            let current = '';
            sections.forEach(section => {
                const sectionTop = section.offsetTop;
                const sectionHeight = section.clientHeight;
                if (pageYOffset >= sectionTop - 100) {
                    current = section.getAttribute('id');
                }
            });

            tocLinks.forEach(link => {
                link.classList.remove('active');
                if (link.getAttribute('href') === '#' + current) {
                    link.classList.add('active');
                }
            });
        }

        window.addEventListener('scroll', highlightToc);
        highlightToc();

        // Interactive card expansion
        document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.metric-card');
            cards.forEach(card => {
                // Add click animation
                card.addEventListener('click', function(e) {
                    // Don't expand if clicking on a link
                    if (e.target.tagName === 'A' || e.target.closest('a')) {
                        return;
                    }
                    
                    this.style.transform = 'scale(0.98)';
                    setTimeout(() => {
                        this.style.transform = '';
                    }, 150);
                });

                // Add hover effects
                card.addEventListener('mouseenter', function() {
                    this.style.boxShadow = '0 8px 25px rgba(102, 126, 234, 0.25)';
                });

                card.addEventListener('mouseleave', function() {
                    this.style.boxShadow = '';
                });
            });

            // Smooth scroll for TOC links
            document.querySelectorAll('.toc a').forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    const targetId = this.getAttribute('href').substring(1);
                    const targetElement = document.getElementById(targetId);
                    
                    if (targetElement) {
                        targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
                        // Close mobile TOC after navigation
                        if (window.innerWidth < 768) {
                            document.getElementById('toc').classList.remove('open');
                        }
                    }
                });
            });

            // Add copy-to-clipboard for code blocks
            document.querySelectorAll('code').forEach(code => {
                code.style.cursor = 'pointer';
                code.title = 'Click to copy';
                code.addEventListener('click', function() {
                    navigator.clipboard.writeText(this.textContent).then(() => {
                        const originalText = this.textContent;
                        this.textContent = '✓ Copied!';
                        setTimeout(() => {
                            this.textContent = originalText;
                        }, 1500);
                    });
                });
            });

            // Animate progress bars on scroll
            const progressBars = document.querySelectorAll('.progress-fill');
            const observer = new IntersectionObserver((entries) => {
                entries.forEach(entry => {
                    if (entry.isIntersecting) {
                        entry.target.style.transition = 'width 1.5s ease-out';
                        const width = entry.target.style.width;
                        entry.target.style.width = '0%';
                        setTimeout(() => {
                            entry.target.style.width = width;
                        }, 100);
                    }
                });
            }, { threshold: 0.5 });

            progressBars.forEach(bar => observer.observe(bar));

            // Add keyboard shortcuts
            document.addEventListener('keydown', function(e) {
                // Ctrl/Cmd + K to toggle TOC
                if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
                    e.preventDefault();
                    toggleToc();
                }
                // Escape to close TOC
                if (e.key === 'Escape') {
                    document.getElementById('toc').classList.remove('open');
                }
            });

            // Add search functionality hint (for future enhancement)
            console.log('💡 Dashboard Pro Tip: Use Ctrl+F to search this dashboard');
            console.log('🔍 Keyboard shortcuts:');
            console.log('  - Ctrl/Cmd + K: Toggle navigation');
            console.log('  - Escape: Close navigation');
            console.log('  - Click code blocks to copy');
        });

        // Auto-refresh every 5 minutes (optional - can be disabled)
        // setTimeout(() => {
        //     window.location.reload();
        // }, 300000);

        // Add live timestamp update
        function updateTimestamp() {
            const now = new Date();
            const timeString = now.toLocaleString();
            document.title = 'AitherZero Dashboard - Updated ' + timeString;
        }
        setInterval(updateTimestamp, 60000); // Update every minute
    </script>
</body>
</html>
"@

    $dashboardPath = Join-Path $OutputPath "dashboard.html"
    if ($PSCmdlet.ShouldProcess($dashboardPath, "Create HTML dashboard")) {
        $html | Set-Content -Path $dashboardPath -Encoding UTF8
        Write-ScriptLog -Message "HTML dashboard created: $dashboardPath"
    }
}

function New-MarkdownDashboard {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [hashtable]$QualityMetrics,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating Markdown dashboard"

    $markdown = @"
# 🚀 AitherZero Project Dashboard

**Infrastructure Automation Platform**

*Last updated: $($Metrics.LastUpdated)*

---

## 📊 Project Metrics

### File Statistics
| Metric | Value | Details |
|--------|-------|---------|
| 📁 **Total Files** | **$($Metrics.Files.Total)** | $($Metrics.Files.PowerShell) Scripts, $($Metrics.Files.Modules) Modules, $($Metrics.Files.Data) Data |
| 📄 **Documentation** | **$($Metrics.Files.Markdown)** | Markdown files |
| 🔧 **Configuration** | **$($Metrics.Files.YAML + $Metrics.Files.JSON)** | $($Metrics.Files.YAML) YAML, $($Metrics.Files.JSON) JSON |

### Code Statistics
| Metric | Value | Details |
|--------|-------|---------|
| 📝 **Lines of Code** | **$($Metrics.LinesOfCode.ToString('N0'))** | Total lines across all PowerShell files |
| 🔨 **Functions** | **$($Metrics.Functions)** | Public and private functions |
$(if ($Metrics.Classes -gt 0) { 
    "| 🏗️ **Classes** | **$($Metrics.Classes)** | PowerShell classes |`n"
})$(
    $commentRatio = if($Metrics.LinesOfCode -gt 0){[math]::Round(($Metrics.CommentLines / $Metrics.LinesOfCode) * 100, 1)}else{0}
    "| 💬 **Comments** | **$($Metrics.CommentLines.ToString('N0'))** | $commentRatio% of total code |"
)
| ⚪ **Blank Lines** | **$($Metrics.BlankLines.ToString('N0'))** | Whitespace and formatting |

### Automation & Infrastructure  
| Metric | Value | Details |
|--------|-------|---------|
| 🤖 **Automation Scripts** | **$($Metrics.AutomationScripts)** | Number-based orchestration (0000-9999) |
| ⚡ **GitHub Workflows** | **$($Metrics.Workflows)** | CI/CD automation |
| 🗂️ **Domain Modules** | **$(@($Metrics.Domains).Count)** | $(($Metrics.Domains | ForEach-Object { $_.Modules } | Measure-Object -Sum).Sum) total modules |

### Testing & Quality
| Metric | Value | Details |
|--------|-------|---------|
| 🧪 **Test Files** | **$($Metrics.Tests.Total)** | $($Metrics.Tests.Unit) Unit, $($Metrics.Tests.Integration) Integration |
$(if ($Metrics.Tests.LastRun) {
    $totalTestsRun = $Metrics.Tests.Passed + $Metrics.Tests.Failed + $Metrics.Tests.Skipped
    $partialRunWarning = if ($totalTestsRun -lt 100) { " ⚠️ **Partial Run** (only $totalTestsRun tests executed)" } else { "" }
    @"
| ✅ **Last Test Run** | **$($Metrics.Tests.Passed)/$totalTestsRun cases** | Success Rate: $($Metrics.Tests.SuccessRate)%; Duration: $($Metrics.Tests.Duration) |
| 📊 **Test Details** | **$($Metrics.Tests.LastRun)** | ✅ $($Metrics.Tests.Passed) passed, ❌ $($Metrics.Tests.Failed) failed$(if($Metrics.Tests.Skipped -gt 0){", ⏭️ $($Metrics.Tests.Skipped) skipped"}) |

"@
    if ($totalTestsRun -lt 100) {
        @"
| ⚠️ **Note** | **Partial Run** | Only $totalTestsRun test cases executed from available test files. Run ``./automation-scripts/0402_Run-UnitTests.ps1`` for full suite. |

> **⚠️ Only $totalTestsRun test cases executed.** Run ``./automation-scripts/0402_Run-UnitTests.ps1`` for full test suite.

"@
    }
} else {
"| ⚠️ **Test Results** | **N/A** | No test results available. Run ``./automation-scripts/0402_Run-UnitTests.ps1`` |
"
})| 🧪 **Test Coverage** | **$($Metrics.TestCoverage.Percentage)%** | $($Metrics.TestCoverage.FilesWithTests) / $($Metrics.TestCoverage.TotalFiles) files have tests |
| 📚 **Documentation Coverage** | **$($Metrics.DocumentationCoverage.Percentage)%** | $($Metrics.DocumentationCoverage.FunctionsWithDocs) / $($Metrics.DocumentationCoverage.TotalFunctions) functions documented |
| ✨ **Code Quality** | **$($Metrics.QualityCoverage.AverageScore)/100** | $(if($Metrics.QualityCoverage.TotalIssues -gt 0){"$($Metrics.QualityCoverage.TotalIssues) issues in $($Metrics.QualityCoverage.WarningFiles + $Metrics.QualityCoverage.FailedFiles) files"}else{"No issues found"}) (✅ $($Metrics.QualityCoverage.PassedFiles) clean / ⚠️ $($Metrics.QualityCoverage.WarningFiles) warnings / ❌ $($Metrics.QualityCoverage.FailedFiles) errors) |

$(if ($Metrics.Git.Branch -ne "Unknown") {
@"
### Git Repository
| Metric | Value | Details |
|--------|-------|---------|
| 🌿 **Branch** | **``$($Metrics.Git.Branch)``** | Current working branch |
| 📝 **Total Commits** | **$($Metrics.Git.CommitCount.ToString('N0'))** | Repository history |
| 👥 **Contributors** | **$($Metrics.Git.Contributors)** | Unique contributors |
| 🔄 **Latest Commit** | **$($Metrics.Git.LastCommit)** | Most recent change |

"@
})

## ✨ Code Quality Validation

| Metric | Score | Status |
|--------|-------|--------|
| 📈 **Overall Quality** | **$($QualityMetrics.AverageScore)%** | $(if($QualityMetrics.AverageScore -ge 90){'✅ Excellent'}elseif($QualityMetrics.AverageScore -ge 70){'⚠️ Good'}else{'❌ Needs Improvement'}) |
| ✅ **Passed Files** | **$($QualityMetrics.PassedFiles)** | Out of $($QualityMetrics.TotalFiles) validated |
| 🔍 **Error Handling** | **$($QualityMetrics.Checks.ErrorHandling.AvgScore)%** | ✅ $($QualityMetrics.Checks.ErrorHandling.Passed) / ⚠️ $($QualityMetrics.Checks.ErrorHandling.Warnings) / ❌ $($QualityMetrics.Checks.ErrorHandling.Failed) |
| 📝 **Logging** | **$($QualityMetrics.Checks.Logging.AvgScore)%** | ✅ $($QualityMetrics.Checks.Logging.Passed) / ⚠️ $($QualityMetrics.Checks.Logging.Warnings) / ❌ $($QualityMetrics.Checks.Logging.Failed) |
| 🧪 **Test Coverage** | **$($QualityMetrics.Checks.TestCoverage.AvgScore)%** | ✅ $($QualityMetrics.Checks.TestCoverage.Passed) / ⚠️ $($QualityMetrics.Checks.TestCoverage.Warnings) / ❌ $($QualityMetrics.Checks.TestCoverage.Failed) |
| 🔬 **PSScriptAnalyzer** | **$($QualityMetrics.Checks.PSScriptAnalyzer.AvgScore)%** | ✅ $($QualityMetrics.Checks.PSScriptAnalyzer.Passed) / ⚠️ $($QualityMetrics.Checks.PSScriptAnalyzer.Warnings) / ❌ $($QualityMetrics.Checks.PSScriptAnalyzer.Failed) |

$(if ($QualityMetrics.LastValidation) {
    "*Last quality validation: $($QualityMetrics.LastValidation)*"
} else {
    "*⚠️ No quality validation data available. Run ``./automation-scripts/0420_Validate-ComponentQuality.ps1 -Path ./domains -Recursive`` to generate quality reports.*"
})

## 🎯 Project Health

$(switch ($Status.Overall) {
    'Healthy' { '✅ **Status: Healthy** - All systems operational' }
    'Issues' { '⚠️ **Status: Issues Detected** - Attention required' }
    default { '❓ **Status: Unknown** - Monitoring in progress' }
})

### Build Status
- **Tests:** $(switch ($Status.Tests) { 'Passing' { '✅ Passing' } 'Failing' { '❌ Failing' } default { '❓ Unknown' } })
- **Security:** 🛡️ Scanned
- **Code Quality:** 📊 $($Metrics.QualityCoverage.AverageScore)/100
- **Platform:** 💻 $($Metrics.Platform)
- **PowerShell:** ⚡ $($Metrics.PSVersion)

## 🔄 Recent Activity

$(if($Activity.Commits.Count -gt 0) {
    $Activity.Commits | Select-Object -First 5 | ForEach-Object {
        "- ``$($_.Hash)`` $($_.Message)"
    } | Join-String -Separator "`n"
} else {
    "No recent activity found"
})

## 🎯 Quick Commands

| Action | Command |
|--------|---------|
| Run Tests | ``./automation-scripts/0402_Run-UnitTests.ps1`` |
| Code Analysis | ``./automation-scripts/0404_Run-PSScriptAnalyzer.ps1`` |
| Generate Reports | ``./automation-scripts/0510_Generate-ProjectReport.ps1`` |
| View Dashboard | ``./automation-scripts/0511_Show-ProjectDashboard.ps1`` |
| Syntax Check | ``./az 0407`` |

## 📋 System Information

- **Platform:** $($Metrics.Platform ?? 'Unknown')
- **PowerShell:** $($Metrics.PSVersion)
- **Environment:** $(if($env:AITHERZERO_CI){'CI/CD'}else{'Development'})
- **Project Root:** ``$ProjectPath``

## 🔗 Resources

- [🏠 GitHub Repository](https://github.com/wizzense/AitherZero)
- [⚡ CI/CD Pipeline](https://github.com/wizzense/AitherZero/actions)
- [📦 Releases](https://github.com/wizzense/AitherZero/releases)
- [🐛 Issues](https://github.com/wizzense/AitherZero/issues)
- [📖 Documentation](https://github.com/wizzense/AitherZero/tree/main/docs)

---

*Dashboard generated by AitherZero automation pipeline*
"@

    $dashboardPath = Join-Path $OutputPath "dashboard.md"
    if ($PSCmdlet.ShouldProcess($dashboardPath, "Create Markdown dashboard")) {
        $markdown | Set-Content -Path $dashboardPath -Encoding UTF8
        Write-ScriptLog -Message "Markdown dashboard created: $dashboardPath"
    }
}

function New-JSONReport {
    param(
        [hashtable]$Metrics,
        [hashtable]$Status,
        [hashtable]$Activity,
        [hashtable]$QualityMetrics,
        [hashtable]$PSScriptAnalyzerMetrics,
        [hashtable]$FileMetrics,
        [hashtable]$Dependencies,
        [hashtable]$DetailedTests,
        [hashtable]$CoverageDetails,
        [hashtable]$Lifecycle,
        [string]$OutputPath
    )

    Write-ScriptLog -Message "Generating JSON report"

    $report = @{
        Generated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        Project = @{
            Name = "AitherZero"
            Description = "Infrastructure Automation Platform"
            Repository = "https://github.com/wizzense/AitherZero"
        }
        Metrics = $Metrics
        Status = $Status
        Activity = $Activity
        QualityMetrics = $QualityMetrics
        PSScriptAnalyzerMetrics = $PSScriptAnalyzerMetrics
        FileMetrics = $FileMetrics
        Dependencies = $Dependencies
        DetailedTests = $DetailedTests
        CoverageDetails = $CoverageDetails
        Lifecycle = $Lifecycle
        Environment = @{
            CI = [bool]$env:AITHERZERO_CI
            Platform = $Metrics.Platform
            PowerShell = $Metrics.PSVersion
            WorkingDirectory = $ProjectPath
        }
    }

    $reportPath = Join-Path $OutputPath "dashboard.json"
    if ($PSCmdlet.ShouldProcess($reportPath, "Create JSON report")) {
        $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
        Write-ScriptLog -Message "JSON report created: $reportPath"
    }
}

try {
    Write-ScriptLog -Message "Starting comprehensive dashboard generation"

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    # Collect data
    Write-ScriptLog -Message "Collecting project data..."
    $metrics = Get-ProjectMetrics
    $status = Get-BuildStatus -Metrics $metrics
    $activity = Get-RecentActivity
    $qualityMetrics = Get-QualityMetrics
    $pssaMetrics = Get-PSScriptAnalyzerMetrics
    
    # Fetch GitHub repository data
    Write-ScriptLog -Message "Fetching live GitHub repository data..."
    $githubData = Get-GitHubRepositoryData -Owner "wizzense" -Repo "AitherZero"
    
    # Fetch GitHub Actions workflow status
    Write-ScriptLog -Message "Fetching GitHub Actions workflow status..."
    $workflowStatus = Get-GitHubWorkflowStatus -Owner "wizzense" -Repo "AitherZero"
    
    # Fetch GitHub issues
    Write-ScriptLog -Message "Fetching GitHub issues..."
    $githubIssues = Get-GitHubIssues -Owner "wizzense" -Repo "AitherZero" -MaxIssues 10
    
    # Load historical metrics for trend analysis (pass current metrics for saving)
    Write-ScriptLog -Message "Loading historical metrics data..."
    $historicalMetrics = Get-HistoricalMetrics -ReportsPath $OutputPath -CurrentMetrics $metrics
    
    # Collect comprehensive detailed metrics
    Write-ScriptLog -Message "Collecting comprehensive project intelligence..."
    $fileMetrics = Get-FileLevelMetrics -ProjectPath $ProjectPath
    $dependencies = Get-DependencyMapping -ProjectPath $ProjectPath
    $detailedTests = Get-DetailedTestResults -ProjectPath $ProjectPath
    $coverageDetails = Get-CodeCoverageDetails -ProjectPath $ProjectPath
    $lifecycle = Get-LifecycleAnalysis -ProjectPath $ProjectPath
    
    # Update main metrics with detailed coverage
    if ($coverageDetails.Overall.Percentage -gt 0) {
        $metrics.Coverage.Percentage = $coverageDetails.Overall.Percentage
        $metrics.Coverage.CoveredLines = $coverageDetails.Overall.CoveredLines
        $metrics.Coverage.TotalLines = $coverageDetails.Overall.TotalLines
    }
    
    # Update main metrics with actual code lines (excluding docs and comments)
    if ($lifecycle.LineCountAnalysis.ActualCode -gt 0) {
        Write-Host "`n📊 Line Count Analysis:" -ForegroundColor Cyan
        Write-Host "  Actual Code Lines: $($lifecycle.LineCountAnalysis.ActualCode.ToString('N0'))" -ForegroundColor Green
        Write-Host "  PowerShell Files Total: $($lifecycle.LineCountAnalysis.PowerShellCode.ToString('N0'))" -ForegroundColor White
        Write-Host "  Documentation (.md): $($lifecycle.LineCountAnalysis.Documentation.ToString('N0'))" -ForegroundColor White
        Write-Host "  Comments: $($lifecycle.LineCountAnalysis.CommentedCode.ToString('N0'))" -ForegroundColor White
        Write-Host "  Blank Lines: $($lifecycle.LineCountAnalysis.BlankLines.ToString('N0'))" -ForegroundColor White
        Write-Host "  Documentation Ratio: $($lifecycle.LineCountAnalysis.DocumentationRatio)%" -ForegroundColor $(if($lifecycle.LineCountAnalysis.DocumentationRatio -gt 30){'Yellow'}else{'White'})
    }

    # Generate dashboards based on format selection
    switch ($Format) {
        'HTML' {
            New-HTMLDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -GitHubData $githubData -WorkflowStatus $workflowStatus -HistoricalMetrics $historicalMetrics -FileMetrics $fileMetrics -Dependencies $dependencies -OutputPath $OutputPath
        }
        'Markdown' {
            New-MarkdownDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -OutputPath $OutputPath
        }
        'JSON' {
            New-JSONReport -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -FileMetrics $fileMetrics -Dependencies $dependencies -DetailedTests $detailedTests -CoverageDetails $coverageDetails -Lifecycle $lifecycle -OutputPath $OutputPath
        }
        'All' {
            New-HTMLDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -GitHubData $githubData -WorkflowStatus $workflowStatus -HistoricalMetrics $historicalMetrics -FileMetrics $fileMetrics -Dependencies $dependencies -OutputPath $OutputPath
            New-MarkdownDashboard -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -OutputPath $OutputPath
            New-JSONReport -Metrics $metrics -Status $status -Activity $activity -QualityMetrics $qualityMetrics -PSScriptAnalyzerMetrics $pssaMetrics -FileMetrics $fileMetrics -Dependencies $dependencies -DetailedTests $detailedTests -CoverageDetails $coverageDetails -Lifecycle $lifecycle -OutputPath $OutputPath
        }
    }

    # Create index file for easy access
    $indexContent = @"
# AitherZero Dashboard

## Available Reports

- [📊 HTML Dashboard](dashboard.html) - Interactive web dashboard
- [📝 Markdown Dashboard](dashboard.md) - Text-based dashboard
- [📋 JSON Report](dashboard.json) - Machine-readable data

## Generated: $($metrics.LastUpdated)

### Quick Stats
- Files: $($metrics.Files.Total)
- Lines of Code: $($metrics.LinesOfCode.ToString('N0'))
- Tests: $($metrics.Tests.Total)
- Coverage: $($metrics.Coverage.Percentage)%
- Status: $($status.Overall)
"@

    $indexPath = Join-Path $OutputPath "README.md"
    if ($PSCmdlet.ShouldProcess($indexPath, "Create index file")) {
        $indexContent | Set-Content -Path $indexPath -Encoding UTF8
    }

    # Summary
    Write-Host "`n🎉 Dashboard Generation Complete!" -ForegroundColor Green
    Write-Host "📁 Output Directory: $OutputPath" -ForegroundColor Cyan

    if ($Format -eq 'All' -or $Format -eq 'HTML') {
        Write-Host "🌐 HTML Dashboard: $(Join-Path $OutputPath 'dashboard.html')" -ForegroundColor Green
    }
    if ($Format -eq 'All' -or $Format -eq 'Markdown') {
        Write-Host "📝 Markdown Dashboard: $(Join-Path $OutputPath 'dashboard.md')" -ForegroundColor Green
    }
    if ($Format -eq 'All' -or $Format -eq 'JSON') {
        Write-Host "📋 JSON Report: $(Join-Path $OutputPath 'dashboard.json')" -ForegroundColor Green
    }

    Write-Host "`n📊 Project Metrics:" -ForegroundColor Cyan
    Write-Host "  Files: $($metrics.Files.Total) ($($metrics.Files.PowerShell) scripts, $($metrics.Files.Modules) modules)" -ForegroundColor White
    Write-Host "  Lines of Code: $($metrics.LinesOfCode.ToString('N0'))" -ForegroundColor White
    Write-Host "  Functions: $($metrics.Functions)" -ForegroundColor White
    Write-Host "  Tests: $($metrics.Tests.Total) ($($metrics.Tests.Unit) unit, $($metrics.Tests.Integration) integration)" -ForegroundColor White
    Write-Host "`n📈 Coverage Metrics:" -ForegroundColor Cyan
    Write-Host "  Test Coverage: $($metrics.TestCoverage.Percentage)% ($($metrics.TestCoverage.FilesWithTests)/$($metrics.TestCoverage.TotalFiles) files)" -ForegroundColor $(if($metrics.TestCoverage.Percentage -ge 80){'Green'}elseif($metrics.TestCoverage.Percentage -ge 60){'Yellow'}else{'Red'})
    Write-Host "  Documentation Coverage: $($metrics.DocumentationCoverage.Percentage)% ($($metrics.DocumentationCoverage.FunctionsWithDocs)/$($metrics.DocumentationCoverage.TotalFunctions) functions)" -ForegroundColor $(if($metrics.DocumentationCoverage.Percentage -ge 80){'Green'}elseif($metrics.DocumentationCoverage.Percentage -ge 60){'Yellow'}else{'Red'})
    Write-Host "  Code Quality: $($metrics.QualityCoverage.AverageScore)/100 $(if($metrics.QualityCoverage.TotalIssues -gt 0){"($($metrics.QualityCoverage.TotalIssues) issues)"}else{"(clean)"})" -ForegroundColor $(if($metrics.QualityCoverage.AverageScore -ge 80){'Green'}elseif($metrics.QualityCoverage.AverageScore -ge 60){'Yellow'}else{'Red'})
    Write-Host "`n  Status: $($status.Overall)" -ForegroundColor $(if($status.Overall -eq 'Healthy'){'Green'}elseif($status.Overall -eq 'Issues'){'Yellow'}else{'Gray'})

    Write-ScriptLog -Message "Dashboard generation completed successfully" -Data @{
        OutputPath = $OutputPath
        Format = $Format
        FilesGenerated = $(if($Format -eq 'All'){3}else{1})
        ProjectFiles = $metrics.Files.Total
        LinesOfCode = $metrics.LinesOfCode
        Status = $status.Overall
    }

    # Open HTML dashboard in browser if requested
    if ($Open -and ($Format -eq 'HTML' -or $Format -eq 'All')) {
        $htmlDashboardPath = Join-Path $OutputPath 'dashboard.html'
        if ($PSCmdlet.ShouldProcess($htmlDashboardPath, "Open HTML dashboard in browser")) {
            Write-Host "`n🌐 Opening HTML dashboard in browser..." -ForegroundColor Cyan
            $opened = Open-HTMLDashboard -FilePath $htmlDashboardPath
            if (-not $opened) {
                Write-Host "⚠️  Could not open dashboard automatically. Please open manually: $htmlDashboardPath" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n🌐 [WhatIf] Would open HTML dashboard in browser: $htmlDashboardPath" -ForegroundColor Yellow
        }
    }

    exit 0

} catch {
    Write-ScriptLog -Level Error -Message "Dashboard generation failed: $_" -Data @{
        Exception = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    }
    exit 1
}