# Playbook Concurrency Guide: Mimicking Pester's Parallel Testing

## Overview

This guide explains how to leverage AitherZero playbooks to achieve efficient parallel test execution similar to Pester's native concurrency features, while taking advantage of the orchestration engine's capabilities.

## Current Limitations

The playbook system currently has basic parallel execution support but doesn't fully leverage all of Pester's advanced features like:
- `-Parallel` parameter for test blocks
- `ForEach-Object -Parallel` for PowerShell 7+
- Thread-safe execution contexts
- Automatic load balancing

## Recommended Approach: Use Dedicated Test Workflows

**Best Practice:** Run tests in dedicated workflows with matrix strategies instead of playbooks.

### Why?

1. **Native Concurrency**: GitHub Actions matrix strategies provide true parallelization across separate runners
2. **Resource Isolation**: Each matrix job gets its own VM, preventing resource contention
3. **Better Visibility**: Individual test job status is clearly visible in the GitHub UI
4. **Faster Execution**: Tests run simultaneously on different runners, not sequentially on one runner
5. **Pester Integration**: Direct `Invoke-Pester` calls with full Pester 5.x feature support

### Example: Current Test Workflow Pattern

```yaml
jobs:
  unit-tests:
    name: 🧪 Unit [${{ matrix.range }}]
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      max-parallel: 9
      matrix:
        range: ['0000-0099', '0100-0199', '0200-0299', '0300-0399', '0400-0499', '0500-0599', '0700-0799', '0800-0899', '0900-0999']
    
    steps:
      - name: 🧪 Run Unit Tests [${{ matrix.range }}]
        shell: pwsh
        run: |
          Import-Module ./AitherZero.psd1 -Force
          $testsPath = "library/tests/unit/automation-scripts/${{ matrix.range }}"
          Invoke-Pester -Path $testsPath -Output Detailed -CI
```

**Benefits:**
- 9 test jobs run simultaneously on 9 different runners
- Total execution time ≈ slowest single range (not sum of all ranges)
- Each job can use full runner resources (CPU, memory)

## When to Use Playbooks

Playbooks are best suited for:

### 1. **Sequential Orchestration Tasks**
Build processes where steps must run in order:

```powershell
@{
    Name = "pr-ecosystem-build"
    Sequence = @(
        @{ Script = "0407"; Description = "Syntax validation" }
        @{ Script = "0515"; Description = "Generate metadata" }
        @{ Script = "0902"; Description = "Create package" }
    )
    Options = @{
        Parallel = $false  # Sequential execution
    }
}
```

### 2. **Grouped Parallel Tasks**
Multiple independent tasks that can run concurrently on the same runner:

```powershell
@{
    Name = "metrics-collection"
    Sequence = @(
        @{ Script = "0520"; Parallel = $true }  # Ring metrics
        @{ Script = "0521"; Parallel = $true }  # Workflow metrics
        @{ Script = "0522"; Parallel = $true }  # Code metrics
        @{ Script = "0523"; Parallel = $true }  # Test metrics
        @{ Script = "0524"; Parallel = $true }  # Quality metrics
    )
    Options = @{
        Parallel = $true
        MaxConcurrency = 5
    }
}
```

**Note:** This runs 5 scripts in parallel on ONE runner using PowerShell background jobs.

### 3. **Complex Workflows with Dependencies**
Tasks with dependency chains:

```powershell
@{
    Sequence = @(
        @{ Script = "0100"; Phase = "setup" }
        @{ Script = "0200"; Phase = "build"; Parallel = $true; Dependencies = @("0100") }
        @{ Script = "0201"; Phase = "build"; Parallel = $true; Dependencies = @("0100") }
        @{ Script = "0300"; Phase = "test"; Dependencies = @("0200", "0201") }
    )
}
```

## Hybrid Approach: Combining Workflows and Playbooks

**Recommended Pattern:**

1. **Use GitHub Actions matrix** for test parallelization
2. **Use playbooks** for build/deploy orchestration
3. **Keep them separate** for clarity and efficiency

### Example: Complete PR Workflow

```yaml
jobs:
  # Tests: Use matrix for parallelization
  unit-tests:
    strategy:
      matrix:
        range: ['0000-0099', '0100-0199', ...]
    steps:
      - run: Invoke-Pester -Path tests/unit/${{ matrix.range }}

  domain-tests:
    strategy:
      matrix:
        module: ['configuration', 'infrastructure', ...]
    steps:
      - run: Invoke-Pester -Path tests/aithercore/${{ matrix.module }}

  # Build: Use playbook for orchestration
  build:
    steps:
      - run: Invoke-AitherPlaybook -Name pr-ecosystem-build
  
  # Dashboard: Use playbook for metrics collection
  dashboard:
    needs: [unit-tests, domain-tests, build]
    steps:
      - run: Invoke-AitherPlaybook -Name dashboard-generation-complete
```

## Implementing Parallel Execution in Playbooks

If you must use playbooks for parallel test execution, here's how:

### Option 1: Script-Level Parallelization

```powershell
# playbook: parallel-test-suite.psd1
@{
    Name = "parallel-test-suite"
    Description = "Run test suites in parallel on single runner"
    
    Sequence = @(
        @{
            Script = "run-unit-tests"
            Parameters = @{ Range = "0000-0099" }
            Parallel = $true
            Timeout = 300
        },
        @{
            Script = "run-unit-tests"
            Parameters = @{ Range = "0100-0199" }
            Parallel = $true
            Timeout = 300
        },
        @{
            Script = "run-unit-tests"
            Parameters = @{ Range = "0200-0299" }
            Parallel = $true
            Timeout = 300
        }
    )
    
    Options = @{
        Parallel = $true
        MaxConcurrency = 3  # Run 3 test scripts simultaneously
        StopOnError = $false
    }
}
```

### Option 2: Use PowerShell 7 Parallel Features in Scripts

Create a test runner script that uses `ForEach-Object -Parallel`:

```powershell
# 0402_Run-AllTests-Parallel.ps1
param(
    [int]$ThrottleLimit = 5
)

$testRanges = @('0000-0099', '0100-0199', '0200-0299', '0300-0399', '0400-0499')

$results = $testRanges | ForEach-Object -Parallel {
    $range = $_
    Import-Module ./AitherZero.psd1 -Force
    
    $testsPath = "library/tests/unit/automation-scripts/$range"
    
    if (Test-Path $testsPath) {
        $result = Invoke-Pester -Path $testsPath -PassThru -Output Minimal
        
        [PSCustomObject]@{
            Range = $range
            Passed = $result.PassedCount
            Failed = $result.FailedCount
            Duration = $result.Duration
        }
    }
} -ThrottleLimit $ThrottleLimit

$results | Format-Table -AutoSize
```

**Limitations:**
- Still runs on single runner (shared CPU/memory)
- PowerShell background jobs have overhead
- Not as efficient as separate GitHub Actions runners

## Performance Comparison

### GitHub Actions Matrix (Recommended)
```
9 ranges × 60s each = 60s total (all run simultaneously on 9 runners)
```

### Playbook Parallel (Single Runner)
```
9 ranges × 60s each / 5 concurrent = ~108s total (shared resources, overhead)
```

### Playbook Sequential
```
9 ranges × 60s each = 540s total (one after another)
```

## Cmdlets for Parallel Execution

### Future Enhancement: Parallel Orchestration Cmdlets

These cmdlets should be added to OrchestrationEngine.psm1:

```powershell
function Invoke-ParallelOrchestration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Tasks,
        
        [int]$ThrottleLimit = 5,
        
        [switch]$StopOnError
    )
    
    $Tasks | ForEach-Object -Parallel {
        $task = $_
        
        # Import module in each parallel thread
        Import-Module $using:ModulePath -Force
        
        # Execute task
        $scriptPath = Get-OrchestrationScript -Number $task.Script
        
        $params = @{}
        if ($task.Parameters) {
            $params = $task.Parameters
        }
        
        & $scriptPath @params
        
    } -ThrottleLimit $ThrottleLimit
}
```

### Usage Example

```powershell
$tasks = @(
    @{ Script = "0520"; Parameters = @{ OutputPath = "reports/ring.json" } }
    @{ Script = "0521"; Parameters = @{ OutputPath = "reports/workflow.json" } }
    @{ Script = "0522"; Parameters = @{ OutputPath = "reports/code.json" } }
)

Invoke-ParallelOrchestration -Tasks $tasks -ThrottleLimit 3
```

## Best Practices

1. **✅ DO**: Use GitHub Actions matrix for test parallelization
2. **✅ DO**: Use playbooks for build/deploy orchestration
3. **✅ DO**: Keep test counts per matrix job reasonable (50-100 tests)
4. **✅ DO**: Use playbooks for metrics collection (lightweight, fast scripts)
5. **❌ DON'T**: Run heavy tests in playbooks with parallel execution
6. **❌ DON'T**: Try to replace GitHub Actions matrix with playbook parallelization
7. **❌ DON'T**: Mix test execution with build/deploy in the same workflow

## Migration Path

### From: pr-complete.yml running all tests

```yaml
jobs:
  test-and-build:
    steps:
      - run: Invoke-AitherPlaybook -Name test-everything  # Slow!
      - run: Invoke-AitherPlaybook -Name build
```

### To: Dedicated test workflows + streamlined pr-complete

```yaml
# comprehensive-test-execution.yml (separate workflow)
jobs:
  unit-tests:
    strategy:
      matrix:
        range: [...]
    steps:
      - run: Invoke-Pester  # Fast parallel execution

# pr-complete.yml (streamlined)
jobs:
  build:
    steps:
      - run: Invoke-AitherPlaybook -Name pr-ecosystem-build  # No tests!
  
  dashboard:
    needs: build
    steps:
      - run: Invoke-AitherPlaybook -Name dashboard-generation-complete
```

## Summary

**Key Takeaway:** GitHub Actions matrix strategies are the right tool for parallel test execution. Playbooks excel at orchestrating sequential or lightly-parallel build/deploy tasks, but shouldn't replace dedicated test workflows.

For the pr-complete.yml workflow specifically:
- ✅ Removed test execution (handled by comprehensive-test-execution.yml)
- ✅ Kept build orchestration (pr-ecosystem-build playbook)
- ✅ Kept dashboard generation (dashboard-generation-complete playbook)
- ✅ Result: Faster, cleaner workflow with better separation of concerns
