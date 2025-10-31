# CI/CD Pipeline Quick Start Guide

## 🚀 Getting Started

The AitherZero CI/CD pipeline is **fully automated** and requires **zero manual configuration** for standard workflows.

## For Developers

### Creating a Pull Request

1. **Create your branch and make changes**
   ```bash
   git checkout -b feature/my-awesome-feature
   # Make your changes
   git add .
   git commit -m "Add awesome feature"
   git push origin feature/my-awesome-feature
   ```

2. **Open PR on GitHub**
   - The CI/CD Orchestrator automatically starts
   - Change detection analyzes what you modified
   - Relevant validations run in parallel

3. **Review automated feedback**
   - **Copilot** and **Gemini** will automatically review your PR
   - Check CI summary for validation results
   - Address any issues found

4. **Iterate if needed**
   ```bash
   # Make fixes
   git add .
   git commit -m "Address review feedback"
   git push
   ```
   - CI automatically re-runs on every push
   - Reviews update automatically

5. **Merge when green**
   - All checks must pass (✅)
   - Reviews should be addressed
   - Ready to merge!

### What Runs Automatically

On every PR update:
- ✅ Syntax validation
- ✅ PSScriptAnalyzer linting
- ✅ Manifest validation
- ✅ Quality checks
- ✅ Test suite (unit, integration, domain)
- ✅ Security scanning
- ✅ Copilot review
- ✅ Gemini review

**Total time**: ~8 minutes (parallel execution)

### Local Testing

Before pushing, run local tests:
```powershell
# Run unit tests
az 0402

# Run syntax validation
az 0407

# Run PSScriptAnalyzer
az 0404

# Generate project report
az 0510 -ShowAll
```

## For Maintainers

### Monitoring Pipeline Health

1. **Check daily health report**
   - Runs every day at 9 AM UTC
   - View in Actions → CI/CD Monitoring workflow
   - Shows success rate, durations, trends

2. **Review auto-created issues**
   - CI failures automatically create issues
   - Labeled with `ci-failure` and `needs-triage`
   - Linked to failed workflow run

3. **Track performance**
   - Metrics stored in `metrics/ci-performance/`
   - Performance degradation alerts automatically
   - Review trends over time

### Manual Workflow Triggers

#### Run CI Orchestrator manually
```
1. Go to Actions → CI/CD Orchestrator
2. Click "Run workflow"
3. Choose branch
4. Optional: Skip tests or reviews
5. Click "Run workflow"
```

#### Trigger deployment manually
```
1. Go to Actions → Automated Deployment
2. Click "Run workflow"
3. Choose environment (staging/production)
4. Optional: Skip tests
5. Click "Run workflow"
```

#### Generate health report
```
1. Go to Actions → CI/CD Monitoring
2. Click "Run workflow"
3. Review summary in job output
```

### Deployment Process

#### Staging (Automatic)
```bash
# Merge to main
git checkout main
git merge feature/my-feature
git push
```
- Automatically deploys to staging
- Pre-deployment tests run first
- Package is built and deployed
- Post-deployment verification
- Automatic rollback if issues

#### Production (Tag-based)
```bash
# Create version tag
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```
- Automatically deploys to production
- Full validation before deployment
- Creates GitHub release
- Post-deployment verification
- Rollback capability

### Handling Failures

#### CI Failure
1. Check auto-created issue
2. Review workflow logs (link in issue)
3. Fix the problem
4. Push fix or re-run workflow

#### Deployment Failure
1. Automatic rollback already triggered
2. Check deployment logs
3. Review rollback job output
4. Fix issue and redeploy

#### Performance Issues
1. Check CI Monitoring alerts
2. Review performance metrics
3. Identify slow jobs
4. Optimize as needed

## Common Workflows

### Trigger AI Reviews Manually

In any PR, add a comment:
```
@copilot /review
```
or
```
@gemini-cli /review
```

### Skip CI for Documentation Changes

Add to commit message:
```
git commit -m "Update docs [skip ci]"
```
(Note: This skips CI entirely - use carefully!)

### Re-run Failed Jobs

1. Go to failed workflow run
2. Click "Re-run jobs"
3. Select "Re-run failed jobs"
4. Or "Re-run all jobs" if needed

### View Detailed Results

1. Click on workflow run
2. Expand job
3. Review step logs
4. Download artifacts if available

## Pipeline Stages

### Stage 1: Change Detection (1-2 min)
- Analyzes what files changed
- Determines which checks to run
- Optimizes pipeline execution

### Stage 2: Fast Validation (3-4 min)
Runs in parallel:
- Syntax validation
- PSScriptAnalyzer linting
- Manifest validation

### Stage 3: Comprehensive Testing (5-6 min)
Runs in parallel:
- Quality checks
- Unit tests
- Integration tests
- Domain tests
- Security scanning

### Stage 4: Automated Reviews (2-3 min)
Runs in parallel:
- Copilot review
- Gemini review

### Stage 5: Summary (1 min)
- Aggregates all results
- Creates comprehensive summary
- Sets final status

**Total**: ~8 minutes for full pipeline

## Best Practices

### Do's ✅
- ✅ Run local tests before pushing
- ✅ Keep PRs small and focused
- ✅ Address review feedback promptly
- ✅ Wait for all checks before merging
- ✅ Monitor CI health regularly

### Don'ts ❌
- ❌ Don't skip tests without reason
- ❌ Don't merge with failing checks
- ❌ Don't ignore security warnings
- ❌ Don't push broken code
- ❌ Don't create huge PRs

## Troubleshooting Quick Fixes

### "Workflow not triggering"
- Check file paths match trigger patterns
- Ensure branch name is correct
- Verify permissions on repository

### "Tests failing"
```powershell
# Run locally to debug
./az.ps1 0402

# Check specific test
Invoke-Pester -Path ./tests/unit/MyTest.Tests.ps1 -Output Detailed
```

### "Timeout issues"
- May need to increase timeout in workflow
- Check for infinite loops
- Review performance of tests

### "Permission denied"
- Check workflow permissions section
- May need repository settings change
- Contact maintainer

## Quick Reference

### Workflow Files
| File | Purpose | Trigger |
|------|---------|---------|
| ci-orchestrator.yml | Main CI controller | PR events |
| automated-deployment.yml | Deployments | Push to main, tags |
| ci-monitoring.yml | Health monitoring | Workflow completion |
| gemini-dispatch.yml | AI reviews | PR events, comments |
| quality-validation.yml | Code quality | PR events |

### Commands
| Action | Command |
|--------|---------|
| Run tests | `./az.ps1 0402` |
| Syntax check | `./az.ps1 0407` |
| Linting | `./az.ps1 0404` |
| Project report | `./az.ps1 0510 -ShowAll` |
| Validate manifest | `./az.ps1 0405` |

### Status Badges

Add to your README.md:
```markdown
![CI/CD Status](https://github.com/wizzense/AitherZero/actions/workflows/ci-orchestrator.yml/badge.svg)
![Deployment Status](https://github.com/wizzense/AitherZero/actions/workflows/automated-deployment.yml/badge.svg)
```

## Getting Help

1. **Check documentation**: `.github/CI-CD-PIPELINE.md`
2. **Review issues**: Look for `ci-failure` label
3. **Ask in PR**: Tag maintainers
4. **Workflow logs**: Always check logs first

## Summary

The CI/CD pipeline is designed to be:
- **Automatic**: No manual steps needed
- **Fast**: Parallel execution (~8 minutes)
- **Comprehensive**: Multiple validation layers
- **Intelligent**: AI-powered reviews
- **Reliable**: Automatic rollback and monitoring

Just create PRs as normal, and the pipeline handles everything else! 🚀
