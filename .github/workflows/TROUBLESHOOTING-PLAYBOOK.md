# GitHub Actions Troubleshooting Playbook

## Purpose
This playbook provides a systematic approach to diagnosing GitHub Actions workflow issues. Follow the steps in order to quickly identify root causes instead of guessing.

## When to Use This Playbook
- Workflows aren't showing up on PRs
- All checks disappeared suddenly
- Workflows show as "pending" indefinitely
- You see failures but can't find logs
- Workflows were working but stopped

---

## Step 1: Check Workflow Approval Status (Most Common Issue)

**Problem**: Workflows show "action_required" conclusion with 0 jobs executed.

**Quick Check**:
```bash
# Use GitHub CLI to check workflow run status
gh run list --branch YOUR_BRANCH_NAME --limit 5 --json conclusion,status,databaseId

# Or check specific run
gh run view RUN_ID --json conclusion,status,jobs
```

**Signs This Is The Issue**:
- Conclusion: "action_required"
- Status: "completed" (but no jobs ran)
- Jobs count: 0
- PR shows "Waiting for approval" or no checks at all

**Solution**:
1. Go to PR → "Checks" tab
2. Look for "Approve and run" buttons
3. Click to approve each workflow
4. Workflows will start running immediately after approval

**Why This Happens**:
- First-time contributors (bots included)
- Workflow files were modified in the PR
- Repository security settings require approval
- GitHub considers Copilot/automation as "external" contributor

**Prevention**:
- Add automation bot to repository collaborators (if trusted)
- Adjust workflow approval settings in repository settings → Actions → General

---

## Step 2: Verify Workflow Trigger Conditions

**Problem**: Workflow exists but doesn't trigger for your changes.

**Quick Check**:
```bash
# Check what files changed in the PR
git diff --name-only origin/main...HEAD

# Check if any match workflow path filters
cat .github/workflows/YOUR_WORKFLOW.yml | grep -A 10 "paths:"
```

**Common Issues**:
1. **Branch mismatch**:
   ```yaml
   on:
     push:
       branches: ["main", "dev"]  # Won't run on feature branches!
   ```

2. **Path filters exclude your changes**:
   ```yaml
   on:
     pull_request:
       paths:
         - 'src/**'  # Won't run if you only changed docs
   ```

3. **Event type mismatch**:
   ```yaml
   on:
     pull_request:
       types: [opened, synchronize]  # Won't run on "ready_for_review"
   ```

**Solution**:
- Add your branch to the branches list
- Adjust or remove path filters
- Add missing event types
- Consider adding `workflow_dispatch` for manual triggers

---

## Step 3: Check for YAML Syntax Errors

**Problem**: Workflow file has syntax errors preventing it from loading.

**Quick Check**:
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/YOUR_WORKFLOW.yml'))"

# Or use yamllint
yamllint .github/workflows/YOUR_WORKFLOW.yml

# Or use actionlint (if installed)
actionlint .github/workflows/YOUR_WORKFLOW.yml
```

**Common YAML Errors**:
- Unescaped colons in strings
- Incorrect indentation
- Missing quotes around special characters
- Trailing whitespace issues
- Emoji in workflow names (use quotes)

**Solution**:
- Fix YAML syntax errors
- Validate before committing
- Use proper quoting for special characters

---

## Step 4: Check Workflow Concurrency Conflicts

**Problem**: Workflows are being cancelled by concurrency groups.

**Quick Check**:
```bash
# Check workflow for concurrency settings
cat .github/workflows/YOUR_WORKFLOW.yml | grep -A 3 "concurrency:"

# List recent runs to see cancellation pattern
gh run list --workflow YOUR_WORKFLOW.yml --limit 10 --json conclusion,status
```

**Signs This Is The Issue**:
- Multiple runs queued
- Earlier runs show "cancelled"
- Conclusion: "cancelled" in API
- Only latest run executes

**Concurrency Configuration**:
```yaml
concurrency:
  group: workflow-name-${{ github.ref }}
  cancel-in-progress: true  # This cancels older runs
```

**Solution**:
- This is often intentional (to save resources)
- Wait for the latest run to complete
- Adjust concurrency group if needed
- Set `cancel-in-progress: false` if you need all runs

---

## Step 5: Check Required Workflow Dependencies

**Problem**: Workflow is waiting for another workflow to complete.

**Quick Check**:
```bash
# Check if workflow has "needs" dependencies
grep -A 5 "needs:" .github/workflows/YOUR_WORKFLOW.yml

# Check status of dependent workflows
gh run list --branch YOUR_BRANCH --limit 10
```

**Signs This Is The Issue**:
- Workflow shows "pending" status
- Another workflow is failing or hasn't run
- `needs:` keyword in workflow file

**Solution**:
- Fix or approve the dependent workflow first
- Temporarily remove `needs:` for testing
- Check if dependent workflow is disabled

---

## Step 6: Check for "Skipped" Status

**Problem**: Workflow runs but all jobs are skipped.

**Quick Check**:
```bash
# Check for conditional "if" statements
grep -B 2 "if:" .github/workflows/YOUR_WORKFLOW.yml

# View specific run
gh run view RUN_ID
```

**Common Skip Conditions**:
```yaml
jobs:
  my-job:
    if: github.event.pull_request.draft == false  # Skips for draft PRs
    if: github.actor != 'dependabot[bot]'        # Skips for dependabot
    if: contains(github.event.head_commit.message, '[skip ci]')
```

**Solution**:
- Check if PR is in draft mode
- Review `if:` conditions
- Remove or adjust conditions as needed

---

## Step 7: Check Repository Permissions

**Problem**: Workflow needs permissions it doesn't have.

**Quick Check**:
```bash
# Check workflow permissions
cat .github/workflows/YOUR_WORKFLOW.yml | grep -A 5 "permissions:"

# Check repository settings
# Go to: Settings → Actions → General → Workflow permissions
```

**Required Permissions**:
```yaml
permissions:
  contents: read        # For checking out code
  pull-requests: write  # For commenting on PRs
  issues: write         # For creating issues
  checks: write         # For setting status checks
  pages: write          # For deploying to GitHub Pages
```

**Solution**:
- Add required permissions to workflow
- Check repository settings for Actions permissions
- Ensure "Read and write permissions" is enabled if needed

---

## Step 8: Check for Secret/Environment Issues

**Problem**: Workflow fails due to missing secrets or environment approval.

**Quick Check**:
```bash
# Check workflow for secret usage
grep -r "secrets\." .github/workflows/YOUR_WORKFLOW.yml

# Check for environment protection rules
cat .github/workflows/YOUR_WORKFLOW.yml | grep -A 3 "environment:"
```

**Signs This Is The Issue**:
- Job fails immediately
- Error mentions missing secret
- Workflow paused at environment deployment
- "Waiting for environment approval"

**Solution**:
- Add required secrets in repository settings
- Approve environment deployment if prompted
- Check environment protection rules
- Verify secret names match exactly (case-sensitive)

---

## Step 9: Check Workflow Enable/Disable Status

**Problem**: Workflow was disabled manually or automatically.

**Quick Check**:
```bash
# List all workflows and their state
gh workflow list

# Check specific workflow
gh workflow view YOUR_WORKFLOW.yml
```

**Why Workflows Get Disabled**:
- Too many consecutive failures (auto-disabled by GitHub)
- Manually disabled by repository admin
- Workflow file deleted then restored
- Branch inactivity for 60+ days

**Solution**:
```bash
# Re-enable workflow
gh workflow enable YOUR_WORKFLOW.yml

# Or via UI: Actions → Workflows → Select workflow → Enable
```

---

## Step 10: Use the GitHub API for Deep Diagnosis

**When all else fails**, use the API to get detailed information:

```bash
# Get workflow runs with detailed status
gh api repos/OWNER/REPO/actions/runs?branch=BRANCH_NAME \
  --jq '.workflow_runs[] | {name: .name, conclusion: .conclusion, status: .status, jobs_count: .jobs_url}'

# Get specific run details
gh api repos/OWNER/REPO/actions/runs/RUN_ID \
  --jq '{conclusion: .conclusion, status: .status, event: .event}'

# List jobs for a run
gh api repos/OWNER/REPO/actions/runs/RUN_ID/jobs \
  --jq '.jobs[] | {name: .name, conclusion: .conclusion, status: .status}'

# Get job logs (if jobs exist)
gh api repos/OWNER/REPO/actions/jobs/JOB_ID/logs
```

**Key Fields to Check**:
- `conclusion`: null, success, failure, cancelled, skipped, **action_required**
- `status`: queued, in_progress, completed, waiting
- `event`: push, pull_request, workflow_dispatch, etc.
- `jobs_url`: Should have jobs if run actually started

---

## Quick Decision Tree

```
START: Workflows not running on PR
  |
  ├─ Are there ANY workflow runs? 
  │  ├─ NO → Check Step 2 (trigger conditions) & Step 9 (disabled)
  │  └─ YES ↓
  |
  ├─ Do runs show "action_required" conclusion?
  │  ├─ YES → **Step 1: Approve workflows** ← MOST COMMON
  │  └─ NO ↓
  |
  ├─ Do runs show "cancelled" conclusion?
  │  ├─ YES → Step 4 (concurrency conflicts)
  │  └─ NO ↓
  |
  ├─ Do runs show "skipped" or 0 jobs?
  │  ├─ YES → Step 6 (skip conditions) or Step 5 (dependencies)
  │  └─ NO ↓
  |
  ├─ Do runs show "failure"?
  │  ├─ YES → Check logs, Step 8 (secrets), Step 7 (permissions)
  │  └─ NO ↓
  |
  └─ Use Step 10 (API diagnosis) for detailed investigation
```

---

## Common Patterns & Solutions

### Pattern 1: "All checks disappeared after working"
**Diagnosis**: Likely concurrency cancellation or approval needed for new commits  
**Solution**: Check Step 1 (approval) and Step 4 (concurrency)

### Pattern 2: "Workflow works on main but not PR"
**Diagnosis**: Branch or path filters, or first-run approval  
**Solution**: Check Step 2 (triggers) and Step 1 (approval)

### Pattern 3: "Some workflows run, others don't"
**Diagnosis**: Different trigger conditions or individual workflow issues  
**Solution**: Compare trigger conditions, check each workflow separately

### Pattern 4: "Workflows worked yesterday, broken today"
**Diagnosis**: Repository settings changed, or workflow file modified  
**Solution**: Check git history, review recent settings changes

---

## Prevention Checklist

Before committing workflow changes:
- [ ] Validate YAML syntax: `python3 -c "import yaml; yaml.safe_load(open('workflow.yml'))"`
- [ ] Check trigger conditions match your branch/changes
- [ ] Verify required permissions are listed
- [ ] Test with `workflow_dispatch` before relying on automatic triggers
- [ ] Consider approval requirements for bot PRs
- [ ] Document any custom concurrency groups

---

## Emergency Commands

```bash
# Quick status of all workflows on a branch
gh run list --branch BRANCH_NAME --limit 5

# Cancel all running workflows (if stuck)
gh run list --status in_progress --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run cancel {}

# Re-run failed workflows
gh run list --status failure --limit 3 --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run rerun {}

# View workflow file from command line
gh api repos/OWNER/REPO/contents/.github/workflows/WORKFLOW.yml \
  --jq '.content' | base64 -d
```

---

## Getting Help

If this playbook doesn't solve your issue:

1. **Get exact status from API** (Step 10)
2. **Check GitHub Status**: https://www.githubstatus.com/
3. **Search GitHub Community**: Common issues are documented
4. **Review workflow logs**: Even failed runs have setup logs

Remember: **Start with Step 1** - approval issues are the #1 cause of "missing" workflows!

---

**Last Updated**: 2025-11-05  
**Maintainer**: AitherZero Team  
**Related Docs**: 
- `.github/prompts/github-actions-troubleshoot.md` - One-shot troubleshooting prompt
- `.github/prompts/troubleshoot-ci-cd.md` - CI/CD specific issues
- `docs/CI-CD-GUIDE.md` - Comprehensive CI/CD documentation
