# Workflow Error Handling Best Practices

This document describes the standardized error handling patterns for GitHub Actions workflows in AitherZero.

## Problem Statement

Previously, workflows used `continue-on-error: true` extensively, which masked failures and caused workflows to report "success" even when critical steps failed. This made it difficult to:

- Identify when builds actually failed
- Debug CI/CD issues
- Trust workflow check statuses
- Understand which steps failed

## Solution

We now use explicit exit code checking and proper error propagation while still allowing workflows to collect complete results.

## Error Handling Patterns

### Pattern 1: Critical Steps (Must Fail Workflow on Error)

Use this pattern for validation, build, and test steps where failures must fail the workflow.

```yaml
- name: 🔨 Critical Step
  id: critical
  shell: pwsh
  run: |
    # Track failures but continue to collect all results
    $failedSteps = @()
    $ErrorActionPreference = 'Continue'
    
    # Run first script
    Write-Host "Running script 1..." -ForegroundColor Cyan
    & "./script1.ps1"
    if ($LASTEXITCODE -ne 0) {
      Write-Host "⚠️ Script 1 failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
      $failedSteps += "Script 1"
    }
    
    # Run second script (even if first failed)
    Write-Host "`nRunning script 2..." -ForegroundColor Cyan
    & "./script2.ps1"
    if ($LASTEXITCODE -ne 0) {
      Write-Host "⚠️ Script 2 failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
      $failedSteps += "Script 2"
    }
    
    # Report final status
    if ($failedSteps.Count -gt 0) {
      Write-Host "`n❌ Step completed with failures:" -ForegroundColor Red
      foreach ($step in $failedSteps) {
        Write-Host "  - $step" -ForegroundColor Red
      }
      exit 1  # Fail the workflow
    } else {
      Write-Host "`n✅ All scripts succeeded" -ForegroundColor Green
      exit 0
    }
```

**Key Points:**
- Sets `$ErrorActionPreference = 'Continue'` to continue on errors
- Tracks failures in `$failedSteps` array
- Checks `$LASTEXITCODE` after each script call
- Reports all failures at the end
- Exits with code 1 if any failures occurred
- **NO `continue-on-error: true` in YAML**

### Pattern 2: Optional Steps (Continue on Error)

Use this pattern for optional steps like coverage reports or artifact downloads where failures shouldn't fail the workflow.

```yaml
- name: 📊 Optional Step
  id: optional
  shell: pwsh
  continue-on-error: true  # OK for optional steps
  run: |
    Write-Host "Running optional step..." -ForegroundColor Cyan
    
    & "./optional-script.ps1"
    if ($LASTEXITCODE -eq 0) {
      Write-Host "✅ Optional step succeeded" -ForegroundColor Green
    } else {
      Write-Host "⚠️ Optional step failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
      Write-Host "Continuing workflow..." -ForegroundColor Yellow
    }
    # No exit - workflow continues regardless
```

**Key Points:**
- `continue-on-error: true` is acceptable here
- Still checks `$LASTEXITCODE` and reports status
- Warns on failure but doesn't exit
- Workflow continues regardless of outcome

### Pattern 3: Best-Effort Steps (Try but Don't Fail)

Use this pattern for dashboard generation or artifact collection where we want partial results.

```yaml
- name: 📊 Best-Effort Step
  id: best-effort
  shell: pwsh
  run: |
    $failedSteps = @()
    $ErrorActionPreference = 'Continue'
    
    try {
      Invoke-PlaybookStep1
      Write-Host "✅ Step 1 completed" -ForegroundColor Green
    } catch {
      Write-Host "⚠️ Step 1 failed: $_" -ForegroundColor Yellow
      $failedSteps += "Step 1"
    }
    
    try {
      Invoke-PlaybookStep2
      Write-Host "✅ Step 2 completed" -ForegroundColor Green
    } catch {
      Write-Host "⚠️ Step 2 failed: $_" -ForegroundColor Yellow
      $failedSteps += "Step 2"
    }
    
    # Report warnings but don't fail
    if ($failedSteps.Count -gt 0) {
      Write-Host "`n⚠️ Completed with warnings:" -ForegroundColor Yellow
      foreach ($step in $failedSteps) {
        Write-Host "  - $step" -ForegroundColor Yellow
      }
      Write-Host "`n✅ Partial results generated" -ForegroundColor Green
    } else {
      Write-Host "`n✅ All steps completed successfully" -ForegroundColor Green
    }
    exit 0  # Always succeed - best effort
```

**Key Points:**
- Uses try/catch for PowerShell cmdlets
- Tracks warnings but doesn't fail
- Always exits with 0 (success)
- Provides partial results

## Status Reporting in Comments

When posting status comments to PRs, use accurate status indicators:

```yaml
- name: 💬 Post Status
  if: always()
  uses: actions/github-script@v7
  with:
    script: |
      const status = '${{ steps.critical.outcome }}';
      const icon = status === 'success' ? '✅' : '❌';
      const statusText = status === 'success' ? 'PASSED' : 'FAILED';
      
      github.rest.issues.createComment({
        issue_number: process.env.PR_NUMBER,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `${icon} **Step ${statusText}**`
      });
```

**Status Icons:**
- ✅ Success - Everything passed
- ❌ Failed - Critical failure  
- ⚠️ Warning - Non-critical issue (optional steps only)
- ℹ️ Info - Informational message (not for test/build results)

**DO NOT USE:**
- ⚠️ or ℹ️ for actual test/build failures
- "COMPLETED WITH ISSUES" when tests actually failed
- "COMPLETED" when the step failed

## Testing the Workflow

### Validate YAML Syntax

```bash
# Validate all workflow files
for file in .github/workflows/*.yml; do
  echo "=== Checking $file ==="
  python3 -c "import yaml; yaml.safe_load(open('$file'))" && echo "✅ Valid" || echo "❌ Invalid"
done
```

### Test Script Execution Locally

```bash
# Test individual scripts
pwsh -Command "Import-Module ./AitherZero.psd1 -Force; ./library/automation-scripts/0902_Create-ReleasePackage.ps1 -PackageFormat Both -OnlyRuntime"

# Check exit code
echo "Exit code: $?"
```

### Verify Exit Code Propagation

```powershell
# In PowerShell workflow steps:
& "./script.ps1"
Write-Host "Exit code: $LASTEXITCODE"

# Should be:
# 0 = Success
# 1 = Failure
# Non-zero = Error
```

## Common Mistakes to Avoid

### ❌ Don't: Use continue-on-error for critical steps

```yaml
- name: 🧪 Run Tests
  continue-on-error: true  # ❌ WRONG - masks test failures!
  run: ./run-tests.ps1
```

### ❌ Don't: Ignore exit codes

```yaml
- name: 🔨 Build
  run: |
    ./build.ps1
    echo "Done"  # ❌ WRONG - no exit code check!
```

### ❌ Don't: Use wrong status icons

```yaml
const icon = status === 'success' ? '✅' : 'ℹ️';  # ❌ WRONG - use ❌ for failures!
```

### ✅ Do: Check exit codes and fail properly

```yaml
- name: 🧪 Run Tests
  run: |
    ./run-tests.ps1
    if ($LASTEXITCODE -ne 0) {
      Write-Host "❌ Tests failed" -ForegroundColor Red
      exit 1
    }
```

## Exit Code Standards

All automation scripts should use these exit codes:

- **0** - Success (everything worked)
- **1** - Failure (operation failed, tests failed, validation failed)
- **2** - Error (execution error, exception, invalid parameters)
- **3010** - Restart required (Windows-specific)

## Real-World Examples

See these workflows for complete examples:

- **02-pr-validation-build.yml** - Critical steps with proper error handling
- **03-test-execution.yml** - Test execution with failure tracking
- **05-publish-reports-dashboard.yml** - Best-effort and optional steps

## Summary

| Pattern | Use When | continue-on-error | Exit Handling | Workflow Fails |
|---------|----------|-------------------|---------------|----------------|
| **Critical** | Tests, build, validation | ❌ No | Check $LASTEXITCODE, exit 1 on failure | ✅ Yes |
| **Optional** | Coverage, artifacts | ✅ Yes | Check $LASTEXITCODE, report only | ❌ No |
| **Best-Effort** | Dashboards, reports | ❌ No | Try/catch, always exit 0 | ❌ No |

## Key Takeaways

1. **Remove `continue-on-error` from critical steps** - Let failures fail the workflow
2. **Always check `$LASTEXITCODE`** - Never assume scripts succeeded
3. **Track failures** - Use arrays to collect all failures before reporting
4. **Exit properly** - Use `exit 1` for failures, `exit 0` for success
5. **Report accurately** - Use ❌ for failures, ✅ for success
6. **Continue processing** - Set `$ErrorActionPreference = 'Continue'` to collect all results

---

*Last Updated: 2025-11-10*
*Related Issue: Workflow failure detection and proper error reporting*
