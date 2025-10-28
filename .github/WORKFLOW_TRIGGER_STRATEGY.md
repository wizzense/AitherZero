# GitHub Actions Workflow Trigger Strategy

## Problem: Duplicate CI Runs on PR Updates

When a Pull Request is updated with new commits, GitHub triggers **both** events:
1. `push` event - because commits are pushed to the PR branch
2. `pull_request` event (type: `synchronize`) - because the PR was updated

This causes workflows configured with both triggers to run **twice simultaneously** for the same code changes, wasting CI resources and creating confusion with duplicate check runs.

### Example Symptoms
When a PR is updated, you'll see duplicate runs in the GitHub Actions UI:
- ✅ Intelligent CI Orchestrator / 🔍 Core Validation (pull_request) - Running
- ✅ Intelligent CI Orchestrator / 🔍 Core Validation (push) - Queued

Both are testing the exact same code, but triggered by different events.

## Solution: Branch-Restricted Push Triggers

To prevent duplicate runs, we restrict the `push` trigger to **only base branches** (main, develop) that don't have PRs:

```yaml
on:
  push:
    # Only run on base branches to avoid duplicate runs with pull_request events
    # Feature branches and copilot branches are tested via pull_request event
    branches: [main, develop]
    paths-ignore:
      - '**.md'
      - 'docs/**'
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

### How This Works

1. **For Feature/Copilot Branches (PR workflow)**:
   - Push to `feature/my-feature` → No push trigger (not in branches list)
   - Create PR → `pull_request` event triggers workflow ✅
   - Push more commits → `pull_request` event (synchronize) ✅
   - Result: **Single run per update**

2. **For Direct Commits to Main/Develop**:
   - Push to `main` → `push` event triggers workflow ✅
   - No PR involved → No pull_request event
   - Result: **Single run for direct commits**

3. **For PRs to Main/Develop**:
   - PR from `feature/X` to `main` → `pull_request` event ✅
   - Push event doesn't fire (source branch not in push branches list)
   - Result: **Single run per PR update**

## Implemented Workflows

This strategy is implemented in the following workflows:

- ✅ `intelligent-ci-orchestrator.yml` - Main CI/CD pipeline
- ✅ `validate-config.yml` - Config manifest validation
- ✅ `validate-manifests.yml` - PowerShell module manifest validation
- ℹ️ `documentation-automation.yml` - Already correctly configured

## Alternative Approaches (Not Used)

### Job-Level Conditions
```yaml
jobs:
  my-job:
    if: github.event_name != 'push' || github.event.pull_request == null
```
**Rejected**: More complex, harder to understand, doesn't prevent workflow from starting

### Concurrency Groups
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.head_ref || github.run_id }}
  cancel-in-progress: true
```
**Rejected**: Cancels one run but both still start, consuming resources and creating confusion

## Verification

To verify this strategy is working:
1. Create a test PR from a feature branch
2. Push a new commit to the PR branch
3. Check GitHub Actions runs - should see only `(pull_request)` runs, no `(push)` runs
4. Push directly to `main` or `develop` (if allowed) - should see only `(push)` runs

## References

- [GitHub Actions: Events that trigger workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- [GitHub Actions: Workflow syntax - on.push.branches](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushbranchestagsbranches-ignoretags-ignore)
- [GitHub Community: Avoiding duplicate workflows](https://github.com/orgs/community/discussions/26940)
