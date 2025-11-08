# AitherZero Workflow System Redesign - Master Plan

## Vision
Every PR gets a complete, coordinated ecosystem:
- **Container Deployment**: PR-specific Docker images
- **GitHub Pages**: Dedicated dashboard with metrics, reports, diffs
- **Test Execution**: Full test suite with historical comparison
- **Quality Validation**: Code quality with trend analysis
- **Documentation**: Auto-generated docs with changelog
- **Build Artifacts**: Release packages ready to deploy
- **Actionable Insights**: Clear next steps and recommendations

## Current System Analysis (18 Workflows)

### Core PR Workflows
1. **pr-validation-v2.yml** - Basic PR checks (syntax, format)
2. **quality-validation-v2.yml** - PSScriptAnalyzer, quality metrics
3. **test-execution.yml** - Test suite execution
4. **deploy-pr-environment.yml** - Container builds and deployment
5. **publish-test-reports.yml** - Dashboard and report publishing

### Supporting Workflows  
6. **documentation-automation.yml** - Doc generation
7. **index-automation.yml** - Project indexing
8. **automated-agent-review.yml** - AI code review

### Release Workflows
9. **release-automation.yml** - Release packaging and publishing
10. **comment-release.yml** - Release notifications

### Maintenance/Support
11. **validate-config.yml** - Config validation
12. **validate-manifests.yml** - Module manifest validation
13. **diagnose-ci-failures.yml** - CI diagnostics
14. **jekyll-gh-pages.yml** - GitHub Pages build
15. **ring-status-dashboard.yml** - Ring deployment status
16. **ci-cd-sequences-v2.yml** - Orchestrated sequences
17. **copilot-agent-router.yml** - AI agent routing
18. **phase2-intelligent-issue-creation.yml** - Issue automation

## Problems with Current System

### 1. **Fragmented Execution**
- Workflows run independently
- No coordinated PR lifecycle
- Duplicate logic across workflows
- No central orchestration

### 2. **Incomplete PR Dashboards**
- Missing bootstrap quickstart
- No diff visualization
- No changelog generation
- Missing historical trends
- No actionable recommendations

### 3. **Path Inconsistencies**
- Mix of `domains/` and `aithercore/` references
- Inconsistent script paths (`automation-scripts/` vs `library/automation-scripts/`)
- Outdated module imports

### 4. **Missing PR Features**
- No per-PR container registry tracking
- No per-PR GitHub Pages deployment status
- No cross-workflow data sharing
- No PR-to-PR comparison
- No build artifact tracking

### 5. **Poor Visibility**
- Hard to find PR deployment info
- Container tags not documented
- Test results scattered
- No single source of truth

## New System Design - "PR Ecosystem Orchestrator"

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  PR Lifecycle Orchestrator                   │
│                  (New: pr-ecosystem.yml)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │
           ┌───────────┴───────────┐
           │                       │
    ┌──────▼──────┐        ┌──────▼──────┐
    │   Build     │        │   Analyze   │
    │   Phase     │        │   Phase     │
    └──────┬──────┘        └──────┬──────┘
           │                       │
    ┌──────▼──────────────────────▼──────┐
    │         Deploy & Report Phase       │
    └─────────────────┬───────────────────┘
                      │
              ┌───────▼───────┐
              │   PR Comment  │
              │  Consolidated │
              └───────────────┘
```

### Phase 1: Build Phase (Parallel Execution)
**Workflow**: `pr-build-phase.yml`

Jobs:
- `build-container`: Build PR-specific Docker image
  - Tag: `ghcr.io/wizzense/aitherzero:pr-{number}-{sha}`
  - Tag: `ghcr.io/wizzense/aitherzero:pr-{number}-latest`
  - Multi-platform: linux/amd64, linux/arm64
  
- `build-package`: Create release package
  - Output: `AitherZero-PR{number}-{sha}.zip`
  - Output: `AitherZero-PR{number}-{sha}.tar.gz`
  - Include: build-info.json with full metadata
  
- `build-mcp-server`: Build MCP server package
  - Output: `aitherzero-mcp-server-pr{number}.tgz`
  - Publish to GitHub Packages with PR tag

**Artifacts Generated**:
- Container images (pushed to GHCR)
- Release packages (uploaded as artifacts)
- Build metadata JSON
- Package manifests

### Phase 2: Analyze Phase (Parallel Execution)
**Workflow**: `pr-analyze-phase.yml`

Jobs:
- `test-execution`: Run complete test suite
  - Unit tests with coverage
  - Integration tests
  - Performance tests (if applicable)
  - Output: Test results XML/JSON
  - Output: Coverage reports
  
- `quality-validation`: Code quality analysis
  - PSScriptAnalyzer (full scan)
  - Custom quality validators
  - Comparison with base branch
  - Output: Quality metrics JSON
  - Output: Issue list with severity
  
- `documentation-check`: Documentation validation
  - Generate documentation
  - Check for missing docs
  - Validate links
  - Output: Doc coverage report
  
- `security-scan`: Security analysis
  - Credential scanning
  - Dependency vulnerabilities
  - CodeQL analysis
  - Output: Security report
  
- `diff-analysis`: Change analysis
  - Files changed with stats
  - Function-level diffs
  - Module impact analysis
  - Complexity delta
  - Output: Diff summary JSON

**Artifacts Generated**:
- Test results (XML, JSON, HTML)
- Coverage reports
- Quality metrics
- Documentation reports
- Security scan results
- Diff analysis

### Phase 3: Deploy & Report Phase (Sequential)
**Workflow**: `pr-deploy-report.yml`

Jobs:
- `generate-changelog`: Create PR changelog
  - Parse commits since base branch
  - Categorize changes (feat/fix/docs/etc)
  - Link to issues/PRs referenced
  - Output: CHANGELOG.md
  
- `generate-dashboard`: Create comprehensive dashboard
  - Aggregate all metrics from previous phases
  - Compare with base branch
  - Compare with previous PR commits
  - Generate trend charts
  - Add actionable recommendations
  - Include bootstrap quickstart
  - Add container deployment guide
  - Output: dashboard.html
  
- `deploy-to-pages`: Deploy to GitHub Pages
  - Create PR-specific directory: `/pr-{number}/`
  - Deploy dashboard, reports, coverage
  - Create navigation index
  - Update main index with PR link
  
- `post-pr-comment`: Consolidated PR comment
  - Single comprehensive comment
  - Build status summary
  - Container deployment commands
  - Dashboard links
  - Test results summary
  - Quality metrics summary
  - Actionable next steps
  - Direct links to all resources

**Artifacts Generated**:
- PR changelog
- Comprehensive dashboard
- GitHub Pages deployment
- PR comment content

### Phase 4: Cleanup Phase (On PR Close/Merge)
**Workflow**: `pr-cleanup.yml`

Jobs:
- `cleanup-pr-resources`:
  - Archive PR GitHub Pages content
  - Tag container images as `archived`
  - Update index to mark PR as closed/merged
  - Preserve historical data

## Data Models

### Build Metadata (build-info.json)
```json
{
  "pr": {
    "number": 123,
    "title": "Fix dashboard generation",
    "author": "username",
    "base_branch": "main",
    "head_branch": "feature/dashboard-fix",
    "base_sha": "abc123",
    "head_sha": "def456"
  },
  "build": {
    "number": 456,
    "timestamp": "2024-01-01T12:00:00Z",
    "workflow_run_id": 789,
    "commit_sha": "def456",
    "commit_short": "def4561",
    "commit_message": "fix: dashboard generation"
  },
  "artifacts": {
    "container_image": "ghcr.io/wizzense/aitherzero:pr-123-def456",
    "package_zip": "AitherZero-PR123-def456.zip",
    "package_tar": "AitherZero-PR123-def456.tar.gz",
    "mcp_server": "aitherzero-mcp-server-pr123.tgz"
  },
  "pages": {
    "dashboard_url": "https://wizzense.github.io/AitherZero/pr-123/",
    "reports_url": "https://wizzense.github.io/AitherZero/pr-123/reports/",
    "coverage_url": "https://wizzense.github.io/AitherZero/pr-123/coverage/"
  }
}
```

### Test Results (test-results.json)
```json
{
  "summary": {
    "total": 500,
    "passed": 485,
    "failed": 10,
    "skipped": 5,
    "duration_seconds": 120.5,
    "success_rate": 97.0
  },
  "coverage": {
    "line_coverage": 85.5,
    "branch_coverage": 78.2,
    "function_coverage": 92.1
  },
  "comparison": {
    "base_branch": "main",
    "tests_added": 5,
    "tests_removed": 0,
    "coverage_delta": 2.3,
    "new_failures": ["Test.Should.Pass"],
    "fixed_failures": ["Test.Was.Broken"]
  },
  "details": [...]
}
```

### Quality Metrics (quality-metrics.json)
```json
{
  "overall_score": 92.5,
  "files_analyzed": 225,
  "issues": {
    "total": 45,
    "error": 2,
    "warning": 18,
    "information": 25
  },
  "comparison": {
    "base_score": 90.2,
    "score_delta": 2.3,
    "new_issues": 3,
    "fixed_issues": 8,
    "files_improved": 12,
    "files_degraded": 2
  },
  "by_severity": {
    "error": [...],
    "warning": [...],
    "information": [...]
  },
  "recommendations": [
    "Fix 2 error-level issues before merging",
    "Address warnings in SecurityModule.psm1",
    "Consider refactoring functions with high complexity"
  ]
}
```

### Diff Analysis (diff-analysis.json)
```json
{
  "summary": {
    "files_changed": 25,
    "additions": 350,
    "deletions": 120,
    "net_change": 230
  },
  "by_type": {
    "powershell": {
      "files": 18,
      "additions": 300,
      "deletions": 100
    },
    "markdown": {
      "files": 5,
      "additions": 40,
      "deletions": 15
    },
    "yaml": {
      "files": 2,
      "additions": 10,
      "deletions": 5
    }
  },
  "impact": {
    "modules_affected": ["automation", "testing", "reporting"],
    "scripts_affected": [0512, 0510, 0404],
    "functions_changed": 12,
    "functions_added": 3,
    "functions_removed": 0
  },
  "complexity_delta": {
    "cyclomatic_before": 450,
    "cyclomatic_after": 435,
    "delta": -15,
    "interpretation": "Reduced complexity (good)"
  }
}
```

## Dashboard Template Structure

### Main PR Dashboard (`/pr-{number}/index.html`)

Sections:
1. **Header**: PR info, status badges, quick actions
2. **Bootstrap QuickStart**: One-liner install with PR-specific instructions
3. **Container Deployment**: Pull commands, run instructions
4. **Build Information**: Commit, timestamp, artifacts
5. **Test Results**: Summary with trends, detailed results
6. **Code Quality**: Metrics with comparison, issue list
7. **Coverage**: Line/branch/function coverage with trends
8. **Diff Analysis**: Files changed, impact analysis
9. **Changelog**: Commits with categorization
10. **Documentation**: Coverage, new docs, validation
11. **Security**: Scan results, vulnerabilities
12. **Actionable Recommendations**: Prioritized next steps
13. **Historical Trends**: Charts showing PR evolution
14. **Navigation**: Links to detailed reports

### Supporting Pages
- `/pr-{number}/reports/tests.html` - Detailed test results
- `/pr-{number}/reports/coverage.html` - Coverage visualization
- `/pr-{number}/reports/quality.html` - Quality deep-dive
- `/pr-{number}/reports/diff.html` - Diff viewer with highlighting
- `/pr-{number}/reports/changelog.html` - Full changelog
- `/pr-{number}/reports/security.html` - Security report

## Implementation Plan

### Sprint 1: Core Infrastructure (This PR)
- [ ] Create new workflow orchestrator
- [ ] Update all workflows to use `aithercore/` paths
- [ ] Create data model schemas
- [ ] Build metadata generation script
- [ ] Create dashboard template with all sections

### Sprint 2: Build Phase
- [ ] Implement `pr-build-phase.yml`
- [ ] Container build with proper tagging
- [ ] Package generation with metadata
- [ ] MCP server build automation
- [ ] Artifact upload coordination

### Sprint 3: Analyze Phase
- [ ] Implement `pr-analyze-phase.yml`
- [ ] Enhance test execution with comparison
- [ ] Quality validation with diff analysis
- [ ] Documentation check automation
- [ ] Security scanning integration
- [ ] Diff analysis script

### Sprint 4: Deploy & Report Phase
- [ ] Implement `pr-deploy-report.yml`
- [ ] Changelog generation script
- [ ] Dashboard generation with all metrics
- [ ] GitHub Pages deployment automation
- [ ] PR comment generation

### Sprint 5: Integration & Polish
- [ ] Connect all phases via orchestrator
- [ ] Add historical data tracking
- [ ] Implement trend analysis
- [ ] Add actionable recommendations engine
- [ ] Create cleanup workflow
- [ ] End-to-end testing

## Success Metrics

### For Each PR
- ✅ Container image published and documented
- ✅ GitHub Pages dashboard accessible
- ✅ All tests executed and reported
- ✅ Quality metrics calculated and displayed
- ✅ Diff analysis completed
- ✅ Changelog generated
- ✅ Actionable recommendations provided
- ✅ Single comprehensive PR comment
- ✅ Historical comparison available

### System-Wide
- ✅ All workflows use consistent paths
- ✅ No duplicate logic between workflows
- ✅ Coordinated execution phases
- ✅ Centralized data models
- ✅ Reusable scripts and templates
- ✅ Fast execution (<10 minutes total)
- ✅ Clear documentation
- ✅ Easy to maintain and extend

## Migration Strategy

### Phase A: Preparation (This PR)
1. Fix all path references (domains → aithercore)
2. Create new workflow templates
3. Build supporting scripts
4. Test individual components

### Phase B: Parallel Deployment
1. Deploy new workflows alongside existing
2. Use feature flag to control activation
3. Test with select PRs
4. Gather feedback

### Phase C: Cutover
1. Activate new system for all PRs
2. Archive old workflows
3. Update documentation
4. Train users on new features

### Phase D: Cleanup
1. Remove old workflows
2. Clean up legacy artifacts
3. Optimize performance
4. Add enhancements based on feedback

## File Structure

```
.github/
├── workflows/
│   ├── pr-ecosystem.yml              # New: Master orchestrator
│   ├── pr-build-phase.yml           # New: Build coordination
│   ├── pr-analyze-phase.yml         # New: Analysis coordination
│   ├── pr-deploy-report.yml         # New: Deploy and reporting
│   ├── pr-cleanup.yml               # New: Resource cleanup
│   └── [existing workflows updated]
├── scripts/
│   ├── generate-build-metadata.ps1   # New
│   ├── generate-pr-changelog.ps1     # New
│   ├── generate-pr-dashboard.ps1     # Enhanced
│   ├── analyze-pr-diff.ps1           # New
│   ├── generate-recommendations.ps1  # New
│   └── deploy-to-pages.ps1          # Enhanced
└── templates/
    ├── pr-dashboard.html            # New: Comprehensive template
    ├── pr-comment.md                # New: Comment template
    ├── build-metadata-schema.json   # New
    └── metrics-schema.json          # New

library/automation-scripts/
├── 0512_Generate-Dashboard.ps1      # Enhanced for PR context
├── 0513_Generate-Changelog.ps1      # New
├── 0514_Analyze-Diff.ps1           # New
└── 0515_Generate-BuildMetadata.ps1 # New
```

## Next Steps (Immediate)

1. **This PR**: Fix all path references, update existing workflows
2. **Create new workflow templates**: Start with pr-build-phase.yml
3. **Build supporting scripts**: Metadata, changelog, diff analysis
4. **Enhanced dashboard**: Add all missing sections
5. **Test with real PR**: Validate complete flow
6. **Iterate and refine**: Based on real-world usage

---

**Status**: 🏗️ In Progress - Coordinated Implementation
**Target**: Complete PR ecosystem for every PR
**Timeline**: 5 sprints (this is sprint 1)
