# 🎯 Ring-Based Deployment Strategy

## Overview

AitherZero implements a comprehensive **ring-based deployment strategy** to ensure safe, incremental rollout of changes across different stability tiers. This approach minimizes risk by validating changes through progressively more rigorous testing environments before reaching production.

## Ring Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                    RING HIERARCHY                        │
└─────────────────────────────────────────────────────────┘

Ring 0                    [Level 0]    Early Development
    │
    ├─► Ring 0-Integrations  [Level 0.5]  Integration Testing
            │
            ├─► Ring 1            [Level 1]    Validation
                    │
                    ├─► Ring 1-Integrations [Level 1.5]  Full Integration
                            │
                            ├─► Ring 2        [Level 2]    Pre-Production
                                    │
                                    ├─► Dev (Ring 4)  [Level 4]    Development Env
                                            │
                                            └─► Main (Ring 5) [Level 5]    Production
```

## Ring Definitions

### Ring 0 - Early Development
- **Purpose**: Earliest testing phase for new features and experimental changes
- **Test Profile**: Quick (2-3 minutes)
- **Required Approvals**: 0
- **Deployment Gates**:
  - ✅ Syntax Validation
  - ✅ Unit Tests
  - ⏭️ Integration Tests (skipped)
  - ⏭️ Security Scan (skipped)

**Best For**:
- Feature branches
- Experimental code
- Rapid iteration
- Early feedback

### Ring 0-Integrations
- **Purpose**: Integration testing for Ring 0 features before promotion
- **Test Profile**: Integration (5-7 minutes)
- **Required Approvals**: 0
- **Deployment Gates**:
  - ✅ Syntax Validation
  - ✅ Unit Tests
  - ✅ Integration Tests
  - ✅ Security Scan (basic)

**Best For**:
- Testing feature interactions
- Validating external dependencies
- Integration smoke tests

### Ring 1 - Validation
- **Purpose**: Secondary validation ring for stable feature development
- **Test Profile**: Standard (5-10 minutes)
- **Required Approvals**: 1
- **Deployment Gates**:
  - ✅ Syntax Validation
  - ✅ Unit Tests
  - ✅ Integration Tests
  - ✅ Security Scan

**Best For**:
- Stable feature branches
- Multi-feature integration
- Pre-release validation

### Ring 1-Integrations
- **Purpose**: Full integration testing before pre-production
- **Test Profile**: Integration (10-15 minutes)
- **Required Approvals**: 1
- **Deployment Gates**:
  - ✅ Syntax Validation
  - ✅ Unit Tests
  - ✅ Integration Tests
  - ✅ Security Scan
  - ✅ Performance Tests

**Best For**:
- Comprehensive integration testing
- Performance validation
- Cross-component testing

### Ring 2 - Pre-Production
- **Purpose**: Pre-production testing with comprehensive validation
- **Test Profile**: Comprehensive (15-20 minutes)
- **Required Approvals**: 1
- **Deployment Gates**:
  - ✅ Syntax Validation
  - ✅ Unit Tests
  - ✅ Integration Tests
  - ✅ Security Scan
  - ✅ Performance Tests
  - ✅ Manual Approval

**Best For**:
- Release candidates
- Final validation before dev
- Production-like environment testing

### Dev (Ring 4) - Development Environment
- **Purpose**: Full development environment with complete test suite
- **Test Profile**: Full (20-30 minutes)
- **Required Approvals**: 1
- **Protected**: ✅ Yes
- **Deployment Gates**:
  - ✅ All previous gates
  - ✅ Code Coverage
  - ✅ Manual Approval

**Best For**:
- Development environment deployment
- End-to-end testing
- Stakeholder demos

### Main (Ring 5) - Production
- **Purpose**: Production environment - highest stability requirements
- **Test Profile**: Production (30-45 minutes)
- **Required Approvals**: 2
- **Protected**: ✅ Yes
- **Deployment Gates**:
  - ✅ All previous gates
  - ✅ Compliance Check
  - ✅ Signed Commits
  - ✅ Manual Approval

**Best For**:
- Production releases
- Public deployments
- Stable, validated code only

## Workflow Integration

### Automatic PR Labeling

When a PR is created, it is automatically labeled based on source and target rings:

```yaml
Labels Applied:
  - ring:source:<ring-name>     # Blue label
  - ring:target:<ring-name>     # Orange label
  - ring:promotion              # Green (if promoting)
  - ring:demotion               # Yellow (if demoting)
```

### Test Profile Selection

Tests run automatically based on the **target ring** of your PR:

| Target Ring | Test Profile | What Runs |
|-------------|--------------|-----------|
| ring-0 | quick | Syntax + Basic Unit Tests |
| ring-0-integrations | integration | + Integration Tests + Basic Security |
| ring-1 | standard | + PSScriptAnalyzer |
| ring-1-integrations | integration | + Performance Tests |
| ring-2 | comprehensive | + Full Security Scan |
| dev | full | + Code Coverage + Load Tests |
| main | production | + Compliance + Stress Tests |

### PR Comments

Every PR receives a detailed comment showing:
- Ring progression visualization
- Test requirements
- Estimated test duration
- Next steps for approval

## Using the Ring System

### Creating a PR Between Rings

1. **Create your feature branch** (based on ring-0):
   ```bash
   git checkout ring-0
   git checkout -b feature/my-new-feature
   # Make changes...
   git push origin feature/my-new-feature
   ```

2. **Create PR to ring-0**:
   - GitHub will auto-label it
   - Quick tests will run (~2-3 min)
   - Merge when tests pass

3. **Promote to ring-0-integrations**:
   ```bash
   # Create PR from ring-0 to ring-0-integrations
   gh pr create --base ring-0-integrations --head ring-0 --title "Promote to Ring 0 Integrations"
   ```
   - Integration tests will run (~5-7 min)
   - Labels update automatically

4. **Continue promotion**:
   - Repeat for each ring level
   - Tests become more comprehensive at each level
   - More approvals required at higher levels

### Using the Management Script

```powershell
# View current ring status
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action status

# Promote with PR creation
./automation-scripts/0710_Manage-RingDeployment.ps1 `
    -Action promote `
    -SourceRing ring-0 `
    -TargetRing ring-0-integrations `
    -CreatePR

# Generate ring report
./automation-scripts/0710_Manage-RingDeployment.ps1 `
    -Action report `
    -Format markdown

# Validate configuration
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action validate
```

### Workflow Dispatch

Use GitHub Actions workflow dispatch for advanced operations:

1. Go to **Actions** → **Ring-Based Deployment**
2. Click **Run workflow**
3. Select:
   - **Action**: promote, demote, or status
   - **From Ring**: Source ring
   - **To Ring**: Target ring
4. Click **Run workflow**

## Branch Protection Rules

Ring branches have protection rules based on their level:

| Ring | Required Checks | Approvals | Restrict Push |
|------|----------------|-----------|---------------|
| ring-0 | Syntax, Unit Tests | 0 | No |
| ring-0-integrations | + Integration Tests | 0 | No |
| ring-1 | + Security Scan | 1 | No |
| ring-1-integrations | + Performance Tests | 1 | No |
| ring-2 | All checks | 1 | Yes (maintainers) |
| dev | All + Coverage | 1 | Yes (admins only) |
| main | All + Compliance | 2 | Yes (admins only) |

## Best Practices

### 1. Start at the Lowest Ring
Always start development in **ring-0** unless hotfixing.

### 2. Incremental Promotion
Promote through each ring sequentially:
```
ring-0 → ring-0-integrations → ring-1 → ring-1-integrations → ring-2 → dev → main
```

### 3. Integration Testing
Use `-integrations` rings for:
- Testing multiple features together
- Validating external dependencies
- Running longer integration tests

### 4. Monitor Test Results
Check test results at each ring level:
- Fix issues before promoting
- Don't skip rings (unless emergency)
- Review test coverage reports

### 5. Emergency Hotfixes
For production emergencies:
1. Branch from `main`
2. Create fix
3. Test in `ring-2` minimum
4. Fast-track to `main` with emergency label
5. Backport to lower rings

## Configuration

### Ring Configuration File
`.github/ring-config.json` contains:
- Ring definitions
- Test profiles
- Deployment gates
- Branch protection rules
- Notification settings

### Modifying Ring Behavior

Edit `.github/ring-config.json`:

```json
{
  "rings": {
    "ring-0": {
      "testProfile": "quick",
      "requiredApprovals": 0,
      "deploymentGates": {
        "syntaxValidation": true,
        "unitTests": true
      }
    }
  }
}
```

## Metrics and Monitoring

### Tracked Metrics
- Promotion duration
- Test duration per ring
- Failure rate by ring
- Time in each ring
- Approval time

### Dashboard
View ring status on the dashboard:
- **URL**: `https://wizzense.github.io/AitherZero/reports/ring-dashboard.html`
- **Updates**: Hourly
- **Retention**: 90 days

## Troubleshooting

### Issue: PR not auto-labeled
**Solution**: Re-run the workflow or manually trigger:
```bash
gh workflow run ring-based-deployment.yml
```

### Issue: Wrong test profile running
**Solution**: Check target branch in PR. Tests match target ring, not source.

### Issue: Can't promote to higher ring
**Solution**: 
1. Ensure source ring tests passed
2. Check required approvals
3. Verify branch exists
4. Check branch protection rules

### Issue: Emergency production fix needed
**Solution**:
1. Use emergency promotion workflow
2. Label PR with `emergency-promotion`
3. Get admin approval
4. Backport after production fix

## Examples

### Example 1: New Feature Development
```bash
# 1. Create feature branch from ring-0
git checkout ring-0
git checkout -b feature/user-auth

# 2. Develop and test locally
# ... make changes ...

# 3. Push and create PR to ring-0
git push origin feature/user-auth
gh pr create --base ring-0 --head feature/user-auth

# 4. After merge, promote through rings
gh pr create --base ring-0-integrations --head ring-0 --title "🎯 Promote: user-auth"
# Wait for tests, merge, repeat...
```

### Example 2: Multi-Feature Integration
```bash
# Features developed in ring-0
# Merge multiple features to ring-0-integrations for integration testing

gh pr create --base ring-0-integrations --head ring-0 \
  --title "🎯 Integration: Features A, B, C"

# Run integration tests
# Fix any integration issues
# Promote to ring-1 when stable
```

### Example 3: Release Preparation
```bash
# Final checks in ring-2
gh pr create --base ring-2 --head ring-1-integrations \
  --title "🎯 Release Candidate: v2.0.0"

# Comprehensive testing in ring-2
# Manual approval + stakeholder review
# Promote to dev for final validation
# Promote to main for production release
```

## Related Documentation

- [CI/CD Guide](./CI-CD-GUIDE.md)
- [Testing Strategy](./TESTING-STRATEGY.md)
- [Branch Protection](./BRANCH-PROTECTION.md)
- [Deployment Process](./DEPLOYMENT-PROCESS.md)

## Support

For questions or issues with the ring deployment system:
- **GitHub Issues**: [Create an issue](https://github.com/wizzense/AitherZero/issues/new)
- **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
- **Workflow Logs**: Check Actions tab for detailed logs

---

**Last Updated**: 2025-11-05  
**Version**: 1.0.0  
**Status**: Active
