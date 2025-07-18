# CI/CD Enhancements Documentation

## Overview

This document describes the enhanced CI/CD pipeline for AitherZero, providing comprehensive metrics collection, automated issue creation, and health monitoring capabilities.

## Workflows

### 1. Enhanced CI Workflow (`ci-enhanced.yml`)

**Purpose**: Extended CI pipeline with detailed metrics collection and artifact generation.

**Triggers**:
- Push to main/develop branches
- Pull requests to main/develop
- Manual dispatch

**Key Features**:
- **Detailed Quality Analysis**: PSScriptAnalyzer results with file-level breakdown
- **Enhanced Test Metrics**: Test results by suite with failure details
- **Build Metrics**: Build timing and package size tracking
- **Comprehensive Dashboard**: HTML report generation with all metrics
- **PR Comments**: Automatic summary comments on pull requests

**Artifacts Generated**:
- `quality-results/`: PSScriptAnalyzer JSON results
- `test-results-enhanced-{platform}/`: Detailed test results per platform
- `build-metrics-{platform}/`: Build timing and size metrics
- `ci-metrics-complete/`: Aggregated CI metrics
- `ci-dashboard-enhanced/`: HTML dashboard

### 2. Issue Automation Workflow (`issue-automation.yml`)

**Purpose**: Automatically create GitHub issues from CI failures and quality problems.

**Triggers**:
- Completion of CI Enhanced workflow (on failure)
- Manual dispatch with dry-run option

**Issue Types Created**:
1. **Quality Issues**: Files with >5 PSScriptAnalyzer errors
2. **Test Failures**: Test suites with 3+ failing tests
3. **Build Failures**: Platform-specific build failures
4. **CI Health Alerts**: Overall pass rate below 80%

**Smart Features**:
- **Deduplication**: Won't create duplicate issues for the same problem
- **Rich Context**: Includes error messages, stack traces, and fix suggestions
- **Priority Labels**: Critical, high, medium based on severity
- **Dry Run Mode**: Preview issues without creating them

### 3. Health Monitor Workflow (`health-monitor.yml`)

**Purpose**: Track project health metrics over time and generate health reports.

**Triggers**:
- Daily at 2 AM UTC
- Manual dispatch

**Health Metrics**:
- **Code Quality Score**: Based on PSScriptAnalyzer errors/warnings
- **Test Coverage**: Percentage of modules with tests
- **Documentation Score**: Required docs and module documentation
- **CI Health**: Success rate and consecutive failures

**Health Grading**:
- **A (90-100)**: Excellent health 🟢
- **B (80-89)**: Good health 🟡
- **C (70-79)**: Fair health 🟠
- **D (60-69)**: Poor health 🔴
- **F (<60)**: Critical health ⛔

**Outputs**:
- Health score and grade
- Trend analysis (healthy/stable/declining)
- Actionable recommendations
- Optional GitHub issue creation

## Usage Examples

### Running Enhanced CI Manually

```bash
# Trigger enhanced CI workflow
gh workflow run ci-enhanced.yml

# Monitor run
gh run watch
```

### Testing Issue Automation

```bash
# Dry run to see what issues would be created
gh workflow run issue-automation.yml -f dry_run=true

# Create issues from specific CI run
gh workflow run issue-automation.yml -f dry_run=false -f source_run_id=123456789
```

### Health Monitoring

```bash
# Run health check
gh workflow run health-monitor.yml

# Run with custom comparison period and create report
gh workflow run health-monitor.yml -f comparison_days=14 -f create_report=true
```

## Metrics Collection

### Quality Metrics

```json
{
  "TotalFiles": 150,
  "TotalIssues": 45,
  "BySeverity": {
    "Error": 10,
    "Warning": 25,
    "Information": 10
  },
  "ByRule": {
    "PSAvoidUsingCmdletAliases": 15,
    "PSUseDeclaredVarsMoreThanAssignments": 8
  }
}
```

### Test Metrics

```json
{
  "Platform": "ubuntu-latest",
  "Summary": {
    "Total": 450,
    "Passed": 425,
    "Failed": 20,
    "Skipped": 5,
    "PassRate": 94.4
  },
  "TestSuites": {
    "Module-Loading": {
      "Total": 50,
      "Failed": 5,
      "Failures": [
        {
          "Test": "Should load module without errors",
          "Error": "Module not found",
          "StackTrace": "..."
        }
      ]
    }
  }
}
```

### Health Metrics

```json
{
  "Overall": {
    "Score": 85.5,
    "Grade": "B"
  },
  "Quality": {
    "Score": 88,
    "Errors": 10,
    "Warnings": 25
  },
  "Tests": {
    "Coverage": 90,
    "TestedModules": 27,
    "TotalModules": 30
  },
  "Documentation": {
    "Score": 75,
    "RequiredDocs": 3,
    "ModuleDocs": 20
  },
  "CI": {
    "Score": 85,
    "SuccessRate": 85,
    "ConsecutiveFailures": 0
  }
}
```

## Configuration

### Severity Thresholds

- **PSScriptAnalyzer Error Threshold**: 25 errors (configurable in workflow)
- **Test Failure Threshold**: 3+ failures to create issue
- **CI Health Threshold**: 80% pass rate

### Artifact Retention

- CI artifacts: 30 days
- Health reports: 90 days
- Issue automation results: 30 days

## Best Practices

1. **Monitor Health Trends**: Review weekly health reports to catch declining metrics early
2. **Address Critical Issues First**: Focus on issues labeled as "critical" or "high"
3. **Use Dry Run**: Test issue automation changes with dry_run=true
4. **Review Dashboards**: Check HTML dashboards for detailed analysis
5. **Act on Recommendations**: Follow health monitor recommendations

## Troubleshooting

### Common Issues

1. **No artifacts found**:
   - Ensure CI Enhanced workflow completed
   - Check artifact names match expected patterns

2. **Duplicate issues created**:
   - Issue automation checks for existing issues
   - May occur if issue title format changes

3. **Health score seems wrong**:
   - Review individual metric scores
   - Check weight configuration in workflow

### Debugging

```bash
# List recent workflow runs
gh run list --workflow=ci-enhanced.yml --limit=10

# Download specific artifacts
gh run download [RUN_ID] -n quality-results

# View workflow logs
gh run view [RUN_ID] --log
```

## Future Enhancements

1. **Historical Trending**: Store metrics in time-series database
2. **Slack/Teams Integration**: Send alerts to chat platforms
3. **Custom Thresholds**: Per-module quality thresholds
4. **Performance Metrics**: Track test execution time
5. **Security Scanning**: Integrate security vulnerability scanning

## Related Documentation

- [CI/CD Overview](./CI-CD-OVERVIEW.md)
- [Testing Guide](./TESTING.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
- [AitherZero Architecture](./ARCHITECTURE.md)