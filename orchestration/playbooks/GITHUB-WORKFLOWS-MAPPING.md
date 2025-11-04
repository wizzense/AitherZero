# GitHub Actions Workflow to Playbook Mapping

**Version**: 2.1  
**Last Updated**: 2025-11-04  
**Purpose**: Map GitHub Actions workflows to local playbook equivalents for testing and development

## Overview

This document maps GitHub Actions workflows (`.github/workflows/*.yml`) to their corresponding orchestration playbooks. Use these playbooks to test workflows locally before pushing to CI/CD.

## Quick Reference Table

| GitHub Workflow | Playbook | Category | Scripts Used |
|----------------|----------|----------|--------------|
| **pr-validation.yml** | ci-pr-validation | Operations | 0407, 0410, 0440, 0413 |
| **comprehensive-test-execution.yml** | ci-comprehensive-test | Operations | 0400, 0402, 0403, 0450 |
| **quality-validation.yml** | ci-quality-validation | Operations | 0404, 0420, 0425 |
| **release-automation.yml** | ci-release | Operations | 0407, 0404, 0402, 0798, 0744, 0745 |
| **documentation-automation.yml** | ci-documentation | Operations | 0733, 0745, 0746, 0515 |
| **deploy-pr-environment.yml** | ci-deploy-pr | Operations | 0850, 0853, 0854, 0851 |
| **validate-config.yml** | ci-validate-config | Operations | 0413, 0003 |
| **validate-manifests.yml** | ci-validate-manifests | Operations | 0405 |
| **validate-test-sync.yml** | ci-validate-test-sync | Operations | 0426 |
| **auto-generate-tests.yml** | ci-auto-generate-tests | Operations | 0950, 0426 |
| **workflow-health-check.yml** | ci-workflow-health | Operations | 0440, monitor script |
| **index-automation.yml** | ci-index-automation | Operations | 0745 |
| **publish-test-reports.yml** | ci-publish-test-reports | Operations | 0450 |
| **ALL VALIDATIONS** | ci-all-validations | Operations | Multiple (see below) |

## Detailed Mappings

### 1. PR Validation (`pr-validation.yml` → `ci-pr-validation`)

**Workflow Purpose**: Validate pull requests for code quality and standards

**Playbook**: `core/operations/ci-pr-validation.json`

**Local Usage**:
```powershell
# Standard PR validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-pr-validation

# Quick validation (skip workflows check)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-pr-validation -PlaybookProfile quick
```

**What it validates**:
- PowerShell syntax (0407)
- PSScriptAnalyzer rules (0410)
- GitHub Actions workflows (0440)
- Configuration manifests (0413)

**GitHub Actions Triggers**: `pull_request`, `issue_comment`

---

### 2. Comprehensive Test Execution (`comprehensive-test-execution.yml` → `ci-comprehensive-test`)

**Workflow Purpose**: Run full test suite (unit + integration)

**Playbook**: `core/operations/ci-comprehensive-test.json`

**Local Usage**:
```powershell
# Run all tests
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test

# Unit tests only
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test -PlaybookProfile unit-only

# Integration tests only
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test -PlaybookProfile integration-only
```

**What it runs**:
- Test discovery
- Install testing tools (0400)
- Unit tests (0402)
- Integration tests (0403)
- Report generation (0450)

**GitHub Actions Triggers**: `push` to main/develop, `pull_request`, `schedule` (daily), `workflow_dispatch`

---

### 3. Quality Validation (`quality-validation.yml` → `ci-quality-validation`)

**Workflow Purpose**: Quality checks on code and components

**Playbook**: `core/operations/ci-quality-validation.json`

**Local Usage**:
```powershell
# Comprehensive quality check
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-quality-validation

# Fast quality check
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-quality-validation -PlaybookProfile fast
```

**What it validates**:
- PSScriptAnalyzer on all code (0404)
- Component quality standards (0420)
- Documentation structure (0425)

**GitHub Actions Triggers**: `pull_request`, `workflow_dispatch`

---

### 4. Release Automation (`release-automation.yml` → `ci-release`)

**Workflow Purpose**: Automate release creation and deployment

**Playbook**: `core/operations/ci-release.json`

**Local Usage**:
```powershell
# Production release
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-release `
    -Variables @{version="1.2.3"}

# Pre-release (skip full tests)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-release `
    -PlaybookProfile prerelease -Variables @{version="1.2.3-beta.1"}
```

**What it does**:
- Pre-release validation (0407, 0404, 0402)
- Version updates
- Changelog generation (0798)
- Documentation build (0744, 0745)
- Tag creation and push

**GitHub Actions Triggers**: `push` with tag `v*`, `workflow_dispatch`

**Prerequisites**:
- Clean git working directory
- On `main` branch
- Version number provided

---

### 5. Documentation Automation (`documentation-automation.yml` → `ci-documentation`)

**Workflow Purpose**: Generate and deploy documentation

**Playbook**: `core/operations/ci-documentation.json`

**Local Usage**:
```powershell
# Full documentation generation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-documentation

# Incremental update
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-documentation `
    -PlaybookProfile incremental
```

**What it generates**:
- Function documentation from comments (0733)
- Project indexes (0745)
- Complete documentation set (0746)
- GitHub Pages deployment (0515)

**GitHub Actions Triggers**: `push` to main/dev with doc changes, `pull_request`, `workflow_dispatch`

---

### 6. PR Environment Deployment (`deploy-pr-environment.yml` → `ci-deploy-pr`)

**Workflow Purpose**: Deploy Docker container for PR testing

**Playbook**: `core/operations/ci-deploy-pr.json`

**Local Usage**:
```powershell
# Deploy PR environment
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-deploy-pr `
    -Variables @{prNumber="123"} -PlaybookProfile deploy

# Test existing environment
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-deploy-pr `
    -Variables @{prNumber="123"} -PlaybookProfile test

# Cleanup environment
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-deploy-pr `
    -Variables @{prNumber="123"} -PlaybookProfile cleanup
```

**What it does**:
- Deploy Docker container (0850)
- Validate deployment (0853)
- Run container tests (0854)
- Cleanup environment (0851)

**GitHub Actions Triggers**: `pull_request`

**Prerequisites**: Docker installed and running

---

### 7. Config Validation (`validate-config.yml` → `ci-validate-config`)

**Workflow Purpose**: Validate config.psd1 manifest structure and synchronization

**Playbook**: `core/operations/ci-validate-config.json`

**Local Usage**:
```powershell
# Standard config validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-validate-config

# Validate and fix issues
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-validate-config -PlaybookProfile fix
```

**What it validates**:
- Config manifest structure (0413)
- Config synchronization with automation scripts (0003)
- PSScriptAnalyzer compliance

**GitHub Actions Triggers**: `push`, `pull_request`, `workflow_dispatch`

---

### 8. Manifest Validation (`validate-manifests.yml` → `ci-validate-manifests`)

**Workflow Purpose**: Validate PowerShell module manifests for syntax and Unicode issues

**Playbook**: `core/operations/ci-validate-manifests.json`

**Local Usage**:
```powershell
# Standard manifest validation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-validate-manifests

# Validate and fix Unicode issues
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-validate-manifests -PlaybookProfile fix
```

**What it validates**:
- PowerShell module manifest syntax (0405)
- Unicode character issues
- Restricted language compliance

**GitHub Actions Triggers**: `push`, `pull_request`, `workflow_dispatch`

---

### 9. Test Sync Validation (`validate-test-sync.yml` → `ci-validate-test-sync`)

**Workflow Purpose**: Validate test files are synchronized with automation scripts

**Playbook**: `core/operations/ci-validate-test-sync.json`

**Local Usage**:
```powershell
# Check for orphaned test files
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-validate-test-sync

# Remove orphaned test files
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-validate-test-sync -PlaybookProfile cleanup
```

**What it validates**:
- Test files have corresponding scripts (0426)
- No orphaned test files exist
- Test directory structure matches scripts

**GitHub Actions Triggers**: `push`, `pull_request`, `workflow_dispatch`

---

### 10. Auto-Generate Tests (`auto-generate-tests.yml` → `ci-auto-generate-tests`)

**Workflow Purpose**: Automatically generate tests for automation scripts

**Playbook**: `core/operations/ci-auto-generate-tests.json`

**Local Usage**:
```powershell
# Quick mode - generate tests for new scripts only
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-auto-generate-tests -PlaybookProfile quick

# Full mode - regenerate all tests
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-auto-generate-tests -PlaybookProfile full
```

**What it does**:
- Auto-generate tests for scripts (0950)
- Validate test synchronization (0426)
- Create missing test files

**GitHub Actions Triggers**: `push`, `pull_request`, `workflow_dispatch`

---

### 11. Workflow Health Check (`workflow-health-check.yml` → `ci-workflow-health`)

**Workflow Purpose**: Validate GitHub Actions workflow health and configuration

**Playbook**: `core/operations/ci-workflow-health.json`

**Local Usage**:
```powershell
# Full workflow health check
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-workflow-health

# Quick health check
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-workflow-health -PlaybookProfile quick
```

**What it validates**:
- Workflow health monitor script
- YAML syntax validation (0440)
- Concurrency groups
- workflow_run trigger names
- Circular dependencies

**GitHub Actions Triggers**: `push`, `pull_request`, `workflow_dispatch`

---

### 12. Index Automation (`index-automation.yml` → `ci-index-automation`)

**Workflow Purpose**: Generate project index.md files for all directories

**Playbook**: `core/operations/ci-index-automation.json`

**Local Usage**:
```powershell
# Incremental index generation
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-index-automation

# Full regeneration
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-index-automation -PlaybookProfile full
```

**What it generates**:
- Project indexes (0745)
- Directory structure documentation
- Navigation indexes

**GitHub Actions Triggers**: `push`, `pull_request`, `workflow_dispatch`

---

### 13. Publish Test Reports (`publish-test-reports.yml` → `ci-publish-test-reports`)

**Workflow Purpose**: Collect and publish test results

**Playbook**: `core/operations/ci-publish-test-reports.json`

**Local Usage**:
```powershell
# Publish test reports
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-publish-test-reports

# Force publish
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-publish-test-reports -PlaybookProfile force
```

**What it does**:
- Collect test results (0450)
- Generate test dashboards
- Publish results to reports directory

**GitHub Actions Triggers**: `workflow_run`, `push`, `workflow_dispatch`

---

### 14. All Validations (`ci-all-validations`)

**Workflow Purpose**: Run all CI validation checks in one playbook

**Playbook**: `core/operations/ci-all-validations.json`

**Local Usage**:
```powershell
# Quick validation (essential checks only)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-all-validations -PlaybookProfile quick

# Standard validation (most CI checks)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-all-validations

# Comprehensive validation (all checks including tests)
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-all-validations -PlaybookProfile comprehensive
```

**What it runs**:
- PR validation (0407)
- Config validation (0413, 0003)
- Manifest validation (0405)
- Test sync validation (0426)
- Workflow health check (0440)
- Quality validation (0404) [optional]
- Unit tests (0400, 0402) [optional]

**Profiles**:
- `quick`: Essential checks (2-5 min)
- `standard`: Most CI checks (10-15 min)
- `comprehensive`: All checks including tests (15-25 min)

**No GitHub Workflow**: This is a meta-playbook combining multiple workflows

---

## Easy Playbook Execution

### New Script: 0962_Run-Playbook.ps1

A new automation script makes it easy to run playbooks:

```powershell
# List all available playbooks
./automation-scripts/0962_Run-Playbook.ps1 -List

# Run a playbook
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-all-validations -Profile quick

# Dry run to see what would execute
./automation-scripts/0962_Run-Playbook.ps1 -Playbook ci-pr-validation -DryRun
```

---

## Workflows Without Direct Playbook Equivalents

Some workflows don't have direct playbook equivalents because they're GitHub-specific:

### GitHub-Specific Workflows

| Workflow | Purpose | Why No Playbook |
|----------|---------|-----------------|
| **jekyll-gh-pages.yml** | Deploy Jekyll to Pages | GitHub Pages deployment only |
| **copilot-agent-router.yml** | Route to Copilot agents | GitHub Copilot integration |
| **archive-documentation.yml** | Archive old docs | GitHub Pages deployment |
| **build-aithercore-packages.yml** | Build packages | Package registry integration |

### Specialized Workflows

| Workflow | Purpose | Alternative |
|----------|---------|-------------|
| **auto-create-issues-from-failures.yml** | Create issues from test failures | Manual: 0800, 0810 |
| **phase2-intelligent-issue-creation.yml** | AI-powered issue creation | AI-assisted workflow |
| **comment-release.yml** | Release on comment | GitHub comment trigger |
| **diagnose-ci-failures.yml** | Diagnose CI failures | Manual debugging |

## Testing Workflow Changes Locally

### Before Pushing Workflow Changes

1. **Validate YAML syntax**:
```powershell
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-pr-validation
```

2. **Test workflow logic** with corresponding playbook:
```powershell
# For pr-validation.yml changes
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-pr-validation

# For comprehensive-test-execution.yml changes
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test
```

3. **Verify script execution**:
```powershell
# Run individual scripts that workflow uses
az 0407  # Syntax validation
az 0404  # PSScriptAnalyzer
az 0402  # Unit tests
```

### Workflow Testing Playbook

For testing GitHub Actions workflows locally:

```powershell
# Validate all workflows
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook workflow-validation

# Test workflows with act (if installed)
./automation-scripts/0441_Test-WorkflowsLocally.ps1
```

## Playbook-to-Workflow Differences

### What Playbooks Don't Do

1. **GitHub-specific actions**: No `actions/checkout`, `actions/upload-artifact`, etc.
2. **GitHub context**: No `${{ github.* }}` variables
3. **Secrets**: No GitHub Secrets access
4. **Matrix builds**: No parallel matrix execution
5. **Event triggers**: Manual execution only

### What Playbooks DO Provide

1. **Local testing**: Test logic before pushing
2. **Development workflow**: Rapid iteration
3. **Troubleshooting**: Debug issues locally
4. **Documentation**: Understand workflow behavior
5. **Consistency**: Same steps as CI/CD

## Profile Equivalents

Many workflows have conditional logic that maps to playbook profiles:

| Workflow Condition | Playbook Profile | Example |
|-------------------|------------------|---------|
| `test_type == 'unit'` | unit-only | ci-comprehensive-test |
| `test_type == 'integration'` | integration-only | ci-comprehensive-test |
| `prerelease == true` | prerelease | ci-release |
| `mode == 'Incremental'` | incremental | ci-documentation |
| Quick checks | quick | ci-pr-validation |

## Environment Variables

### Workflow → Playbook Mapping

| Workflow Env Var | Playbook Equivalent | Notes |
|-----------------|---------------------|-------|
| `AITHERZERO_CI=true` | Automatic in CI mode | Set in playbook environment |
| `AITHERZERO_NONINTERACTIVE=true` | `nonInteractive=true` | Variable in playbook |
| `GITHUB_TOKEN` | N/A | Use `gh` CLI authentication |
| `PR_NUMBER` | `prNumber` variable | Pass as parameter |

## Best Practices

### 1. Test Locally First

Always run the corresponding playbook before pushing workflow changes:

```powershell
# Change workflow file
vim .github/workflows/pr-validation.yml

# Test locally
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-pr-validation

# If passes, commit and push
git add .github/workflows/pr-validation.yml
git commit -m "feat: update PR validation workflow"
git push
```

### 2. Match Script Versions

Ensure playbooks use the same script numbers as workflows:

- Workflow uses `0407` → Playbook stage uses `["0407"]`
- Keep script sequence order consistent

### 3. Profile Mapping

Use profiles to test different workflow paths:

```powershell
# Test workflow_dispatch with test_type='unit'
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test `
    -PlaybookProfile unit-only

# Test workflow_dispatch with test_type='integration'
./Start-AitherZero.ps1 -Mode Orchestrate -Playbook ci-comprehensive-test `
    -PlaybookProfile integration-only
```

### 4. Debug Failed Workflows

When a GitHub Actions workflow fails:

1. Run corresponding playbook locally
2. Check which stage fails
3. Run individual script: `az XXXX`
4. Fix issue
5. Re-run playbook to verify
6. Push fix

## Maintenance

### Keeping Playbooks in Sync

When updating workflows:

1. **Update workflow file** (`.github/workflows/*.yml`)
2. **Update corresponding playbook** (`orchestration/playbooks/core/operations/*.json`)
3. **Update this mapping document** if scripts change
4. **Test both** workflow (push) and playbook (local)

### Version Control

Both workflows and playbooks should be version controlled together:

```powershell
# Workflow and playbook change together
git add .github/workflows/pr-validation.yml
git add orchestration/playbooks/core/operations/ci-pr-validation.json
git commit -m "feat: update PR validation with new check"
```

## Support

- **Playbook Issues**: [GitHub Issues](https://github.com/wizzense/AitherZero/issues)
- **Workflow Documentation**: See `.github/workflows/README.md`
- **Script Documentation**: See `automation-scripts/README.md`

---

**Note**: This mapping is maintained as workflows evolve. Always check playbook metadata `githubWorkflow` field for current mapping.
