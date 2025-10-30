# Test Scenarios for Automated Doc/Index Updates

## Test Case 1: PR with Documentation Changes

### Setup
1. Create a feature branch from `develop`
2. Modify a PowerShell function that affects documentation
3. Create a PR targeting `develop`

### Expected Behavior
1. `documentation-automation.yml` workflow runs
2. If doc changes detected:
   - Creates branch `auto-docs/<pr-number>`
   - Commits doc changes to that branch
   - Creates PR from `auto-docs/<pr-number>` → `feature-branch`
   - Adds comment to original PR with link
3. If no changes:
   - Adds comment saying "No changes needed"

### Validation
- [ ] Auto-docs branch created
- [ ] Auto-docs PR created with correct base (feature branch, not main)
- [ ] Commit message includes "[auto-generated]" tag
- [ ] Original PR has comment with link to auto-docs PR
- [ ] Auto-docs PR has labels: `documentation`, `automated`, `auto-docs`

## Test Case 2: PR with Index Changes

### Setup
1. Create a feature branch from `develop`
2. Add/modify files in a directory that affects indexes
3. Create a PR targeting `develop`

### Expected Behavior
1. `index-automation.yml` workflow runs
2. If index changes detected:
   - Creates branch `auto-index/<pr-number>`
   - Commits index changes to that branch
   - Creates PR from `auto-index/<pr-number>` → `feature-branch`
   - Adds comment to original PR with link
3. If no changes:
   - Adds comment saying "No changes needed"

### Validation
- [ ] Auto-index branch created
- [ ] Auto-index PR created with correct base
- [ ] Commit message includes "[auto-generated]" tag
- [ ] Original PR has comment with link to auto-index PR
- [ ] Auto-index PR has labels: `documentation`, `automated`, `auto-index`

## Test Case 3: PR with Both Doc and Index Changes

### Setup
1. Create a feature branch
2. Make changes that affect both documentation and indexes
3. Create a PR

### Expected Behavior
1. Both workflows run in parallel
2. Two separate auto PRs created:
   - `auto-docs/<pr-number>` → `feature-branch`
   - `auto-index/<pr-number>` → `feature-branch`
3. Both PRs linked in comments on original PR

### Validation
- [ ] Two separate auto PRs created
- [ ] No conflicts between the two auto PRs
- [ ] Both can be merged independently
- [ ] Original PR receives two comments (one for each)

## Test Case 4: Re-running Workflow

### Setup
1. Create PR with changes
2. Auto PR created
3. Make more changes to feature branch
4. Re-run the automation workflow

### Expected Behavior
1. Workflow detects existing auto PR
2. Deletes old auto branch
3. Creates fresh auto branch from new HEAD
4. Updates existing auto PR (or creates new one)

### Validation
- [ ] Only one auto PR exists per type (docs/index)
- [ ] Auto PR is based on latest commit
- [ ] No duplicate branches or PRs

## Test Case 5: No Changes Detected

### Setup
1. Create PR without any documentation or index-affecting changes
2. Let workflows run

### Expected Behavior
1. Workflows run successfully
2. No auto branches created
3. No auto PRs created
4. Comment added to PR: "No changes needed"

### Validation
- [ ] No auto-docs or auto-index branches exist
- [ ] No auto PRs created
- [ ] Appropriate "no changes" comment added
- [ ] Workflow completes successfully (not failed)

## Test Case 6: Merge Auto PR

### Setup
1. Create feature PR with auto PRs created
2. Review and approve auto PRs
3. Merge auto PRs into feature branch

### Expected Behavior
1. Auto PR merges successfully
2. Feature branch now has automated commits
3. Auto branch is deleted
4. Original PR is updated with new commits

### Validation
- [ ] Feature branch contains auto-generated commits
- [ ] Auto branches are cleaned up
- [ ] Commit history shows proper attribution (github-actions[bot])
- [ ] Auto PRs are marked as merged

## Test Case 7: Close Original PR

### Setup
1. Create feature PR with auto PRs
2. Close the original PR without merging

### Expected Behavior
1. Auto PRs should ideally be closed automatically
2. Auto branches can be manually cleaned up

### Validation
- [ ] Auto branches can be safely deleted
- [ ] No orphaned PRs remain
- [ ] Workflow doesn't error on closed PR

## Test Case 8: Direct Push to Main

### Setup
1. Push changes directly to `main` branch

### Expected Behavior
1. Workflows run in "Full" mode
2. No auto PRs created (not a PR event)
3. Changes detected and reported in workflow logs

### Validation
- [ ] Workflow completes successfully
- [ ] No auto branches/PRs created
- [ ] Appropriate artifacts uploaded

## YAML Validation Tests

### Test 1: YAML Syntax
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/index-automation.yml'))"
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/documentation-automation.yml'))"
```

Expected: No errors

### Test 2: GitHub Actions Validation
```bash
# If actionlint is available
actionlint .github/workflows/index-automation.yml
actionlint .github/workflows/documentation-automation.yml
```

Expected: No critical errors

## Integration Tests

### Test with Local Act (GitHub Actions locally)

```bash
# Install act if not available
# Test index automation
act pull_request -W .github/workflows/index-automation.yml

# Test documentation automation
act pull_request -W .github/workflows/documentation-automation.yml
```

## Manual Testing Checklist

Before marking implementation as complete:

- [ ] Created test PR in a fork/test repo
- [ ] Verified auto-docs branch creation
- [ ] Verified auto-index branch creation
- [ ] Verified PR creation with correct base
- [ ] Verified commit messages format
- [ ] Verified labels applied correctly
- [ ] Verified comments added to original PR
- [ ] Tested merging auto PRs
- [ ] Tested re-running workflow
- [ ] Tested "no changes" scenario
- [ ] Verified YAML syntax is valid
- [ ] Checked workflow logs for errors

## Known Limitations

1. **Branch Permissions**: Requires `contents: write` permission
2. **PR Permissions**: Requires `pull-requests: write` permission
3. **Re-run Behavior**: Old auto branches are deleted and recreated
4. **Manual Cleanup**: Auto branches may need manual cleanup if PR is closed
5. **Nested PRs**: Auto PRs are PRs to feature branches, not to main

## Future Enhancements

- [ ] Auto-merge auto PRs when all checks pass
- [ ] Auto-close auto PRs when parent PR is closed
- [ ] Add GitHub Status Check for auto PR state
- [ ] Notification when auto PRs are ready for review
- [ ] Dashboard showing all active auto PRs
