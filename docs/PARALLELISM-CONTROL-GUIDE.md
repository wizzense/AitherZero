# Parallelism Control Guide

## Overview

AitherZero supports multi-level parallelism control to prevent deadlocks and optimize execution. This guide explains how to control parallelism at different levels.

## Three Levels of Control

### 1. Playbook-Level Control

Control parallel execution for an entire playbook using the `Options` section:

```powershell
# playbook.psd1
@{
    Name = "my-playbook"
    
    Sequence = @(
        @{ Script = "0001" },
        @{ Script = "0002" }
    )
    
    Options = @{
        Parallel = $false         # Run scripts sequentially
        MaxConcurrency = 1        # Only 1 script at a time
        StopOnError = $false      # Continue even if scripts fail
    }
}
```

**Use Cases:**
- Test playbooks (prevent module loading conflicts)
- Database migration playbooks (ensure sequential execution)
- Deployment playbooks (control resource contention)

### 2. Script-Level Metadata Control

Mark individual scripts as non-parallel using metadata comments:

```powershell
<#
.SYNOPSIS
    My critical script
.NOTES
    Stage: Testing
    Order: 0402
    Dependencies: 0400
    Tags: testing
    AllowParallel: false
#>
```

**Use Cases:**
- Scripts that load PowerShell modules (module loading is not thread-safe)
- Scripts that access shared resources (files, databases)
- Scripts with heavy I/O or CPU requirements
- Test runners (Pester with parallel tests internally)

### 3. Config Manifest Control

Define default parallelism settings in `config.psd1`:

```powershell
@{
    Automation = @{
        DefaultMode = "Sequential"  # or "Parallel"
        MaxConcurrency = 4
        
        # Per-range defaults
        ScriptDefaults = @{
            "0400-0499" = @{
                AllowParallel = $false
                Timeout = 600
            }
        }
    }
}
```

**Use Cases:**
- Organization-wide policies
- Environment-specific settings (CI vs local)
- Range-based defaults (all testing scripts sequential)

## Priority Order

When determining parallelism, the system checks in this order:

1. **Script Metadata** (`AllowParallel: false` in script header)
2. **Config Manifest** (`ScriptDefaults` in config.psd1)
3. **Playbook Options** (`Options.Parallel` in playbook)
4. **Command-line Parameter** (`-Parallel $false`)
5. **Default** (Parallel=true)

## Implementation Details

### Environment Variables

The orchestration engine sets environment variables to communicate context:

- `AITHERZERO_ORCHESTRATED_PARALLEL="true"` - Set when running in parallel orchestration
- `AITHERZERO_NONINTERACTIVE="true"` - Set for all orchestrated scripts
- `AITHERZERO_TEST_MODE="true"` - Set during test execution

Scripts can check these to modify behavior:

```powershell
if ($env:AITHERZERO_ORCHESTRATED_PARALLEL) {
    # Disable internal parallelism to avoid nesting
    $useParallel = $false
}
```

### Parallel Orchestration Behavior

When `AllowParallel = $false`:
- Scripts are extracted from the parallel queue
- Executed sequentially FIRST, before parallel scripts
- Run in priority order (by script number)
- Not subject to MaxConcurrency limits

When `AllowParallel = $true` (default):
- Scripts run in parallel ThreadJobs
- Subject to MaxConcurrency limits
- Dependency resolution applied
- Can be timeout-controlled

## Common Scenarios

### Scenario 1: Test Playbooks

**Problem:** Test scripts hang when run in parallel due to module loading conflicts.

**Solution:**
```powershell
# In playbook
Options = @{
    Parallel = $false
    MaxConcurrency = 1
}

# In test scripts (0402, 0403)
# AllowParallel: false
```

### Scenario 2: Mixed Workload

**Problem:** Some scripts can run in parallel, others cannot.

**Solution:**
```powershell
# Fast, parallel-safe scripts
<#
.NOTES
    AllowParallel: true  # (or omit, true is default)
#>

# Resource-intensive or conflict-prone scripts
<#
.NOTES
    AllowParallel: false
#>
```

The orchestration engine will:
1. Run `AllowParallel=false` scripts first (sequentially)
2. Then run `AllowParallel=true` scripts in parallel

### Scenario 3: CI/CD Optimization

**Problem:** Need fast execution in CI, but safe execution locally.

**Solution:**
```powershell
# config.ci.psd1
@{
    Automation = @{
        DefaultMode = "Sequential"  # Safe for CI
        MaxConcurrency = 1
    }
}

# config.local.psd1  
@{
    Automation = @{
        DefaultMode = "Parallel"    # Fast for local dev
        MaxConcurrency = 4
    }
}
```

Then in workflow:
```powershell
Invoke-AitherPlaybook -Name test-suite -Variables @{ ConfigFile = "./config.ci.psd1" }
```

## Debugging Parallelism Issues

### Enable Logging

```powershell
$env:AITHERZERO_LOG_LEVEL = 'Information'
Invoke-AitherPlaybook -Name myplaybook -Variables @{ Verbose = $true }
```

### Check Orchestration Mode

Look for these log messages:
```
[Orchestration] Starting parallel orchestration with max concurrency: 4
[Orchestration] Starting sequential orchestration
[Orchestration] Detected N script(s) that must run sequentially: ...
```

### Verify Script Metadata

```powershell
Get-OrchestrationScripts -Numbers @('0402') | Select-Object Number, Name, AllowParallel
```

## Best Practices

1. **Default to Parallel**: Only mark scripts as `AllowParallel: false` when necessary
2. **Use Playbook Options**: Control playbook-level behavior via Options, not individual script settings
3. **Document Reasons**: Comment why a script needs sequential execution
4. **Test Both Modes**: Verify scripts work in both parallel and sequential contexts
5. **Monitor Performance**: Sequential execution is slower - only use when required

## Migration Guide

### Updating Existing Playbooks

**Before:**
```powershell
@{
    Sequence = @("0402", "0403")
    # Parallel not controlled
}
```

**After:**
```powershell
@{
    Sequence = @(
        @{ Script = "0402"; Parallel = $false },
        @{ Script = "0403"; Parallel = $false }
    )
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
    }
}
```

### Updating Scripts

Add to script header:
```powershell
<#
.NOTES
    # ... existing metadata ...
    AllowParallel: false
#>
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Script hangs | Nested parallelism | Add `AllowParallel: false` |
| Module loading errors | Parallel module import | Set playbook `Parallel = $false` |
| Timeout in CI | Sequential too slow | Optimize tests, increase timeout |
| Resource contention | Multiple scripts accessing same resource | Mark scripts as `AllowParallel: false` |

## See Also

- [Orchestration Engine Documentation](./ORCHESTRATION-ENGINE.md)
- [Playbook Format Specification](./PLAYBOOK-FORMAT.md)
- [Script Metadata Guide](./SCRIPT-METADATA.md)
- [CI/CD Integration Guide](./CICD-INTEGRATION.md)
