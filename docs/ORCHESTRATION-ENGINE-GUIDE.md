# Orchestration Engine Guide

## Overview

The OrchestrationEngine is AitherZero's powerful workflow automation system that executes scripts using number-based sequences. It supports both sequential and parallel execution with dependency management, timeout handling, and comprehensive error recovery.

## Features

### Core Capabilities
- **Number-based sequences**: Execute scripts by number (0000-9999)
- **Playbook system**: Reusable workflows with .psd1 or .json formats
- **Parallel execution**: Run scripts concurrently with dependency resolution
- **Timeout handling**: Automatic cleanup of hung operations
- **Matrix builds**: Execute scripts with multiple configurations (experimental)
- **Caching system**: Speed up repeated executions (experimental)
- **Notifications**: Integration with external systems (planned for v2.1)

### Async Operation Support
- Thread-based parallelism with `Start-ThreadJob`
- Configurable concurrency limits
- Timeout detection and cleanup
- Graceful error handling
- Progress tracking

## Quick Start

### Execute a Single Script
```powershell
Invoke-OrchestrationSequence -Sequence "0407"
```

### Execute a Range
```powershell
Invoke-OrchestrationSequence -Sequence "0400-0499"
```

### Execute from Playbook
```powershell
Invoke-OrchestrationSequence -LoadPlaybook "test-orchestration"
```

### Dry Run (Preview)
```powershell
Invoke-OrchestrationSequence -LoadPlaybook "project-health-check" -DryRun
```

## Playbook Format

### Simple Playbook (String Sequences)
```powershell
@{
    Name = 'my-playbook'
    Description = 'Simple script sequence'
    Sequence = @('0407', '0413', '0402')  # Just numbers
    Variables = @{ CI = $true }
}
```

### Advanced Playbook (Script Definitions)
```powershell
@{
    Name = 'advanced-playbook'
    Description = 'Detailed script configuration'
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            Description = 'Syntax validation'
            Parameters = @{ All = $true }
            Timeout = 120  # Seconds
            ContinueOnError = $false
        },
        @{
            Script = '0404_Run-PSScriptAnalyzer.ps1'
            Description = 'Code quality'
            Parameters = @{}
            Timeout = 300
            ContinueOnError = $true
        }
    )
    Variables = @{
        CI = $true
        Environment = 'Test'
    }
    Options = @{
        Parallel = $false
        MaxConcurrency = 4
        StopOnError = $false
    }
}
```

## Sequence Syntax

### Supported Formats
```powershell
# Single script
"0407"

# Range
"0400-0499"

# List
"0407,0413,0402"

# Wildcard (all in range)
"04*"  # All 0400-0499

# Exclusion
"0400-0499,!0450"  # All except 0450

# Stage-based
"stage:Testing"

# Tag-based  
"tag:validation"
```

## Execution Modes

### Sequential Execution
```powershell
Invoke-OrchestrationSequence -Sequence "0407,0413,0402" -Parallel $false
```

**Characteristics:**
- Scripts run one at a time in order
- Deterministic execution
- Easier debugging
- Lower resource usage

### Parallel Execution
```powershell
Invoke-OrchestrationSequence -Sequence "0407,0413,0402" -Parallel $true -MaxConcurrency 4
```

**Characteristics:**
- Scripts run concurrently
- Respects dependencies
- Faster completion
- Requires careful script design

## Timeout Handling

### Configure Timeouts in Playbook
```powershell
@{
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            Timeout = 120  # 2 minutes
        }
    )
}
```

**Behavior:**
- Job is automatically stopped after timeout
- Exit code 124 (standard timeout code)
- Cleanup performed automatically
- Respects `ContinueOnError` flag

### Default Timeout
No timeout by default. Set explicitly for long-running operations.

## Error Handling

### Continue on Error
```powershell
Invoke-OrchestrationSequence -Sequence "0407,0413,0402" -ContinueOnError
```

### Stop on First Error
```powershell
Invoke-OrchestrationSequence -Sequence "0407,0413,0402"
# Default: stops on first error
```

### Per-Script Error Handling
```powershell
@{
    Sequence = @(
        @{
            Script = '0407_Validate-Syntax.ps1'
            ContinueOnError = $false  # Must succeed
        },
        @{
            Script = '0404_Run-PSScriptAnalyzer.ps1'
            ContinueOnError = $true  # Optional - continue if fails
        }
    )
}
```

## Testing Orchestration

### Before Committing Changes

1. **Syntax Validation**
```powershell
# Validate OrchestrationEngine.psm1
./automation-scripts/0407_Validate-Syntax.ps1 -FilePath aithercore/automation/OrchestrationEngine.psm1
```

2. **Dry Run Test**
```powershell
# Test playbook loading and sequence extraction
Invoke-OrchestrationSequence -LoadPlaybook 'test-orchestration' -DryRun
```

3. **Simple Execution**
```powershell
# Run test playbook
Invoke-OrchestrationSequence -LoadPlaybook 'test-orchestration'
```

4. **Verify Exports**
```powershell
# Check all functions are exported
Get-Command -Module AitherZero | Where-Object { $_.Name -like '*Orchestration*' }
```

### Test Playbooks

#### test-orchestration.psd1
Simple single-script validation:
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'test-orchestration'
```

#### pr-validation-fast.psd1
Quick PR validation (2 scripts):
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'pr-validation-fast' -DryRun
```

#### project-health-check.psd1
Comprehensive validation (8 scripts):
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'project-health-check' -DryRun
```

## Best Practices

### 1. Always Test with Dry Run First
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'my-playbook' -DryRun
```

### 2. Set Appropriate Timeouts
```powershell
# Fast operations: 60-120 seconds
# Build operations: 300-600 seconds
# Test suites: 600-1200 seconds
```

### 3. Use ContinueOnError Wisely
```powershell
# Critical validation: ContinueOnError = $false
# Optional steps: ContinueOnError = $true
```

### 4. Validate Before Commit
```powershell
# Run syntax check
./automation-scripts/0407_Validate-Syntax.ps1 -All

# Test orchestration
Invoke-OrchestrationSequence -LoadPlaybook 'test-orchestration'
```

### 5. Monitor Parallel Execution
```powershell
# Start with MaxConcurrency = 2
# Increase gradually based on results
```

## Troubleshooting

### Playbook Not Found
```powershell
# Check playbook exists
ls aithercore/orchestration/playbooks/*.psd1

# Verify playbook name (without extension)
Invoke-OrchestrationSequence -LoadPlaybook 'my-playbook'  # Not 'my-playbook.psd1'
```

### No Scripts Match Sequence
```powershell
# Playbook with script definitions requires extraction
# This is now handled automatically (commit ade1ae0)

# Verify scripts exist
ls automation-scripts/0407*.ps1
```

### Timeout Issues
```powershell
# Increase timeout in playbook
Timeout = 600  # 10 minutes

# Or run sequentially for better visibility
-Parallel $false
```

### Function Not Exported
```powershell
# Reload module
Import-Module ./AitherZero.psd1 -Force

# Verify export
Get-Command Invoke-ParallelOrchestration
```

## Advanced Features

### Matrix Builds
```powershell
Invoke-OrchestrationSequence -Sequence "0402" -Matrix @{
    profile = @('quick', 'comprehensive')
    platform = @('Windows', 'Linux')
}
```

### Caching
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'test-full' -UseCache
```

### Summary Generation
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'test-full' -GenerateSummary
```

## Integration with CI/CD

### GitHub Actions
```yaml
- name: Run Orchestration
  shell: pwsh
  run: |
    Import-Module ./AitherZero.psd1
    Invoke-OrchestrationSequence -LoadPlaybook 'ci-validation'
```

### Local Development
```powershell
# Use global wrapper (after bootstrap)
aitherzero orchestrate test-orchestration
```

## Performance Tips

1. **Use Parallel for Independent Scripts**
   - 2-4x faster for independent operations
   - Set MaxConcurrency = CPU cores

2. **Sequential for Dependent Scripts**
   - Better error visibility
   - Easier debugging

3. **Enable Caching**
   - Reuse results for unchanged scripts
   - Reduces validation time

4. **Set Realistic Timeouts**
   - Prevents hung operations
   - Enables faster failure detection

## See Also

- [Playbook Examples](../aithercore/orchestration/playbooks/README.md)
- [Script Metadata](./SCRIPT-METADATA.md)
- [Testing Guide](./TESTING-README.md)
- [Project Health Validation](./PROJECT-HEALTH-VALIDATION.md)

## Experimental Features

The following features are available but considered experimental. Use with caution in production environments.

### Matrix Builds
Execute scripts with multiple parameter combinations:
```powershell
Invoke-OrchestrationSequence -Sequence "0402" -Matrix @{
    profile = @('quick', 'comprehensive')
    platform = @('Windows', 'Linux')
}
```

**Status**: Functional but limited testing. May have edge cases.

### Caching
Cache execution results for faster repeated runs:
```powershell
Invoke-OrchestrationSequence -LoadPlaybook 'test-full' -UseCache
```

**Status**: Basic caching implemented. Advanced cache invalidation pending.

### Notifications
Send notifications to external systems:
```powershell
# Planned for v2.1
```

**Status**: Planned. Not yet implemented. Framework in place for future development.

---

**Last Updated**: 2025-11-07
**Version**: 2.0.0
