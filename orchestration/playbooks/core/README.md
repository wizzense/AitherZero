# AitherZero Playbook Core Files

This directory contains the core playbook JSON files for local CI/CD workflow execution.

## Directory Structure

```
core/
├── operations/     # CI/CD operations playbooks (15 files)
│   ├── ci-all-validations.json
│   ├── ci-pr-validation.json
│   ├── ci-comprehensive-test.json
│   ├── ci-quality-validation.json
│   ├── ci-validate-config.json
│   ├── ci-validate-manifests.json
│   ├── ci-validate-test-sync.json
│   ├── ci-auto-generate-tests.json
│   ├── ci-workflow-health.json
│   ├── ci-index-automation.json
│   ├── ci-publish-test-reports.json
│   ├── ci-documentation.json
│   ├── ci-release.json
│   ├── ci-deploy-pr.json
│   └── ci-unified-testing.json
└── testing/        # Testing playbooks (4 files)
    ├── test-quick.json
    ├── test-standard.json
    ├── test-comprehensive.json
    └── test-full.json
```

## Usage

All playbooks can be executed using the wrapper script:

```powershell
# List all available playbooks
./automation-scripts/0960_Run-Playbook.ps1 -List

# Run a playbook
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations

# Run with profile
./automation-scripts/0960_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick

# Dry run (preview execution)
./automation-scripts/0960_Run-Playbook.ps1 -Playbook test-quick -DryRun
```

## Operations Playbooks

Operations playbooks mirror GitHub Actions workflows for local execution:

| Playbook | GitHub Workflow | Purpose | Duration |
|----------|----------------|---------|----------|
| ci-all-validations | Multiple | All CI validation checks | 15-25 min |
| ci-pr-validation | pr-validation.yml | PR validation | 10-15 min |
| ci-comprehensive-test | comprehensive-test-execution.yml | Full test suite | 20-30 min |
| ci-quality-validation | quality-validation.yml | Quality checks | 10-15 min |
| ci-validate-config | validate-config.yml | Config validation | 2-5 min |
| ci-validate-manifests | validate-manifests.yml | Manifest validation | 2-5 min |
| ci-validate-test-sync | validate-test-sync.yml | Test synchronization | 2-5 min |
| ci-auto-generate-tests | auto-generate-tests.yml | Auto-generate tests | 5-15 min |
| ci-workflow-health | workflow-health-check.yml | Workflow health | 2-5 min |
| ci-index-automation | index-automation.yml | Generate indexes | 5-10 min |
| ci-publish-test-reports | publish-test-reports.yml | Publish reports | 3-8 min |
| ci-documentation | documentation-automation.yml | Generate docs | 10-15 min |
| ci-release | release-automation.yml | Release automation | 15-30 min |
| ci-deploy-pr | deploy-pr-environment.yml | PR deployment | 10-20 min |

## Testing Playbooks

Testing playbooks provide different levels of validation:

| Playbook | Purpose | Duration | Use When |
|----------|---------|----------|----------|
| test-quick | Fast validation | 5-10 min | During active development |
| test-standard | Standard testing | 10-15 min | Before creating PR |
| test-comprehensive | Comprehensive validation | 20-30 min | Before merging PR |
| test-full | Complete test suite | 30-45 min | Final validation |

## Profile System

Most playbooks support profiles to customize execution:

| Profile | Description | Use Case |
|---------|-------------|----------|
| quick | Essential checks only | Active development |
| standard | Most checks | Before PR creation |
| comprehensive | All checks including tests | Before PR merge |
| ci | CI/CD optimized | Automated pipelines |

## JSON Structure

All playbooks follow this structure:

```json
{
  "metadata": {
    "name": "playbook-name",
    "description": "Purpose",
    "version": "1.0.0",
    "category": "operations|testing",
    "tags": ["tag1", "tag2"],
    "estimatedDuration": "X-Y minutes",
    "githubWorkflow": "workflow-name.yml"
  },
  "requirements": {
    "minimumPowerShellVersion": "7.0",
    "requiredModules": [],
    "requiredTools": [],
    "platforms": ["Windows", "Linux", "macOS"]
  },
  "orchestration": {
    "defaultVariables": {},
    "profiles": {},
    "stages": [
      {
        "name": "Stage Name",
        "description": "Description",
        "sequences": ["0XXX"],
        "variables": {},
        "continueOnError": false,
        "timeout": 120,
        "condition": "{{variable}} == value"
      }
    ]
  }
}
```

## Best Practices

1. **Test locally first**: Run playbooks before pushing to CI/CD
2. **Use profiles**: Customize execution for different scenarios
3. **Dry run first**: Preview execution with `-DryRun`
4. **Match workflows**: Keep in sync with GitHub Actions
5. **Document changes**: Update metadata when modifying

## Validation

All playbooks are validated for:
- Valid JSON structure
- Required fields present
- Proper stage configuration
- Executable script references

## See Also

- [Parent README](../README.md) - Playbook system overview
- [GITHUB-WORKFLOWS-MAPPING.md](../GITHUB-WORKFLOWS-MAPPING.md) - Workflow mappings
- [MIGRATION-GUIDE.md](../MIGRATION-GUIDE.md) - Migration guide
- [../../automation-scripts/0960_Run-Playbook.ps1](../../automation-scripts/0960_Run-Playbook.ps1) - Wrapper script

---

**Version**: 1.0.0  
**Last Updated**: 2025-11-04  
**Maintainer**: AitherZero CI/CD Team
