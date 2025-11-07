# Workflow Token Setup Guide

## Problem: Bot Commits Don't Trigger Workflows

By default, when a GitHub Actions workflow commits changes using `GITHUB_TOKEN`, those commits **do not trigger other workflows**. This is a GitHub Actions security feature to prevent infinite workflow loops.

### Affected Workflows

The following workflows commit changes back to the PR branch and need to trigger other workflows:
- `index-automation.yml` - Auto-generates project index files
- `auto-generate-tests.yml` - Auto-generates test files for new scripts  
- `validate-test-sync.yml` - Removes orphaned test files

## Solution: Use Personal Access Token (PAT)

To allow bot commits to trigger workflows, you need to configure a **Personal Access Token (PAT)** with the `workflow` scope.

### Step 1: Create a Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token" → "Generate new token (classic)"
3. Configure the token:
   - **Name**: `AitherZero Workflow Token`
   - **Expiration**: Choose appropriate expiration (recommend 90 days with calendar reminder)
   - **Select scopes**:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows) **← REQUIRED**
4. Click "Generate token"
5. **Copy the token immediately** (you won't be able to see it again!)

### Step 2: Add Token to Repository Secrets

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Configure the secret:
   - **Name**: `PAT_WITH_WORKFLOW_SCOPE`
   - **Secret**: Paste the PAT you created
4. Click "Add secret"

### Step 3: Verify Setup

After adding the secret, the workflows will automatically use it. To verify:

1. Make a change that would trigger one of the workflows (e.g., add a new automation script)
2. Create a PR
3. The workflow should:
   - Generate files (tests, indexes, etc.)
   - Commit them to the PR
   - **Trigger other workflows** (checks should appear on the PR)

If checks appear, the setup is working correctly! ✅

## Fallback Behavior

The workflows are configured to fall back gracefully:
```yaml
token: ${{ secrets.PAT_WITH_WORKFLOW_SCOPE || secrets.GITHUB_TOKEN }}
```

- **If PAT is configured**: Bot commits trigger workflows ✅
- **If PAT is missing**: Bot commits DON'T trigger workflows ⚠️ (but workflows still run and commit)

## Security Considerations

### Why is this safe?

1. **Scoped permissions**: The PAT only has `repo` and `workflow` scopes
2. **Repository secret**: Only accessible to workflows in this repository
3. **Audit trail**: All commits are attributed to github-actions[bot]
4. **Manual review**: PRs still require approval before merge

### Best Practices

1. **Use fine-grained PAT** (when available for workflow scope) for even better security
2. **Set expiration**: Use 90-day expiration with calendar reminder to rotate
3. **Restrict access**: Only repository admins should have access to manage secrets
4. **Audit regularly**: Review Actions tab to ensure workflows behave as expected

## Troubleshooting

### Problem: Checks still show 0 after bot commit

**Cause**: PAT not configured or expired

**Solution**:
1. Verify secret exists: Settings → Secrets → Actions → `PAT_WITH_WORKFLOW_SCOPE`
2. Check token expiration (GitHub will email you before expiration)
3. Regenerate token if expired and update secret

### Problem: Infinite workflow loops

**Cause**: Workflow triggers on its own commits

**Solution**: The workflows already have proper concurrency control:
```yaml
concurrency:
  group: workflow-name-${{ github.ref }}
  cancel-in-progress: true
```

This prevents multiple runs of the same workflow on the same branch.

### Problem: Workflows fail with permission errors

**Cause**: PAT missing required scopes

**Solution**: Verify PAT has both `repo` and `workflow` scopes enabled

## Alternative: GitHub App

For organizations, consider using a GitHub App instead of a PAT:
- Better security model
- Automatic token rotation
- Fine-grained permissions
- No user dependency

See: https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps

## References

- [Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request)
- [Triggering a workflow from a workflow](https://docs.github.com/en/actions/using-workflows/triggering-a-workflow#triggering-a-workflow-from-a-workflow)
- [Automatic token authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#using-the-github_token-in-a-workflow)
