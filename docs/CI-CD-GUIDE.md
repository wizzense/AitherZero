# AitherZero CI/CD System Guide

## Overview

The AitherZero CI/CD system uses a **single comprehensive playbook** (`ci-cd-complete`) that handles the entire pipeline from validation to release. This unified approach ensures consistency and simplicity.

## Quick Start

### Run Complete CI/CD Pipeline

```powershell
# Run the complete CI/CD pipeline
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete

# Using the az shortcut
az playbook ci-cd-complete

# For CI environments (automated)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete -CI
```

### Control What Runs

The same playbook adapts to different scenarios through variables:

```powershell
# For Pull Requests (no build/release)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete -CI `
  -Variables @{
    RunBuild = $false
    CreateRelease = $false
    TestProfile = 'Standard'
  }

# For Main Branch (full pipeline with docs)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete -CI `
  -Variables @{
    RunBuild = $true
    DeployDocs = $true
    TestProfile = 'Full'
  }

# For Tagged Releases
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete -CI `
  -Variables @{
    CreateRelease = $true
    Version = 'v1.2.3'
  }
```

## The Single Playbook Architecture

### One Playbook, Multiple Scenarios

The `ci-cd-complete` playbook (`/orchestration/playbooks-psd1/ops/ci-cd-complete.psd1`) contains all stages:

1. **Environment Setup** - Initialize and detect configuration
2. **Validation** - Syntax, workflows, playbooks
3. **Static Analysis** - PSScriptAnalyzer
4. **Testing** - Unit and integration tests with coverage
5. **Security** - Vulnerability scanning
6. **Build** - Create release packages
7. **Package Validation** - Test built packages
8. **Documentation** - Generate reports and dashboards
9. **Release** - Create GitHub releases

### Intelligent Stage Control

Stages automatically adapt based on:
- **Variables**: Control flags like `RunTests`, `RunBuild`, etc.
- **Environment**: CI vs local, branch detection
- **Context**: Pull request vs main branch vs tagged release

## GitHub Actions Integration

### Simple Workflows, Complex Playbook

Our GitHub workflows are intentionally simple - they just call the playbook:

**CI Workflow** (`.github/workflows/ci.yml`):
```yaml
steps:
  - name: Checkout
    uses: actions/checkout@v4
    
  - name: Bootstrap
    run: ./bootstrap.ps1
    
  - name: Run CI/CD Pipeline
    run: |
      ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete -CI `
        -Variables @{ 
          RunBuild = $false      # Don't build on PRs
          CreateRelease = $false # Don't release on PRs
          TestProfile = 'Standard'
        }
```

**CD Workflow** (`.github/workflows/cd.yml`):
```yaml
steps:
  - name: Run CI/CD Pipeline
    run: |
      # Detect if this is a release
      $createRelease = "${{ github.ref }}" -match "^refs/tags/v"
      
      ./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-cd-complete -CI `
        -Variables @{ 
          RunBuild = $true
          CreateRelease = $createRelease
          DeployDocs = $true
          TestProfile = 'Full'
        }
```

## Configuration Through Variables

### Control Flags

| Variable | Default | Purpose |
|----------|---------|---------|
| `RunValidation` | `$true` | Run syntax and workflow validation |
| `RunTests` | `$true` | Run test suite |
| `RunSecurity` | `$true` | Run security scanning |
| `RunBuild` | `$true` | Build release packages |
| `CreateRelease` | `$false` | Create GitHub release |
| `DeployDocs` | `$false` | Deploy to GitHub Pages |

### Configuration Options

| Variable | Options | Purpose |
|----------|---------|---------|
| `TestProfile` | Quick, Standard, Full | Test thoroughness |
| `BuildProfiles` | Core, Standard, Full | Package types to build |
| `CoverageThreshold` | 0-100 | Required code coverage % |
| `Version` | String | Override version detection |

## Local Development Workflow

### Before Committing
```powershell
# Quick validation
az playbook ci-cd-complete -Variables @{
  RunTests = $true
  RunBuild = $false
  TestProfile = 'Quick'
}
```

### Before Pull Request
```powershell
# Standard testing
az playbook ci-cd-complete -Variables @{
  RunTests = $true
  RunSecurity = $true
  RunBuild = $false
  TestProfile = 'Standard'
}
```

### Test Full Pipeline
```powershell
# Everything except release
az playbook ci-cd-complete -Variables @{
  CreateRelease = $false
  DeployDocs = $false
  TestProfile = 'Full'
}
```

## Quality Gates

The playbook enforces quality standards automatically:

- **Validation**: All code must pass syntax checks
- **Testing**: 95% minimum test pass rate
- **Coverage**: 80% code coverage threshold
- **Analysis**: Zero errors, maximum 20 warnings
- **Security**: No critical vulnerabilities

## Reports and Artifacts

### Generated Reports
- Test results: `./tests/results/`
- Coverage reports: `./tests/coverage/`
- Security scans: `./tests/security/`
- Analysis reports: `./tests/analysis/`
- Project dashboard: `./reports/dashboard.html`

### GitHub Pages Dashboard
When `DeployDocs = $true`, the pipeline deploys:
- Live test results
- Coverage trends
- Security status
- Release history

## Troubleshooting

### Test the Playbook
```powershell
# Validate playbook syntax
Import-PowerShellDataFile './orchestration/playbooks-psd1/ops/ci-cd-complete.psd1'

# Dry run to see what would execute
az playbook ci-cd-complete -WhatIf

# Run specific stages only
az playbook ci-cd-complete -Variables @{
  RunValidation = $true
  RunTests = $false
  RunSecurity = $false
  RunBuild = $false
}
```

### Common Issues and Solutions

**Tests failing?**
```powershell
# Use AI-powered test fixing
az playbook test-fix-workflow
```

**Security scan too slow?**
```powershell
# Use quick scan level
-Variables @{ ScanLevel = 'Quick' }
```

**Build failing?**
```powershell
# Test without building
-Variables @{ RunBuild = $false }
```

## Best Practices

1. **One Playbook Rule**: Always use `ci-cd-complete` for CI/CD
2. **Control Through Variables**: Don't create new playbooks, use variables
3. **Test Locally**: Run the playbook locally before pushing
4. **Progressive Testing**: Start with Quick, then Standard, then Full
5. **Monitor Quality Gates**: Keep metrics high

## Examples

### PR Validation
```powershell
az playbook ci-cd-complete -Variables @{
  RunBuild = $false
  CreateRelease = $false
  TestProfile = 'Standard'
}
```

### Nightly Build
```powershell
az playbook ci-cd-complete -Variables @{
  RunBuild = $true
  CreateRelease = $false
  TestProfile = 'Full'
}
```

### Release Build
```powershell
az playbook ci-cd-complete -Variables @{
  CreateRelease = $true
  DeployDocs = $true
  Version = '1.0.0'
  TestProfile = 'Full'
}
```

### Security Audit Only
```powershell
az playbook ci-cd-complete -Variables @{
  RunValidation = $false
  RunTests = $false
  RunSecurity = $true
  RunBuild = $false
}
```

## Summary

The AitherZero CI/CD system's strength lies in its simplicity:
- **One playbook** handles everything
- **Variables** control what runs
- **Same commands** work locally and in CI
- **GitHub workflows** are just thin wrappers

This approach eliminates complexity while providing full enterprise CI/CD capabilities.