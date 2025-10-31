# AitherCore Build Workflow Integration Guide

This document explains how the AitherCore build workflow integrates with existing AitherZero GitHub Actions workflows.

## Overview

The AitherCore build workflow (`build-aithercore-packages.yml`) is designed to work alongside existing workflows without conflicts, following AitherZero's established CI/CD patterns.

## Integration Points

### 1. Workflow Triggers

**AitherCore Build Workflow**:
- Manual dispatch with version input
- Push to tags matching `aithercore-v*`
- Can be called from other workflows (`workflow_call`)

**No Conflicts With**:
- `release-automation.yml` (triggers on `v*` tags, not `aithercore-v*`)
- `quality-validation.yml` (triggers on PR changes)
- `pr-validation.yml` (triggers on PR events)

### 2. Concurrency Control

**AitherCore**:
```yaml
concurrency:
  group: aithercore-build-${{ github.ref }}
  cancel-in-progress: false
```

**Benefits**:
- Prevents concurrent builds of same ref
- Doesn't cancel in-progress builds (all platforms must complete)
- Different group name prevents conflicts with other workflows

**Comparison with Other Workflows**:
- `pr-validation.yml`: Uses `pr-validation-${{ github.event.pull_request.number }}`
- `quality-validation.yml`: Uses `quality-validation-${{ github.event.pull_request.number || github.run_id }}`
- `release-automation.yml`: No explicit concurrency control

### 3. Environment Variables

**Shared Variables** (aligned with existing workflows):
```yaml
env:
  AITHERZERO_CI: true
  AITHERZERO_NONINTERACTIVE: true
```

These are consistent across all workflows for proper CI behavior.

### 4. Permissions

**AitherCore**:
```yaml
permissions:
  contents: write  # Needed for creating releases
```

**Minimal and Safe**:
- Only requests what's needed
- Follows principle of least privilege
- Same pattern as `release-automation.yml`

### 5. Matrix Strategy

**AitherCore Uses**:
```yaml
strategy:
  fail-fast: false  # Complete all platforms even if one fails
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
```

**Benefits**:
- All platforms build in parallel (cost-efficient)
- Platform-specific packages created simultaneously
- Failures isolated to specific platforms
- Consistent with GitHub best practices

### 6. Artifact Handling

**AitherCore Artifacts**:
- Named: `aithercore-{platform}`
- Retention: 30 days
- Downloaded in `create-release` job

**No Conflicts With**:
- Other workflows use different artifact names
- Separate retention policies
- Independent download/upload cycles

## Workflow Relationships

### Independent Workflows

```
├── pr-validation.yml         → PR analysis (forks & internal)
├── quality-validation.yml    → Code quality checks
├── release-automation.yml    → Full AitherZero releases (v* tags)
└── build-aithercore-packages.yml  → AitherCore packages (aithercore-v* tags)
```

### Workflow Call Integration

The AitherCore workflow can be called from other workflows:

```yaml
# In release-automation.yml (optional addition)
jobs:
  build-aithercore:
    uses: ./.github/workflows/build-aithercore-packages.yml
    with:
      version: ${{ github.event.inputs.version }}
      include_examples: false
      create_release: false
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Usage Scenarios

### Scenario 1: Standalone AitherCore Release

```bash
# Tag and push
git tag aithercore-v1.0.0
git push origin aithercore-v1.0.0

# Result:
# - Builds packages for Windows, Linux, macOS
# - Creates GitHub release
# - Attaches all platform packages
```

### Scenario 2: Manual Build Without Release

```bash
# Use GitHub Actions UI
# Actions → Build AitherCore Packages → Run workflow
# Set: version=1.0.0, create_release=false

# Result:
# - Builds packages
# - Uploads as workflow artifacts (30 days)
# - No GitHub release created
```

### Scenario 3: Full AitherZero Release + AitherCore

Future enhancement - add to `release-automation.yml`:

```yaml
# After main release job
build-aithercore-packages:
  needs: create-release
  uses: ./.github/workflows/build-aithercore-packages.yml
  with:
    version: ${{ needs.create-release.outputs.version }}
    include_examples: true
    create_release: true
```

## Validation & Testing

### Pre-Build Validation

AitherCore workflow includes:
- Module structure validation (11 modules present)
- Module loading test (90 functions)
- Package contents verification

### Post-Build Testing

Each platform build:
- Verifies package creation
- Checks file size
- Lists package contents

### Integration Testing

To test integration:

```bash
# 1. Test manual dispatch
gh workflow run build-aithercore-packages.yml \
  -f version=1.0.0-test \
  -f create_release=false

# 2. Test tag trigger
git tag aithercore-v1.0.0-test
git push origin aithercore-v1.0.0-test

# 3. Verify no conflicts
# - Check other workflows still run
# - Verify no permission errors
# - Confirm artifact isolation
```

## Cost Optimization

### Parallel Builds

Matrix strategy runs all platforms simultaneously:
- Ubuntu: ~3-5 minutes
- Windows: ~4-6 minutes
- macOS: ~4-6 minutes
- **Total billable**: ~5-6 minutes (not 15+ minutes)

### Conditional Execution

```yaml
if: |
  always() &&
  needs.build-packages.result == 'success' &&
  (github.event.inputs.create_release == 'true' || startsWith(github.ref, 'refs/tags/aithercore-v'))
```

Release job only runs when:
- Build succeeds
- Explicitly requested OR tag pushed
- Saves minutes on failed builds

### Artifact Retention

30-day retention balances:
- Availability for debugging
- Storage cost management
- Compliance with other workflows

## Security Considerations

### Fork PR Safety

AitherCore workflow:
- Only triggered by tags or manual dispatch
- Not triggered by PR events
- No risk of malicious PR triggering builds

### Permission Isolation

- Minimal permissions (`contents: write`)
- No access to secrets beyond GITHUB_TOKEN
- Isolated from sensitive workflows

### Tag Protection

Recommendation:
```yaml
# .github/settings.yml (if using probot/settings)
branches:
  - name: main
    protection:
      required_status_checks:
        strict: true
        contexts:
          - Quality Validation
          - PR Validation

tags:
  - name: 'aithercore-v*'
    protection:
      required_signatures: true  # Require signed tags
```

## Monitoring & Debugging

### Workflow Status

Check integration health:
```bash
# List recent workflow runs
gh run list --workflow=build-aithercore-packages.yml

# View specific run
gh run view <run-id> --log

# Check for conflicts
gh run list --status=failure
```

### Common Issues

**Issue**: Build fails on specific platform  
**Solution**: Check platform-specific logs, `fail-fast: false` allows other platforms to complete

**Issue**: Release not created  
**Solution**: Verify conditional logic, check build job succeeded

**Issue**: Artifacts not found  
**Solution**: Verify artifact names match between upload/download

## Future Enhancements

### Potential Additions

1. **Integration with main releases**:
   - Call AitherCore workflow from `release-automation.yml`
   - Create AitherCore packages alongside full releases

2. **PR validation for aithercore/**:
   - Add path trigger for aithercore changes
   - Quick validation before merge

3. **Scheduled builds**:
   - Weekly/monthly automated builds
   - Keep packages fresh

4. **Multi-version support**:
   - Build multiple versions simultaneously
   - Support LTS versions

## Conclusion

The AitherCore build workflow is designed to:
- ✅ Work independently without conflicts
- ✅ Follow existing patterns and conventions
- ✅ Integrate seamlessly when needed
- ✅ Maintain cost efficiency
- ✅ Ensure security and isolation

The workflow is **production-ready** and can be used immediately without impacting existing CI/CD pipelines.

## Quick Reference

| Workflow | Trigger | Output | Conflicts |
|----------|---------|--------|-----------|
| `release-automation.yml` | `v*` tags | Full AitherZero release | None |
| `build-aithercore-packages.yml` | `aithercore-v*` tags | AitherCore packages | None |
| `pr-validation.yml` | PR events | PR analysis | None |
| `quality-validation.yml` | PR changes to code | Quality checks | None |

**Tag Patterns**:
- `v1.0.0` → Full AitherZero release
- `aithercore-v1.0.0` → AitherCore packages only

**Artifact Names**:
- `aithercore-Windows`, `aithercore-Linux`, `aithercore-macOS`
- No conflicts with other workflow artifacts

**Concurrency Groups**:
- All workflows use unique group names
- No cancellation conflicts
