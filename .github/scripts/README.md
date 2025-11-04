# GitHub Scripts README

## Overview
This directory contains JavaScript scripts used by GitHub Actions workflows for enhanced reporting and automation.

## Scripts

### generate-test-comment.js
Generates detailed PR comments for parallel test execution results.

**Key Features:**
- Aggregates test results from multiple parallel jobs
- Shows job-level status with accurate failure detection
- Displays test metrics (passed, failed, skipped counts)
- Provides links to detailed logs and artifacts

**Important Implementation Details:**

The script correctly handles jobs with `continue-on-error: true` by checking step conclusions from the GitHub REST API instead of job conclusions:

```javascript
// When continue-on-error is true:
// - job.conclusion will be 'success' even if tests fail
// - step.conclusion will correctly reflect 'failure'
// We use step.conclusion for accurate status reporting
// Note: GitHub REST API exposes 'conclusion' and 'status' for steps, not 'outcome'
```

This ensures that failed tests are properly marked as "❌ FAILED" in PR comments even when the workflow continues execution.

### test-generate-comment.js
Test suite for `generate-test-comment.js` to verify correct status reporting logic.

**What it tests:**
- Jobs with `continue-on-error: true` and failing tests show as FAILED
- Jobs with passing tests show as PASSED
- Warning section appears when there are failures
- Failure counts are accurate

**Run the test:**
```bash
cd .github/scripts
node test-generate-comment.js
```

## Workflow Integration

### parallel-testing.yml
The parallel testing workflow uses `generate-test-comment.js` to create PR comments:

```yaml
- name: 💬 Comment on PR
  uses: actions/github-script@v7
  with:
    script: |
      const script = require('./.github/scripts/generate-test-comment.js');
      return await script({github, context, core});
```

## Troubleshooting

### Issue: All jobs show as PASSED even with test failures

**Cause:** Jobs use `continue-on-error: true`, causing `job.conclusion` to be 'success' even when tests fail.

**Solution:** The script now checks `step.conclusion` from job steps (via GitHub REST API) to get the actual test result. Note that the API exposes `step.conclusion` and `step.status`, not `step.outcome` (which only exists in workflow context).

### Issue: Failed jobs not appearing in summary

**Cause:** The `failedJobs` filter was using `job.conclusion` instead of `job.actualOutcome`.

**Solution:** Updated to use `job.actualOutcome` which correctly reflects step failures from the REST API.

## Development

### Adding New Job Types

To add support for a new job type in the comment:

1. Add the job to the appropriate array (`unitTests`, `domainTests`, etc.)
2. Update the step name matching logic to include your new job's test step name
3. Add a section builder similar to `unitSection`, `domainSection`, etc.
4. Update the test to verify your new job type is handled correctly

### Testing Changes

Always run `test-generate-comment.js` after making changes to `generate-test-comment.js`:

```bash
node test-generate-comment.js
```

Expected output:
```
✅ All tests passed!
```

## References

- [GitHub Actions API - List Jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run)
- [GitHub Actions - continue-on-error](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepscontinue-on-error)
