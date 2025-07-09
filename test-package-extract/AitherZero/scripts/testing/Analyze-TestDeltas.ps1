# Analyze-TestDeltas.ps1 - Test Change Detection and Delta Analysis
# Part of AitherZero Unified Test & Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/test-state.json",

    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),

    [Parameter(Mandatory = $false)]
    [string[]]$TargetModules = @(),

    [Parameter(Mandatory = $false)]
    [switch]$DetailedAnalysis,

    [Parameter(Mandatory = $false)]
    [switch]$ExportChanges
)

# Find project root if not specified
if (-not (Test-Path $ProjectRoot)) {
    . "$PSScriptRoot/../../aither-core/shared/Find-ProjectRoot.ps1"
    $ProjectRoot = Find-ProjectRoot
}

# Import required modules
if (Test-Path "$ProjectRoot/aither-core/modules/Logging") {
    Import-Module "$ProjectRoot/aither-core/modules/Logging" -Force -ErrorAction SilentlyContinue
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    if (Get-Command Write-CustomLog -ErrorAction SilentlyContinue) {
        Write-CustomLog -Message $Message -Level $Level
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARN"){"Yellow"} else{"Green"})
    }
}

function Get-ModuleTestMetrics {
    <#
    .SYNOPSIS
    Calculates comprehensive test metrics for a module

    .DESCRIPTION
    Analyzes test coverage, execution times, staleness, and change patterns
    to detect modules that need test attention
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [string]$ModulePath,

        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeExecutionMetrics
    )

    $metrics = @{
        moduleName = $ModuleName
        modulePath = $ModulePath
        scanTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        codeMetrics = @{
            totalFiles = 0
            totalLines = 0
            publicFunctions = 0
            privateFunctions = 0
            lastModified = $null
            complexity = "Unknown"
        }
        testMetrics = @{
            hasTests = $false
            testFiles = 0
            testCases = 0
            estimatedCoverage = 0
            lastModified = $null
            executionTime = 0
            testStrategy = "None"
        }
        deltaAnalysis = @{
            isStale = $false
            staleDays = 0
            codeChangedAfterTests = $false
            daysSinceCodeChange = 0
            daysSinceTestChange = 0
            lineCountDelta = 0
            lineCountDeltaPercent = 0
            coverageDelta = 0
        }
        qualityFlags = @()
        riskLevel = "Low"
        priorityScore = 0
    }

    try {
        # Analyze code metrics
        $metrics.codeMetrics = Get-CodeMetrics -ModulePath $ModulePath

        # Analyze test metrics
        $metrics.testMetrics = Get-TestMetrics -ModuleName $ModuleName -ModulePath $ModulePath -ProjectRoot $ProjectRoot

        # Perform delta analysis
        $metrics.deltaAnalysis = Get-DeltaAnalysis -CodeMetrics $metrics.codeMetrics -TestMetrics $metrics.testMetrics

        # Assess quality and risk
        $metrics.qualityFlags = Get-QualityFlags -Metrics $metrics
        $metrics.riskLevel = Get-RiskLevel -Metrics $metrics
        $metrics.priorityScore = Get-PriorityScore -Metrics $metrics

    } catch {
        Write-Log "Error analyzing module $ModuleName : $_" -Level "ERROR"
        $metrics.qualityFlags += "Analysis Error: $($_.Exception.Message)"
        $metrics.riskLevel = "High"
    }

    return $metrics
}

function Get-CodeMetrics {
    <#
    .SYNOPSIS
    Analyzes module code metrics and complexity
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath
    )

    $metrics = @{
        totalFiles = 0
        totalLines = 0
        publicFunctions = 0
        privateFunctions = 0
        lastModified = $null
        complexity = "Simple"
    }

    try {
        # Get all PowerShell files
        $psFiles = @()
        $psFiles += Get-ChildItem -Path $ModulePath -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
        $psFiles += Get-ChildItem -Path $ModulePath -Filter "*.psm1" -ErrorAction SilentlyContinue
        $psFiles += Get-ChildItem -Path $ModulePath -Filter "*.psd1" -ErrorAction SilentlyContinue

        $metrics.totalFiles = $psFiles.Count

        if ($psFiles.Count -gt 0) {
            # Get most recent modification
            $metrics.lastModified = ($psFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")

            # Analyze content
            foreach ($file in $psFiles) {
                $content = Get-Content $file.FullName -ErrorAction SilentlyContinue
                if ($content) {
                    $metrics.totalLines += $content.Count

                    # Count functions
                    $functionMatches = $content | Select-String -Pattern "^function\s+[A-Za-z]" -AllMatches

                    if ($file.FullName -match "\\Public\\") {
                        $metrics.publicFunctions += $functionMatches.Count
                    } elseif ($file.FullName -match "\\Private\\") {
                        $metrics.privateFunctions += $functionMatches.Count
                    } else {
                        # Mixed file - estimate distribution
                        $metrics.publicFunctions += [Math]::Ceiling($functionMatches.Count / 2)
                        $metrics.privateFunctions += [Math]::Floor($functionMatches.Count / 2)
                    }
                }
            }

            # Determine complexity
            $complexityFactors = 0
            if ($metrics.totalFiles -gt 10) { $complexityFactors++ }
            if ($metrics.totalLines -gt 1000) { $complexityFactors++ }
            if (($metrics.publicFunctions + $metrics.privateFunctions) -gt 20) { $complexityFactors++ }

            $metrics.complexity = switch ($complexityFactors) {
                { $_ -gt 2 } { "Complex" }
                { $_ -gt 0 } { "Moderate" }
                default { "Simple" }
            }
        }

    } catch {
        Write-Log "Error analyzing code metrics for $ModulePath : $_" -Level "WARN"
    }

    return $metrics
}

function Get-TestMetrics {
    <#
    .SYNOPSIS
    Analyzes module test metrics and coverage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [string]$ModulePath,

        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $metrics = @{
        hasTests = $false
        testFiles = 0
        testCases = 0
        estimatedCoverage = 0
        lastModified = $null
        executionTime = 0
        testStrategy = "None"
        testPaths = @()
        lastResults = @{
            passed = 0
            failed = 0
            duration = 0
            status = "Unknown"
        }
    }

    try {
        # Check for distributed tests
        $distributedTestPath = Join-Path $ModulePath "tests"
        $distributedTestFile = Join-Path $distributedTestPath "$ModuleName.Tests.ps1"

        # Check for centralized tests
        $centralizedTestPath = Join-Path $ProjectRoot "tests/unit/modules/$ModuleName"

        $testFiles = @()

        if (Test-Path $distributedTestFile) {
            $testFiles += Get-Item $distributedTestFile
            $metrics.testStrategy = "Distributed"
            $metrics.testPaths += $distributedTestFile

        } elseif (Test-Path $centralizedTestPath) {
            $centralizedFiles = Get-ChildItem -Path $centralizedTestPath -Filter "*.Tests.ps1" -ErrorAction SilentlyContinue
            $testFiles += $centralizedFiles
            $metrics.testStrategy = "Centralized"
            foreach ($file in $centralizedFiles) {
                $metrics.testPaths += $file.FullName
            }
        }

        if ($testFiles.Count -gt 0) {
            $metrics.hasTests = $true
            $metrics.testFiles = $testFiles.Count
            $metrics.lastModified = ($testFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")

            # Count test cases
            foreach ($testFile in $testFiles) {
                $content = Get-Content $testFile.FullName -ErrorAction SilentlyContinue
                if ($content) {
                    # Count "It" blocks (Pester test cases)
                    $itMatches = $content | Select-String -Pattern "^\s*It\s+[`"`']" -AllMatches
                    $metrics.testCases += $itMatches.Count
                }
            }

            # Try to get execution results from recent test runs
            $metrics.lastResults = Get-RecentTestResults -ModuleName $ModuleName -ProjectRoot $ProjectRoot
        }

    } catch {
        Write-Log "Error analyzing test metrics for $ModuleName : $_" -Level "WARN"
    }

    return $metrics
}

function Get-RecentTestResults {
    <#
    .SYNOPSIS
    Attempts to get recent test execution results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $results = @{
        passed = 0
        failed = 0
        duration = 0
        status = "Unknown"
        lastRun = $null
    }

    try {
        # Look for test results in common locations
        $resultsPaths = @(
            Join-Path $ProjectRoot "tests/results"
            Join-Path $ProjectRoot "TestResults"
            Join-Path $ProjectRoot ".github/test-results"
        )

        foreach ($resultsPath in $resultsPaths) {
            if (Test-Path $resultsPath) {
                $resultFiles = Get-ChildItem -Path $resultsPath -Filter "*$ModuleName*" -ErrorAction SilentlyContinue
                $resultFiles += Get-ChildItem -Path $resultsPath -Filter "*.json" -ErrorAction SilentlyContinue |
                    Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match $ModuleName }

                if ($resultFiles.Count -gt 0) {
                    $latestResult = $resultFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $results.lastRun = $latestResult.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
                    $results.status = "Found"
                    break
                }
            }
        }

    } catch {
        Write-Log "Error getting test results for $ModuleName : $_" -Level "DEBUG"
    }

    return $results
}

function Get-DeltaAnalysis {
    <#
    .SYNOPSIS
    Analyzes deltas between code and test changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CodeMetrics,

        [Parameter(Mandatory = $true)]
        [hashtable]$TestMetrics
    )

    $analysis = @{
        isStale = $false
        staleDays = 0
        codeChangedAfterTests = $false
        daysSinceCodeChange = 0
        daysSinceTestChange = 0
        lineCountDelta = 0
        lineCountDeltaPercent = 0
        coverageDelta = 0
        changeReasons = @()
    }

    try {
        $now = Get-Date

        # Calculate time-based staleness
        if ($CodeMetrics.lastModified) {
            $lastCodeChange = [DateTime]::Parse($CodeMetrics.lastModified)
            $analysis.daysSinceCodeChange = ($now - $lastCodeChange).TotalDays
        }

        if ($TestMetrics.lastModified) {
            $lastTestChange = [DateTime]::Parse($TestMetrics.lastModified)
            $analysis.daysSinceTestChange = ($now - $lastTestChange).TotalDays
        }

        # Check if code changed after tests
        if ($CodeMetrics.lastModified -and $TestMetrics.lastModified) {
            $lastCodeChange = [DateTime]::Parse($CodeMetrics.lastModified)
            $lastTestChange = [DateTime]::Parse($TestMetrics.lastModified)

            if ($lastCodeChange -gt $lastTestChange) {
                $analysis.codeChangedAfterTests = $true
                $analysis.staleDays = ($lastCodeChange - $lastTestChange).TotalDays
                $analysis.changeReasons += "Code modified after tests ($([Math]::Round($analysis.staleDays, 1)) days ago)"
            }
        }

        # Check general staleness based on time gates
        if ($analysis.daysSinceTestChange -gt 14) {  # testStaleDays threshold
            $analysis.isStale = $true
            $analysis.changeReasons += "Tests not updated in $([Math]::Round($analysis.daysSinceTestChange, 1)) days"
        }

        if ($analysis.codeChangedAfterTests -and $analysis.staleDays -gt 7) {  # codeChangeReviewDays threshold
            $analysis.isStale = $true
            $analysis.changeReasons += "Code changed but tests not updated (review needed)"
        }

        # Check if module has no tests at all
        if (-not $TestMetrics.hasTests) {
            $analysis.isStale = $true
            $analysis.changeReasons += "Module has no tests"
        }

        # Estimate coverage change (this would be better with historical data)
        if ($TestMetrics.hasTests -and $CodeMetrics.publicFunctions -gt 0) {
            $estimatedCoverage = [Math]::Min(100, ($TestMetrics.testCases * 1.5 / $CodeMetrics.publicFunctions) * 100)
            $TestMetrics.estimatedCoverage = [Math]::Round($estimatedCoverage, 1)

            # If coverage is low, flag for review
            if ($estimatedCoverage -lt 50) {
                $analysis.changeReasons += "Low estimated test coverage ($([Math]::Round($estimatedCoverage, 1))%)"
            }
        }

    } catch {
        Write-Log "Error in delta analysis: $_" -Level "WARN"
        $analysis.changeReasons += "Error in analysis: $($_.Exception.Message)"
    }

    return $analysis
}

function Get-QualityFlags {
    <#
    .SYNOPSIS
    Identifies quality issues that need attention
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics
    )

    $flags = @()

    # No tests
    if (-not $Metrics.testMetrics.hasTests) {
        $flags += "No tests exist"
    }

    # Low test coverage
    if ($Metrics.testMetrics.estimatedCoverage -lt 50) {
        $flags += "Low test coverage ($($Metrics.testMetrics.estimatedCoverage)%)"
    }

    # Few test cases for complex code
    if ($Metrics.codeMetrics.complexity -eq "Complex" -and $Metrics.testMetrics.testCases -lt 10) {
        $flags += "Complex code with insufficient tests"
    }

    # Stale tests
    if ($Metrics.deltaAnalysis.isStale) {
        $flags += "Tests are stale or outdated"
    }

    # Code changed after tests
    if ($Metrics.deltaAnalysis.codeChangedAfterTests) {
        $flags += "Code modified after tests"
    }

    # Many public functions but few tests
    if ($Metrics.codeMetrics.publicFunctions -gt 10 -and $Metrics.testMetrics.testCases -lt $Metrics.codeMetrics.publicFunctions) {
        $flags += "More functions than test cases"
    }

    return $flags
}

function Get-RiskLevel {
    <#
    .SYNOPSIS
    Assesses overall risk level for the module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics
    )

    $riskFactors = 0

    # No tests = high risk
    if (-not $Metrics.testMetrics.hasTests) {
        $riskFactors += 3
    }

    # Complex code without adequate tests
    if ($Metrics.codeMetrics.complexity -eq "Complex" -and $Metrics.testMetrics.testCases -lt 10) {
        $riskFactors += 2
    }

    # Stale tests
    if ($Metrics.deltaAnalysis.isStale) {
        $riskFactors += 1
    }

    # Code changed after tests
    if ($Metrics.deltaAnalysis.codeChangedAfterTests -and $Metrics.deltaAnalysis.staleDays -gt 7) {
        $riskFactors += 2
    }

    # Low coverage
    if ($Metrics.testMetrics.estimatedCoverage -lt 30) {
        $riskFactors += 1
    }

    if ($riskFactors -gt 4) {
        return "Critical"
    } elseif ($riskFactors -gt 2) {
        return "High"
    } elseif ($riskFactors -gt 0) {
        return "Medium"
    } else {
        return "Low"
    }
}

function Get-PriorityScore {
    <#
    .SYNOPSIS
    Calculates a priority score for test attention (0-100)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics
    )

    $score = 0

    # Base score for missing tests
    if (-not $Metrics.testMetrics.hasTests) {
        $score += 40
    }

    # Code complexity factor
    switch ($Metrics.codeMetrics.complexity) {
        "Complex" { $score += 20 }
        "Moderate" { $score += 10 }
        default { $score += 5 }
    }

    # Staleness factor
    if ($Metrics.deltaAnalysis.isStale) {
        $score += 15
    }

    # Code changed after tests
    if ($Metrics.deltaAnalysis.codeChangedAfterTests) {
        $score += 10
    }

    # Coverage factor
    if ($Metrics.testMetrics.estimatedCoverage -lt 50) {
        $score += 10
    }

    # Recent activity factor (more recent = higher priority)
    if ($Metrics.deltaAnalysis.daysSinceCodeChange -lt 7) {
        $score += 5
    }

    return [Math]::Min(100, $score)
}

function Compare-ModuleTestMetrics {
    <#
    .SYNOPSIS
    Compares current metrics with previous state to detect changes
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CurrentMetrics,

        [Parameter()]
        [hashtable]$PreviousState,

        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    $comparison = @{
        hasSignificantChanges = $false
        changesSinceLastScan = @()
        autoGenerationCandidate = $false
        reviewRequired = $false
        confidenceScore = 0
        recommendations = @()
    }

    $moduleName = $CurrentMetrics.moduleName

    try {
        # Compare with previous state if available
        if ($PreviousState -and $PreviousState.modules.ContainsKey($moduleName)) {
            $previousModule = $PreviousState.modules[$moduleName]

            # Check for test status changes
            if ($CurrentMetrics.testMetrics.hasTests -ne $previousModule.hasTests) {
                $comparison.hasSignificantChanges = $true
                if ($CurrentMetrics.testMetrics.hasTests) {
                    $comparison.changesSinceLastScan += "Tests were added"
                } else {
                    $comparison.changesSinceLastScan += "Tests were removed"
                }
            }

            # Check for coverage changes
            $coverageDelta = $CurrentMetrics.testMetrics.estimatedCoverage - $previousModule.estimatedCoverage
            if ([Math]::Abs($coverageDelta) -gt 10) {
                $comparison.hasSignificantChanges = $true
                $comparison.changesSinceLastScan += "Coverage changed by $([Math]::Round($coverageDelta, 1))%"
            }

            # Check for test case count changes
            $testCaseDelta = $CurrentMetrics.testMetrics.testCases - $previousModule.estimatedTestCases
            if ([Math]::Abs($testCaseDelta) -gt 2) {
                $comparison.hasSignificantChanges = $true
                $comparison.changesSinceLastScan += "Test cases changed by $testCaseDelta"
            }
        }

        # Determine if module is a candidate for auto-generation
        if (-not $CurrentMetrics.testMetrics.hasTests) {
            $comparison.autoGenerationCandidate = $true
            $comparison.confidenceScore = Get-AutoGenerationConfidence -Metrics $CurrentMetrics
            $comparison.recommendations += "Generate initial test file using templates"
        }

        # Determine if manual review is required
        if ($CurrentMetrics.riskLevel -in @("High", "Critical") -or $CurrentMetrics.qualityFlags.Count -gt 2) {
            $comparison.reviewRequired = $true
            $comparison.recommendations += "Manual review required due to $($CurrentMetrics.riskLevel.ToLower()) risk level"
        }

        # Add specific recommendations
        if ($CurrentMetrics.deltaAnalysis.codeChangedAfterTests) {
            $comparison.recommendations += "Update tests to match recent code changes"
        }

        if ($CurrentMetrics.testMetrics.estimatedCoverage -lt 50 -and $CurrentMetrics.testMetrics.hasTests) {
            $comparison.recommendations += "Increase test coverage (currently $($CurrentMetrics.testMetrics.estimatedCoverage)%)"
        }

        if ($CurrentMetrics.codeMetrics.complexity -eq "Complex" -and $CurrentMetrics.testMetrics.testCases -lt 10) {
            $comparison.recommendations += "Add more comprehensive tests for complex module"
        }

    } catch {
        Write-Log "Error comparing metrics for $moduleName : $_" -Level "WARN"
        $comparison.changesSinceLastScan += "Error in comparison: $($_.Exception.Message)"
    }

    return $comparison
}

function Get-AutoGenerationConfidence {
    <#
    .SYNOPSIS
    Calculates confidence score for automatic test generation (0-100)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Metrics
    )

    $confidence = 50  # Base confidence

    # Simple modules are easier to auto-generate
    switch ($Metrics.codeMetrics.complexity) {
        "Simple" { $confidence += 20 }
        "Moderate" { $confidence += 10 }
        "Complex" { $confidence -= 10 }
    }

    # Modules with clear structure are easier
    if ($Metrics.codeMetrics.publicFunctions -gt 0) {
        $confidence += 15
    }

    # Well-organized modules (with Public/Private folders) are easier
    $modulePath = Join-Path $ProjectRoot $Metrics.modulePath
    if ((Test-Path (Join-Path $modulePath "Public")) -and (Test-Path (Join-Path $modulePath "Private"))) {
        $confidence += 15
    }

    # Reduce confidence for very old or very new modules
    if ($Metrics.deltaAnalysis.daysSinceCodeChange -gt 90) {
        $confidence -= 10  # Very old, might have outdated patterns
    } elseif ($Metrics.deltaAnalysis.daysSinceCodeChange -lt 1) {
        $confidence -= 5   # Very new, might be unstable
    }

    return [Math]::Max(0, [Math]::Min(100, $confidence))
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath

    Write-Log "Starting test delta analysis..." -Level "INFO"

    # Load current state or initialize
    if (Test-Path $stateFilePath) {
        $currentState = Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
        Write-Log "Loaded existing test state with $($currentState.modules.Count) modules" -Level "INFO"
    } else {
        Write-Log "No existing state found, will create new baseline" -Level "WARN"
        $currentState = $null
    }

    # Load configuration
    $config = if ($currentState) { $currentState.configuration } else { @{
        changeThresholds = @{
            testStaleDays = 14
            codeChangeReviewDays = 7
            lineDeltaPercent = 15
            minSignificantChange = 10
            testCoverageThreshold = 70
        }
    }}

    # Get modules to analyze
    $modulesToAnalyze = if ($TargetModules.Count -gt 0) {
        $TargetModules
    } else {
        $modulesPath = Join-Path $ProjectRoot "aither-core/modules"
        if (Test-Path $modulesPath) {
            (Get-ChildItem -Path $modulesPath -Directory).Name
        } else {
            @()
        }
    }

    Write-Log "Analyzing $($modulesToAnalyze.Count) modules for test deltas..." -Level "INFO"

    # Analyze each module
    $analysisResults = @{
        analysisDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        modulesAnalyzed = $modulesToAnalyze.Count
        autoGenerationCandidates = @()
        reviewRequired = @()
        significantChanges = @()
        summary = @{
            totalAnalyzed = 0
            modulesWithTests = 0
            modulesWithoutTests = 0
            staleModules = 0
            highRiskModules = 0
            autoGenCandidates = 0
            reviewRequiredCount = 0
        }
    }

    foreach ($moduleName in $modulesToAnalyze) {
        $modulePath = Join-Path $ProjectRoot "aither-core/modules/$moduleName"

        if (Test-Path $modulePath) {
            $metrics = Get-ModuleTestMetrics -ModuleName $moduleName -ModulePath $modulePath -ProjectRoot $ProjectRoot -IncludeExecutionMetrics:$DetailedAnalysis
            $comparison = Compare-ModuleTestMetrics -CurrentMetrics $metrics -PreviousState $currentState -Configuration $config

            # Update summary statistics
            $analysisResults.summary.totalAnalyzed++
            if ($metrics.testMetrics.hasTests) {
                $analysisResults.summary.modulesWithTests++
            } else {
                $analysisResults.summary.modulesWithoutTests++
            }

            if ($metrics.deltaAnalysis.isStale) {
                $analysisResults.summary.staleModules++
            }

            if ($metrics.riskLevel -in @("High", "Critical")) {
                $analysisResults.summary.highRiskModules++
            }

            # Categorize for action
            if ($comparison.autoGenerationCandidate -and $comparison.confidenceScore -gt 60) {
                $analysisResults.autoGenerationCandidates += @{
                    moduleName = $moduleName
                    confidence = $comparison.confidenceScore
                    complexity = $metrics.codeMetrics.complexity
                    reasons = $comparison.recommendations
                }
                $analysisResults.summary.autoGenCandidates++
            }

            if ($comparison.reviewRequired -or $metrics.riskLevel -eq "Critical") {
                $analysisResults.reviewRequired += @{
                    moduleName = $moduleName
                    riskLevel = $metrics.riskLevel
                    priorityScore = $metrics.priorityScore
                    qualityFlags = $metrics.qualityFlags
                    reasons = $comparison.recommendations
                    deltaReasons = $metrics.deltaAnalysis.changeReasons
                }
                $analysisResults.summary.reviewRequiredCount++
            }

            if ($comparison.hasSignificantChanges) {
                $analysisResults.significantChanges += @{
                    moduleName = $moduleName
                    changes = $comparison.changesSinceLastScan
                    metrics = $metrics
                }
            }
        }
    }

    # Export results if requested
    if ($ExportChanges) {
        $exportPath = Join-Path $ProjectRoot "test-delta-analysis.json"
        $analysisResults | ConvertTo-Json -Depth 10 | Set-Content -Path $exportPath -Encoding UTF8
        Write-Log "Analysis results exported to: $exportPath" -Level "INFO"
    }

    # Display summary
    Write-Host "`n🧪 Test Delta Analysis Summary:" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "  Modules Analyzed: $($analysisResults.summary.totalAnalyzed)" -ForegroundColor White
    Write-Host "  With Tests: $($analysisResults.summary.modulesWithTests)" -ForegroundColor Green
    Write-Host "  Without Tests: $($analysisResults.summary.modulesWithoutTests)" -ForegroundColor Red
    Write-Host "  Stale Tests: $($analysisResults.summary.staleModules)" -ForegroundColor Yellow
    Write-Host "  High Risk: $($analysisResults.summary.highRiskModules)" -ForegroundColor Red
    Write-Host "  Auto-Gen Candidates: $($analysisResults.summary.autoGenCandidates)" -ForegroundColor Blue
    Write-Host "  Review Required: $($analysisResults.summary.reviewRequiredCount)" -ForegroundColor Magenta

    Write-Log "Test delta analysis completed successfully" -Level "SUCCESS"

} catch {
    Write-Log "Test delta analysis failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
