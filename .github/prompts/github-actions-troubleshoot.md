# GitHub Actions Troubleshooting Prompt

Use this prompt when GitHub Actions workflows are failing or not appearing on PRs.

## One-Shot Troubleshooting Prompt

```
@copilot GitHub Actions workflows are failing/not showing on PR. Please investigate and fix:

1. Validate YAML syntax for ALL workflows:
   yamllint -d relaxed .github/workflows/*.yml
   Look for: syntax errors, trailing spaces, invalid mappings, emoji/special chars

2. Check workflow triggers:
   grep -A5 "^on:" .github/workflows/*.yml
   Verify: branch names match (main/develop/dev), pull_request triggers exist

3. Check recent workflow runs:
   gh run list --limit 20 --json conclusion,status,name,headBranch
   Look for: patterns in failures, workflows not running at all

4. Common root causes to check:
   - YAML syntax errors (breaks entire workflow system)
   - Wrong branch names in triggers (workflow won't run)
   - Missing pull_request trigger (no PR checks)
   - Circular workflow_run dependencies
   - Invalid emoji or special characters in names

5. Fix process:
   - Fix YAML syntax errors FIRST (highest priority)
   - Update branch triggers: [main, develop, dev]
   - Remove emoji from workflow names
   - Use proper YAML escaping for colons in strings
   - Strip trailing whitespace from all lines

6. Verify fixes:
   yamllint .github/workflows/*.yml  # Must pass
   git commit && git push  # Push fixes
   Check PR for workflow runs appearing
```

## Specific Scenarios

### Scenario 1: Workflows Suddenly Disappeared from PR

**Symptoms:**
- PR had working checks, now none appear
- Workflows in Actions tab but not on PR
- No status checks required for merge

**Root Causes:**
1. New workflow file has YAML syntax error
2. Recent commit broke workflow YAML
3. Workflow renamed or deleted
4. Branch trigger mismatch

**Quick Fix:**
```bash
# Find the problematic workflow
for f in .github/workflows/*.yml; do
  echo "Checking $f"
  yamllint -d relaxed "$f" 2>&1 | grep -i error && echo "ERROR IN: $f"
done

# Common fixes
# 1. Remove emoji from names
sed -i 's/name: 🚀 /name: "/' .github/workflows/*.yml

# 2. Fix colon escaping
sed -i 's/name: \(.*\):\(.*\)/name: "\1 - \2"/' .github/workflows/*.yml

# 3. Strip trailing whitespace
find .github/workflows -name "*.yml" -exec sed -i 's/[[:space:]]*$//' {} \;

# 4. Validate all
for f in .github/workflows/*.yml; do
  yamllint -d relaxed "$f" || echo "Still broken: $f"
done
```

### Scenario 2: Workflows Failing Immediately

**Symptoms:**
- Workflows start but fail in < 10 seconds
- Error about workflow syntax or configuration
- All jobs fail together

**Root Causes:**
1. PowerShell syntax error in inline script
2. Invalid expression in `if:` condition
3. Missing required input or secret
4. Circular workflow_run trigger

**Quick Fix:**
```bash
# Check for shell script syntax
grep -A20 "run: |" .github/workflows/*.yml | grep -E "(unclosed|unexpected)"

# Check for invalid expressions
grep -E "if:.*\$\{\{.*\}\}" .github/workflows/*.yml

# Look for workflow_run loops
grep -A10 "workflow_run:" .github/workflows/*.yml
```

### Scenario 3: Workflows Not Triggering on PR

**Symptoms:**
- Workflows exist and are valid
- Manual trigger works
- But PR shows no checks

**Root Causes:**
1. Missing `pull_request` trigger
2. Branch name doesn't match trigger pattern
3. Path filters exclude all changed files
4. Workflow in draft PR only

**Quick Fix:**
```bash
# Check PR triggers
grep -A10 "^on:" .github/workflows/*.yml | grep -A3 "pull_request:"

# Add missing PR trigger
# Edit .github/workflows/[workflow].yml:
on:
  pull_request:
    branches: [main, develop, dev]
    types: [opened, synchronize, reopened]
```

### Scenario 4: Circular Workflow Dependencies

**Symptoms:**
- Workflows never complete
- Workflows keep retriggering each other
- Timeout after 6 hours

**Root Causes:**
1. Workflow A triggers Workflow B which triggers Workflow A
2. workflow_run: completed triggers on itself
3. Multiple workflows editing same files

**Quick Fix:**
```bash
# Map workflow_run dependencies
echo "Workflow Dependencies:"
grep -B5 "workflow_run:" .github/workflows/*.yml | grep -E "(name:|workflows:)"

# Break the loop by:
# 1. Remove workflow_run trigger from one
# 2. Use workflow_dispatch instead
# 3. Add conditions to prevent loops:
if: github.event.workflow_run.conclusion == 'success' && github.event.workflow_run.head_branch != 'skip-ci'
```

## Prevention Best Practices

### 1. Always Validate YAML Before Committing

```bash
# Add to pre-commit hook
for f in .github/workflows/*.yml; do
  yamllint -d relaxed "$f" || exit 1
done
```

### 2. Use Consistent Branch Patterns

```yaml
on:
  push:
    branches: [main, develop, dev]  # All variants
  pull_request:
    branches: [main, develop, dev]
    types: [opened, synchronize, reopened]
```

### 3. Avoid Special Characters in Names

```yaml
# BAD - emoji can cause parsing issues
name: 🚀 Deploy Production

# BAD - unescaped colon
name: Phase 2: Implementation

# GOOD - plain ASCII
name: "Deploy Production"

# GOOD - escaped colon
name: 'Phase 2 - Implementation'
```

### 4. Test Workflows Locally

```bash
# Use act to test locally (if available)
act -l  # List workflows
act -j job-name -n  # Dry run
act pull_request  # Test PR trigger

# Or validate with actionlint
actionlint .github/workflows/*.yml
```

### 5. Monitor Workflow Health

```bash
# Create monitoring script
#!/bin/bash
echo "Workflow Health Check"
echo "===================="

# Recent failures
gh run list --limit 10 --json conclusion,name,createdAt --jq \
  '.[] | select(.conclusion != "success") | "\(.createdAt): \(.name) - \(.conclusion)"'

# Syntax validation
for f in .github/workflows/*.yml; do
  yamllint -d relaxed "$f" >/dev/null 2>&1 || echo "YAML error: $f"
done

# Circular dependencies
echo ""
echo "Workflow Triggers:"
grep -A5 "workflow_run:" .github/workflows/*.yml | grep -E "(File:|workflows:)"
```

## Quick Reference Commands

```bash
# Validate ALL workflows
find .github/workflows -name "*.yml" -exec yamllint -d relaxed {} \;

# List recent runs
gh run list --limit 20

# View failed run logs
gh run view [run-id] --log-failed

# Re-run failed workflow
gh run rerun [run-id]

# Check workflow triggers
grep -A10 "^on:" .github/workflows/*.yml

# Find YAML errors
for f in .github/workflows/*.yml; do
  yamllint "$f" 2>&1 | grep -i error && echo "^^^ $f"
done

# Strip trailing spaces (common issue)
find .github/workflows -name "*.yml" -exec sed -i 's/[[:space:]]*$//' {} \;

# Check for workflow_run loops
grep -B2 -A8 "workflow_run:" .github/workflows/*.yml
```

## Automated Diagnostics Script

Save as `.github/scripts/diagnose-workflows.sh`:

```bash
#!/bin/bash
set -e

echo "=== GitHub Actions Workflow Diagnostics ==="
echo ""

# 1. YAML Validation
echo "1. Validating YAML syntax..."
YAML_ERRORS=0
for file in .github/workflows/*.yml; do
  if ! yamllint -d relaxed "$file" >/dev/null 2>&1; then
    echo "  ❌ YAML ERROR: $file"
    yamllint -d relaxed "$file" 2>&1 | grep -E "(error|syntax)"
    YAML_ERRORS=$((YAML_ERRORS + 1))
  else
    echo "  ✓ $file"
  fi
done

if [ $YAML_ERRORS -gt 0 ]; then
  echo "  ⚠️  Found $YAML_ERRORS files with YAML errors - FIX THESE FIRST"
fi

# 2. Branch Triggers
echo ""
echo "2. Checking workflow triggers..."
for file in .github/workflows/*.yml; do
  echo "  File: $(basename $file)"
  grep -A5 "^on:" "$file" | grep -E "(branches:|pull_request:)" | head -5 | sed 's/^/    /'
done

# 3. Common Issues
echo ""
echo "3. Checking for common issues..."

echo "  - Emoji in names:"
grep -n "name:.*[😀-🙏🚀-🛿]" .github/workflows/*.yml || echo "    None found ✓"

echo "  - Unescaped colons in names:"
grep -n '^name: [^"'\'']*:' .github/workflows/*.yml || echo "    None found ✓"

echo "  - Trailing spaces:"
grep -n "[[:space:]]$" .github/workflows/*.yml | wc -l | xargs echo "    Found lines with trailing spaces:"

echo "  - workflow_run loops:"
grep -c "workflow_run:" .github/workflows/*.yml | grep -v ":0$" | sed 's/:/ has /' | sed 's/$/ workflow_run triggers/' || echo "    None found ✓"

# 4. Recent Runs
echo ""
echo "4. Recent workflow runs:"
if command -v gh &> /dev/null; then
  gh run list --limit 10 --json conclusion,name,status,createdAt --jq \
    '.[] | "\(.createdAt | split("T")[0]) \(.name): \(.conclusion // .status)"'
else
  echo "  gh CLI not installed - install for run history"
fi

echo ""
echo "=== Diagnostics Complete ==="

if [ $YAML_ERRORS -gt 0 ]; then
  echo "⚠️  ACTION REQUIRED: Fix YAML errors before proceeding"
  exit 1
fi
```

Make executable and run:
```bash
chmod +x .github/scripts/diagnose-workflows.sh
./.github/scripts/diagnose-workflows.sh
```

## When to Use This Prompt

Use this prompt when you experience:

- ✅ Workflows suddenly stop appearing on PRs
- ✅ All workflows failing with similar errors
- ✅ Workflows not triggering at all
- ✅ Workflows worked yesterday, broken today
- ✅ After adding/modifying workflow files
- ✅ After renaming branches
- ✅ Circular dependencies suspected
- ✅ YAML parsing errors in Actions tab
- ✅ "Workflow not found" errors
- ✅ Checks required but not running

## Related Prompts

- **test-failure-triage.md** - When tests fail within workflows
- **pr-validation-failures.md** - When PR validation fails
- **troubleshoot-ci-cd.md** - For deeper CI/CD issues
- **use-aitherzero-workflows.md** - For AitherZero-specific commands

## Example Usage

```
@copilot My PR had 5 workflow checks yesterday, now has 0. 
Use github-actions-troubleshoot prompt to diagnose and fix.

Also check if any of my recent commits broke the workflows.
```

Copilot will:
1. Validate YAML in all workflows
2. Identify the breaking commit
3. Show exact syntax errors
4. Provide fix commands
5. Verify workflows work after fix
