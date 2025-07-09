#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates missing test files for AitherZero modules without test coverage

.DESCRIPTION
    This script analyzes the AitherZero module structure and generates standardized
    test files for modules that don't have tests, focusing on achieving 100% test
    coverage across all critical functionality.

.PARAMETER ModulesToTest
    Specific modules to generate tests for (default: all modules without tests)

.PARAMETER Force
    Overwrite existing test files

.PARAMETER AnalyzeOnly
    Only analyze modules without generating tests

.EXAMPLE
    ./Generate-MissingTests.ps1 -AnalyzeOnly

.EXAMPLE
    ./Generate-MissingTests.ps1 -ModulesToTest @("SecureCredentials", "SystemMonitoring")

.EXAMPLE
    ./Generate-MissingTests.ps1 -Force
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$ModulesToTest = @(),

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$AnalyzeOnly
)

# Import required modules
try {
    Import-Module "$PSScriptRoot/../../aither-core/modules/TestingFramework" -Force
    Import-Module "$PSScriptRoot/../../aither-core/modules/Logging" -Force
} catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# Initialize logging
Write-CustomLog -Level 'INFO' -Message "Starting test generation analysis"

# Get all modules and their test status
$AllModules = Get-DiscoveredModules -IncludeDistributedTests:$true -IncludeCentralizedTests:$false
$ModulesWithoutTests = $AllModules | Where-Object { $_.TestDiscovery.TestStrategy -eq "None" }

if ($ModulesToTest.Count -gt 0) {
    $ModulesWithoutTests = $ModulesWithoutTests | Where-Object { $_.Name -in $ModulesToTest }
}

Write-CustomLog -Level 'INFO' -Message "Found $($ModulesWithoutTests.Count) modules without tests"

# Critical modules that must have tests
$CriticalModules = @(
    "ConfigurationManager", "SecureCredentials", "SystemMonitoring", 
    "SecurityAutomation", "LicenseManager", "StartupExperience",
    "UtilityServices", "SemanticVersioning", "UnifiedMaintenance"
)

# Priority analysis
$CriticalWithoutTests = $ModulesWithoutTests | Where-Object { $_.Name -in $CriticalModules }
$NonCriticalWithoutTests = $ModulesWithoutTests | Where-Object { $_.Name -notin $CriticalModules }

Write-CustomLog -Level 'WARN' -Message "Critical modules without tests: $($CriticalWithoutTests.Count)"
Write-CustomLog -Level 'INFO' -Message "Non-critical modules without tests: $($NonCriticalWithoutTests.Count)"

# Module test coverage analysis
$TestCoverageAnalysis = @{
    TotalModules = $AllModules.Count
    ModulesWithTests = ($AllModules | Where-Object { $_.TestDiscovery.TestStrategy -ne "None" }).Count
    ModulesWithoutTests = $ModulesWithoutTests.Count
    CriticalModulesWithoutTests = $CriticalWithoutTests.Count
    CoveragePercentage = [Math]::Round((($AllModules.Count - $ModulesWithoutTests.Count) / $AllModules.Count) * 100, 2)
    CriticalCoverage = [Math]::Round((($CriticalModules.Count - $CriticalWithoutTests.Count) / $CriticalModules.Count) * 100, 2)
}

Write-CustomLog -Level 'INFO' -Message "Test Coverage Analysis:"
Write-CustomLog -Level 'INFO' -Message "  Total Modules: $($TestCoverageAnalysis.TotalModules)"
Write-CustomLog -Level 'INFO' -Message "  Modules with Tests: $($TestCoverageAnalysis.ModulesWithTests)"
Write-CustomLog -Level 'INFO' -Message "  Overall Coverage: $($TestCoverageAnalysis.CoveragePercentage)%"
Write-CustomLog -Level 'INFO' -Message "  Critical Module Coverage: $($TestCoverageAnalysis.CriticalCoverage)%"

# Detailed module analysis
$ModuleAnalysisResults = @()

foreach ($Module in $ModulesWithoutTests) {
    $Analysis = Get-ModuleAnalysis -ModulePath $Module.Path -ModuleName $Module.Name
    $ModuleAnalysisResults += $Analysis
    
    $IsCritical = $Module.Name -in $CriticalModules
    $Priority = if ($IsCritical) { "HIGH" } else { "MEDIUM" }
    
    Write-CustomLog -Level 'INFO' -Message "Module: $($Module.Name) | Type: $($Analysis.ModuleType) | Functions: $($Analysis.ExportedFunctions.Count) | Priority: $Priority"
}

if ($AnalyzeOnly) {
    Write-CustomLog -Level 'SUCCESS' -Message "Analysis complete. Use -Force to generate missing tests."
    
    # Export analysis results
    $AnalysisReport = @{
        Timestamp = Get-Date
        CoverageAnalysis = $TestCoverageAnalysis
        ModulesWithoutTests = $ModuleAnalysisResults
        CriticalModules = $CriticalModules
        Recommendations = @(
            "Generate tests for $($CriticalWithoutTests.Count) critical modules first",
            "Focus on modules with high function counts",
            "Consider integration tests for modules with complex dependencies"
        )
    }
    
    $ReportPath = "$PSScriptRoot/../../tests/results/test-coverage-analysis.json"
    $AnalysisReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $ReportPath
    Write-CustomLog -Level 'SUCCESS' -Message "Analysis report saved to: $ReportPath"
    
    return
}

# Generate missing tests
Write-CustomLog -Level 'INFO' -Message "Generating missing tests..."

# Prioritize critical modules
$ModulesToGenerate = @()
$ModulesToGenerate += $CriticalWithoutTests
$ModulesToGenerate += $NonCriticalWithoutTests

$GenerationResults = @()
$SuccessCount = 0
$FailureCount = 0

foreach ($Module in $ModulesToGenerate) {
    try {
        Write-CustomLog -Level 'INFO' -Message "Generating test for: $($Module.Name)"
        
        $Result = New-ModuleTest -ModuleName $Module.Name -ModulePath $Module.Path -Force:$Force
        
        if ($Result) {
            $SuccessCount++
            Write-CustomLog -Level 'SUCCESS' -Message "✅ Generated test for: $($Module.Name)"
        } else {
            $FailureCount++
            Write-CustomLog -Level 'ERROR' -Message "❌ Failed to generate test for: $($Module.Name)"
        }
        
        $GenerationResults += @{
            ModuleName = $Module.Name
            Success = $Result
            Timestamp = Get-Date
        }
        
    } catch {
        $FailureCount++
        Write-CustomLog -Level 'ERROR' -Message "❌ Error generating test for $($Module.Name): $_"
        
        $GenerationResults += @{
            ModuleName = $Module.Name
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date
        }
    }
}

# Summary
Write-CustomLog -Level 'INFO' -Message "Test generation complete:"
Write-CustomLog -Level 'SUCCESS' -Message "  Successfully generated: $SuccessCount tests"
Write-CustomLog -Level 'ERROR' -Message "  Failed to generate: $FailureCount tests"

# Updated coverage calculation
$NewCoveragePercentage = [Math]::Round((($AllModules.Count - $FailureCount) / $AllModules.Count) * 100, 2)
Write-CustomLog -Level 'INFO' -Message "  New estimated coverage: $NewCoveragePercentage%"

# Export generation results
$GenerationReport = @{
    Timestamp = Get-Date
    InitialCoverage = $TestCoverageAnalysis.CoveragePercentage
    EstimatedNewCoverage = $NewCoveragePercentage
    GenerationResults = $GenerationResults
    Summary = @{
        TotalAttempted = $ModulesToGenerate.Count
        Successful = $SuccessCount
        Failed = $FailureCount
    }
}

$GenerationReportPath = "$PSScriptRoot/../../tests/results/test-generation-results.json"
$GenerationReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $GenerationReportPath
Write-CustomLog -Level 'SUCCESS' -Message "Generation report saved to: $GenerationReportPath"

# Next steps recommendation
Write-CustomLog -Level 'INFO' -Message "Next Steps:"
Write-CustomLog -Level 'INFO' -Message "1. Review generated tests for accuracy"
Write-CustomLog -Level 'INFO' -Message "2. Run './tests/Run-Tests.ps1 -All' to validate new tests"
Write-CustomLog -Level 'INFO' -Message "3. Customize tests for module-specific functionality"
Write-CustomLog -Level 'INFO' -Message "4. Add integration tests for complex modules"