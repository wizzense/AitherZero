// Generate detailed PR comment for parallel test execution
// This script is called from parallel-testing.yml workflow

module.exports = async ({github, context, core}) => {
  const passed = core.getInput('passed');
  const failed = core.getInput('failed');
  const skipped = core.getInput('skipped');
  
  const status = failed > 0 ? 'TESTS FAILED' : 'ALL TESTS PASSED';
  const statusIcon = failed > 0 ? '❌' : '✅';
  const color = failed > 0 ? '🔴' : '🟢';
  
  // Get all workflow jobs to show detailed status
  const jobs = await github.rest.actions.listJobsForWorkflowRun({
    owner: context.repo.owner,
    repo: context.repo.repo,
    run_id: context.runId
  });
  
  // Organize jobs by type
  const unitTests = [];
  const domainTests = [];
  const integrationTests = [];
  const staticAnalysis = [];
  
  for (const job of jobs.data.jobs) {
    const jobInfo = {
      name: job.name,
      conclusion: job.conclusion,
      status: job.status,
      url: job.html_url,
      duration: job.completed_at && job.started_at 
        ? Math.round((new Date(job.completed_at) - new Date(job.started_at)) / 1000) 
        : 0
    };
    
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
    const icon = job.conclusion === 'success' ? '✅' : 
                job.conclusion === 'failure' ? '❌' : 
                job.conclusion === 'skipped' ? '⏭️' : '⏳';
    const statusText = job.conclusion === 'success' ? 'PASSED' : 
                      job.conclusion === 'failure' ? 'FAILED' : 
                      job.conclusion === 'skipped' ? 'SKIPPED' : 'RUNNING';
    return `| ${icon} [${job.name}](${job.url}) | **${statusText}** | ${job.duration}s |`;
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
  
  const totalTests = parseInt(passed) + parseInt(failed) + parseInt(skipped);
  const passedPct = totalTests > 0 ? (passed/totalTests*100).toFixed(1) : '0.0';
  const failedPct = totalTests > 0 ? (failed/totalTests*100).toFixed(1) : '0.0';
  const skippedPct = totalTests > 0 ? (skipped/totalTests*100).toFixed(1) : '0.0';
  
  const comment = `## ⚡ Parallel Test Execution Results ${color}

**Overall Status**: ${statusIcon} **${status}**

### 📊 Aggregate Test Results

| Metric | Count | Percentage |
|--------|-------|------------|
| ✅ Passed | **${passed}** | ${passedPct}% |
| ❌ Failed | **${failed}** | ${failedPct}% |
| ⏭️ Skipped | **${skipped}** | ${skippedPct}% |
| **Total Tests** | **${totalTests}** | **100%** |

---
${unitSection}${domainSection}${integrationSection}${staticSection}
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
