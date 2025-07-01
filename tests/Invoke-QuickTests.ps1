#Requires -Version 7.0
<#
.SYNOPSIS
    Simplified test runner with coverage enforcement for AitherZero
.DESCRIPTION
    Streamlined test execution with mandatory coverage thresholds, optimized for development workflow.
    Designed for rapid feedback during development with enforced quality gates.
.PARAMETER TestCategory
    Test category to run: Unit, Integration, Critical, E2E, All
.PARAMETER MinCoverage
    Minimum code coverage percentage required (default: 80%)
.PARAMETER FailFast
    Stop on first test failure
.PARAMETER ShowCoverage
    Display detailed coverage report
.PARAMETER OutputFormat
    Output format: Console, JSON, HTML
.PARAMETER CreateIssues
    Create GitHub issues for failures (requires GitHub CLI)
.PARAMETER CI
    Run in CI/CD optimized mode
.EXAMPLE
    ./tests/Invoke-QuickTests.ps1 -TestCategory Unit -MinCoverage 85
.EXAMPLE
    ./tests/Invoke-QuickTests.ps1 -TestCategory Critical -ShowCoverage -FailFast
.EXAMPLE
    ./tests/Invoke-QuickTests.ps1 -TestCategory All -CI -CreateIssues
#>

[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Critical', 'E2E', 'All')]
    [string]$TestCategory = 'Unit',
    
    [ValidateRange(0, 100)]
    [int]$MinCoverage = 80,
    
    [switch]$FailFast,
    [switch]$ShowCoverage,
    [switch]$CreateIssues,
    [switch]$CI,
    
    [ValidateSet('Console', 'JSON', 'HTML')]
    [string]$OutputFormat = 'Console',
    
    [string]$OutputPath = './tests/TestResults/quick-tests'
)

# Initialize environment
$ErrorActionPreference = 'Stop'
$script:StartTime = Get-Date

# Ensure output directory exists
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# Import parallel execution module if available
$script:ParallelAvailable = $false
try {
    $projectRoot = Split-Path $PSScriptRoot -Parent
    $parallelModulePath = Join-Path $projectRoot "aither-core/modules/ParallelExecution"
    
    if (Test-Path $parallelModulePath) {
        Import-Module $parallelModulePath -Force -ErrorAction Stop
        $script:ParallelAvailable = $true
        Write-Verbose "ParallelExecution module loaded successfully"
    }
} catch {
    Write-Verbose "ParallelExecution module not available: $_"
}

function Write-QuickLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    if ($CI) {
        # CI mode - structured output
        $timestamp = Get-Date -Format 'HH:mm:ss'
        Write-Host "[$timestamp] [$Level] $Message"
    } else {
        # Interactive mode - colorized output
        $color = switch ($Level) {
            'INFO' { 'Cyan' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            'SUCCESS' { 'Green' }
        }
        
        $icon = switch ($Level) {
            'INFO' { "ℹ️" }
            'WARN' { "⚠️" }
            'ERROR' { "❌" }
            'SUCCESS' { "✅" }
        }
        
        Write-Host "$icon $Message" -ForegroundColor $color
    }
}

function Get-OptimalParallelSettings {
    <#
    .SYNOPSIS
    Calculate optimal parallel execution settings for quick tests
    #>
    param([switch]$CI)
    
    $processorCount = [Environment]::ProcessorCount
    $availableMemoryGB = 8  # Default assumption
    
    # Try to get actual memory (cross-platform)
    try {
        if ($IsWindows) {
            $memory = Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty TotalPhysicalMemory
            $availableMemoryGB = [math]::Round($memory / 1GB, 1)
        } elseif ($IsLinux) {
            $memInfo = Get-Content /proc/meminfo | Where-Object { $_ -match '^MemTotal' }
            if ($memInfo -match '(\d+)\s+kB') {
                $availableMemoryGB = [math]::Round([int]$matches[1] / 1MB, 1)
            }
        }
    } catch {
        # Use default if detection fails
    }
    
    # Calculate optimal settings
    $maxParallel = if ($CI) {
        # CI environments - be conservative for quick tests
        [math]::Min($processorCount, 3)
    } else {
        # Local development - more aggressive for quick feedback
        if ($availableMemoryGB -lt 4) {
            [math]::Max([math]::Floor($processorCount / 2), 2)
        } elseif ($availableMemoryGB -lt 8) {
            [math]::Max([math]::Floor($processorCount * 0.75), 2)
        } else {
            [math]::Min($processorCount, 6)  # Cap at 6 for quick tests
        }
    }
    
    return @{
        MaxParallel = [int]$maxParallel
        ProcessorCount = $processorCount
        AvailableMemoryGB = $availableMemoryGB
        RecommendParallel = $processorCount -ge 4 -and -not $CI  # Only recommend parallel for multi-core non-CI
    }
}

function Get-TestFilesForParallel {
    <#
    .SYNOPSIS
    Get test files organized for optimal parallel execution
    #>
    param([string[]]$TestPaths)
    
    $testFiles = @()
    foreach ($path in $TestPaths) {
        if (Test-Path $path) {
            $files = Get-ChildItem -Path $path -Filter "*.Tests.ps1" -Recurse -File
            $testFiles += $files.FullName
        }
    }
    
    if ($testFiles.Count -eq 0) {
        return @()
    }
    
    # For quick tests, group smaller test files together
    # Sort by estimated size (small files first for better load balancing)
    $fileInfo = $testFiles | ForEach-Object {
        $size = if (Test-Path $_) { (Get-Item $_).Length } else { 0 }
        @{
            Path = $_
            Size = $size
        }
    } | Sort-Object Size
    
    return $fileInfo | ForEach-Object { $_.Path }
}

function Get-OptimalTestGroups {
    <#
    .SYNOPSIS
    Group test files for optimal parallel execution
    #>
    param(
        [string[]]$TestFiles,
        [int]$MaxParallel
    )
    
    if ($TestFiles.Count -le $MaxParallel) {
        # Each file gets its own group
        return $TestFiles | ForEach-Object { @($_) }
    }
    
    # For quick tests, create balanced groups
    $groups = @()
    $filesPerGroup = [math]::Ceiling($TestFiles.Count / $MaxParallel)
    
    for ($i = 0; $i -lt $TestFiles.Count; $i += $filesPerGroup) {
        $endIndex = [math]::Min($i + $filesPerGroup - 1, $TestFiles.Count - 1)
        $group = $TestFiles[$i..$endIndex]
        $groups += ,$group
    }
    
    return $groups
}

function Test-Prerequisites {
    Write-QuickLog "Checking prerequisites..." -Level 'INFO'
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "PowerShell 7.0+ required, found $($PSVersionTable.PSVersion)"
    }
    
    # Check for Pester
    if (-not (Get-Module Pester -ListAvailable | Where-Object Version -ge '5.0')) {
        Write-QuickLog "Installing Pester 5.0+..." -Level 'INFO'
        Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.0
    }
    
    # Check project structure
    $requiredPaths = @(
        'aither-core/aither-core.ps1',
        'tests',
        'aither-core/modules'
    )
    
    foreach ($path in $requiredPaths) {
        if (-not (Test-Path $path)) {
            throw "Required path not found: $path"
        }
    }
    
    Write-QuickLog "Prerequisites validated" -Level 'SUCCESS'
}

function Invoke-QuickTestExecution {
    Write-QuickLog "Executing $TestCategory tests..." -Level 'INFO'
    
    # Set test paths based on category
    $testPaths = switch ($TestCategory) {
        'Unit' { @('tests/Unit') }
        'Integration' { @('tests/Integration') }
        'Critical' { @('tests/Critical') }
        'E2E' { @('tests/E2E') }
        'All' { @('tests/Unit', 'tests/Integration', 'tests/Critical', 'tests/E2E') }
    }
    
    # Filter to existing paths
    $existingTestPaths = $testPaths | Where-Object { Test-Path $_ }
    if ($existingTestPaths.Count -eq 0) {
        throw "No test files found for category: $TestCategory"
    }
    
    # Determine execution strategy
    $parallelSettings = Get-OptimalParallelSettings -CI:$CI
    $testFiles = Get-TestFilesForParallel -TestPaths $existingTestPaths
    
    # Parallel execution decision for quick tests
    $useParallel = $script:ParallelAvailable -and 
                   $parallelSettings.RecommendParallel -and 
                   $testFiles.Count -gt 2 -and
                   -not ($ShowCoverage -or $MinCoverage -gt 0)  # Coverage complicates parallel execution
    
    if ($useParallel) {
        Write-QuickLog "⚡ Using PARALLEL execution for optimal performance" -Level 'SUCCESS'
        Write-QuickLog "CPU cores: $($parallelSettings.ProcessorCount), Parallel threads: $($parallelSettings.MaxParallel)" -Level 'INFO'
        
        # Group test files for parallel execution
        $testGroups = Get-OptimalTestGroups -TestFiles $testFiles -MaxParallel $parallelSettings.MaxParallel
        Write-QuickLog "Executing $($testFiles.Count) test files in $($testGroups.Count) parallel groups" -Level 'INFO'
        
        # Execute tests in parallel using our ParallelExecution module
        $parallelResults = Invoke-ParallelPesterTests -TestPaths $testGroups -ThrottleLimit $parallelSettings.MaxParallel -OutputFormat 'Minimal'
        
        # Merge parallel results into standard Pester result format
        $testResult = Merge-ParallelTestResults -TestResults $parallelResults
        
        # Convert merged results to Pester-compatible format for the rest of the pipeline
        $pesterCompatibleResult = [PSCustomObject]@{
            TotalCount = $testResult.TotalTests
            PassedCount = $testResult.Passed
            FailedCount = $testResult.Failed
            SkippedCount = $testResult.Skipped
            Failed = $testResult.Failures
            CodeCoverage = $null  # Not available in parallel mode
            TotalTime = $testResult.TotalTime
        }
        
        return $pesterCompatibleResult
    } else {
        # Sequential execution with full Pester configuration
        Write-QuickLog "📋 Using SEQUENTIAL execution for comprehensive coverage analysis" -Level 'INFO'
        
        # Configure Pester
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Exit = $false
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = if ($CI) { 'Minimal' } else { 'Normal' }
        $pesterConfig.TestResult.Enabled = $true
        $pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "test-results.xml"
        $pesterConfig.TestResult.OutputFormat = 'NUnitXml'
        
        # Configure coverage
        if ($ShowCoverage -or $MinCoverage -gt 0) {
            $pesterConfig.CodeCoverage.Enabled = $true
            $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "coverage.xml"
            $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
            
            # Coverage paths based on test category
            $coveragePaths = switch ($TestCategory) {
                'Unit' {
                    @(
                        'aither-core/modules/*/Public/*.ps1',
                        'aither-core/modules/*/Private/*.ps1',
                        'aither-core/shared/*.ps1'
                    )
                }
                'Integration' {
                    @(
                        'aither-core/*.ps1',
                        'aither-core/modules/*/*.psm1',
                        'aither-core/shared/*.ps1'
                    )
                }
                'Critical' {
                    @(
                        'Start-AitherZero.ps1',
                        'aither-core/aither-core.ps1',
                        'aither-core/modules/Logging/*.ps1',
                        'aither-core/modules/TestingFramework/*.ps1'
                    )
                }
                'E2E' {
                    @(
                        'Start-AitherZero.ps1',
                        'aither-core/aither-core.ps1'
                    )
                }
                'All' {
                    @(
                        'Start-AitherZero.ps1',
                        'aither-core/*.ps1',
                        'aither-core/modules/*/*.ps1',
                        'aither-core/modules/*/*.psm1',
                        'aither-core/shared/*.ps1'
                    )
                }
            }
            
            $pesterConfig.CodeCoverage.Path = $coveragePaths
        }
        
        $pesterConfig.Run.Path = $existingTestPaths
        
        # Configure fail-fast
        if ($FailFast) {
            $pesterConfig.Run.Exit = $true
        }
        
        # Execute tests
        Write-QuickLog "Running tests from: $($existingTestPaths -join ', ')" -Level 'INFO'
        $testResults = Invoke-Pester -Configuration $pesterConfig
        
        return $testResults
    }
}

function Test-CoverageThreshold {
    param([object]$TestResults)
    
    if (-not $TestResults.CodeCoverage -or $MinCoverage -eq 0) {
        Write-QuickLog "Coverage validation skipped" -Level 'INFO'
        return $true
    }
    
    $coverage = $TestResults.CodeCoverage
    $coveragePercent = if ($coverage.NumberOfCommandsAnalyzed -gt 0) {
        [math]::Round(($coverage.NumberOfCommandsExecuted / $coverage.NumberOfCommandsAnalyzed) * 100, 2)
    } else {
        0
    }
    
    Write-QuickLog "Code Coverage: $coveragePercent% (Commands: $($coverage.NumberOfCommandsExecuted)/$($coverage.NumberOfCommandsAnalyzed))" -Level 'INFO'
    
    if ($coveragePercent -lt $MinCoverage) {
        Write-QuickLog "Coverage below threshold! Required: $MinCoverage%, Actual: $coveragePercent%" -Level 'ERROR'
        
        # Show missed coverage details
        if ($coverage.MissedCommands.Count -gt 0) {
            Write-QuickLog "Top missed commands:" -Level 'WARN'
            $coverage.MissedCommands | Select-Object -First 10 | ForEach-Object {
                Write-QuickLog "  • $($_.File):$($_.Line) - $($_.Command)" -Level 'WARN'
            }
        }
        
        return $false
    } else {
        Write-QuickLog "Coverage threshold met: $coveragePercent% >= $MinCoverage%" -Level 'SUCCESS'
        return $true
    }
}

function Export-QuickTestResults {
    param(
        [object]$TestResults,
        [bool]$CoveragePass
    )
    
    $duration = (Get-Date) - $script:StartTime
    $summary = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        TestCategory = $TestCategory
        Duration = @{
            TotalSeconds = $duration.TotalSeconds
            Formatted = "$($duration.Minutes)m $($duration.Seconds)s"
        }
        Tests = @{
            Total = $TestResults.TotalCount
            Passed = $TestResults.PassedCount
            Failed = $TestResults.FailedCount
            Skipped = $TestResults.SkippedCount
            PassRate = if ($TestResults.TotalCount -gt 0) { 
                [math]::Round(($TestResults.PassedCount / $TestResults.TotalCount) * 100, 2) 
            } else { 0 }
        }
        Coverage = @{
            Enabled = ($null -ne $TestResults.CodeCoverage)
            Percentage = if ($TestResults.CodeCoverage) {
                if ($TestResults.CodeCoverage.NumberOfCommandsAnalyzed -gt 0) {
                    [math]::Round(($TestResults.CodeCoverage.NumberOfCommandsExecuted / $TestResults.CodeCoverage.NumberOfCommandsAnalyzed) * 100, 2)
                } else { 0 }
            } else { 0 }
            Threshold = $MinCoverage
            Pass = $CoveragePass
        }
        OverallResult = if ($TestResults.FailedCount -gt 0 -or -not $CoveragePass) { 'Failed' } else { 'Passed' }
        Failures = @()
    }
    
    # Collect failure details
    if ($TestResults.Failed) {
        $summary.Failures = $TestResults.Failed | ForEach-Object {
            @{
                Name = $_.Name
                ErrorRecord = $_.ErrorRecord.Exception.Message
                File = $_.ScriptBlock.File
                Line = $_.ScriptBlock.StartPosition.StartLine
            }
        }
    }
    
    # Export based on format
    switch ($OutputFormat) {
        'JSON' {
            $jsonPath = Join-Path $OutputPath "quick-test-summary.json"
            $summary | ConvertTo-Json -Depth 5 | Out-File $jsonPath -Encoding UTF8
            Write-QuickLog "JSON report: $jsonPath" -Level 'INFO'
        }
        'HTML' {
            $htmlPath = Join-Path $OutputPath "quick-test-summary.html"
            $htmlReport = New-QuickTestHtmlReport -Summary $summary
            $htmlReport | Out-File $htmlPath -Encoding UTF8
            Write-QuickLog "HTML report: $htmlPath" -Level 'INFO'
        }
        'Console' {
            # Already displayed during execution
        }
    }
    
    return $summary
}

function New-QuickTestHtmlReport {
    param([hashtable]$Summary)
    
    $resultColor = if ($Summary.OverallResult -eq 'Passed') { '#28a745' } else { '#dc3545' }
    $coverageColor = if ($Summary.Coverage.Pass) { '#28a745' } else { '#dc3545' }
    
    return @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quick Test Results - $($Summary.TestCategory)</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 20px; background: #f8f9fa; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .header h1 { color: #333; margin-bottom: 10px; }
        .status-badge { display: inline-block; padding: 8px 16px; border-radius: 20px; color: white; font-weight: bold; background: $resultColor; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { text-align: center; padding: 20px; background: #f8f9fa; border-radius: 8px; }
        .metric-value { font-size: 2em; font-weight: bold; color: #495057; }
        .metric-label { font-size: 0.9em; color: #6c757d; text-transform: uppercase; }
        .coverage-bar { width: 100%; height: 20px; background: #e9ecef; border-radius: 10px; overflow: hidden; margin: 10px 0; }
        .coverage-fill { height: 100%; background: $coverageColor; width: $($Summary.Coverage.Percentage)%; transition: width 0.3s ease; }
        .failures { margin-top: 20px; }
        .failure { background: #f8d7da; border: 1px solid #f5c6cb; border-radius: 5px; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Quick Test Results</h1>
            <p>Test Category: <strong>$($Summary.TestCategory)</strong></p>
            <p>Generated: $($Summary.Timestamp)</p>
            <div style="margin-top: 15px;">
                <span class="status-badge">$($Summary.OverallResult)</span>
            </div>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$($Summary.Tests.Total)</div>
                <div class="metric-label">Total Tests</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #28a745;">$($Summary.Tests.Passed)</div>
                <div class="metric-label">Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #dc3545;">$($Summary.Tests.Failed)</div>
                <div class="metric-label">Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #17a2b8;">$($Summary.Tests.PassRate)%</div>
                <div class="metric-label">Pass Rate</div>
            </div>
            <div class="metric">
                <div class="metric-value" style="color: #6f42c1;">$($Summary.Duration.Formatted)</div>
                <div class="metric-label">Duration</div>
            </div>
        </div>
        
        $(if ($Summary.Coverage.Enabled) {
            @"
        <div style="margin: 20px 0;">
            <h3>📊 Code Coverage</h3>
            <div class="coverage-bar">
                <div class="coverage-fill"></div>
            </div>
            <p>Coverage: <strong>$($Summary.Coverage.Percentage)%</strong> (Threshold: $($Summary.Coverage.Threshold)%) 
            $(if ($Summary.Coverage.Pass) { '✅' } else { '❌' })</p>
        </div>
"@
        })
        
        $(if ($Summary.Failures.Count -gt 0) {
            @"
        <div class="failures">
            <h3>❌ Test Failures</h3>
            $($Summary.Failures | ForEach-Object {
                "<div class='failure'><strong>$($_.Name)</strong><br><small>$($_.File):$($_.Line)</small><br>$($_.ErrorRecord)</div>"
            } | Join-String)
        </div>
"@
        })
    </div>
</body>
</html>
"@
}

function New-GitHubIssue {
    param(
        [object]$TestResults,
        [object]$Summary
    )
    
    if (-not $CreateIssues -or $Summary.OverallResult -eq 'Passed') {
        return
    }
    
    Write-QuickLog "Creating GitHub issue for test failures..." -Level 'INFO'
    
    try {
        # Check if GitHub CLI is available
        if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-QuickLog "GitHub CLI not available, skipping issue creation" -Level 'WARN'
            return
        }
        
        $issueTitle = "Quick Test Failures: $TestCategory ($($Summary.Tests.Failed) failures)"
        $issueBody = @"
## 🧪 Quick Test Failure Report

**Test Category:** $TestCategory  
**Execution Time:** $($Summary.Timestamp)  
**Duration:** $($Summary.Duration.Formatted)

### 📊 Summary
- **Total Tests:** $($Summary.Tests.Total)
- **Failed:** $($Summary.Tests.Failed)
- **Pass Rate:** $($Summary.Tests.PassRate)%
- **Coverage:** $($Summary.Coverage.Percentage)% (Threshold: $($Summary.Coverage.Threshold)%)

### ❌ Failures
$($Summary.Failures | ForEach-Object {
    "- **$($_.Name)** ($($_.File):$($_.Line))`n  ``$($_.ErrorRecord)``"
} | Join-String -Separator "`n`n")

### 🔧 Actions Required
- [ ] Review and fix failing tests
- [ ] Ensure code coverage meets $($Summary.Coverage.Threshold)% threshold
- [ ] Re-run tests to verify fixes

---
*🤖 Automatically created by Quick Test Runner*
"@
        
        # Create the issue
        $result = gh issue create --title $issueTitle --body $issueBody --label "test-failure,automated" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-QuickLog "GitHub issue created successfully" -Level 'SUCCESS'
        } else {
            Write-QuickLog "Failed to create GitHub issue: $result" -Level 'ERROR'
        }
        
    } catch {
        Write-QuickLog "Error creating GitHub issue: $_" -Level 'ERROR'
    }
}

# Main execution
Write-Host ""
Write-Host "🧪 Quick Test Runner" -ForegroundColor Green
Write-Host "===================" -ForegroundColor Green
Write-Host "Category: $TestCategory" -ForegroundColor Cyan
Write-Host "Coverage Threshold: $MinCoverage%" -ForegroundColor Cyan
Write-Host ""

try {
    # Execute test pipeline
    Test-Prerequisites
    $testResults = Invoke-QuickTestExecution
    $coveragePass = Test-CoverageThreshold -TestResults $testResults
    $summary = Export-QuickTestResults -TestResults $testResults -CoveragePass $coveragePass
    
    # Create GitHub issue if needed
    New-GitHubIssue -TestResults $testResults -Summary $summary
    
    # Display final summary
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor Yellow
    Write-Host "🏁 QUICK TEST SUMMARY" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow
    
    $resultColor = if ($summary.OverallResult -eq 'Passed') { 'Green' } else { 'Red' }
    Write-Host "Result: " -NoNewline
    Write-Host $summary.OverallResult -ForegroundColor $resultColor
    Write-Host "Tests: $($summary.Tests.Passed)/$($summary.Tests.Total) passed ($($summary.Tests.PassRate)%)"
    Write-Host "Duration: $($summary.Duration.Formatted)"
    
    if ($summary.Coverage.Enabled) {
        $coverageColor = if ($summary.Coverage.Pass) { 'Green' } else { 'Red' }
        Write-Host "Coverage: " -NoNewline
        Write-Host "$($summary.Coverage.Percentage)%" -ForegroundColor $coverageColor -NoNewline
        Write-Host " (threshold: $($summary.Coverage.Threshold)%)"
    }
    
    Write-Host ""
    
    # Exit with appropriate code
    if ($summary.OverallResult -eq 'Failed') {
        exit 1
    } else {
        exit 0
    }
    
} catch {
    Write-QuickLog "Quick test execution failed: $_" -Level 'ERROR'
    Write-Host ""
    Write-Host "❌ Quick test execution failed!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}