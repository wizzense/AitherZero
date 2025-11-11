# Workflow Concurrency Fix

## Problem
The PR validation workflow (02-pr-validation-build.yml) was not running because of conflicting concurrency groups causing workflows to cancel each other.

## Root Cause
When the master orchestrator (01-master-orchestrator.yml) calls the PR validation workflow via `workflow_call`, both workflows had their own concurrency groups with `cancel-in-progress: true`:

1. **Orchestrator**: `group: orchestrator-${{ github.event.pull_request.number }}` with `cancel-in-progress: true`
2. **PR Validation**: `group: pr-ecosystem-${{ github.event.pull_request.number }}` with `cancel-in-progress: true`

This caused the workflows to compete and cancel each other, preventing the PR validation workflow from completing.

## Solution
**Removed concurrency groups from called workflows** (workflow_call):
- ✅ `02-pr-validation-build.yml` - Removed concurrency group (called by orchestrator)
- ✅ `20-release-automation.yml` - Added workflow_call trigger and removed concurrency group

**Kept concurrency group in orchestrator**:
- ✅ `01-master-orchestrator.yml` - Controls all concurrency at the top level

## Best Practice
For GitHub Actions workflows:
- **Calling workflows** (that use `workflow_call`) should **NOT** have concurrency groups
- **Master orchestrator** workflows should have the concurrency group
- This prevents nested concurrency conflicts and ensures proper workflow coordination

## Files Changed
1. `.github/workflows/02-pr-validation-build.yml`
   - Removed `concurrency` section
   - Added comment explaining orchestrator controls concurrency

2. `.github/workflows/20-release-automation.yml`
   - Added `workflow_call` trigger
   - Added comment explaining orchestrator controls concurrency

## Testing
After this fix:
- PR validation workflow should run to completion when orchestrator calls it
- No more premature cancellations due to concurrency conflicts
- Proper workflow coordination through the master orchestrator

## Additional Notes
Other workflows that use `workflow_call`:
- None currently - only 02-pr-validation-build.yml was designed for workflow_call
- 20-release-automation.yml now also supports workflow_call

Workflows with concurrency groups (standalone):
- `03-test-execution.yml` - Independent test workflow
- `04-deploy-pr-environment.yml` - Independent deployment (cancel-in-progress: false)
- `05-publish-reports-dashboard.yml` - Independent publishing (cancel-in-progress: false)
- `06-documentation.yml` - Independent docs generation
- `07-indexes.yml` - Independent indexing
- `08-update-pr-title.yml` - Independent title update (cancel-in-progress: false)
- `10-module-validation-performance.yml` - Independent module validation
- `30-ring-status-dashboard.yml` - Independent ring status

These are all independent workflows that don't conflict with the orchestrator.
