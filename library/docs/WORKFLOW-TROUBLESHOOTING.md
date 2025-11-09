# GitHub Actions Workflow Troubleshooting

## Problem: Workflow Checks Disappearing from PRs

### Symptoms
- PR initially shows 20+ workflow checks running
- Checks show passes/fails for a brief period
- All checks suddenly disappear from PR view
- No status checks appear for required merges

### Root Cause
**Trailing spaces in YAML workflow files** can cause GitHub Actions parser to fail silently, resulting in workflows not being recognized or executed.

### Why This Happens
GitHub Actions uses a YAML parser that is sensitive to whitespace characters. When trailing spaces are present:

1. The YAML parser may fail to parse the file correctly
2. The workflow is silently ignored (no error message shown)
3. Checks that were previously registered disappear from the PR
4. The issue affects ALL workflows, not just the one with the error

### Solution
Remove all trailing spaces from workflow files:

```bash
# Fix all workflow files at once
find .github/workflows -name '*.yml' -exec sed -i 's/[[:space:]]*$//' {} \;

# Verify the fix
python3 -c "import yaml; import sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/*.yml
```

### Prevention
We've implemented multiple safeguards to prevent this issue:

#### 1. Diagnostic Script
Run the diagnostic script to check for common workflow issues:

```bash
./.github/scripts/diagnose-workflows.sh
```

This checks for:
- YAML syntax errors
- Trailing spaces
- Invalid workflow triggers
- Circular workflow dependencies

#### 2. Pre-commit Hook
Install the pre-commit hook to validate workflows before committing:

```bash
git config core.hooksPath .githooks
```

The hook automatically:
- Validates YAML syntax
- Detects trailing spaces
- Prevents commits with workflow errors

#### 3. Editor Configuration
Configure your editor to remove trailing spaces automatically:

**VS Code** (`.vscode/settings.json`):
```json
{
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true
}
```

**Vim** (`.vimrc`):
```vim
autocmd BufWritePre * :%s/\s\+$//e
```

**EditorConfig** (`.editorconfig`):
```ini
[*.{yml,yaml}]
trim_trailing_whitespace = true
insert_final_newline = true
```

### Validation Commands

#### Quick Validation
```bash
# Check for trailing spaces
grep -n "[[:space:]]$" .github/workflows/*.yml

# Validate YAML syntax
for f in .github/workflows/*.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "✓ $f" || echo "✗ $f"
done
```

#### Install yamllint for Advanced Validation
```bash
pip install yamllint

# Validate all workflows
yamllint -d relaxed .github/workflows/*.yml
```

### Other Common Issues

#### 1. Emoji in Workflow Names
**Problem:** Emoji can cause parsing issues in some environments.

**Solution:** Use plain ASCII or escape emoji in strings:
```yaml
# BAD
name: 🚀 Deploy Production

# GOOD
name: "Deploy Production"
```

#### 2. Unescaped Colons in Names
**Problem:** Colons have special meaning in YAML.

**Solution:** Quote strings with colons:
```yaml
# BAD
name: Phase 2: Implementation

# GOOD
name: "Phase 2: Implementation"
# or
name: 'Phase 2 - Implementation'
```

#### 3. Branch Name Mismatches
**Problem:** Workflow doesn't trigger because branch name doesn't match.

**Solution:** Include all branch variants:
```yaml
on:
  push:
    branches: [main, develop, dev, dev-staging]
  pull_request:
    branches: [main, develop, dev]
```

#### 4. Missing pull_request Trigger
**Problem:** Workflow exists but doesn't run on PRs.

**Solution:** Add pull_request trigger:
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
```

### Monitoring Workflow Health

#### Check Recent Workflow Runs
```bash
# View recent workflow runs
gh run list --limit 20

# View failed runs
gh run list --status failure --limit 10

# View specific run logs
gh run view [run-id] --log-failed
```

#### Check Workflow Status
```bash
# List all workflows
gh workflow list

# View workflow details
gh workflow view [workflow-name]
```

### Files Fixed in This Issue
The following workflow files had trailing spaces removed:

- archive-documentation.yml
- auto-create-issues-from-failures.yml
- build-aithercore-packages.yml
- comment-release.yml
- deploy-pr-environment.yml
- diagnose-ci-failures.yml
- documentation-tracking.yml
- jekyll-gh-pages.yml
- parallel-testing.yml
- phase2-intelligent-issue-creation.yml
- pr-validation.yml
- publish-test-reports.yml
- quality-validation.yml
- release-automation.yml
- validate-config.yml
- workflow-health-check.yml

### Quick Reference

| Issue | Symptom | Fix |
|-------|---------|-----|
| Trailing spaces | Checks disappear | `find .github/workflows -name '*.yml' -exec sed -i 's/[[:space:]]*$//' {} \;` |
| YAML syntax error | Workflow fails immediately | Validate with `yamllint` or Python's `yaml.safe_load()` |
| Wrong branch name | Workflow doesn't trigger | Update `branches:` in workflow `on:` section |
| Missing PR trigger | No checks on PR | Add `pull_request:` to workflow `on:` section |

### Related Resources
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [YAML Specification](https://yaml.org/spec/)
- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [Repository Troubleshooting Guide](.github/prompts/github-actions-troubleshoot.md)

### Prevention Checklist
- [ ] Install pre-commit hooks: `git config core.hooksPath .githooks`
- [ ] Configure editor to trim trailing whitespace
- [ ] Run diagnostic script before pushing: `./.github/scripts/diagnose-workflows.sh`
- [ ] Validate YAML syntax locally before committing
- [ ] Test workflow changes on a separate branch first

---

**Last Updated:** 2025-11-06
**Issue Reference:** Workflow checks disappearing from PRs
**Resolution:** Removed trailing spaces from 16 workflow files
