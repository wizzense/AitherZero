# Playbook Examples Cookbook

This cookbook provides practical, ready-to-use playbook examples for common scenarios in AitherZero.

## Table of Contents

- [Quick Start Examples](#quick-start-examples)
- [Testing Playbooks](#testing-playbooks)
- [CI/CD Playbooks](#cicd-playbooks)
- [Deployment Playbooks](#deployment-playbooks)
- [Maintenance Playbooks](#maintenance-playbooks)
- [Advanced Patterns](#advanced-patterns)

---

## Quick Start Examples

### Example 1: Simple Syntax Validation

**Use Case**: Quick syntax check before committing code

**Playbook**: `quick-syntax-check.psd1`

```powershell
@{
    Name = 'quick-syntax-check'
    Description = 'Fast syntax validation for pre-commit'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0407'
            Description = 'Validate PowerShell syntax'
            Parameters = @{ All = $true }
            Timeout = 60
            ContinueOnError = $false
        }
    )
    
    Variables = @{}
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
}
```

**Usage**:
```powershell
# Create from template
New-PlaybookTemplate -Name 'quick-syntax-check' -Scripts @('0407') -Type Simple

# Run
Invoke-OrchestrationSequence -LoadPlaybook 'quick-syntax-check'
```

---

### Example 2: Config Validation

**Use Case**: Validate configuration manifests

**Playbook**: `validate-config.psd1`

```powershell
@{
    Name = 'validate-config'
    Description = 'Validate configuration manifests'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0413'
            Description = 'Validate config manifest structure'
            Parameters = @{}
            Timeout = 30
            ContinueOnError = $false
        }
    )
    
    Variables = @{
        StrictValidation = $true
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
}
```

---

## Testing Playbooks

### Example 3: Unit Tests Only

**Use Case**: Run unit tests quickly during development

**Playbook**: `unit-tests.psd1`

```powershell
@{
    Name = 'unit-tests'
    Description = 'Run unit tests for rapid feedback'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0402'
            Description = 'Execute unit test suite'
            Parameters = @{
                Path = './tests/unit'
                Output = 'Detailed'
            }
            Timeout = 300
            ContinueOnError = $false
        }
    )
    
    Variables = @{
        TestMode = $true
        FailFast = $true
        CoverageEnabled = $false
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
}
```

**Create with**:
```powershell
New-PlaybookTemplate -Name 'unit-tests' -Scripts @('0402') -Type Testing
```

---

### Example 4: Comprehensive Testing

**Use Case**: Full test suite with coverage

**Playbook**: `comprehensive-tests.psd1`

```powershell
@{
    Name = 'comprehensive-tests'
    Description = 'Complete test suite with code coverage'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0402'
            Description = 'Run unit tests'
            Parameters = @{ Path = './tests/unit' }
            Timeout = 300
        },
        @{
            Script = '0403'
            Description = 'Run integration tests'
            Parameters = @{ Path = './tests/integration' }
            Timeout = 600
        },
        @{
            Script = '0404'
            Description = 'Code quality analysis'
            Parameters = @{ Fast = $false }
            Timeout = 180
        }
    )
    
    Variables = @{
        TestMode = $true
        CoverageThreshold = 80
        GenerateReports = $true
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $false  # Run all tests even if some fail
        CaptureOutput = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $false
        MinimumSuccessCount = 2  # At least 2 of 3 must pass
    }
}
```

---

## CI/CD Playbooks

### Example 5: PR Validation (Fast)

**Use Case**: Quick validation for pull requests (< 2 minutes)

**Playbook**: `pr-validation-fast.psd1`

```powershell
@{
    Name = 'pr-validation-fast'
    Description = 'Fast PR validation - essential checks only'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0407'
            Description = 'Quick syntax validation'
            Parameters = @{ All = $true }
            Timeout = 60
        },
        @{
            Script = '0413'
            Description = 'Config validation'
            Parameters = @{}
            Timeout = 30
        }
    )
    
    Variables = @{
        CI = 'true'
        AITHERZERO_CI = 'true'
        AITHERZERO_NONINTERACTIVE = 'true'
        FailFast = $true
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
        GenerateSummary = $true
    }
}
```

**Create with**:
```powershell
New-PlaybookTemplate -Name 'pr-validation-fast' -Scripts @('0407', '0413') -Type CI
```

---

### Example 6: Full CI Validation

**Use Case**: Complete CI validation suite

**Playbook**: `ci-full-validation.psd1`

```powershell
@{
    Name = 'ci-full-validation'
    Description = 'Complete CI validation suite'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0407'
            Description = 'Syntax validation'
            Parameters = @{ All = $true }
            Timeout = 120
        },
        @{
            Script = '0404'
            Description = 'PSScriptAnalyzer'
            Parameters = @{ Fast = $true; UseCache = $true }
            Timeout = 180
        },
        @{
            Script = '0413'
            Description = 'Config validation'
            Parameters = @{}
            Timeout = 30
        },
        @{
            Script = '0402'
            Description = 'Unit tests'
            Parameters = @{}
            Timeout = 300
        }
    )
    
    Variables = @{
        CI = 'true'
        AITHERZERO_CI = 'true'
        AITHERZERO_NONINTERACTIVE = 'true'
        GenerateReports = $true
    }
    
    Options = @{
        Parallel = $false
        MaxConcurrency = 1
        StopOnError = $true
        CaptureOutput = $true
    }
    
    Reporting = @{
        GenerateReport = $true
        IncludeTimings = $true
    }
}
```

---

## Deployment Playbooks

### Example 7: Staging Deployment

**Use Case**: Deploy to staging environment

**Playbook**: `deploy-staging.psd1`

```powershell
@{
    Name = 'deploy-staging'
    Description = 'Deploy to staging environment with validation'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0100'
            Description = 'Prepare staging infrastructure'
            Parameters = @{ 
                Environment = 'Staging'
                DryRun = $false
            }
            Timeout = 600
        },
        @{
            Script = '0101'
            Description = 'Deploy application'
            Parameters = @{ 
                Target = 'Staging'
                Validate = $true
            }
            Timeout = 900
        },
        @{
            Script = '0105'
            Description = 'Verify deployment'
            Parameters = @{}
            Timeout = 300
        }
    )
    
    Variables = @{
        Environment = 'Staging'
        DryRun = $false
        BackupBeforeDeploy = $true
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
}
```

**Create with**:
```powershell
New-PlaybookTemplate -Name 'deploy-staging' -Scripts @('0100', '0101', '0105') -Type Deployment
```

---

### Example 8: Production Deployment (with Approval)

**Use Case**: Production deployment with manual approval step

**Playbook**: `deploy-production.psd1`

```powershell
@{
    Name = 'deploy-production'
    Description = 'Production deployment with validation and approval'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0100'
            Description = 'Pre-deployment validation'
            Parameters = @{ 
                Environment = 'Production'
                ValidateOnly = $true
            }
            Timeout = 300
        },
        @{
            Script = '0101'
            Description = 'Deploy to production'
            Parameters = @{ 
                Target = 'Production'
                CreateBackup = $true
            }
            Timeout = 1800
            ContinueOnError = $false
        },
        @{
            Script = '0105'
            Description = 'Post-deployment verification'
            Parameters = @{ Comprehensive = $true }
            Timeout = 600
        }
    )
    
    Variables = @{
        Environment = 'Production'
        DryRun = $false
        RequireApproval = $true
        BackupRetentionDays = 30
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
}
```

---

## Maintenance Playbooks

### Example 9: Cleanup & Maintenance

**Use Case**: Regular cleanup and maintenance tasks

**Playbook**: `maintenance-cleanup.psd1`

```powershell
@{
    Name = 'maintenance-cleanup'
    Description = 'Regular cleanup and maintenance'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '9001'
            Description = 'Clean temporary files'
            Parameters = @{ Age = 7 }
            Timeout = 120
        },
        @{
            Script = '9002'
            Description = 'Archive old logs'
            Parameters = @{ Age = 30 }
            Timeout = 180
        },
        @{
            Script = '9010'
            Description = 'Optimize databases'
            Parameters = @{}
            Timeout = 600
        }
    )
    
    Variables = @{
        MaintenanceMode = $true
        NotifyOnCompletion = $true
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $false
        ContinueOnError = $true
    }
}
```

---

## Advanced Patterns

### Example 10: Parallel Execution

**Use Case**: Run independent tasks in parallel

**Playbook**: `parallel-validation.psd1`

```powershell
@{
    Name = 'parallel-validation'
    Description = 'Run validation checks in parallel for speed'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0407'
            Description = 'Syntax validation'
            Parameters = @{ All = $true }
            Timeout = 120
            AllowParallel = $true
        },
        @{
            Script = '0404'
            Description = 'PSScriptAnalyzer'
            Parameters = @{ Fast = $true }
            Timeout = 180
            AllowParallel = $true
        },
        @{
            Script = '0413'
            Description = 'Config validation'
            Parameters = @{}
            Timeout = 60
            AllowParallel = $true
        }
    )
    
    Variables = @{}
    
    Options = @{
        Parallel = $true
        MaxConcurrency = 3
        StopOnError = $false
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $true
    }
}
```

---

### Example 11: Conditional Execution

**Use Case**: Execute different scripts based on conditions

**Playbook**: `conditional-deployment.psd1`

```powershell
@{
    Name = 'conditional-deployment'
    Description = 'Conditional deployment based on environment'
    Version = '1.0.0'
    
    Sequence = @(
        @{
            Script = '0100'
            Description = 'Prepare infrastructure'
            Parameters = @{ 
                Environment = '$env:DEPLOY_ENVIRONMENT'
            }
            Timeout = 600
        },
        @{
            Script = '0101'
            Description = 'Deploy application'
            Parameters = @{ 
                Target = '$env:DEPLOY_ENVIRONMENT'
                SkipTests = '$env:SKIP_TESTS'
            }
            Timeout = 900
        }
    )
    
    Variables = @{
        Environment = '$env:DEPLOY_ENVIRONMENT'
        DeploymentType = '$env:DEPLOYMENT_TYPE'
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
}
```

---

### Example 12: Multi-Stage Pipeline

**Use Case**: Multi-stage pipeline with dependencies

**Playbook**: `multi-stage-pipeline.psd1`

```powershell
@{
    Name = 'multi-stage-pipeline'
    Description = 'Multi-stage build and deploy pipeline'
    Version = '1.0.0'
    
    Sequence = @(
        # Stage 1: Build
        @{
            Script = '0200'
            Description = 'Build stage - compile and package'
            Parameters = @{ Configuration = 'Release' }
            Timeout = 600
        },
        
        # Stage 2: Test
        @{
            Script = '0402'
            Description = 'Test stage - unit tests'
            Parameters = @{}
            Timeout = 300
        },
        @{
            Script = '0403'
            Description = 'Test stage - integration tests'
            Parameters = @{}
            Timeout = 600
        },
        
        # Stage 3: Quality
        @{
            Script = '0404'
            Description = 'Quality stage - code analysis'
            Parameters = @{}
            Timeout = 180
        },
        
        # Stage 4: Deploy
        @{
            Script = '0100'
            Description = 'Deploy stage - staging'
            Parameters = @{ Environment = 'Staging' }
            Timeout = 900
        }
    )
    
    Variables = @{
        PipelineStage = 'Complete'
        ArtifactRetentionDays = 30
    }
    
    Options = @{
        Parallel = $false
        StopOnError = $true
    }
    
    SuccessCriteria = @{
        RequireAllSuccess = $true
        MinimumSuccessCount = 5
    }
}
```

---

## Tips & Best Practices

### 1. Template-Based Creation

**Always start with a template:**
```powershell
# Simple playbook
New-PlaybookTemplate -Name 'my-playbook' -Scripts @('0407') -Type Simple

# Testing playbook
New-PlaybookTemplate -Name 'my-tests' -Scripts @('0402') -Type Testing

# CI playbook
New-PlaybookTemplate -Name 'my-ci' -Scripts @('0404', '0407') -Type CI
```

### 2. Validation Before Running

**Always validate:**
```powershell
Test-PlaybookDefinition -Path './library/playbooks/my-playbook.psd1'
```

### 3. Descriptive Names

Use clear, descriptive names:
- ✅ `pr-validation-fast`, `deploy-staging`, `cleanup-weekly`
- ❌ `test1`, `my-playbook`, `temp`

### 4. Appropriate Timeouts

Set realistic timeouts:
- Syntax validation: 30-120 seconds
- Unit tests: 300-600 seconds
- Integration tests: 600-1800 seconds
- Deployments: 900-3600 seconds

### 5. Error Handling

Configure error handling appropriately:
```powershell
# Critical operations - stop on error
StopOnError = $true
ContinueOnError = $false

# Best-effort operations - continue on error
StopOnError = $false
ContinueOnError = $true
```

---

## Quick Reference

| Use Case | Template Type | Example Scripts |
|----------|---------------|-----------------|
| Quick validation | Simple | 0407 |
| Pre-commit checks | Testing | 0407, 0413 |
| PR validation | CI | 0407, 0404, 0413 |
| Full CI suite | CI | 0407, 0404, 0402, 0403 |
| Staging deploy | Deployment | 0100, 0101, 0105 |
| Maintenance | Simple | 9001, 9002, 9010 |

---

**Need help?** See `README-PlaybookHelpers.md` for complete documentation.
