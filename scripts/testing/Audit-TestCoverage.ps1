# Audit-TestCoverage.ps1 - Comprehensive Test Coverage Auditing
# Part of AitherZero Unified Test & Documentation Automation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StateFilePath = ".github/test-state.json",

    [Parameter(Mandatory = $false)]
    [string]$ProjectRoot = (Get-Location),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./test-audit-report.json",

    [Parameter(Mandatory = $false)]
    [switch]$GenerateHTML,

    [Parameter(Mandatory = $false)]
    [switch]$DetailedAnalysis,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Critical", "High", "Medium", "Low", "All")]
    [string]$MinimumRiskLevel = "All",

    [Parameter(Mandatory = $false)]
    [string[]]$Categories = @("Coverage", "Staleness", "Quality", "Risk"),

    [Parameter(Mandatory = $false)]
    [switch]$CrossReference
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

function Get-ComprehensiveTestAudit {
    <#
    .SYNOPSIS
    Performs comprehensive test coverage audit across the entire project
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $false)]
        [hashtable]$TestState = @{},

        [Parameter(Mandatory = $false)]
        [string[]]$Categories = @("Coverage", "Staleness", "Quality", "Risk")
    )

    $audit = @{
        auditDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        projectRoot = $ProjectRoot
        categories = $Categories
        overallHealth = @{
            score = 0
            grade = "F"
            status = "Critical"
        }
        coverage = @{
            totalModules = 0
            modulesWithTests = 0
            modulesWithoutTests = 0
            coveragePercentage = 0
            averageTestCases = 0
            averageCoverage = 0
        }
        quality = @{
            excellentModules = 0
            goodModules = 0
            needsImprovementModules = 0
            criticalModules = 0
            totalQualityIssues = 0
        }
        staleness = @{
            currentModules = 0
            staleModules = 0
            outdatedModules = 0
            averageStaleDays = 0
            oldestTest = @{
                module = ""
                daysSinceUpdate = 0
            }
        }
        risk = @{
            lowRisk = 0
            mediumRisk = 0
            highRisk = 0
            criticalRisk = 0
            riskDistribution = @{}
        }
        modules = @{}
        recommendations = @()
        trends = @{}
        crossReference = @{}
    }

    Write-Log "Starting comprehensive test audit..." -Level "INFO"

    # Get all modules
    $modulesPath = Join-Path $ProjectRoot "aither-core/modules"
    if (-not (Test-Path $modulesPath)) {
        Write-Log "Modules directory not found: $modulesPath" -Level "ERROR"
        return $audit
    }

    $moduleDirectories = Get-ChildItem -Path $modulesPath -Directory
    $audit.coverage.totalModules = $moduleDirectories.Count

    Write-Log "Auditing $($moduleDirectories.Count) modules..." -Level "INFO"

    # Analyze each module
    foreach ($moduleDir in $moduleDirectories) {
        $moduleName = $moduleDir.Name
        $moduleAudit = Get-ModuleTestAudit -ModuleName $moduleName -ModulePath $moduleDir.FullName -ProjectRoot $ProjectRoot -TestState $TestState
        $audit.modules[$moduleName] = $moduleAudit

        # Update coverage statistics
        if ($moduleAudit.hasTests) {
            $audit.coverage.modulesWithTests++
            $audit.coverage.averageTestCases += $moduleAudit.testMetrics.testCases
            $audit.coverage.averageCoverage += $moduleAudit.testMetrics.estimatedCoverage
        } else {
            $audit.coverage.modulesWithoutTests++
        }

        # Update quality statistics
        switch ($moduleAudit.qualityGrade) {
            "A" { $audit.quality.excellentModules++ }
            "B" { $audit.quality.goodModules++ }
            "C" { $audit.quality.needsImprovementModules++ }
            default { $audit.quality.criticalModules++ }
        }
        $audit.quality.totalQualityIssues += $moduleAudit.qualityIssues.Count

        # Update staleness statistics
        if ($moduleAudit.staleness.isStale) {
            if ($moduleAudit.staleness.severity -eq "Critical") {
                $audit.staleness.outdatedModules++
            } else {
                $audit.staleness.staleModules++
            }

            if ($moduleAudit.staleness.daysSinceUpdate -gt $audit.staleness.oldestTest.daysSinceUpdate) {
                $audit.staleness.oldestTest = @{
                    module = $moduleName
                    daysSinceUpdate = $moduleAudit.staleness.daysSinceUpdate
                }
            }
        } else {
            $audit.staleness.currentModules++
        }

        # Update risk statistics
        switch ($moduleAudit.riskLevel) {
            "Low" { $audit.risk.lowRisk++ }
            "Medium" { $audit.risk.mediumRisk++ }
            "High" { $audit.risk.highRisk++ }
            "Critical" { $audit.risk.criticalRisk++ }
        }
    }

    # Calculate final statistics
    $audit.coverage.coveragePercentage = if ($audit.coverage.totalModules -gt 0) {
        [Math]::Round(($audit.coverage.modulesWithTests / $audit.coverage.totalModules) * 100, 1)
    } else { 0 }

    $audit.coverage.averageTestCases = if ($audit.coverage.modulesWithTests -gt 0) {
        [Math]::Round($audit.coverage.averageTestCases / $audit.coverage.modulesWithTests, 1)
    } else { 0 }

    $audit.coverage.averageCoverage = if ($audit.coverage.modulesWithTests -gt 0) {
        [Math]::Round($audit.coverage.averageCoverage / $audit.coverage.modulesWithTests, 1)
    } else { 0 }

    $audit.staleness.averageStaleDays = if (($audit.staleness.staleModules + $audit.staleness.outdatedModules) -gt 0) {
        $totalStaleDays = 0
        $staleCount = 0
        foreach ($moduleKey in $audit.modules.Keys) {
            if ($audit.modules[$moduleKey].staleness.isStale) {
                $totalStaleDays += $audit.modules[$moduleKey].staleness.daysSinceUpdate
                $staleCount++
            }
        }
        if ($staleCount -gt 0) { [Math]::Round($totalStaleDays / $staleCount, 1) } else { 0 }
    } else { 0 }

    # Calculate overall health score
    $audit.overallHealth = Get-OverallHealthScore -Audit $audit

    # Generate recommendations
    $audit.recommendations = Get-AuditRecommendations -Audit $audit

    Write-Log "Test audit completed for $($audit.coverage.totalModules) modules" -Level "SUCCESS"

    return $audit
}

function Get-ModuleTestAudit {
    <#
    .SYNOPSIS
    Performs detailed audit of a single module's test coverage
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
        [hashtable]$TestState = @{}
    )

    $moduleAudit = @{
        moduleName = $ModuleName
        hasTests = $false
        testMetrics = @{
            testFiles = 0
            testCases = 0
            estimatedCoverage = 0
            testStrategy = "None"
            lastModified = $null
        }
        codeMetrics = @{
            totalFiles = 0
            totalLines = 0
            publicFunctions = 0
            complexity = "Unknown"
            lastModified = $null
        }
        staleness = @{
            isStale = $false
            severity = "None"
            daysSinceUpdate = 0
            reasons = @()
        }
        qualityGrade = "F"
        qualityScore = 0
        qualityIssues = @()
        riskLevel = "Unknown"
        recommendations = @()
        trends = @{}
    }

    try {
        # Use existing test state if available
        if ($TestState.modules -and $TestState.modules.ContainsKey($ModuleName)) {
            $stateData = $TestState.modules[$ModuleName]
            $moduleAudit.hasTests = $stateData.hasTests
            $moduleAudit.testMetrics.testFiles = $stateData.testFiles.Count
            $moduleAudit.testMetrics.testCases = $stateData.estimatedTestCases
            $moduleAudit.testMetrics.estimatedCoverage = $stateData.estimatedCoverage
            $moduleAudit.testMetrics.testStrategy = $stateData.testStrategy
            $moduleAudit.testMetrics.lastModified = $stateData.lastTestModified

            $moduleAudit.codeMetrics.totalFiles = $stateData.codeMetrics.totalFiles
            $moduleAudit.codeMetrics.totalLines = $stateData.codeMetrics.totalLines
            $moduleAudit.codeMetrics.publicFunctions = $stateData.codeMetrics.publicFunctions
            $moduleAudit.codeMetrics.lastModified = $stateData.lastCodeModified

            $moduleAudit.staleness.isStale = $stateData.isStale
            if ($stateData.reviewReasons) {
                $moduleAudit.staleness.reasons = $stateData.reviewReasons
            }
        } else {
            # Perform fresh analysis
            Write-Log "Performing fresh analysis for $ModuleName" -Level "DEBUG"
            # This would call the analysis functions from Track-TestState.ps1
            # For now, we'll mark it as needing analysis
            $moduleAudit.qualityIssues += "Fresh analysis needed"
        }

        # Determine complexity
        $complexityFactors = 0
        if ($moduleAudit.codeMetrics.totalFiles -gt 10) { $complexityFactors++ }
        if ($moduleAudit.codeMetrics.totalLines -gt 1000) { $complexityFactors++ }
        if ($moduleAudit.codeMetrics.publicFunctions -gt 20) { $complexityFactors++ }

        $moduleAudit.codeMetrics.complexity = switch ($complexityFactors) {
            { $_ -gt 2 } { "Complex" }
            { $_ -gt 0 } { "Moderate" }
            default { "Simple" }
        }

        # Calculate staleness
        $moduleAudit.staleness = Get-ModuleStaleness -ModuleAudit $moduleAudit

        # Calculate quality grade and score
        $qualityAssessment = Get-QualityAssessment -ModuleAudit $moduleAudit
        $moduleAudit.qualityGrade = $qualityAssessment.grade
        $moduleAudit.qualityScore = $qualityAssessment.score
        $moduleAudit.qualityIssues += $qualityAssessment.issues

        # Calculate risk level
        $moduleAudit.riskLevel = Get-ModuleRiskLevel -ModuleAudit $moduleAudit

        # Generate recommendations
        $moduleAudit.recommendations = Get-ModuleRecommendations -ModuleAudit $moduleAudit

    } catch {
        Write-Log "Error auditing module $ModuleName : $_" -Level "ERROR"
        $moduleAudit.qualityIssues += "Audit error: $($_.Exception.Message)"
        $moduleAudit.riskLevel = "Critical"
    }

    return $moduleAudit
}

function Get-ModuleStaleness {
    <#
    .SYNOPSIS
    Assesses module test staleness
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAudit
    )

    $staleness = @{
        isStale = $false
        severity = "None"
        daysSinceUpdate = 0
        reasons = @()
    }

    try {
        if (-not $ModuleAudit.hasTests) {
            $staleness.isStale = $true
            $staleness.severity = "Critical"
            $staleness.reasons += "No tests exist"
            return $staleness
        }

        $now = Get-Date

        # Calculate days since test update
        if ($ModuleAudit.testMetrics.lastModified) {
            $lastTestUpdate = [DateTime]::Parse($ModuleAudit.testMetrics.lastModified)
            $staleness.daysSinceUpdate = ($now - $lastTestUpdate).TotalDays
        }

        # Calculate days since code update
        $daysSinceCodeUpdate = 0
        if ($ModuleAudit.codeMetrics.lastModified) {
            $lastCodeUpdate = [DateTime]::Parse($ModuleAudit.codeMetrics.lastModified)
            $daysSinceCodeUpdate = ($now - $lastCodeUpdate).TotalDays

            # Check if code was updated after tests
            if ($ModuleAudit.testMetrics.lastModified -and $lastCodeUpdate -gt $lastTestUpdate) {
                $staleness.isStale = $true
                $staleness.reasons += "Code updated after tests"

                $daysSinceCodeChangedAfterTests = ($lastCodeUpdate - $lastTestUpdate).TotalDays
                if ($daysSinceCodeChangedAfterTests -gt 14) {
                    $staleness.severity = "Critical"
                } elseif ($daysSinceCodeChangedAfterTests -gt 7) {
                    $staleness.severity = "High"
                } else {
                    $staleness.severity = "Medium"
                }
            }
        }

        # Check general staleness
        if ($staleness.daysSinceUpdate -gt 30) {
            $staleness.isStale = $true
            $staleness.severity = "Critical"
            $staleness.reasons += "Tests not updated in over 30 days"
        } elseif ($staleness.daysSinceUpdate -gt 14) {
            $staleness.isStale = $true
            if ($staleness.severity -eq "None") { $staleness.severity = "High" }
            $staleness.reasons += "Tests not updated in over 14 days"
        }

    } catch {
        Write-Log "Error assessing staleness: $_" -Level "WARN"
        $staleness.isStale = $true
        $staleness.severity = "Critical"
        $staleness.reasons += "Error in staleness analysis"
    }

    return $staleness
}

function Get-QualityAssessment {
    <#
    .SYNOPSIS
    Assesses overall test quality for a module
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAudit
    )

    $assessment = @{
        score = 0
        grade = "F"
        issues = @()
    }

    # Base score for having tests
    if ($ModuleAudit.hasTests) {
        $assessment.score += 30
    } else {
        $assessment.issues += "No tests exist"
        return $assessment  # Can't score higher without tests
    }

    # Coverage score (0-25 points)
    $coverageScore = [Math]::Min(25, ($ModuleAudit.testMetrics.estimatedCoverage / 100) * 25)
    $assessment.score += $coverageScore

    if ($ModuleAudit.testMetrics.estimatedCoverage -lt 50) {
        $assessment.issues += "Low test coverage ($($ModuleAudit.testMetrics.estimatedCoverage)%)"
    }

    # Test case adequacy (0-20 points)
    $expectedTestCases = [Math]::Max(5, $ModuleAudit.codeMetrics.publicFunctions)
    $testCaseRatio = if ($expectedTestCases -gt 0) {
        [Math]::Min(1, $ModuleAudit.testMetrics.testCases / $expectedTestCases)
    } else { 1 }
    $testCaseScore = $testCaseRatio * 20
    $assessment.score += $testCaseScore

    if ($testCaseRatio -lt 0.5) {
        $assessment.issues += "Insufficient test cases ($($ModuleAudit.testMetrics.testCases) for $($ModuleAudit.codeMetrics.publicFunctions) public functions)"
    }

    # Freshness score (0-15 points)
    if (-not $ModuleAudit.staleness.isStale) {
        $assessment.score += 15
    } else {
        $assessment.issues += "Tests are stale: $($ModuleAudit.staleness.reasons -join ', ')"

        # Partial credit based on staleness severity
        switch ($ModuleAudit.staleness.severity) {
            "Medium" { $assessment.score += 10 }
            "High" { $assessment.score += 5 }
            "Critical" { $assessment.score += 0 }
        }
    }

    # Complexity appropriateness (0-10 points)
    $complexityBonus = switch ($ModuleAudit.codeMetrics.complexity) {
        "Simple" {
            if ($ModuleAudit.testMetrics.testCases -ge 3) { 10 } else { 5 }
        }
        "Moderate" {
            if ($ModuleAudit.testMetrics.testCases -ge 8) { 10 } else { 3 }
        }
        "Complex" {
            if ($ModuleAudit.testMetrics.testCases -ge 15) { 10 } else { 0 }
        }
        default { 0 }
    }
    $assessment.score += $complexityBonus

    if ($complexityBonus -lt 5) {
        $assessment.issues += "Test coverage inadequate for code complexity ($($ModuleAudit.codeMetrics.complexity))"
    }

    # Convert score to grade
    $assessment.grade = switch ($assessment.score) {
        { $_ -ge 90 } { "A" }
        { $_ -ge 80 } { "B" }
        { $_ -ge 70 } { "C" }
        { $_ -ge 60 } { "D" }
        default { "F" }
    }

    return $assessment
}

function Get-ModuleRiskLevel {
    <#
    .SYNOPSIS
    Determines risk level for a module based on test metrics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAudit
    )

    $riskFactors = 0

    # No tests = automatic high risk
    if (-not $ModuleAudit.hasTests) {
        $riskFactors += 4
    }

    # Low coverage
    if ($ModuleAudit.testMetrics.estimatedCoverage -lt 30) {
        $riskFactors += 2
    } elseif ($ModuleAudit.testMetrics.estimatedCoverage -lt 50) {
        $riskFactors += 1
    }

    # Staleness
    switch ($ModuleAudit.staleness.severity) {
        "Critical" { $riskFactors += 3 }
        "High" { $riskFactors += 2 }
        "Medium" { $riskFactors += 1 }
    }

    # Complex code without adequate tests
    if ($ModuleAudit.codeMetrics.complexity -eq "Complex" -and $ModuleAudit.testMetrics.testCases -lt 10) {
        $riskFactors += 2
    }

    # Quality grade factor
    switch ($ModuleAudit.qualityGrade) {
        "F" { $riskFactors += 2 }
        "D" { $riskFactors += 1 }
    }

    return switch ($riskFactors) {
        { $_ -gt 6 } { "Critical" }
        { $_ -gt 4 } { "High" }
        { $_ -gt 2 } { "Medium" }
        default { "Low" }
    }
}

function Get-ModuleRecommendations {
    <#
    .SYNOPSIS
    Generates specific recommendations for improving module tests
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ModuleAudit
    )

    $recommendations = @()

    if (-not $ModuleAudit.hasTests) {
        $recommendations += "Create initial test file using automated generation"
        $recommendations += "Focus on testing public functions first"
        return $recommendations
    }

    if ($ModuleAudit.testMetrics.estimatedCoverage -lt 50) {
        $recommendations += "Increase test coverage to at least 70%"
        $recommendations += "Add tests for untested public functions"
    }

    if ($ModuleAudit.staleness.isStale) {
        switch ($ModuleAudit.staleness.severity) {
            "Critical" { $recommendations += "URGENT: Update tests to match recent code changes" }
            "High" { $recommendations += "Update tests to reflect recent code modifications" }
            "Medium" { $recommendations += "Review and refresh existing tests" }
        }
    }

    if ($ModuleAudit.testMetrics.testCases -lt $ModuleAudit.codeMetrics.publicFunctions) {
        $recommendations += "Add more test cases to match number of public functions"
    }

    if ($ModuleAudit.codeMetrics.complexity -eq "Complex" -and $ModuleAudit.testMetrics.testCases -lt 15) {
        $recommendations += "Add comprehensive tests for complex module functionality"
        $recommendations += "Consider integration tests for complex workflows"
    }

    if ($ModuleAudit.qualityGrade -in @("D", "F")) {
        $recommendations += "Focus on test quality improvement"
        $recommendations += "Review existing tests for completeness and accuracy"
    }

    return $recommendations
}

function Get-OverallHealthScore {
    <#
    .SYNOPSIS
    Calculates overall project test health score
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Audit
    )

    $health = @{
        score = 0
        grade = "F"
        status = "Critical"
    }

    # Coverage component (40% of score)
    $coverageScore = $Audit.coverage.coveragePercentage * 0.4

    # Quality component (30% of score)
    $qualityScore = 0
    if ($Audit.coverage.totalModules -gt 0) {
        $goodModules = $Audit.quality.excellentModules + $Audit.quality.goodModules
        $qualityPercentage = ($goodModules / $Audit.coverage.totalModules) * 100
        $qualityScore = $qualityPercentage * 0.3
    }

    # Risk component (20% of score)
    $riskScore = 0
    if ($Audit.coverage.totalModules -gt 0) {
        $lowRiskModules = $Audit.risk.lowRisk + $Audit.risk.mediumRisk
        $riskPercentage = ($lowRiskModules / $Audit.coverage.totalModules) * 100
        $riskScore = $riskPercentage * 0.2
    }

    # Staleness component (10% of score)
    $stalenessScore = 0
    if ($Audit.coverage.totalModules -gt 0) {
        $currentPercentage = ($Audit.staleness.currentModules / $Audit.coverage.totalModules) * 100
        $stalenessScore = $currentPercentage * 0.1
    }

    $health.score = [Math]::Round($coverageScore + $qualityScore + $riskScore + $stalenessScore, 1)

    # Determine grade and status
    $health.grade = switch ($health.score) {
        { $_ -ge 90 } { "A" }
        { $_ -ge 80 } { "B" }
        { $_ -ge 70 } { "C" }
        { $_ -ge 60 } { "D" }
        default { "F" }
    }

    $health.status = switch ($health.score) {
        { $_ -ge 80 } { "Excellent" }
        { $_ -ge 70 } { "Good" }
        { $_ -ge 60 } { "Needs Improvement" }
        { $_ -ge 40 } { "Poor" }
        default { "Critical" }
    }

    return $health
}

function Get-AuditRecommendations {
    <#
    .SYNOPSIS
    Generates project-wide recommendations based on audit results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Audit
    )

    $recommendations = @()

    # Coverage recommendations
    if ($Audit.coverage.coveragePercentage -lt 70) {
        $recommendations += @{
            category = "Coverage"
            priority = "High"
            description = "Increase test coverage to at least 70% (currently $($Audit.coverage.coveragePercentage)%)"
            action = "Generate tests for $($Audit.coverage.modulesWithoutTests) modules without tests"
        }
    }

    # Quality recommendations
    if ($Audit.quality.criticalModules -gt 0) {
        $recommendations += @{
            category = "Quality"
            priority = "Critical"
            description = "Address $($Audit.quality.criticalModules) modules with critical test quality issues"
            action = "Focus on modules with grade F first"
        }
    }

    # Risk recommendations
    if ($Audit.risk.criticalRisk -gt 0) {
        $recommendations += @{
            category = "Risk"
            priority = "Critical"
            description = "Mitigate $($Audit.risk.criticalRisk) critical risk modules immediately"
            action = "Prioritize modules with complex code and no tests"
        }
    }

    # Staleness recommendations
    if ($Audit.staleness.outdatedModules -gt 0) {
        $recommendations += @{
            category = "Staleness"
            priority = "High"
            description = "Update $($Audit.staleness.outdatedModules) severely outdated test suites"
            action = "Review tests that haven't been updated in over 30 days"
        }
    }

    # Overall health recommendations
    if ($Audit.overallHealth.score -lt 60) {
        $recommendations += @{
            category = "Overall"
            priority = "Critical"
            description = "Overall test health is poor (score: $($Audit.overallHealth.score))"
            action = "Implement comprehensive test improvement plan"
        }
    }

    return $recommendations
}

function Export-AuditHTML {
    <#
    .SYNOPSIS
    Generates HTML report from audit results
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Audit,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $htmlPath = $OutputPath -replace '\.json$', '.html'

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AitherZero Test Coverage Audit Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .summary { background-color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric { display: inline-block; margin: 10px 20px 10px 0; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; }
        .metric-label { font-size: 0.9em; color: #666; }
        .grade-A { color: #27ae60; }
        .grade-B { color: #2980b9; }
        .grade-C { color: #f39c12; }
        .grade-D { color: #e67e22; }
        .grade-F { color: #e74c3c; }
        .status-excellent { color: #27ae60; }
        .status-good { color: #2980b9; }
        .status-needs-improvement { color: #f39c12; }
        .status-poor { color: #e67e22; }
        .status-critical { color: #e74c3c; }
        .modules { background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .module { margin: 10px 0; padding: 15px; border-left: 4px solid #ddd; background-color: #f9f9f9; }
        .module.critical { border-left-color: #e74c3c; }
        .module.high { border-left-color: #e67e22; }
        .module.medium { border-left-color: #f39c12; }
        .module.low { border-left-color: #27ae60; }
        .recommendations { background-color: white; padding: 20px; border-radius: 8px; margin-top: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .recommendation { margin: 10px 0; padding: 10px; border-radius: 4px; }
        .recommendation.critical { background-color: #fdf2f2; border-left: 4px solid #e74c3c; }
        .recommendation.high { background-color: #fef5e7; border-left: 4px solid #e67e22; }
        .recommendation.medium { background-color: #fffbf0; border-left: 4px solid #f39c12; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 AitherZero Test Coverage Audit Report</h1>
        <p>Generated: $($Audit.auditDate) | Overall Health: <span class="status-$($Audit.overallHealth.status.ToLower() -replace ' ', '-')">$($Audit.overallHealth.status)</span></p>
    </div>

    <div class="summary">
        <h2>📊 Executive Summary</h2>
        <div class="metric">
            <div class="metric-value grade-$($Audit.overallHealth.grade)">$($Audit.overallHealth.grade)</div>
            <div class="metric-label">Overall Grade</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Audit.overallHealth.score)%</div>
            <div class="metric-label">Health Score</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Audit.coverage.coveragePercentage)%</div>
            <div class="metric-label">Test Coverage</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Audit.coverage.modulesWithTests)</div>
            <div class="metric-label">Modules with Tests</div>
        </div>
        <div class="metric">
            <div class="metric-value">$($Audit.risk.criticalRisk)</div>
            <div class="metric-label">Critical Risk</div>
        </div>
    </div>

    <div class="summary">
        <h2>📈 Detailed Metrics</h2>
        <h3>Coverage Distribution</h3>
        <p>📊 Total Modules: $($Audit.coverage.totalModules)</p>
        <p>✅ With Tests: $($Audit.coverage.modulesWithTests) ($($Audit.coverage.coveragePercentage)%)</p>
        <p>❌ Without Tests: $($Audit.coverage.modulesWithoutTests)</p>
        <p>📝 Average Test Cases: $($Audit.coverage.averageTestCases)</p>
        <p>🎯 Average Coverage: $($Audit.coverage.averageCoverage)%</p>

        <h3>Quality Distribution</h3>
        <p>🌟 Excellent (A): $($Audit.quality.excellentModules)</p>
        <p>👍 Good (B): $($Audit.quality.goodModules)</p>
        <p>⚠️ Needs Improvement (C): $($Audit.quality.needsImprovementModules)</p>
        <p>🚨 Critical (D/F): $($Audit.quality.criticalModules)</p>

        <h3>Risk Distribution</h3>
        <p>🟢 Low Risk: $($Audit.risk.lowRisk)</p>
        <p>🟡 Medium Risk: $($Audit.risk.mediumRisk)</p>
        <p>🟠 High Risk: $($Audit.risk.highRisk)</p>
        <p>🔴 Critical Risk: $($Audit.risk.criticalRisk)</p>

        <h3>Staleness Analysis</h3>
        <p>✅ Current: $($Audit.staleness.currentModules)</p>
        <p>⏰ Stale: $($Audit.staleness.staleModules)</p>
        <p>⚠️ Outdated: $($Audit.staleness.outdatedModules)</p>
        <p>📅 Average Stale Days: $($Audit.staleness.averageStaleDays)</p>
        <p>🗓️ Oldest Test: $($Audit.staleness.oldestTest.module) ($($Audit.staleness.oldestTest.daysSinceUpdate) days)</p>
    </div>
"@

    # Add module details
    $html += "<div class=`"modules`"><h2>📦 Module Details</h2>"

    $sortedModules = $Audit.modules.GetEnumerator() | Sort-Object { $_.Value.riskLevel -eq "Critical" ? 0 : $_.Value.riskLevel -eq "High" ? 1 : $_.Value.riskLevel -eq "Medium" ? 2 : 3 }, Name

    foreach ($moduleEntry in $sortedModules) {
        $module = $moduleEntry.Value
        $riskClass = $module.riskLevel.ToLower()

        $html += @"
        <div class="module $riskClass">
            <h3>$($module.moduleName) - Grade: <span class="grade-$($module.qualityGrade)">$($module.qualityGrade)</span> | Risk: <span class="status-$($riskClass)">$($module.riskLevel)</span></h3>
            <p><strong>Tests:</strong> $(if($module.hasTests){"✅ $($module.testMetrics.testCases) test cases, $($module.testMetrics.estimatedCoverage)% coverage"}else{"❌ No tests"})</p>
            <p><strong>Code:</strong> $($module.codeMetrics.complexity) complexity, $($module.codeMetrics.publicFunctions) public functions</p>
            <p><strong>Status:</strong> $(if($module.staleness.isStale){"⚠️ Stale ($($module.staleness.severity))"}else{"✅ Current"})</p>
            $(if($module.qualityIssues.Count -gt 0){"<p><strong>Issues:</strong> $($module.qualityIssues -join ', ')</p>"}else{""})
            $(if($module.recommendations.Count -gt 0){"<p><strong>Recommendations:</strong> $($module.recommendations -join '; ')</p>"}else{""})
        </div>
"@
    }

    $html += "</div>"

    # Add recommendations
    if ($Audit.recommendations.Count -gt 0) {
        $html += "<div class=`"recommendations`"><h2>💡 Recommendations</h2>"

        foreach ($recommendation in $Audit.recommendations) {
            $priorityClass = $recommendation.priority.ToLower()
            $html += @"
            <div class="recommendation $priorityClass">
                <h3>$($recommendation.category) - $($recommendation.priority) Priority</h3>
                <p><strong>Issue:</strong> $($recommendation.description)</p>
                <p><strong>Action:</strong> $($recommendation.action)</p>
            </div>
"@
        }

        $html += "</div>"
    }

    $html += @"
    <div style="margin-top: 40px; text-align: center; color: #666; font-size: 0.9em;">
        <p>Generated by AitherZero Test Coverage Audit System</p>
        <p>For more details, see the JSON report: $(Split-Path $OutputPath -Leaf)</p>
    </div>
</body>
</html>
"@

    Set-Content -Path $htmlPath -Value $html -Encoding UTF8
    Write-Log "HTML report generated: $htmlPath" -Level "SUCCESS"

    return $htmlPath
}

# Main execution
try {
    $stateFilePath = Join-Path $ProjectRoot $StateFilePath

    Write-Log "Starting comprehensive test coverage audit..." -Level "INFO"

    # Load test state if available
    $testState = if (Test-Path $stateFilePath) {
        Get-Content -Path $stateFilePath -Raw | ConvertFrom-Json -AsHashtable
    } else {
        Write-Log "No test state found, will perform fresh analysis" -Level "WARN"
        @{}
    }

    # Perform comprehensive audit
    $auditResults = Get-ComprehensiveTestAudit -ProjectRoot $ProjectRoot -TestState $testState -Categories $Categories

    # Cross-reference with documentation if requested
    if ($CrossReference) {
        $docStateFile = Join-Path $ProjectRoot ".github/documentation-state.json"
        if (Test-Path $docStateFile) {
            $docState = Get-Content -Path $docStateFile -Raw | ConvertFrom-Json -AsHashtable
            # Add cross-reference analysis here
            $auditResults.crossReference = @{
                hasDocumentationState = $true
                modulesWithBothDocsAndTests = 0
                modulesWithDocsButNoTests = 0
                modulesWithTestsButNoDocs = 0
                modulesWithNeither = 0
            }

            foreach ($moduleName in $auditResults.modules.Keys) {
                $hasTests = $auditResults.modules[$moduleName].hasTests
                $hasDocs = $docState.directories.ContainsKey("aither-core/modules/$moduleName") -and $docState.directories["aither-core/modules/$moduleName"].readmeExists

                if ($hasTests -and $hasDocs) {
                    $auditResults.crossReference.modulesWithBothDocsAndTests++
                } elseif ($hasDocs -and -not $hasTests) {
                    $auditResults.crossReference.modulesWithDocsButNoTests++
                } elseif ($hasTests -and -not $hasDocs) {
                    $auditResults.crossReference.modulesWithTestsButNoDocs++
                } else {
                    $auditResults.crossReference.modulesWithNeither++
                }
            }

            Write-Log "Cross-reference with documentation completed" -Level "INFO"
        }
    }

    # Filter by risk level if specified
    if ($MinimumRiskLevel -ne "All") {
        $riskOrder = @("Low", "Medium", "High", "Critical")
        $minIndex = $riskOrder.IndexOf($MinimumRiskLevel)

        $filteredModules = @{}
        foreach ($moduleKey in $auditResults.modules.Keys) {
            $moduleRiskIndex = $riskOrder.IndexOf($auditResults.modules[$moduleKey].riskLevel)
            if ($moduleRiskIndex -ge $minIndex) {
                $filteredModules[$moduleKey] = $auditResults.modules[$moduleKey]
            }
        }
        $auditResults.modules = $filteredModules
    }

    # Export results
    $auditResults | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Log "Audit results exported to: $OutputPath" -Level "SUCCESS"

    # Generate HTML report if requested
    if ($GenerateHTML) {
        $htmlPath = Export-AuditHTML -Audit $auditResults -OutputPath $OutputPath
        Write-Log "HTML report available at: $htmlPath" -Level "SUCCESS"
    }

    # Display summary
    Write-Host "`n🧪 Test Coverage Audit Summary:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host "Overall Health: $($auditResults.overallHealth.status) (Score: $($auditResults.overallHealth.score)%, Grade: $($auditResults.overallHealth.grade))" -ForegroundColor $(
        switch ($auditResults.overallHealth.grade) {
            "A" { "Green" }
            "B" { "Green" }
            "C" { "Yellow" }
            "D" { "Red" }
            default { "Red" }
        }
    )
    Write-Host "Test Coverage: $($auditResults.coverage.coveragePercentage)% ($($auditResults.coverage.modulesWithTests)/$($auditResults.coverage.totalModules) modules)" -ForegroundColor White
    Write-Host "Quality Distribution: A:$($auditResults.quality.excellentModules) B:$($auditResults.quality.goodModules) C:$($auditResults.quality.needsImprovementModules) D/F:$($auditResults.quality.criticalModules)" -ForegroundColor White
    Write-Host "Risk Distribution: Low:$($auditResults.risk.lowRisk) Medium:$($auditResults.risk.mediumRisk) High:$($auditResults.risk.highRisk) Critical:$($auditResults.risk.criticalRisk)" -ForegroundColor White
    Write-Host "Staleness: Current:$($auditResults.staleness.currentModules) Stale:$($auditResults.staleness.staleModules) Outdated:$($auditResults.staleness.outdatedModules)" -ForegroundColor White

    if ($auditResults.recommendations.Count -gt 0) {
        Write-Host "`n💡 Top Recommendations:" -ForegroundColor Yellow
        $topRecommendations = $auditResults.recommendations | Where-Object { $_.priority -in @("Critical", "High") } | Select-Object -First 3
        foreach ($rec in $topRecommendations) {
            Write-Host "  [$($rec.priority)] $($rec.description)" -ForegroundColor $(if($rec.priority -eq "Critical"){"Red"}else{"Yellow"})
        }
    }

    Write-Log "Test coverage audit completed successfully" -Level "SUCCESS"

} catch {
    Write-Log "Test coverage audit failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
