# Orchestration Engine v3.0 - GitHub Actions-Inspired Improvements

## Overview

The AitherZero Orchestration Engine v3.0 introduces a powerful job-based orchestration model inspired by GitHub Actions design principles. This provides enhanced flexibility, better dependency management, improved observability, and familiar patterns for developers.

## Key Features

### 1. Job-Based Architecture

Instead of sequential stages, v3.0 introduces **jobs** - independent units of work that can run in parallel with explicit dependency management.

**Benefits:**
- Parallel execution by default (where dependencies allow)
- Clear dependency declarations via `needs`
- Better resource utilization
- Improved execution time for complex workflows

**Example:**
```json
{
  "orchestration": {
    "jobs": {
      "setup": {
        "name": "Setup Environment",
        "steps": [...]
      },
      "test": {
        "name": "Run Tests",
        "needs": ["setup"],
        "steps": [...]
      },
      "deploy": {
        "name": "Deploy",
        "needs": ["test"],
        "steps": [...]
      }
    }
  }
}
```

### 2. Step-Level Granularity

Jobs contain sequential **steps** that represent individual actions:

**Step Types:**
- `run`: Execute automation script by number (e.g., "0402")
- `script`: Execute inline PowerShell code
- `uses`: Invoke reusable actions or playbooks

**Example:**
```json
{
  "steps": [
    {
      "id": "runTests",
      "name": "Execute Unit Tests",
      "run": "0402",
      "with": {
        "NoCoverage": true
      }
    },
    {
      "id": "summary",
      "name": "Display Results",
      "script": "Write-Host 'Tests completed!'"
    }
  ]
}
```

### 3. Output Management

Jobs and steps can produce outputs that are consumed by dependent jobs:

**Job Outputs:**
```json
{
  "job_id": {
    "outputs": {
      "testCount": "${{ steps.runTests.outputs.totalCount }}",
      "result": "${{ steps.runTests.outputs.passed }}"
    }
  }
}
```

**Step Outputs:**
```json
{
  "steps": [
    {
      "id": "runTests",
      "outputs": [
        {
          "name": "totalCount",
          "value": "$result.TotalCount"
        }
      ]
    }
  ]
}
```

### 4. Conditional Execution

Jobs and steps support conditional execution:

**Special Conditions:**
- `always()` - Always run regardless of previous failures
- `success()` - Run only if all dependencies succeeded
- `failure()` - Run only if any dependency failed

**PowerShell Expressions:**
```json
{
  "job_id": {
    "if": "$env:ENVIRONMENT -eq 'production'",
    "steps": [
      {
        "if": "always()",
        "name": "Cleanup"
      }
    ]
  }
}
```

### 5. Environment Variable Management

Three levels of environment variables:

1. **Global** (orchestration.env) - Available to all jobs
2. **Job-level** (job.env) - Available to all steps in a job
3. **Step-level** (step.env) - Available only to that step

**Example:**
```json
{
  "orchestration": {
    "env": {
      "AITHERZERO_CI": "true"
    },
    "jobs": {
      "test": {
        "env": {
          "testPath": "./tests"
        },
        "steps": [
          {
            "env": {
              "NoCoverage": "true"
            }
          }
        ]
      }
    }
  }
}
```

### 6. Concurrency Control

Control parallel execution and prevent conflicts:

```json
{
  "orchestration": {
    "concurrency": {
      "group": "test-quick",
      "cancelInProgress": true,
      "maxConcurrency": 4
    }
  }
}
```

### 7. Defaults

Set default values for all jobs:

```json
{
  "orchestration": {
    "defaults": {
      "continueOnError": false,
      "timeout": 600,
      "retries": 0,
      "shell": "pwsh"
    }
  }
}
```

### 8. Job Permissions

Declare required permissions at the job level:

```json
{
  "job_id": {
    "permissions": {
      "filesystem": ["/path/to/data"],
      "network": ["https://api.example.com"],
      "registry": true
    }
  }
}
```

### 9. Matrix Strategy (Planned)

Execute jobs across multiple configurations in parallel:

```json
{
  "job_id": {
    "strategy": {
      "matrix": {
        "platform": ["Windows", "Linux", "macOS"],
        "version": ["7.0", "7.4"]
      },
      "failFast": true,
      "maxParallel": 3
    }
  }
}
```

## Comparison: v2.0 vs v3.0

| Feature | v2.0 (Stages) | v3.0 (Jobs) |
|---------|---------------|-------------|
| **Execution Model** | Sequential stages | Parallel jobs with dependencies |
| **Granularity** | Stage-level | Job + Step level |
| **Outputs** | Variables only | Typed outputs with expressions |
| **Dependencies** | Implicit (order) | Explicit (`needs`) |
| **Parallelization** | Limited | Full support |
| **Conditionals** | Stage-level | Job + Step level |
| **Environment** | Variables | Env vars at 3 levels |
| **Observability** | Basic logging | Rich summaries (planned) |

## Usage Examples

### Simple Sequential Workflow

```json
{
  "metadata": {
    "name": "simple-workflow",
    "version": "3.0.0"
  },
  "orchestration": {
    "jobs": {
      "build": {
        "name": "Build",
        "steps": [
          {
            "name": "Compile",
            "run": "0201"
          }
        ]
      },
      "test": {
        "name": "Test",
        "needs": ["build"],
        "steps": [
          {
            "name": "Run Tests",
            "run": "0402"
          }
        ]
      }
    }
  }
}
```

### Parallel Execution with Fan-In

```json
{
  "jobs": {
    "setup": {
      "name": "Setup",
      "steps": [...]
    },
    "unit_tests": {
      "name": "Unit Tests",
      "needs": ["setup"],
      "steps": [...]
    },
    "integration_tests": {
      "name": "Integration Tests",
      "needs": ["setup"],
      "steps": [...]
    },
    "report": {
      "name": "Aggregate Report",
      "needs": ["unit_tests", "integration_tests"],
      "steps": [...]
    }
  }
}
```

### Conditional Deployment

```json
{
  "jobs": {
    "test": {
      "name": "Test",
      "steps": [...]
    },
    "deploy_staging": {
      "name": "Deploy to Staging",
      "needs": ["test"],
      "if": "$env:BRANCH -eq 'develop'",
      "steps": [...]
    },
    "deploy_production": {
      "name": "Deploy to Production",
      "needs": ["test"],
      "if": "$env:BRANCH -eq 'main' -and $env:ENVIRONMENT -eq 'production'",
      "steps": [...]
    }
  }
}
```

## Migration from v2.0

### Before (v2.0):

```json
{
  "orchestration": {
    "stages": [
      {
        "name": "Setup",
        "sequences": ["0400"]
      },
      {
        "name": "Test",
        "sequences": ["0402"]
      }
    ]
  }
}
```

### After (v3.0):

```json
{
  "orchestration": {
    "jobs": {
      "setup": {
        "name": "Setup",
        "steps": [
          {
            "name": "Install Tools",
            "run": "0400"
          }
        ]
      },
      "test": {
        "name": "Test",
        "needs": ["setup"],
        "steps": [
          {
            "name": "Run Tests",
            "run": "0402"
          }
        ]
      }
    }
  }
}
```

## Backward Compatibility

The v3.0 engine maintains **full backward compatibility** with v2.0 and v1 playbooks:

- V2.0 playbooks with `stages` continue to work
- V1 playbooks with simple `Sequence` arrays continue to work
- The engine automatically detects the playbook version and routes to the appropriate execution engine

## Performance Considerations

**Parallel Execution:**
- Jobs run in parallel by default when dependencies allow
- Use `concurrency.maxConcurrency` to control resource usage
- Dependencies (`needs`) create execution order automatically

**Timeout Management:**
- Set at orchestration, job, or step level
- More granular control than v2.0
- Prevents hung executions

**Resource Control:**
- Job-level permissions prevent unauthorized access
- Concurrency groups prevent conflicts
- Cancel-in-progress saves resources

## Best Practices

1. **Keep Jobs Focused**: Each job should have a single responsibility
2. **Use Dependencies**: Explicitly declare job dependencies via `needs`
3. **Leverage Outputs**: Pass data between jobs using outputs, not side effects
4. **Fail Fast**: Use `strategy.failFast` for matrix jobs to save time
5. **Use Conditions**: Skip unnecessary work with job/step conditions
6. **Set Timeouts**: Prevent hung jobs with appropriate timeout values
7. **Continue on Error**: Use `continueOnError` judiciously for cleanup jobs
8. **Environment Variables**: Use the appropriate level (global/job/step)

## Troubleshooting

### Job Not Running

Check:
1. Are dependencies (`needs`) satisfied?
2. Is the condition (`if`) evaluating to true?
3. Did a dependency fail without `continueOnError`?

### Output Not Available

Check:
1. Is the step `id` correct?
2. Did the step complete successfully?
3. Is the output expression syntax correct?

### Slow Execution

Check:
1. Are jobs running in parallel?
2. Is `maxConcurrency` set too low?
3. Are there unnecessary dependencies blocking parallelization?

## Future Enhancements

- **Matrix Execution**: Automatic job expansion across configurations
- **Job Summaries**: Markdown-formatted reports
- **Artifact Management**: Explicit artifact upload/download between jobs
- **Caching**: Job-level caching for faster reruns
- **Secrets Management**: Secure credential handling
- **Status Annotations**: Rich progress indicators
- **Timeline Visualization**: Graphical execution timeline

## Related Documentation

- [Playbook Schema v3.0](../schema/playbook-schema-v3.json)
- [Example Playbooks](../playbooks/examples/)
- [Migration Guide](./MIGRATION-V2-TO-V3.md) (Coming Soon)
- [API Reference](./API-REFERENCE.md) (Coming Soon)

## Contributing

To contribute to the orchestration engine:

1. Follow existing patterns for jobs and steps
2. Add tests for new functionality
3. Update documentation
4. Ensure backward compatibility
5. Run PSScriptAnalyzer before submitting

---

**Version**: 3.0.0  
**Last Updated**: 2025-01-02  
**Author**: AitherZero Infrastructure Team
