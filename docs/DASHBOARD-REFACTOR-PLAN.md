# Dashboard Generation Refactoring Plan

## Overview
Refactor monolithic 5280-line 0512_Generate-Dashboard.ps1 into modular, maintainable components.

## Architecture

### Module: aithercore/reporting/DashboardGeneration.psm1 ✅ CREATED
Core dashboard generation functions:
- Initialize-DashboardSession
- Register-DashboardMetrics
- New-DashboardHTML
- New-DashboardJSON
- Complete-DashboardSession
- Import-MetricsFromJSON
- Get-AggregatedTestResults

### Automation Scripts (library/automation-scripts/)

#### ✅ 0520_Collect-RingMetrics.ps1 - CREATED
Collects ring strategy health metrics:
- Branch health status
- Active PRs per ring
- Commit activity (last 7 days)
- Test pass rates
- Quality scores
- Deployment status

#### 0521_Collect-WorkflowHealth.ps1 - TODO
Collects GitHub Actions workflow metrics:
- Workflow success rates (last 50 runs)
- Duration trends
- Job failure analysis
- Concurrency utilization
- Cost analysis (minutes consumed)
- Bottleneck detection

#### 0522_Collect-CodeMetrics.ps1 - TODO
Collects code quality and complexity metrics:
- Lines of code by type
- Cyclomatic complexity
- Function/file size distribution
- Code duplication detection
- Module dependency mapping
- Dead code detection

#### 0523_Collect-TestMetrics.ps1 - TODO
Aggregates test execution metrics:
- Test results from all 19 parallel jobs
- Coverage data
- Flaky test detection
- Test performance trends
- Test gap analysis

#### 0524_Collect-QualityMetrics.ps1 - TODO
Aggregates code quality data:
- PSScriptAnalyzer results
- Code smell detection
- Maintainability index
- Comment density
- Quality trends (30 days)

#### 0525_Generate-DashboardHTML.ps1 - TODO
Orchestrates HTML generation:
- Loads all collected metrics
- Applies templates
- Generates complete dashboard
- Creates index pages

### HTML Templates (library/_templates/dashboard/)

#### TODO: Create Templates
- executive-summary.html
- ring-health.html
- test-results.html
- quality-metrics.html
- code-map.html
- workflow-health.html
- configuration-explorer.html
- main-dashboard.html (master template)

### Playbooks

#### dashboard-generation-complete.psd1 - TODO
Complete dashboard generation orchestration:
```powershell
Sequence = @(
    # Phase 1: Collect Metrics (Parallel)
    @{ Script = "0520"; Description = "Ring metrics"; Parallel = $true }
    @{ Script = "0521"; Description = "Workflow health"; Parallel = $true }
    @{ Script = "0522"; Description = "Code metrics"; Parallel = $true }
    @{ Script = "0523"; Description = "Test metrics"; Parallel = $true }
    @{ Script = "0524"; Description = "Quality metrics"; Parallel = $true }
    
    # Phase 2: Generate Dashboard (Sequential)
    @{ Script = "0525"; Description = "Generate HTML dashboard" }
)
```

## Refactored 0512_Generate-Dashboard.ps1

The existing script will become a thin wrapper that:
1. Imports DashboardGeneration module
2. Calls playbook for full generation, OR
3. Provides backward compatibility by calling individual scripts

## Workflow Simplification

### Before (Complex)
```yaml
- name: Generate Dashboard
  shell: pwsh
  run: |
    Import-Module ./AitherZero.psd1
    # Complex inline logic...
    Invoke-OrchestrationSequence -LoadPlaybook pr-ecosystem-report
```

### After (Simple)
```yaml
- name: Generate Dashboard
  shell: pwsh
  run: |
    ./bootstrap.ps1 -Mode Update
    Invoke-AitherScript -Playbook dashboard-generation-complete
```

## Benefits

1. **Modularity**: Each component has single responsibility
2. **Testability**: Easy to unit test individual collectors
3. **Reusability**: Metrics collection can be used separately
4. **Parallelism**: Collection scripts can run concurrently
5. **Maintainability**: 200-300 line scripts vs 5000+ lines
6. **Flexibility**: Can generate dashboard without workflows
7. **Templates**: Easy to customize visualizations

## Implementation Status

- [x] Create DashboardGeneration.psm1
- [x] Create 0520_Collect-RingMetrics.ps1
- [ ] Create 0521_Collect-WorkflowHealth.ps1
- [ ] Create 0522_Collect-CodeMetrics.ps1
- [ ] Create 0523_Collect-TestMetrics.ps1
- [ ] Create 0524_Collect-QualityMetrics.ps1
- [ ] Create 0525_Generate-DashboardHTML.ps1
- [ ] Create HTML templates
- [ ] Create dashboard-generation-complete.psd1 playbook
- [ ] Refactor 0512 to use new architecture
- [ ] Update pr-ecosystem-report.psd1 to use new playbook
- [ ] Simplify workflows to call playbooks only

## Next Steps

1. Complete remaining collector scripts (0521-0524)
2. Create HTML templates
3. Create 0525 dashboard generator
4. Create playbook
5. Test standalone execution
6. Update workflows
7. Deprecate monolithic 0512 (keep for backward compat)
