#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Demonstration of new orchestration engine features (Matrix, Caching, Summaries)

.DESCRIPTION
    This script demonstrates the GitHub Actions-like features added to the orchestration engine:
    - Matrix builds for parallel execution with different configurations
    - Caching system for faster repeated executions
    - Execution summaries as markdown reports

.EXAMPLE
    # Demo 1: Matrix builds
    ./0963_Demo-OrchestrationFeatures.ps1 -Demo Matrix

.EXAMPLE
    # Demo 2: Caching
    ./0963_Demo-OrchestrationFeatures.ps1 -Demo Caching

.EXAMPLE
    # Demo 3: Execution summaries
    ./0963_Demo-OrchestrationFeatures.ps1 -Demo Summary

.EXAMPLE
    # Run all demos
    ./0963_Demo-OrchestrationFeatures.ps1 -Demo All

.NOTES
    Stage: Demonstration
    Dependencies: OrchestrationEngine module
    Tags: orchestration, matrix, caching, demo
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Matrix', 'Caching', 'Summary', 'All')]
    [string]$Demo = 'All'
)

# Initialize
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Import orchestration engine
Import-Module (Join-Path $ProjectRoot "AitherZero.psd1") -Force

# Helper function for demo headers
function Write-DemoHeader {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host ""
}

function Demo-MatrixBuilds {
    Write-DemoHeader "DEMO: Matrix Builds"
    
    Write-Host "Matrix builds allow running the same workflow with different configurations" -ForegroundColor Yellow
    Write-Host "Similar to GitHub Actions 'strategy.matrix'" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Example 1: Simple 2x2 Matrix" -ForegroundColor Green
    Write-Host "  Matrix dimensions:" -ForegroundColor White
    Write-Host "    - profile: quick, comprehensive" -ForegroundColor White
    Write-Host "    - platform: Windows, Linux" -ForegroundColor White
    Write-Host ""
    
    $matrix1 = @{
        profile = @('quick', 'comprehensive')
        platform = @('Windows', 'Linux')
    }
    
    Write-Host "Generating combinations..." -ForegroundColor Yellow
    $combinations = Get-MatrixCombinations -Matrix $matrix1
    Write-Host "  Generated $($combinations.Count) combinations:" -ForegroundColor Green
    $combinations | ForEach-Object {
        $combo = ($_ | ConvertTo-Json -Compress)
        Write-Host "    - $combo" -ForegroundColor White
    }
    
    Write-Host "`nExample 2: Complex 3x2x2 Matrix" -ForegroundColor Green
    Write-Host "  Matrix dimensions:" -ForegroundColor White
    Write-Host "    - os: Windows, Linux, macOS" -ForegroundColor White
    Write-Host "    - psVersion: 7.0, 7.4" -ForegroundColor White
    Write-Host "    - testType: unit, integration" -ForegroundColor White
    Write-Host ""
    
    $matrix2 = @{
        os = @('Windows', 'Linux', 'macOS')
        psVersion = @('7.0', '7.4')
        testType = @('unit', 'integration')
    }
    
    Write-Host "Generating combinations..." -ForegroundColor Yellow
    $combinations2 = Get-MatrixCombinations -Matrix $matrix2
    Write-Host "  Generated $($combinations2.Count) combinations!" -ForegroundColor Green
    Write-Host "  (This would create $($combinations2.Count) parallel jobs in execution)" -ForegroundColor Cyan
    
    Write-Host "`nUsage in orchestration:" -ForegroundColor Green
    Write-Host "  Invoke-OrchestrationSequence -Sequence '0402' -Matrix `$matrix1" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Benefits:" -ForegroundColor Yellow
    Write-Host "  ✓ Test across multiple platforms automatically" -ForegroundColor Green
    Write-Host "  ✓ Run with different configurations in parallel" -ForegroundColor Green
    Write-Host "  ✓ Comprehensive coverage with minimal effort" -ForegroundColor Green
    Write-Host "  ✓ GitHub Actions parity for local development" -ForegroundColor Green
}

function Demo-Caching {
    Write-DemoHeader "DEMO: Caching System"
    
    Write-Host "Caching stores execution results for faster repeated workflows" -ForegroundColor Yellow
    Write-Host "Similar to GitHub Actions 'actions/cache'" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Cache Structure:" -ForegroundColor Green
    Write-Host "  .orchestration-cache/" -ForegroundColor White
    Write-Host "  ├── results/     # Execution results (JSON)" -ForegroundColor White
    Write-Host "  ├── artifacts/   # Script outputs and files" -ForegroundColor White
    Write-Host "  └── metadata/    # Cache keys and metadata" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Example: Cache Key Generation" -ForegroundColor Green
    $testScripts = @(
        @{Number='0402'; Name='Run-UnitTests.ps1'; Path='/path/to/script'}
        @{Number='0404'; Name='Run-PSScriptAnalyzer.ps1'; Path='/path/to/script2'}
    )
    $testVars = @{
        profile = 'quick'
        verbose = $false
    }
    
    Write-Host "  Scripts: 0402, 0404" -ForegroundColor White
    Write-Host "  Variables: profile=quick, verbose=false" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Generating cache key..." -ForegroundColor Yellow
    $cacheKey = Get-OrchestrationCacheKey -Scripts $testScripts -Variables $testVars
    Write-Host "  Cache key: $cacheKey" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Cache benefits:" -ForegroundColor Yellow
    Write-Host "  First run:  Execute all scripts, save to cache (5 minutes)" -ForegroundColor White
    Write-Host "  Second run: Load from cache if unchanged (<10 seconds)" -ForegroundColor White
    Write-Host "  Result: ~30x faster for cached runs!" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Usage in orchestration:" -ForegroundColor Green
    Write-Host "  Invoke-OrchestrationSequence -LoadPlaybook 'test-full' -UseCache" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Cache invalidation:" -ForegroundColor Yellow
    Write-Host "  ✓ Automatic when scripts or variables change" -ForegroundColor Green
    Write-Host "  ✓ Manual: Remove-Item '.orchestration-cache' -Recurse" -ForegroundColor Green
}

function Demo-ExecutionSummaries {
    Write-DemoHeader "DEMO: Execution Summaries"
    
    Write-Host "Execution summaries generate markdown reports after workflow completion" -ForegroundColor Yellow
    Write-Host "Similar to GitHub Actions job summaries" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Example Summary Output:" -ForegroundColor Green
    Write-Host ""
    
    $exampleSummary = @"
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
"@
    
    Write-Host $exampleSummary -ForegroundColor White
    Write-Host ""
    
    Write-Host "Usage in orchestration:" -ForegroundColor Green
    Write-Host "  Invoke-OrchestrationSequence -LoadPlaybook 'ci-all-validations' -GenerateSummary" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Summary features:" -ForegroundColor Yellow
    Write-Host "  ✓ Markdown format for easy sharing" -ForegroundColor Green
    Write-Host "  ✓ Success/failure metrics and rates" -ForegroundColor Green
    Write-Host "  ✓ Variable dump for reproducibility" -ForegroundColor Green
    Write-Host "  ✓ Failed script details with errors" -ForegroundColor Green
    Write-Host "  ✓ Matrix combination breakdown" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Output location:" -ForegroundColor Yellow
    Write-Host "  reports/orchestration/summary-TIMESTAMP.md" -ForegroundColor White
}

function Demo-CombinedFeatures {
    Write-DemoHeader "DEMO: Combined Features - Maximum Power!"
    
    Write-Host "Combine all features for ultimate workflow efficiency" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Example: Comprehensive Test Workflow" -ForegroundColor Green
    Write-Host ""
    
    $command = @"
Invoke-OrchestrationSequence ``
    -LoadPlaybook 'test-comprehensive' ``
    -Matrix @{
        profile = @('quick', 'standard', 'comprehensive')
        coverage = @(`$true, `$false)
    } ``
    -UseCache ``
    -GenerateSummary ``
    -MaxConcurrency 8
"@
    
    Write-Host $command -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "This single command:" -ForegroundColor Yellow
    Write-Host "  1. Loads the 'test-comprehensive' playbook" -ForegroundColor White
    Write-Host "  2. Expands into 6 matrix jobs (3 profiles × 2 coverage options)" -ForegroundColor White
    Write-Host "  3. Runs up to 8 jobs in parallel" -ForegroundColor White
    Write-Host "  4. Caches results for subsequent runs" -ForegroundColor White
    Write-Host "  5. Generates a comprehensive markdown summary" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Performance comparison:" -ForegroundColor Yellow
    Write-Host "  Before: Sequential, no cache" -ForegroundColor White
    Write-Host "    → 6 jobs × 2 minutes = 12 minutes" -ForegroundColor Red
    Write-Host ""
    Write-Host "  After: Parallel + matrix + caching" -ForegroundColor White
    Write-Host "    → First run: 6 jobs ÷ 8 parallel = ~2 minutes" -ForegroundColor Green
    Write-Host "    → Cached run: <10 seconds" -ForegroundColor Green
    Write-Host "    → Improvement: ~72x faster!" -ForegroundColor Cyan
}

# Main execution
try {
    Write-Host ""
    Write-Host "===========================================================================" -ForegroundColor Magenta
    Write-Host "  AitherZero Orchestration Engine - New Features Demonstration" -ForegroundColor Magenta
    Write-Host "  GitHub Actions Parity: Matrix Builds, Caching, Summaries" -ForegroundColor Magenta
    Write-Host "===========================================================================" -ForegroundColor Magenta
    
    switch ($Demo) {
        'Matrix' {
            Demo-MatrixBuilds
        }
        'Caching' {
            Demo-Caching
        }
        'Summary' {
            Demo-ExecutionSummaries
        }
        'All' {
            Demo-MatrixBuilds
            Demo-Caching
            Demo-ExecutionSummaries
            Demo-CombinedFeatures
        }
    }
    
    Write-Host ""
    Write-Host ("=" * 80) -ForegroundColor Magenta
    Write-Host "  For more information, see: ORCHESTRATION-ENHANCEMENTS.md" -ForegroundColor Magenta
    Write-Host ("=" * 80) -ForegroundColor Magenta
    Write-Host ""
    
    exit 0
    
} catch {
    Write-Error "Demo failed: $_"
    exit 1
}
