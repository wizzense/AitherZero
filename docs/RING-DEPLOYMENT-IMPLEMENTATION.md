# 🚀 Ring Deployment System - Implementation Guide

This guide helps you get the ring-based deployment system up and running in your repository.

## ✅ What's Included

This PR provides a **complete, production-ready** ring-based deployment system:

- ✅ Automated workflow for ring-aware CI/CD
- ✅ Automatic PR labeling based on source/target rings
- ✅ Progressive test execution (quick → production)
- ✅ Ring management CLI tools
- ✅ Visual HTML dashboard
- ✅ Branch protection configurator
- ✅ Comprehensive documentation

## 🚀 Quick Start (5 Minutes)

### Step 1: Merge This PR

```bash
# Review and merge this PR
gh pr merge <PR_NUMBER> --merge
```

### Step 2: Set Up Ring Branches

```bash
# Checkout main/dev branch as base
git checkout main  # or dev
git pull origin main

# Create all ring branches
for ring in ring-0 ring-0-integrations ring-1 ring-1-integrations ring-2; do
  git branch $ring
  git push origin $ring
done
```

### Step 3: Test the System

```bash
# Create a test change in ring-0
git checkout ring-0
echo "# Ring System Test" >> RING-TEST.md
git add RING-TEST.md
git commit -m "test: verify ring system"
git push origin ring-0

# Create PR to next ring
gh pr create \
  --base ring-0-integrations \
  --head ring-0 \
  --title "🎯 Test: Ring System Validation" \
  --body "Testing automated ring detection and labeling"
```

### Step 4: Verify Automation

Watch the PR you just created:

1. **Labels Applied**: Should see `ring:source:ring-0`, `ring:target:ring-0-integrations`, `ring:promotion`
2. **PR Comment**: Should see detailed ring information with visual hierarchy
3. **Tests Running**: Should execute "integration" test profile
4. **Status Checks**: Should create ring-specific checks

### Step 5: View Dashboard

```powershell
# Generate and view dashboard
./automation-scripts/0711_Generate-RingDashboard.ps1 -OpenBrowser

# Or view ring status in console
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action status
```

## 🔒 Branch Protection (Optional, Requires Admin)

### Configure via Workflow (Recommended)

1. Go to **Actions** → **Configure Ring Branch Protection**
2. Click **Run workflow**
3. Select:
   - **Ring**: `all`
   - **Dry run**: ✅ (checked for first run)
4. Click **Run workflow**
5. Review the generated report
6. Re-run with **Dry run** unchecked to apply

### Manual Configuration

If you prefer to configure manually, use the settings from `.github/ring-config.json`:

**Settings → Branches → Add Branch Protection Rule**

For each ring, configure:
- **Branch name pattern**: `ring-0`, `ring-0-integrations`, etc.
- **Required status checks**: From `branchProtection.requiredStatusChecks`
- **Required approvals**: From `branchProtection.requireApprovals`
- **Dismiss stale reviews**: From `branchProtection.dismissStaleReviews`

## 📊 Daily Usage

### Create Feature Branch

```bash
# Always start from ring-0
git checkout ring-0
git checkout -b feature/my-new-feature

# Develop your feature
# ...

# Push and create PR to ring-0
git push origin feature/my-new-feature
gh pr create --base ring-0 --title "feat: my new feature"
```

### Promote Through Rings

```bash
# After ring-0 PR is merged, promote to next ring
gh pr create \
  --base ring-0-integrations \
  --head ring-0 \
  --title "🎯 Promote to Ring 0-Integrations"

# Continue: ring-0-integrations → ring-1 → ring-1-integrations → ring-2 → dev → main
```

### Using the CLI

```powershell
# View current ring status
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action status

# Promote with automatic PR creation
./automation-scripts/0710_Manage-RingDeployment.ps1 `
  -Action promote `
  -SourceRing ring-0 `
  -TargetRing ring-0-integrations `
  -CreatePR

# Generate dashboard
./automation-scripts/0711_Generate-RingDashboard.ps1 -OpenBrowser

# Validate configuration
./automation-scripts/0710_Manage-RingDeployment.ps1 -Action validate
```

## 🎯 Ring Progression Path

```
Feature Branch
    ↓
ring-0 (Quick tests: 2-3 min)
    ↓
ring-0-integrations (Integration: 5-7 min)
    ↓
ring-1 (Standard: 5-10 min)
    ↓
ring-1-integrations (Full integration: 10-15 min)
    ↓
ring-2 (Comprehensive: 15-20 min)
    ↓
dev (Full suite: 20-30 min) 🔒
    ↓
main (Production: 30-45 min) 🔒
```

## 🔧 Customization

### Modify Ring Behavior

Edit `.github/ring-config.json`:

```json
{
  "rings": {
    "ring-0": {
      "testProfile": "quick",           // Change test profile
      "requiredApprovals": 0,           // Change approval count
      "deploymentGates": {
        "syntaxValidation": true,       // Enable/disable gates
        "unitTests": true
      }
    }
  }
}
```

### Add New Ring

1. Add to `rings` section in `ring-config.json`
2. Add to `branchProtection` section
3. Validate: `./automation-scripts/0710_Manage-RingDeployment.ps1 -Action validate`
4. Create branch: `git branch new-ring && git push origin new-ring`
5. Apply protection: Run configure workflow

### Modify Test Profiles

Edit `testProfiles` section in `ring-config.json`:

```json
{
  "testProfiles": {
    "my-custom-profile": {
      "name": "Custom Tests",
      "estimatedDuration": "10-15 minutes",
      "tests": ["syntax", "unit", "custom-tests"],
      "parallel": true
    }
  }
}
```

## 🐛 Troubleshooting

### Workflow Not Running

**Problem**: Ring-based deployment workflow doesn't trigger
**Solution**:
1. Check workflow file is in `.github/workflows/`
2. Verify branch names match configuration
3. Check workflow permissions
4. Review workflow logs in Actions tab

### Labels Not Applied

**Problem**: PR doesn't get ring labels
**Solution**:
1. Ensure PR is between valid ring branches
2. Check workflow ran (Actions tab)
3. Manually trigger: Actions → Ring-Based Deployment → Run workflow
4. Check workflow logs for errors

### Tests Not Running

**Problem**: Wrong test profile executing or no tests
**Solution**:
1. Verify test profile exists in configuration
2. Check playbook mapping in workflow (lines 450-460)
3. Ensure playbooks exist in `orchestration/playbooks/`
4. Review workflow logs

### Can't Apply Branch Protection

**Problem**: Configure workflow fails with permission error
**Solution**:
1. Requires repository admin permissions
2. Check workflow permissions in `.github/workflows/configure-ring-protection.yml`
3. Try manual configuration in Settings → Branches

## 📚 Documentation

- **Complete Guide**: [`docs/RING-DEPLOYMENT-STRATEGY.md`](docs/RING-DEPLOYMENT-STRATEGY.md)
- **Quick Reference**: [`docs/RING-DEPLOYMENT-QUICK-REFERENCE.md`](docs/RING-DEPLOYMENT-QUICK-REFERENCE.md)
- **System README**: [`.github/RING-DEPLOYMENT-README.md`](.github/RING-DEPLOYMENT-README.md)

## 🆘 Getting Help

- **Issues**: [Create an issue](https://github.com/wizzense/AitherZero/issues/new)
- **Discussions**: [GitHub Discussions](https://github.com/wizzense/AitherZero/discussions)
- **Documentation**: Review docs linked above

## ✨ What Makes This System Great

**Progressive Validation**
- Changes tested incrementally
- Catch issues early
- Build confidence gradually

**Clear Visualization**
- See exactly where changes are
- Understand promotion path
- Track progress easily

**Automated Everything**
- Labels applied automatically
- Tests selected intelligently
- Comments posted with details

**Flexible & Safe**
- Emergency hotfix support
- Demotion capability
- Dry-run mode for safety

## 🎉 You're Ready!

Your ring-based deployment system is now set up and ready to use. Start by:

1. ✅ Creating ring branches
2. ✅ Testing with a sample PR
3. ✅ Configuring branch protection
4. ✅ Training your team on the workflow

Happy deploying! 🚀

---

**Questions?** Check the [documentation](docs/RING-DEPLOYMENT-STRATEGY.md) or [create an issue](https://github.com/wizzense/AitherZero/issues/new).
