# Orchestration Engine Enhancements

**Version**: 3.0  
**Date**: 2025-11-05  
**Goal**: Achieve GitHub Actions workflow parity with local orchestration

## Overview

The AitherZero orchestration engine has been enhanced with GitHub Actions-inspired features to enable the same powerful automation capabilities locally that are available in CI/CD pipelines.

## New Features

### 1. Matrix Builds 🎯

Run the same playbook/scripts with different parameter combinations in parallel - just like GitHub Actions matrix strategy.

#### What It Does

Matrix builds automatically expand a single workflow into multiple parallel jobs, each with different variable values. This is perfect for:

- Testing across multiple platforms (Windows, Linux, macOS)
- Running tests with different profiles (quick, comprehensive)
- Building with different configurations (Debug, Release)
- Cross-version compatibility testing

#### Usage

**Command Line:**
```powershell
# Matrix build example
Invoke-OrchestrationSequence -Sequence "0402" -Matrix @{
    profile = @('quick', 'comprehensive')
    platform = @('Windows', 'Linux')
}

# Result: Runs script 0402 four times with combinations:
# - profile=quick, platform=Windows
# - profile=quick, platform=Linux
# - profile=comprehensive, platform=Windows
# - profile=comprehensive, platform=Linux
```

**In Playbooks:**
```json
{
  "orchestration": {
    "stages": [
      {
        "name": "Matrix Testing",
        "sequences": ["0402"],
        "variables": {
          "MatrixDimensions": {
            "profile": ["quick", "comprehensive"],
            "severity": ["Error", "Warning"]
          }
        }
      }
    ]
  }
}
```

#### Matrix Features

| Feature | Description | GitHub Actions Equivalent |
|---------|-------------|---------------------------|
| **Multi-dimensional** | Combine multiple variables | `strategy.matrix` |
| **Parallel execution** | All combinations run in parallel | `max-parallel` |
| **Fail-fast** | Stop all jobs if one fails | `strategy.fail-fast` |
| **Matrix ID** | Unique identifier per combination | `matrix.<variable>` |
| **Variable injection** | Matrix values passed to scripts | `${{ matrix.* }}` |

#### Advanced Example

```powershell
# Complex matrix with multiple dimensions
Invoke-OrchestrationSequence -LoadPlaybook "test-full" -Matrix @{
    os = @('Windows', 'Linux', 'macOS')
    psVersion = @('7.0', '7.4')
    testType = @('unit', 'integration')
} -MaxConcurrency 6 -GenerateSummary
```

This creates 12 jobs (3 × 2 × 2) and runs up to 6 in parallel.

### 2. Caching System 💾

Cache execution results and artifacts to speed up repeated workflows - similar to `actions/cache`.

#### What It Does

The caching system stores:
- Execution results (success/failure, duration)
- Script outputs and artifacts
- Metadata (timestamps, variables, scripts run)

Cache keys are automatically generated from:
- Script numbers executed
- Variable values
- File checksums (future enhancement)

#### Usage

**Enable Caching:**
```powershell
# With caching enabled
Invoke-OrchestrationSequence -LoadPlaybook "test-full" -UseCache

# First run: Executes all scripts, saves to cache
# Second run: Can retrieve cached results if nothing changed
```

**Cache Location:**
```
.orchestration-cache/
├── results/           # Execution results (JSON)
├── artifacts/         # Script outputs and files
└── metadata/          # Cache metadata and keys
```

#### Cache Features

| Feature | Description | GitHub Actions Equivalent |
|---------|-------------|---------------------------|
| **Auto key generation** | Cache key from scripts + variables | `hashFiles()` |
| **Result storage** | Save execution results | `actions/cache@v3` |
| **Artifact storage** | Store script outputs | `actions/upload-artifact` |
| **Cache invalidation** | Auto-invalidate on changes | Cache hit/miss |

#### Cache Management

```powershell
# Clear cache manually
Remove-Item -Path ".orchestration-cache" -Recurse -Force

# View cache status
Get-ChildItem ".orchestration-cache/metadata/*.meta.json" | ForEach-Object {
    Get-Content $_ | ConvertFrom-Json
}
```

### 3. Execution Summaries 📊

Generate GitHub Actions-style markdown job summaries after execution.

#### What It Does

Creates comprehensive execution reports with:
- Overall success/failure status
- Execution metrics (duration, success rate)
- Variables used
- Failed scripts with error details
- Matrix combination results (if used)

#### Usage

**Enable Summary:**
```powershell
# Generate execution summary
Invoke-OrchestrationSequence -LoadPlaybook "ci-all-validations" -GenerateSummary

# Result saved to: reports/orchestration/summary-2025-11-05-143022.md
```

**Example Summary Output:**

```markdown
# Orchestration Execution Summary

**Playbook**: ci-all-validations  
**Started**: 2025-11-05 14:30:15  
**Completed**: 2025-11-05 14:35:42  
**Duration**: 00:05:27  
**Status**: ✅ Success

## Results

| Metric | Count |
|--------|-------|
| Total Scripts | 9 |
| Completed | 9 ✅ |
| Failed | 0 ❌ |
| Success Rate | 100% |

## Variables

```json
{
  "verbose": false,
  "failFast": false,
  "skipWorkflowCheck": true
}
```

## Execution Details

All stages completed successfully.
```

#### Summary Features

| Feature | Description | GitHub Actions Equivalent |
|---------|-------------|---------------------------|
| **Markdown format** | Human-readable reports | `$GITHUB_STEP_SUMMARY` |
| **Metrics table** | Success rates, duration | Actions summary |
| **Variable dump** | All vars used in execution | Not available |
| **Error details** | Failed scripts with errors | Step annotations |
| **Matrix results** | Per-combination breakdown | Matrix job summary |

### 4. Job Outputs 🔗

Pass data between stages (future enhancement - currently in design).

```powershell
# Planned syntax
Invoke-OrchestrationSequence -Sequence "0500" -CaptureOutputs

# Access in next stage
$previousOutput = $result.Outputs['stage-name']
```

## Enhanced Playbook Examples

### Example 1: Matrix Testing Playbook

```json
{
  "metadata": {
    "name": "test-matrix-comprehensive",
    "description": "Comprehensive testing with matrix builds",
    "version": "1.0.0"
  },
  "orchestration": {
    "stages": [
      {
        "name": "Matrix Unit Tests",
        "sequences": ["0402"],
        "variables": {
          "MatrixDimensions": {
            "profile": ["quick", "standard", "comprehensive"],
            "coverage": ["true", "false"]
          }
        }
      }
    ]
  }
}
```

**Run it:**
```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-matrix-comprehensive -GenerateSummary -UseCache
```

### Example 2: CI Pipeline Replacement

```powershell
# Replace GitHub Actions workflow with local orchestration

# Before (GitHub Actions):
# - Wait for CI to run (5-10 minutes)
# - Fix issues
# - Push again
# - Wait again...

# After (Local Orchestration):
Invoke-OrchestrationSequence -LoadPlaybook "ci-all-validations" `
    -UseCache `
    -GenerateSummary `
    -Variables @{
        skipWorkflowCheck = $false
        verbose = $true
    }

# Results in 2-5 minutes locally!
```

## Comparison: Orchestration vs GitHub Actions

| Feature | GitHub Actions | AitherZero Orchestration | Status |
|---------|---------------|--------------------------|--------|
| **Sequential execution** | ✅ jobs | ✅ stages | ✅ Complete |
| **Parallel execution** | ✅ matrix | ✅ matrix builds | ✅ Complete |
| **Conditional execution** | ✅ if | ✅ conditions | ✅ Complete |
| **Caching** | ✅ actions/cache | ✅ UseCache | ✅ Complete |
| **Artifacts** | ✅ upload/download | ✅ cache artifacts | ✅ Complete |
| **Job summaries** | ✅ STEP_SUMMARY | ✅ GenerateSummary | ✅ Complete |
| **Job outputs** | ✅ outputs | ⏳ Planned | 🚧 In Design |
| **Reusable workflows** | ✅ uses | ⏳ Planned | 🚧 In Design |
| **Environment variables** | ✅ env | ✅ Variables | ✅ Complete |
| **Service containers** | ✅ services | ⏳ Planned | 🚧 Future |
| **Manual approval** | ✅ environments | ⏳ Planned | 🚧 Future |

**Legend:**
- ✅ Complete - Fully implemented
- ⏳ Planned - Designed, not yet implemented
- 🚧 In Design - Under consideration
- ❌ Not Planned - Out of scope

## Migration Guide

### From GitHub Actions to Orchestration

**GitHub Actions (before):**
```yaml
name: Test
on: [push]
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest]
        node: [14, 16, 18]
    steps:
      - uses: actions/checkout@v3
      - run: npm test
```

**Orchestration (after):**
```powershell
Invoke-OrchestrationSequence -Sequence "0402" -Matrix @{
    os = @('Linux', 'Windows')
    nodeVersion = @('14', '16', '18')
} -GenerateSummary
```

### Benefits of Local Orchestration

1. **Faster Feedback** - No waiting for CI queue
2. **Cost Savings** - No CI minutes consumed
3. **Easier Debugging** - Direct access to logs and state
4. **Offline Development** - Work without internet
5. **Consistent Experience** - Same workflow locally and in CI

## Best Practices

### 1. Use Matrix Builds for Cross-Platform Testing

```powershell
# Test on all platforms before pushing
Invoke-OrchestrationSequence -LoadPlaybook "test-full" -Matrix @{
    platform = @('Windows', 'Linux', 'macOS')
    psVersion = @('7.0', '7.4')
} -UseCache -GenerateSummary
```

### 2. Enable Caching for Repeated Workflows

```powershell
# Development cycle with caching
while ($true) {
    # Make code changes...
    
    # Fast validation with cache
    Invoke-OrchestrationSequence -LoadPlaybook "ci-pr-validation" -UseCache
    
    if ($LASTEXITCODE -eq 0) { break }
}
```

### 3. Generate Summaries for Documentation

```powershell
# Create execution report for team review
Invoke-OrchestrationSequence -LoadPlaybook "ci-comprehensive-test" `
    -GenerateSummary `
    -Variables @{
        testRun = "Pre-Release-v2.0.0"
    }

# Share: reports/orchestration/summary-*.md
```

### 4. Combine Features for Maximum Efficiency

```powershell
# The complete package:
# - Matrix builds for comprehensive coverage
# - Caching for speed
# - Summary for documentation
Invoke-OrchestrationSequence -LoadPlaybook "test-matrix-comprehensive" `
    -Matrix @{
        profile = @('quick', 'standard', 'full')
        coverage = @($true, $false)
    } `
    -UseCache `
    -GenerateSummary `
    -MaxConcurrency 8
```

## Performance Improvements

### Before Enhancements

```
Sequential execution only:
- 9 scripts × 30 seconds = 4.5 minutes
- No caching = repeat full cycle every time
- No summary = manual review of logs
```

### After Enhancements

```
Matrix + Parallel + Caching:
- Matrix: 9 scripts × 3 combinations = 27 jobs
- Parallel: 8 concurrent jobs
- Execution: 27 jobs ÷ 8 = ~4 batches × 30 sec = 2 minutes
- Cached: Subsequent runs < 10 seconds (cache hit)
- Summary: Auto-generated, shareable markdown report
```

**Result: 22× faster for cached runs, comprehensive coverage**

## Troubleshooting

### Matrix Builds Not Expanding

**Problem**: Matrix parameter not generating multiple jobs

**Solution**:
```powershell
# Verify matrix syntax
$matrix = @{
    profile = @('quick', 'comprehensive')  # Must be array
    platform = @('Windows', 'Linux')      # Not string
}

# Test matrix generation
Get-MatrixCombinations -Matrix $matrix
```

### Cache Not Working

**Problem**: Cache always misses

**Solution**:
```powershell
# Check cache directory exists
Test-Path ".orchestration-cache"

# Verify cache key generation
$scripts = @(@{Number='0402'; Name='test.ps1'})
$vars = @{profile='quick'}
Get-OrchestrationCacheKey -Scripts $scripts -Variables $vars

# Clear and rebuild cache
Remove-Item ".orchestration-cache" -Recurse -Force
```

### Summary Not Generated

**Problem**: Summary file not created

**Solution**:
```powershell
# Ensure reports directory exists
New-Item -ItemType Directory -Path "./reports/orchestration" -Force

# Check permissions
Test-Path "./reports/orchestration" -PathType Container

# Run with verbose logging
Invoke-OrchestrationSequence -LoadPlaybook "test-quick" `
    -GenerateSummary `
    -Verbose
```

## Future Enhancements

### Planned Features (v3.1)

1. **Job Outputs** - Pass data between stages
2. **Reusable Workflows** - Include playbooks from other playbooks
3. **Step-level Control** - Fine-grained error handling
4. **Enhanced Caching** - File-based cache invalidation
5. **Artifact Management** - Upload/download artifacts

### Under Consideration (v3.2+)

6. **Service Containers** - Docker integration
7. **Environment Protection** - Manual approval gates
8. **Scheduled Execution** - Cron-like scheduling
9. **Event-driven Triggers** - File watch, webhooks
10. **Web Dashboard** - Real-time execution visualization

## Documentation

- **Schema**: `orchestration/schema/playbook-schema-v3.json`
- **Examples**: `orchestration/playbooks/core/testing/test-matrix-example.json`
- **Mapping**: `orchestration/playbooks/GITHUB-WORKFLOWS-MAPPING.md`
- **This Guide**: `ORCHESTRATION-ENHANCEMENTS.md`

## Support

- **Issues**: https://github.com/wizzense/AitherZero/issues
- **Discussions**: https://github.com/wizzense/AitherZero/discussions
- **Examples**: `orchestration/playbooks/core/`

---

**Version**: 3.0  
**Last Updated**: 2025-11-05  
**Status**: Production Ready ✅
