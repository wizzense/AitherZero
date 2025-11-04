# AitherZero Orchestration Playbooks

**Complete local execution of GitHub Actions workflows** - Run the same automation locally that runs in CI/CD.

## 🚀 Quick Start

```powershell
# List all available playbooks
./automation-scripts/0960_Run-Playbook.ps1 -List

# Run all validations before pushing code
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick

# Test PR validation locally
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-pr-validation -DryRun

# Run comprehensive tests
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-comprehensive-test
```

## 📋 Available Playbooks

### Core Operations (CI/CD Workflows)

All workflows that run in GitHub Actions have corresponding playbooks for local execution:

| Playbook | Purpose | Duration | Profile Options |
|----------|---------|----------|-----------------|
| **ci-all-validations** | Run all CI validation checks | 15-25 min | quick, standard, comprehensive |
| **ci-pr-validation** | PR validation (syntax, PSScriptAnalyzer) | 10-15 min | quick, standard |
| **ci-comprehensive-test** | Run full test suite | 20-30 min | unit-only, integration-only, ci |
| **ci-quality-validation** | Quality checks on code | 10-15 min | fast, standard |
| **ci-validate-config** | Validate config.psd1 manifest | 2-5 min | standard, fix |
| **ci-validate-manifests** | Validate PS module manifests | 2-5 min | standard, fix, with-tests |
| **ci-validate-test-sync** | Check test-script synchronization | 2-5 min | standard, cleanup, quick |
| **ci-auto-generate-tests** | Auto-generate tests for scripts | 5-15 min | quick, full, detect |
| **ci-workflow-health** | Validate workflow health | 2-5 min | standard, quick |
| **ci-index-automation** | Generate project indexes | 5-10 min | incremental, full, verify |
| **ci-publish-test-reports** | Publish test results | 3-8 min | standard, force |
| **ci-documentation** | Generate documentation | 10-15 min | incremental, full |
| **ci-release** | Automate releases | 15-30 min | production, prerelease |
| **ci-deploy-pr** | Deploy PR environment | 10-20 min | deploy, test, cleanup |

### Testing Playbooks

| Playbook | Purpose | Duration |
|----------|---------|----------|
| **test-quick** | Fast validation for development | 5-10 min |
| **test-standard** | Standard test execution | 10-15 min |
| **test-comprehensive** | Comprehensive validation | 20-30 min |
| **test-full** | Complete test suite | 30-45 min |

## 🎯 Common Use Cases

### Before Pushing Code

```powershell
# Quick validation (2-5 minutes)
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick

# What it runs:
# - PowerShell syntax validation (0407)
# - Config manifest validation (0413, 0003)
# - Module manifest validation (0405)
```

### Before Creating a PR

```powershell
# Standard validation (10-15 minutes)
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations

# What it runs:
# - All quick validations
# - Test-script synchronization (0426)
# - Workflow health checks (0440)
```

### Before Merging a PR

```powershell
# Comprehensive validation (15-25 minutes)
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile comprehensive

# What it runs:
# - All standard validations
# - Quality validation (0404)
# - Unit tests (0400, 0402)
```

### Testing Specific Workflows

```powershell
# Test PR validation workflow
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-pr-validation

# Test documentation generation
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-documentation

# Test auto-generate tests
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-auto-generate-tests -Profile quick
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
./automation-scripts/0960_Run-Playbook.ps1 -List

# Run playbook
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations

# With profile
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-comprehensive-test -Profile unit-only

# Dry run
./automation-scripts/0960_Run-Playbook.ps1 -Playbook test-quick -DryRun
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
./automation-scripts/0960_Run-Playbook.ps1 -List

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
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations -DryRun

# Run specific validation to isolate issue
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-validate-config
```

## 📊 Workflow Coverage

Current coverage: **13 of 21** GitHub Actions workflows have corresponding playbooks.

| Status | Count | Workflows |
|--------|-------|-----------|
| ✅ Complete | 13 | All validation, testing, and deployment workflows |
| 🚧 Partial | 0 | N/A |
| ❌ No Playbook | 8 | GitHub-specific workflows (Pages, Copilot, etc.) |

See [GITHUB-WORKFLOWS-MAPPING.md](./GITHUB-WORKFLOWS-MAPPING.md) for complete details.

## 🚀 Next Steps

1. **Run validations**: `./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick`
2. **Explore playbooks**: `./automation-scripts/0960_Run-Playbook.ps1 -List`
3. **Read mapping**: See [GITHUB-WORKFLOWS-MAPPING.md](./GITHUB-WORKFLOWS-MAPPING.md)
4. **Create custom**: Copy from `templates/` and customize

---

**Version**: 2.1  
**Last Updated**: 2025-11-04  
**Maintainer**: AitherZero CI/CD Team
