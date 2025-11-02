# GitHub Actions Workflow to Playbook Mapping

**Version**: 2.0  
**Last Updated**: 2025-11-02  
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

## Workflows Without Direct Playbook Equivalents

Some workflows don't have direct playbook equivalents because they're GitHub-specific:

### GitHub-Specific Workflows

| Workflow | Purpose | Why No Playbook |
|----------|---------|-----------------|
| **jekyll-gh-pages.yml** | Deploy Jekyll to Pages | GitHub Pages deployment only |
| **copilot-agent-router.yml** | Route to Copilot agents | GitHub Copilot integration |
| **workflow-health-check.yml** | Monitor workflow health | GitHub Actions metadata |
| **validate-config.yml** | Validate config manifest | Simple validation (0413) |
| **validate-manifests.yml** | Validate PS manifests | Simple validation (0405) |

### Specialized Workflows

| Workflow | Purpose | Alternative |
|----------|---------|-------------|
| **auto-create-issues-from-failures.yml** | Create issues from test failures | Manual: 0800, 0810 |
| **phase2-intelligent-issue-creation.yml** | AI-powered issue creation | AI-assisted workflow |
| **comment-release.yml** | Release on comment | GitHub comment trigger |
| **publish-test-reports.yml** | Publish test reports | Use ci-comprehensive-test |

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
