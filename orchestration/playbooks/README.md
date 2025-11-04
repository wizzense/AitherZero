# AitherZero Orchestration Playbooks

**Complete local execution of GitHub Actions workflows** - Run the same automation locally that runs in CI/CD.

## 🚀 Quick Start

```powershell
# List all available playbooks
./automation-scripts/0962_Run-Playbook.ps1 -List

# Run all validations before pushing code
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick

# Test PR validation locally
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-pr-validation -DryRun

# Run comprehensive tests
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-comprehensive-test
```

## 📋 Available Playbooks

### Core Operations (CI/CD Workflows)

All workflows that run in GitHub Actions have corresponding playbooks for local execution:

| Playbook | Purpose | Duration | Workflow |
|----------|---------|----------|----------|
| **ci-all-validations** | Meta-playbook - all validation checks | 2-25 min | Combined |
| **ci-pr-validation** | PR validation (syntax, PSScriptAnalyzer) | 1-2 min | pr-validation.yml |
| **ci-comprehensive-test** | Run full test suite | 5-10 min | comprehensive-test-execution.yml |
| **ci-quality-validation** | Quality checks on code | 2-3 min | quality-validation.yml |
| **ci-validate-config** | Validate config.psd1 manifest | 30 sec | validate-config.yml |
| **ci-validate-manifests** | Validate PS module manifests | 30 sec | validate-manifests.yml |
| **ci-validate-test-sync** | Check test-script synchronization | 1 min | validate-test-sync.yml |
| **ci-auto-generate-tests** | Auto-generate tests for scripts | 1-2 min | auto-generate-tests.yml |
| **ci-workflow-health** | Validate workflow health | 30 sec | workflow-health-check.yml |
| **ci-index-automation** | Generate project indexes | 1 min | index-automation.yml |
| **ci-publish-test-reports** | Publish test results | 2-3 min | publish-test-reports.yml |

### Documentation & Reporting

| Playbook | Purpose | Duration |
|----------|---------|----------|
| **documentation-tracking** | Track doc freshness & validate coverage | 2-5 min |

### Testing Playbooks

| Playbook | Purpose | Duration |
|----------|---------|----------|
| **test-orchestrated** | Orchestrated testing with unified reporting | 10-15 min |

## 🎯 Common Use Cases

### Before Pushing Code

```powershell
# Quick validation (2-5 minutes)
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick

# What it runs:
# - PowerShell syntax validation (0407)
# - Config manifest validation (0413)
# - Test-script synchronization (0426)
```

### Before Creating a PR

```powershell
# Standard validation (10-15 minutes)
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations

# What it runs:
# - Syntax validation (0407)
# - Config validation (0413)
# - Manifest validation (0414)
# - Test sync validation (0426)
# - Unit tests (0402)
# - PSScriptAnalyzer (0404)
```

### Before Merging a PR

```powershell
# Comprehensive validation (15-25 minutes)
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations -Profile comprehensive

# What it runs:
# - All standard validations
# - Integration tests (0403)
# - Quality validation (0420)
# - Workflow health check (0950)
```

### Testing Specific Workflows

```powershell
# Test PR validation workflow
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-pr-validation

# Preview what would run (WhatIf mode)
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-pr-validation -WhatIf

# Test config validation
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-validate-config
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-auto-generate-tests -Profile quick
```

## 📖 Usage Patterns

### Using Start-AitherZero.ps1 Directly

```powershell
# Standard execution
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-pr-validation

# With profile
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test -PlaybookProfile unit-only

# Dry run (preview only)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook test-quick -DryRun

# With custom variables
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-release -Variables @{version="1.2.3"}
```

### Using the Wrapper Script (Recommended)

```powershell
# List all playbooks
./automation-scripts/0962_Run-Playbook.ps1 -List

# Run playbook
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations

# With profile
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-comprehensive-test -Profile unit-only

# Dry run
./automation-scripts/0962_Run-Playbook.ps1 -Playbook test-quick -DryRun
```

## 🔧 Playbook Profiles

Most playbooks support profiles to customize execution:

| Profile | Description | Use When |
|---------|-------------|----------|
| **quick** | Fast execution, essential checks only | During active development |
| **standard** | Standard execution, most checks | Before creating PR |
| **comprehensive** | Complete execution, all checks | Before merging PR |
| **fix** | Validate and fix issues | Fixing validation failures |
| **ci** | CI/CD mode with reporting | CI/CD pipelines |

## 📚 Documentation

- **[GITHUB-WORKFLOWS-MAPPING.md](./GITHUB-WORKFLOWS-MAPPING.md)**: Complete mapping of workflows to playbooks
- **[MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md)**: Guide for migrating to v2.0 playbooks
- **[EXECUTIVE-SUMMARY.md](./EXECUTIVE-SUMMARY.md)**: High-level overview of orchestration system

## 🏗️ Playbook Structure

Playbooks are JSON files with the following structure:

```json
{
  "metadata": {
    "name": "playbook-name",
    "description": "What this playbook does",
    "version": "1.0.0",
    "category": "operations",
    "tags": ["ci", "testing"],
    "estimatedDuration": "5-10 minutes",
    "githubWorkflow": "workflow-name.yml"
  },
  "requirements": {
    "minimumPowerShellVersion": "7.0",
    "requiredModules": ["Pester"],
    "requiredTools": [],
    "platforms": ["Windows", "Linux", "macOS"]
  },
  "orchestration": {
    "defaultVariables": {},
    "profiles": {
      "quick": {
        "description": "Fast execution",
        "variables": {}
      }
    },
    "stages": [
      {
        "name": "Stage Name",
        "description": "What this stage does",
        "sequences": ["0407"],
        "variables": {},
        "continueOnError": false,
        "timeout": 120
      }
    ]
  }
}
```

## 🎨 Creating Custom Playbooks

1. Copy a template from `orchestration/playbooks/templates/`
2. Update metadata and requirements
3. Define stages with script sequences
4. Add profiles for different execution modes
5. Test with dry-run: `./Start-AitherZero.ps1 -Mode Orchestrate -Playbook your-playbook -DryRun`

## 🤝 Best Practices

1. **Test locally first**: Always run playbooks locally before pushing to CI/CD
2. **Use profiles**: Customize execution for different scenarios
3. **Dry run first**: Preview what will execute with `-DryRun`
4. **Match workflows**: Keep playbooks synchronized with GitHub Actions workflows
5. **Document changes**: Update playbook metadata when modifying

## 🔍 Troubleshooting

### Playbook Not Found

```powershell
# List all available playbooks
./automation-scripts/0962_Run-Playbook.ps1 -List

# Ensure playbook exists in orchestration/playbooks/
```

### Script Not Found

```powershell
# Check if automation script exists
ls automation-scripts/0XXX*.ps1

# Playbook may reference a script that doesn't exist
```

### Validation Failures

```powershell
# Run validation in dry-run mode to see execution plan
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations -DryRun

# Run specific validation to isolate issue
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-validate-config
```

## 📊 Workflow Coverage

Current coverage: **13 of 23** GitHub Actions workflows have corresponding playbooks.

| Status | Count | Workflows |
|--------|-------|-----------|
| ✅ Complete | 13 | All validation, testing, and deployment workflows |
| 🚧 Partial | 0 | N/A |
| ❌ No Playbook | 10 | GitHub-specific workflows (Pages, Copilot, etc.) |

See [GITHUB-WORKFLOWS-MAPPING.md](./GITHUB-WORKFLOWS-MAPPING.md) for complete details.

## 🚀 Next Steps

1. **Run validations**: `./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick`
2. **Explore playbooks**: `./automation-scripts/0962_Run-Playbook.ps1 -List`
3. **Read mapping**: See [GITHUB-WORKFLOWS-MAPPING.md](./GITHUB-WORKFLOWS-MAPPING.md)
4. **Create custom**: Copy from `templates/` and customize

---

**Version**: 2.1  
**Last Updated**: 2025-11-04  
**Maintainer**: AitherZero CI/CD Team
