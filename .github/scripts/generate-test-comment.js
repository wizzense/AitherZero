// Generate detailed PR comment for parallel test execution
// This script is called from parallel-testing.yml workflow

module.exports = async ({github, context, core}) => {
  // Parse as integers - core.getInput returns strings
  const passed = parseInt(core.getInput('passed') || '0', 10);
  const failed = parseInt(core.getInput('failed') || '0', 10);
  const skipped = parseInt(core.getInput('skipped') || '0', 10);
  
  // Debug logging
  console.log(`📊 Test Results: Passed=${passed}, Failed=${failed}, Skipped=${skipped}`);
  
  const status = failed > 0 ? 'TESTS FAILED' : 'ALL TESTS PASSED';
  const statusIcon = failed > 0 ? '❌' : '✅';
  const color = failed > 0 ? '🔴' : '🟢';
  
  // Get all workflow jobs to show detailed status
  const jobs = await github.rest.actions.listJobsForWorkflowRun({
    owner: context.repo.owner,
    repo: context.repo.repo,
    run_id: context.runId
  });
  
  // Step name patterns for test execution steps
  // Add new patterns here when introducing new test job types
  const TEST_STEP_PATTERNS = [
    'Run Unit Tests',
    'Run Domain Tests',
    'Run Integration Tests'
  ];
  
  // Organize jobs by type
  const unitTests = [];
  const domainTests = [];
  const integrationTests = [];
  const staticAnalysis = [];
  
  // Debug: Log what we received from API
  console.log(`📊 Processing ${jobs.data.jobs.length} jobs from workflow run`);
  console.log(`📊 Test totals - Passed: ${passed}, Failed: ${failed}, Skipped: ${skipped}`);
  
  for (const job of jobs.data.jobs) {
    // Check if the job has a 'run-tests' step and get its conclusion
    // When continue-on-error is true, job.conclusion will be 'success' even if tests fail
    // But step.conclusion will correctly reflect 'failure'
    // Note: GitHub REST API exposes 'conclusion' and 'status' for steps, not 'outcome'
    let actualOutcome = job.conclusion;
    let detectionMethod = 'job-conclusion';  // Track how we determined the status
    
    if (job.steps && job.steps.length > 0) {
      // Method 1: Look for step with id 'run-tests' (most reliable)
      const runTestsStepById = job.steps.find(step => 
        step.name && (step.name.includes('[id:run-tests]') || step.number === 3 || step.number === 4)
      );
      
      // Method 2: Look for steps matching test patterns
      const runTestsStepByName = job.steps.find(step => 
        step.name && TEST_STEP_PATTERNS.some(pattern => step.name.includes(pattern))
      );
      
      const runTestsStep = runTestsStepById || runTestsStepByName;
      
      // Use step.conclusion (API field) instead of step.outcome (workflow context only)
      if (runTestsStep && runTestsStep.conclusion) {
        actualOutcome = runTestsStep.conclusion;
        detectionMethod = 'step-conclusion';
      } else {
        // If no matching test step found, check for any failed step
        const failedStep = job.steps.find(step => step.conclusion === 'failure');
        if (failedStep) {
          actualOutcome = 'failure';
          detectionMethod = 'any-failed-step';
        }
      }
    }
    
    // Fallback: For test jobs, if we have overall test failures but couldn't detect step status,
    // and the job completed successfully (which happens with continue-on-error), 
    // we need to check if this specific job's artifact contains failures
    if (actualOutcome === 'success' && failed > 0 && detectionMethod === 'job-conclusion') {
      // If this is a test job and we have overall failures, we'll mark it as "needs-review"
      // The consolidation step will show the actual failures
      if (job.name.includes('Unit Tests') || job.name.includes('Domain Tests') || job.name.includes('Integration Tests')) {
        // Don't override - we'll show accurate status in aggregate
        console.log(`⚠️  Job "${job.name}" - cannot determine step status, showing job conclusion (${actualOutcome})`);
      }
    }
    
    const jobInfo = {
      name: job.name,
      conclusion: job.conclusion,
      actualOutcome: actualOutcome,  // Use step conclusion from API for accurate status
      detectionMethod: detectionMethod,  // For debugging
      status: job.status,
      url: job.html_url,
      duration: job.completed_at && job.started_at 
        ? Math.round((new Date(job.completed_at) - new Date(job.started_at)) / 1000) 
        : 0
    };
    
    // Debug logging
    if (job.name.includes('Unit Tests') || job.name.includes('Domain Tests') || job.name.includes('Integration Tests')) {
      console.log(`  - ${job.name}: conclusion=${job.conclusion}, actualOutcome=${actualOutcome}, method=${detectionMethod}, steps=${job.steps ? job.steps.length : 0}`);
    }
    
    if (job.name.includes('Unit Tests')) {
      unitTests.push(jobInfo);
    } else if (job.name.includes('Domain Tests')) {
      domainTests.push(jobInfo);
    } else if (job.name.includes('Integration Tests')) {
      integrationTests.push(jobInfo);
    } else if (job.name.includes('Static Analysis')) {
      staticAnalysis.push(jobInfo);
    }
  }
  
  // Helper function to format job status
  const formatJob = (job) => {
    // Use actualOutcome (which reflects step conclusion from API) instead of job conclusion
    // This correctly shows failures even when continue-on-error is true
    let icon, statusText;
    
    if (job.actualOutcome === 'success') {
      icon = '✅';
      statusText = 'PASSED';
    } else if (job.actualOutcome === 'failure') {
      icon = '❌';
      statusText = '**FAILED**';
    } else if (job.actualOutcome === 'skipped') {
      icon = '⏭️';
      statusText = 'SKIPPED';
    } else if (job.actualOutcome === 'cancelled') {
      icon = '🚫';
      statusText = 'CANCELLED';
    } else {
      icon = '⏳';
      statusText = 'RUNNING';
    }
    
    return `| ${icon} [${job.name}](${job.url}) | ${statusText} | ${job.duration}s |`;
  };
  
  // Build sections
  let unitSection = '';
  if (unitTests.length > 0) {
    unitTests.sort((a, b) => a.name.localeCompare(b.name));
    unitSection = `\n### 🧪 Unit Tests (${unitTests.length} jobs)\n**Tests by Script Range**\n\n| Job | Status | Duration |\n|-----|--------|----------|\n`;
    for (const job of unitTests) {
      unitSection += formatJob(job) + '\n';
    }
  }
  
  let domainSection = '';
  if (domainTests.length > 0) {
    domainTests.sort((a, b) => a.name.localeCompare(b.name));
    domainSection = `\n---\n\n### 🏗️ Domain Tests (${domainTests.length} jobs)\n**Tests by Module**\n\n| Job | Status | Duration |\n|-----|--------|----------|\n`;
    for (const job of domainTests) {
      domainSection += formatJob(job) + '\n';
    }
  }
  
  let integrationSection = '';
  if (integrationTests.length > 0) {
    integrationSection = `\n---\n\n### 🔗 Integration Tests (${integrationTests.length} job${integrationTests.length > 1 ? 's' : ''})\n**End-to-End Test Suites**\n\n| Job | Status | Duration |\n|-----|--------|----------|\n`;
    for (const job of integrationTests) {
      integrationSection += formatJob(job) + '\n';
    }
  }
  
  let staticSection = '';
  if (staticAnalysis.length > 0) {
    staticSection = `\n---\n\n### 🔍 Static Analysis (${staticAnalysis.length} job${staticAnalysis.length > 1 ? 's' : ''})\n**Code Quality Checks**\n\n| Job | Status | Duration |\n|-----|--------|----------|\n`;
    for (const job of staticAnalysis) {
      staticSection += formatJob(job) + '\n';
    }
  }
  
  const totalJobs = unitTests.length + domainTests.length + integrationTests.length + staticAnalysis.length;
  const maxDuration = Math.max(...[...unitTests, ...domainTests, ...integrationTests, ...staticAnalysis].map(j => j.duration));
  const estimatedSequential = totalJobs * 60;
  
  const totalTests = passed + failed + skipped;
  const passedPct = totalTests > 0 ? (passed/totalTests*100).toFixed(1) : '0.0';
  const failedPct = totalTests > 0 ? (failed/totalTests*100).toFixed(1) : '0.0';
  const skippedPct = totalTests > 0 ? (skipped/totalTests*100).toFixed(1) : '0.0';
  
  // Calculate job statuses - use actualOutcome for accurate status
  const allJobs = [...unitTests, ...domainTests, ...integrationTests, ...staticAnalysis];
  const failedJobs = allJobs.filter(j => j.actualOutcome === 'failure');
  const hasFailures = failed > 0 || failedJobs.length > 0;
  
  // Add failed jobs summary if there are failures
  let failedJobsSection = '';
  if (failedJobs.length > 0) {
    failedJobsSection = `\n---\n\n### ❌ Failed Jobs Summary\n\n**${failedJobs.length} job(s) failed** - please review and address:\n\n| Failed Job | Link to Logs |\n|------------|-------------|\n`;
    for (const job of failedJobs) {
      failedJobsSection += `| ${job.name} | [View Logs →](${job.url}) |\n`;
    }
    failedJobsSection += '\n';
  }
  
  // Build warning section if there are failures
  let warningSection = '';
  if (hasFailures) {
    warningSection = `
> ## ⚠️ **ATTENTION: This PR has test failures and quality issues**
> 
> **${failed} test(s) failed** across ${failedJobs.length} job(s). Please review and fix before merging.
> 
> - ❌ **Action Required**: Fix failing tests listed below
> - 🔍 **Check Status**: Click on failed job links to see detailed logs
> - 📋 **Not Blocking**: You can still merge, but failures should be addressed
>
> ---

`;
  }
  
  const comment = `## ⚡ Parallel Test Execution Results ${color}

**Overall Status**: ${statusIcon} **${status}**
${warningSection}
### 📊 Aggregate Test Results

| Metric | Count | Percentage |
|--------|-------|------------|
| ✅ Passed | **${passed}** | ${passedPct}% |
| ❌ Failed | **${failed}** | ${failedPct}% |
| ⏭️ Skipped | **${skipped}** | ${skippedPct}% |
| **Total Tests** | **${totalTests}** | **100%** |

---
${unitSection}${domainSection}${integrationSection}${staticSection}${failedJobsSection}
---

### ⚡ Parallel Execution Stats

- **Total Jobs**: ${totalJobs}
- **Concurrent Execution**: Up to 8 parallel jobs
- **Total Duration**: ~${maxDuration}s (vs ~${estimatedSequential}s sequential)
- **Speed Improvement**: ~**3-4x faster** than sequential execution

### 📁 Artifacts & Reports

- [📊 View Full Test Report](${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId})
- [📥 Download Test Results](${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}#artifacts)
- [📈 Test History Dashboard](${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/workflows/parallel-testing.yml)

---

<details>
<summary>💡 <b>Click to expand: How to fix failing tests</b></summary>

1. **View detailed logs**: Click on any failed job link above
2. **Download test results**: Check artifacts section for XML reports
3. **Run locally**: 
   \`\`\`powershell
   # For specific range
   Invoke-Pester -Path "./tests/unit/automation-scripts/0000-0099" -Output Detailed
   
   # For specific domain
   Invoke-Pester -Path "./tests/domains/configuration" -Output Detailed
   \`\`\`
4. **Fix issues**: Address test failures identified in logs
5. **Re-run**: Push changes to trigger automatic re-test

</details>

---

*🤖 Automated by Parallel Testing System • Generated at ${new Date().toISOString()}*
`;
  
  await github.rest.issues.createComment({
    owner: context.repo.owner,
    repo: context.repo.repo,
    issue_number: context.issue.number,
    body: comment
  });
};
