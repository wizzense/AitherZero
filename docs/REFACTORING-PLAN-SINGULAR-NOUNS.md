# Singular Noun Refactoring Plan

## Overview

This document tracks the refactoring of plural noun cmdlets to follow the singular noun design pattern across the AitherZero project.

**Total Functions Found**: 69 with plural nouns  
**Priority 1 Status**: ✅ COMPLETED (Infrastructure submodules)  
**Documentation Status**: ✅ COMPLETE (All guides ready)  
**Priorities 2-6**: Planned for future sprints

## Refactoring Priorities

### Priority 1: High-Impact Pipeline Cmdlets (Immediate)

These cmdlets are frequently used in pipelines and would benefit most from refactoring:

| Current Name | Proposed Name | Rationale | Effort |
|--------------|---------------|-----------|--------|
| ~~`Update-InfrastructureSubmodules`~~ | ~~`Update-InfrastructureSubmodule`~~ | ✅ **COMPLETED** | Done |
| ~~`Get-InfrastructureSubmodules`~~ | ~~`Get-InfrastructureSubmodule`~~ | ✅ **COMPLETED** | Done |
| ~~`Sync-InfrastructureSubmodules`~~ | ~~`Sync-InfrastructureSubmodule`~~ | ✅ **COMPLETED** | Done |
| `Get-GitHubIssues` | `Get-GitHubIssue` | Pipeline for issue processing | Medium |
| `Get-LogFiles` | `Get-LogFile` | Stream log files for analysis | Medium |
| `Get-Logs` | `Get-Log` | Stream individual log entries | Medium |
| `Search-Logs` | `Search-Log` | Search and stream matching logs | Medium |

### Priority 2: Test Generation Cmdlets (High)

Test generators should output one test at a time for flexibility:

| Current Name | Proposed Name | Status | Notes |
|--------------|---------------|--------|-------|
| `Build-ErrorHandlingTests` | `Build-ErrorHandlingTest` | Pending | Generate one test per function |
| `Build-FunctionalTests` | `Build-FunctionalTest` | Pending | Stream test generation |
| `Build-MockTests` | `Build-MockTest` | Pending | One mock test per scenario |
| `Build-StructuralTests` | `Build-StructuralTest` | Pending | Stream structural tests |
| `New-AllAutomationTests` | `New-AutomationTest` | Pending | Generate per script |
| `New-DependencyTests` | `New-DependencyTest` | Pending | One test per dependency |
| `New-ErrorHandlingTests` | `New-ErrorHandlingTest` | Pending | Stream error tests |
| `New-ExecutionTests` | `New-ExecutionTest` | Pending | One execution test |
| `New-FunctionTests` | `New-FunctionTest` | Pending | Per-function test |
| `New-ParameterTests` | `New-ParameterTest` | Pending | Per-parameter test |
| `New-PlatformTests` | `New-PlatformTest` | Pending | Per-platform test |

### Priority 3: Metrics and Reporting (Medium)

Metrics cmdlets should stream individual metric objects:

| Current Name | Proposed Name | Status | Notes |
|--------------|---------------|--------|-------|
| `Get-AitherMetrics` | `Get-AitherMetric` | Pending | Stream metric types |
| `Export-AitherMetrics` | `Export-AitherMetric` | Pending | Export one metric |
| `Get-CodeQualityMetrics` | `Get-CodeQualityMetric` | Pending | Individual metrics |
| `Get-ExecutionMetrics` | `Get-ExecutionMetric` | Pending | Per-execution metric |
| `Get-FileLevelMetrics` | `Get-FileLevelMetric` | Pending | Per-file metrics |
| `Get-PerformanceMetrics` | `Get-PerformanceMetric` | Pending | Stream perf metrics |
| `Get-ProjectMetrics` | `Get-ProjectMetric` | Pending | Individual metrics |
| `Get-PSScriptAnalyzerMetrics` | `Get-PSScriptAnalyzerMetric` | Pending | Per-rule metric |
| `Get-QualityMetrics` | `Get-QualityMetric` | Pending | Stream quality data |
| `Get-SystemMetrics` | `Get-SystemMetric` | Pending | System metric types |
| `Get-AutomationMetrics` | `Get-AutomationMetric` | Pending | Per-script metric |
| `Get-MockMetrics` | `Get-MockMetric` | Pending | Mock usage metrics |
| `Show-ProjectMetrics` | `Show-ProjectMetric` | Pending | Display one metric |

### Priority 4: Maintenance Operations (Medium)

| Current Name | Proposed Name | Status | Notes |
|--------------|---------------|--------|-------|
| `Clear-LogFiles` | `Clear-LogFile` | Pending | Clear one log |
| `Clear-Logs` | `Clear-Log` | Pending | Clear individual logs |
| `Clear-OldLogs` | `Clear-OldLog` | Pending | Clean one old log |
| `Clear-ReportFiles` | `Clear-ReportFile` | Pending | Clear one report |
| `Clear-TemporaryFiles` | `Clear-TemporaryFile` | Pending | Clear one temp file |
| `Clear-TestResults` | `Clear-TestResult` | Pending | Clear one result |

### Priority 5: Analysis and Result Cmdlets (Low)

| Current Name | Proposed Name | Status | Notes |
|--------------|---------------|--------|-------|
| `Get-AnalysisResults` | `Get-AnalysisResult` | Pending | Stream results |
| `Get-CachedResults` | `Get-CachedResult` | Pending | Cached result objects |
| `Get-DetailedTestResults` | `Get-DetailedTestResult` | Pending | Test result stream |
| `Get-LatestAnalysisResults` | `Get-LatestAnalysisResult` | Pending | Latest results |
| `Get-LatestTestResults` | `Get-LatestTestResult` | Pending | Test results |
| `Get-TestResults` | `Get-TestResult` | Pending | Stream test results |
| `Save-AnalysisResults` | `Save-AnalysisResult` | Pending | Save one result |
| `Set-CachedResults` | `Set-CachedResult` | Pending | Cache one result |
| `Merge-AnalysisResults` | `Merge-AnalysisResult` | Pending | Merge one result |
| `Format-SearchResults` | `Format-SearchResult` | Pending | Format one result |

### Priority 6: Keep as Plural (Batch Operations)

These cmdlets perform inherently batch operations and should remain plural:

| Function Name | Reason to Keep Plural | Action |
|---------------|----------------------|---------|
| `Analyze-Changes` | Analyzes git changeset as a whole | Keep |
| `Analyze-SecurityIssues` | Security analysis of entire codebase | Keep |
| `Copy-ExistingReports` | Batch copy operation | Keep |
| `Find-TestFiles` | Discovery returns collection | Keep |
| `Fix-UnicodeIssues` | Batch fix operation | Keep |
| `Get-AllLogFiles` | Explicit "all" operation | Keep |
| `Get-AllPowerShellFiles` | Explicit "all" operation | Keep |
| `Get-AuditLogs` | Audit log is a collection | Keep |
| `Get-HistoricalMetrics` | Time-series data | Keep |
| `Get-OrchestrationLogs` | Orchestration log stream | Keep |
| `Get-StagedChanges` | Git staging area | Keep |
| `Invoke-LegacyPesterTests` | Legacy batch runner | Keep |
| `Invoke-ViewLogs` | Interactive viewer | Keep |
| `Search-InteractiveLogs` | Interactive search | Keep |
| `Show-AuditLogs` | Display audit trail | Keep |
| `Show-RecentLogs` | Display recent entries | Keep |
| `Show-Settings` | Display configuration | Keep |
| `Show-TestResults` | Display test summary | Keep |
| `Show-UpdatedFiles` | Display file list | Keep |
| `Test-ShouldRunTests` | Test orchestration decision | Keep |

## Refactoring Checklist

For each cmdlet being refactored:

### Phase 1: Analysis
- [ ] Review current function implementation
- [ ] Identify if it processes multiple items internally
- [ ] Check for pipeline input support
- [ ] Review all call sites

### Phase 2: Design
- [ ] Design singular version with `Begin/Process/End`
- [ ] Add `InputObject` parameter for pipeline
- [ ] Add parameter sets (ByObject, ByName, ByPath, etc.)
- [ ] Design output object with PSTypeName

### Phase 3: Implementation
- [ ] Create new singular function
- [ ] Add Begin block for initialization
- [ ] Add Process block for single-item processing
- [ ] Add End block for cleanup/summary
- [ ] Support pipeline input with ValueFromPipeline
- [ ] Add ShouldProcess support
- [ ] Return processed objects for chaining

### Phase 4: Testing
- [ ] Write pipeline tests
- [ ] Write parameter set tests
- [ ] Write parallel processing tests
- [ ] Test with ForEach-Object -Parallel
- [ ] Verify output streaming

### Phase 5: Migration
- [ ] Update all call sites
- [ ] Update documentation
- [ ] Update examples
- [ ] Add deprecation notice to old function
- [ ] Update tests

### Phase 6: Cleanup
- [ ] Remove old plural function (after deprecation period)
- [ ] Update changelog
- [ ] Update release notes

## Implementation Template

```powershell
function Get-Item {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType('AitherZero.Item')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByObject')]
        [PSCustomObject]$InputObject,

        [Parameter(ParameterSetName = 'ByName', ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByPath', ValueFromPipelineByPropertyName)]
        [string]$Path,

        [Parameter()]
        [switch]$Detailed
    )

    begin {
        Write-Verbose "Starting Get-Item operation"
        $config = Get-Configuration -ErrorAction SilentlyContinue
    }

    process {
        try {
            # Determine target
            $target = switch ($PSCmdlet.ParameterSetName) {
                'ByObject' { $InputObject }
                'ByName' { Get-ItemByName -Name $Name }
                'ByPath' { Get-ItemByPath -Path $Path }
            }

            # Process single item
            $result = [PSCustomObject]@{
                PSTypeName = 'AitherZero.Item'
                Name = $target.Name
                Path = $target.Path
                # ... other properties
            }

            # Add detailed info if requested
            if ($Detailed) {
                # ... add detailed properties
            }

            # Output for pipeline
            Write-Output $result
        }
        catch {
            Write-Error "Failed to get item: $_"
            throw
        }
    }

    end {
        Write-Verbose "Get-Item operation complete"
    }
}
```

## Testing Template

```powershell
Describe "Get-Item" {
    Context "Pipeline Support" {
        It "Should accept pipeline input" {
            $items = @(
                [PSCustomObject]@{ Name = 'item1' }
                [PSCustomObject]@{ Name = 'item2' }
            )
            { $items | Get-Item } | Should -Not -Throw
        }

        It "Should stream items one at a time" {
            $count = 0
            Get-Item | ForEach-Object { $count++ }
            $count | Should -BeGreaterThan 0
        }

        It "Should work with Where-Object" {
            $filtered = Get-Item | Where-Object { $_.Name -like '*test*' }
            $filtered | Should -Not -BeNullOrEmpty
        }

        It "Should work with ForEach-Object -Parallel" {
            $results = Get-Item | ForEach-Object -Parallel {
                $_.Name
            } -ThrottleLimit 2
            $results | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameter Sets" {
        It "Should work with -Name" {
            { Get-Item -Name 'test' } | Should -Not -Throw
        }

        It "Should work with -Path" {
            { Get-Item -Path '/test/path' } | Should -Not -Throw
        }

        It "Should work with InputObject" {
            $obj = [PSCustomObject]@{ Name = 'test' }
            { Get-Item -InputObject $obj } | Should -Not -Throw
        }
    }
}
```

## Progress Tracking

### Priority 1: Infrastructure Cmdlets ✅ COMPLETED
- [x] Infrastructure submodule cmdlets (COMPLETED)
  - [x] Get-InfrastructureSubmodule
  - [x] Update-InfrastructureSubmodule
  - [x] Sync-InfrastructureSubmodule
- [x] Documentation complete
  - [x] docs/SINGULAR-NOUN-DESIGN.md
  - [x] docs/STYLE-GUIDE.md
  - [x] .github/copilot-instructions.md updated
  - [x] infrastructure/SUBMODULES.md updated

### Priority 2: High-Impact Pipeline Cmdlets (Future Sprint)
- [ ] Get-GitHubIssue
- [ ] Get-LogFile
- [ ] Get-Log
- [ ] Search-Log

### Priority 3: Test Generation Cmdlets (Future Sprint)
- [ ] Test generation cmdlets (11 total)

### Priority 4: Metrics and Reporting (Future Sprint)
- [ ] Metrics cmdlets (13 total)

### Priority 5: Maintenance Operations (Future Sprint)
- [ ] Maintenance cmdlets (6 total)

### Priority 6: Analysis and Result Cmdlets (Future Sprint)
- [ ] Analysis cmdlets (10 total)

## Documentation Updates Required

- [x] docs/SINGULAR-NOUN-DESIGN.md (Created)
- [x] .github/copilot-instructions.md (Add singular noun guidance) - COMPLETED
- [x] docs/STYLE-GUIDE.md (Add singular noun section) - COMPLETED
- [x] README.md (Update examples) - Not needed, infrastructure examples not in README
- [x] infrastructure/SUBMODULES.md (Updated) - COMPLETED
- [ ] All cmdlet help examples - To be updated as Priority 2-6 cmdlets are refactored

## Style Guide Integration

Add to `.github/copilot-instructions.md` and `docs/STYLE-GUIDE.md`:

```markdown
## PowerShell Cmdlet Naming

**ALWAYS use singular nouns for cmdlets:**

❌ Wrong:
- `Get-Items`
- `Update-Files`
- `Remove-Logs`

✅ Correct:
- `Get-Item` (processes one, supports pipeline)
- `Update-File` (updates one, supports pipeline)
- `Remove-Log` (removes one, supports pipeline)

**Key Principles:**
1. Cmdlets process ONE object at a time
2. Use Begin/Process/End blocks
3. Support pipeline with ValueFromPipeline
4. Enable ForEach-Object -Parallel
5. Return processed objects for chaining

See docs/SINGULAR-NOUN-DESIGN.md for complete guidelines.
```

## Notes

- Some cmdlets genuinely need to remain plural (batch operations, collections)
- Focus on high-impact pipeline cmdlets first
- Maintain backward compatibility during transition
- Add deprecation warnings before removing old functions
- Update all examples and documentation

## References

- docs/SINGULAR-NOUN-DESIGN.md
- PowerShell Best Practices
- about_Functions_Advanced_Methods
- about_Functions_CmdletBindingAttribute

---

**Last Updated**: 2025-11-08  
**Status**: Priority 1 COMPLETE - Documentation Ready - Priorities 2-6 Planned  
**Next Phase**: Priority 2 cmdlets (scheduled for future sprint)
