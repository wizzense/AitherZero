# Complete Cmdlet Inventory - Plural Nouns

## Summary

This document provides a complete inventory of all cmdlets with plural nouns found in the AitherZero codebase.

**Total Found**: 61 cmdlets with plural nouns  
**Last Scanned**: 2025-11-08  
**Scan Method**: Recursive search of `./aithercore` directory

## Breakdown

- **To Refactor**: 22 cmdlets (Priorities 2-7)
- **Keep Plural**: 39 cmdlets (batch operations, documented rationale)

---

## Priority 1: Infrastructure Submodules ✅ COMPLETED

| Cmdlet | Status | New Name |
|--------|--------|----------|
| `Get-InfrastructureSubmodules` | ✅ Refactored | `Get-InfrastructureSubmodule` |
| `Update-InfrastructureSubmodules` | ✅ Refactored | `Update-InfrastructureSubmodule` |
| `Sync-InfrastructureSubmodules` | ✅ Refactored | `Sync-InfrastructureSubmodule` |

---

## Priority 2: High-Impact Pipeline Cmdlets (Future)

| Cmdlet | Proposed Name | Location |
|--------|---------------|----------|
| `Get-GitHubIssues` | `Get-GitHubIssue` | Development domain |
| `Get-LogFiles` | `Get-LogFile` | Utilities/Logging |
| `Get-Logs` | `Get-Log` | Utilities/Logging |
| `Search-Logs` | `Search-Log` | Utilities/Logging |

---

## Priority 3: Test Generation Cmdlets (Future)

| Cmdlet | Proposed Name | Location |
|--------|---------------|----------|
| `Build-ErrorHandlingTests` | `Build-ErrorHandlingTest` | Testing/TestGenerator |
| `Build-FunctionalTests` | `Build-FunctionalTest` | Testing/FunctionalTestGenerator |
| `Build-MockTests` | `Build-MockTest` | Testing/TestGenerator |
| `Build-StructuralTests` | `Build-StructuralTest` | Testing/TestGenerator |
| `New-AllAutomationTests` | `New-AutomationTest` | Testing/AutoTestGenerator |
| `New-DependencyTests` | `New-DependencyTest` | Testing/TestGenerator |
| `New-ErrorHandlingTests` | `New-ErrorHandlingTest` | Testing/TestGenerator |
| `New-ExecutionTests` | `New-ExecutionTest` | Testing/TestGenerator |
| `New-FunctionTests` | `New-FunctionTest` | Testing/FunctionalTestGenerator |
| `New-ParameterTests` | `New-ParameterTest` | Testing/TestGenerator |
| `New-PlatformTests` | `New-PlatformTest` | Testing/TestGenerator |

---

## Priority 4: Metrics and Reporting (Future)

| Cmdlet | Proposed Name | Location |
|--------|---------------|----------|
| `Export-AitherMetrics` | `Export-AitherMetric` | Reporting/ReportingEngine |
| `Get-AitherMetrics` | `Get-AitherMetric` | Reporting/ReportingEngine |
| `Get-AnalysisResults` | `Get-AnalysisResult` | Reporting/TechDebtAnalysis |
| `Get-CachedResults` | `Get-CachedResult` | Reporting/TechDebtAnalysis |
| `Get-ExecutionMetrics` | `Get-ExecutionMetric` | Reporting/ReportingEngine |
| `Get-LatestAnalysisResults` | `Get-LatestAnalysisResult` | Reporting/TechDebtAnalysis |
| `Get-LatestTestResults` | `Get-LatestTestResult` | Reporting/ReportingEngine |
| `Get-LogStatistics` | `Get-LogStatistic` | Utilities/LogViewer |
| `Get-PerformanceMetrics` | `Get-PerformanceMetric` | Utilities/Performance |
| `Get-TestCacheStatistics` | `Get-TestCacheStatistic` | Testing/TestCacheManager |
| `Merge-AnalysisResults` | `Merge-AnalysisResult` | Reporting/TechDebtAnalysis |
| `Save-AnalysisResults` | `Save-AnalysisResult` | Reporting/TechDebtAnalysis |
| `Set-CachedResults` | `Set-CachedResult` | Reporting/TechDebtAnalysis |
| `Show-TestTrends` | `Show-TestTrend` | Reporting/ReportingEngine |
| `Format-SearchResults` | `Format-SearchResult` | Utilities/LogViewer |

---

## Priority 5: Maintenance Operations (Future)

| Cmdlet | Proposed Name | Location |
|--------|---------------|----------|
| `Clear-LogFiles` | `Clear-LogFile` | Utilities/Logging |
| `Clear-Logs` | `Clear-Log` | Utilities/Logging |
| `Clear-OldLogs` | `Clear-OldLog` | Utilities/Logging |
| `Clear-ReportFiles` | `Clear-ReportFile` | Reporting/ReportingEngine |
| `Clear-TemporaryFiles` | `Clear-TemporaryFile` | Utilities/Bootstrap |
| `Clear-TestResults` | `Clear-TestResult` | Testing/TestingFramework |

---

## Priority 6: Analysis and Result Cmdlets (Future)

| Cmdlet | Proposed Name | Location |
|--------|---------------|----------|
| `Get-CodeQualityMetrics` | `Get-CodeQualityMetric` | Reporting/ReportingEngine |
| `Get-FileLevelMetrics` | `Get-FileLevelMetric` | Reporting/ReportingEngine |
| `Get-ProjectMetrics` | `Get-ProjectMetric` | Reporting/ReportingEngine |
| `Get-PSScriptAnalyzerMetrics` | `Get-PSScriptAnalyzerMetric` | Testing/QualityValidator |
| `Get-QualityMetrics` | `Get-QualityMetric` | Testing/QualityValidator |
| `Get-SystemMetrics` | `Get-SystemMetric` | Utilities/Performance |
| `Get-AutomationMetrics` | `Get-AutomationMetric` | Reporting/ReportingEngine |
| `Get-MockMetrics` | `Get-MockMetric` | Testing/TestGenerator |
| `Show-ProjectMetrics` | `Show-ProjectMetric` | Reporting/ReportingEngine |
| `Get-TestResults` | `Get-TestResult` | Testing/TestingFramework |

---

## Priority 7: Dependencies and Features (Future)

| Cmdlet | Proposed Name | Location |
|--------|---------------|----------|
| `Get-FeatureDependencies` | `Get-FeatureDependency` | Configuration/ConfigManager |
| `Get-ModuleDependencies` | `Get-ModuleDependency` | Documentation/DocumentationEngine |

---

## Keep as Plural (Documented Rationale)

### Batch Operations & Initialization

| Cmdlet | Reason | Location |
|--------|--------|----------|
| `Initialize-DefaultTemplates` | Batch template initialization | Documentation/DocumentationEngine |
| `Initialize-ValidationRules` | Batch rule initialization | Documentation/DocumentationEngine |
| `Install-DevelopmentTools` | Batch tool installation | Utilities/Bootstrap |
| `Install-TestingTools` | Batch tool installation | Testing/TestingFramework |
| `Install-ValidationTools` | Batch tool installation | Utilities/Bootstrap |
| `Load-DocumentationTemplates` | Batch template loading | Documentation/DocumentationEngine |

### Collection Returns

| Cmdlet | Reason | Location |
|--------|--------|----------|
| `Get-ContributingGuidelines` | Returns documentation collection | Documentation/DocumentationEngine |
| `Get-InstallationInstructions` | Returns instruction collection | Documentation/DocumentationEngine |
| `Get-ProjectExamples` | Returns example collection | Documentation/DocumentationEngine |
| `Get-AllLogFiles` | Explicit "all" operation | Utilities/LogViewer |
| `Get-AllPowerShellFiles` | Explicit "all" operation | Utilities |
| `Get-AuditLogs` | Audit log is a collection | Utilities/Logging |
| `Get-OrchestrationLogs` | Orchestration log stream | Automation |
| `Get-HistoricalMetrics` | Time-series data | Reporting/ReportingEngine |

### Coordination & Sync Operations

| Cmdlet | Reason | Location |
|--------|--------|----------|
| `Resolve-FeatureDependencies` | Coordination across dependencies | Configuration/ConfigManager |
| `Analyze-Changes` | Analyzes git changeset as whole | Development |
| `Analyze-SecurityIssues` | Security analysis of entire codebase | Security |
| `Get-StagedChanges` | Git staging area | Development |

### Batch Test Suite Operations

| Cmdlet | Reason | Location |
|--------|--------|----------|
| `Invoke-AllTestSuites` | Batch test suite runner | Testing/AitherTestFramework |
| `Invoke-LegacyPesterTests` | Legacy batch runner | Testing/TestingFramework |
| `Register-AutomationScriptTestSuites` | Registers suite collection | Testing/CoreTestSuites |
| `Register-CoreTestSuites` | Registers suite collection | Testing/CoreTestSuites |
| `Register-InfrastructureTestSuites` | Registers suite collection | Testing/CoreTestSuites |
| `Register-IntegrationTestSuites` | Registers suite collection | Testing/CoreTestSuites |
| `Register-ModuleTestSuites` | Registers suite collection | Testing/CoreTestSuites |
| `Register-PerformanceTestSuites` | Registers suite collection | Testing/CoreTestSuites |
| `Test-ShouldRunTests` | Test orchestration decision | Testing/TestCacheManager |

### Display & Interactive Operations

| Cmdlet | Reason | Location |
|--------|--------|----------|
| `Invoke-ViewLogs` | Interactive viewer | Utilities/LogViewer |
| `Search-InteractiveLogs` | Interactive search | Utilities/LogViewer |
| `Show-AuditLogs` | Display audit trail | Utilities/Logging |
| `Show-RecentLogs` | Display recent entries | Utilities/LogViewer |
| `Show-Settings` | Display configuration | Configuration |
| `Show-TestResults` | Display test summary | Testing/TestingFramework |
| `Show-UpdatedFiles` | Display file list | Development |

### Other Batch Operations

| Cmdlet | Reason | Location |
|--------|--------|----------|
| `Copy-ExistingReports` | Batch copy operation | Reporting/ReportingEngine |
| `Find-TestFiles` | Discovery returns collection | Testing/TestingFramework |
| `Fix-UnicodeIssues` | Batch fix operation | Utilities |

---

## Scan Methodology

This inventory was generated using:

```bash
# Search for all function definitions with plural patterns
grep -rh "^function" ./aithercore --include="*.psm1" --include="*.ps1" | \
  sed 's/function \([^ {]*\).*/\1/' | \
  grep -E "(Issues|Files|Logs|Tests|Results|Metrics|Items|Submodules|Changes|Settings|Dependencies|Templates|Rules|Suites|Guidelines|Instructions|Examples|Trends|Statistics|Tools)$" | \
  sort -u
```

**Verification Date**: 2025-11-08  
**Total Found**: 61 cmdlets

---

## Related Documents

- [SINGULAR-NOUN-DESIGN.md](./SINGULAR-NOUN-DESIGN.md) - Design philosophy
- [REFACTORING-PLAN-SINGULAR-NOUNS.md](./REFACTORING-PLAN-SINGULAR-NOUNS.md) - Complete refactoring roadmap
- [STYLE-GUIDE.md](./STYLE-GUIDE.md) - Coding standards
- [IMPLEMENTATION-SUMMARY-DOCUMENTATION.md](./IMPLEMENTATION-SUMMARY-DOCUMENTATION.md) - Documentation summary

---

**Status**: Complete inventory - All 61 cmdlets catalogued and categorized  
**Next Action**: Begin Priority 2 refactoring in future sprint
