# Orchestration Playbook Examples

This directory contains example playbooks demonstrating various orchestration patterns and features.

## Available Examples

### V3.0 (Job-Based)

#### test-quick-v3.json
**Purpose**: Fast validation using GitHub Actions-style jobs and steps

**Features Demonstrated:**
- Job-based orchestration
- Job dependencies (`needs`)
- Step-level granularity
- Job and step outputs
- Conditional execution (`if`)
- Environment variable management (3 levels)
- Concurrency control
- Parallel job execution
- Always-run cleanup steps

**Jobs:**
1. **setup** - Verify testing tools are installed
   - Outputs: `pesterVersion`, `psaVersion`
   
2. **unit_tests** - Run all unit tests (depends on setup)
   - Outputs: `testCount`, `passedCount`, `failedCount`
   - Parallel with: `static_analysis`, `syntax_validation`
   
3. **static_analysis** - Run PSScriptAnalyzer (depends on setup)
   - Continue on error
   - Parallel with: `unit_tests`, `syntax_validation`
   
4. **syntax_validation** - Validate PowerShell syntax (depends on setup)
   - Continue on error
   - Parallel with: `unit_tests`, `static_analysis`
   
5. **summary** - Aggregate results (depends on all previous jobs)
   - Always runs (even if tests fail)
   - Consumes outputs from other jobs

**Usage:**
```powershell
# Run the playbook
Invoke-OrchestrationSequence -LoadPlaybook "test-quick-v3"

# Dry run to see execution plan
Invoke-OrchestrationSequence -LoadPlaybook "test-quick-v3" -DryRun
```

**Execution Flow:**
```
setup
  ├─> unit_tests ─┐
  ├─> static_analysis ─┤
  └─> syntax_validation ─┘
              └─> summary (always runs)
```

## Pattern Categories

### Sequential Workflows
Examples showing step-by-step execution with explicit dependencies.

**Use Cases:**
- Build → Test → Deploy pipelines
- Data processing pipelines
- Configuration management

### Parallel Workflows
Examples showing concurrent execution for faster completion.

**Use Cases:**
- Multiple test suites running simultaneously
- Multi-platform builds
- Independent validation steps

### Fan-In/Fan-Out Patterns
Examples showing jobs that split work and reconverge.

**Use Cases:**
- Matrix testing with aggregated reporting
- Multi-environment deployments with validation
- Distributed data processing

### Conditional Workflows
Examples showing environment-based or result-based branching.

**Use Cases:**
- Environment-specific deployments
- Optional steps based on changed files
- Failure recovery and rollback

### Output Propagation
Examples showing data passing between jobs.

**Use Cases:**
- Build metadata propagation
- Test result aggregation
- Version number generation and use

## Creating Your Own Playbooks

### V3.0 Job-Based Structure

```json
{
  "metadata": {
    "name": "my-playbook",
    "description": "Description of what this playbook does",
    "version": "3.0.0",
    "category": "testing|infrastructure|deployment|etc",
    "author": "Your Name",
    "tags": ["tag1", "tag2"],
    "estimatedDuration": "5-10 minutes"
  },
  "requirements": {
    "minimumPowerShellVersion": "7.0",
    "requiredModules": ["Pester"],
    "platforms": ["CrossPlatform"]
  },
  "orchestration": {
    "env": {
      "GLOBAL_VAR": "value"
    },
    "concurrency": {
      "group": "my-group",
      "cancelInProgress": true,
      "maxConcurrency": 4
    },
    "defaults": {
      "timeout": 600,
      "retries": 0
    },
    "jobs": {
      "job1": {
        "name": "First Job",
        "steps": [
          {
            "name": "Step Name",
            "run": "0400"
          }
        ]
      },
      "job2": {
        "name": "Second Job",
        "needs": ["job1"],
        "steps": [...]
      }
    }
  }
}
```

### Best Practices

1. **Clear Naming**: Use descriptive job and step names
2. **Explicit Dependencies**: Always use `needs` to declare dependencies
3. **Output Management**: Define outputs for data that other jobs need
4. **Error Handling**: Use `continueOnError` appropriately
5. **Timeouts**: Set reasonable timeouts to prevent hung jobs
6. **Conditions**: Use `if` to skip unnecessary work
7. **Environment Variables**: Use the appropriate level (global/job/step)

### Validation

Validate your playbook against the schema:

```powershell
# Using Test-Json (PowerShell 6.1+)
$schema = Get-Content "./orchestration/schema/playbook-schema-v3.json" -Raw
$playbook = Get-Content "./my-playbook.json" -Raw
Test-Json -Json $playbook -Schema $schema
```

### Testing

Test your playbook before using in production:

```powershell
# Dry run to see execution plan
Invoke-OrchestrationSequence -LoadPlaybook "my-playbook" -DryRun

# Test with minimal scope
Invoke-OrchestrationSequence -LoadPlaybook "my-playbook" -Variables @{ 
    Environment = "Development"
}
```

## Comparison with V2.0

### V2.0 Stage-Based
```json
{
  "orchestration": {
    "stages": [
      {
        "name": "Stage 1",
        "sequences": ["0400", "0401"]
      },
      {
        "name": "Stage 2",
        "sequences": ["0402"]
      }
    ]
  }
}
```

### V3.0 Job-Based
```json
{
  "orchestration": {
    "jobs": {
      "stage1": {
        "name": "Stage 1",
        "steps": [
          { "name": "Step 1", "run": "0400" },
          { "name": "Step 2", "run": "0401" }
        ]
      },
      "stage2": {
        "name": "Stage 2",
        "needs": ["stage1"],
        "steps": [
          { "name": "Step 1", "run": "0402" }
        ]
      }
    }
  }
}
```

**Advantages of V3.0:**
- Explicit dependencies
- Parallel execution where possible
- Step-level control
- Output management
- Better observability

## Additional Resources

- [Orchestration V3.0 Documentation](../../docs/ORCHESTRATION-V3.md)
- [Playbook Schema V3.0](../schema/playbook-schema-v3.json)
- [Orchestration Engine](../../domains/automation/OrchestrationEngine.psm1)

## Contributing

To add new examples:

1. Follow the V3.0 schema
2. Add clear documentation in comments
3. Test thoroughly
4. Update this README
5. Submit a PR

---

For questions or issues, please open a GitHub issue or refer to the main documentation.
