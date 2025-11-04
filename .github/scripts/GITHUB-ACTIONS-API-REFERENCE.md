# GitHub Actions API Field Reference

This document explains the differences between fields available in GitHub Actions workflows vs. the GitHub REST API, particularly focusing on job and step status fields.

## Key Distinction: Workflow Context vs. REST API

GitHub Actions has **two different contexts** where you interact with job and step data:

1. **Workflow Context** (inside workflow YAML files)
2. **REST API** (when calling GitHub API endpoints)

These contexts expose **different fields**, which can cause confusion.

## Workflow Context vs REST API Fields

### In Workflow YAML (`${{ }}` expressions)

When you reference steps in workflow expressions, you can use:

```yaml
steps:
  - id: my-step
    run: exit 1
    continue-on-error: true
    
  - name: Check status
    if: steps.my-step.outcome == 'failure'  # ✅ 'outcome' exists here
    run: echo "Step failed but workflow continues"
```

**Available fields in workflow context:**
- `steps.<id>.outcome` - Raw result before error handling
- `steps.<id>.conclusion` - Final result after error handling
- `steps.<id>.outputs.<name>` - Step outputs

### In REST API Responses

When you call `listJobsForWorkflowRun` or similar API endpoints, the step objects have:

```javascript
const jobs = await github.rest.actions.listJobsForWorkflowRun({
  owner: 'owner',
  repo: 'repo',
  run_id: 12345
});

// Each job has a 'steps' array:
for (const job of jobs.data.jobs) {
  for (const step of job.steps) {
    console.log(step.name);
    console.log(step.conclusion);  // ✅ 'conclusion' exists in API
    console.log(step.status);      // ✅ 'status' exists in API
    console.log(step.outcome);     // ❌ 'outcome' does NOT exist in API
  }
}
```

**Available fields in REST API:**
- `step.name` - Step name
- `step.status` - Execution status: `queued`, `in_progress`, `completed`
- `step.conclusion` - Final result: `success`, `failure`, `cancelled`, `skipped`, `timed_out`, etc.
- `step.number` - Step sequence number
- `step.started_at` - ISO timestamp
- `step.completed_at` - ISO timestamp

**NOT available in REST API:**
- ❌ `step.outcome` - This field only exists in workflow context!

## The Difference: outcome vs conclusion

### In Workflow Context

Both `outcome` and `conclusion` exist, with different meanings:

- **`outcome`**: The raw result of the step **before** any error handling
- **`conclusion`**: The final result **after** considering error handling like `continue-on-error`

**Example with `continue-on-error: true`:**

```yaml
steps:
  - id: failing-step
    run: exit 1
    continue-on-error: true
    
  - run: echo "outcome is ${{ steps.failing-step.outcome }}"      # "failure"
  - run: echo "conclusion is ${{ steps.failing-step.conclusion }}" # "success"
```

The step failed (`outcome: failure`), but due to `continue-on-error`, the workflow treats it as success (`conclusion: success`).

### In REST API

Only `conclusion` exists (no `outcome`):

```javascript
// After a step with continue-on-error: true fails:
{
  name: "Failing Step",
  status: "completed",
  conclusion: "success"  // Reflects error handling - appears as success
}
```

**The API's `conclusion` field reflects the same value as workflow context's `conclusion`**, which includes error handling.

## Common Mistake: Checking for `step.outcome` in API Code

**❌ WRONG - This will never work:**

```javascript
const jobs = await github.rest.actions.listJobsForWorkflowRun({...});

for (const job of jobs.data.jobs) {
  const step = job.steps.find(s => s.name === 'Run Tests');
  
  // BUG: 'outcome' doesn't exist in API response!
  if (step && step.outcome) {  
    console.log(step.outcome);  // Always undefined
  }
}
```

**✅ CORRECT - Use `conclusion` instead:**

```javascript
const jobs = await github.rest.actions.listJobsForWorkflowRun({...});

for (const job of jobs.data.jobs) {
  const step = job.steps.find(s => s.name === 'Run Tests');
  
  // Use 'conclusion' which exists in API response
  if (step && step.conclusion) {  
    console.log(step.conclusion);  // "success", "failure", etc.
  }
}
```

## Detecting Actual Failures with continue-on-error

When a job uses `continue-on-error: true`, the **job-level** `conclusion` will be `"success"` even if tests fail. To detect actual test failures:

**❌ WRONG - Only checks job conclusion:**

```javascript
for (const job of jobs.data.jobs) {
  if (job.conclusion === 'success') {
    console.log('PASSED');  // Wrong! Could have failed tests
  }
}
```

**✅ CORRECT - Check step conclusion:**

```javascript
for (const job of jobs.data.jobs) {
  let actualStatus = job.conclusion;
  
  // Find the actual test step
  const testStep = job.steps.find(s => s.name.includes('Run Tests'));
  
  // Use step's conclusion, which reflects actual test result
  if (testStep && testStep.conclusion) {
    actualStatus = testStep.conclusion;  // Use this instead of job.conclusion
  }
  
  if (actualStatus === 'failure') {
    console.log('FAILED');  // Correctly detects failure!
  }
}
```

## Summary Table

| Field | Workflow Context | REST API | Use Case |
|-------|-----------------|----------|----------|
| `job.conclusion` | ✅ Yes | ✅ Yes | Job-level result (affected by `continue-on-error`) |
| `job.status` | ✅ Yes | ✅ Yes | Job execution state (`completed`, `in_progress`, etc.) |
| `step.outcome` | ✅ Yes | ❌ **NO** | Raw step result (workflow context only) |
| `step.conclusion` | ✅ Yes | ✅ Yes | Final step result (includes error handling) |
| `step.status` | ✅ Yes | ✅ Yes | Step execution state |

## Best Practices

### ✅ DO:
- Use `step.conclusion` when working with REST API responses
- Check step-level conclusions to detect actual test failures
- Use `step.status` to check if a step is still running
- Reference GitHub's REST API documentation for exact field names

### ❌ DON'T:
- Try to access `step.outcome` from API responses (it doesn't exist)
- Rely only on `job.conclusion` when jobs use `continue-on-error`
- Assume workflow context and API context have the same fields
- Mix up `outcome` (workflow only) with `conclusion` (both contexts)

## References

- [GitHub Actions Runner ADR 0274: Step outcome and conclusion](https://github.com/actions/runner/blob/main/docs/adrs/0274-step-outcome-and-conclusion.md)
- [GitHub REST API - Workflow Jobs](https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run)
- [GitHub Actions Context - steps context](https://docs.github.com/en/actions/learn-github-actions/contexts#steps-context)
- [GitHub Actions - continue-on-error](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepscontinue-on-error)

## Real-World Example: Test Status Detection

This exact issue occurred in our parallel testing workflow:

**The Bug:**
```javascript
// Checked for 'outcome' which doesn't exist in API
if (runTestsStep && runTestsStep.outcome) {
  actualOutcome = runTestsStep.outcome;  // Always undefined!
}
// Always fell back to job.conclusion, which was 'success' due to continue-on-error
```

**The Fix:**
```javascript
// Use 'conclusion' which exists in API
if (runTestsStep && runTestsStep.conclusion) {
  actualOutcome = runTestsStep.conclusion;  // Now correctly gets 'failure'!
}
// Properly detects test failures even with continue-on-error
```

**Result:** Failed tests are now properly surfaced in PR comments instead of showing all jobs as PASSED.

---

**Last Updated:** 2025-11-04  
**Related Files:** 
- `.github/scripts/generate-test-comment.js` - Uses this API correctly
- `.github/scripts/test-generate-comment.js` - Tests with correct field names
